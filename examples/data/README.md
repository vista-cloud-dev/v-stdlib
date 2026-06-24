# examples/data — sample input/output fixtures

Sample data the living examples read and assert against, one subfolder per
module (`data/<module>/…`).

**Status (E1):** the established home; the fixtures + executable examples land
with the example backfill (E2–E3 of the Living Executable Examples proposal —
docs `proposals/living-executable-examples.md`). v-stdlib's executable-example
coverage starts at 0/117 — the index (`examples/index.md`) surfaces that gap.

**v-stdlib is VistA-flavored.** Unlike m-stdlib's pure-data fixtures (CSV/JSON),
most VSL examples interact with a **live VistA** — they read known data on
`vehu`/`foia`, or mutate inside a transaction and restore (the side-effect-safety
model in the proposal §8). So this folder holds expected-*shape* fixtures and
seed/restore helpers more than static inputs. No synthetic PHI.
