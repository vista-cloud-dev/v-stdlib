---
name: m3-vslfs
description: VSL/MSL M3 Lane B DONE — VSLFS binds the STDKV storage seam (MSL v0.9.0) to VistA's FileMan DBS (UPDATE^DIE / $$GET1^DIQ / FILE^DIE). Re-pinned msl_ref v0.8.0→v0.9.0. Dual-engine GREEN 7/7 (vehu YDB + foia-t12 IRIS): create/get byte-identical, exists, kill (FDA .01="@"), DIERR→,U-VSL-FS-DIERR, $ECODE. 3 boundaries green; ICR notional (DBS marker). M3.T1 (2026-06-17): re-proven against the DEDICATED #999000 ZZVSLFS installed by the v-pkg FileMan-DD enabler (borrowed #8989.51 retired).
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

## Test file — NOW the DEDICATED throwaway #999000 ZZVSLFS (M3.T1 part 2, 2026-06-17)
`tests/VSLFSTST.m setup()` points at **#999000 ZZVSLFS**, a dedicated throwaway
file the **v-pkg FileMan-DD enabler installs from scratch** (`.01` NAME free text,
1–30 chars, data global `^DIZ(999000,` — see v-pkg `fileman-dd-component.md`). The
ZZ-namespaced record (`"ZZVSLFS "_$job_<tag>`) round-trips byte-identical; VSLFS.m
is unchanged (file-number parameterized) — only `setup()` `8989.51`→`999000` + the
header comment changed.
**Original M3 acceptance used a BORROWED file** (#8989.51 PARAMETER DEFINITION,
free-text `.01`, no other required fields) — no DD install needed; that was the
decoupled track now closed.
**Fixture-install acceptance harness (driver stack only), per engine:** `v pkg
install /tmp/ZZVSLFS.kids --engine <e> --transport docker` (DD must be RESIDENT
before `m test`) → `m test --engine <e> --docker <c> [...] tests/VSLFSTST.m` → `v pkg
uninstall …`. The `.KID` is built from v-pkg `testdata/zzvslfs/kids/ZZVSLFS.build.json`
(v-pkg branch `m3t1-fileman-dd`, byte-identical to the committed golden). **Re-proven
dual-engine 7/7 (vehu YDB + foia-t12 IRIS), clean back-out each (`^DD/^DIC/^DIZ(999000)`
+ #9.7 all gone); full suite 56/56 with the fixture resident.** Note: `m test --docker`
and `v pkg --transport docker` are two engine paths — don't cross their flags.

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

## F1 internal-filing hazard — `$$set` SILENTLY corrupts on `^` / over-width (2026-06-29 adversarial)
`$$set` files INTERNAL (`UPDATE^DIE`, no `"E"` flag → no input transform), so it
does **NOT** validate the `^` piece delimiter or the field width, and the corruption
is **SILENT (no DIERR)** — confirmed live on vehu (YDB) + foia (IRIS):
- A `^`-bearing value files with no error; `$$get` reads back only the **first
  `^`-piece** (silent truncation / data loss).
- **Severe**: when the target field shares its storage node with sibling fields, the
  extra `^`-pieces silently **OVERWRITE the siblings** (cross-field corruption). Ground
  truth on the canonical #999001 VSL AUDIT: `.01` is at node `0;1`, TIMESTAMP at `0;2`
  (SAME node), so `$$set(.01,"A^B^C")` lands `"B"` in TIMESTAMP and `"C"` in USER — and
  a later external/`GETS` read of the now-non-date TIMESTAMP **faults**. (This is what a
  `^`-bearing VSLLOG `event` does before its own field-sets overwrite the pieces back.)
- An over-width value files **oversize** (the 30-char DD width is not enforced).
- **CORRECTION**: do NOT believe "FileMan raises loud when `^` would overflow a sibling"
  — an earlier first-pass note claimed that; the clean canonical file proves it is
  silent. (The transient "raise" seen earlier was an artifact of an already-damaged file.)
- Pinned: `tests/VSLFSTST.m` tCaretSilentlyTruncates / tOverWidthSilentlyStored /
  tCaretSilentlyCorruptsSibling + the `$$set` doc + module-header HAZARD notes.
- **Why:** callers must never pass `^`-bearing or over-width values to a free-text DBS
  field through `$$set`; there is no guard and the failure is silent.

## v-pkg KIDS install of #999001 on vehu — the env incantation (operational, 2026-06-29)
`v pkg install … --engine ydb --transport docker` against **vehu** fails with
`stage ZVPKGRD: driver loaded no routine` UNLESS the m-ydb docker driver is told the
container AND a writable routine path via env:
`M_YDB_CONTAINER=vehu M_YDB_ROUTINES='/home/vehu/r/r2.02_x86_64*(/home/vehu/r) /home/vehu/p/r2.02_x86_64*(/home/vehu/p)' v pkg install --engine ydb --transport docker --allow-overwrite dist/kids/VSL.kids`.
(The m-cli `m test --docker vehu` path stages routines on its own; the SDK-client path
v-pkg uses does not yet — "Load staging lands in M2/M3", m-ydb session.go.) **Caution:**
heavy adversarial `$$set`/`$$kill` on #999001 can leave/delete the file — a destructive
run **wiped `^DD/^DIZ/^DIC(999001)` entirely**; restore with the install above, then the
full vehu suite is green again (130/130). The #999001-dependent suite tests are
**unguarded** (abort 0/0 if the DD is absent), so #999001 must be RESIDENT to run
VSLFSTST/VSLLOGTST. Read live globals for diagnosis via the sanctioned `m vista exec
--engine ydb --transport docker` (needs `M_YDB_CONTAINER=vehu`; it DOES capture device
output, unlike a bare default-transport exec).

## Owed / next
- **M2 tail** (parallel, unblocked): STDNET IRIS leg + tier-3 TLS.
- **DD-install enabler + re-test — DONE (M3.T1, 2026-06-17).** v-pkg learned the
  FileMan FILE-DD component (`fileman-dd-component.md`); VSLFS re-proven against the
  dedicated #999000 ZZVSLFS, dual-engine 7/7, borrowed #8989.51 out of the loop.
- **Next: M4** (VSLSEC + VSLLOG — security + audit seams, §12.2). VSLLOG reuses
  this FileMan-DBS binding (S3) for the audit-file sink.
Companion to [[m2-vslio]] (the Lane-B adapter rhythm) + the m-stdlib leaf
`m3-stdkv-storage-seam`.
