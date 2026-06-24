---
name: stdlib-docs-phase1
description: Stdlib-docs Phase 1 / AC1 DONE — activated v-stdlib's dormant doc generation pipeline (manifest + errors + skill + 17 module stubs + golden test), gated in CI.
metadata:
  type: project
---

# Stdlib documentation system — Phase 1 / AC1 (v-stdlib leg)

**DONE 2026-06-23**, trunk on `main` (routine single-writer, no branch). Plan:
`docs/proposals/stdlib-documentation-system-implementation-plan.md` (docs repo),
§5 task table P1.1–P1.7. Prompt:
`docs/prompts/stdlib-docs-phase1-vstdlib-activate-kickoff.md`.

**What this was.** m-stdlib already built the `source-tag → generate → registry →
red-gate` doc pipeline. v-stdlib's 17 `VSL*` routines are 100% `; doc:`-tagged but
only the *drift-gate* half (icr/namespaces/seams/msl-pin) had been ported — the
*discoverability* half (manifest/skill/module-pages) was a dormant byte-copy.
Phase 1 **activated** it. Because the input tags were already complete, one
increment took v-stdlib from zero end-user API surface to a full manifest + error
index + AI skill + 17 module-page stubs.

**Non-obvious findings / decisions:**
- **The dormant `tools/gen-manifest.py` was NOT byte-identical (prompt assumed it
  was).** It had already been adapted to the `VSL*` glob + `dist/vsl-manifest.json`,
  but wrote `dist/vsl-errors.json`. **Reconciled the errors filename to
  `dist/errors.json`** to match m-stdlib exactly + the prompt DoD + what
  `gen-skill.py` reads. Net: v-stdlib's gen-manifest now differs from m-stdlib's in
  only 3 spots — the `VSL*` glob, `vsl-manifest.json` name, docstring — so the two
  stay one maintained generator (risk R-DRIFT). Self-test fixture (STDFOO) kept
  byte-identical to m-stdlib's.
- **D4 resolved locally:** manifest artifact = `dist/vsl-manifest.json` (per-repo
  `<lib>=vsl`); error index = `dist/errors.json` (same name as m-stdlib — installs
  to a separate skill dir so no collision).
- **`stdlib_version` is empty** ("") — `read_stdlib_version()` walks a changelog
  that v-stdlib doesn't have. Deterministic (always ""), so the drift gate is
  stable; the skill/index render "unversioned". Fine for Phase 1.
- **`write-module-frontmatter.py` had to DIVERGE structurally from m-stdlib's.**
  m-stdlib's only *backfills* frontmatter onto pages that already exist and reads
  `index.md` for phase/tag/conformance. v-stdlib had **zero** pages, so the v-stdlib
  variant **creates** the stub (frontmatter + placeholder body) when absent AND
  generates `docs/modules/index.md` itself (browsable catalogue) from the manifest.
  Frontmatter schema is v-flavored: `module / layer: v / since / stable / synopsis /
  labels / errors / see_also / doc_type`. Idempotent (skips pages with FM unless
  `--force`); index always regenerated.
- **Golden test (P1.7) fixture lives in `tools/fixtures/VSLGOLD.m`, NOT `src/` or
  `tests/`** — kept out of the `VSL*.m` manifest glob AND the fmt/lint/test source
  globs so `m fmt` can't shift its line numbers and break the `source.file:line`
  assertion. `tools/test-manifest-golden.py` imports the hyphenated `gen-manifest.py`
  via `importlib`, parses the fixture, diffs vs `tools/fixtures/vslgold-manifest-slice.json`
  (`--write` regenerates, `--check`/`make manifest-golden` gates). Pins signature,
  params, returns, raises, source.file:line. TDD red→green proven (golden-absent →
  exit 1; written → clean).

**Deliverables (all green):** `tools/gen-skill.py`, `tools/skill-patterns.md`
(v-flavored seed: VSLCFG/VSLSEC/VSLFS/VSLTAP+VSLRPCWRAP/VSLS3/VSLTASK/VSLLOG
idioms), `tools/write-module-frontmatter.py`, `tools/test-manifest-golden.py` +
fixture/golden, `docs/guides/m-doc-grammar.md` (interim copy; promoted org-level in
Phase 5 / D-grammar), `dist/vsl-manifest.json` (17 modules / 117 labels),
`dist/errors.json` (7 U-VSL* codes / 6 modules), `dist/skill/{SKILL,manifest-index,
patterns,error-codes}.md`, `docs/modules/{17×vsl*.md + index.md}`. Makefile targets
`manifest manifest-check manifest-golden frontmatter skill skill-check skill-install`;
`manifest-check skill-check manifest-golden` added to `make gates` AND the `ci.yml`
`engine-free-targets`. `make skill-install` → `~/claude/skills/v-stdlib/`.
`make check-fast` + `make gates` green.

**Scope fence held (NOT done — later phases):** no `make docs-check` completeness
gate (Phase 2, must ship green AFTER stubs exist — R-GATEBLOCK), no generated page
*bodies* (Phase 4), no unified cross-library catalog / `m doc` CLI (Phase 5), no
doctests.

**NEXT: Phase 2** — the `make docs-check` completeness gate in both repos; it ships
green in v-stdlib because Phase 1 generated all 17 stub pages. Shared:
[[rpc-traffic-s3-streaming-proposal]] is unrelated; this is a new workstream.
