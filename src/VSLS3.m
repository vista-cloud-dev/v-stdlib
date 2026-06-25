VSLS3	; v-stdlib — S3 egress sink: LDJSON envelope + the §11 bucket layout.
	; doc: @exrun bare
	; m-lint: disable-file=M-MOD-024
	; M-MOD-024 false positive: `hdr` is populated by reference by $$hdr^VSLTAP in
	; resolveRec; the analyser cannot see through the by-ref call, so it reads it as
	; "read before defined".
	; m-lint: disable-file=M-MOD-036
	; M-MOD-036: gSerialize walks a v2 "g" MERGE snapshot via @root/@nref indirection.
	; The refs are internal closed ^XTMP("VSLTAP",…) names built by $name here (drain-side,
	; off the in-path), never external input — the indirection is the deferred FU-17 serialize.
	;
	; Phase 3 / M2 of the RPC+HL7 -> S3 traffic tap (spec §9/§11/§12). VSLS3 is
	; the `v` wrapper over the `m` S3 client (STDS3/STDSIGV4): it frames one
	; verbatim captured record as a single LDJSON line carrying the RAW payload
	; (escaped-inline, lossless and greppable — base64 a per-stream switch), and
	; it PUTs/GETs objects under the per-station key layout. The envelope is the
	; ENTIRE format decision (§9): a thin, non-interpretive header (ts, proto,
	; dir, station, seq, conn, len) + the RAW payload. **No parsing, typing, or
	; structuring of the traffic happens here** — the only operations are
	; content-preserving (copy -> envelope -> ship). NO hashing/integrity field is
	; added: RPC traffic is plain ASCII the tap only OBSERVES, and fidelity is
	; proven downstream by BYTE-EQUALITY against the captured source (VSLTAPFC), not
	; by an embedded digest. In-transit/at-rest integrity is the storage layer's
	; (S3's) job, not the tap's.
	;
	; *** Layer: v (above the m/v waterline). It consumes `m` DOWN only —
	; STDJSON (the public node->text encoder, so JSON escaping is never hand-
	; rolled), STDB64 (the base64 switch), STDDATE (the day
	; partition), and STDS3/STDSIGV4 (the egress transport monopoly, the only
	; way to reach S3). It never inverts the dependency. The S3 credentials /
	; endpoint / bucket / station are a CONFIG SEAM read from ^VSLTAP("cfg",…)
	; (the same control state the Phase-2 core uses), so a deployment points the
	; sink at real S3 or a local S3-equivalent (MinIO/LocalStack) with no code
	; change — just the `endpoint` override (§15.1).
	;
	; The live PUT/GET round-trip needs engine HTTP egress (G-HTTP-YDB /
	; G-HTTP-IRIS-GET); the envelope/key/config core here is egress-INDEPENDENT
	; and runs on a bare engine. The round-trip is proven in the integration
	; harness against a MinIO sink (spec §15.2).
	;
	; Public API:
	;   $$envelope(.rec,.opt)                      one schema-v1 LDJSON line from a field array
	;   $$gSerialize(seq)                          serialize a v2 "g" MERGE subtree (FU-17, drain-side)
	;   $$key(station,proto,seq,ymd)               traffic/<st>/<proto>/Y/M/D/<seq>.ndjson
	;   $$offWindowsKey(station,ymd)               traffic/<st>/_offwindows/Y/M/D.json
	;   $$fidelityKey(station,ymd)                 traffic/<st>/_fidelity/Y/M/D.json
	;   $$ctx(ctx,opt)                             build the S3 ctx+opt from the seam -> bucket
	;   $$ship(ctx,bucket,key,body,opt,resp)       PUT one object (status; egress)
	;   $$readback(ctx,bucket,key,opt,resp)        GET one object (status; egress)
	;   $$list(ctx,bucket,prefix,opt,listing)      LIST object keys under a prefix (status; egress)
	;   $$drain(res)                               flush the ^XTMP ring -> ship -> trim
	;
	quit
	;
	; ---------- the LDJSON envelope (spec §9) ----------
	;
envelope(rec,opt)	; Frame one captured record as a single schema-v1 LDJSON line.
	; doc: @param rec  array  by-ref schema-v1 field array; rec("payload") = the RAW bytes,
	; doc:                    plus event_id/call_id/ts/protocol/direction/station/seq/rpc/
	; doc:                    duz/job/client[/denied|result_kind]/chunk_count/payload_encoding
	; doc: @param opt  array  by-ref: opt("ts") (default ts) / opt("base64") (default encoding)
	; doc: @returns    string one schema-v1 JSON object line, no trailing newline
	; doc: The object is assembled as a STDJSON node and serialised by the PUBLIC
	; doc: $$encode^STDJSON — so the payload's JSON string-escaping is lossless and never
	; doc: hand-rolled. Keys emit in M collation order (deterministic, so fixtures
	; doc: byte-compare). ONE shape serves req and resp (`direction` discriminates): a req
	; doc: carries `denied`, a resp carries `result_kind`. wire_len is computed HERE over
	; doc: the RAW bytes; NO payload digest is emitted (fidelity is proven by byte-equality
	; doc: downstream in VSLTAPFC, not an embedded hash). RAW is byte-faithful + greppable and round-trips
	; doc: under byte mode (1 M char == 1 byte); set opt("base64") (the §9 per-stream switch,
	; doc: FU-1 default) for guaranteed-conformant UTF-8 output on binary streams.
	; doc: Full contract: docs/design/s3tap-envelope-schema-lock.md §3 (schema v1).
	; doc: @example   new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="hello world" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"the line is well-formed JSON") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("payload")),"hello world","payload round-trips byte-exact")
	; doc: @example   new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="x" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("event_id")),"500-1-7:resp","event_id = call_id ':' direction")
	; doc: @example   new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="hello world" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("wire_len")),11,"wire_len = byte length of the RAW payload")
	; doc: @example   new rec,opt,line,t set rec("direction")="req",rec("call_id")="500-1-8",rec("seq")=8,rec("denied")=1,rec("payload")="p" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("denied")),1,"a req carries denied, not result_kind")
	; doc: @example   new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-9",rec("seq")=9,rec("payload")="v" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("result_kind")),"scalar","a resp carries result_kind, not denied")
	; doc: @example   new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")=("a"_$char(9)_"b"_""""_"q") set opt("base64")=1 set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$decode^STDB64($$valueOf^STDJSON(t("payload"))),"a"_$char(9)_"b"_""""_"q","base64 switch decodes byte-exact")
	; doc: @example   new rec,opt,a,b set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="hello world" set a=$$envelope^VSLS3(.rec,.opt),b=$$envelope^VSLS3(.rec,.opt) do eq^STDASSERT(.pass,.fail,a,b,"deterministic: same fixture frames byte-identical (M-collation key order)")
	new env,enc,pl,raw,dir,wl,cc
	set raw=$get(rec("payload"))
	set dir=$get(rec("direction"))
	set enc=$get(rec("payload_encoding"))
	if enc="" set enc=$select(+$get(opt("base64")):"base64",1:"raw")
	set pl=$select(enc="base64":$$encode^STDB64(raw),1:raw)
	set wl=$length(raw)
	set cc=+$get(rec("chunk_count")) if cc<1 set cc=1
	set env="o"
	set env("schema_version")="n:"_(+$get(rec("schema_version"),1))
	set env("event_id")="s:"_$$eventId(.rec)
	set env("call_id")="s:"_$get(rec("call_id"))
	set env("ts")="s:"_$get(rec("ts"),$get(opt("ts"),$horolog))
	set env("protocol")="s:"_$get(rec("protocol"),"rpc")
	set env("direction")="s:"_dir
	set env("station")="s:"_$get(rec("station"))
	set env("seq")="n:"_(+$get(rec("seq")))
	set env("rpc")="s:"_$get(rec("rpc"))
	set env("duz")="s:"_$get(rec("duz"))
	set env("job")="n:"_(+$get(rec("job")))
	set env("client")="s:"_$get(rec("client"))
	if dir="req" set env("denied")="n:"_(+$get(rec("denied")))
	if dir="resp" set env("result_kind")="s:"_$get(rec("result_kind"),"scalar")
	set env("wire_len")="n:"_wl
	set env("chunk_count")="n:"_cc
	set env("payload_encoding")="s:"_enc
	set env("payload")="s:"_pl
	quit $$encode^STDJSON(.env)
	;
