VSLTAPTST	; v-stdlib — VSLTAP non-interference core test suite.
	; The safety gate (spec §6/§4.1): rolling ^XTMP ring (bounded, overwrite-
	; oldest, ,0) purge node), the capture gate (kill-switch / consumer / always-
	; on), the auto-failover watchdog (copy-cost / pressure / disable+rearm with
	; recorded _offwindows), the state machine and the liveness heartbeat.
	; Runs on a BARE engine — no VistA, no egress (kickoff: the gate runs on the
	; test engines):
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPTST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tConsumerGateBlocksAppend(.pass,.fail)
	do tConsumerPresentAppends(.pass,.fail)
	do tAlwaysOnAppendsWithoutConsumer(.pass,.fail)
	do tKillSwitchOffBlocks(.pass,.fail)
	do tRingOverwritesOldest(.pass,.fail)
	do tPurgeNodeShape(.pass,.fail)
	do tCopyCostTripsFailover(.pass,.fail)
	do tStateMachineTransitions(.pass,.fail)
	do tHeartbeatHealthVsUnhealthy(.pass,.fail)
	do tDisableRearmRecordsOffWindow(.pass,.fail)
	do tSeedMapCoversTapAndS3Knobs(.pass,.fail)
	do tSeedIsNoopOnBareEngine(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
reset()	; (private) wipe all tap state for a deterministic test
	kill ^VSLTAP,^XTMP("VSLTAP")
	quit
	;
tConsumerGateBlocksAppend(pass,fail)	;@TEST "consumer-gated default: no consumer -> no append, no growth (D-8, exit c)"
	do reset()
	do arm^VSLTAP()
	do true^STDASSERT(.pass,.fail,$$enabled^VSLTAP()=0,"armed + no consumer + no always-on -> not enabled (fail-safe-OFF)")
	do eq^STDASSERT(.pass,.fail,$$append^VSLTAP("rpc-record"),0,"$$append returns 0 when gated")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"ring stays empty when gated")
	quit
	;
tConsumerPresentAppends(pass,fail)	;@TEST "consumer present -> the verbatim record is appended and reads back byte-exact"
	new rec
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set rec="TST^DUZ=1^arg1^arg2"
	do true^STDASSERT(.pass,.fail,$$enabled^VSLTAP()=1,"armed + consumer present -> enabled")
	do eq^STDASSERT(.pass,.fail,$$append^VSLTAP(rec),1,"$$append returns 1 when active")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"one entry in the ring")
	do eq^STDASSERT(.pass,.fail,$$read^VSLTAP($$head^VSLTAP()),rec,"the stored record is verbatim (no transform)")
	quit
	;
tAlwaysOnAppendsWithoutConsumer(pass,fail)	;@TEST "always-on opt-in: flight-recorder appends even with no consumer"
	do reset()
	do arm^VSLTAP(),setAlwaysOn^VSLTAP(1)
	do true^STDASSERT(.pass,.fail,$$enabled^VSLTAP()=1,"armed + always-on -> enabled without a consumer")
	do eq^STDASSERT(.pass,.fail,$$append^VSLTAP("x"),1,"always-on append succeeds")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"always-on entry recorded")
	quit
	;
tKillSwitchOffBlocks(pass,fail)	;@TEST "operator kill-switch OFF blocks capture even with a consumer present (exit d)"
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1),off^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"OFF","kill-switch -> state OFF")
	do true^STDASSERT(.pass,.fail,$$enabled^VSLTAP()=0,"OFF -> not enabled")
	do eq^STDASSERT(.pass,.fail,$$append^VSLTAP("x"),0,"OFF -> no append")
	quit
	;
tRingOverwritesOldest(pass,fail)	;@TEST "bounded ring overwrites oldest: cap kept, head/tail advance"
	new i,rc
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","cap")=3
	for i=1:1:5 set rc=$$append^VSLTAP("r"_i)
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),3,"ring holds exactly cap=3 entries")
	do eq^STDASSERT(.pass,.fail,$$read^VSLTAP($$head^VSLTAP()),"r5","newest record retained at head")
	do eq^STDASSERT(.pass,.fail,$$read^VSLTAP($$tail^VSLTAP()+1),"r3","oldest retained is r3 (r1,r2 overwritten)")
	do eq^STDASSERT(.pass,.fail,$$read^VSLTAP(1),"","overwritten r1 is gone")
	quit
	;
