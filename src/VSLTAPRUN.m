VSLTAPRUN	; v-stdlib — the periodic fidelity-run task (closes the console loop).
	;
	; Phase 5 / M4 (GA), plan stage 5.1. persist^VSLTAPFC + $$lastFidelity exist
	; and the VWEBT console reads ^VSLTAP("fc","last"), but in a live install
	; NOTHING calls persist — only the test suite writes it — so the console's
	; fidelity panel shows `pending` forever. VSLTAPRUN is the schedulable task
	; that closes that loop: on a cadence it reconciles a shipped-vs-source sample
	; and calls persist, giving the operator a real, current match %.
	;
	; *** Layer: v. It consumes the fidelity comparator (VSLTAPFC, v) and the gate
	; (VSLTAP, v) and binds TaskMan (^%ZTLOAD, the same #10063 seam VSLTASK uses)
	; to re-queue itself. The persist seam ($$reconcilePersist) is pure M and
	; bare-proven; the live sample (read recently-shipped objects back and compare
	; to the independent source) is the egress/VistA leg — see $$liveReconcile.
	;
	; Public API:
	;   do run()                     the scheduled task body (gate -> sample -> persist -> re-queue)
	;   $$reconcilePersist(corpus,envs)  reconcile a sample then persist it -> ok (the persist seam)
	;   $$cadence()                  the run period in seconds (XPAR VSL TAP FIDELITY CADENCE; default 3600)
	;   $$schedule()                 queue run^VSLTAPRUN at now+cadence; record the task# -> task#
	;
	quit
	;
	; ---------- the persist seam (pure M; the bare-proven loop-closer) ----------
	;
reconcilePersist(corpus,envs)	; Reconcile the corpus vs the read-back envelopes, persist the result, return ok.
	; doc: @param corpus  array  by-ref: corpus(seq) = the source record
	; doc: @param envs    array  by-ref: envs(seq)   = the read-back envelope line
	; doc: @returns       bool   1 iff the sample reconciles byte-perfect (ok=true persisted)
	; doc: The one call that writes ^VSLTAP("fc","last") in production — the live
	; doc: sampler and the make-test-s3 round-trip both funnel through here so the
	; doc: console (VWEBT $$lastFidelity^VSLTAPFC) stops showing `pending`.
	new res,ok
	set ok=$$reconcile^VSLTAPFC(.corpus,.envs,.res)
	do persist^VSLTAPFC(.res)
	quit ok
	;
	; ---------- the cadence (XPAR config; the period between runs) ----------
	;
cadence()	; The fidelity-run period in seconds: XPAR VSL TAP FIDELITY CADENCE, default 3600.
	; doc: @returns numeric  a positive number of seconds between fidelity runs
	; doc: $text-guarded — a bare engine has no XPAR, so the default (1h) applies.
	; doc: @icr 2263 @call $$GET^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#getxpar-return-an-instance-of-a-parameter
	new $etrap,v
	set $etrap="set $ecode="""" quit"
	set v=3600
	if $text(GET^XPAR)'="" set v=+$$get^VSLCFG("VSL TAP FIDELITY CADENCE",3600)
	if v'>0 set v=3600
	quit v
	;
	; ---------- the scheduler (non-persistent TaskMan re-queue) ----------
	;
schedule()	; Queue run^VSLTAPRUN at now+cadence; record the task# (so back-out can dequeue it); return it.
	; doc: @returns numeric  the queued task number, or 0 when there is no TaskMan (bare/no-queue)
	; doc: A NON-persistent periodic task (each run re-queues the next) — NOT a
	; doc: PSET self-restarting listener (so it is cleanly dequeueable by VSLTAPBO,
	; doc: unlike a persistent listener). Records ^VSLTAP("task","fidelity")=task#.
	; doc: $text-guarded so a bare engine is a clean no-op.
	; doc: @icr 10063 @call ^%ZTLOAD @status Supported @custodian XU @source XU/krn_8_0_tm#callable-entry-points
	new $etrap,ZTRTN,ZTDESC,ZTIO,ZTDTH,ZTSK,ztsk
	set $etrap="set $ecode="""" quit"
	if $text(^%ZTLOAD)="" quit 0
	set ZTRTN="run^VSLTAPRUN",ZTIO="",ZTDESC="VSL traffic-tap fidelity run"
	set ZTDTH=$$nextRun($$cadence())
	do ^%ZTLOAD
	set ztsk=+$get(ZTSK)
	if ztsk>0 set ^VSLTAP("task","fidelity")=ztsk
	quit ztsk
	;
nextRun(secs)	; (private) the $H timestamp `secs` seconds from now (with day rollover).
	new d,s
	set d=$piece($horolog,",",1),s=$piece($horolog,",",2)+(+secs)
	for  quit:s<86400  set s=s-86400,d=d+1
	quit d_","_s
	;
	; ---------- the task body ----------
	;
run()	; The scheduled task body: gate -> sample+persist -> re-queue. Fenced (never aborts TaskMan).
	; doc: Respects the Phase-2 gate — when the tap is OFF / auto-disabled / has no
	; doc: consumer it skips the live work entirely (no false fidelity result). The
	; doc: whole body is fault-fenced so a sampling/egress fault self-clears and the
	; doc: next tick is still re-queued.
	new $etrap
	set $etrap="set $ecode="""" quit"
	if '$$enabled^VSLTAP() quit
	do liveReconcile()
	do reschedule()
	quit
	;
reschedule()	; (private) re-queue the next periodic run (bare-safe no-op without TaskMan).
	new ztsk
	set ztsk=$$schedule()
	quit
	;
liveReconcile()	; (private) the LIVE fidelity sample — read recently-shipped objects back and reconcile.
	; doc: The egress/VistA leg. The byte-equality round-trip itself is already
	; doc: proven (VSLTAPFC + VSLS3E2ETST against MinIO); what lands with the GA
	; doc: real-S3 increment (plan §9 stage 5.2 + the "VSLTAPFC HL7 live-periodic
	; doc: hook") is the SOURCE selection: the independent durable source to compare
	; doc: the shipped object against — the passive mirror for RPC, or the #772
	; doc: store for HL7 (the ring is trimmed after $$drain, so it cannot be the
	; doc: source). Until that source seam is wired, this is a deliberate, fenced
	; doc: no-op; the scheduler, gate, cadence and persist seam around it are live.
	; doc: When wired it assembles corpus(seq)/envs(seq) and calls
	; doc: $$reconcilePersist — the one seam that lights up the console.
	quit
