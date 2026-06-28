# v-stdlib — per-repo memory index

One line per memory file. Content lives in the files, not here. Durable facts
only (keep-test: true after the next increment AND not already in an ADR, the
tracker, or git). Active R-item status lives in the tracker
`docs/proposals/v-stdlib-remediation-plan.md`, not here.

## Modules (VistA-binding adapters — the durable canon)
- [m2-vslio](m2-vslio.md) — VSLIO binds STDNET → Kernel device handler; outbound TCP via `CALL^%ZISTCP` (**ICR #2118**, argument-passed not input-var); no Supported listen/accept.
- [m3-vslfs](m3-vslfs.md) — VSLFS binds STDKV → FileMan DBS (`UPDATE^DIE`/`$$GET1^DIQ`/`FILE^DIE` with FDA `.01="@"`; **no `DELETE^DIE` exists**); DIERR→`,U-VSL-FS-DIERR,`; ICR notional (DBS marker).
- [m4-vslsec-vsllog](m4-vslsec-vsllog.md) — VSLSEC (authz over `^XUSEC`, no portable Kernel hash → crypto stays in STDCRYPTO) + VSLLOG (first v→v composition, reuses VSLFS); the zgoto-`$ETRAP` harness-abort gotcha → use flag-based `$ETRAP`.
- [m5-vsltask-vslbld](m5-vsltask-vslbld.md) — VSLTASK (`^%ZTLOAD` **#10063**) + VSLENV + VSLBLD (KIDS base build); TaskMan live on both engines; destructive self-restart soft-skipped (runaway-unsafe).
- [m6.5-vslsec-secid-binding](m6.5-vslsec-secid-binding.md) — VSLSEC `$$bySecid` (SecID → #200 IEN via `EN1^XUPSQRY`, **ICR 4575** CS, by-ref result array); the VistA half of validate-token-not-PIV auth.
- [r2-vslcfg-loud-effective](r2-vslcfg-loud-effective.md) — VSLCFG made loud (`$$set` raises from `EN^XPAR`'s scalar error) + `$$lastError`/`$$getEffective` (`GET^XPAR "ALL"` precedence); `EN^XPAR`/`$$GET^XPAR` both **ICR #2263**.
- [vslsec-user-regression-fix](vslsec-user-regression-fix.md) — `$$user^VSLSEC` fell through with no body (a doc-tag edit deleted the line); lesson → the empty-body/fall-through lint gate ([[r6-fallthrough-gate]]). Remediation-plan headlines (R2/R3/R7).

## Scaffold / packaging foundations
- [t0b4-msl-seam-pin](t0b4-msl-seam-pin.md) — the cross-repo MSL seam-contract pin (`dist/msl-seam-pin.json` + drift gate); don't conflate with v-stdlib's own `dist/seam-snapshot.json`.
- [t1.2-vslcfg](t1.2-vslcfg.md) — VSLCFG binding details + the `m test --docker` `ydb_routines`-vs-`gtmroutines` fix; XPAR's filer needs a FileMan-built `#8989.51` def (direct global SETs don't FILE).
- [t1.3-vsl-kids](t1.3-vsl-kids.md) — the VSL layer packaged as a KIDS build; Required-build posture (a) (emitted to #9.6 but not enforced under direct-populate install); `make check-kids` golden gate.
- [meta-root-and-owed](meta-root-and-owed.md) — layer tag in root `repo.meta.json`; the owed `fileViaDie^VSLSEED` FileMan filer (re-homed from STDSEED per the G2 waterline decision), not yet implemented.

## Docs / governance tooling
- [stdlib-docs-pipeline](stdlib-docs-pipeline.md) — the doc-generation pipeline (manifest/skill/module-pages/examples) + its drift gates + reusable gotchas; tools are byte-identical siblings of m-stdlib's except gen-manifest/write-module-frontmatter.
- [docs-governance-regime-b](docs-governance-regime-b.md) — generated module pages are Regime B (own schema + `check-frontmatter` gate; excluded from the prose validator); grammar is a thin pointer to m-stdlib's canonical.
- [r6-fallthrough-gate](r6-fallthrough-gate.md) — `tools/check-fallthrough.py`, the engine-free empty-body/fall-through lint gate (the R1 `$$user^VSLSEC` bug class); string/paren-aware tokenizer.
