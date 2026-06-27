# quarantine/ — the retired RPC/HL7 → S3 traffic-tap subsystem

This folder holds the **prior** VSL traffic-tap implementation, removed from the
active library on 2026-06-27. **Do not build on, import, install, or "reuse"
anything here.** It is kept for reference only and will be deleted once the
greenfield replacement lands.

## Why it was quarantined

The prior tap was specified and built against the **now-retired
`CALLP^XWBBRK` `{XWB}` callback broker seam** (variable contract
`XWB(2,"CAPI")` / `XWB(3,"P",*)`). Modern CPRS dispatches through the
**`CALLP^XWBPRS` `[XWB]` non-callback path** (a *different* contract:
`XWB(2,"RPC")` / `XWB(5,"P",*)`; the `{XWB}` callback path was retired at
`XWB*1.1*60`). The replacement is a **greenfield** effort, `v-rpc-tap`, specified
fresh against live `CALLP^XWBPRS`:

- Design: `docs` repo → `proposals/v-rpc-tap-scalable.md` (package `VSL RPC TAP 1.0`,
  new `VSLRT*` routines, host-side egress, off-path reaper).

## Contents

| Path | What it was |
|---|---|
| `src/` | tap engine routines: `VSLTAP` `VSLRPCTAP` `VSLRPCWRAP` `VSLS3` `VSLHL7TAP` `VSLTAPFC` `VSLTAPHL` |
| `tests/` | the tap/S3 suites (`VSL*TAP*TST` / `VSLS3*TST` / `VSLRPC*TST` / `VSLHL7TAPTST`) |
| `examples/` | the `@example`-generated tap demo programs (`VSL*EX`) |
| `docs/modules/` | the generated per-module API pages for the tap routines |
| `docs/guides/` | `tap-architecture.md`, `traffic-tap-dibrg.md` (old design + deploy/back-out runbook) |
| `kids/` | `vsltap-rpc-wrap.preimage.kids` (old `CALLP^XWBBRK` splice pre-image) |
| `s3-testbed.sh` | the MinIO round-trip testbed for the old engine-side S3 egress |

## What changed in the active library

- `kids/vsl.build.json` — the 7 tap routines and all `VSL TAP *` / `VSL S3 *`
  parameter definitions removed; patch bumped `4 → 5`.
- `Makefile` — `BARE_TESTS` reduced to the smoke + security suites; the
  `test-s3` / `test-s3-matrix` targets and `S3_TESTBED` removed; `make ci` no
  longer runs the S3 round-trip.
- `.github/workflows/ci.yml` — the tap/S3 CI steps removed.
- All generated artifacts (manifest, registries, module docs, skill, examples,
  `dist/kids/VSL.kids`) regenerated from the reduced 6-module source set.
