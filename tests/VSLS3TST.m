VSLS3TST	; v-stdlib — VSLS3 egress sink + LDJSON envelope test suite.
	; Phase 3 / M2, stage 3.1 (spec §9 envelope, §11 bucket layout, §12 sink).
	; The egress-INDEPENDENT core: the LDJSON framing (raw verbatim payload,
	; base64 switch, per-record sha256 anchor), the §11 object-key layout, and
	; the config seam. The live S3 PUT/GET round-trip (which needs engine HTTP
	; egress, G-HTTP-*) is carved into the integration suite, not here — these
	; run on a BARE engine:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLS3TST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLS3TST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tEnvelopePayloadByteExact(.pass,.fail)
	do tEnvelopeMetadataFields(.pass,.fail)
	do tEnvelopeNoTrailingNewline(.pass,.fail)
	do tEnvelopeBase64RoundTrip(.pass,.fail)
	do tEnvelopeHashAnchorsRawBytes(.pass,.fail)
	do tKeyLayout(.pass,.fail)
	do tManifestKeyLayout(.pass,.fail)
	do tCtxFromConfigSeam(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
specials()	; (private) a verbatim record spanning the §15.2 edge cases.
	; $C(1) RPC delimiter, CR/LF, tab, a double-quote, a backslash, control byte.
	quit "ORWPT ID INFO"_$char(1)_"500;DPT(0)"_$char(13,10)_"a"_$char(9)_"b\c"_""""_"q"_$char(2)
	;
tEnvelopePayloadByteExact(pass,fail)	;@TEST "inline envelope: payload round-trips BYTE-EXACT through JSON escaping (full fidelity)"
	new rec,opt,line,t
	set rec=$$specials()
	set opt("ts")="65800,43200"
	set line=$$envelope^VSLS3(rec,"rpc","resp","500",7,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"the LDJSON line is well-formed JSON")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("payload")),rec,"decoded payload equals the verbatim record byte-for-byte")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("enc")),"inline","enc=inline by default")
	quit
	;
tEnvelopeMetadataFields(pass,fail)	;@TEST "envelope metadata: proto/dir/station/seq/len/ts carried non-interpretively"
	new rec,opt,line,t
	set rec="hello world"
	set opt("ts")="65800,43200"
	set line=$$envelope^VSLS3(rec,"rpc","req","442",13,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("proto")),"rpc","proto field")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("dir")),"req","dir field")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("station")),"442","station field")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("seq")),13,"seq field (numeric)")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("len")),$length(rec),"len = byte length")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("ts")),"65800,43200","ts carried verbatim")
	quit
	;
tEnvelopeNoTrailingNewline(pass,fail)	;@TEST "the envelope is one LDJSON line: no embedded/trailing newline (flush adds $C(10))"
	new line,opt
	set opt("ts")="65800,43200"
	set line=$$envelope^VSLS3("plain","rpc","req","500",1,.opt)
	do eq^STDASSERT(.pass,.fail,$extract(line,1),"{","line opens with {")
	do eq^STDASSERT(.pass,.fail,$extract(line,$length(line)),"}","line closes with } — no trailing newline")
	do eq^STDASSERT(.pass,.fail,$length(line,$char(10)),1,"no embedded newline in the line itself")
	quit
	;
tEnvelopeBase64RoundTrip(pass,fail)	;@TEST "base64 switch: payload is base64; decode is byte-exact (guaranteed for arbitrary bytes)"
	new rec,opt,line,t,b64
	set rec=$$specials()
	set opt("ts")="65800,43200",opt("base64")=1
	set line=$$envelope^VSLS3(rec,"rpc","resp","500",9,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("enc")),"base64","enc=base64 when switched on")
	set b64=$$valueOf^STDJSON(t("payload"))
	do eq^STDASSERT(.pass,.fail,$$decode^STDB64(b64),rec,"base64 payload decodes byte-exact")
	quit
	;
tEnvelopeHashAnchorsRawBytes(pass,fail)	;@TEST "per-record sha256 anchors the RAW bytes (the fidelity anchor VSLTAPFC re-checks)"
	new rec,opt,line,t
	set rec=$$specials()
	set opt("ts")="65800,43200"
	set line=$$envelope^VSLS3(rec,"rpc","resp","500",7,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("hash")),$$sha256^STDCRYPTO(rec),"hash = sha256 of the verbatim record")
	quit
	;
tKeyLayout(pass,fail)	;@TEST "object key follows §11: traffic/<station>/<proto>/<yyyy>/<mm>/<dd>/<seq>.ndjson"
	do eq^STDASSERT(.pass,.fail,$$key^VSLS3("500","rpc",42,"20260619"),"traffic/500/rpc/2026/06/19/42.ndjson","RPC key layout")
	do eq^STDASSERT(.pass,.fail,$$key^VSLS3("442","hl7",1,"20260101"),"traffic/442/hl7/2026/01/01/1.ndjson","HL7 key layout, zero-padded month/day")
	quit
	;
tManifestKeyLayout(pass,fail)	;@TEST "manifest keys follow §11: _offwindows and _fidelity per-day JSON objects"
	do eq^STDASSERT(.pass,.fail,$$offWindowsKey^VSLS3("500","20260619"),"traffic/500/_offwindows/2026/06/19.json","_offwindows manifest key")
	do eq^STDASSERT(.pass,.fail,$$fidelityKey^VSLS3("500","20260619"),"traffic/500/_fidelity/2026/06/19.json","_fidelity manifest key")
	quit
	;
tCtxFromConfigSeam(pass,fail)	;@TEST "ctx is built from the ^VSLTAP config seam (creds/region/endpoint/bucket/station)"
	new ctx,opt,bucket
	kill ^VSLTAP("cfg")
	set ^VSLTAP("cfg","s3accesskey")="minioadmin"
	set ^VSLTAP("cfg","s3secretkey")="minioadmin"
	set ^VSLTAP("cfg","s3region")="us-east-1"
	set ^VSLTAP("cfg","s3endpoint")="http://m-s3-minio:9000"
	set ^VSLTAP("cfg","s3bucket")="vista-traffic"
	set bucket=$$ctx^VSLS3(.ctx,.opt)
	do eq^STDASSERT(.pass,.fail,bucket,"vista-traffic","bucket read from the config seam")
	do eq^STDASSERT(.pass,.fail,ctx("accessKey"),"minioadmin","accessKey from the seam")
	do eq^STDASSERT(.pass,.fail,ctx("secretKey"),"minioadmin","secretKey from the seam")
	do eq^STDASSERT(.pass,.fail,ctx("region"),"us-east-1","region from the seam")
	do eq^STDASSERT(.pass,.fail,ctx("service"),"s3","service defaults to s3")
	do eq^STDASSERT(.pass,.fail,opt("endpoint"),"http://m-s3-minio:9000","endpoint override from the seam (path-style)")
	quit
