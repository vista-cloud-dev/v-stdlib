---
name: vsl-wrapping-baseline-audit
description: 2026-06-28 dual-engine adversarial audit of all six VSL* modules → the VistA-library wrapping baseline (coverage model + stress policy + 9 gates) and four defects, ALL FIXED 2026-06-28 (VSLSEC default-duz UNDEF, VSLIO RED on IRIS, VSLFS internal-doc, VSLTASK "@"). Green YDB suites had masked them. Remaining = enhancements (missing verbs, coverage-model test categories).
metadata:
  type: project
---

# VSL* wrapping baseline audit (2026-06-28)

A 20-agent workflow + hand-verification audited all six `VSL*` modules on three
axes (docs↔GOLD-corpus, code↔live-dual-engine, coverage-of-wrapped-lib) and
produced the **VistA-library wrapping baseline**:
`docs/proposals/vista-library-wrapping-baseline.md` (the canonical record — coverage
model, stress-test policy, anti-redundancy rules, 9-gate baseline, per-module recs).

## Durable lesson
**Green canonical suites masked four real defects.** The suites passed
explicit-arg / valid-input / transform-invariant / prefix-`$ECODE`-match paths and
never reached the contract edges. "Comprehensive coverage" for a VistA wrapper is
the 7-category model in the doc — happy-path green is necessary, not sufficient.

**The omitted-optional-arg UNDEF is a SYSTEMIC class, not a one-off.** It bit VSLSEC
(`duz`, 2026-06-28) and then VSLCFG (`default` in `$$get`/`$$getEffective`,
2026-06-29 — `$select(v="":default,...)` evaluates the undefined formal). The
contract-shape coverage category (P1) exists to catch exactly this: **every optional
formal in a VSL routine must be `$get`-guarded** before use (raw read, `$select`
branch, or `$data`-less reference). When adding any VSL verb, test the
omit-the-optional path, not just the all-args-supplied path.

## Four defects (verified) — ✅ ALL FIXED 2026-06-28 (commits 0acedb0, c56df66, f0df013, + this)
1. **VSLSEC default-duz UNDEF — ✅ FIXED 2026-06-28.** single-arg
   `$$hasKey(key)`/`$$user()` raised UNDEF on BOTH engines: `$$pduz(duz)` evaluated an
   omitted formal by value before its `$get`. Fix: call sites pass `$$pduz($get(duz))`.
   Added regression tests + an engine-split `$$safeRun` helper in VSLSECTST so a
   "does-not-raise" assertion fails **cleanly** instead of aborting the suite 0/0
   (the plain `eq^STDASSERT` of a raising call aborts the whole suite — confirmed on
   both engines). `VSLSECTST` 17/17 dual-engine. **Test-design lesson:** to assert a
   call does NOT raise, capture via XECUTE under the engine-split trap (IRIS
   try/catch, YDB `$ETRAP`+ZGOTO — never arg-less QUIT around a `$$` frame).
2. **VSLIO RED on IRIS — ✅ FIXED 2026-06-28.** `VSLIOTST` was 9/10 exit 3 on foia
   (green on vehu): `$$write` had no `$ZVERSION["IRIS"` flush arm → client→server
   bytes dropped on IRIS. Fix: `if $zversion["IRIS" write *-3` after the write
   (mirrors `$$writeIris^STDNET`); now **10/10 on both engines**. Also corrected the
   stale [[m2-vslio]] "needs no $ZVERSION arm / IRIS soft-skips" claim
   (`$$available^STDNET()=1` on IRIS now). Lesson stands: an engine-divergent I/O arm
   that a stale soft-skip never runs on IRIS is exactly where a portability bug hides.
3. **VSLFS E-flag — ✅ FIXED 2026-06-28 (doc, not code).** `$$set` doc said
   "external value" but `UPDATE^DIE` has no `E` flag → files INTERNAL
   ([[r3a-vsllog-audit-dd]]). The CODE is correct and VSLLOG depends on internal
   filing, so the fix corrected the contract doc (value is INTERNAL; `$$set` files
   internal while `$$get` defaults external — read transformed fields back with
   `$$get(...,"I")`), plus a lock-in test (`tInternalFilingRoundtrip`) proving
   internal≠external via the resident #999001 DATE field (#999000's `.01` is
   transform-invariant). VSLFSTST 16/16 dual-engine. **"Pass E" would have broken
   VSLLOG — the doc was the bug.** Deferred: a DATE field on #999000 (v-pkg testdata,
   cross-repo).
4. **VSLTASK schedule `@` — ✅ FIXED 2026-06-28 (doc-only).** docstring "`@` = ASAP"
   was backwards; corpus `XU/krn_8_0_dg_taskman_ug#example-7` = `ZTDTH="@"` means
   do-NOT-schedule (defer). Fixed: `when` doc says omit it (→ `$HOROLOG`, the code
   default) to run now; `"@"` defers. Also dropped the "deliberately un-KILLable"
   wording from the user-facing doc — the corpus `KILL^%ZTLOAD` contract documents
   only success/invalid-task (no persistence exemption), so the doc no longer asserts
   un-killability; the real obstacle is the un-undoable side effect on a shared
   engine. **Discrepancy (unresolved):** [[m5-vsltask-vslbld]] has a *code-derived*
   "`KILL` refuses a persistent task (`I $D(^%ZTSCH("ZTSK",ZTSK,"P")) Q`)" note —
   undocumented in the corpus; could be real undocumented routine behavior, left
   neutral in the doc rather than asserting either way. `VSLTASKTST` 8/8 dual-engine.
   (The `"@"`=ASAP wording was R5a's — the audit caught its own house's error.)

## Cross-cutting
- **Corpus empty-body anchors** (systematic, not per-module): `VSLCFG set()`,
  `VSLLOG $$NOW^XLFDT`, `VSLTASK queue()`, and ALL FIVE VSLFS DBS anchors resolve but
  return empty text → `@status Supported` not corpus-confirmable for the VSLFS
  surface. One vdocs pipeline re-extraction task, not six doc edits.
- **In-scope missing verbs** classified: VSLFS `GETS^DIQ`/`WP^DIE`, VSLSEC
  `$$ACTIVE^XUSER`, VSLTASK `$$ASKSTOP`/`PCLEAR`/`STAT` (the stop/retire/observe
  half), VSLCFG `DEL^XPAR`.

The audit deliverable was analysis-only; **all four High defects were then fixed as
TDD increments (2026-06-28)** — VSLIO, VSLSEC, VSLFS, VSLTASK all green dual-engine.
**Remaining (enhancement, not defects)** — tracked + prioritized with a paste-ready
resume prompt in **`docs/vsl-coverage-enhancements-tracker.md`**: P1 coverage-model
test backfill (exact-ecode, default-arg, boundary, volume/residue), P2 in-scope
missing verbs, P3 corpus empty-anchor re-extraction + doc-accuracy, P4 the
`KILL^%ZTLOAD`-vs-persistent discrepancy. New session: read that tracker first.
