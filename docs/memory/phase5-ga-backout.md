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

# Phase 5 / M4 (GA): VSLTAPRUN periodic fidelity-run task (closes the console loop)

Second GA increment (same branch). `persist^VSLTAPFC`/`$$lastFidelity` exist
and VWEBT reads `^VSLTAP("fc","last")`, but **nothing in a live install calls
persist** — only the test suite — so the console fidelity panel shows `pending`
forever. `VSLTAPRUN` is the schedulable task that closes the loop.

## What was built (`src/VSLTAPRUN.m`)
- `$$reconcilePersist(corpus,envs)` — the **persist seam**: `$$reconcile^VSLTAPFC`
  then `do persist^VSLTAPFC(.res)` → writes `^VSLTAP("fc","last")`. Pure M,
  **bare-proven** — this is the one call that lights up the console.
- `$$cadence()` — the run period in seconds from XPAR `VSL TAP FIDELITY CADENCE`
  (default 3600); `$text(GET^XPAR)`-guarded → default on bare.
- `$$schedule()` — queues `run^VSLTAPRUN` at now+cadence via a **NON-persistent**
  `^%ZTLOAD` (each run re-queues the next — deliberately NOT a PSET self-
  restarting listener, so VSLTAPBO can cleanly dequeue it); records
  `^VSLTAP("task","fidelity")=task#` (the record VSLTAPBO.cleanTasks removes).
  `$text(^%ZTLOAD)`-guarded → returns 0 on bare.
- `do run()` — task body: **gate** (`$$enabled^VSLTAP` — OFF/disabled/no-consumer
  → skip, no false result), fault-fenced, `do liveReconcile()`, `reschedule()`.

## KEY design boundary — why `liveReconcile` is a deliberate fenced no-op (for now)
`drain^VSLS3` ships a **batch keyed by the last seq** and **trims the ring after**
shipping. So a source-vs-shipped byte-equality check **cannot use the ring as the
source** (it's gone post-drain) — it needs an INDEPENDENT durable source: the
**passive mirror** for RPC, or the **#772 store** for HL7 (the plan already lists
"VSLTAPFC HL7 live-periodic hook" as a remaining M2 item). That source-selection
seam lands with the **real-S3 increment** (plan §9 stage 5.2). The round-trip
itself is already proven (VSLTAPFC + `VSLS3E2ETST` vs MinIO). So this increment
delivers the **scheduler + gate + cadence + persist seam** (all bare-proven) and
leaves `liveReconcile` as the explicit integration point — NOT a fabricated live
comparison.

## Verification
- `tests/VSLTAPRUNTST.m` **8/8 dual-engine**; added to `BARE_TESTS` → full bare
  **194/194 both engines** (12 suites). `VSLTAPRUN` in the KIDS build (16
  routines); dist + registries regenerated; engine-free gates green (icr 25,
  citations 25, kids golden).

# Phase 5 / M4 (GA): KIDS param definitions + DIBRG (3rd increment)

Same branch. (a) The **10 tap XPAR `#8989.51` PARAMETER DEFINITIONs** added to
`kids/vsl.build.json` — names **exactly match `$$params^VSLTAPBO`** (the back-out
+ verify-clean targets), dataTypes numeric/yes-no/free-text, SYS entity. Dist
regenerated (16 routines / 11 params); **`check-kids` golden, all engine-free
gates green**. **Patch kept at `VSL*1.0*2`** (NOT bumped): `VSLBLD.$$manifest` +
`VSLBLDTST` assert `VSL*1.0*2` and run only on a live engine — the patch bump +
VSLBLD sync rides with the live-proof increment (where VSLBLDTST re-runs). (b)
The **DIBRG** written: `docs/traffic-tap-dibrg.md` — footprint table, install
(exact `v-pkg` driver commands per engine), configure, **back-out =
`do backout^VSLTAPBO()` THEN `v-pkg uninstall`** (runtime footprint first, then
routines), verify-clean exit gate, rollback.

# Phase 5 / M4 (GA): LIVE install→back-out→verify-clean PROVEN dual-engine + the seed step (4th increment)

Same branch. The **G-UNINST exit gate is GREEN on BOTH VistA engines** over the
driver: full `install → verify → footprint → backout^VSLTAPBO() → verifyClean →
uninstall` on **vehu (YDB-VistA, GT.M r2.02)** and **foia-t12 (IRIS-VistA
2026.1)**. Footprint = all **10 XPAR `#8989.51` params installed** (IENs found)
+ scheduled fidelity task (in `^%ZTSCH`) + seeded `^VSLTAP("cfg")` + a ring
record; after `backout`: **`clean=1`, paramsLeft=0, globals=0, task dequeued** on
both engines.

