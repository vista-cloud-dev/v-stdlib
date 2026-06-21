---
name: phase4-fidelity-persist
description: Traffic-tap Phase 4 (M3) v-stdlib leaf — VSLTAPFC gains do persist(res,ts) + $$lastFidelity() so the v-web console (VWEBT) can read the last fidelity result passively; dual-engine 28/28; branch phase4-fidelity-persist off ship-all-routines.
metadata:
  type: project
---

**Traffic-tap Phase 4 / M3 — v-stdlib fidelity-persistence primitive DONE
(2026-06-21, branch `phase4-fidelity-persist` off `ship-all-routines`, unmerged).**
Built leaf-first so the v-web SSE console ([[phase3-egress-fidelity]]'s consumer
side) has a passive getter for "last fidelity %". Extends [[phase3-egress-fidelity]].

**The gap closed:** `$$verify`/`$$matches`/`$$reconcile`/`$$manifest^VSLTAPFC`
compute fidelity ON CALL against a corpus — there was no passive getter, so the
console couldn't read a last result without re-running a comparison. Added two
tiny entry points to `VSLTAPFC` (no new routine, no namespace/kids-list change):

- `do persist^VSLTAPFC(res,ts)` — serialises the run via the existing
  `$$manifest(.res,ts)` and stores the line at **`^VSLTAP("fc","last")`** (single
  "last" slot; a newer run overwrites). The production caller is the periodic
  comparator; the `make test-s3` round-trip harness (`VSLS3E2ETST`) now also calls
  it after its `$$reconcile`, so a live round-trip populates the console getter.
- `$$lastFidelity^VSLTAPFC()` — pure read of `$get(^VSLTAP("fc","last"))`; returns
  `""` when no run has run (the console renders "last-run pending", honest — never
  a fabricated number). VWEBT parses the stored manifest into its snapshot.

**Stored shape = the `_fidelity` manifest** (`matched`/`mismatch`/`missing`/
`extra`/`ok`/`ts`); match-% and pass/fail are derived by the console from these.
RPC-mirror-vs-HL7-#772 split is NOT in the manifest (the comparator isn't
proto-tagged) — left out rather than faked.

**Verified:** TDD red-first (suite aborted 0/0 on the missing entry points) →
green. **VSLTAPFCTST 28/28 dual-engine** (YDB m-test-engine + IRIS m-test-iris,
+3 new tests: empty-before-run, persist→read-back-JSON, overwrite-latest).
`make check-fast` all engine-free gates green; `dist/kids/VSL.kids` regenerated
(`make kids` — VSLTAPFC src changed; routine count unchanged at 14).

**No VSL version tag needed for v-web to consume:** v-web stages VSL* via
`--routines $(VSTDLIB)/src` off the local checkout (only the MSL `STD*` seam is
version-pinned), so v-web sees `persist`/`lastFidelity` as long as this branch is
checked out. Shared note: `docs` repo
`docs/memory/rpc-traffic-s3-streaming-proposal.md`.
