VSLTASK	; v-stdlib — VistA TaskMan persistent-listener adapter (the process seam).
	;
	; Binds the persistent-listener seam to Kernel TaskMan. A long-running VSL/
	; VWEB socket listener is a TaskMan **persistent task**: $$PSET^%ZTLOAD marks
	; a queued task persistent, so TaskMan automatically RE-RUNS it when the lock
	; on ^%ZTSCH("TASK",n) is dropped — a self-healing listener (architecture
	; §3.5). VSLTASK is a thin binding over the Supported ^%ZTLOAD programmer API
	; (ICR #10063), NOT new machinery; portable diagnostics belong in STDLOG (v->m),
	; never re-implemented here.
	;
	; Public API:
	;   $$running^VSLTASK()            — 1 iff the TaskMan scheduler is live (=$$TM^%ZTLOAD)
	;   $$stop^VSLTASK()              — 1 iff a stop has been requested (=$$S^%ZTLOAD)
	;   $$persist^VSLTASK(ztsk)       — mark queued task `ztsk` self-restarting (=$$PSET^%ZTLOAD)
	;   $$schedule^VSLTASK(entry,desc,when) — headless-queue a persistent listener -> its task#
	;   $$lastError^VSLTASK()         — last error detail, else ""
	;
	; *** ERROR CONTRACT — loud on a malformed call / a real TaskMan fault ***
	; A malformed call (no entry / no task#) or a TaskMan queue fault maps to a
	; clean ,U-VSL-TASK-ARG, / ,U-VSL-TASK-QUEUE, $ECODE, with the detail in
	; ^TMP($job,"vsltask","err") for $$lastError. A normal negative — "the
	; scheduler is not running here" ($$running=0) or "no stop requested"
	; ($$stop=0) — is NOT an error (kickoff decision 4). The flag-based $ETRAP
	; pattern is used (NEVER zgoto — a zgoto trap aborts the resident harness 0/0,
	; the M4 VSLLOG gotcha); OUR trap is cleared before any re-raise.
	;
	; Self-restart note: the restart CONTRACT is bound here ($$PSET^%ZTLOAD marks
	; ^%ZTSCH("TASK",n,"P"); TaskMan re-runs on a lock drop). Observing a live
	; restart needs the task body installed as a RESIDENT routine (the VSLBLD/
	; v-pkg path) + lock manipulation, and a persistent task is deliberately
	; un-KILLable — out of scope for a safe unit test (see VSLTASKTST).
	;
	quit
	;
	; ---------- the TaskMan binding (ICR #10063, Supported) ----------
	;
running()	; 1 iff the TaskMan scheduler is live (its ^%ZTSCH("RUN") heartbeat is fresh).
	; doc: @returns          bool     1 iff TaskMan is running (the self-heal precondition); 0 otherwise
	; doc: @icr 10063 @call $$TM^%ZTLOAD @status Supported @custodian XU @source XU/krn_8_0_dg_taskman_ug#tmztload-check-if-taskman-is-running
	quit ''$$TM^%ZTLOAD()
	;
stop()	; 1 iff a stop has been requested of the currently-running task (cooperative stop).
	; doc: @returns          bool     1 iff the listener loop should stop; 0 when not in a task / no stop pending
	; doc: @icr 10063 @call $$S^%ZTLOAD @status Supported @custodian XU @source XU/krn_8_0_dg_taskman_ug#sztload-check-for-task-stop-request
	quit ''$$S^%ZTLOAD
	;
persist(ztsk)	; Mark queued task `ztsk` persistent so TaskMan self-restarts it on a lock drop.
	; doc: @param   ztsk     numeric  the task number (from $$schedule / ^%ZTLOAD)
	; doc: @returns          bool     1 iff the task was marked persistent, else 0 (task not queued)
	; doc: @raises  U-VSL-TASK-ARG   the call is malformed (no positive task number)
	; doc: @icr 10063 @call $$PSET^%ZTLOAD @status Supported @custodian XU @source XU/krn_8_0_dg_taskman_ug#psetztload-set-task-as-persistent
	if +$get(ztsk)'>0 do raise("U-VSL-TASK-ARG","persist: a positive task number is required") quit ""
	quit ''$$PSET^%ZTLOAD(ztsk)
	;
schedule(entry,desc,when)	; Headless-queue a persistent listener at `entry`; return its task number.
	; doc: @param   entry    string   the task entry reference (TAG^ROUTINE)
	; doc: @param   desc     string   a human description (optional)
	; doc: @param   when     string   $H start time (optional; default now). MUST be <=5-digit $H or "@"
	; doc: @returns          numeric  the queued task number
	; doc: @raises  U-VSL-TASK-ARG    no entry reference supplied
	; doc: @raises  U-VSL-TASK-QUEUE  the TaskMan queue / persist failed
	new $etrap,ztsk,ok
	if $get(entry)="" do raise("U-VSL-TASK-ARG","schedule: an entry reference is required") quit ""
	set ok=1
	set $etrap="set ok=0,$ecode="""" quit"
	set ztsk=$$queue(entry,$get(desc),$get(when))
	set $etrap=""
	if 'ok!(+ztsk'>0) do raise("U-VSL-TASK-QUEUE","schedule: TaskMan queue failed") quit ""
	if '$$PSET^%ZTLOAD(ztsk) do raise("U-VSL-TASK-QUEUE","schedule: could not mark task "_ztsk_" persistent") quit ""
	quit ztsk
	;
lastError()	; The last VSLTASK error message (the composed malformed-call / fault detail).
	; doc: @returns          string   ^TMP($job,"vsltask","err"), or "" if none
	quit $get(^TMP($job,"vsltask","err"))
	;
	; ---------- internals ----------
	;
queue(entry,desc,when)	; (private) headless ^%ZTLOAD queue (no device); return the task number, else 0.
	; doc: @icr 10063 @call ^%ZTLOAD @status Supported @custodian XU @source XU/krn_8_0_tm#callable-entry-points
	new ZTRTN,ZTDESC,ZTIO,ZTDTH,ZTSK
	set ZTRTN=entry,ZTIO=""
	set ZTDESC=$select(desc'="":desc,1:"VSL persistent listener")
	set ZTDTH=$select(when'="":when,1:$horolog)
	do ^%ZTLOAD
	quit +$get(ZTSK)
	;
raise(code,msg)	; (private) stash the detail, then raise the clean ,<code>, $ECODE.
	set ^TMP($job,"vsltask","err")=msg
	set $ecode=","_code_","
	quit
