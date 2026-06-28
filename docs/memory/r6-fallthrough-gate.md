---
name: r6-fallthrough-gate
description: "2026-06-28: R6 highest-ROI item DONE — tools/check-fallthrough.py, the engine-free gate that reds on the R1 class of bug (a label that falls through into the next label)"
metadata:
  type: project
---

**2026-06-28: R6's highest-ROI item landed** (remediation plan, after R2).
`tools/check-fallthrough.py` is the empty-body/fall-through gate the
[[vslsec-user-regression-fix]] lesson called for. It reds when any `src/*.m`
label can fall through into the next label — an **empty body** (only
doc/comment lines, exactly the R1 `$$user^VSLSEC` regression) or a **last line
that isn't an unconditional `quit`/`goto`/`halt`**.

**Why it works where engine gates didn't:** R1 survived because no suite
executes `$$user` on a live engine. This gate reads the `.m` text only —
engine-free, in `make check-fast`. Proven: feeding it the exact R1-broken
VSLSEC (the deleted `quit $$get^VSLFS(...)` line) flags `user` as
"empty body … falls through".

**Parser non-obvious bits** (so a future edit doesn't weaken it):
- It tokenizes M command structure **string/paren aware**, so a `quit` inside a
  `$etrap="…quit"` string literal is NOT counted as a terminator (VSLLOG/VSLTASK
  both have such lines — they'd false-positive a naive substring check).
- A terminator must be the **last** command on the line AND unconditional: a
  postconditional `quit:cond` or an `if x quit` (gated by `$TEST`) does NOT
  count — both can fall through. But a mid-line `set … do … quit ""` (VSLLOG
  `write`) DOES count, because the trailing `quit` is unconditional.
- The strict rule "**every** label ends in an unconditional transfer" holds for
  all 6 modules with **zero** false positives (49/49 labels clean), so it's
  applied to every label, not just public ones — verified before shipping.

Scope: `src/*.m` only (where R1 lived; where the manifest/docs gates point).
Self-test is the test (10 cases, `--self-test`), the house gate idiom (cf.
`check-docs.py`). Wired into `gates` → `check-fast`/`ci`.

**Still TODO in R6** (this closed only the gate sub-item): the triplicated
assertions (doc-tag / `examples/programs/*EX.m` / `tests/*TST.m` — collapse to
test-suite-canonical) and the 356-column `@example` lines. See
`docs/proposals/v-stdlib-remediation-plan.md` R6. Next in the recommended
sequence: R7 (docs-repo session) then R3 (real VSLLOG audit DD).
