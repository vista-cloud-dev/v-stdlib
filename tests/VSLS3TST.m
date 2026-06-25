VSLS3TST	; v-stdlib — VSLS3 egress sink + schema-v1 LDJSON envelope test suite.
	; Phase 3 / M2 + Phase 6 (FU-14/15/17/18): the schema-v1 wire envelope
	; (docs/design/s3tap-envelope-schema-lock.md §3), the §11 object-key layout,
	; and the config seam. The envelope is ONE shape for req + resp (`direction`
	; discriminates); wire_len is computed over the RAW bytes (no payload digest —
	; the tap adds no crypto); the
	; payload round-trips byte-exact (raw inline + base64). The live S3 PUT/GET
	; round-trip (which needs engine HTTP egress, G-HTTP-*) is carved into the
	; integration suite, not here — these run on a BARE engine:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLS3TST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLS3TST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tEnvelopePayloadByteExact(.pass,.fail)
	do tEnvelopeSchemaVersionAndIds(.pass,.fail)
	do tEnvelopeMetadataFields(.pass,.fail)
	do tEnvelopeReqCarriesDenied(.pass,.fail)
	do tEnvelopeRespCarriesResultKind(.pass,.fail)
	do tEnvelopeNoTrailingNewline(.pass,.fail)
	do tEnvelopeBase64RoundTrip(.pass,.fail)
	do tEnvelopeHasNoHashField(.pass,.fail)
	do tEnvelopeByteIdenticalDeterministic(.pass,.fail)
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
resp(rec,payload,seq)	; (private) build a schema-v1 resp field array fixture.
	kill rec
	set rec("direction")="resp",rec("call_id")="500-123-7",rec("ts")="65800,43200"
	set rec("protocol")="rpc",rec("station")="500",rec("seq")=seq,rec("rpc")="ORWPT ID INFO"
	set rec("duz")="10",rec("job")=123,rec("client")="10.0.0.5:4711",rec("result_kind")="scalar"
	set rec("payload")=payload
	quit
	;
tEnvelopePayloadByteExact(pass,fail)	;@TEST "schema-v1 envelope: payload round-trips BYTE-EXACT through JSON escaping (full fidelity)"
	new rec,opt,line,t
	do resp(.rec,$$specials(),7)
	set line=$$envelope^VSLS3(.rec,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"the LDJSON line is well-formed JSON")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("payload")),$$specials(),"decoded payload equals the verbatim record byte-for-byte")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("payload_encoding")),"raw","payload_encoding=raw by default")
	quit
	;
tEnvelopeSchemaVersionAndIds(pass,fail)	;@TEST "schema-v1: schema_version=1, event_id = call_id ':' direction (FU-14 correlation)"
	new rec,opt,line,t
	do resp(.rec,"hello",7)
	set line=$$envelope^VSLS3(.rec,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("schema_version")),1,"schema_version is 1")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("call_id")),"500-123-7","call_id carried")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("event_id")),"500-123-7:resp","event_id = call_id ':' direction")
	quit
	;
tEnvelopeMetadataFields(pass,fail)	;@TEST "schema-v1 metadata: protocol/direction/station/seq/rpc/duz/job/client/wire_len/chunk_count"
	new rec,opt,line,t
	do resp(.rec,"hello world",13)
	set line=$$envelope^VSLS3(.rec,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("protocol")),"rpc","protocol field")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("direction")),"resp","direction field")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("station")),"500","station field")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("seq")),13,"seq field (numeric)")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("rpc")),"ORWPT ID INFO","rpc name field")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("duz")),"10","duz field (FU-18)")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("job")),123,"job field = $J (FU-18, numeric)")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("client")),"10.0.0.5:4711","client IP:port field (FU-18)")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("wire_len")),11,"wire_len = byte length of the raw payload")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("chunk_count")),1,"chunk_count defaults to 1 (single-node payload)")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("ts")),"65800,43200","ts carried verbatim")
	quit
	;
tEnvelopeReqCarriesDenied(pass,fail)	;@TEST "schema-v1: a req carries `denied`, NOT `result_kind` (allOf discriminator)"
	new rec,opt,line,t
	kill rec
	set rec("direction")="req",rec("call_id")="500-123-8",rec("station")="500",rec("seq")=8
	set rec("rpc")="XUS SIGNON SETUP",rec("denied")=1,rec("payload")="param1"_$char(13)_"param2"
	set line=$$envelope^VSLS3(.rec,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("denied")),1,"req carries denied=1 (drives rpc_denied)")
	do eq^STDASSERT(.pass,.fail,$data(t("result_kind")),0,"req does NOT carry result_kind")
	quit
	;
tEnvelopeRespCarriesResultKind(pass,fail)	;@TEST "schema-v1: a resp carries `result_kind`, NOT `denied` (allOf discriminator)"
	new rec,opt,line,t
	do resp(.rec,"scalar value",9)
	set line=$$envelope^VSLS3(.rec,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("result_kind")),"scalar","resp carries result_kind")
	do eq^STDASSERT(.pass,.fail,$data(t("denied")),0,"resp does NOT carry denied")
	quit
	;
tEnvelopeNoTrailingNewline(pass,fail)	;@TEST "the envelope is one LDJSON line: no embedded/trailing newline (flush adds $C(10))"
	new rec,opt,line
	do resp(.rec,"plain",1)
	set line=$$envelope^VSLS3(.rec,.opt)
	do eq^STDASSERT(.pass,.fail,$extract(line,1),"{","line opens with {")
	do eq^STDASSERT(.pass,.fail,$extract(line,$length(line)),"}","line closes with } — no trailing newline")
	do eq^STDASSERT(.pass,.fail,$length(line,$char(10)),1,"no embedded newline in the line itself")
	quit
	;
tEnvelopeBase64RoundTrip(pass,fail)	;@TEST "base64 switch: payload is base64; decode is byte-exact (guaranteed for arbitrary bytes)"
	new rec,opt,line,t,b64
	do resp(.rec,$$specials(),9)
	set opt("base64")=1
	set line=$$envelope^VSLS3(.rec,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("payload_encoding")),"base64","payload_encoding=base64 when switched on")
	set b64=$$valueOf^STDJSON(t("payload"))
	do eq^STDASSERT(.pass,.fail,$$decode^STDB64(b64),$$specials(),"base64 payload decodes byte-exact")
	quit
	;
tEnvelopeHasNoHashField(pass,fail)	;@TEST "the envelope carries NO payload digest field (the tap observes raw RPC; it adds no crypto)"
	new rec,opt,line,t
	do resp(.rec,$$specials(),7)
	set line=$$envelope^VSLS3(.rec,.opt)
	do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed")
	do eq^STDASSERT(.pass,.fail,$data(t("payload_sha256")),0,"no payload_sha256 member is emitted")
	quit
	;
tEnvelopeByteIdenticalDeterministic(pass,fail)	;@TEST "the same fixture frames to a byte-identical line on every call (deterministic key order)"
	new rec,opt,a,b
	do resp(.rec,$$specials(),7)
	set a=$$envelope^VSLS3(.rec,.opt)
	set b=$$envelope^VSLS3(.rec,.opt)
	do eq^STDASSERT(.pass,.fail,a,b,"STDJSON emits keys in M-collation order -> deterministic, byte-comparable across engines")
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
