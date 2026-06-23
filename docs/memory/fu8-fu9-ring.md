---
name: fu8-fu9-ring
description: Traffic-tap FU-8 (atomic $INCREMENT seq) + FU-9 (always-on ring / egress-gate split) in VSLTAP/VSLS3; the head-ahead-of-data window + gap-safe drain; gate-split behavior inversion.
metadata:
  type: project
---

**RPC→S3 traffic tap — FU-8 + FU-9 DONE 2026-06-23, branch `s3tap-fu8-fu9-ring`
(stacked on the FU-4 branch), unmerged.** Both blocking for a concurrent deployment;
both land before the FU-5 wrap (plan §13.4 step 3).

**FU-8 — atomic `$INCREMENT` sequence (G-SEQ).** `write1^VSLTAP` replaced the racy
`set seq=+$get(^XTMP("VSLTAP","head"))+1` … `set ^…("head")=seq` (two concurrent broker
handlers read the same head → a lost record AND a duplicate seq, breaking the §11
idempotent S3 key) with `set seq=$increment(^XTMP("VSLTAP","head"))` — atomic on YDB+IRIS,
no LOCK; it allocates the unique seq AND advances head in one indivisible step. **Load-bearing
ordering:** the `$increment` sits AFTER the maxbytes copy-cost guard so a rejected
mega-payload never burns a seq (which would leave a permanent hole the gap-safe drain would
stop at forever). The old separate `set head=seq` line is gone (the increment is the advance).

**FU-8 side-effect → the head-ahead-of-data window (and the drain fix it forced).**
`$increment` advances head ONE statement BEFORE the `set ^data(seq)=rec`, so an always-on
drain (FU-9) can momentarily see head ahead of an in-flight slot (or, with concurrent
appenders, a mid-prefix hole — seq 6's data committed before seq 5's). The old drain shipped
(tail,head] and `drainTo(head)` — it would ship "" for the in-flight slot and KILL a record
about to land. **Fix (in `VSLS3 $$drain`):** ship only the CONTIGUOUS COMMITTED PREFIX —
`for seq=t+1:1:h quit:'$$present^VSLTAP(seq)` (stop at the first absent slot) and
`drainTo(last)` not `drainTo(h)`. The gap slot waits for the next tick → no loss, no
double-ship. New helper **`$$present(seq)`** = `$data(^…("data",seq))'=0` (distinguishes an
absent/uncommitted slot from a legitimately-empty record, which `$$read`'s `$get` can't).

**FU-9 — always-on ring / egress-gate split (D-6).** The former single gate `$$enabled`
(armed ∧ ¬disabled ∧ (consumer ∨ alwayson)) is SPLIT:
- **`$$captureOn()`** = armed ∧ ¬disabled — the **always-on capture gate** (used by
  `append`). The ring records whenever armed; only the kill-switch (`off`) or auto-failover
  (`disable`) stops it. A down/absent sink no longer stops capture.
- **`$$enabled()`** = `$$captureOn()` ∧ consumer — the **egress gate** (used by the drain,
  `$$state` ACTIVE, and the HL7 tail). With no consumer the ring still captures but the PUT
  pauses; `$$state` reports ARMED-IDLE (capturing, not shipping) vs ACTIVE (shipping).

**HL7 tail STAYS consumer-gated on purpose** — `#772`/`#778` are a *persisted, replayable*
store with a freezable cursor, so "no consumer → don't tail, freeze cursor, catch up on
re-arm" is a feature; only the *ephemeral* RPC ring goes always-on. So `VSLHL7TAP` was NOT
changed (it keeps `$$enabled`). `setAlwaysOn`/`alwayson` are now SUBSUMED (the ring is
always-on by default) → kept as a documented **legacy no-op** that still writes the cfg key
so v-web's console display keeps resolving.

**Behavior inversion → test rewrites.** "no consumer → no capture" is now "no consumer →
ring STILL captures." Rewrote: VSLTAPTST `tConsumerGateBlocksAppend`→`tRingAlwaysOnNoConsumer`
+ new `tSinkDownRingLapsToDropOldest` (always-on ring laps to drop_oldest with sink down) +
new `tAtomicSeqNoCollision` (FU-8 invariant); VSLRPCTAPTST `tCaptureGatedNoConsumer`→
`tCaptureAlwaysOnNoConsumer`; VSLS3DRAINTST new `tDrainStopsAtUncommittedGap` (the
head-ahead-of-data proof: manually set head ahead of data → drain ships the prefix, leaves
the gap, the late record ships next tick); VSLTAPBENCHTST idle arm reframed
`tConsumerGatedIdleIsNearZero`→`tKillSwitchIdleIsNearZero` (post-FU-9 the near-zero idle
path is the OFF/disabled gate, not "no consumer").

**Gotcha:** `JOB` does not work in the bare test engines (workers don't run / write-capture
quirk), so a true OS-parallel concurrency test isn't possible here — `tAtomicSeqNoCollision`
asserts the post-append invariants (unique/contiguous/no-loss) + the `$INCREMENT` primitive
serially, and is HONEST in its doc that atomicity-under-contention rests on the engine
guarantee. Also (re-)hit: calling the `append` *function* via `DO` raises
`%YDB-E-NOTEXTRINSIC` (argumented QUIT in a DO frame) — use `set x=$$append^VSLTAP(...)`.

**Gates:** dual-engine GREEN **198/198** (YDB+IRIS); fmt/lint/arch green; **IRIS coverage
95%** (VSLTAP+VSLS3 157/165; YDB collector env-broken, see [[fu4-naked-ref-fence]]).
**Cross-repo follow-up:** v-web `VWEBT` still labels `$$enabled` as "the capture gate
(… consumer OR alwayson)" — update it to show captureOn vs egressOn (a v-web increment).
**NEXT: FU-5 — the XWB wrap at `CALLP^XWBBRK`** (FU-4 fence + FU-8 + FU-9 now all in place).
Shared workstream memory: [[rpc-traffic-s3-streaming-proposal]] (docs). Extends
[[fu4-naked-ref-fence]] / [[phase2-vsltap]].
