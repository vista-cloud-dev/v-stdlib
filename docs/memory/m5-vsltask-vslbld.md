---
name: m5-vsltask-vslbld
description: VSL/MSL M5 DONE — VSLTASK (TaskMan persistent-listener / process seam) + VSLENV (KIDS env-check) + VSLBLD (full KIDS base build + back-out / packaging seam) in v-stdlib. Dual-engine GREEN 23/23 (vehu YDB + foia-t12 IRIS); KIDS install→verify(8 routines+param)→back-out→verify-clean both engines. GROUNDED: TaskMan is LIVE on BOTH engines ($$TM^%ZTLOAD=1) so liveness+API+error-contract are live-green; the destructive self-restart observation is soft-skipped (runaway-unsafe). Lane A NO-OP (pin stays v0.9.0). All ICRs corpus-verified: ^%ZTLOAD=#10063, XPDUTL=#10141, XPAR=#2263.
metadata:
  type: project
---

# VSL T-M5 — VSLTASK (process seam) + VSLBLD/VSLENV (packaging seam), 2026-06-17

The listener + packaging seams (§12.2). Branch `m5-vsltask-vslbld` off `main`.
Adds **VSLTASK** (6th), **VSLENV** (7th), **VSLBLD** (8th) `VSL*` routines.
**Dual-engine GREEN 23/23** (VSLTASK 8 + VSLBLD 15) on `vehu` (YDB GT.M V7.0-005)
+ `foia-t12` (IRIS); full v-stdlib suite **56/56** on vehu (no regression).
**Lane A NO-OP** — no MSL seam change (process+build seams have no pure MSL
contract); m-stdlib untouched, **no new tag**, pin stays **`v0.9.0`**.

