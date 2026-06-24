---
name: grammar-spec-from-code-gate
description: v-stdlib slice of the grammar spec-from-code gate — carries the byte-identical mdoc_tags.py registry; its gen-manifest.py derives KNOWN_TAGS from it (behaviour-preserving).
metadata:
  type: project
---

# Grammar spec-from-code gate (v-stdlib slice)

**DONE 2026-06-24**, v-stdlib `main`. The full design + rationale live in m-stdlib
(`docs/plans/grammar-spec-from-code-gate-plan.md`,
`docs/memory/grammar-spec-from-code-gate.md`). This is the v-stdlib slice.

- `tools/mdoc_tags.py` — the 11-tag registry, a **byte-identical sibling** of
  m-stdlib's (the grammar is engine-neutral; one source serves both).
- `tools/gen-manifest.py` now derives `KNOWN_TAGS = mdoc_tags.label_tags()`
  (was a hardcoded literal set). `sys.path.insert(0, <tools dir>)` makes the
  registry importable however the generator is loaded (direct run or the golden
  test's importlib).
- **Behaviour-preserving:** `dist/vsl-manifest.json` + `errors.json` byte-unchanged;
  `manifest-golden` + `manifest-check` green — the proof the refactor changed
  nothing observable.

v-stdlib does NOT carry the grammar doc, `gen-grammar.py`, or the `grammar-check`
gate — those are m-stdlib-only (canonical grammar home); v-stdlib keeps its
grammar **pointer**. It carries the registry solely to feed its own generator.
Builds on [[docs-governance-regime-b]].
