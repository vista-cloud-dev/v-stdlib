---
name: stdlib-docs-pipeline
description: v-stdlib's doc-generation pipeline (manifest/skill/module-pages/examples) and its drift gates — the durable gotchas. Tools are byte-identical siblings of m-stdlib's except gen-manifest.py and write-module-frontmatter.py. Consolidates the E1–E4 living-examples + stdlib-docs Phase 1/2/4/6 + grammar-registry increments.
metadata:
  type: project
---

# v-stdlib doc-generation pipeline — durable notes

The `source-tag → generate → registry → red-gate` doc pipeline (built leaf-first
in m-stdlib) runs in v-stdlib over the `VSL*` routines' `; doc:` tags. Most tools
are **byte-identical siblings** of m-stdlib's (one maintained source serves both);
the canonical design + grammar live in m-stdlib. Org plan (central `docs` repo):
`proposals/stdlib-documentation-system-implementation-plan.md`,
`proposals/living-executable-examples.md`. Regime-B governance of the generated
pages is its own note: [[docs-governance-regime-b]].

## What diverges from m-stdlib (and why)
- **`tools/gen-manifest.py`** differs in only 3 spots — the `VSL*` glob, the
  `dist/vsl-manifest.json` name, and the docstring. Error index reconciled to
  **`dist/errors.json`** (same name as m-stdlib; installs to a separate skill dir
  so no collision). Derives `KNOWN_TAGS = mdoc_tags.label_tags()` from the shared
  registry (was a hardcoded set); `sys.path.insert(0,<tools>)` so the registry
  imports under direct-run *and* the golden test's `importlib`.
- **`tools/write-module-frontmatter.py`** structurally diverges: m-stdlib only
  *backfills* frontmatter onto existing pages; v-stdlib had **zero** pages, so the
  v-variant **creates** the stub (frontmatter + body) when absent AND generates
  `docs/modules/index.md` from the manifest. Idempotent (skips pages with FM unless
  `--force`); index always regenerated. v-flavored FM: `module/layer:v/since/stable/
  synopsis/labels/errors/see_also/doc_type`.
- **`tools/mdoc_tags.py`** (the 11-tag registry) is byte-identical — the grammar is
  engine-neutral, one source feeds both. v-stdlib does **not** carry the grammar
  doc / `gen-grammar.py` / `grammar-check` (m-stdlib-only canonical home); it keeps
  a **pointer** and carries the registry only to feed its own generator.
- **`gen-examples.py` / `gen-bodies.py` / `check-docs.py`** are byte-identical
  siblings (lib name auto-discovered from the manifest, so no VSL delta).

## Gates (all engine-free, in `make gates` + `ci.yml`)
- **`manifest-check`** — regenerate + git-diff `dist/vsl-manifest.json` + `errors.json`.
- **`manifest-golden`** — parser regression vs `tools/fixtures/VSLGOLD.m`. **The
  golden fixture lives in `tools/fixtures/`, OUT of the `VSL*.m` manifest glob AND
  the fmt/lint/test source globs**, so `m fmt` can't shift its line numbers and
  break the `source.file:line` assertion. `test-manifest-golden.py` imports the
  hyphenated `gen-manifest.py` via `importlib`.
- **`docs-check`** (completeness) — red when any `src/*.m` lacks a manifest entry OR
  a `docs/modules/<module>.md` page. One byte-identical `check-docs.py`; per-repo
  difference is **data** (`tools/docs-check-allow.txt`; v-stdlib has none → 17/17
  green). Wired into the org **`m-ci.yml` as a guarded auto-step** (`grep -qE
  '^docs-check:' Makefile`), so every M caller inherits it WITHOUT listing it in
  `engine-free-targets` (no double-run); doc-less/Go repos skip cleanly.
- **`docs-bodies-check`** — `gen-bodies.py` maintains a `## API reference` block
  between `<!-- BEGIN/END GENERATED API REFERENCE -->` markers; it owns **only**
  between the markers → **additive & lossless by construction** (m-stdlib's 40 prose
  pages: 0 deletions). Drift-gate reds on a `.m` signature edit not propagated.
- **`check-frontmatter`** (Regime-B schema) — see [[docs-governance-regime-b]];
  candidate for removal once `modules/` is fully under regenerate-and-diff (OQ-2).
- **`examples-check` / `examples-coverage`** — `examples/` drift + advisory coverage.

## Living executable examples (E1–E4)
- Coverage started **0/117** (no Pattern-A self-contained `@example` tags in VSL
  source). The E3 backfill (a per-module agent that **lifts side-effect-safe
  assertions from each `VSL*TST.m`** — the gold source, higher quality than
  authoring blind) took executable+illustrative coverage to 100%, every example
  engine-verified (bare `m-test-engine` + live `vehu`).
- Grammar tags added across E2–E3b: `@fixture`, `@illustrative`, `@internal`,
  `@example` (Pattern-B `do:postcond`), `@raises`, `@raisesnodemo`.
- **E4 two-tier executed runner** (`run-examples.py`, byte-identical sibling):
  `@exrun bare|bare-ydb|live|dual` selects which engine actually *runs* each `*EX.m`
  program; `@exsafe transactional` marks self-restoring mutators. `make examples-run`
  (bare) is the gate; `examples-run-live` is the nightly cadence. **VSLSEC was the
  one kickoff correction** — listed live-only but its read-only auth examples pass on
  both bare engines → `dual` (empirical, not assumed).
- **The live residue check earned its keep:** it caught a module family leaving
  named-key residue in its own scratch global after a shared-live run. Lesson: an
  example that sets state on a *shared* live engine must self-restore (TSTART/
  TROLLBACK or save/restore) or be scoped `bare`; a post-run residue check is what
  surfaces shared-engine pollution.

## Reusable gotchas (cost real iterations)
- **A single-line `for` scopes the trailing assert** — `for i=1:1:N set x=$$f() do
  eq^STDASSERT(...)` runs the assert once PER iteration (spurious pass inflation /
  failures). M has no mid-line `for` terminator → a one-line example must not put an
  assert after a `for`; unroll it.
- **Private helpers need `; doc: @internal`** or the manifest miscounts them public →
  reported "uncovered".
- **`@raises` demo substring must be the FULL error code** (the coverage gate does a
  literal-code match) — a prefix like `U-VSL-SEC` misses; use `U-VSL-SEC-ARG`.
- **`make lint` is aligned to the house gate `scripts/m-lint-gate.sh`** (zero
  ERROR-severity; style advisory) — long Pattern-B example lines are `M-MOD-001`
  (line>200, style), which a bare `m lint --check` would red. Same posture as
  m-stdlib (global CLAUDE.md rule).
- **Editing `src/*.m` drifts `dist/kids/VSL.kids`** (it embeds routine source) → run
  `make kids` and commit.
- **`docs-validate` (doc-framework) is a SEPARATE GitHub workflow from `make
  gates`** → a `make`-only check misses doc-validate link errors. (This is how a
  verbatim grammar-doc copy with m-stdlib-relative links sat RED from Phase 1 until
  the [[docs-governance-regime-b]] grammar-pointer fix.)
- **`stdlib_version` renders empty `""`** — `read_stdlib_version()` walks a changelog
  v-stdlib doesn't have; deterministic, so the drift gate is stable (skill/index show
  "unversioned").
- **D3 resolved = NO:** do not force `doc-framework`'s prose schema on module pages
  (`additionalProperties:false`, no "reference" `type`) — it would strip the
  load-bearing `module/labels/errors/see_also` frontmatter the skill/index/docs-check
  tooling reads. Module pages are a distinct document class (Regime B).
