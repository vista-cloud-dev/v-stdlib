---
name: phase5-ga-forward-port
description: Traffic-tap Phase 5 / M4 (GA) DELIVERABLES forward-ported onto Phase-6 main — VSLTAPBO back-out (G-UNINST) + VSLTAPRUN periodic fidelity-run task + VSLTAP seed + VSLS3 list + 10 XPAR params + DIBRG. The original work was live-proven on the now-superseded branch phase5-ga-kids-backout / PR #15, which went STALE against Phase-6 (FU-4/5) and could not be merged without reverting it.
metadata:
  type: project
---

# Phase 5 / M4 (GA): the GA deliverables forward-ported onto Phase-6 main

**Done 2026-06-23, committed straight to `main`** (trunk-based per org rule).
The GA traffic-tap deliverables (KIDS install/back-out, the production
fidelity-run task) were originally built and **live-proven dual-engine** on
branch `phase5-ga-kids-backout` (**PR #15**, 5 increments). That branch was cut
**2026-06-21, before the Phase-6 FU-4/FU-5 work landed on `main` 2026-06-23** —
so the PR went **stale**: its diff DELETES `VSLRPCWRAP`/`VSLTAPV2TST`/
`VSLTAPFENCETST` and reverts the schema-v1 capture rewrite. **Merging PR #15
would revert Phase 6.** The correct path was a **forward-port of the net-new
artifacts** onto current main (a rebase would conflict massively on the shared
rewritten files VSLTAP/VSLS3/VSLTAPFC/VSLRPCTAP). **PR #15 is superseded — close
it, do not merge.**

## What was ported (net-new on main)
- **`src/VSLTAPBO.m`** — the back-out / verify-clean (risk **G-UNINST**).
  `backout()` = `cleanTasks` → `cleanParams` → `cleanState` (order matters: task
  numbers live in `^VSLTAP("task",…)` which `cleanState` then kills). Reverses
  the runtime footprint `v-pkg uninstall` leaves orphaned (XPAR `#8989.51`
  params, the fidelity/flush TaskMan jobs, `^XTMP("VSLTAP")` cache, `^VSLTAP`
  state); `$$verifyClean(detail)` proves no residue. Self-contained, seam-stable
  → ported byte-identical. `$$params` is the canonical 10-name XPAR list (single
  source of truth shared with the KIDS param-definitions).
- **`src/VSLTAPRUN.m`** — the periodic fidelity-run task (closes the console
  loop: nothing in a live install calls `persist^VSLTAPFC`, so the panel showed
  `pending`). `$$reconcilePersist` (bare-proven), `$$cadence` (XPAR
  `VSL TAP FIDELITY CADENCE`, default 3600), `$$schedule` (non-persistent
  `^%ZTLOAD` re-queue, cleanly dequeueable by VSLTAPBO), `run()` (gate→sample→
  reschedule), **`$$fidelityNow`** (LIST shipped → read back → `$$verify^VSLTAPFC`
  each → persist; round-trip integrity, NOT the deeper capture==wire leg).
- **`src/VSLTAP.m` `seed`/`seedMap`/`seedOne`/`sm`** — the install-time XPAR→
  `^VSLTAP("cfg")` bridge (the hot-path gate + VSLS3 ctx read cfg, NOT XPAR). 9
  mappings; `$text(GET^XPAR)`-guarded → bare no-op. (The fidelity cadence is read
  from XPAR direct, so it is not mirrored.)
- **`src/VSLS3.m` `list`** — a one-line wrapper over `$$listObjectsV2^STDS3`
  (the discovery leg `$$fidelityNow` needs; v→m, no new ICR).
- **`kids/vsl.build.json`** — added `VSLTAPBO`+`VSLTAPRUN` (KEEPING `VSLRPCWRAP`,
  which the stale branch dropped) + the **10 tap XPAR `#8989.51` param
  definitions** (names == `$$params^VSLTAPBO`) + **patch `VSL*1.0*2`→`*3`** (also
  in `VSLBLD.$$manifest` + `VSLBLDTST`). `dist/kids/VSL.kids` + icr/namespace
  registries regenerated.
- **`docs/traffic-tap-dibrg.md`** — the deploy/install/back-out/rollback guide
  (footprint table, per-engine `v-pkg` driver commands, the endpoint-flip config
  for real-S3, **back-out = `do backout^VSLTAPBO()` THEN `v-pkg uninstall`**).

## The one schema-v1 adaptation
The only seam incompatibility: VSLTAPRUNTST's `env()` helper used the OLD 6-arg
`$$envelope^VSLS3(rec,proto,dir,status,seq,opt)`. Phase-6 main's envelope is
**`envelope(.rec,.opt)`** with a by-ref schema-v1 field array (`rec("payload")`).
Rewrote `env()` to build a resp rec (`payload`/`protocol`/`direction`/
`result_kind`/`seq`/`call_id`) — everything else seam-compatible. VSLTAPBO +
VSLTAPBOTST ported byte-identical (the back-out is ring-layout-agnostic — it
`kill`s the whole `^XTMP("VSLTAP")` subtree, so the v2 layout change is moot).

## Verification (this increment)
- **Bare dual-engine GREEN: 15 suites / 309 passed / 0 failed on BOTH** YDB
  (m-test-engine) and IRIS (m-test-iris). New suites **VSLTAPBOTST 12/12 +
  VSLTAPRUNTST 8/8** each engine.
- All **engine-free gates green**: lint 0, arch G3/G4 clean, **check-icr 26**
  (the new `$$FIND1^DIC`/`FILE^DIE`/`EN^XPAR`/`KILL^%ZTLOAD`/`GET^XPAR` notional
  citations verified vs the gold corpus), check-citations 26, check-namespaces 17,
  **check-kids deterministic/golden at patch 3**.

## OWED (next increment — the live + egress re-proof on current main)
The GA logic is identical to the branch's (which was already live-proven), so
these are **defense-in-depth re-proofs on Phase-6 main**, not new logic:
1. **LIVE `install → verify → back-out → verify-clean` on vehu + foia-t12** over
   the driver (the real G-UNINST gate) — now with `VSLRPCWRAP` co-resident.
   (Live env recipe + the `delParam` FDA-case bug the live proof once caught are
   in the stale branch memory.)
2. **MinIO matrix for `$$fidelityNow`/`$$list`** — port the 2 fidelityNow tests
   into `VSLS3E2ETST` (the stale branch's `tamperLine` used the old envelope API;
   rebuild it schema-v1) and run `make test-s3-matrix`.
3. **Real-S3 endpoint flip** smoke + **fleet rollout (5.4)** — config/ops; fleet
   deferred indefinitely (user, 2026-06-21) until a real deployment need.

Shared workstream: [[rpc-traffic-s3-streaming-proposal]] (docs repo).
Builds on [[fu5a-schema-v1-capture]] / [[fu5b1-rpcwrap-glue]] /
[[phase4-fidelity-persist]] / [[phase3-egress-fidelity]] / [[phase2-vsltap]].
