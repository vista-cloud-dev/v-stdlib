# `examples/` — living examples + demos

## `programs/VSL*EX.m` — generated, self-verifying examples ⚠ DO NOT EDIT BY HAND

One self-asserting program per module, **generated** by `tools/gen-examples.py`
(`make examples`) from each module's `@example` tags in `src/VSL*.m`. Their job
is to **prove the documented usage examples actually run** against a live VistA —
a drift gate on the docs, not a coverage suite. They use **real, present** VistA
data (e.g. `#200` USER IEN 1) and are read-only / state-restoring. CI rejects
manual edits.

- **Change an example:** edit the `@example` tag in `src/VSL*.m`, then run
  `make examples`. Never edit `programs/*EX.m`, [`index.md`](index.md), or
  `REPORT.md` directly — all three are generated.

## `vsl*-demo.m` — hand-written onboarding demos

Currently `vslcfg-demo.m` only — an interactive read-modify-restore walkthrough
against a real SYS-level parameter. Edited by hand.

## `data/` — sample input files used by the demos and examples.

---

These are two of three verification surfaces — see
[`docs/guides/verification-surfaces.md`](../docs/guides/verification-surfaces.md)
for how `examples/` relates to the hand-written `tests/VSL*TST.m` suites.
