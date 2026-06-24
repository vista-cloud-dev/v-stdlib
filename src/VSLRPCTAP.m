VSLRPCTAP	; v-stdlib — RPC tap adapter at the VSLRPC chokepoint (the fenced tee).
	;
	; The thin RPC adapter over the VSLTAP core (spec §4.1.3, §6.1). VSLRPC is the
	; ephemeral RPC runner (proposed, unbuilt) — so this session wires the seam,
	; not a live runner: the real VSLRPC will call `do capture^VSLRPCTAP(.msg)` as
	; a side-call BESIDE `D TAG^ROUTINE`, exactly the way the tests inject it. The
	; tee's whole contract is to be invisible to the RPC path:
	;
	;   - It is fire-and-forget: its return is ignored, its arg is scratch (read,
	;     never written), and it touches no symbol the caller's result / $ECODE /
	;     $T / IO depends on.
	;   - The fault fence lives in $$tee^VSLTAP (flag-based $ETRAP, dual-engine);
	;     ANY fault inside the tap is swallowed there and self-disables capture.
	;   - It NEWs $TEST so the caller's $T survives the side-call untouched.
	;
	; The append itself is one fast ^XTMP SET into the rolling ring (no LOCK, no
	; serialize, no socket, no I/O, no block) — the irreducible minimum a tap on an
	; ephemeral protocol can be (HL7, already persisted in #772, needs even less).
	;
	; Layer: v. Consumes the VSLTAP core (v->v); the engine seam stays in VSLTAP.
	;
	; Public API:
	;   do capture^VSLRPCTAP(.rec)   — fenced fire-and-forget tee of one RPC record (cache layout v2)
	;   $$callId^VSLRPCTAP(station,ctr) — build a station-$J-ctr correlation id (FU-14)
	;
	; The record `rec` is a by-ref descriptor (schema-lock §2/§3): rec("dir")="req"|"resp",
	; rec("rpc"), rec("payload") (verbatim params for a req / scalar result for a resp),
	; rec("gref") (closed-root global ref to MERGE for a GLOBAL ARRAY result, FU-17),
	; rec("result_kind"), rec("call_id") (correlates the req with its resp; the wrap bumps a
	; $J-scoped local counter once per RPC and shares it across both side-calls), and the
	; FU-18 context rec("duz")/rec("job")/rec("client")/rec("station")/rec("denied"). The tap
	; reads it; it never writes it (scratch contract).
	;
	quit
	;
capture(rec)	; Fenced fire-and-forget tee of one RPC record (cache layout v2) into the rolling ring.
	; doc: @param rec  array  by-ref record descriptor (read-only; the tap never mutates it)
	; doc: @returns    void   fire-and-forget — the result/$ECODE/$T/naked-ref of the RPC worker are untouched
	; doc: This is the boundary the FU-5 wrap calls, so the caller-state fence lives HERE:
	; doc: $TEST and the naked indicator ($REFERENCE on YDB / $ZREFERENCE on IRIS) are
	; doc: snapshotted at entry — before any global reference — and re-established on EVERY
	; doc: exit. naked-reference save/restore (FU-4, R-NAKED) is the keystone: the tap's ^XTMP
	; doc: SETs mutate the caller's naked indicator, so without the restore the caller's next
	; doc: `^(sub)` would silently hit ^XTMP. The SVN differs by engine (neither compiles the
	; doc: other's token), so $$nakedRef reads it dual-engine; the restore is one benign FULL
	; doc: reference `s zz=$d(@nref)` — it re-points the indicator without reading the value.
	; doc: The restore runs in the FINALLY path (after a DO-framed worker) so it fires on
	; doc: success, gating, AND a swallowed fault — and is the LAST global op before return.
	; doc: The `nref'=""` guard handles a job-start empty indicator (AC-2). $TEST is restored
	; doc: by hand (NOT `new $test` — that aborts on IRIS); `if t` reproduces 0/1 exactly.
	; doc: @example   new rec do off^VSLTAP(),arm^VSLTAP() kill ^XTMP("VSLTAP") set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="ORWU DT",rec("payload")="DUZ=10^NOW" do capture^VSLRPCTAP(.rec) do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"capture tees one record into the always-on ring") do off^VSLTAP() kill ^XTMP("VSLTAP")
	new t,nref,zz
	; m-lint: disable-next-line=M-MOD-017
	set t=$test
	set nref=$$nakedRef()
	do work(.rec)
	; finally — re-establish the caller's naked indicator LAST, then $TEST.
	if nref'="" set zz=$data(@nref)
	if t
	quit
	;
callId(station,ctr)	; Build a correlation call_id = station "-" $J "-" ctr (schema-lock §2).
	; doc: @param station  string   the originating station number
	; doc: @param ctr      numeric  a $J-scoped counter the wrap bumps ONCE per RPC invocation
	; doc: @returns        string   the call_id shared by that RPC's req + resp records
	; doc: A process-local counter (not a global hot node, spec §4.1.3) keeps event_id
	; doc: (call_id ":" direction) deterministic without cross-process contention.
	; doc: @example   do eq^STDASSERT(.pass,.fail,$$callId^VSLRPCTAP("500",7),"500-"_$job_"-7","callId builds station-$J-counter")
	quit $get(station)_"-"_$job_"-"_(+$get(ctr))
	;
work(rec)	; (private) the global-touching side, DO-framed so a fault can never escape the boundary.
	; doc: @param rec  array  by-ref record descriptor (the caller's array is untouched)
	; doc: $$teeRec^VSLTAP is already self-fenced (it swallows + self-disables); this frame's
	; doc: flag-based $ETRAP is the backstop so that even a residual escape returns here
	; doc: via an arg-less QUIT, letting capture's finally restore the naked indicator.
	; doc: MUST stay DO-invoked (never `$$`): the trap's arg-less QUIT raises M17
	; doc: NOTEXTRINSIC in an extrinsic frame (same gotcha as append/write1).
	; doc: @example   new rec do off^VSLTAP(),arm^VSLTAP() kill ^XTMP("VSLTAP") set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="X",rec("payload")="P" do work^VSLRPCTAP(.rec) do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"work appends the record (the global-touching side)") do off^VSLTAP() kill ^XTMP("VSLTAP")
	new x,$etrap
	set $etrap="set $ecode="""" quit"
	set x=$$teeRec^VSLTAP(.rec)
	quit
	;
nakedRef()	; (private) the caller's last global reference, dual-engine. "" at job start.
	; doc: @returns string  $REFERENCE (YDB) / $ZREFERENCE (IRIS) — the naked indicator
	; doc: The SVN name differs by engine and neither engine compiles the other's token,
	; doc: so it is read via XECUTE of an engine-selected assignment — no literal SVN in
	; doc: the compiled routine. XECUTE keeps the current naked-reference context, and a
	; doc: function call does not reset it, so this returns the CALLER's last reference.
	; doc: (Engine-neutral — a candidate to promote to an m-stdlib STD* primitive later.)
	; doc: @example   new zz set zz=$data(^VSLTAP("cfg")) do eq^STDASSERT(.pass,.fail,$$nakedRef^VSLRPCTAP(),"^VSLTAP(""cfg"")","nakedRef returns the caller's last global reference")
	new nr,cmd
	set nr=""
	set cmd="set nr="_$select($zversion["IRIS":"$zreference",1:"$reference")
	xecute cmd
	quit nr
