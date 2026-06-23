VSLS3DRAINTST	; v-stdlib — VSLS3 drain-loop test suite (^XTMP ring -> ship -> trim).
	; Phase 3 / M2, stage 3.1 wiring (spec §4.1.3). The VSLTASK-driven flush:
	; $ORDER the rolling ring into one LDJSON batch, ship it via VSLS3 (the egress
	; transport monopoly), then KILL the shipped entries (self-drain). It is
	; consumer-gated and auto-failover-aware (reuses the Phase-2 VSLTAP gate), and
	; it runs in the SEPARATE flush process — off the RPC CPU. The egress leg is
	; exercised here through a CAPTURE sink seam (the batch body/key are returned
	; in `res`, no real PUT) so the drain/batch/trim/gate logic is proven on a
	; BARE engine; the live PUT round-trip is the integration harness (§15.2):
	;   m test --engine ydb  --docker m-test-engine --chset m \
	;     --routines src --routines <m-stdlib>/src tests/VSLS3DRAINTST.m
	new pass,fail
	do start^STDASSERT(.pass,.fail)
	;
	do tDrainShipsAllInSeqAndTrims(.pass,.fail)
	do tDrainBatchPayloadsByteExact(.pass,.fail)
	do tDrainStopsAtUncommittedGap(.pass,.fail)
	do tDrainConsumerGatedShipsNothing(.pass,.fail)
	do tDrainAutoDisabledShipsNothing(.pass,.fail)
	do tDrainEmptyRing(.pass,.fail)
	do tDrainKeyFollowsLayout(.pass,.fail)
	;
	do report^STDASSERT(pass,fail)
	quit
	;
setup()	; (private) reset tap + ring, arm with a consumer, configure the capture sink.
	kill ^VSLTAP,^XTMP("VSLTAP")
	do arm^VSLTAP(),setConsumer^VSLTAP(1)
	set ^VSLTAP("cfg","s3sink")="capture"
	set ^VSLTAP("cfg","s3bucket")="vista-traffic"
	set ^VSLTAP("cfg","s3station")="500"
	set ^VSLTAP("cfg","s3proto")="rpc"
	quit
	;
fill(n)	; (private) append n verbatim records to the ring (the records fill() mirrors).
	new i,x
	for i=1:1:n set x=$$append^VSLTAP("rec#"_i_$char(1)_"body"_$char(13,10)_i)
	quit
	;
tDrainShipsAllInSeqAndTrims(pass,fail)	;@TEST "drain ships every ring entry once and trims the ring empty"
	new res,n
	do setup()
	do fill(3)
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),3,"ring holds 3 before drain")
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,n,3,"drain reports 3 shipped")
	do eq^STDASSERT(.pass,.fail,res("status"),200,"capture sink returns 200")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"ring is emptied (shipped entries KILLed)")
	quit
	;
tDrainBatchPayloadsByteExact(pass,fail)	;@TEST "the shipped batch is LDJSON: one line per record, payloads byte-exact, in seq"
	new res,body,i,line,rec,n
	do setup()
	do fill(3)
	set n=$$drain^VSLS3(.res)
	set body=res("body")
	do eq^STDASSERT(.pass,.fail,$length(body,$char(10)),4,"3 lines + trailing newline (LDJSON)")
	for i=1:1:3 do
	. set line=$piece(body,$char(10),i)
	. set rec="rec#"_i_$char(1)_"body"_$char(13,10)_i
	. do true^STDASSERT(.pass,.fail,$$matches^VSLTAPFC(line,rec),"batch line "_i_" byte-equals its source record")
	quit
	;
tDrainStopsAtUncommittedGap(pass,fail)	;@TEST "FU-8/FU-9: drain ships only the contiguous committed prefix and never trims an in-flight (head-ahead-of-data) slot"
	new res,n
	do setup()
	do fill(3)
	; simulate the FU-8 window: an appender atomically advanced head to 4 (allocated
	; seq 4 via $INCREMENT) but has NOT yet written ^data(4) — head is ahead of the
	; committed data. A naive drain would ship "" for seq 4 and KILL it.
	set ^XTMP("VSLTAP","head")=4
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,n,3,"shipped only the committed prefix seq 1..3, stopped at the gap")
	do eq^STDASSERT(.pass,.fail,$$head^VSLTAP(),4,"head untouched -> the in-flight seq 4 slot is preserved")
	do eq^STDASSERT(.pass,.fail,$$tail^VSLTAP(),3,"trimmed only to the last committed seq (3), NOT to head")
	do true^STDASSERT(.pass,.fail,'$$present^VSLTAP(4),"seq 4 left uncommitted for the next tick (not shipped as empty)")
	; the in-flight append now lands; the next tick ships it — nothing lost
	set ^XTMP("VSLTAP","data",4)="rec#4-late"
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,n,1,"the late record (seq 4) ships on the next tick — no lost record")
	quit
	;
tDrainConsumerGatedShipsNothing(pass,fail)	;@TEST "consumer-gated: no consumer -> drain ships nothing, ring untouched (D-5)"
	new res,n
	do setup()
	do fill(2)
	; the records are captured while a consumer is present; the consumer then
	; leaves -> the drain must ship nothing and leave the ring intact.
	do setConsumer^VSLTAP(0)
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,n,0,"no consumer -> 0 shipped")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),2,"ring untouched when egress is gated off")
	quit
	;
tDrainAutoDisabledShipsNothing(pass,fail)	;@TEST "auto-failover: a disabled tap -> drain ships nothing (safety > completeness)"
	new res,n
	do setup()
	do fill(2)
	do disable^VSLTAP("test")
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,n,0,"auto-disabled -> 0 shipped")
	do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),2,"ring untouched while auto-disabled")
	quit
	;
tDrainEmptyRing(pass,fail)	;@TEST "drain on an empty ring is a clean no-op (0 shipped)"
	new res,n
	do setup()
	set n=$$drain^VSLS3(.res)
	do eq^STDASSERT(.pass,.fail,n,0,"empty ring -> 0 shipped")
	quit
	;
tDrainKeyFollowsLayout(pass,fail)	;@TEST "the batch object key follows the §11 layout (station/proto/seq)"
	new res,n
	do setup()
	do fill(2)
	set n=$$drain^VSLS3(.res)
	do true^STDASSERT(.pass,.fail,res("key")[("traffic/500/rpc/"),"key carries the station/proto prefix")
	do true^STDASSERT(.pass,.fail,res("key")[".ndjson","key is an .ndjson object")
	quit
