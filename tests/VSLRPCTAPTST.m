VSLRPCTAPTST	; v-stdlib — VSLRPCTAP (RPC tap adapter) test suite.
	; The fenced fire-and-forget tee the FU-5 broker wrap calls (spec §4.1.3, §6.1;
	; schema-lock §1). Proves: it appends a RICH (cache layout v2) record when active;
	; it is ALWAYS-ON for capture (FU-9: the ring captures even with no consumer — only
	; egress is gated); req↔resp correlation by call_id (FU-14); and — the heart of the
	; gate — a fault inside the tap is swallowed and leaves the caller's result / $ECODE
	; / $T untouched, self-disabling the tap (exit d). The live VSLRPC/XWB wrap does not
	; exist yet; the seam is injected by calling capture^VSLRPCTAP the way the wrap will.
	; Bare engine, no egress:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLRPCTAPTST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLRPCTAPTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tCaptureAppendsWhenActive(.pass,.fail)
	do tCaptureAlwaysOnNoConsumer(.pass,.fail)
	do tReqRespCorrelation(.pass,.fail)
	do tCallIdFormat(.pass,.fail)
	do tFaultFenceLeavesCallerIntact(.pass,.fail)
	do tCaptureArgIsScratch(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
reset()	; (private) wipe all tap state
	kill ^VSLTAP,^XTMP("VSLTAP")
	quit
	;
tCaptureAppendsWhenActive(pass,fail)	;@TEST "capture^VSLRPCTAP tees a rich (v2) record into the ring when active; payload byte-verbatim"
	new rec,h,hdr
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="ORWU DT",rec("payload")="DUZ=10^NOW"
	do capture^VSLRPCTAP(.rec)
	set h=$$head^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"the tee appended one record")
	do true^STDASSERT(.pass,.fail,$$isV2^VSLTAP(h),"the record is a cache-layout-v2 record (header + payload chunk)")
	do eq^STDASSERT(.pass,.fail,$$chunk^VSLTAP(h,1),"DUZ=10^NOW","the teed payload is byte-verbatim in chunk 1")
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h,.hdr),"the v2 header parses")
	do eq^STDASSERT(.pass,.fail,hdr("direction"),"resp","header carries direction=resp")
	do eq^STDASSERT(.pass,.fail,hdr("rpc"),"ORWU DT","header carries the rpc name")
	quit
	;
tCaptureAlwaysOnNoConsumer(pass,fail)	;@TEST "FU-9: no consumer -> the tee STILL captures into the always-on ring (only egress is gated)"
	new rec
	do reset()
	do arm^VSLTAP()
	set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="ORWU DT",rec("payload")="x"
	do capture^VSLRPCTAP(.rec)
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"always-on ring: capture happens with no consumer")
	do eq^STDASSERT(.pass,.fail,$$writes^VSLTAPHL(),1,"capture-write counter bumped (always-on)")
	do eq^STDASSERT(.pass,.fail,$$enabled^VSLTAP(),0,"egress gate stays OFF with no consumer (the FU-9 split)")
	quit
	;
tReqRespCorrelation(pass,fail)	;@TEST "FU-14: a req and its resp are two records correlated by a shared call_id"
	new rec,cid,seqs,h1,h2,ha,hb
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set cid=$$callId^VSLRPCTAP("500",42)
	; request side-call (before dispatch): dir=req, the verbatim params
	kill rec set rec("dir")="req",rec("call_id")=cid,rec("rpc")="ORWPT LIST",rec("payload")="A^B^C",rec("denied")=0
	do capture^VSLRPCTAP(.rec)
	set h1=$$head^VSLTAP()
	; result side-call (after dispatch): dir=resp, same call_id
	kill rec set rec("dir")="resp",rec("call_id")=cid,rec("rpc")="ORWPT LIST",rec("payload")="result",rec("result_kind")="scalar"
	do capture^VSLRPCTAP(.rec)
	set h2=$$head^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),2,"two records captured (req + resp)")
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h1,.ha),"req header parses")
	do true^STDASSERT(.pass,.fail,$$hdr^VSLTAP(h2,.hb),"resp header parses")
	do eq^STDASSERT(.pass,.fail,ha("direction"),"req","first record is the request")
	do eq^STDASSERT(.pass,.fail,hb("direction"),"resp","second record is the response")
	do eq^STDASSERT(.pass,.fail,ha("call_id"),hb("call_id"),"req and resp share the same call_id (correlation key)")
	do eq^STDASSERT(.pass,.fail,ha("event_id"),cid_":req","req event_id = call_id ':' req")
	do eq^STDASSERT(.pass,.fail,hb("event_id"),cid_":resp","resp event_id = call_id ':' resp")
	quit
	;
tCallIdFormat(pass,fail)	;@TEST "callId builds station-$J-counter (deterministic per-RPC correlation id)"
	do eq^STDASSERT(.pass,.fail,$$callId^VSLRPCTAP("500",7),"500-"_$job_"-7","call_id = station '-' $J '-' counter")
	quit
	;
tFaultFenceLeavesCallerIntact(pass,fail)	;@TEST "a fault inside the tap is swallowed: caller result/$ECODE/$T untouched, tap self-disables (exit d)"
	new rec,result,savedt,m
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","faultinject")=1
	set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="X",rec("payload")="WILL FAULT"
	set result="gold"
	set $ecode=""
	set savedt=0
	; establish a known $TEST (=1), tee on the RPC worker's path, then snapshot $TEST
	if 1
	do capture^VSLRPCTAP(.rec)
	set savedt=$test
	do eq^STDASSERT(.pass,.fail,result,"gold","caller's result is untouched by the swallowed fault")
	do eq^STDASSERT(.pass,.fail,$ecode,"","caller's $ECODE is untouched (the fault never propagates)")
	do eq^STDASSERT(.pass,.fail,savedt,1,"caller's $TEST is preserved across the tee")
	do true^STDASSERT(.pass,.fail,$$disabled^VSLTAP()'="","the tap self-disabled on the fault (fail-safe-OFF)")
	do true^STDASSERT(.pass,.fail,$$offWindows^VSLTAP(.m)'<1,"the fault off-window was recorded")
	quit
	;
tCaptureArgIsScratch(pass,fail)	;@TEST "the tee treats its arg as scratch: the caller's record array is unchanged"
	new rec
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="X",rec("payload")="UNCHANGED"
	do capture^VSLRPCTAP(.rec)
	do eq^STDASSERT(.pass,.fail,rec("payload"),"UNCHANGED","capture does not mutate the caller's payload")
	do eq^STDASSERT(.pass,.fail,rec("call_id"),"500-1-1","capture does not mutate the caller's call_id")
	do eq^STDASSERT(.pass,.fail,$data(rec("event_id")),0,"capture does not inject derived fields back into the caller's array")
	quit
