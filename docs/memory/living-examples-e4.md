---
name: living-examples-e4
description: Living Examples E4 (v-stdlib) — the VSL* EX programs are now EXECUTED via tools/run-examples.py (byte-identical sibling of m-stdlib's), two-tier by @exrun scope, with examples/REPORT.md + live residue check. KEY: the tap/S3 family is @exrun bare (writes its own ^VSLTAP → not live-safe on shared VistA); VSLRPCWRAP is bare-ydb (IRIS EX-harness transaction divergence); VistA-binding modules are @exrun live.
metadata:
  type: project
---

# Living Executable Examples — E4 (v-stdlib slice, DONE)

**DONE 2026-06-24**, v-stdlib `main`. Proposal: docs
`proposals/living-executable-examples.md` (§7 live, §8 safety, L2/L4). The
v-stdlib half of E4 — wire the `VSL*EX.m` programs into the two-tier executed
runner. Follows [[living-examples-e3]]. The runner, the two grammar tags
(`@exrun`/`@exsafe`), the residue design, and the full gotcha list are the
**byte-identical sibling** of m-stdlib's `living-examples-e4` — read that too.

## v-stdlib per-module engine split (the kickoff's split, encoded as `@exrun`)

The split matches the kickoff almost exactly; **VSLSEC was the one correction**
(the kickoff listed it live-only, but its read-only auth examples pass on BOTH
bare engines → `dual`). Empirical, not assumed.

- **`@exrun bare`** (both bare engines, NOT live — they exercise the tap's own
  `^VSLTAP` global, which would pollute a shared live VistA): VSLTAP, VSLTAPBO,
  VSLTAPFC, VSLTAPHL, VSLTAPRUN, VSLRPCTAP, VSLHL7TAP, VSLS3.
- **`@exrun bare-ydb`** (YDB bare only): **VSLRPCWRAP** — its 3 transactional
  tap-capture examples abort `0/0` on the IRIS example harness (the in-transaction
  `$$hdr^VSLTAP` finds no record on IRIS — a YDB/IRIS tap-in-transaction
  divergence; minimal `tstart`/`trollback` works fine on IRIS, so it's the tap, not
  the transaction). IRIS capability is proven separately by VSLRPCWRAPTST (33/33).
- **`@exrun live`** (live VistA only — `0/0` on bare, need Kernel/FileMan):
  VSLCFG, VSLBLD, VSLENV, VSLFS, VSLIO, VSLLOG, VSLTASK.
- **`dual`** (default): VSLSEC.

`@exsafe transactional` on VSLCFG/VSLFS/VSLLOG/VSLTASK/VSLRPCWRAP (they mutate +
self-restore); the rest read-only.

## Result (all arms green, residue clean)

bare YDB 10/10, bare IRIS 9/9; live YDB 8/8 (VSLSEC + 7 VistA-binding), live IRIS
8/8; residue clean on both live arms. `make examples-run` (bare) is the gate;
`examples-run-live` is the nightly cadence. Coverage stays 125/125 + 9/9 `@raises`.

## KEY finding — the residue check earned its keep

The first live run RED'd: VSLTAPRUNEX failed live + the tap family left `^VSLTAP`
named-key (`"cfg"`) residue after the run (VSLTAP, VSLTAPFC, VSLTAPHL, VSLHL7TAP,
VSLRPCTAP all leave cfg; VSLTAPBO/VSLS3 clean). The tap examples set
`^VSLTAP("cfg",…)` as setup without teardown — fine on a dedicated bare engine,
not on a shared live one. **Resolution: the tap/S3 family is `@exrun bare`** (a
bare-tier concern by design — the kickoff's split), so they never touch the live
engine; the residue check then runs clean. (Marking them per-module
`illustrative-skip` was whack-a-mole — VSLS3 then went red on shared `^VSLTAP`
state; the `bare` scope is the right model.) **FOLLOW-UP (E5 / optional):** if the
tap family ever needs live execution, the examples must self-restore `^VSLTAP`
cfg (TSTART/TROLLBACK or save/restore).

## CI / nightly

CI `engine-ydb` job hard-gates `make examples-run-ydb`; the fail-soft
`engine-iris` job runs `make examples-run-iris`. A scheduled self-hosted `.github`
`examples-live.yml` runs the live tier nightly + commits `examples/REPORT.md`
(decision b). v-stdlib never had a doctest path, so nothing to retire here.

See [[living-examples-e3]] / [[living-examples-e2]].
