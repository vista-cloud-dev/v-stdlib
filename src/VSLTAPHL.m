VSLTAPHL	; v-stdlib — tap health instrument + standby readiness (the watchdog).
	;
	; The always-on instrument behind the tap (spec §6.2/§6.4/§8/§8.1): cheap
	; counters/timers, the A/B latency watchdog that FEEDS auto-failover, and the
	; standby readiness probe + synthetic canary that prove a gated, idle tap is
	; healthy — NOT dead. On for both regimes (tap on/off); the counters make the
	; always-on capture tax visible in real time even with no consumer.
	;
	; Layer: v. Consumes the VSLTAP core (v->v: cfg/disable/heartbeat/healthy). No
	; egress in Phase 2 — the readiness "egress ping" reduces to the substrate +
	; fence checks; the real S3 HEAD ping is the Phase-3 consumer-presence wiring.
	;
	; Counters (^VSLTAP("hl",…) — VSL namespace):
	;   writes  captured-record count        bytes  bytes-to-buffer
	;   denied  consumer-gate denials         s,i    bounded latency-sample window
	;
	; Public API:
	;   do record(us,bytes,denied)   record one capture sample (us=0 -> count only, no latency)
	;   $$writes() / $$bytes() / $$denied()    counter reads
	;   $$pctl(p)                    p-th percentile capture latency (nearest-rank)
	;   $$abcheck(base,tapped)       1 iff tapped-base exceeds the D-7 latency bound
	;   do watchLatency(base,tapped) trip auto-failover OFF on a latency-delta breach
	;   $$ready()                    standby readiness probe (idle -> provably healthy)
	;   $$canary()                   synthetic byte-exact round-trip through ^XTMP (no real RPC)
	;   do beat()                    update the liveness heartbeat
	;
	quit
	;
	; ---------- counters ----------
	;
record(us,bytes,denied)	; Record one capture sample: a denial, or a write (+bytes, +optional latency).
	; doc: @param us      numeric  capture latency in microseconds (0 -> no latency sample)
	; doc: @param bytes   numeric  bytes copied into the buffer
	; doc: @param denied  bool     1 iff the consumer-gate denied this capture (no write)
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") do record^VSLTAPHL(120,50,0),record^VSLTAPHL(80,40,0),record^VSLTAPHL(0,0,1) do eq^STDASSERT(.pass,.fail,$$writes^VSLTAPHL(),2,"two capture writes counted (the denied sample is not a write)")
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") do record^VSLTAPHL(120,50,0),record^VSLTAPHL(80,40,0) do eq^STDASSERT(.pass,.fail,$$bytes^VSLTAPHL(),90,"bytes-to-buffer summed across writes")
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") do record^VSLTAPHL(0,0,1) do eq^STDASSERT(.pass,.fail,$$denied^VSLTAPHL(),1,"one consumer-gate denial counted")
	new b
	if +$get(denied) do incr("denied") quit
	do incr("writes")
	set b=+$get(bytes)
	set ^VSLTAP("hl","bytes")=+$get(^VSLTAP("hl","bytes"))+b
	if +$get(us)>0 do sample(+us)
	quit
	;
incr(k)	; (private) increment counter ^VSLTAP("hl",k).
	set ^VSLTAP("hl",k)=+$get(^VSLTAP("hl",k))+1
	quit
	;
