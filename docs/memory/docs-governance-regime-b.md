---
name: docs-governance-regime-b
description: Two-regime docs governance — v-stdlib's generated module pages are now Regime B (own schema + check-frontmatter gate); fixed the Phase-1 grammar-copy link regression (docs-validate now clean); skill cross-references m-stdlib.
metadata:
  type: project
---

# Docs governance — Regime B (v-stdlib slice)

**DONE 2026-06-23**, v-stdlib `main`. Implements the org ADR
`docs/background/docs-governance-two-regimes-adr.md` (in the `docs` repo).
Found while scoping stdlib-docs Phase 5 (see [[stdlib-docs-pipeline]]).

**Context.** The doc-framework prose validator (run via `docs-validate.yml`) was
governing v-stdlib's machine-generated `docs/modules/` pages — wrong schema class,
**and it had been RED since my Phase-1 commit `adfb4d7`**: I copied
`m-doc-grammar.md` verbatim from m-stdlib, carrying its m-stdlib-relative links
(`../tracking/…`) which don't resolve in v-stdlib → 3 link errors. A `make`-only
verification missed it because `docs-validate` is a separate workflow.

**v-stdlib changes (M2 + M3 + M4 of the ADR):**
- **M1 (doc-framework repo):** `modules` added to the validator `EXCLUDE_DIRS` →
  generated pages no longer touched by the prose validator (removed the modules
  warnings).
- **M2 — Regime-B schema + gate:** `tools/reference-frontmatter.schema.json` +
  `tools/check-frontmatter.py` (`make check-frontmatter`, in `gates` + `ci.yml`).
  **Byte-identical siblings of m-stdlib's** — one schema validates both; v-stdlib's
  17 pages pass (its `layer` field + the m-stdlib-only `tag/phase/...` are all in
  the union with the common-core required set).
- **M3 — grammar pointer (the regression fix):** `docs/guides/m-doc-grammar.md` is
  now a **thin pointer** to m-stdlib's canonical spec (GitHub URL), not a verbatim
  copy. Kills the 3 broken links (R-GRAMMAR: one canonical copy, no drift). The
  full canonical stays in m-stdlib (its relative links resolve in-repo).
  **`docs-validate` is now clean (0 errors).**
- **M4 — consumer-assembled catalog:** `gen-skill.py` emits a `## Companion
  library` section pointing at m-stdlib's SKILL.md (GitHub URL) + the `v -> m`
  waterline. Mutual with m-stdlib's; resolves R-2SKILLS (no merged artifact in the
  internal docs repo — the unified view is assembled by the consumer/skill).

**Gates green:** `check-frontmatter` 17/17, `skill-check`, `docs-bodies-check`,
`manifest-check`, `manifest-golden` clean; `docs-validate` 0 errors.

**Phase 5 status:** P5.1 (merged catalog) → superseded by M4; P5.4 (grammar
promotion) → realised as M3. Remaining: the `m doc` CLI assembler (deferred —
needs a catalog-access design), the meta-gate, and the org-contract doc.
