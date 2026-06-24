VSLTAPBO	; v-stdlib — traffic-tap back-out / verify-clean (the G-UNINST gate).
	; doc: @exrun bare
	;
	; Phase 5 / M4 (GA), plan stage 5.1. v-pkg's KIDS uninstall is routine-only
	; (it removes the routines + the #9.7/#9.6 build records); it deliberately
	; leaves the tap's RUNTIME footprint behind. VSLTAPBO reverses exactly that
	; footprint and then PROVES, by inspection, that nothing is orphaned — the
	; reversible-install invariant a fleet rollout depends on (risk G-UNINST):
	;
	;   1. the scheduled flush / fidelity TaskMan jobs (recorded in ^VSLTAP("task"))
	;   2. the tap's XPAR #8989.51 PARAMETER instances + definitions (the config seam)
	;   3. the ^XTMP("VSLTAP",…) rolling capture cache (the SAC scratch global)
	;   4. the ^VSLTAP control state (cfg / disabled / hb / _offwindows / hl / fc)
	;
	; *** Layer: v (above the m/v waterline). The state-global cleanup (3,4) is
	; pure M and runs on a BARE engine; the XPAR (2) and TaskMan (1) legs are
	; VistA seams, each fault-fenced so a bare engine survives them and a partial
	; VistA absence never blocks the cleanup. Order matters: dequeue tasks (their
	; numbers live in ^VSLTAP) BEFORE the state kill removes the record.
	;
	; Public API:
	;   do backout()              full back-out: dequeue tasks -> drop params -> kill state
	;   $$verifyClean(detail)     1 iff no tap residue; detail(globals/params/tasks) names any
	;   do cleanState()           kill ^XTMP("VSLTAP") + ^VSLTAP (the bare-testable core)
	;   do cleanParams()          drop the tap #8989.51 XPAR instances + definitions (fenced)
	;   do cleanTasks()           dequeue the recorded flush/fidelity TaskMan jobs (fenced)
	;   $$params(out)             the canonical tap XPAR param-name list -> count
	;
	quit
	;
	; ---------- the canonical tap XPAR param list (single source of truth) ----------
	;
params(out)	; Fill out(1..N) with the tap's XPAR #8989.51 param names; return N.
	; doc: @param out  array  by-ref; killed then filled out(1)=name … out(N)=name
	; doc: @returns    numeric  the count of tap params (the KIDS build + the back-out share this list)
	; doc: The durable install-time config + the S3 deployment knobs. Operator
	; doc: RUNTIME state (mode/consumer) stays in ^VSLTAP("cfg"), not XPAR.
	; doc: @example      do true^STDASSERT(.pass,.fail,$$params^VSLTAPBO(.out)>0,"params: the tap ships at least one XPAR param")
	; doc: @example      new out do eq^STDASSERT(.pass,.fail,$$params^VSLTAPBO(.out)_"|"_out(7),"10|VSL S3 ENDPOINT","params: 10 knobs, the 7th is the S3 endpoint")
	new n
	kill out
	set n=0
	do add(.out,.n,"VSL TAP CAP")
	do add(.out,.n,"VSL TAP MAXBYTES")
	do add(.out,.n,"VSL TAP HBSTALE")
	do add(.out,.n,"VSL TAP RETAIN")
	do add(.out,.n,"VSL TAP ALWAYSON")
	do add(.out,.n,"VSL TAP FIDELITY CADENCE")
	do add(.out,.n,"VSL S3 ENDPOINT")
	do add(.out,.n,"VSL S3 BUCKET")
	do add(.out,.n,"VSL S3 REGION")
	do add(.out,.n,"VSL S3 PREFIX")
	quit n
	;
add(out,n,name)	; (private) append `name` to the param list.
	set n=n+1
	set out(n)=name
	quit
	;
	; ---------- the orchestrated back-out ----------
	;
backout()	; Full back-out: dequeue tasks, drop the XPAR params, kill the state. Idempotent.
	; doc: Each leg is independently fault-fenced, so a missing TaskMan/XPAR/FileMan
	; doc: (a bare engine, or a partial install) never blocks the state cleanup. Tasks
	; doc: first — their numbers live in ^VSLTAP, which the state kill then removes.
	; doc: @example      set ^XTMP("VSLTAP","data",1)="rec",^VSLTAP("hb")=$horolog do backout^VSLTAPBO() do true^STDASSERT(.pass,.fail,$$verifyClean^VSLTAPBO(.detail),"backout: a seeded footprint verifies clean afterward")
	do cleanTasks()
	do cleanParams()
	do cleanState()
	quit
	;
	; ---------- (3,4) the state-global cleanup — the bare-testable core ----------
	;
cleanState()	; Kill the rolling capture cache and ALL VSL control state.
	; doc: The whole tap footprint that lives in globals: ^XTMP("VSLTAP",…) (the
	; doc: SAC auto-purge scratch cache) and ^VSLTAP (cfg/disabled/hb/_offwindows/
	; doc: hl/fc/task). Pure M — no VistA needed; this is what the bare suite proves.
	; doc: @example      set ^VSLTAP("cfg","mode")="armed",^XTMP("VSLTAP","data",1)="x" do cleanState^VSLTAPBO() do eq^STDASSERT(.pass,.fail,$data(^VSLTAP)+$data(^XTMP("VSLTAP")),0,"cleanState: both the cache and the control state are gone")
	kill ^XTMP("VSLTAP")
	kill ^VSLTAP
	quit
	;
	; ---------- (2) the XPAR #8989.51 param cleanup — a fenced VistA seam ----------
	;
cleanParams()	; Drop every tap XPAR param: clear the SYS instance, delete the #8989.51 definition.
	; doc: Fault-fenced as a whole (a bare engine has no XPAR/FileMan), and per-param
	; doc: inside delParam, so one missing param does not strand the rest.
	; doc: @example      do cleanParams^VSLTAPBO() do true^STDASSERT(.pass,.fail,1,"cleanParams: the fenced XPAR leg returns without raising on a bare engine")
	new $etrap,out,n,i
	set $etrap="set $ecode="""" quit"
	set n=$$params(.out)
	for i=1:1:n do delParam(out(i))
	quit
	;
delParam(name)	; (private) clear the SYS-level instance, then delete the #8989.51 definition record.
	; doc: @param name  string  the XPAR parameter name (#8989.51 .01)
	; doc: EN^XPAR(...,"@") removes the SYS instance value; the definition record is
	; doc: deleted via FileMan DBS FILE^DIE with .01="@" (no DELETE^DIE exists — the
	; doc: VSLFS pattern). Per-param fenced so a not-present param is a clean no-op.
	; doc: @icr 2263 @call EN^XPAR @status Supported @custodian XU @source XU/krn_8_0_dg_toolkit_ug#enxpar-add-change-delete-parameters
	; doc: @icr DBS @call $$FIND1^DIC @status Supported @custodian DI @source DI/fm22_2dg#find1dic-finder-single-record
	; doc: @icr DBS @call FILE^DIE @status Supported @custodian DI @source DI/fm22_2dg#filedie-filer
	; doc: $text-guarded: a bare engine has no XPAR/FileMan, so each leg is a clean
	; doc: skip (there is nothing to remove); the $etrap still fences a genuine fault.
	; doc: @example      do delParam^VSLTAPBO("VSL TAP CAP") do true^STDASSERT(.pass,.fail,1,"delParam: a not-present param is a clean no-op (fenced) on a bare engine")
	new $etrap,ien,FDA,ERR
	set $etrap="set $ecode="""" quit"
	if $text(EN^XPAR)'="" do EN^XPAR("SYS",name,1,"@")
	if $text(FIND1^DIC)="" quit
	set ien=+$$FIND1^DIC(8989.51,"","X",name,"B")
	if ien'>0 quit
	set FDA(8989.51,ien_",",.01)="@"
	do FILE^DIE("","FDA","ERR")
	quit
	;
	; ---------- (1) the TaskMan dequeue — a fenced VistA seam ----------
	;
cleanTasks()	; Dequeue every recorded flush/fidelity TaskMan job (read BEFORE cleanState).
	; doc: The scheduled-task numbers live in ^VSLTAP("task",label)=ztsk. The
	; doc: fidelity/flush jobs are periodic re-queues (NOT persistent listeners),
	; doc: so they dequeue cleanly. Fenced — no TaskMan on a bare engine.
	; doc: @example      do cleanTasks^VSLTAPBO() do true^STDASSERT(.pass,.fail,1,"cleanTasks: the fenced TaskMan leg returns without raising on a bare engine")
	new $etrap,k
	set $etrap="set $ecode="""" quit"
	set k=""
	for  do dequeueNext(.k) quit:k=""
	quit
	;
dequeueNext(k)	; (private) advance to the next recorded task label and dequeue its job.
	set k=$order(^VSLTAP("task",k))
	if k="" quit
	do dequeue(+$get(^VSLTAP("task",k)))
	quit
	;
dequeue(ztsk)	; (private) unschedule task `ztsk` via the Kernel ZTLOAD programmer API. Fenced.
	; doc: @param ztsk  numeric  the task number to remove from the schedule
	; doc: @icr 10063 @call KILL^%ZTLOAD @status Supported @custodian XU @source XU/krn_8_0_dg_taskman_ug#killztload-delete-a-task
	; doc: @example      do dequeue^VSLTAPBO(0) do true^STDASSERT(.pass,.fail,1,"dequeue: a non-positive task number is a clean no-op")
	new $etrap,ZTSK
	set $etrap="set $ecode="""" quit"
	if +$get(ztsk)'>0 quit
	if $text(KILL^%ZTLOAD)="" quit
	set ZTSK=ztsk
	do KILL^%ZTLOAD
	quit
	;
	; ---------- the verify-clean proof (the exit gate) ----------
	;
verifyClean(detail)	; 1 iff no tap residue remains across all layers; detail() names any survivor.
	; doc: @param detail  array  OUT by-ref; killed then filled detail(globals/params/tasks)
	; doc: @returns        bool   1 iff globals, XPAR params and tasks are all clean
	; doc: Globals (cache + control state) are checked on any engine; the XPAR-param
	; doc: and task legs are fenced VistA seams — a bare engine reports them clean.
	; doc: @example      kill ^XTMP("VSLTAP"),^VSLTAP do true^STDASSERT(.pass,.fail,$$verifyClean^VSLTAPBO(.detail),"verifyClean: an empty system verifies clean")
	new ok
	kill detail
	set ok=1
	if $data(^XTMP("VSLTAP"))!$data(^VSLTAP) set detail("globals")="^XTMP(""VSLTAP"") / ^VSLTAP control state survives",ok=0
	if $$paramsResidue(.detail) set ok=0
	if $$tasksResidue(.detail) set ok=0
	quit ok
	;
paramsResidue(detail)	; (private) 1 iff any tap #8989.51 definition survives (fenced; bare -> 0).
	; doc: @icr DBS @call $$FIND1^DIC @status Supported @custodian DI @source DI/fm22_2dg#find1dic-finder-single-record
	; doc: @example      do eq^STDASSERT(.pass,.fail,$$paramsResidue^VSLTAPBO(.detail),0,"paramsResidue: a bare engine (no FileMan) reports no surviving XPAR definitions")
	new $etrap,out,n,i,found
	set $etrap="set $ecode="""" quit"
	set found=0
	if $text(FIND1^DIC)="" quit 0
	set n=$$params(.out)
	for i=1:1:n if +$$FIND1^DIC(8989.51,"","X",out(i),"B")>0 set found=found+1
	if found set detail("params")=found_" tap XPAR parameter definition(s) survive"
	quit ''found
	;
tasksResidue(detail)	; (private) 1 iff a recorded flush/fidelity task record survives.
	new found
	set found=($order(^VSLTAP("task",""))'="")
	if found set detail("tasks")="a scheduled task record survives"
	quit found
