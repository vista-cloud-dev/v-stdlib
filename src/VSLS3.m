VSLS3	; v-stdlib — S3 egress sink: LDJSON envelope + the §11 bucket layout.
	;
	; Phase 3 / M2 of the RPC+HL7 -> S3 traffic tap (spec §9/§11/§12). VSLS3 is
	; the `v` wrapper over the `m` S3 client (STDS3/STDSIGV4): it frames one
	; verbatim captured record as a single LDJSON line carrying the RAW payload
	; (escaped-inline, lossless and greppable — base64 a per-stream switch), and
	; it PUTs/GETs objects under the per-station key layout. The envelope is the
	; ENTIRE format decision (§9): a thin, non-interpretive header (ts, proto,
	; dir, station, seq, conn, len, hash) + the payload. **No parsing, typing, or
	; structuring of the traffic happens here** — the only operations are
	; content-preserving (copy -> envelope -> ship). Fidelity is anchored by a
	; per-record sha256 over the RAW bytes, which VSLTAPFC re-checks downstream.
	;
	; *** Layer: v (above the m/v waterline). It consumes `m` DOWN only —
	; STDJSON (the public node->text encoder, so JSON escaping is never hand-
	; rolled), STDCRYPTO (sha256), STDB64 (the base64 switch), STDDATE (the day
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
	;   $$envelope(rec,proto,dir,station,seq,opt)  one LDJSON line (raw verbatim)
	;   $$key(station,proto,seq,ymd)               traffic/<st>/<proto>/Y/M/D/<seq>.ndjson
	;   $$offWindowsKey(station,ymd)               traffic/<st>/_offwindows/Y/M/D.json
	;   $$fidelityKey(station,ymd)                 traffic/<st>/_fidelity/Y/M/D.json
	;   $$ctx(ctx,opt)                             build the S3 ctx+opt from the seam -> bucket
	;   $$ship(ctx,bucket,key,body,opt,resp)       PUT one object (status; egress)
	;   $$readback(ctx,bucket,key,resp)            GET one object (status; egress)
	;   $$drain(res)                               flush the ^XTMP ring -> ship -> trim
	;
	quit
	;
	; ---------- the LDJSON envelope (spec §9) ----------
	;
envelope(rec,proto,dir,station,seq,opt)	; Frame one verbatim record as a single LDJSON line.
	; doc: @param rec      byte-string  the verbatim captured payload (no transform — D-1)
	; doc: @param proto    string  protocol tag ("rpc"/"hl7")
	; doc: @param dir      string  direction ("req"/"resp"/"")
	; doc: @param station  string  the originating station number (the §11 partition)
	; doc: @param seq      numeric the capture sequence number
	; doc: @param opt      array   by-ref: opt("ts")/opt("conn")/opt("base64")
	; doc: @returns        string  one JSON object line, no trailing newline
	; doc: The object is assembled as a STDJSON node and serialised by the PUBLIC
	; doc: $$encode^STDJSON — so the payload's JSON string-escaping is lossless
	; doc: and never hand-rolled. Keys emit in M collation order (deterministic,
	; doc: so fixtures byte-compare). The hash anchors the RAW bytes (§7).
	; doc: INLINE is byte-faithful and greppable, and round-trips exactly under
	; doc: byte mode (one M char == one byte); for a payload carrying high bytes
	; doc: (0x80-0xFF, non-UTF-8) the inline line is byte-lossless but not strictly
	; doc: conformant UTF-8 JSON — set opt("base64") for guaranteed-conformant
	; doc: output on binary streams (the §9 per-stream switch).
	new env,enc,pl
	set enc=$select(+$get(opt("base64")):"base64",1:"inline")
	set pl=$select(enc="base64":$$encode^STDB64($get(rec)),1:$get(rec))
	set env="o"
	set env("ts")="s:"_$get(opt("ts"),$horolog)
	set env("proto")="s:"_$get(proto)
	set env("dir")="s:"_$get(dir)
	set env("station")="s:"_$get(station)
	set env("conn")="s:"_$get(opt("conn"))
	set env("seq")="n:"_(+$get(seq))
	set env("len")="n:"_$length($get(rec))
	set env("hash")="s:"_$$sha256^STDCRYPTO($get(rec))
	set env("enc")="s:"_enc
	set env("payload")="s:"_pl
	quit $$encode^STDJSON(.env)
	;
	; ---------- the §11 bucket / object key layout ----------
	;
key(station,proto,seq,ymd)	; The object key for one traffic stream: traffic/<st>/<proto>/Y/M/D/<seq>.ndjson.
	; doc: @param station  string  the station partition
	; doc: @param proto    string  protocol tag ("rpc"/"hl7")
	; doc: @param seq      numeric the capture sequence number
	; doc: @param ymd      string  YYYYMMDD day partition (default: today)
	; doc: @returns        string  the S3 object key
	new d
	set d=$get(ymd) if d="" set d=$$today()
	quit "traffic/"_station_"/"_proto_"/"_$$ymdPath(d)_"/"_(+seq)_".ndjson"
	;
offWindowsKey(station,ymd)	; The per-day _offwindows manifest key (explicit tap-off windows, §11).
	; doc: @param station  string  the station partition
	; doc: @param ymd      string  YYYYMMDD day partition (default: today)
	; doc: @returns        string  the S3 object key
	new d
	set d=$get(ymd) if d="" set d=$$today()
	quit "traffic/"_station_"/_offwindows/"_$$ymdPath(d)_".json"
	;
fidelityKey(station,ymd)	; The per-day _fidelity manifest key (periodic VSLTAPFC results, §11).
	; doc: @param station  string  the station partition
	; doc: @param ymd      string  YYYYMMDD day partition (default: today)
	; doc: @returns        string  the S3 object key
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
	set opt("contentType")=$get(opt("contentType"),"application/x-ndjson")
	quit $$putObject^STDS3(.ctx,bucket,key,$get(body),.opt,.resp)
	;
readback(ctx,bucket,key,resp)	; GET one object back from S3 / the S3-equivalent via STDS3.
	; doc: @param ctx     array  the credential context (from $$ctx), by-ref
	; doc: @param bucket  string the source bucket
	; doc: @param key     string the object key
	; doc: @param resp    array  OUT by-ref: resp("body") holds the bytes on 200
	; doc: @returns       int    HTTP status (200 ok); 0 on transport failure
	; doc: The fidelity-harness read leg (spec §15.2 step 4): read the shipped
	; doc: object back and compare byte-for-byte (VSLTAPFC).
	quit $$getObject^STDS3(.ctx,bucket,key,.resp)
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
	new ctx,opt,bucket,station,proto,h,t,seq,rec,body,line,n,last,key,sc
	kill res
	set res("shipped")=0
	; consumer-gate + auto-failover (the Phase-2 safety reflexes) — fail-safe-OFF.
	if '$$enabled^VSLTAP() quit 0
	set h=$$head^VSLTAP(),t=$$tail^VSLTAP()
	if h'>t quit 0
	set bucket=$$ctx(.ctx,.opt)
	set station=$$cfg^VSLTAP("s3station","")
	set proto=$$cfg^VSLTAP("s3proto","rpc")
	; assemble the batch: one LDJSON line per retained record, in seq order. The
	; ring (tail,head] is contiguous (append +1's head; only drainTo/trim KILL,
	; from the tail up), so every seq in range is present — ship them ALL,
	; including a genuinely-empty captured record, so nothing is silently dropped.
	set body="",n=0,last=0
	for seq=t+1:1:h do
	. set rec=$$read^VSLTAP(seq)
	. set line=$$envelope(rec,proto,$$cfg^VSLTAP("s3dir",""),station,seq,.opt)
	. set body=body_line_$char(10),n=n+1,last=seq
	if 'n quit 0
	set key=$$key(station,proto,last)
	set sc=$$shipBatch(.ctx,bucket,key,body,.opt,.res)
	set res("key")=key,res("body")=body,res("status")=sc
	; ship failed -> leave the ring intact for the next flush tick (no trim).
	if sc'=200 quit 0
	do drainTo^VSLTAP(h)
	set res("shipped")=n
	quit n
	;
shipBatch(ctx,bucket,key,body,opt,resp)	; (private) ship one batch object; honour the capture-sink test seam.
	; doc: The §6.2-style injected seam: with ^VSLTAP("cfg","s3sink")="capture"
	; doc: the batch is returned in `res` (no real PUT) so the drain logic is
	; doc: provable on a bare engine; otherwise it PUTs via the STDS3 monopoly.
	if $$cfg^VSLTAP("s3sink","")="capture" quit 200
	quit $$ship(.ctx,bucket,key,$get(body),.opt,.resp)
