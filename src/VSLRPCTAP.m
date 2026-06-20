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
	; doc: @returns    void    fire-and-forget — the result/$ECODE/$T of the RPC worker are untouched
	; doc: $TEST is saved and restored by hand (NOT `new $test` — that aborts on
	; doc: IRIS); `if t` restores the caller's truthy/falsy $TEST exactly (it is
	; doc: always 0/1). Dual-engine-portable.
	new x,t
	; m-lint: disable-next-line=M-MOD-017
	set t=$test
	set x=$$tee^VSLTAP($get(rec))
	if t
	quit