eventId(rec)	; (private) event_id = the explicit override, else call_id ":" direction (schema-lock §2).
	if $get(rec("event_id"))'="" quit rec("event_id")
	quit $get(rec("call_id"))_":"_$get(rec("direction"))
	;
gSerialize(seq)	; Serialize a v2 GLOBAL-ARRAY MERGE snapshot (^...,"g") to a deterministic, lossless blob.
	; doc: @param seq  numeric  the ring sequence of a v2 record whose result_kind="global"
	; doc: @returns    byte-string  one node per line: $$encode^STDJSON of {s:<subscripts>,v:<value>}
	; doc: FU-17 defers ALL of a global result's serialize/chunk/hash to the drain (off the
	; doc: in-path; capture did one MERGE). The $QUERY walk is in M-collation order so the
	; doc: blob is deterministic across engines, and STDJSON escaping makes each node lossless
	; doc: for arbitrary bytes (the blob is then base64'd in the envelope). The exact wire form
	; doc: (vs the broker's SNDDATA encoding) is FU-11's concern; here it need only be a
	; doc: deterministic, byte-faithful representation the §15.2 round-trip can prove.
	; doc: @example   new save,b merge save=^XTMP("VSLTAP","data",991,"g") kill ^XTMP("VSLTAP","data",991,"g") set ^XTMP("VSLTAP","data",991,"g","DPT",1)="ONE",^XTMP("VSLTAP","data",991,"g","DPT",2)="TWO" set b=$$gSerialize^VSLS3(991) kill ^XTMP("VSLTAP","data",991,"g") merge ^XTMP("VSLTAP","data",991,"g")=save do eq^STDASSERT(.pass,.fail,$length(b,$char(10)),2,"one JSON node line per descendant of the g MERGE snapshot")
	new root,pfx,nref,out,sub
	set root=$name(^XTMP("VSLTAP","data",+$get(seq),"g"))
	; the descendant prefix is the root WITHOUT its trailing ")": "^...,""g""" — so a
	; sibling subtree ("hc"/"p") or the next seq stops the walk, but every "g" descendant
	; (which begins pfx_",") is included. (Comparing against the full root would mismatch
	; legitimate descendants, since root ends in ")" and descendants continue with ",".)
	set pfx=$extract(root,1,$length(root)-1)
	set out=""
	; the snapshot root may itself carry a value (MERGE copies the source root value).
	if $data(@root)#10 set out=$$gNode("",$get(@root))
	set nref=root
	for  do gStep(.nref,pfx,.out) quit:nref=""
	quit out
	;
gStep(nref,pfx,out)	; (private) advance to the next "g" descendant; append its serialized node ("" nref stops the walk).
	set nref=$query(@nref)
	if nref="" quit
	; left the "g" subtree (next sibling subtree / next seq) -> stop the walk.
	if $extract(nref,1,$length(pfx)+1)'=(pfx_",") set nref="" quit
	new sub
	set sub=$extract(nref,$length(pfx)+2,$length(nref)-1)
	set out=$select(out="":$$gNode(sub,$get(@nref)),1:out_$char(10)_$$gNode(sub,$get(@nref)))
	quit
	;
gNode(sub,val)	; (private) one serialized global-subtree node as a JSON object {s:subscripts,v:value}.
	new n
	set n="o"
	set n("s")="s:"_sub
	set n("v")="s:"_val
	quit $$encode^STDJSON(.n)
	;
	; ---------- the §11 bucket / object key layout ----------
	;
key(station,proto,seq,ymd)	; The object key for one traffic stream: traffic/<st>/<proto>/Y/M/D/<seq>.ndjson.
	; doc: @param station  string  the station partition
	; doc: @param proto    string  protocol tag ("rpc"/"hl7")
	; doc: @param seq      numeric the capture sequence number
	; doc: @param ymd      string  YYYYMMDD day partition (default: today)
	; doc: @returns        string  the S3 object key
	; doc: @example   write $$key^VSLS3("500","rpc",42,"20260619")  ; "traffic/500/rpc/2026/06/19/42.ndjson"
	; doc: @example   write $$key^VSLS3("442","hl7",1,"20260101")  ; "traffic/442/hl7/2026/01/01/1.ndjson"
	new d
	set d=$get(ymd) if d="" set d=$$today()
	quit "traffic/"_station_"/"_proto_"/"_$$ymdPath(d)_"/"_(+seq)_".ndjson"
	;
offWindowsKey(station,ymd)	; The per-day _offwindows manifest key (explicit tap-off windows, §11).
	; doc: @param station  string  the station partition
	; doc: @param ymd      string  YYYYMMDD day partition (default: today)
	; doc: @returns        string  the S3 object key
	; doc: @example   write $$offWindowsKey^VSLS3("500","20260619")  ; "traffic/500/_offwindows/2026/06/19.json"
	new d
	set d=$get(ymd) if d="" set d=$$today()
	quit "traffic/"_station_"/_offwindows/"_$$ymdPath(d)_".json"
	;
fidelityKey(station,ymd)	; The per-day _fidelity manifest key (periodic VSLTAPFC results, §11).
	; doc: @param station  string  the station partition
	; doc: @param ymd      string  YYYYMMDD day partition (default: today)
	; doc: @returns        string  the S3 object key
	; doc: @example   write $$fidelityKey^VSLS3("500","20260619")  ; "traffic/500/_fidelity/2026/06/19.json"
	new d
	set d=$get(ymd) if d="" set d=$$today()
	quit "traffic/"_station_"/_fidelity/"_$$ymdPath(d)_".json"
	;
ymdPath(ymd)	; (private) YYYYMMDD -> "YYYY/MM/DD".
	quit $extract(ymd,1,4)_"/"_$extract(ymd,5,6)_"/"_$extract(ymd,7,8)
	;
today()	; (private) today's date as YYYYMMDD, from $H via STDDATE.
	new z,y,m,d
	set z=+$horolog-47117
	do civilFromDays^STDDATE(z,.y,.m,.d)
	quit (y*10000)+(m*100)+d_""
	;
	; ---------- the config seam (S3 ctx from ^VSLTAP) ----------
	;
ctx(ctx,opt)	; Build the S3 credential ctx + opt(endpoint) from the ^VSLTAP config seam.
	; doc: @param ctx  array  OUT by-ref: accessKey/secretKey/region/service[/sessionToken]
	; doc: @param opt  array  OUT by-ref: opt("endpoint") for path-style (MinIO/LocalStack)
	; doc: @returns    string the bucket name from the seam
	; doc: The same control state the Phase-2 core uses (^VSLTAP("cfg",…)). An
	; doc: empty endpoint -> virtual-hosted real S3; a set endpoint -> path-style
	; doc: S3-equivalent (the no-code-change testbed hook, §15.1).
	; doc: @example   new ctx,opt,b,save merge save=^VSLTAP("cfg") kill ^VSLTAP("cfg") set ^VSLTAP("cfg","s3bucket")="vista-traffic",^VSLTAP("cfg","s3endpoint")="http://m-s3-minio:9000" set b=$$ctx^VSLS3(.ctx,.opt) kill ^VSLTAP("cfg") merge ^VSLTAP("cfg")=save do eq^STDASSERT(.pass,.fail,b,"vista-traffic","bucket + endpoint read from the ^VSLTAP config seam (set-then-restore)")
	new ep,tok
	set ctx("accessKey")=$$cfg^VSLTAP("s3accesskey","")
	set ctx("secretKey")=$$cfg^VSLTAP("s3secretkey","")
	set ctx("region")=$$cfg^VSLTAP("s3region","us-east-1")
	set ctx("service")=$$cfg^VSLTAP("s3service","s3")
	set tok=$$cfg^VSLTAP("s3token","")
	if tok'="" set ctx("sessionToken")=tok
	set ep=$$cfg^VSLTAP("s3endpoint","")
	if ep'="" set opt("endpoint")=ep
	quit $$cfg^VSLTAP("s3bucket","")
	;
	; ---------- egress (the STDS3 transport monopoly; needs engine HTTP) ----------
	;
ship(ctx,bucket,key,body,opt,resp)	; PUT one object to S3 / the S3-equivalent via STDS3.
	; doc: @param ctx     array  the credential context (from $$ctx), by-ref
	; doc: @param bucket  string the target bucket
	; doc: @param key     string the object key (from $$key)
	; doc: @param body    byte-string  the LDJSON body (one or more envelope lines)
	; doc: @param opt     array  by-ref: opt("endpoint") + contentType
	; doc: @param resp    array  OUT by-ref: resp("header",*)/("error",*)
	; doc: @returns       int    HTTP status (200 ok); 0 on transport failure
	; doc: The ONLY way to reach S3 (waterline rule 3: the m S3 client is the
	; doc: transport monopoly). Runs in the SEPARATE flush process, never the
	; doc: RPC path (§4.1.3). 0 on a bare engine with no HTTP egress (G-HTTP-*).
	; doc: @illustrative  live S3/MinIO PUT over engine HTTP egress (STDS3); no side-effect-safe bare-engine example — proven in the §15.2 MinIO integration harness.
	set opt("contentType")=$get(opt("contentType"),"application/x-ndjson")
	quit $$putObject^STDS3(.ctx,bucket,key,$get(body),.opt,.resp)
	;
readback(ctx,bucket,key,opt,resp)	; GET one object back from S3 / the S3-equivalent via STDS3.
	; doc: @param ctx     array  the credential context (from $$ctx), by-ref
	; doc: @param bucket  string the source bucket
	; doc: @param key     string the object key
	; doc: @param opt     array  by-ref: opt("endpoint") — REQUIRED to reach the S3-equivalent
	; doc: @param resp    array  OUT by-ref: resp("body") holds the bytes on 200
	; doc: @returns       int    HTTP status (200 ok); 0 on transport failure
	; doc: The fidelity-harness read leg (spec §15.2 step 4): read the shipped
	; doc: object back and compare byte-for-byte (VSLTAPFC). `opt` carries the
	; doc: endpoint override (from $$ctx) so the GET reaches the same endpoint the
	; doc: PUT used — without it the read op signs+sends to real AWS, not MinIO.
	; doc: @illustrative  live S3/MinIO GET over engine HTTP egress (STDS3); the read leg of the §15.2 round-trip, not runnable on a bare engine.
	quit $$getObject^STDS3(.ctx,bucket,key,.opt,.resp)
	;
list(ctx,bucket,prefix,opt,listing)	; LIST object keys under `prefix` via STDS3 listObjectsV2.
	; doc: @param ctx      array  the credential context (from $$ctx), by-ref
	; doc: @param bucket   string the source bucket
	; doc: @param prefix   string the key prefix to list under ("" = whole bucket)
	; doc: @param opt      array  by-ref: opt("endpoint") — REQUIRED to reach the S3-equivalent
	; doc: @param listing  array  OUT by-ref: listing(1..n,"key"/"size"/"etag") + ("truncated"/"next")
	; doc: @returns        int    HTTP status (200 ok); 0 on transport failure
	; doc: The discovery leg for the periodic fidelity sampler (VSLTAPRUN
	; doc: $$fidelityNow): enumerate recently-shipped objects under the per-station
	; doc: prefix so they can be read back and integrity-verified. Same `opt`
	; doc: endpoint override as ship/readback. LIST is dual-engine-proven (STDS3MINIOTST).
	; doc: @illustrative  live S3/MinIO LIST over engine HTTP egress (STDS3 listObjectsV2); proven in STDS3MINIOTST, not on a bare engine.
	quit $$listObjectsV2^STDS3(.ctx,bucket,$get(prefix),.opt,.listing)
	;
	; ---------- the drain loop (VSLTASK-driven flush; spec §4.1.3) ----------
	;
drain(res)	; Flush the ^XTMP ring to S3 as one LDJSON batch, then trim the shipped entries.
	; doc: @param res  array  OUT by-ref: res("shipped")/("key")/("body")/("status")
	; doc: @returns    int    the number of records shipped (0 if gated/empty/failed)
	; doc: The whole egress path runs in the SEPARATE flush process (VSLTASK calls
	; doc: this) — never the RPC CPU (§4.1.3). It is consumer-gated AND auto-
	; doc: failover-aware: it ships ONLY while the Phase-2 gate is enabled, so a
	; doc: dead/slow sink or any interference signal turns it off cleanly (the gate
	; doc: records the off-window). On a 200 it self-drains the shipped seqs
	; doc: (drainTo^VSLTAP); on any other status it leaves the ring for retry.
	; doc: @example   new res,save,csave merge save=^XTMP("VSLTAP") merge csave=^VSLTAP("cfg") kill ^XTMP("VSLTAP"),^VSLTAP("cfg") set ^VSLTAP("cfg","s3sink")="capture",^VSLTAP("cfg","mode")="armed",^VSLTAP("cfg","consumer")=1,^VSLTAP("cfg","s3station")="500" set ^XTMP("VSLTAP","head")=1,^XTMP("VSLTAP","tail")=0,^XTMP("VSLTAP","data",1)="ONELINE" set n=$$drain^VSLS3(.res) kill ^XTMP("VSLTAP"),^VSLTAP("cfg") merge ^XTMP("VSLTAP")=save merge ^VSLTAP("cfg")=csave do eq^STDASSERT(.pass,.fail,n,1,"capture-sink seam drains the 1-record ring without a live PUT (status 200)")
	new ctx,opt,bucket,station,proto,h,t,seq,erec,body,line,n,last,key,sc
	kill res
	set res("shipped")=0
	; consumer-gate + auto-failover (the Phase-2 safety reflexes) — fail-safe-OFF.
	if '$$enabled^VSLTAP() quit 0
	set h=$$head^VSLTAP(),t=$$tail^VSLTAP()
	if h'>t quit 0
	set bucket=$$ctx(.ctx,.opt)
	set station=$$cfg^VSLTAP("s3station","")
	set proto=$$cfg^VSLTAP("s3proto","rpc")
	; assemble the batch: one LDJSON line per retained record, in seq order. Ship the
	; CONTIGUOUS COMMITTED PREFIX (tail,last] and STOP at the first uncommitted slot
	; ($$present=0). FU-8's atomic $INCREMENT advances head one statement before the data
	; SET, so an always-on drain (FU-9) can momentarily see head ahead of an in-flight
	; record; stopping at the gap (and trimming only to `last`, not `h`) leaves that slot
	; for the next tick instead of shipping "" and KILLing a record about to land. A
	; genuinely-empty captured record still ships ($$present is true for an empty value).
	set body="",n=0,last=t
	for seq=t+1:1:h quit:'$$present^VSLTAP(seq)  do
	. kill erec
	. do resolveRec(seq,station,proto,.erec)
	. set line=$$envelope(.erec,.opt)
	. set body=body_line_$char(10),n=n+1,last=seq
	if 'n quit 0
	set key=$$key(station,proto,last)
	set sc=$$shipBatch(.ctx,bucket,key,body,.opt,.res)
	set res("key")=key,res("body")=body,res("status")=sc
	; ship failed -> leave the ring intact for the next flush tick (no trim).
	if sc'=200 quit 0
	do drainTo^VSLTAP(last)
	set res("shipped")=n
	quit n
	;
resolveRec(seq,station,proto,erec)	; Build the schema-v1 field array for the record at `seq` (dual-mode: v2 header / v1 legacy).
	; doc: @param seq      numeric  the ring sequence
	; doc: @param station  string   the station partition (authoritative for the §11 key)
	; doc: @param proto     string   default protocol when the record carries none
	; doc: @param erec     array    OUT by-ref: the schema-v1 fields incl. erec("payload") = RAW bytes
	; doc: A v2 record (the FU-5 wrap) is framed from its 18-piece header: a GLOBAL ARRAY
	; doc: result is serialized from the "g" MERGE snapshot (FU-17) and base64'd; a scalar
	; doc: from its "p",1 chunk. A legacy v1 string record ($$append — the synthetic
	; doc: demonstrator path) ships as a plain payload under the configured direction. The
	; doc: header's schema_version keeps both readable from one ring (schema-lock §4).
	; doc: @example   new erec,save merge save=^XTMP("VSLTAP") kill ^XTMP("VSLTAP") set ^XTMP("VSLTAP","data",993)="RAWBYTES" do resolveRec^VSLS3(993,"500","rpc",.erec) kill ^XTMP("VSLTAP") merge ^XTMP("VSLTAP")=save do eq^STDASSERT(.pass,.fail,erec("payload"),"RAWBYTES","a legacy v1 record resolves to a plain payload under the station/proto key (set-then-restore)")
	new hdr
	kill erec
	if $$hdr^VSLTAP(seq,.hdr) do  quit
	. merge erec=hdr
	. set erec("seq")=seq,erec("station")=station
	. if hdr("protocol")="" set erec("protocol")=proto
	. if hdr("result_kind")="global" do  quit
	. . set erec("payload")=$$gSerialize(seq)
	. . set erec("payload_encoding")="base64"
	. . set erec("chunk_count")=1
	. set erec("payload")=$$chunk^VSLTAP(seq,1)
	. set erec("chunk_count")=+hdr("chunk_count")
	; legacy v1 string record (the synthetic demonstrator / VSLS3DRAINTST path)
	set erec("payload")=$$read^VSLTAP(seq)
	set erec("seq")=seq,erec("station")=station,erec("protocol")=proto
	set erec("direction")=$$cfg^VSLTAP("s3dir","")
	quit
	;
shipBatch(ctx,bucket,key,body,opt,resp)	; (private) ship one batch object; honour the capture-sink test seam.
	; doc: @internal
	; doc: The §6.2-style injected seam: with ^VSLTAP("cfg","s3sink")="capture"
	; doc: the batch is returned in `res` (no real PUT) so the drain logic is
	; doc: provable on a bare engine; otherwise it PUTs via the STDS3 monopoly.
	if $$cfg^VSLTAP("s3sink","")="capture" quit 200
	quit $$ship(.ctx,bucket,key,$get(body),.opt,.resp)
