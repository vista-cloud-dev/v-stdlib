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
- **M2 — Regime-B gate.** Originally `tools/reference-frontmatter.schema.json` +
  `tools/check-frontmatter.py` (`make check-frontmatter`) — byte-identical siblings
  of m-stdlib's. **SUPERSEDED 2026-06-28** (remediation-plan Part 4 action 5 / OQ-2):
  both DELETED in favour of **`frontmatter-check`** — a regenerate-and-diff gate
  (`make frontmatter` re-syncs every page's frontmatter + index from the manifest
  via `--force`; git-diff must be clean). It is **strictly stronger** than the schema
  validator: a byte-match to the manifest-driven generator implies schema-valid AND
  catches manifest drift the schema check missed. The collapse **caught a real latent
  drift** — VSLCFG's `getEffective`/`lastError` labels + `U-VSL-CFG-SET` (added by
  [[r2-vslcfg-loud-effective]]) were in the manifest + the generated API body but the
  page *frontmatter* + index had gone stale; `check-frontmatter` passed because the
  old list was still schema-*valid*. (Org two-regimes ADR amended 2026-06-28 — §7
  records the M2 schema-validator → regenerate-and-diff change; m-stdlib did the
  same collapse in its own Phase-4 increment, so both stdlibs now match.)
- **M3 — grammar pointer (the regression fix):** `docs/guides/m-doc-grammar.md` is
  now a **thin pointer** to m-stdlib's canonical spec (GitHub URL), not a verbatim
  copy. Kills the 3 broken links (R-GRAMMAR: one canonical copy, no drift). The
  full canonical stays in m-stdlib (its relative links resolve in-repo).
  **`docs-validate` is now clean (0 errors).**
- **M4 — consumer-assembled catalog:** `gen-skill.py` emits a `## Companion
  library` section pointing at m-stdlib's SKILL.md (GitHub URL) + the `v -> m`
  waterline. Mutual with m-stdlib's; resolves R-2SKILLS (no merged artifact in the
  internal docs repo — the unified view is assembled by the consumer/skill).

**Gates green:** `frontmatter-check` (regenerate-and-diff), `skill-check`,
`docs-bodies-check`, `manifest-check`, `manifest-golden` clean; `docs-validate`
0 errors.

**Phase 5 status:** P5.1 (merged catalog) → superseded by M4; P5.4 (grammar
promotion) → realised as M3. Remaining: the `m doc` CLI assembler (deferred —
needs a catalog-access design), the meta-gate, and the org-contract doc.
