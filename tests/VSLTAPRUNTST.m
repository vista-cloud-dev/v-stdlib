VSLTAPRUNTST	; v-stdlib — VSLTAPRUN periodic fidelity-run task test suite.
	;
	; Phase 5 / M4 (GA), plan stage 5.1 — wiring the PRODUCTION fidelity run.
	; persist^VSLTAPFC + $$lastFidelity exist and the VWEBT console reads them,
	; but nothing in a live install CALLS persist — so the console shows
	; `pending` forever. VSLTAPRUN is the schedulable task that closes the loop:
	; it reconciles a shipped-vs-source corpus and calls persist, on a cadence.
	;
	; This suite proves the BARE-engine-testable core: $$reconcilePersist (the
	; reconcile-then-persist seam that actually writes ^VSLTAP("fc","last")), the
	; cadence default, gate-respecting run(), and that schedule() is bare-safe.
	; The live S3 read-back leg + the TaskMan queue are VistA/egress seams.
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPRUNTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tReconcilePersistWritesLastFidelity(.pass,.fail)
	do tReconcilePersistPerfectIsOk(.pass,.fail)
	do tReconcilePersistMismatchNotOk(.pass,.fail)
	do tCadenceDefaultOnBareEngine(.pass,.fail)
	do tScheduleIsBareSafe(.pass,.fail)
	do tRunGatedSkipsWhenTapDisabled(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
env(rec,seq)	; (private) build one faithful envelope line for `rec` at `seq`.
	new o
	set o("ts")="65800,43200"
	quit $$envelope^VSLS3(rec,"rpc","resp","500",seq,.o)
	;
corpus(corpus,envs)	; (private) build a 2-record perfect corpus + its read-back envelopes.
	kill corpus,envs
	set corpus(1)="first record"_$char(9)_"x",envs(1)=$$env(corpus(1),1)
	set corpus(2)="second record\q",envs(2)=$$env(corpus(2),2)
	quit
	;
tReconcilePersistWritesLastFidelity(pass,fail)	;@TEST "reconcilePersist: writes ^VSLTAP(""fc"",""last"") so the console stops showing pending"
	new corpus,envs,ok
	kill ^VSLTAP("fc")
	do corpus(.corpus,.envs)
	set ok=$$reconcilePersist^VSLTAPRUN(.corpus,.envs)
	do true^STDASSERT(.pass,.fail,$$lastFidelity^VSLTAPFC()'="","a fidelity result is now persisted (no longer pending)")
	quit
	;
tReconcilePersistPerfectIsOk(pass,fail)	;@TEST "reconcilePersist: a byte-perfect corpus persists ok=true and returns 1"
	new corpus,envs,ok,t
	do corpus(.corpus,.envs)
	set ok=$$reconcilePersist^VSLTAPRUN(.corpus,.envs)
	do eq^STDASSERT(.pass,.fail,ok,1,"a perfect round-trip reconciles ok")
	if '$$parse^STDJSON($$lastFidelity^VSLTAPFC(),.t)
	do eq^STDASSERT(.pass,.fail,$$type^STDJSON($get(t("ok"))),"true","the persisted manifest records ok=true")
	quit
	;
tReconcilePersistMismatchNotOk(pass,fail)	;@TEST "reconcilePersist: a drifted corpus persists ok=false and returns 0"
	new corpus,envs,ok,t
	do corpus(.corpus,.envs)
	set corpus(2)="the source drifted away from what shipped"
	set ok=$$reconcilePersist^VSLTAPRUN(.corpus,.envs)
	do eq^STDASSERT(.pass,.fail,ok,0,"a drift is not ok")
	if '$$parse^STDJSON($$lastFidelity^VSLTAPFC(),.t)
	do eq^STDASSERT(.pass,.fail,$$type^STDJSON($get(t("ok"))),"false","the persisted manifest records ok=false")
	quit
	;
tCadenceDefaultOnBareEngine(pass,fail)	;@TEST "cadence: defaults to a sane positive period when the XPAR param is unset"
	do true^STDASSERT(.pass,.fail,$$cadence^VSLTAPRUN()>0,"the fidelity-run cadence is a positive number of seconds")
	quit
	;
tScheduleIsBareSafe(pass,fail)	;@TEST "schedule: bare-safe — no TaskMan present, returns a safe value and never aborts"
	new ztsk
	set ztsk=$$schedule^VSLTAPRUN()
	do true^STDASSERT(.pass,.fail,+ztsk'>0,"with no TaskMan the schedule is a clean no-op (0/empty), not a crash")
	quit
	;
tRunGatedSkipsWhenTapDisabled(pass,fail)	;@TEST "run: when the tap is OFF it skips the live work and persists nothing new"
	kill ^VSLTAP
	do off^VSLTAP()
	set ^VSLTAP("fc","last")="{""sentinel"":1}"
	do run^VSLTAPRUN()
	do eq^STDASSERT(.pass,.fail,$$lastFidelity^VSLTAPFC(),"{""sentinel"":1}","a disabled tap leaves the last result untouched")
	quit
