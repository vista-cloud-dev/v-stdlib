---
name: vsl-wrapping-baseline-audit
description: 2026-06-28 dual-engine adversarial audit of all six VSL* modules → the VistA-library wrapping baseline (coverage model + stress policy + 9 gates) and FOUR verified-open defects (VSLSEC default-duz UNDEF, VSLIO RED on IRIS, VSLFS E-flag doc/code, VSLTASK "@"). Green YDB suites masked them.
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

## Four OPEN defects (verified; true until fixed — keep until each lands)
1. **VSLSEC default-duz UNDEF** — single-arg `$$hasKey(key)`/`$$user()` raise UNDEF
   on BOTH engines: `$$pduz(duz)` evaluates an omitted formal by value before its
   `$get` (`src/VSLSEC.m` `pduz`). Fix: `$$pduz($get(duz))` / `.duz`. Suite masks it
   (always passes explicit duz).
2. **VSLIO RED on IRIS** — `VSLIOTST` 9/10 exit 3 on foia (green on vehu): `$$write`
   has no `$ZVERSION["IRIS"` flush arm → client→server bytes dropped on IRIS.
   Corrects the old [[m2-vslio]] "needs no $ZVERSION arm / IRIS soft-skips" claim
   (now stale: `$$available^STDNET()=1` on IRIS). **Committed RED on a supported
   engine — the dual-engine gate is not actually green today.**
3. **VSLFS E-flag** — `$$set` doc says "external value" but `UPDATE^DIE` has no `E`
   flag → files INTERNAL (corpus + [[r3a-vsllog-audit-dd]]). Only free-text `.01`
   round-trips; DATE/POINTER/SET would file wrong silently.
4. **VSLTASK schedule `@`** — docstring "`@` = ASAP" is backwards; corpus
   `XU/krn_8_0_dg_taskman_ug#example-7` = `ZTDTH="@"` means do-NOT-schedule. (This
   was wording R5a introduced — the audit caught its own house's error.)

## Cross-cutting
- **Corpus empty-body anchors** (systematic, not per-module): `VSLCFG set()`,
  `VSLLOG $$NOW^XLFDT`, `VSLTASK queue()`, and ALL FIVE VSLFS DBS anchors resolve but
  return empty text → `@status Supported` not corpus-confirmable for the VSLFS
  surface. One vdocs pipeline re-extraction task, not six doc edits.
- **In-scope missing verbs** classified: VSLFS `GETS^DIQ`/`WP^DIE`, VSLSEC
  `$$ACTIVE^XUSER`, VSLTASK `$$ASKSTOP`/`PCLEAR`/`STAT` (the stop/retire/observe
  half), VSLCFG `DEL^XPAR`.

Deliverable was analysis-only (no code/test changes). Forward path: fix the four
High defects as TDD increments (VSLIO first — it's CI-red on IRIS), then adopt the
coverage model + add the missing test categories to the six suites.
