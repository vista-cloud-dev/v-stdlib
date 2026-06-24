---
name: living-examples-e2
description: Living Examples E2 (v-stdlib, DONE) — @fixture/@illustrative grammar tags + dormant manifest extraction, plus the gen-examples --coverage advisory report (make/CI). Coverage baseline 0/117 labels, 0/9 raises — the E3 backfill made visible.
metadata:
  type: project
---

# Living Executable Examples — E2 (v-stdlib slice, DONE)

**Part 1 + Part 2 DONE 2026-06-24**, v-stdlib `main`. Full design in m-stdlib's
`docs/memory/living-examples-e2.md`. Proposal: docs
`proposals/living-executable-examples.md`.

- `tools/mdoc_tags.py`: **byte-identical sibling** of m-stdlib's — now carries
  `@fixture` + `@illustrative`. (No grammar doc here; v-stdlib keeps its pointer.)
- `tools/gen-manifest.py`: the E2 extraction **delta** applied on top of v-stdlib's
  VSL naming (NOT copied verbatim — it differs in the `VSL*` glob /
  `vsl-manifest.json` name / docstring). Conditional-emit ⇒ manifest byte-unchanged
  (no VSL source uses the tags yet).
- Gates: manifest-check + manifest-golden clean; manifest byte-unchanged.

**Part 2 (this increment):** `gen-examples.py` updated with `--coverage`
(advisory) + `--strict` — a **byte-identical sibling port** from m-stdlib (`\cp -f`;
the lib name auto-discovers, so no VSL delta — unlike `gen-manifest.py`). `make
examples-coverage` added + appended to the CI `engine-free-targets`. Coverage
baseline: **0/117 labels, 0/9 `@raises`, 0 fixtures** — the full E3 backfill
(mostly live-VistA + side-effect-safe) now surfaced and accountable. Self-test
green; examples-check clean. **NEXT: E3.** Builds on [[living-examples-e1]].
