VSLTAPBENCHTST	; v-stdlib — VSLTAP 3-arm non-interference benchmark (THE gate, exit a).
	; Proves the tapped RPC-dispatch path is indistinguishable from baseline
	; within the pre-registered D-7 latency bound (spec §6.4/§7). Three arms over
	; one fixed synthetic-dispatch workload, timed with the portable STDPROF
	; microsecond clock (v->m): (1) tap OFF baseline; (2) tap ON + consumer
	; present; (3) tap ON, NO consumer (FU-9: the ring captures anyway). The added
	; per-op cost of the tee (arm-baseline) must stay under the bound, on small AND
	; large payloads — a blocking/IO regression (ms-scale) or an O(n^2) copy would
	; blow it. Plus a kill-switch-idle arm (gate OFF -> zero capture/cost) and a unit
	; us/SET microbench.
	; Runs as a `make ci` gate on BARE engines, both YDB and IRIS:
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPBENCHTST.m
	;   m test --engine iris --docker m-test-iris \
	;     --routines src --routines <m-stdlib>/src tests/VSLTAPBENCHTST.m
	;
	; Pre-registered bounds (generous for a shared CI host's ~1ms clock noise,
	; yet tight enough to catch any blocking/IO/quadratic regression):
	;   N small=2000  payload~40B   LATBOUND   = 250 us / op
	;   N large=400   payload~50KB  LATBOUNDBIG = 2500 us / op
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tSmallPayloadWithinBound(.pass,.fail)
	do tLargePayloadCopyCostBounded(.pass,.fail)
	do tKillSwitchIdleIsNearZero(.pass,.fail)
	do tMicrobenchPerSet(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
reset()	; (private) wipe all tap state
	kill ^VSLTAP,^XTMP("VSLTAP")
	quit
	;
dispatch(i)	; (private) a fixed synthetic RPC-dispatch workload (the thing we must not perturb)
	new s,k
	set s=0
	for k=1:1:8 set s=s+(i*k)
	quit s
	;
runArm(mode,n,payload)	; (private) time n dispatches under `mode`; return total elapsed us
	; mode: "off" baseline (no tee) | "tee" dispatch + capture (consumer present) |
	;       "alwayson" tee with NO consumer (FU-9: the ring captures anyway) |
	;       "killed" tee called but the kill-switch is OFF (near-zero gated path)
	new i,t0,t1
	do reset()
	if mode="tee" do arm^VSLTAP(),setConsumer^VSLTAP(1)
	if mode="alwayson" do arm^VSLTAP()
	if mode="killed" do arm^VSLTAP(),off^VSLTAP()
	; warm-up (compilation / global allocation) outside the timed window
	for i=1:1:50 do oneIter(mode,i,payload)
	set t0=$$nowMicros^STDPROF()
	for i=1:1:n do oneIter(mode,i,payload)
	set t1=$$nowMicros^STDPROF()
	quit t1-t0
	;
oneIter(mode,i,payload)	; (private) one synthetic dispatch; the tee runs on every non-baseline arm
	new d
	set d=$$dispatch(i)
	if mode'="off" do capture^VSLRPCTAP(payload)
	quit
	;
tSmallPayloadWithinBound(pass,fail)	;@TEST "3-arm: tap ON (consumer) and ON (always-on) add < 250 us/op vs baseline on a small payload (exit a)"
	new n,pay,base,onc,ona,ovc,ova
	set n=2000
	set pay="ORWU DT^DUZ=10^FMNOW^arg2^arg3"
	set base=$$runArm("off",n,pay)
	set onc=$$runArm("tee",n,pay)
	set ona=$$runArm("alwayson",n,pay)
	set ovc=(onc-base)/n
	set ova=(ona-base)/n
	do true^STDASSERT(.pass,.fail,ovc'>250,"ON+consumer per-op overhead "_ovc_"us <= 250us bound")
	do true^STDASSERT(.pass,.fail,ova'>250,"ON+always-on per-op overhead "_ova_"us <= 250us bound")
	quit
	;
tLargePayloadCopyCostBounded(pass,fail)	;@TEST "large ~50KB payload: the verbatim copy stays bounded (< 2500 us/op), proving O(size) not exploding"
	new n,big,k,base,on,ov
	set n=400
	set big=""
	for k=1:1:1000 set big=big_"0123456789ABCDEFGHIJ0123456789ABCDEFGHIJ0123456789"
	set ^VSLTAP("cfg","maxbytes")=200000
	set base=$$runArm("off",n,big)
	set on=$$runArm("tee",n,big)
	set ov=(on-base)/n
	do true^STDASSERT(.pass,.fail,$length(big)'<50000,"payload is ~50KB ("_$length(big)_" bytes)")
	do true^STDASSERT(.pass,.fail,ov'>2500,"large-payload per-op overhead "_ov_"us <= 2500us bound")
	quit
	;
tKillSwitchIdleIsNearZero(pass,fail)	;@TEST "kill-switch idle: a tee call with the gate OFF is ~0 cost, no append, no counters (FU-9: the near-zero idle path is the OFF gate, not 'no consumer')"
	new n,pay,base,gated,ov
	set n=2000
	set pay="ORWU DT^DUZ=10^FMNOW"
	set base=$$runArm("off",n,pay)
	set gated=$$runArm("killed",n,pay)
	set ov=(gated-base)/n
	do true^STDASSERT(.pass,.fail,ov'>250,"kill-switch idle per-op overhead "_ov_"us <= 250us bound (one $G short-circuit)")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"kill-switch idle captured nothing (gate OFF)")
	do eq^STDASSERT(.pass,.fail,$$writes^VSLTAPHL(),0,"kill-switch idle bumped no capture counters")
	quit
	;
tMicrobenchPerSet(pass,fail)	;@TEST "unit microbench: one verbatim ^XTMP append is cheap (< 250 us), the unit the aggregate is built from"
	new n,pay,i,t0,t1,per,rc
	set n=2000
	set pay="0123456789ABCDEF0123456789ABCDEF"
	do reset()
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","cap")=100000
	for i=1:1:50 set rc=$$append^VSLTAP(pay)
	set t0=$$nowMicros^STDPROF()
	for i=1:1:n set rc=$$append^VSLTAP(pay)
	set t1=$$nowMicros^STDPROF()
	set per=(t1-t0)/n
	do true^STDASSERT(.pass,.fail,per'>250,"per-append cost "_per_"us <= 250us")
	quit
