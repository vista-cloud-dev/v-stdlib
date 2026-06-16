---
name: m3-vslfs
description: VSL/MSL M3 Lane B DONE — VSLFS binds the STDKV storage seam (MSL v0.9.0) to VistA's FileMan DBS (UPDATE^DIE / $$GET1^DIQ / FILE^DIE). Re-pinned msl_ref v0.8.0→v0.9.0. Dual-engine GREEN 7/7 (vehu YDB + foia-t12 IRIS) over #8989.51: create/get byte-identical, exists, kill (FDA .01="@"), DIERR→,U-VSL-FS-DIERR, $ECODE. 3 boundaries green; ICR notional (DBS marker).
metadata:
  type: project
---

# VSL T-M3 Lane B — VSLFS (FileMan DBS storage adapter), 2026-06-16

The VistA side of the M3 storage seam (S1): `VSLFS` binds the portable MSL
`STDKV` seam (MSL **v0.9.0**) to VistA's FileMan Database Server (DBS) API.
Branch `m3-vslfs` **stacked on `m2-vslio`** (NOT off `main` — m2-vslio is
unmerged and carries the Makefile `--routines $(SRC)` test fix + the
icr-registry/pin tooling VSLFS needs; branching off main would regress VSLIO).
Merge order: m2-vslio → m3-vslfs. Third `VSL*` module (after VSLCFG, VSLIO).

## Re-pin (boundary ①)
`make pin` after hand-setting `dist/msl-seam-pin.json` `msl_ref` v0.8.0→**v0.9.0**:
syncs the `seams` block from `git show v0.9.0:dist/seam-snapshot.json` → now
carries **STDENV + STDNET + STDKV** (STDKV = 4 verbs). `check-msl-pin` green.

## The adapter — FileMan DBS binding ONLY (4 verbs, same signature as STDKV)
`$$set^VSLFS(file,iens,field,value)`→resolved IENS · `$$get(file,iens,field,
default)` · `$$exists(file,iens)`→1/0 · `$$kill(file,iens)`→1 · `$$lastError()`.
- **set** = `UPDATE^DIE("","FDA","IEN","ERR")` (handles both `"+1,"` add and
  in-place file); returns the resolved IENS (for an add, the new IEN from
  `IEN(n)` via `resolveIens`). Pragmatic adapter return (like VSLIO's device
  handle), not STDKV's bool — FileMan create must surface the new IEN.
- **get/exists** = `$$GET1^DIQ(file,iens,field,"","","ERR")`. A DIERR on a read
  is NOT an error — `$$get` returns the default, `$$exists` returns 0 (the STDKV
  "absent → default" semantics). exists probes `.01`.
- **kill** = delete via an FDA **`.01="@"`** through `FILE^DIE("","FDA","ERR")`.
  **KEY corpus finding: there is NO `DELETE^DIE`** — the Supported DBS delete is
  filing `.01="@"`; `^DIK`/direct global KILL are forbidden (Classic/non-DBS).

## Error contract — loud (kickoff decision 4)
A DIERR on a **write** maps to a clean **`,U-VSL-FS-DIERR,`** `$ECODE` (via
`raiseDierr`), with the composed DIERR TEXT in `^TMP($job,"vslfs","err")` for
`$$lastError`. Every DBS call passes an explicit **MSG_ROOT `"ERR"`** so errors
land in the adapter's own array, never the shared `^TMP("DIERR",$J)`. `kill` is
idempotent (records a DIERR, still returns 1).

## Test file — an EXISTING low-risk file (no DD install; that's the deferred v-pkg track)
**#8989.51 PARAMETER DEFINITION**: `.01` (NAME) is free-text with **NO other
required fields** (verified live via a DD probe — `^DD(8989.51,*)`), so a
throwaway **ZZ-namespaced** record (`"ZZVSLFS "_$job_<tag>`) is created and
deleted cleanly through the DBS API. The NAME is uppercase, so the round-trip
value is **transform-invariant** → byte-identical set→get over real FileMan.
Present on both engines.

## Acceptance — dual-engine GREEN 7/7 (the exit criterion)
3 tests / 7 assertions on **BOTH** `vehu`(YDB) and `foia-t12`(IRIS): create→get
byte-identical, exists→kill→exists-false→get-default, and DIERR-is-loud
(`$$set` into bogus file 99999999 raises `U-VSL-FS-...`, `$$lastError` carries
the FileMan text). **No `$ZVERSION` arm** — FileMan DBS is VistA-portable
(kickoff decision 5 confirmed). Full v-stdlib suite on vehu **22/22** (VSLCFG 3 +
VSLFS 7 + VSLIO 10 + smoke 2) — no regression. Recipe: `m test --engine ydb
--docker vehu --chset m --routines src --routines <m-stdlib>/src tests/VSLFSTST.m`
(IRIS: `--engine iris --docker foia-t12 --namespace VISTA`). Driver stack only.

## ICR is NOTIONAL — never a blocker (gate change shipped here)
The FileMan DBS API has **no ICR number in the gold corpus** (custodian DI, doc
`DI/fm22_2dg`) — and per the user directive the DBIA registry is a notional,
human-curated FORUM list, not enforced programmatically. So `tools/gen-icr.py`
now accepts a **notional marker** `@icr DBS` (NOTIONAL_MARKERS) in place of a
number; the gate's real invariants stay (`@status Supported` + no-direct-global).
Each VSLFS call: `; doc: @icr DBS @call <c> @status Supported @custodian DI
@source DI/fm22_2dg#<anchor>`. See shared memory [[notional-dbia-not-a-blocker]]
+ plan §5.4. Do NOT re-raise the missing-number as a gap.

## Gates (all green)
`make check-fast`: fmt/lint (**0 findings** — restructured `stashDierr`'s `$order`
loops to the `for  quit  do` house idiom to clear M-MOD-009 4-commands/line) +
`m arch check .` (layer v) + check-seams (0 — VSLFS is a consumer) + **check-icr
(8: VSLCFG #2263×2 + VSLIO #2118×2 + VSLFS DBS×4)** + **check-citations (8 vs
gold corpus — DI/fm22_2dg anchors verified)** + check-namespaces (3 VSL routines)
+ **check-msl-pin (v0.9.0)** + check-engine-access. No KIDS/VSLBLD (that's M5).

## Owed / next
- **M2 tail** (parallel, unblocked): STDNET IRIS leg + tier-3 TLS.
- **DD-install enabler** (deferred v-pkg track): teach `v pkg` the FileMan
  FILE-DD component, then re-test VSLFS with a throwaway *dedicated* file
  instead of #8989.51. The "DD install" the M3 milestone bundles.
- **Next: M4** (VSLSEC + VSLLOG — security + audit seams, §12.2). VSLLOG reuses
  this FileMan-DBS binding (S3) for the audit-file sink.
Companion to [[m2-vslio]] (the Lane-B adapter rhythm) + the m-stdlib leaf
`m3-stdkv-storage-seam`.
