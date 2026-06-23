VSLTAP	; v-stdlib — non-interference traffic-tap core (the safety gate).
	;
	; Phase 2 / M1 of the RPC+HL7 -> S3 traffic tap (spec §6/§4.1). VSLTAP is the
	; load-bearing capture core everything downstream waits behind. Its whole job
	; is to be INVISIBLE to the clinical RPC flow it observes: a bounded, rolling
	; ^XTMP ring filled by an irreducible memory-copy append, gated three ways
	; (operator kill-switch / consumer-presence / always-on opt-in), fenced so any
	; fault self-disables instead of touching the caller, and watched so ANY
	; interference signal flips the tap OFF automatically (fail-safe-OFF).
	;
	; *** Layer: v (above the m/v waterline). It touches ^XTMP (Kernel's SAC-
	; sanctioned scratch global) and consumes `m` utilities DOWN (STDDATE for the
	; FileMan purge-date); it never inverts the dependency. The egress/VistA
	; bindings (XPAR config source, VSLRPC chokepoint, Kernel XQ82 purge schedule)
	; are SEAMS, not Phase-2 dependencies — so the gate runs on a BARE engine with
	; no VistA and no S3 (kickoff). Config/state ride in ^VSLTAP (small control
	; state); the rolling capture cache rides in ^XTMP("VSLTAP",…) (the auto-
	; purged scratch global, §4.1.1 — no FileMan file).
	;
	; Capture buffer (the rolling "flight recorder", §4.1, Option A / D-10):
	;   ^XTMP("VSLTAP",0)            purgedate^createdate^description (Kernel XQ82)
	;   ^XTMP("VSLTAP","head")       highest written seq
	;   ^XTMP("VSLTAP","tail")       (lowest-retained seq) - 1
	;   ^XTMP("VSLTAP","data",seq)   the verbatim record (no transform)
	;
	; Control state (^VSLTAP — VSL namespace):
	;   ^VSLTAP("cfg",key)           mode/consumer/alwayson/cap/maxbytes/latbound/…
	;   ^VSLTAP("disabled")          auto-failover reason, else absent
	;   ^VSLTAP("hb")                liveness heartbeat ($H)
	;   ^VSLTAP("_offwindows")       count; (,n)=open^reason^close (explicit, never silent)
	;   ^VSLTAP("hl",…)              health counters/samples (VSLTAPHL)
	;   ^VSLTAP("fc","last")         last fidelity manifest line (VSLTAPFC persist)
	;
	; Public API:
	;   $$enabled^VSLTAP()           1 iff capture should run now (the one gate)
	;   $$append^VSLTAP(rec)         gated memory-copy append -> 1 captured / 0 not
	;   $$tee^VSLTAP(rec)            fault-fenced $$append (used by VSLRPCTAP)
	;   $$size^VSLTAP() / $$head() / $$tail() / $$read(seq)   ring inspection
	;   $$state^VSLTAP()             OFF | ARMED-IDLE | ACTIVE | AUTO-DISABLED | UNHEALTHY
	;   $$disabled^VSLTAP()          auto-failover reason or ""
	;   do arm() / off() / setConsumer(b) / setAlwaysOn(b)   operator/gate controls
	;   do disable(reason) / rearm()  auto-failover OFF / re-arm (records _offwindows)
	;   do heartbeat() / $$healthy()  liveness
	;   do purgeNode()               write the Kernel auto-purge node
	;   $$cfg(key,default)           read a config knob (consumed by VSLTAPHL)
	;   $$offWindows(.out)           recorded off-windows -> count
	;
	quit
	;
	; ---------- config ----------
	;
cfg(key,default)	; Read a config knob from ^VSLTAP("cfg",key), else `default`.
	; doc: @param key      string  config key (mode/consumer/alwayson/cap/maxbytes/latbound/hbstale/retain)
	; doc: @param default  string  value when unset
	; doc: @returns        string  the configured value or the default
	quit $get(^VSLTAP("cfg",key),default)
	;
arm()	; Operator: arm the tap (kill-switch ON) and clear any prior auto-disable.
	set ^VSLTAP("cfg","mode")="armed"
	kill ^VSLTAP("disabled")
	quit
	;
off()	; Operator: kill-switch OFF (state OFF; capture cannot run).
	set ^VSLTAP("cfg","mode")="off"
	quit
	;
setConsumer(present)	; Set the consumer-presence flag (D-5): no consumer -> egress/capture OFF.
	set ^VSLTAP("cfg","consumer")=+$get(present)
	quit
	;