## GROUNDED Q1: TaskMan is LIVE on BOTH engines — so liveness is REAL green, not a skip
The M5 grounding risk (analog of M4's hash-grounding). Probed via the driver
(`m vista exec --engine ydb/iris --transport docker`):
- **`$$TM^%ZTLOAD()` = 1 on BOTH** vehu and foia-t12 — TaskMan's scheduler
  heartbeat (`^%ZTSCH("RUN")`, $H format) is fresh (<500s; the `TM^%ZTLOAD`
  extrinsic checks exactly that). On vehu the heartbeat ticked **6s** before the
  probe.
- All `^%ZTLOAD` API resolves on both: `$$PSET`/`$$TM`/`$$S`/`KILL`/`STAT`.
- So VSLTASK's **liveness, cooperative-stop, the whole API binding, and the loud
  error contract are asserted LIVE-GREEN** — a NARROWER soft-skip than M2's
  loopback (only the destructive restart observation is skipped).

### Why the live SELF-RESTART is SOFT-SKIPPED (not blocked, not faked)
Observing a real self-restart (queue a sentinel task → drop its `^%ZTSCH("TASK",n)`
lock → poll for a TaskMan re-run) is **runaway-unsafe in an automated unit test**,
for two grounded reasons read off the live `^%ZTLOAD` source:
1. **The restartable body must be a RESIDENT routine.** TaskMan's submanager runs
   the task in a separate process off the engine's resident routine path; a
   test-staged VSLTASK is invisible to it. A real sentinel task needs VSLBLD/v-pkg
   to install it resident first — an integration test, beyond M5's unit scope.
2. **A PSET-persistent task is deliberately un-KILLable.** `^%ZTLOAD` `KILL`
   refuses a persistent task (`I $D(^%ZTSCH("ZTSK",ZTSK,"P")) Q`) — exactly the
   runaway the kickoff forbids ("never leave a runaway task").
The restart CONTRACT is bound + documented (`$$PSET^%ZTLOAD` sets
`^%ZTSCH("TASK",n,"P")`; TaskMan re-runs on a lock drop) and asserted *wired*;
the live observation is an infra/integration-gated follow-up.

### Headless-queue gotcha (for the future live integration test)
`^%ZTLOAD` (QUEUE→`^%ZTLOAD1`) **prompts interactively** (`ASK^%ZTLOAD2`) unless
`ZTDTH` is `"@"` or a **≤5-digit-day** `$H` (pattern `1.5N1","1.5N`). A
`$H`-day+offset that overflows to 6 digits (e.g. +36500 today) trips the prompt
and hangs a test. `$$schedule^VSLTASK` always sets `ZTDTH=$H` (now), never blank.

## VSLTASK — the TaskMan binding (5 entry points, all ICR #10063 Supported)
- `$$running^VSLTASK()` → `$$TM^%ZTLOAD()` — is the scheduler live? (the self-heal
  precondition; live-green=1 both engines).
- `$$stop^VSLTASK()` → `$$S^%ZTLOAD` — should the listener loop stop? (0 outside a
  queued task — a normal negative, NOT an error).
- `$$persist^VSLTASK(ztsk)` → `$$PSET^%ZTLOAD(ztsk)` — mark a queued task
  self-restarting. Loud `,U-VSL-TASK-ARG,` on a missing/non-positive task#.
- `$$schedule^VSLTASK(entry,desc,when)` → headless `^%ZTLOAD` queue (ZTRTN/ZTDESC/
  ZTIO=""/ZTDTH) + `$$PSET`; returns the task#. Loud `,U-VSL-TASK-ARG,` (no entry)
  / `,U-VSL-TASK-QUEUE,` (queue/persist fault). **Live queue soft-skipped** (the
  arg-guard fires first in the test, so no task is ever queued live).
- `$$lastError^VSLTASK()` → `^TMP($job,"vsltask","err")`.
- Flag-based `$ETRAP` (NEVER zgoto — the M4 [[m4-vslsec-vsllog]] harness-abort
  gotcha); OUR trap cleared before any re-raise. STDLOG diagnostics are the
  intended sink (v→m), not re-implemented.

## VSLBLD + VSLENV — the packaging seam
**VSLENV** = the single **SELF-CONTAINED** KIDS env-check routine (the `XPDENV`
hook), named in the build's `"envCheck"`. KIDS loads only it at check time + runs
it twice (XPDENV signals the phase), so it calls only intrinsics + RESIDENT Kernel
APIs (no STD*/VSL*). Reports engine/version (`$ZVERSION`), Kernel level
(`$$VERSION^XPDUTL("XU")`, #10141), TLS-config presence (`$$GET^XPAR("SYS",
"DEFAULT TLS SERVER CONFIG",1)`, #2263); aborts (`XPDQUIT=2`) only if Kernel is
absent (never on a VistA). `$$check^VSLENV(.facts)` returns the facts off-install
(faultable reads isolated + trapped → always returns 1, all 4 facts defined).

**VSLBLD** = the build-definition binding (no duplication of v-pkg's install
mechanics — in-`v` waterline):
- `$$manifest^VSLBLD(.out)` → the base's self-description: `out("routines",1..8)`,
  `out("requiredBuild")="MSL*0.1*1"`, `out("patch")="VSL*1.0*2"`; returns 8.
- `$$envCheck^VSLBLD(.facts)` → `$$check^VSLENV` (v→v).
- `$$requireBase^VSLBLD(build)` → `''$$PATCH^XPDUTL(build)` (#10141) — the **R6
  version-skew** check (1 iff the named base build is installed). An absent base
  is a normal `0` (NOT an error); empty build name → loud `,U-VSL-BLD-ARG,`.
- `$$lastError^VSLBLD()` → `^TMP($job,"vslbld","err")`.

## Q2: the KIDS base matured IN PLACE on `main` (T1.3's base → full scale)
`kids/vsl.build.json` bumped **VSLCFG-only `VSL*1.0*1` → all-8 `VSL*1.0*2`**:
routines `[VSLBLD,VSLCFG,VSLENV,VSLFS,VSLIO,VSLLOG,VSLSEC,VSLTASK]` + `"envCheck":
"VSLENV"` + the unchanged VPNG GREETING #8989.51 param + Required Build
`MSL*0.1*1` (LEAVE GLOBAL). `make kids` → `dist/kids/VSL.kids` (8 routines/1
param/1 reqBuild); `make check-kids` golden-clean. **FileMan DD files stay
DEFERRED** (the v-pkg DD-install track) — the base ships routines+XPAR-def+Required
Build+env-check, the T1.3 shape just fuller. (Includes the 3 new M5 routines too —
the honest "full VSL base" is whatever's in `src/`, now 8, not the kickoff's
literal "5"; `check-namespaces` counts all 8.)

## KIDS install→verify→back-out→verify-clean — GREEN on BOTH engines (full base)
Driven by **v-pkg standalone** over the driver (a SHELL step, like T1.3; NOT from
M). Both engines: install → `installed:true status:3`; verify → status 3 + **all 8
routines true** + `params."VPNG GREETING":true`; uninstall → `uninstalled:true`;
verify-clean → all 8 routines + param **false**, **process exit 3** (the clean
signal; the JSON envelope `.exit` is 0 — read the *process* exit). Recipes exactly
as T1.3 ([[t1.3-vsl-kids]]): YDB `--engine ydb --transport docker` + `M_YDB_*`
(CONTAINER=vehu, GBLDIR=/home/vehu/g/vehu.gld, ROUTINES=vehu gtmroutines); IRIS
`--engine iris --transport docker` + `M_IRIS_*` (CONTAINER=foia-t12,
NAMESPACE=VISTA, IRIS_INSTANCE=IRIS).

## ICRs — corpus-verified (decision 3; the plan's prose was right this time)
`corpus-researcher` confirmed against the gold corpus:
- **`^%ZTLOAD` whole programmer API = ICR #10063, Supported, custodian XU** (a
  SINGLE DBIA covers PSET/TM/S/queue — Table 28). Citations:
  `XU/krn_8_0_dg_taskman_ug#{psetztload-set-task-as-persistent,tmztload-check-if-taskman-is-running,sztload-check-for-task-stop-request}`,
  `XU/krn_8_0_tm#callable-entry-points`.
- **`XPDUTL` KIDS API = ICR #10141, Supported, custodian XU** (VERSION/PATCH/MES/
  BMES). Citations: `XU/krn_8_0_dg_kids_ug#{versionxpdutl-...,verifying-patch-installation,mesxpdutl-output-a-message}`.
