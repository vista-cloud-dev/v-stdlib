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
	; bare-proven; the live sampler ($$fidelityNow — LIST shipped objects, read
	; them back, integrity-verify each) is the egress leg that lights the console.
	;
	; Public API:
	;   do run()                     the scheduled task body (gate -> sample -> persist -> re-queue)
	;   $$fidelityNow()              LIST shipped objects -> read back -> integrity-verify -> persist -> matched
	;   $$reconcilePersist(corpus,envs)  reconcile a known corpus then persist it -> ok (the e2e-harness seam)
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
	new $etrap,x
	set $etrap="set $ecode="""" quit"
	if '$$enabled^VSLTAP() quit
	set x=$$fidelityNow()
	do reschedule()
	quit
	;
reschedule()	; (private) re-queue the next periodic run (bare-safe no-op without TaskMan).
	new ztsk
	set ztsk=$$schedule()
	quit
	;
	; ---------- the live fidelity sampler (the source seam that lights the console) ----------
	;
fidelityNow()	; Sample recently-shipped objects, integrity-verify each, persist the result -> matched count.
	; doc: @returns numeric  the count of shipped envelopes whose payload re-hashes to its
	; doc:                   sha256 anchor (round-trip integrity match); -1 if no egress / nothing sampled
	; doc: The PRODUCTION fidelity signal that lights the VWEBT console — it needs no
	; doc: generated corpus and no separate process. It LISTs the per-station shipped
	; doc: objects under `traffic/<station>/<proto>/` (`$$list^VSLS3`), reads each back,
	; doc: and runs `$$verify^VSLTAPFC` on every envelope (the shipped payload re-hashes
	; doc: to the sha256 anchor captured at ship time) -> matched/mismatch. This proves
	; doc: the ship->store->readback path is BYTE-FAITHFUL to what the tap captured —
	; doc: it catches storage / transport / encoding corruption (exactly the egress
	; doc: bugs the build hit). [The deeper capture==wire leg — shipped vs an independent
	; doc: mirror/#772 source — remains a documented future enhancement; the ring is
	; doc: trimmed post-drain so it cannot be that source.] Fenced; persists
	; doc: ^VSLTAP("fc","last"), which VWEBT reads via `$$lastFidelity^VSLTAPFC`.
	new $etrap,ctx,opt,bucket,station,proto,prefix,listing,sc,res,k,cap,seen
	set $etrap="set $ecode="""" quit -1"
	set bucket=$$ctx^VSLS3(.ctx,.opt)
	set station=$$cfg^VSLTAP("s3station",""),proto=$$cfg^VSLTAP("s3proto","rpc")
	set prefix="traffic/"_station_"/"_proto_"/"
	set sc=$$list^VSLS3(.ctx,bucket,prefix,.opt,.listing)
	if sc'=200 quit -1
	set res("matched")=0,res("mismatch")=0,res("missing")=0,res("extra")=0
	set cap=+$$cfg^VSLTAP("fcmax",50)
	set seen=0,k=""
	for  do nextKey(.k,.seen,.listing,.ctx,bucket,.opt,.res) quit:k=""!(seen'<cap)
	if 'res("matched"),'res("mismatch") quit -1
	do persist^VSLTAPFC(.res)
	quit res("matched")
	;
nextKey(k,seen,listing,ctx,bucket,opt,res)	; (private) step to the previous listed subscript; verify its object if it's a real key.
	; doc: The caller's FOR bounds the count (quit:seen'<cap), so no cap check here.
	set k=$order(listing(k),-1)
	if k="" quit
	if $get(listing(k,"key"))="" quit
	do verifyObject(listing(k,"key"),.ctx,bucket,.opt,.res)
	set seen=seen+1
	quit
	;
verifyObject(key,ctx,bucket,opt,res)	; (private) read one shipped object back and integrity-verify each NDJSON envelope line.
	new $etrap,resp,sc,body,i
	set $etrap="set $ecode="""" quit"
	set sc=$$readback^VSLS3(.ctx,bucket,key,.opt,.resp)
	if sc'=200 quit
	set body=$get(resp("body"))
	for i=1:1:$length(body,$char(10)) do tallyLine($piece(body,$char(10),i),.res)
	quit
	;
tallyLine(line,res)	; (private) integrity-verify one envelope line; bump matched / mismatch.
	if line="" quit
	if $$verify^VSLTAPFC(line) set res("matched")=res("matched")+1 quit
	set res("mismatch")=res("mismatch")+1
	quit
