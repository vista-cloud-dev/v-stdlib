VSLRPCTAPTST	; v-stdlib — VSLRPCTAP (RPC tap adapter) test suite.
	; The fenced fire-and-forget tee at the (injected) VSLRPC chokepoint
	; (spec §4.1.3, §6.1). Proves: it appends when active; it is ALWAYS-ON for
	; capture (FU-9: the ring captures even with no consumer — only egress is gated);
	; and — the heart of the gate — a fault inside the tap is swallowed and leaves the caller's
	; result / $ECODE / $T untouched, self-disabling the tap (exit d). VSLRPC does
	; not exist yet; the chokepoint is injected by calling capture^VSLRPCTAP the
	; way VSLRPC will. Bare engine, no egress:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLRPCTAPTST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLRPCTAPTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tCaptureAppendsWhenActive(.pass,.fail)
	do tCaptureAlwaysOnNoConsumer(.pass,.fail)
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
tCaptureAppendsWhenActive(pass,fail)	;@TEST "capture^VSLRPCTAP tees a verbatim record into the ring when active"
	new msg
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set msg="ORWU DT^DUZ=10^NOW"
	do capture^VSLRPCTAP(msg)
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"the tee appended one record")
	do eq^STDASSERT(.pass,.fail,$$read^VSLTAP($$head^VSLTAP()),msg,"the teed record is byte-verbatim")
	quit
	;
tCaptureAlwaysOnNoConsumer(pass,fail)	;@TEST "FU-9: no consumer -> the tee STILL captures into the always-on ring (only egress is gated)"
	do reset()
	do arm^VSLTAP()
	do capture^VSLRPCTAP("ORWU DT^DUZ=10^NOW")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"always-on ring: capture happens with no consumer")
	do eq^STDASSERT(.pass,.fail,$$writes^VSLTAPHL(),1,"capture-write counter bumped (always-on)")
	do true^STDASSERT(.pass,.fail,$$bytes^VSLTAPHL()>0,"bytes-to-buffer counter bumped")
	do eq^STDASSERT(.pass,.fail,$$enabled^VSLTAP(),0,"egress gate stays OFF with no consumer (the FU-9 split)")
	quit
	;
tFaultFenceLeavesCallerIntact(pass,fail)	;@TEST "a fault inside the tap is swallowed: caller result/$ECODE/$T untouched, tap self-disables (exit d)"
	new msg,result,savedt
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","faultinject")=1
	set msg="WILL FAULT"
	set result="gold"
	set $ecode=""
	set savedt=0
	; establish a known $TEST (=1), tee on the RPC worker's path, then snapshot $TEST
	if 1
	do capture^VSLRPCTAP(msg)
	set savedt=$test
	do eq^STDASSERT(.pass,.fail,result,"gold","caller's result is untouched by the swallowed fault")
	do eq^STDASSERT(.pass,.fail,$ecode,"","caller's $ECODE is untouched (the fault never propagates)")
	do eq^STDASSERT(.pass,.fail,savedt,1,"caller's $TEST is preserved across the tee")
	do true^STDASSERT(.pass,.fail,$$disabled^VSLTAP()'="","the tap self-disabled on the fault (fail-safe-OFF)")
	do true^STDASSERT(.pass,.fail,$$offWindows^VSLTAP(.msg)'<1,"the fault off-window was recorded")
	quit
	;
tCaptureArgIsScratch(pass,fail)	;@TEST "the tee treats its arg as scratch: the caller's variable is unchanged"
	new msg
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set msg="UNCHANGED"
	do capture^VSLRPCTAP(msg)
	do eq^STDASSERT(.pass,.fail,msg,"UNCHANGED","capture does not mutate the caller's record variable")
	quit
