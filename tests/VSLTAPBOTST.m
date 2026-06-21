VSLTAPBOTST	; v-stdlib — VSLTAPBO traffic-tap back-out / verify-clean test suite.
	;
	; Phase 5 / M4 (GA), plan stage 5.1 — the G-UNINST gate. v-pkg's uninstall is
	; routine-only (routines + #9.7/#9.6); it leaves the tap's RUNTIME footprint
	; behind — the XPAR config params, the scheduled flush/fidelity tasks, the
	; ^XTMP("VSLTAP",…) rolling cache and the ^VSLTAP control state. VSLTAPBO
	; reverses exactly that, then $$verifyClean proves nothing is orphaned.
	;
	; This suite proves the BARE-engine-testable core: the state-global cleanup
	; (^XTMP + ^VSLTAP), verify-clean residue detection, idempotency, and the
	; canonical param list. The XPAR-param and TaskMan-dequeue legs are VistA
	; seams (fenced here; live-proven install→back-out→verify-clean on vehu+foia).
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPBOTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tCleanStateRemovesCacheAndControl(.pass,.fail)
	do tVerifyCleanTrueWhenEmpty(.pass,.fail)
	do tVerifyCleanFalseWithCacheResidue(.pass,.fail)
	do tVerifyCleanFalseWithControlResidue(.pass,.fail)
	do tVerifyCleanDetailNamesResidue(.pass,.fail)
	do tBackoutRemovesState(.pass,.fail)
	do tBackoutIdempotent(.pass,.fail)
	do tParamsListIsCanonical(.pass,.fail)
	do tBackoutFencedOnBareEngine(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
seed()	; (private) plant a realistic post-run footprint: cache + full control state.
	kill ^XTMP("VSLTAP"),^VSLTAP
	set ^XTMP("VSLTAP",0)="3690101^3680101^VSL RPC traffic-tap rolling cache"
	set ^XTMP("VSLTAP","head")=3,^XTMP("VSLTAP","tail")=0
	set ^XTMP("VSLTAP","data",1)="rec-1",^XTMP("VSLTAP","data",2)="rec-2",^XTMP("VSLTAP","data",3)="rec-3"
	set ^VSLTAP("cfg","mode")="armed",^VSLTAP("cfg","cap")=1000
	set ^VSLTAP("hb")=$horolog
	set ^VSLTAP("fc","last")="{""ok"":true}"
	set ^VSLTAP("task","fidelity")=4242
	quit
	;
tCleanStateRemovesCacheAndControl(pass,fail)	;@TEST "cleanState: kills both ^XTMP(""VSLTAP"") and ^VSLTAP entirely"
	do seed()
	do cleanState^VSLTAPBO()
	do eq^STDASSERT(.pass,.fail,$data(^XTMP("VSLTAP")),0,"the rolling cache global is gone")
	do eq^STDASSERT(.pass,.fail,$data(^VSLTAP),0,"the control-state global is gone")
	quit
	;
tVerifyCleanTrueWhenEmpty(pass,fail)	;@TEST "verifyClean: 1 when no cache/control residue remains"
	kill ^XTMP("VSLTAP"),^VSLTAP
	new detail
	do true^STDASSERT(.pass,.fail,$$verifyClean^VSLTAPBO(.detail),"an empty system verifies clean")
	quit
	;
tVerifyCleanFalseWithCacheResidue(pass,fail)	;@TEST "verifyClean: 0 when the ^XTMP cache survives"
	kill ^XTMP("VSLTAP"),^VSLTAP
	set ^XTMP("VSLTAP","data",1)="orphan"
	new detail
	do eq^STDASSERT(.pass,.fail,$$verifyClean^VSLTAPBO(.detail),0,"a surviving cache is not clean")
	quit
	;
tVerifyCleanFalseWithControlResidue(pass,fail)	;@TEST "verifyClean: 0 when ^VSLTAP control state survives"
	kill ^XTMP("VSLTAP"),^VSLTAP
	set ^VSLTAP("cfg","mode")="armed"
	new detail
	do eq^STDASSERT(.pass,.fail,$$verifyClean^VSLTAPBO(.detail),0,"surviving control state is not clean")
	quit
	;
tVerifyCleanDetailNamesResidue(pass,fail)	;@TEST "verifyClean: detail() names the residue layer (globals)"
	kill ^XTMP("VSLTAP"),^VSLTAP
	set ^VSLTAP("hb")=$horolog
	new detail,clean
	set clean=$$verifyClean^VSLTAPBO(.detail)
	do true^STDASSERT(.pass,.fail,$get(detail("globals"))'="","detail('globals') names the surviving control state")
	quit
	;
tBackoutRemovesState(pass,fail)	;@TEST "backout: a seeded footprint verifies clean afterward"
	do seed()
	do backout^VSLTAPBO()
	new detail
	do true^STDASSERT(.pass,.fail,$$verifyClean^VSLTAPBO(.detail),"backout leaves a verify-clean system")
	quit
	;
tBackoutIdempotent(pass,fail)	;@TEST "backout: running it twice on an already-clean system is a no-op (no error)"
	do seed()
	do backout^VSLTAPBO()
	do backout^VSLTAPBO()
	new detail
	do true^STDASSERT(.pass,.fail,$$verifyClean^VSLTAPBO(.detail),"a second back-out stays clean and raises nothing")
	quit
	;
tParamsListIsCanonical(pass,fail)	;@TEST "params: the canonical tap XPAR param list is non-empty and includes the S3 + cadence knobs"
	new out,n,i,seen
	set n=$$params^VSLTAPBO(.out)
	do true^STDASSERT(.pass,.fail,n>0,"the tap ships at least one XPAR param")
	set seen=""
	for i=1:1:n set seen=seen_"^"_out(i)
	do true^STDASSERT(.pass,.fail,seen["VSL S3 ENDPOINT","the S3 endpoint flip is a tap param")
	do true^STDASSERT(.pass,.fail,seen["VSL TAP FIDELITY CADENCE","the fidelity cadence is a tap param")
	quit
	;
tBackoutFencedOnBareEngine(pass,fail)	;@TEST "backout: the VistA seams (params/tasks) are fenced — bare engine survives them"
	; On a bare engine there is no XPAR/TaskMan; cleanParams/cleanTasks must fault-
	; fence so backout still completes the state cleanup and never raises.
	do seed()
	do cleanParams^VSLTAPBO()
	do cleanTasks^VSLTAPBO()
	do true^STDASSERT(.pass,.fail,1,"the VistA-seam legs return without raising on a bare engine")
	quit
