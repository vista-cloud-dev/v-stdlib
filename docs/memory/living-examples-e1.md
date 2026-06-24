---
name: living-examples-e1
description: Living Examples E1 (v-stdlib) — gen-examples (byte-identical sibling) generates examples/ + index; v-stdlib starts at 0/117 executable coverage (the index surfaces the whole backfill job).
metadata:
  type: project
---

# Living Executable Examples — E1 (v-stdlib slice)

**DONE 2026-06-24**, v-stdlib `main`. Proposal: docs
`proposals/living-executable-examples.md`. Full design in m-stdlib's
`docs/memory/living-examples-e1.md`.

- `tools/gen-examples.py` — **byte-identical sibling** of m-stdlib's (manifest
  auto-discovered). `make examples` / `examples-check` (drift gate, in `gates` +
  `ci.yml`). `examples/data/README.md` home.
- **v-stdlib executable-example coverage starts at 0/117** — `examples/index.md`
  surfaces it. 0 programs generated (no Pattern-A self-contained `@example` tags
  in VSL source). The example backfill is the whole job (E2–E3), and it's
  **mostly live-VistA + side-effect-safe** (read known vehu/foia data, or
  transactional write/restore — proposal §8), so it's the L-effort long pole.
- v-stdlib (unlike m-stdlib) has no `gen-doctests`/DOCTST, so there's no
  coexistence here — `examples/` is the sole example artifact.

Gates: examples-check clean. Builds on [[docs-governance-regime-b]].
