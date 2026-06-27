VSLRPCWRAPTST	; v-stdlib — VSLRPCWRAP (the XWB broker-dispatch wrap glue) test suite.
	; Phase 6 / FU-5 (5B.1). The two fenced side-calls the broker CALLP^XWBBRK
	; splice invokes. The live broker is simulated by setting its process-scope
	; vars (XWB(2,"CAPI"), XWB(3,"P",*), XWBSEC, XWBP, XWBPTYPE, DUZ, XWBTIP,
	; XWBTSKT) as locals, then calling req/resp the way the splice will. Proves:
	; a dir=req per RPC carrying the params + FU-18 context + denied flag; a
	; dir=resp correlated by call_id; result classification by XWBPTYPE incl. the
	; FU-17 single MERGE for a GLOBAL ARRAY; and — the keystone — the caller's
	; naked indicator + $TEST survive the side-call (the FU-4 fence). Bare engine,
	; no VistA, no egress:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLRPCWRAPTST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLRPCWRAPTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tReqEmitsRequestRecord(.pass,.fail)
	do tReqDeniedFlag(.pass,.fail)
	do tReqRespCorrelation(.pass,.fail)
	do tRespScalarResult(.pass,.fail)
	do tRespGlobalMergeSingleOp(.pass,.fail)
	do tCounterBumpsPerRpc(.pass,.fail)
	do tNakedRefPreserved(.pass,.fail)
	do tGatedOffNoCapture(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
reset()	; (private) wipe tap state + the broker-sim vars + the $J correlation locals.
	kill ^VSLTAP,^XTMP("VSLTAP"),XWB,XWBP,XWBPTYPE,XWBSEC,DUZ,XWBTIP,XWBTSKT,VSLWCC,VSLWCID
	set ^VSLTAP("cfg","s3station")="500"
	quit
	;
broker()	; (private) seed a typical successful RPC's broker vars (the live wrap reads these).
	set XWB(2,"CAPI")="ORWPT LIST ALL"
	set XWB(3,"P",1)="ALPHA",XWB(3,"P",2)="9",XWB(3,"P",3)=""
	set XWBSEC=""
	set DUZ=168,XWBTIP="10.1.2.3",XWBTSKT=51001
	set XWBP="patient list result",XWBPTYPE=1
	quit
	;
tReqEmitsRequestRecord(pass,fail)	;@TEST "req: one dir=req record per RPC carrying rpc/params/context; denied=0 when allowed"
	new h,hdr
	do reset(),broker()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	do req^VSLRPCWRAP()
	set h=$$head^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"the request side-call captured one record")
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h,.hdr),"the v2 header parses")
	do eq^STDASSERT(.pass,.fail,hdr("direction"),"req","direction=req")
	do eq^STDASSERT(.pass,.fail,hdr("rpc"),"ORWPT LIST ALL","rpc name from the XWB CAPI node")
	do eq^STDASSERT(.pass,.fail,hdr("denied"),0,"denied=0 (CHKPRMIT did not set XWBSEC)")
	do eq^STDASSERT(.pass,.fail,hdr("duz"),168,"duz from DUZ (FU-18)")
	do eq^STDASSERT(.pass,.fail,hdr("client"),"10.1.2.3:51001","client = XWBTIP:XWBTSKT (FU-18)")
	do eq^STDASSERT(.pass,.fail,$$chunk^VSLTAP(h,1),"ALPHA"_$char(1)_"9"_$char(1)_"","params $C(1)-joined verbatim from the broker input nodes")
	do true^STDASSERT(.pass,.fail,hdr("call_id")["500-","call_id carries the station prefix")
	quit
	;
tReqDeniedFlag(pass,fail)	;@TEST "req: a CHKPRMIT denial (XWBSEC set) marks the request denied=1 (drives rpc_denied)"
	new h,hdr
	do reset(),broker()
	set XWBSEC="You do not have permission"
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	do req^VSLRPCWRAP()
	set h=$$head^VSLTAP()
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h,.hdr),"header parses")
	do eq^STDASSERT(.pass,.fail,hdr("denied"),1,"denied=1 when XWBSEC is set at CALLP:152")
	quit
	;
tReqRespCorrelation(pass,fail)	;@TEST "FU-14: req then resp are two records sharing one call_id (resp reuses the counter)"
	new h1,h2,a,b
	do reset(),broker()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	do req^VSLRPCWRAP()
	set h1=$$head^VSLTAP()
	do resp^VSLRPCWRAP()
	set h2=$$head^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),2,"two records (req + resp)")
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h1,.a),"req header parses")
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h2,.b),"resp header parses")
	do eq^STDASSERT(.pass,.fail,a("direction"),"req","first is the request")
	do eq^STDASSERT(.pass,.fail,b("direction"),"resp","second is the response")
	do eq^STDASSERT(.pass,.fail,a("call_id"),b("call_id"),"req and resp share the same call_id")
	quit
	;
