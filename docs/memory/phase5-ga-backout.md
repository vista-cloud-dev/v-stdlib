---
name: phase5-ga-backout
description: Traffic-tap Phase 5 / M4 (GA) — VSLTAPBO back-out + verify-clean routine, the G-UNINST keystone. Reverses the tap's runtime footprint (tasks/XPAR params/^XTMP cache/^VSLTAP state) that v-pkg's routine-only uninstall leaves behind; $$verifyClean proves no orphan. Bare-proven dual-engine 12/12.
metadata:
  type: project
---

# Phase 5 / M4 (GA): VSLTAPBO back-out + verify-clean — the G-UNINST keystone

Branch `phase5-ga-kids-backout` (off `main`), unmerged. First GA increment of
the RPC+HL7→S3 traffic tap (plan §9 stage 5.1). Closes the reversible-install
gap a fleet rollout depends on.

## Why VSLTAPBO exists
`v-pkg uninstall` is **routine-only** back-out — it removes the routines + the
`#9.7`/`#9.6` KIDS build records and *nothing else*. The tap's RUNTIME footprint
is left orphaned: the scheduled flush/fidelity TaskMan jobs, the tap's XPAR
`#8989.51` PARAMETER instances+definitions, the `^XTMP("VSLTAP",…)` rolling
cache, and the `^VSLTAP` control state. That orphaning **is** risk G-UNINST.
`VSLTAPBO` reverses exactly that footprint and then proves it clean.

## What was built (`src/VSLTAPBO.m`)
- `do backout()` — orchestrates, **order matters**: `cleanTasks()` →
  `cleanParams()` → `cleanState()`. Tasks first because their numbers live in
  `^VSLTAP("task",…)`, which `cleanState` then kills. Idempotent.
- `do cleanState()` — `kill ^XTMP("VSLTAP")` + `kill ^VSLTAP`. Pure M, the
  bare-testable core.
- `do cleanParams()` — per-param: clear the SYS instance (`EN^XPAR(…,"@")`),
  then delete the `#8989.51` definition via FileMan DBS `FILE^DIE` with `.01="@"`
  (the no-`DELETE^DIE` pattern, like VSLFS), IEN via `$$FIND1^DIC`.
- `do cleanTasks()` — `$ORDER` over `^VSLTAP("task",…)`, `KILL^%ZTLOAD` each
  (the jobs are periodic re-queues, NOT persistent listeners, so they dequeue
  cleanly — no un-KILLable PSET problem).
- `$$verifyClean(detail)` — 1 iff globals + XPAR params + task records are all
  clean; `detail(globals/params/tasks)` names any survivor. The exit gate.
- `$$params(out)` — the canonical 10-name tap XPAR list (single source of truth,
  shared by the back-out and the future KIDS param-definitions): `VSL TAP CAP /
  MAXBYTES / HBSTALE / RETAIN / ALWAYSON / FIDELITY CADENCE` + `VSL S3 ENDPOINT /
  BUCKET / REGION / PREFIX`. (Operator RUNTIME state — mode/consumer — stays in
  `^VSLTAP("cfg")`, NOT XPAR.)

## KEY decision — `$text()`-guard the VistA-seam legs (not just `$ETRAP`)
Calling an **undefined** Kernel routine (`EN^XPAR`/`FIND1^DIC`/`KILL^%ZTLOAD`)
on a BARE engine aborts the suite **0/0 even with a flag-`$ETRAP`** — the trap
does not save a routine-not-found in this harness path. Fix: guard every VistA
call with `if $text(EN^XPAR)'="" …` / `if $text(FIND1^DIC)="" quit` so a bare
engine cleanly **skips** (nothing to remove → trivially clean), and keep the
`$ETRAP` for a genuine runtime fault. This is what lets `backout`/`cleanParams`/
`cleanTasks` run in the BARE suite at all (the other VistA-API routines —
VSLCFG/VSLFS/… — are simply excluded from `test-bare` instead).

## GOTCHA (5th sighting) — `DO` of an extrinsic → YDB 0/0 abort
A test had `do verifyClean^VSLTAPBO(.detail)` to capture a by-ref arg; calling an
extrinsic (`quit <value>`) with **`DO`** aborts YDB → 0/0. Use
`set x=$$verifyClean^VSLTAPBO(.detail)`. (Same family as the `tee^VSLTAP`
sighting in [[phase3-egress-fidelity]] and the M4 zgoto one.)

## Verification
- `tests/VSLTAPBOTST.m` **12/12 dual-engine** (YDB m-test-engine + IRIS
  m-test-iris); added to `BARE_TESTS` → full bare suite **186/186 both engines**
  (11 suites, +12).
- `VSLTAPBO` added to `kids/vsl.build.json` components.routines (15 routines);
  `dist/kids/VSL.kids` + icr/namespace registries regenerated; **all engine-free
  gates green** — check-icr 23 (new `$$FIND1^DIC` DBS notional citation verified
  vs the gold corpus `DI/fm22_2dg`), check-citations 23, check-namespaces 15,
  check-kids golden ✓.

## OWED (next GA increments — still ⚪)
- **The 10 XPAR `#8989.51` PARAMETER DEFINITIONs + patch bump** in
  `kids/vsl.build.json`, then the **live install → verify → back-out →
  verify-clean on BOTH VistA engines** (vehu YDB + foia IRIS, stopped now —
  startable) over the driver. That live proof is the real G-UNINST exit gate;
  the bare suite proves the logic only.
- **The production fidelity-run task** (wire `persist^VSLTAPFC`, cadence =
  `VSL TAP FIDELITY CADENCE`) so the VWEBT console shows a real match %, not
  `pending`.
- **DIBRG** (deploy/install/back-out/rollback guide), real-S3 endpoint flip
  config, fleet rollout runbook.

Extends [[phase4-fidelity-persist]] / [[phase3-egress-fidelity]] /
[[phase2-vsltap]].
