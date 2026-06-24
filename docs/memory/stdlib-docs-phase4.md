---
name: stdlib-docs-phase4
description: Stdlib-docs Phase 4 / AC4 — module-page API bodies are now generated from the manifest (delimited block; hand prose preserved), drift-gated; v-stdlib stubs became real reference pages.
metadata:
  type: project
---

# Stdlib documentation system — Phase 4 / AC4 (generated page bodies)

**DONE 2026-06-23** (cross-repo: v-stdlib `main` + m-stdlib `master`). Plan: docs
repo `stdlib-documentation-system-implementation-plan.md` §8 (P4.1–P4.4). Builds
on [[stdlib-docs-phase3]].

**What.** Each module page now carries a generated `## API reference` block —
signature table + per-label params/returns/raises/@example, rendered from the
manifest by `tools/gen-bodies.py` (`make docs-bodies`). Edit a signature in
`src/*.m` → `make manifest docs-bodies` → the page updates; `docs-bodies-check`
red-gates a stale block (AC4). For v-stdlib this turned the 17 Phase-1 **stubs
into real reference pages**.

**The contract (P4.1) — additive, lossless, marker-delimited:**
- The block lives between HTML-comment markers `<!-- BEGIN/END GENERATED API
  REFERENCE -->`. The generator owns ONLY the text between them; **everything
  else on the page is preserved byte-for-byte** → risk R-CLOBBER solved by
  construction (not by heuristic section-detection).
- Placement: inserted as the first `## ` section (after the intro, before the
  first existing `## ` heading); on regen, found by markers and replaced in
  place. Idempotent. On m-stdlib's 40 prose pages the splice was verified
  **purely additive — 0 deletions** (6302 insertions); the hand `## Public API`
  walkthrough now sits *below* the generated `## API reference` (reference +
  guide). A future cleanup MAY trim the now-supplementary hand API sections —
  out of scope (lossy to automate; not needed for AC4).
- `tools/gen-bodies.py` is a **byte-identical sibling** of m-stdlib's (manifest
  auto-discovered). It has a `--self-test` (4 cases): insert, idempotency,
  replace-in-place on a signature change, prose-preservation.

**v-stdlib stub migration:** the 17 stub pages' "> **Stub.** … lands in Phase 4"
placeholder was stripped and replaced with a self-documenting HTML comment, then
`gen-bodies` filled the block. `write-module-frontmatter.py`'s `stub_body` was
updated so future new modules get the same clean stub (no Phase-4 placeholder).

**P4.3 / D3 RESOLVED = NO (don't force the doc-framework prose schema).**
`doc-framework/schema/frontmatter.schema.json` has `additionalProperties: false`,
requires `id/title/type/status/created/updated`, and its `type` enum has no
"reference". Module pages carry load-bearing `module/labels/errors/see_also`
frontmatter the skill/index/docs-check tooling reads — forcing the prose schema
would strip that metadata AND has no valid `type` for a generated reference page.
The two are different document classes; module pages keep their reference-class
frontmatter. (Plan leaned "yes"; verifying against the actual schema flips it.)

**Wiring:** `docs-bodies` / `docs-bodies-check` Makefile targets; `docs-bodies-check`
in `make gates` + `ci.yml` engine-free-targets (both repos).

**Gates green:** `docs-bodies-check` clean (v-stdlib 17, m-stdlib 40), idempotent;
drift proof verified (perturb the manifest → red; regenerate → green); `check-fast`
green.

**NEXT: Phase 5** — the unified cross-library catalog (Tier 3): merge both
manifests into one layer-labeled `library-catalog.{md,json}` + a CLI/skill lookup
spanning both libs.
