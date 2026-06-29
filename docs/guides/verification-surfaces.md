---
title: Verification surfaces — tests/, examples/, and demos
status: live
created: 2026-06-28
last_modified: 2026-06-28
revisions: 0
doc_type: [GUIDE]
---

# Verification surfaces — `tests/`, `examples/`, and demos

v-stdlib verifies every `VSL*` module through the **same three surfaces** as its
sibling m-stdlib. The shared model — what each surface is for and where new code
belongs — is documented once, canonically, in
**m-stdlib `docs/guides/verification-surfaces.md`**. This page records only the
v-stdlib-specific facts.

## The three surfaces

| Surface | Location | Author | Produced by | Job |
|---|---|---|---|---|
| **Unit tests** | `tests/VSL*TST.m` | hand-written | a developer, TDD-first | edge cases, error contracts — the correctness spec |
| **Living examples** | `examples/programs/VSL*EX.m` | **generated** | `make examples` from `@example` tags | happy-path API usage + doc-drift gate |
| **Demos** | `examples/vsl*-demo.m` | hand-written | by hand | end-to-end onboarding narrative |

## What differs from m-stdlib

`VSL*` modules touch a **live VistA** (FileMan, XPAR, TaskMan, Kernel) over the
driver stack — never a bare engine — so the two surfaces deliberately use
**different data**:

- **`examples/programs/VSL*EX.m`** exercise the happy path against **real,
  guaranteed-present VistA data** (e.g. `#200` USER IEN 1) and are read-only /
  state-restoring. They are generated from `@example` tags and **must not be
  hand-edited** (CI drift gate); regenerate with `make examples`. Per-label
  coverage is tracked in [`examples/index.md`](../../examples/index.md).
- **`tests/VSL*TST.m`** run the full create / modify / delete / error lifecycle
  against **ephemeral throwaway fixtures** (e.g. the `#999000` `ZZVSLFS` test
  file), so they can probe error contracts and teardown cleanly without touching
  production records. Integration-gated behavior that needs a v-pkg-installed
  resident task (e.g. VSLTASK self-restart) is documented as a **SOFT-SKIP** in
  the suite rather than left untested-but-silent.
- **`tests/VSLSMOKETST.m`** is a fast cross-module smoke check.
- **Demos:** only `examples/vslcfg-demo.m` ships today — an interactive
  read-modify-restore walkthrough against a real SYS-level parameter.

## Not a surface: `docs/quarantine/`

`docs/quarantine/tests/` holds `*TST.m` suites for **future `VSL*` modules not
yet in `src/`** (HL7 tap, RPC wrap, S3, …). They are parked, not deployed, and do
not run in `make test`. They are not duplication of the active suites — they are
the TDD-red head start for modules that haven't graduated.

## Decision rule

```
Specifying / defending VSL behavior, edge case, error path?  → tests/VSL*TST.m  (ephemeral fixtures)
Documenting how to call a function (happy path)?             → @example tag in src/  (regenerates *EX.m)
Teaching an end-to-end workflow?                             → examples/vsl*-demo.m
```

## See also

- m-stdlib `docs/guides/verification-surfaces.md` — the canonical shared model
  and rationale (why three surfaces, not one).
- [`guides/quick-start.md`](quick-start.md) — fastest path to calling `VSL*` code.
- The m-stdlib `comprehensive-testing.md` guide covers running **both** libraries
  (`STD*` + `VSL*`) across both engines and tiers.