setAlwaysOn(flag)	; Opt-in always-on flight-recorder (D-8): capture even with no consumer.
	set ^VSLTAP("cfg","alwayson")=+$get(flag)
	quit
	;
	; ---------- the capture gate + the rolling ring ----------
	;
enabled()	; 1 iff capture should run now: armed AND not auto-disabled AND (consumer OR always-on).
	; doc: @returns bool  the single capture gate (fail-safe-OFF; consumer-gated default, D-8)
	if $$cfg("mode","off")'="armed" quit 0
	if $$disabled()'="" quit 0
	if +$$cfg("consumer",0) quit 1
	if +$$cfg("alwayson",0) quit 1
	quit 0
	;
append(rec)	; Gated, fault-fenced, bounded memory-copy append of a verbatim record.
	; doc: @param rec   string  the verbatim payload (no parse, no transform — D-1)
	; doc: @returns bool 1 iff captured; 0 iff gated, auto-disabled, copy-cost-tripped, or fenced
	; doc: The ONLY in-path op (besides the $G gate): one global SET + bounded trim.
	; doc: No LOCK, no serialize, no socket, no I/O, no block (§6.1). Self-fenced:
	; doc: ANY fault inside the write self-disables and returns 0 — never the caller.
	; doc: Flag-based $ETRAP (ISO, dual-engine; NEVER zgoto, the M4 resident-harness
	; doc: gotcha). The write runs in a DO-invoked frame (write1) so the trap's
	; doc: argument-less QUIT is legal — an arg-less QUIT trap fired in an extrinsic
	; doc: ($$) frame raises M17 NOTEXTRINSIC (per STDASSERT raises()).
	new ok,$etrap,wrote
	if '$$enabled() quit 0
	set ok=1,wrote=0
	set $etrap="set ok=0,$ecode="""" quit"
	do write1(rec,.wrote)
	if ok quit wrote
	set $etrap=""
	do disable("fault")
	quit 0
	;
write1(rec,wrote)	; (private) the ring write, DO-invoked so the append fence's QUIT is legal.
	; doc: @param rec    string  the verbatim payload
	; doc: @param wrote  bool    by-ref; set 1 iff the record was appended
	new seq,cap
	; fault-injection seam — the §6.2 "injected deviation" exit-gate (b) lever.
	if +$$cfg("faultinject",0) set $ecode=",U-VSLTAP-INJECT,"
	; copy-cost guard (§6.2): a pathological mega-payload trips auto-failover OFF.
	if $length(rec)>+$$cfg("maxbytes",1000000) do disable("copycost") quit
	set cap=+$$cfg("cap",1000)
	set seq=+$get(^XTMP("VSLTAP","head"))+1
	set ^XTMP("VSLTAP","data",seq)=rec
	; FU-4 post-write fault-injection seam: fire AFTER the ring SET so the fence
	; property suite (VSLTAPFENCETST) proves the naked-reference restore even once
	; the tap has dirtied the caller's indicator (AC-1). Inert unless configured.
	if +$$cfg("faultinjectpost",0) set $ecode=",U-VSLTAP-INJECTPOST,"
	set ^XTMP("VSLTAP","head")=seq
	do trim(seq,cap)
	do record^VSLTAPHL(0,$length(rec),0)
	set wrote=1
	quit
	;
trim(seq,cap)	; (private) overwrite-oldest: drop entries until the ring holds at most `cap`.
	new t
	set t=+$get(^XTMP("VSLTAP","tail"))
	for  quit:(seq-t)'>cap  do dropOldest(.t)
	set ^XTMP("VSLTAP","tail")=t
	quit
	;
dropOldest(t)	; (private) drop the oldest retained entry and advance the tail cursor.
	set t=t+1
	kill ^XTMP("VSLTAP","data",t)
	quit
	;
tee(rec)	; The named capture seam the VSLRPC chokepoint calls (VSLRPCTAP) — fenced.
	; doc: @param rec   string  the verbatim payload
	; doc: @returns bool the $$append result (0 if gated or a fault was fenced)
	; doc: $$append is already self-fenced (a DO-framed $ETRAP that self-disables on
	; doc: any fault); tee is the stable adapter entry. Either leaves the caller's
	; doc: result / $ECODE / $T untouched.
	quit $$append(rec)
	;
size()	; Current ring entry count (head - tail).
	quit +$get(^XTMP("VSLTAP","head"))-+$get(^XTMP("VSLTAP","tail"))
	;
head()	; Highest written seq (0 if empty).
	quit +$get(^XTMP("VSLTAP","head"))
	;
tail()	; (lowest-retained seq) - 1 (0 if empty).
	quit +$get(^XTMP("VSLTAP","tail"))
	;
read(seq)	; The verbatim record at `seq`, or "" if absent/overwritten.
	quit $get(^XTMP("VSLTAP","data",+$get(seq)))
	;
drainTo(seq)	; Post-ship trim: drop retained entries up to and including `seq`, advance tail.
	; doc: @param seq  numeric  the highest shipped sequence (bounded to head)
	; doc: @returns    void     the drain self-KILLs shipped entries (spec §4.1.3)
	; doc: Called by the SEPARATE flush process (VSLS3 $$drain) AFTER a batch ships
	; doc: 200 — never from the RPC path. Idempotent; never advances past head.
	new t,h
	set h=+$get(^XTMP("VSLTAP","head"))
	if +$get(seq)>h set seq=h
	set t=+$get(^XTMP("VSLTAP","tail"))
	for  quit:t'<+$get(seq)  do dropOldest(.t)
	set ^XTMP("VSLTAP","tail")=t
	quit
	;
	; ---------- auto-failover + state machine ----------
	;
disable(reason)	; Auto-failover: disable the tap, record an off-window (explicit, never silent).
	; doc: @param reason  string  the interference signal (fault/copycost/latency/pressure)
	new n
	if $get(^VSLTAP("disabled"))'="" quit
	set ^VSLTAP("disabled")=reason
	set n=+$get(^VSLTAP("_offwindows"))+1
	set ^VSLTAP("_offwindows")=n
	set ^VSLTAP("_offwindows",n)=$horolog_"^"_reason_"^"
	quit
	;
disabled()	; The auto-failover reason, or "" if armed/clean.
	quit $get(^VSLTAP("disabled"))
	;
rearm()	; Re-arm after a clean cool-down (D-4): clear the disable + close the off-window.
	new n
	kill ^VSLTAP("disabled")
	set n=+$get(^VSLTAP("_offwindows"))
	if n,$piece($get(^VSLTAP("_offwindows",n)),"^",3)="" set $piece(^VSLTAP("_offwindows",n),"^",3)=$horolog
	quit
	;
offWindows(out)	; Populate out(1..N) with the recorded off-windows; return the count.
	; doc: @param out  array  by-ref; killed then filled with open^reason^close rows
	new n,i
	kill out
	set n=+$get(^VSLTAP("_offwindows"))
	for i=1:1:n set out(i)=$get(^VSLTAP("_offwindows",i))
	quit n
	;
state()	; The standby state-machine label (spec §8.1).
	; doc: @returns string OFF | AUTO-DISABLED | UNHEALTHY | ACTIVE | ARMED-IDLE
	if $$cfg("mode","off")'="armed" quit "OFF"
	if $$disabled()'="" quit "AUTO-DISABLED"
	if '$$healthy() quit "UNHEALTHY"
	if $$enabled() quit "ACTIVE"
	quit "ARMED-IDLE"
	;
	; ---------- liveness ----------
	;
heartbeat()	; Stamp the liveness heartbeat (the watchdog beats this every N seconds).
	set ^VSLTAP("hb")=$horolog
	quit
	;
healthy()	; 1 iff the heartbeat is fresh within the staleness bound (k8s-style liveness).
	; doc: @returns bool  a stale/absent heartbeat -> 0 (UNHEALTHY) even with zero traffic
	new hb,age,now
	set hb=$get(^VSLTAP("hb"))
	if hb="" quit 0
	set now=$horolog
	set age=(($piece(now,",",1)-$piece(hb,",",1))*86400)+($piece(now,",",2)-$piece(hb,",",2))
	quit (age'>+$$cfg("hbstale",60))
	;
	; ---------- Kernel auto-purge node (the cache backstop) ----------
	;
purgeNode()	; Write ^XTMP("VSLTAP",0)=purgedate^createdate^description so Kernel XQ82 reaps it.
	; doc: The SAC ^XTMP convention (XU/krn_8_0_dg_xtmp_global_ug): a ,0) node of
	; doc: FileMan internal dates lets `XQ XUTL $J NODES` auto-purge the cache. No
	; doc: FileMan file (§4.1.1). Scheduling the option is an install-time seam.
	new td,ret
	set ret=+$$cfg("retain",2)
	set td=+$horolog
	set ^XTMP("VSLTAP",0)=$$fmDate(td+ret)_"^"_$$fmDate(td)_"^VSL RPC traffic-tap rolling cache"
	quit
	;
fmDate(hday)	; ($H day-count) -> FileMan internal date (YYYMMDD, YYY=year-1700).
	new z,y,m,d
	set z=hday-47117
	do civilFromDays^STDDATE(z,.y,.m,.d)
	quit ((y-1700)*10000)+(m*100)+d
