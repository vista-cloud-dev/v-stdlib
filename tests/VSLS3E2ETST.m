VSLS3E2ETST	; v-stdlib — end-to-end round-trip fidelity harness (the M2 exit gate).
	; m-lint: disable-file=M-MOD-024
	; M-MOD-024 false positive: resp/listing are populated by reference by STDS3.
	;
	; Phase 3 / M2, stage 3.4 (spec §15.2). The executable proof of FULL FIDELITY:
	;   generate a deterministic RPC corpus (edge cases) -> drive it into the tap
	;   ring -> VSLS3 $$drain ships LDJSON to the S3-equivalent (MinIO) -> read the
	;   object back -> VSLTAPFC reconciles every record BYTE-FOR-BYTE (present once,
	;   in seq, sha256-matched, no unaccounted drop).
	;
	; *** INTEGRATION suite — needs LIVE engine HTTP egress to a MinIO/LocalStack
	; sink (endpoint override, no code change). It is NOT in `make ci` / `make
	; test`; run it via `make test-s3` once the egress blockers are resolved:
	;   - G-HTTP-YDB: m-test-engine has no stdhttp/libcurl callout — bake
	;     stdhttp.so+libcurl+ydb_xc_stdhttp into the image (mirror the B1 crypto bake).
	;   - G-HTTP-IRIS-GET: STDHTTP %Net fails signed bodyless GET/HEAD/DELETE; PUT works.
	; Until then the READ-BACK leg (step 4) cannot run; the PUT leg (live ship) is
	; provable on IRIS today (Phase-1 proved live signed PUT->MinIO=200). The
	; capture->drain->envelope->trim core is fully proven on a bare engine by
	; VSLS3TST / VSLTAPFCTST / VSLS3DRAINTST.
	;
	; Run (after egress is wired), MinIO reachable as in m-stdlib's s3-testbed:
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLS3E2ETST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tRoundTripByteExact(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
cfg()	; (private) configure the tap to ship to the MinIO testbed (path-style endpoint).
	; The same MinIO the m-stdlib s3-testbed stands up (reachable from inside the
	; engine container at http://m-s3-minio:9000).
	kill ^VSLTAP,^XTMP("VSLTAP")
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","s3accesskey")="minioadmin"
	set ^VSLTAP("cfg","s3secretkey")="minioadmin"
	set ^VSLTAP("cfg","s3region")="us-east-1"
	set ^VSLTAP("cfg","s3endpoint")="http://m-s3-minio:9000"
	; the bucket the s3-testbed stands up (scripts/s3-testbed.sh BUCKET default,
	; same one m-stdlib's STDS3MINIOTST uses) — a real S3 deployment points this
	; at the production traffic bucket with no code change.
	set ^VSLTAP("cfg","s3bucket")="vista-test-logs"
	set ^VSLTAP("cfg","s3station")="500"
	set ^VSLTAP("cfg","s3proto")="rpc"
	quit
	;
corpus(c)	; (private) a deterministic RPC corpus spanning the §15.2 edge cases.
	; doc: @param c  array  OUT by-ref: c(seq) = the verbatim generated record
	kill c
	set c(1)="ORWPT ID INFO"_$char(1)_"500;DPT(0)"      ; $C(1)-delimited params
	set c(2)="literal-arg"                                ; a plain literal
	set c(3)="list"_$char(1)_"a"_$char(1)_"b"_$char(1)_"c" ; list params
	set c(4)="ref^DPT(500,0)"                             ; a reference param
	set c(5)="ctl"_$char(0)_$char(13,10)_$char(9)_$char(2) ; control bytes incl NUL
	set c(6)=$$big()                                      ; a large (multi-KB) result
	set c(7)="error: -1^no such patient"                  ; an error case
	quit
	;
big()	; (private) a multi-KB record (volume edge case).
	new s,i
	set s=""
	for i=1:1:200 set s=s_"row"_i_$char(1)_"field-a"_$char(1)_"field-b"_$char(13,10)
	quit s
	;
tRoundTripByteExact(pass,fail)	;@TEST "round-trip: every generated RPC lands byte-exact in the S3-equivalent"
	new c,seq,x,res,n,bucket,ctx,opt,sc,resp,key,body,line,envs,i
	do cfg()
	do corpus(.c)
	; drive the corpus into the tap ring (the tee's role)
	set seq=""
	for  do drive(.seq,.c) quit:seq=""
	; ship: drain the ring to MinIO (a real signed PUT)
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,res("status"),200,"live PUT to the S3-equivalent returns 200")
	do eq^STDASSERT(.pass,.fail,n,7,"all 7 corpus records shipped in one batch")
	; read back: GET the shipped object from MinIO
	set bucket=$$ctx^VSLS3(.ctx,.opt),key=res("key")
	set sc=$$readback^VSLS3(.ctx,bucket,key,.opt,.resp)
	do eq^STDASSERT(.pass,.fail,sc,200,"read-back GET returns 200 (needs G-HTTP-* resolved)")
	set body=$get(resp("body"))
	; reconcile: split the read-back NDJSON into per-record envelopes by seq
	kill envs
	for i=1:1:$length(body,$char(10)) do
	. set line=$piece(body,$char(10),i)
	. if line="" quit
	. set envs($$seqOf(line))=line
	do true^STDASSERT(.pass,.fail,$$reconcile^VSLTAPFC(.c,.envs,.res),"byte-for-byte round-trip is faithful")
	do eq^STDASSERT(.pass,.fail,res("matched"),7,"all 7 records matched on read-back")
	do eq^STDASSERT(.pass,.fail,res("mismatch")+res("missing")+res("extra"),0,"no drift, no drop, no extra")
	; persist the run so the live console (VWEBT) can read the last fidelity result —
	; the production caller is the periodic comparator; here the harness stands in.
	do persist^VSLTAPFC(.res)
	do true^STDASSERT(.pass,.fail,$$lastFidelity^VSLTAPFC()'="","the round-trip result is persisted for the console")
	quit
	;
drive(seq,c)	; (private) append the next corpus record to the ring (the tee's role).
	new x
	set seq=$order(c(seq))
	if seq="" quit
	set x=$$append^VSLTAP(c(seq))
	quit
	;
seqOf(line)	; (private) the seq field of one envelope line.
	new t
	if '$$parse^STDJSON(line,.t) quit ""
	quit $$valueOf^STDJSON($get(t("seq")))
