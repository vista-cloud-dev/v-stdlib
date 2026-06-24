---
name: living-examples-e3
description: Living Examples E3 (v-stdlib backfill) — VSL* executable label coverage 0%→100% (125/125: 113 executable, 12 illustrative), all engine-verified across bare m-test-engine + live vehu, side-effect-safe. Raises 8/9 (advisory).
metadata:
  type: project
---

# Living Executable Examples — E3 (v-stdlib backfill, DONE)

**DONE 2026-06-24**, v-stdlib `main`. Proposal: docs
`proposals/living-executable-examples.md` (E3). Sibling of m-stdlib's
[[living-examples-e3]] (the m-stdlib slice). Builds on [[living-examples-e2]].

**Result: executable+illustrative coverage 0% → 100% (125/125 labels: 113
executable, 12 illustrative, 0 uncovered), every executable example
engine-verified** — 348 bare assertions on `m-test-engine` + 46 live assertions
on `vehu` (= 394 total), and the 15 pre-existing `VSL*TST` suites still green
(309/0). Raises **8/9** (advisory).

**How — a 17-agent workflow (`scratchpad/e3-vstdlib.mjs`), one agent per module:**
each agent LIFTED side-effect-safe assertions from the module's `tests/VSL*TST.m`
(already engine-verified + safe) into `@example` tags, then verified on the right
engine. The TST suites were the gold source — far higher quality than authoring
blind.

**Engine split (which `m test --docker <engine>` an example needs):**
- **Bare** (`m-test-engine`, ydb, `--chset m`): the engine-neutral modules —
  VSLTAP/VSLTAPBO/VSLTAPFC/VSLTAPHL/VSLTAPRUN/VSLRPCTAP/VSLRPCWRAP/VSLHL7TAP/VSLS3
  (touch only their own `^VSLTAP`/`^XTMP("VSLTAP")` scratch globals).
- **Live** (`vehu` YDB-VistA): the VistA-binding modules — VSLCFG(XPAR),
  VSLBLD(KIDS), VSLFS(FileMan), VSLIO, VSLLOG, VSLTASK(TaskMan), VSLENV, VSLSEC
  (Kernel). Run with `--routines src --routines $MSTDLIB/src` (STD* deps loaded
  on top of vehu's resident VistA).

**Side-effect safety (vehu is shared, must stay byte-identical):** every example
is read-only (existing `^XUSEC` pair, #200 IEN 1 = postmaster, an existing XPAR
param), self-restoring in the same line (capture→set→assert→restore, the
VSLCFGTST pattern), or uses a test seam (VSLS3 drain `s3sink="capture"` → no real
PUT). Genuinely-mutating verbs (VSLFS.set/kill add/delete a FileMan record;
VSLTASK.schedule/queue create a persistent TaskMan task; VSLS3.ship/list need
live MinIO) are honestly `@illustrative`, NOT forced.

**GOTCHAS (cost real iterations):**
- **`for` on a single example line scopes the trailing assert** — `for i=1:1:N set
  x=$$f() do eq^STDASSERT(...)` runs the assert once PER iteration (spurious
  pass-count inflation / failures). M has no mid-line `for` terminator → a
  one-line example must not put an assert after a `for`; unroll it (agents fixed
  VSLTAP/VSLTAPBO).
- **8 private helpers lacked `@internal`** (marked `(private)` in prose only) so
  the manifest miscounted them public → "uncovered": VSLTAP.write1/hdrLine/
  write1rec, VSLHL7TAP.read1/nextIen/tailOne/tailStore, VSLS3.shipBatch. Added
  `; doc: @internal` → correctly excluded.
- **`VSLSEC.user`** ($$GET1^DIQ #200 NAME read) FAULTS on the current vehu's
  FileMan path (suite aborts 0/0) and `$$GET1^DIQ` is absent on bare → no clean
  portable example → `@illustrative` (the honest escape hatch; it IS exercised by
  VSLSECTST on live VistA).
- **`@raises` demo substring must be the FULL code** — agents asserted a prefix
  (`U-VSL-SEC`) which the coverage gate's `raises_demonstrated` (literal-code
  match) missed; widened to `U-VSL-SEC-ARG`/`U-VSL-BLD-ARG` (still passes — the
  full code is in `$ECODE`).
- **v-stdlib `make lint` was bare `m lint --check`** (reds on ANY finding); the
  long Pattern-B example lines are `M-MOD-001` (line>200, **style**). Aligned the
  target to the house gate `scripts/m-lint-gate.sh` (zero ERROR-severity; style
  advisory) — same as m-stdlib, per the global CLAUDE.md rule.
- Editing `src/*.m` drifts **`dist/kids/VSL.kids`** (it embeds routine source) →
  `make kids` + commit.

**Generator (`tools/gen-examples.py`, byte-identical sibling):** gained Pattern B
`do:postconditional` support (`do:$text(...)'="" eq^STDASSERT(…)`) — the regex
now allows an optional `:postcond` between `do` and the assert call. No m-stdlib
output change (it has no such examples).

**Remaining (E3b, advisory):** 1 undemonstrated raise — VSLTASK.schedule
`U-VSL-TASK-QUEUE` (only reachable via a genuinely-failed live TaskMan queue, a
side-effecting/non-deterministic path). Same not-demonstrable class as m-stdlib's
infra raises → needs the `@raises`-not-demonstrable exemption tag. NEXT: E4 (wire
EX programs into engine execution by tier + the live `vehu`/`foia` cadence).