tPurgeNodeShape(pass,fail)	;@TEST "^XTMP(,0) purge node is purgedate^createdate^description (Kernel XQ82 auto-purge)"
	new node
	do reset()
	do purgeNode^VSLTAP()
	set node=$get(^XTMP("VSLTAP",0))
	do true^STDASSERT(.pass,.fail,$length(node,"^")=3,"purge node has 3 ^-pieces")
	do true^STDASSERT(.pass,.fail,+$piece(node,"^",1)'<+$piece(node,"^",2),"purgedate >= createdate (FileMan internal dates)")
	do true^STDASSERT(.pass,.fail,$piece(node,"^",3)'="","description present")
	quit
	;
tCopyCostTripsFailover(pass,fail)	;@TEST "copy-cost ceiling: a pathological mega-payload trips auto-failover OFF (exit b)"
	new big
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","maxbytes")=16
	set big="0123456789ABCDEF-this-is-over-the-ceiling"
	do eq^STDASSERT(.pass,.fail,$$append^VSLTAP(big),0,"oversized payload is NOT appended")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"ring untouched by the rejected mega-payload")
	do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"copycost","tap self-disabled with reason copycost")
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"AUTO-DISABLED","state -> AUTO-DISABLED")
	do true^STDASSERT(.pass,.fail,$$offWindows^VSLTAP(.big)'<1,"an off-window was recorded (explicit, never silent)")
	quit
	;
tStateMachineTransitions(pass,fail)	;@TEST "state machine: OFF -> ARMED-IDLE -> ACTIVE -> AUTO-DISABLED -> ACTIVE"
	do reset()
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"OFF","unconfigured -> OFF")
	do arm^VSLTAP(),heartbeat^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"ARMED-IDLE","armed, no consumer -> ARMED-IDLE")
	do setConsumer^VSLTAP(1)
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"ACTIVE","consumer present -> ACTIVE")
	do disable^VSLTAP("latency")
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"AUTO-DISABLED","failover -> AUTO-DISABLED")
	do rearm^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"ACTIVE","re-arm after a clean cool-down -> ACTIVE (D-4)")
	quit
	;
tHeartbeatHealthVsUnhealthy(pass,fail)	;@TEST "liveness heartbeat: fresh -> healthy; stale -> UNHEALTHY even with zero traffic (§8.1)"
	do reset()
	do arm^VSLTAP(),heartbeat^VSLTAP()
	do true^STDASSERT(.pass,.fail,$$healthy^VSLTAP()=1,"fresh heartbeat -> healthy")
	set ^VSLTAP("hb")=0
	do true^STDASSERT(.pass,.fail,$$healthy^VSLTAP()=0,"stale heartbeat -> not healthy")
	do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"UNHEALTHY","stale heartbeat -> UNHEALTHY (liveness, not traffic)")
	quit
	;
tDisableRearmRecordsOffWindow(pass,fail)	;@TEST "disable opens an off-window + blocks capture; re-arm closes it + restores capture"
	new n
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	do disable^VSLTAP("pressure")
	do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"pressure","disable records the reason")
	do true^STDASSERT(.pass,.fail,$$enabled^VSLTAP()=0,"auto-disabled -> capture off")
	set n=$$offWindows^VSLTAP(.n)
	do true^STDASSERT(.pass,.fail,n'<1,"off-window opened")
	do rearm^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"","re-arm clears the disable reason")
	do true^STDASSERT(.pass,.fail,$$enabled^VSLTAP()=1,"re-arm restores capture")
	quit
	;
tSeedMapCoversTapAndS3Knobs(pass,fail)	;@TEST "seedMap: maps the installed XPAR params to the ^VSLTAP(""cfg"") keys the tap reads"
	new map,n,i,seen
	set n=$$seedMap^VSLTAP(.map)
	do true^STDASSERT(.pass,.fail,n'<9,"the seed maps the tap + S3 knobs")
	set seen=""
	for i=1:1:n set seen=seen_"|"_map(i,"param")_">"_map(i,"cfg")
	do true^STDASSERT(.pass,.fail,seen["VSL TAP CAP>cap","TAP CAP -> cfg(cap) (the hot-path ring cap)")
	do true^STDASSERT(.pass,.fail,seen["VSL S3 ENDPOINT>s3endpoint","S3 ENDPOINT -> cfg(s3endpoint) (the VSLS3 ctx seam)")
	quit
	;
tSeedIsNoopOnBareEngine(pass,fail)	;@TEST "seed: bare-safe — no XPAR present, it sets no cfg and never aborts"
	do reset()
	do seed^VSLTAP()
	do eq^STDASSERT(.pass,.fail,$data(^VSLTAP("cfg")),0,"with no XPAR the seed is a clean no-op")
	quit
