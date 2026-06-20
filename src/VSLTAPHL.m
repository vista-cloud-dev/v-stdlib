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
	quit ((+tapped-+base)>+$$cfg^VSLTAP("latbound",250))
	;
watchLatency(base,tapped)	; Trip auto-failover OFF when the tapped-vs-baseline delta breaches the bound.
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
	new tag,rb,ok,$etrap
	set ok=1
	set $etrap="set ok=0,$ecode="""" quit"
	set tag="VSLTAP-CANARY^"_$job_"^heartbeat"
	set ^XTMP("VSLTAP","canary")=tag
	set rb=$get(^XTMP("VSLTAP","canary"))
	kill ^XTMP("VSLTAP","canary")
	if 'ok quit 0
	quit (rb=tag)
