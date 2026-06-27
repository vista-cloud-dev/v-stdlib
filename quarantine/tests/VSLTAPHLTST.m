VSLTAPHLTST	; v-stdlib — VSLTAPHL (health instrument + standby readiness) test suite.
	; The always-on counters/percentiles, the A/B latency watchdog that feeds
	; auto-failover (spec §6.2/§8), and the standby readiness probe + synthetic
	; canary that prove a gated, idle tap is healthy — not dead (spec §8.1, exit
	; e). Bare engine, no egress:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPHLTST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPHLTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tCountersAccumulate(.pass,.fail)
	do tPercentilesBounded(.pass,.fail)
	do tAbWatchdogTripsOnBreach(.pass,.fail)
	do tWatchLatencyDisablesTap(.pass,.fail)
	do tStandbyReadyWhileIdle(.pass,.fail)
	do tCanaryRoundTrips(.pass,.fail)
	do tStaleHeartbeatNotReady(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
reset()	; (private) wipe all tap state
	kill ^VSLTAP,^XTMP("VSLTAP")
	quit
	;
tCountersAccumulate(pass,fail)	;@TEST "record() accumulates capture-writes, bytes and denied counters"
	do reset()
	do record^VSLTAPHL(120,50,0)
	do record^VSLTAPHL(80,40,0)
	do record^VSLTAPHL(0,0,1)
	do eq^STDASSERT(.pass,.fail,$$writes^VSLTAPHL(),2,"two capture writes counted (the denied sample is not a write)")
	do eq^STDASSERT(.pass,.fail,$$bytes^VSLTAPHL(),90,"bytes-to-buffer summed")
	do eq^STDASSERT(.pass,.fail,$$denied^VSLTAPHL(),1,"one consumer-gate denial counted")
	quit
	;
tPercentilesBounded(pass,fail)	;@TEST "latency percentiles are monotonic and within the observed sample range"
	new i,p50,p95
	do reset()
	for i=1:1:100 do record^VSLTAPHL(i,1,0)
	set p50=$$pctl^VSLTAPHL(50)
	set p95=$$pctl^VSLTAPHL(95)
	do true^STDASSERT(.pass,.fail,(p50'<1)&(p50'>100),"p50 within [1,100]")
	do true^STDASSERT(.pass,.fail,p95'<p50,"p95 >= p50 (monotonic)")
	do true^STDASSERT(.pass,.fail,(p95'<90)&(p95'>100),"p95 near the top of the range")
	quit
	;
tAbWatchdogTripsOnBreach(pass,fail)	;@TEST "A/B watchdog: within-bound delta is clean; an over-bound delta trips"
	do reset()
	set ^VSLTAP("cfg","latbound")=100
	do eq^STDASSERT(.pass,.fail,$$abcheck^VSLTAPHL(10,60),0,"tapped-base=50 <= 100 bound -> clean")
	do eq^STDASSERT(.pass,.fail,$$abcheck^VSLTAPHL(10,510),1,"tapped-base=500 > 100 bound -> trip")
	quit
	;
tWatchLatencyDisablesTap(pass,fail)	;@TEST "watchLatency() trips auto-failover OFF on a latency-delta breach (exit b)"
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","latbound")=100
	do watchLatency^VSLTAPHL(10,10)
	do true^STDASSERT(.pass,.fail,$$disabled^VSLTAP()="","a within-bound sample does not disable the tap")
	do watchLatency^VSLTAPHL(10,500)
	do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"latency","an over-bound sample self-disables with reason latency")
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"AUTO-DISABLED","state -> AUTO-DISABLED")
	quit
	;
tStandbyReadyWhileIdle(pass,fail)	;@TEST "standby readiness: a gated idle tap probes ready=1 (ARMED-IDLE, healthy) (exit e)"
	do reset()
	do arm^VSLTAP(),beat^VSLTAPHL()
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"ARMED-IDLE","idle + healthy -> ARMED-IDLE")
	do true^STDASSERT(.pass,.fail,$$ready^VSLTAPHL()=1,"readiness probe green while idle (substrate writable, fence armed, heartbeat fresh)")
	quit
	;
tCanaryRoundTrips(pass,fail)	;@TEST "synthetic canary round-trips a tagged record through ^XTMP byte-exact, touching no real ring entries"
	do reset()
	do arm^VSLTAP(),beat^VSLTAPHL()
	do true^STDASSERT(.pass,.fail,$$canary^VSLTAPHL()=1,"canary proves capture-substrate works on standby (byte-exact)")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"the canary leaves the real ring empty (no clinical-traffic perturbation)")
	quit
	;
tStaleHeartbeatNotReady(pass,fail)	;@TEST "a stale heartbeat flips readiness red even with zero traffic (liveness vs readiness)"
	do reset()
	do arm^VSLTAP(),beat^VSLTAPHL()
	set ^VSLTAP("hb")=0
	do true^STDASSERT(.pass,.fail,$$ready^VSLTAPHL()=0,"stale heartbeat -> not ready")
	quit