sample(us)	; (private) append a latency sample into a bounded window for percentiles.
	new n,cap
	set cap=200
	set n=+$get(^VSLTAP("hl","scount"))+1
	set ^VSLTAP("hl","scount")=n
	set ^VSLTAP("hl","s",((n-1)#cap)+1)=us
	quit
	;
writes()	; Captured-record count.
	quit +$get(^VSLTAP("hl","writes"))
	;
bytes()	; Bytes-to-buffer count.
	quit +$get(^VSLTAP("hl","bytes"))
	;
denied()	; Consumer-gate denial count.
	quit +$get(^VSLTAP("hl","denied"))
	;
pctl(p)	; The p-th percentile (nearest-rank) of the latency-sample window; 0 if none.
	; doc: @param p   numeric  percentile 0..100
	; doc: @returns   numeric  the nearest-rank sample value
	; doc: @example   new i kill ^VSLTAP,^XTMP("VSLTAP") for i=1:1:100 do record^VSLTAPHL(i,1,0)  do true^STDASSERT(.pass,.fail,($$pctl^VSLTAPHL(50)'<1)&($$pctl^VSLTAPHL(50)'>100),"p50 of 1..100 falls within [1,100]")
	; doc: @example   new i kill ^VSLTAP,^XTMP("VSLTAP") for i=1:1:100 do record^VSLTAPHL(i,1,0)  do true^STDASSERT(.pass,.fail,$$pctl^VSLTAPHL(95)'<$$pctl^VSLTAPHL(50),"p95 >= p50 (percentiles are monotonic)")
	new j,cnt,tmp,idx,acc,res,v,done,cap,sc
	set cap=200
	set sc=+$get(^VSLTAP("hl","scount"))
	set cnt=$select(sc>cap:cap,1:sc)
	if 'cnt quit 0
	for j=1:1:cnt do tally(.tmp,+$get(^VSLTAP("hl","s",j)))
	set idx=$$ceil((p*cnt)/100)
	if idx<1 set idx=1
	set acc=0,res=0,v="",done=0
	for  quit:done  do walk(.tmp,.v,.acc,.res,.done,idx)
	quit res
	;
tally(tmp,v)	; (private) bucket one sample value into the value-keyed multiset.
	set tmp(v)=+$get(tmp(v))+1
	quit
	;
walk(tmp,v,acc,res,done,idx)	; (private) advance in value order, accumulating counts to the nearest rank.
	set v=$order(tmp(v))
	if v="" set done=1 quit
	set acc=acc+tmp(v),res=v
	if acc'<idx set done=1
	quit
	;
ceil(x)	; (private) integer ceiling of a non-negative number.
	quit (x\1)+((x>(x\1)))
	;
	; ---------- the A/B latency watchdog (feeds auto-failover) ----------
	;
abcheck(base,tapped)	; 1 iff (tapped - base) exceeds the pre-registered D-7 latency bound.
	; doc: @param base    numeric  baseline (tap OFF) latency
	; doc: @param tapped  numeric  tapped (tap ON) latency
	; doc: @returns bool   the exact signal the §6.2 watchdog trips on
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") set ^VSLTAP("cfg","latbound")=100 do eq^STDASSERT(.pass,.fail,$$abcheck^VSLTAPHL(10,60),0,"tapped-base=50 <= 100 bound -> clean")
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") set ^VSLTAP("cfg","latbound")=100 do eq^STDASSERT(.pass,.fail,$$abcheck^VSLTAPHL(10,510),1,"tapped-base=500 > 100 bound -> trip")
	quit ((+tapped-+base)>+$$cfg^VSLTAP("latbound",250))
	;
watchLatency(base,tapped)	; Trip auto-failover OFF when the tapped-vs-baseline delta breaches the bound.
	; doc: @param base    numeric  baseline (tap OFF) latency
	; doc: @param tapped  numeric  tapped (tap ON) latency
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),setConsumer^VSLTAP(1) set ^VSLTAP("cfg","latbound")=100 do watchLatency^VSLTAPHL(10,10) do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"","a within-bound sample does not disable the tap")
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),setConsumer^VSLTAP(1) set ^VSLTAP("cfg","latbound")=100 do watchLatency^VSLTAPHL(10,500) do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"latency","an over-bound sample self-disables with reason latency")
	if $$abcheck(.base,.tapped) do disable^VSLTAP("latency")
	quit
	;
beat()	; Update the liveness heartbeat (the watchdog's k8s-style liveness beat).
	do heartbeat^VSLTAP()
	quit
	;
	; ---------- standby readiness (idle != dead, §8.1) ----------
	;
ready()	; Standby readiness probe: 1 iff a gated/idle tap COULD capture if a consumer appeared.
	; doc: @returns bool  checks (1) armed (2) not auto-disabled (3) heartbeat fresh
	; doc: (4) the ^XTMP capture substrate is writable. Egress HEAD ping is Phase 3.
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),beat^VSLTAPHL() do true^STDASSERT(.pass,.fail,$$ready^VSLTAPHL()=1,"readiness probe green while idle (substrate writable, fence armed, heartbeat fresh)")
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),beat^VSLTAPHL() set ^VSLTAP("hb")=0 do true^STDASSERT(.pass,.fail,$$ready^VSLTAPHL()=0,"a stale heartbeat flips readiness red even with zero traffic")
	if $$cfg^VSLTAP("mode","off")'="armed" quit 0
	if $$disabled^VSLTAP()'="" quit 0
	if '$$healthy^VSLTAP() quit 0
	if '$$substrateWritable() quit 0
	quit 1
	;
substrateWritable()	; (private) prove the ^XTMP capture substrate is writable, fenced, leaving no trace.
	new ok,$etrap
	set ok=1
	set $etrap="set ok=0,$ecode="""" quit"
	set ^XTMP("VSLTAP","probe")=$job
	if +$get(^XTMP("VSLTAP","probe"))'=$job set ok=0
	kill ^XTMP("VSLTAP","probe")
	quit ok
	;
canary()	; Synthetic byte-exact round-trip of a tagged record through ^XTMP — touches no real RPC.
	; doc: @returns bool  1 iff the capture substrate round-trips byte-exact on standby
	; doc: Proves capture works while idle without perturbing the ring (the §8.1
	; doc: synthetic monitor; the §15 harness run with a one-record corpus).
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),beat^VSLTAPHL() do true^STDASSERT(.pass,.fail,$$canary^VSLTAPHL()=1,"canary proves capture-substrate works on standby (byte-exact round-trip)")
	; doc: @example   kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),beat^VSLTAPHL() set %=$$canary^VSLTAPHL() do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"the canary leaves the real ring empty (no clinical-traffic perturbation)")
	new tag,rb,ok,$etrap
	set ok=1
	set $etrap="set ok=0,$ecode="""" quit"
	set tag="VSLTAP-CANARY^"_$job_"^heartbeat"
	set ^XTMP("VSLTAP","canary")=tag
	set rb=$get(^XTMP("VSLTAP","canary"))
	kill ^XTMP("VSLTAP","canary")
	if 'ok quit 0
	quit (rb=tag)
