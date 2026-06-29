# `tests/` — unit test suites (hand-written)

One `VSL*TST.m` suite per module, hand-written **TDD-first** and asserting
through `^STDASSERT`, plus `VSLSMOKETST.m` (fast cross-module smoke). This is
v-stdlib's **correctness specification**: edge cases, error/`$ECODE` contracts,
and full create / modify / delete lifecycle.

Unlike the generated `examples/programs/*EX.m` (which read **real** VistA data
like `#200` IEN 1), these suites run against **ephemeral throwaway fixtures**
(e.g. `#999000`) so they can probe error paths and teardown cleanly. Behavior
that needs a v-pkg-installed resident task is documented as a SOFT-SKIP rather
than left silently untested.

This is one of three verification surfaces — see
[`docs/guides/verification-surfaces.md`](../docs/guides/verification-surfaces.md).

- **Run:** `make test` · `make coverage`. All engine access is through the driver
  stack only (m/v waterline) — never raw `docker exec`.
- **Add a test:** write the failing `VSL*TST.m` case first, then implement in
  `src/VSL*.m` until green.
- **Note:** `docs/quarantine/tests/` holds parked suites for future modules not
  yet in `src/` — not run by `make test`.