tRespScalarResult(pass,fail)	;@TEST "resp: XWBPTYPE=1 -> result_kind=scalar, payload = the verbatim XWBP value"
	new h,hdr
	do reset(),broker()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	do req^VSLRPCWRAP()
	do resp^VSLRPCWRAP()
	set h=$$head^VSLTAP()
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h,.hdr),"resp header parses")
	do eq^STDASSERT(.pass,.fail,hdr("result_kind"),"scalar","XWBPTYPE=1 -> scalar")
	do eq^STDASSERT(.pass,.fail,$$chunk^VSLTAP(h,1),"patient list result","scalar payload = XWBP byte-verbatim")
	quit
	;
tRespGlobalMergeSingleOp(pass,fail)	;@TEST "FU-17: XWBPTYPE=4 (global array) -> one MERGE snapshot byte-equals the source subtree"
	new h,hdr,r
	do reset(),broker()
	; a global-array result: XWBP holds the closed-root global ref string (FU-16(c))
	set r=$name(^TMP($job,"VSLWG"))
	kill @r
	set @r@("a")="alpha",@r@("b",1)="beta"_$char(1)_"x",@r@("c","d")="deep"
	set XWBP=r,XWBPTYPE=4
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	do req^VSLRPCWRAP()
	do resp^VSLRPCWRAP()
	set h=$$head^VSLTAP()
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h,.hdr),"resp header parses")
	do eq^STDASSERT(.pass,.fail,hdr("result_kind"),"global","XWBPTYPE=4 -> global")
	do eq^STDASSERT(.pass,.fail,$get(^XTMP("VSLTAP","data",h,"g","a")),"alpha","MERGE snapshot node a byte-equals source")
	do eq^STDASSERT(.pass,.fail,$get(^XTMP("VSLTAP","data",h,"g","b",1)),"beta"_$char(1)_"x","snapshot node b,1 (control byte) byte-equals source")
	do eq^STDASSERT(.pass,.fail,$get(^XTMP("VSLTAP","data",h,"g","c","d")),"deep","deep snapshot node byte-equals source")
	quit
	;
tCounterBumpsPerRpc(pass,fail)	;@TEST "FU-14: the call counter bumps once per request -> distinct call_ids across RPCs"
	new h1,h2,a,b
	do reset(),broker()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	do req^VSLRPCWRAP()
	set h1=$$head^VSLTAP()
	do req^VSLRPCWRAP()
	set h2=$$head^VSLTAP()
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h1,.a),"first req header parses")
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h2,.b),"second req header parses")
	do true^STDASSERT(.pass,.fail,a("call_id")'=b("call_id"),"two RPCs get distinct call_ids (counter advanced)")
	quit
	;
tNakedRefPreserved(pass,fail)	;@TEST "FU-4: the wrap leaves the broker's naked indicator under its own global, not ^XTMP"
	new landed,leaked
	do reset(),broker()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	; the broker's last full reference BEFORE the side-call
	set ^TMP("VSLWRT",$job,1,2,3)="seed"
	do req^VSLRPCWRAP()
	; ONE naked reference — must resolve under the seed global if the fence held
	set ^(9)="probe"
	set landed=$data(^TMP("VSLWRT",$job,1,2,9))
	set leaked=$data(^XTMP("VSLTAP","data",9))
	do true^STDASSERT(.pass,.fail,$$size^VSLTAP()=1,"sanity: the wrap captured one record")
	do eq^STDASSERT(.pass,.fail,landed,1,"the broker's naked reference still resolves under its own global")
	do eq^STDASSERT(.pass,.fail,leaked,0,"the naked reference did NOT leak into the tap's ^XTMP tree")
	quit
	;
tGatedOffNoCapture(pass,fail)	;@TEST "the wrap is gated: kill-switch OFF -> nothing captured, and the naked indicator is still preserved"
	new landed
	do reset(),broker()
	do off^VSLTAP()
	set ^TMP("VSLWRT",$job,1,2,3)="seed"
	do req^VSLRPCWRAP()
	set ^(9)="probe"
	set landed=$data(^TMP("VSLWRT",$job,1,2,9))
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"kill-switch OFF -> the wrap captures nothing")
	do eq^STDASSERT(.pass,.fail,landed,1,"the naked indicator is preserved even on the gated-off path")
	quit
