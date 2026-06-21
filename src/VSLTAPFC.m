VSLTAPFC	; v-stdlib — fidelity comparator: byte-equality proof, not assertion.
	; m-lint: disable-file=M-MOD-024
	; M-MOD-024 false positives: `t` is populated by reference by $$parse^STDJSON
	; (and `res` by reconcile's helpers); the analyser cannot see through the
	; extrinsic/by-ref call, so it reads them as "read before defined".
	;
	; Phase 3 / M2 of the RPC+HL7 -> S3 traffic tap (spec §7). VSLTAPFC is the
	; standing, gated, byte-level equivalence check that answers "is the captured
	; copy full-fidelity correct?" — by COMPARISON, never by claim. It re-derives
	; the per-record sha256 anchor a shipped envelope carries (intrinsic
	; integrity), it decodes a shipped envelope back to the raw bytes and proves
	; they byte-equal the captured source (RPC: the in-app tee vs the independent
	; passive mirror; HL7: the shipped object vs its #772 source), and it
	; reconciles a whole corpus against the read-back objects — every record
	; present exactly once, in sequence, sha256-matched, no unaccounted drop (the
	; §15.2 round-trip core). A mismatch is a FAILURE, surfaced on the console and
	; red-gated in CI.
	;
	; *** Layer: v (above the m/v waterline). It consumes `m` DOWN only — STDJSON
	; (parse the LDJSON envelope), STDCRYPTO (re-hash), STDB64 (decode a base64
	; payload). It produces no traffic and reaches no engine: pure comparison
	; over envelopes and source records, so it runs on a bare engine and as a CI
	; gate over recorded fixtures (the live read-back leg is VSLS3 $$readback,
	; exercised by the integration harness).
	;
	; Public API:
	;   $$payloadOf(line)            decode one envelope line back to the raw bytes
	;   $$verify(line)               1 iff the payload re-hashes to its own anchor
	;   $$matches(line,source)       1 iff payload byte-equals source AND verifies
	;   $$reconcile(corpus,envs,res) round-trip reconcile; res(matched/mismatch/missing/extra)
	;   $$manifest(res,ts)           serialise a fidelity run to a JSON manifest line
	;   do persist(res,ts)           store the last run at ^VSLTAP("fc","last")
	;   $$lastFidelity()             the last persisted manifest line, or "" (none yet)
	;
	quit
	;
	; ---------- single-record fidelity ----------
	;
payloadOf(line)	; Decode one LDJSON envelope line back to the verbatim captured bytes.
	; doc: @param line  string  one VSLS3 envelope line (inline or base64 payload)
	; doc: @returns     byte-string  the raw payload, byte-exact (escaping/base64 reversed)
	new t,pl
	if '$$parse^STDJSON(line,.t) quit ""
	set pl=$$valueOf^STDJSON($get(t("payload")))
	if $$valueOf^STDJSON($get(t("enc")))="base64" quit $$decode^STDB64(pl)
	quit pl
	;
verify(line)	; 1 iff the envelope's payload re-hashes to the sha256 anchor it carries (§7).
	; doc: @param line  string  one VSLS3 envelope line
	; doc: @returns     bool    intrinsic integrity — the shipped object equals what was captured
	new t,hash
	if '$$parse^STDJSON(line,.t) quit 0
	set hash=$$valueOf^STDJSON($get(t("hash")))
	quit (hash=$$sha256^STDCRYPTO($$payloadOf(line)))
	;
matches(line,source)	; 1 iff the decoded payload byte-equals `source` AND the hash anchor is intact.
	; doc: @param line    string  one VSLS3 envelope line
	; doc: @param source  byte-string  the captured source record (the tee, the #772 message)
	; doc: @returns       bool    the byte-equality proof (RPC tee-vs-mirror; HL7 vs #772)
	quit ($$payloadOf(line)=$get(source))&$$verify(line)
	;
	; ---------- round-trip reconciliation (the §15.2 core) ----------
	;
reconcile(corpus,envs,res)	; Reconcile a generated corpus against the read-back envelopes, by sequence.
	; doc: @param corpus  array  by-ref: corpus(seq) = the generated verbatim record
	; doc: @param envs    array  by-ref: envs(seq)   = the read-back envelope line
	; doc: @param res     array  OUT by-ref: res("matched"/"mismatch"/"missing"/"extra")
	; doc: @returns       bool   1 iff EVERY corpus record is present exactly once,
	; doc:                       byte-equal + hash-matched, with no missing and no extra
	; doc: A drift (payload differs or hash stale) is a mismatch; a dropped record
	; doc: is missing; a record shipped under a seq not in the corpus is extra.
	; doc: Drops are only acceptable if accounted for in _offwindows (out of band).
	new seq
	kill res
	set res("matched")=0,res("mismatch")=0,res("missing")=0,res("extra")=0
	set seq=""
	for  do recOne(.seq,.corpus,.envs,.res) quit:seq=""
	set seq=""
	for  do extraOne(.seq,.corpus,.envs,.res) quit:seq=""
	quit ('res("mismatch"))&('res("missing"))&('res("extra"))
	;
recOne(seq,corpus,envs,res)	; (private) advance to the next corpus seq; classify matched/mismatch/missing.
	set seq=$order(corpus(seq))
	if seq="" quit
	if '$data(envs(seq)) set res("missing")=res("missing")+1 quit
	if $$matches(envs(seq),corpus(seq)) set res("matched")=res("matched")+1 quit
	set res("mismatch")=res("mismatch")+1
	quit
	;
extraOne(seq,corpus,envs,res)	; (private) advance to the next shipped seq; count any with no corpus source.
	set seq=$order(envs(seq))
	if seq="" quit
	if '$data(corpus(seq)) set res("extra")=res("extra")+1
	quit
	;
	; ---------- the _fidelity manifest (spec §11) ----------
	;
manifest(res,ts)	; Serialise a fidelity run to a single JSON manifest line (the _fidelity object).
	; doc: @param res  array   by-ref: res("matched"/"mismatch"/"missing"/"extra")
	; doc: @param ts   string  capture timestamp (default $H)
	; doc: @returns    string  one RFC-8259 JSON object summarising the run
	; doc: ok=true iff there were zero mismatches, zero missing and zero extras —
	; doc: the standing byte-equality proof shipped under traffic/<st>/_fidelity/.
	new m,ok
	set ok=('+$get(res("mismatch")))&('+$get(res("missing")))&('+$get(res("extra")))
	set m="o"
	set m("ts")="s:"_$get(ts,$horolog)
	set m("matched")="n:"_(+$get(res("matched")))
	set m("mismatch")="n:"_(+$get(res("mismatch")))
	set m("missing")="n:"_(+$get(res("missing")))
	set m("extra")="n:"_(+$get(res("extra")))
	set m("ok")=$select(ok:"t",1:"f")
	quit $$encode^STDJSON(.m)
	;
	; ---------- the persisted last-fidelity result (the console getter, spec §8.1) ----------
	;
persist(res,ts)	; Store the last fidelity run so the console can read it (no live run on request).
	; doc: @param res  array   by-ref: res("matched"/"mismatch"/"missing"/"extra")
	; doc: @param ts   string  capture timestamp (default $H)
	; doc: @returns    void     writes the manifest line to ^VSLTAP("fc","last")
	; doc: $$verify/$$reconcile/$$manifest compute fidelity ON CALL against a corpus;
	; doc: VWEBT (the console) needs a passive getter, so the periodic comparator (and
	; doc: the make test-s3 round-trip) call persist after a run. Single "last" slot:
	; doc: a newer run replaces the prior one (the console shows the latest result).
	set ^VSLTAP("fc","last")=$$manifest(.res,$get(ts,$horolog))
	quit
	;
lastFidelity()	; The last persisted _fidelity manifest line, or "" when no run has run yet.
	; doc: @returns string  the JSON manifest stored by persist, or "" (console: "pending")
	; doc: A pure read of the VSL control state — the snapshot reader (VWEBT) parses it.
	quit $get(^VSLTAP("fc","last"))