- `$$GET^XPAR` = **#2263** (reused from [[t1.2-vslcfg]]).
- `XPDENV`/`XPDQUIT` are KIDS control VARIABLES (no ICR; not `^refs` → invisible to
  the gate anyway).
All 6 cited doc_keys are **gold (`is_latest=1`)** — the architecture's
"gold-promotion-pending" note on the TaskMan/KIDS guides is STALE (already
promoted; M4 used the security-keys guide fine).

## Gate change — `gen-icr.py` now enforces the `XPD` namespace as L4
KIDS calls enter the codebase for the first time at M5. Added `XPD`/`XPDUTL`/
`XPDIL`/`XPDIJ`/`XPDID`/`XPDI` to `VISTA_API_PREFIXES` (+ a self-test case) so
`$$VERSION/$$PATCH/MES/BMES^XPDUTL` are gated, not silently passed. (`%ZTLOAD`
was already in the list.)

## Gates (all green) + recipe
`make check-fast`: fmt/lint (0) + `m arch check .` (layer v) + check-seams (0 —
all consumers) + **check-icr 17** (VSLCFG 2 + VSLIO 2 + VSLFS 4 + VSLSEC 1 +
**VSLTASK 4 + VSLENV 3 + VSLBLD 1**) + **check-citations 17** (vs gold) +
**check-namespaces 8 routines** + **check-msl-pin v0.9.0** (no re-pin) +
check-engine-access + **check-kids golden** (8 routines). Engine recipe (driver
ONLY): `m test --engine ydb --docker vehu --chset m --routines src --routines
<m-stdlib>/src tests/VSLTASKTST.m tests/VSLBLDTST.m` (IRIS: `--engine iris
--docker foia-t12 --namespace VISTA`).

## Owed / next
- **Live self-restart integration test** (infra/integration-gated): install a
  resident sentinel via VSLBLD/v-pkg, queue+PSET it, drop its `^%ZTSCH("TASK",n)`
  lock, bounded-poll for the re-run, clean up. Out of M5's safe-unit scope.
- **M5 is the LAST `VSL*` library milestone. Next: M6** (`VWEB` — FHIR GET
  /Patient over HTTPS consumer vertical, §12.2) + the §6.2 worked examples. M6's
  env-check **Requires + extends** VSLENV (TLS-config presence, IRIS-for-Health
  minimum).
Companion to [[t1.3-vsl-kids]] (the base it matures), [[m4-vslsec-vsllog]] (the
$ETRAP gotcha + Lane-A-NO-OP rhythm), [[t1.2-vslcfg]] (the #2263 XPAR citation),
shared [[notional-dbia-not-a-blocker]] + [[engine-access-through-driver-stack]].
