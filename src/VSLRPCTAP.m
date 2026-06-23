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
	;   do capture^VSLRPCTAP(rec)   — fenced fire-and-forget tee of one verbatim RPC record
	;
	quit
	;
capture(rec)	; Fenced fire-and-forget tee of a verbatim RPC record into the rolling ring.
	; doc: @param rec  string  the verbatim RPC record (read-only; the tap never mutates it)
	; doc: @returns    void    fire-and-forget — the result/$ECODE/$T/naked-ref of the RPC worker are untouched
	; doc: This is the boundary the XWB wrap (FU-5) calls, so the caller-state fence
	; doc: lives HERE: $TEST and $ZREFERENCE (the naked indicator) are snapshotted at
	; doc: entry — before any global reference — and re-established on EVERY exit.
	; doc: naked-reference save/restore (FU-4, R-NAKED) is the keystone: the tap's ^XTMP
	; doc: SETs mutate the caller's naked indicator, so without the restore the
	; doc: caller's next `^(sub)` would silently hit ^XTMP. The SVN differs by engine
	; doc: (YDB `$REFERENCE`, IRIS `$ZREFERENCE` — neither compiles the other's token),
	; doc: so $$nakedRef reads it dual-engine; the restore is one benign FULL reference
	; doc: `s zz=$d(@nref)` — it re-points the indicator without reading the value (the
	; doc: SVN is read-only on both engines). The restore runs in the
	; doc: FINALLY path (after a DO-framed worker) so it fires on success, gating, AND
	; doc: a swallowed fault — and is the LAST global op before return. The `nref'=""`
	; doc: guard handles a job-start empty indicator (AC-2). $TEST is restored by hand
	; doc: (NOT `new $test` — that aborts on IRIS); `if t` reproduces 0/1 exactly.
	new t,nref,zz
	; m-lint: disable-next-line=M-MOD-017
	set t=$test
	set nref=$$nakedRef()
	do work($get(rec))
	; finally — re-establish the caller's naked indicator LAST, then $TEST.
	if nref'="" set zz=$data(@nref)
	if t
	quit
	;
work(rec)	; (private) the global-touching side, DO-framed so a fault can never escape the boundary.
	; doc: @param rec  string  the verbatim record (by value — the caller's var is untouched)
	; doc: $$tee^VSLTAP is already self-fenced (it swallows + self-disables); this frame's
	; doc: flag-based $ETRAP is the backstop so that even a residual escape returns here
	; doc: via an arg-less QUIT, letting capture's finally restore the naked indicator.
	; doc: MUST stay DO-invoked (never `$$`): the trap's arg-less QUIT raises M17
	; doc: NOTEXTRINSIC in an extrinsic frame (same gotcha as append/write1).
	new x,$etrap
	set $etrap="set $ecode="""" quit"
	set x=$$tee^VSLTAP(rec)
	quit
	;
nakedRef()	; (private) the caller's last global reference, dual-engine. "" at job start.
	; doc: @returns string  $REFERENCE (YDB) / $ZREFERENCE (IRIS) — the naked indicator
	; doc: The SVN name differs by engine and neither engine compiles the other's token,
	; doc: so it is read via XECUTE of an engine-selected assignment — no literal SVN in
	; doc: the compiled routine. XECUTE keeps the current naked-reference context, and a
	; doc: function call does not reset it, so this returns the CALLER's last reference.
	; doc: (Engine-neutral — a candidate to promote to an m-stdlib STD* primitive later.)
	new nr,cmd
	set nr=""
	set cmd="set nr="_$select($zversion["IRIS":"$zreference",1:"$reference")
	xecute cmd
	quit nr