## The XPAR→cfg seed step (`seed`/`seedMap`/`seedOne` in VSLTAP)
The installed params are INERT until copied into `^VSLTAP("cfg")` — the hot-path
gate (`$$cfg`) and the VSLS3 ctx seam read `^VSLTAP("cfg")`, NOT XPAR (no XPAR
read on the capture path). `do seed^VSLTAP()` bridges them via `$$seedMap` (9
param→cfg mappings: `VSL TAP CAP→cap`, … `VSL S3 ENDPOINT→s3endpoint`,
`VSL S3 PREFIX→s3station`; the fidelity cadence is read from XPAR directly by
VSLTAPRUN, so it's not mirrored). `$text(GET^XPAR)`-guarded → bare no-op.
**Live-proven**: XPAR `VSL TAP CAP`=777 → `^VSLTAP("cfg","cap")`=777 on both
engines. The install/configure should `do seed^VSLTAP()` + `$$schedule^VSLTAPRUN`.

## BUG the live proof caught (bare tests could NOT)
`VSLTAPBO.delParam` built the FileMan FDA array as **`fda`** (lowercase) but
passed **`"FDA"`** to `FILE^DIE` — M is case-sensitive, so DIE read an empty
`FDA` and **deleted nothing**; the first live verify-clean returned 0 with
"10 … parameter definition(s) survive". Fix: uppercase `FDA`/`ERR` (the VSLFS
convention). On a BARE engine `FILE^DIE` is `$text`-skipped, so the mismatch was
invisible — **this is exactly why the live proof is the real exit gate**, not the
bare suite. (A direct `FDA`-cased `FILE^DIE .01="@"` deleted the record cleanly,
confirming the delete mechanism + isolating the bug to the var name.)

## Patch bump
`VSL*1.0*2`→`VSL*1.0*3` across `kids/vsl.build.json`, `VSLBLD.$$manifest`, and
`VSLBLDTST` (asserts it). **VSLBLDTST 15/15 + VSLTAPTST 42/42 live on vehu.**

## Verification (this increment)
- Live dual-engine: install/verify/back-out/verify-clean/uninstall green on vehu
  + foia-t12 (driver path; `--transport docker`).
- Bare: VSLTAPTST 42/42 (added 2 seed tests), full bare **198/198 both engines**
  (12 suites); engine-free gates green (icr 26, check-kids golden at patch 3).

# Phase 5 / M4 (GA): the fidelity source seam — console shows a real match % (5th increment)

Same workstream, branch `s3tap-livereconcile` (v-stdlib). The console's fidelity
panel was wired (`persist`/`$$lastFidelity`) but nothing produced a live result.
**`$$fidelityNow^VSLTAPRUN`** is the source seam that lights it up.

## What it does (`VSLTAPRUN.fidelityNow` + `VSLS3.list`)
Production fidelity that needs **no generated corpus and no separate process**:
1. `$$list^VSLS3` (new — wraps `listObjectsV2^STDS3`) enumerates the shipped
   objects under `traffic/<station>/<proto>/` (the §11 per-station prefix);
2. reads each back (`$$readback^VSLS3`), splits the NDJSON;
3. runs **`$$verify^VSLTAPFC`** on every envelope — the shipped payload re-hashes
   to the sha256 anchor captured at ship time → matched / mismatch;
4. `do persist^VSLTAPFC(.res)` → `^VSLTAP("fc","last")`, which VWEBT reads.

`run^VSLTAPRUN` now calls it (replacing the no-op `liveReconcile`): gate →
`$$fidelityNow()` → reschedule. Bounded by `fcmax` (default 50, the most-recent
keys); fenced; returns -1 (persists nothing) when there's no egress / nothing
shipped, so the console stays honest.

## What this proves — and the boundary
It proves the **ship → store → read-back path is byte-faithful to what the tap
captured** (catches storage / transport / encoding corruption — exactly the
egress bugs the build hit: IRIS `WriteRawMode`, the YDB callout ABI). It is
**round-trip integrity** (shipped == captured-and-hashed), NOT the deeper
**capture == wire** check. That deeper leg still needs an independent durable
source (passive mirror for RPC / #772 for HL7) and stays a documented future
enhancement — but the operator console now shows a **real, current production
match %** from actual shipped traffic, not `pending`.

## Verification
- **MinIO matrix GREEN on BOTH engines: `VSLS3E2ETST` 15/15** (YDB + IRIS) — the
  round-trip + 2 new tests: `fidelityNow` integrity-verifies all 7 shipped
  envelopes (matched=7, ok=true), and **catches a planted tampered object**
  (payload≠hash → mismatch>0, ok=false). It's in `make ci` (`test-s3-matrix`).
- Bare 198/198 (no regression — `fidelityNow` only runs with egress); engine-free
  gates green (check-kids golden; `$$list^VSLS3` is v→m, no new ICR).

## OWED (remaining GA — narrowed)
- **Deeper capture==wire fidelity** (mirror / #772 independent source) — future
  enhancement; round-trip integrity covers the egress path today.
- **Real-S3 endpoint flip** smoke — code-complete, real-bucket smoke skipped (user).
- **Fleet rollout (5.4)** — **deferred indefinitely (user, 2026-06-21)** until an
  actual deployment need is established.

> Live-engine driver env recipe (for the next live session): YDB
> `M_YDB_CONTAINER=vehu M_YDB_GBLDIR=/home/vehu/g/vehu.gld M_YDB_ROUTINES='/home/vehu/{p,s,r}/r2.02_x86_64*(...) /home/vehu/lib/gtm/libgtmutil.so'`;
> IRIS `M_IRIS_TRANSPORT=docker M_IRIS_CONTAINER=foia-t12 M_IRIS_NAMESPACE=VISTA M_IRIS_IRIS_INSTANCE=IRIS`.
> `v-pkg install` refuses re-install of the same patch ("already-installed") —
> uninstall first. Engines were stopped; `docker start vehu foia-t12`.

Extends [[phase4-fidelity-persist]] / [[phase3-egress-fidelity]] /
[[phase2-vsltap]].
