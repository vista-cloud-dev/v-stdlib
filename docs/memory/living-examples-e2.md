---
name: living-examples-e2
description: Living Examples E2 (v-stdlib) — the @fixture/@illustrative grammar tags + dormant manifest extraction (byte-identical sibling of m-stdlib's); coverage gate is the E2 remainder.
metadata:
  type: project
---

# Living Executable Examples — E2 (v-stdlib slice, IN PROGRESS)

**Part 1 DONE 2026-06-24**, v-stdlib `main`. Full design in m-stdlib's
`docs/memory/living-examples-e2.md`. Proposal: docs
`proposals/living-executable-examples.md`.

- `tools/mdoc_tags.py`: **byte-identical sibling** of m-stdlib's — now carries
  `@fixture` + `@illustrative`. (No grammar doc here; v-stdlib keeps its pointer.)
- `tools/gen-manifest.py`: the E2 extraction **delta** applied on top of v-stdlib's
  VSL naming (NOT copied verbatim — it differs in the `VSL*` glob /
  `vsl-manifest.json` name / docstring). Conditional-emit ⇒ manifest byte-unchanged
  (no VSL source uses the tags yet).
- Gates: manifest-check + manifest-golden clean; manifest byte-unchanged.

**E2 remainder:** `gen-examples.py --coverage` advisory gate + Makefile/ci wiring
(both repos) + the proposal E2 row. v-stdlib's executable coverage is 0/117 — the
coverage gate will surface the full backfill (E3, mostly live-VistA + side-effect-safe).
Builds on [[living-examples-e1]].
