VSLTASKTST	; v-stdlib — VSLTASK (TaskMan persistent-listener adapter) test suite.
	; Exercises VSLTASK against a live VistA's TaskMan (^%ZTLOAD), over the
	; driver stack only (m/v waterline — the ONLY path):
	;   m test --engine ydb  --docker vehu     --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLTASKTST.m
	;   m test --engine iris --docker foia-t12 --namespace VISTA \
	;     --routines src --routines <m-stdlib>/src tests/VSLTASKTST.m
	;
	; VSLTASK binds the persistent-listener seam to Kernel TaskMan. The seam's
	; reason to exist is the SELF-RESTARTING listener: $$PSET^%ZTLOAD marks a
	; queued task persistent so TaskMan re-runs it when its ^%ZTSCH("TASK",n)
	; lock is dropped (architecture §3.5). VSLTASK is a thin binding over the
	; Supported ^%ZTLOAD programmer API (ICR #10063): $$running (is the scheduler
	; live? = $$TM^%ZTLOAD), $$stop (cooperative-stop = $$S^%ZTLOAD), $$persist
	; (mark self-restarting = $$PSET^%ZTLOAD) and $$schedule (headless queue +
	; persist). A malformed call is a loud ,U-VSL-TASK-..., $ECODE.
	;
	; *** What is asserted LIVE vs SOFT-SKIPPED (Q1 grounding, 2026-06-17) ***
	; Both test engines run TaskMan ($$TM^%ZTLOAD()=1 — heartbeat fresh on vehu
	; AND foia-t12), so liveness, the cooperative-stop check, the API binding and
	; the loud error contract are all asserted LIVE-GREEN. The full self-restart
	; observation (queue a sentinel task -> drop its ^%ZTSCH lock -> poll for a
	; TaskMan re-run) is SOFT-SKIPPED with a loud diagnostic: it would need the
	; restartable task body installed as a RESIDENT routine (the v-pkg install
	; path, an integration test) AND lock manipulation on a shared live
	; VistA, and a PSET-persistent task is deliberately un-KILLable (^%ZTLOAD KILL
	; refuses a persistent task) — exactly the runaway hazard the kickoff forbids
	; in an automated unit test. The restart contract is bound + documented; its
	; live observation is an infra/integration-gated follow-up. This mirrors M2's
	; loopback soft-skip and VSLIO's TLS gap, but is NARROWER (liveness is real).
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tRunningReportsLiveScheduler(.pass,.fail)
	do tStopIsCleanOutsideTask(.pass,.fail)
	do tPersistRejectsBadArg(.pass,.fail)
	do tScheduleRejectsBadArg(.pass,.fail)
	do tSelfRestartIsWiredSoftSkip(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
tRunningReportsLiveScheduler(pass,fail)	;@TEST "$$running reports the live TaskMan scheduler (=1) via $$TM^%ZTLOAD (heartbeat fresh)"
	new r
	set r=$$running^VSLTASK()
	do true^STDASSERT(.pass,.fail,(r=0)!(r=1),"$$running returns a clean boolean (the binding resolves $$TM^%ZTLOAD)")
	do true^STDASSERT(.pass,.fail,r=1,"TaskMan is live here (=1) — the self-heal precondition; on a TaskMan-down engine this is the soft-skip pivot")
	quit
	;
tStopIsCleanOutsideTask(pass,fail)	;@TEST "$$stop is a clean 0 outside a queued task (no stop requested) via $$S^%ZTLOAD"
	new r
	set r=$$stop^VSLTASK()
	do true^STDASSERT(.pass,.fail,r=0,"$$stop=0 when not running as a TaskMan task (the cooperative-stop check the listener loops on)")
	quit
	;
tPersistRejectsBadArg(pass,fail)	;@TEST "$$persist on a missing task# raises a clean ,U-VSL-TASK-..., with detail in $$lastError"
	do raises^STDASSERT(.pass,.fail,"set x=$$persist^VSLTASK("""")",",U-VSL-TASK-ARG,","$$persist with no task# raises exactly ,U-VSL-TASK-ARG,")
	do eq^STDASSERT(.pass,.fail,$ecode,"","$ECODE is clear after the trapped persist raise (clean unwind)")
	do true^STDASSERT(.pass,.fail,$$lastError^VSLTASK()'="","lastError carries the malformed-call detail")
	quit
	;
tScheduleRejectsBadArg(pass,fail)	;@TEST "$$schedule with an empty entry raises a clean ,U-VSL-TASK-..., (wired; live queue is soft-skipped)"
	do raises^STDASSERT(.pass,.fail,"set x=$$schedule^VSLTASK("""",""ZZ"")",",U-VSL-TASK-ARG,","$$schedule with no entry raises exactly ,U-VSL-TASK-ARG,")
	do eq^STDASSERT(.pass,.fail,$ecode,"","$ECODE is clear after the trapped schedule raise (clean unwind)")
	do true^STDASSERT(.pass,.fail,$$lastError^VSLTASK()'="","lastError carries the malformed-call detail")
	quit
	;
tSelfRestartIsWiredSoftSkip(pass,fail)	;@TEST "self-restart binding is wired + documented; the live restart observation is integration-gated (SOFT-SKIP)"
	; Loud, deliberate skip (not a silent gap): the restart contract is
	; $$PSET^%ZTLOAD -> ^%ZTSCH("TASK",n,"P"); TaskMan re-runs the task on a
	; ^%ZTSCH lock drop. Observing it needs a resident task body (v-pkg-installed)
	; + lock manipulation + a bounded poll, and a persistent task is un-KILLable
	; (runaway risk). Deferred to a v-pkg-installed integration test.
	do true^STDASSERT(.pass,.fail,1,"SOFT-SKIP: live self-restart (queue->drop ^%ZTSCH lock->observe re-run) integration-gated — runaway-unsafe in a unit test; contract bound + documented")
	quit
