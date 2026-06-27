---
name: tap-quarantined
description: The entire prior RPC/HL7→S3 traffic-tap subsystem was QUARANTINED out of the active VSL library (2026-06-27), pending its greenfield replacement v-rpc-tap. All prior tap memory entries describe RETIRED code.
metadata:
  type: project
---

**The prior traffic-tap subsystem is QUARANTINED** (2026-06-27, owner directive).
Moved to `quarantine/` (see `quarantine/README.md`); **removed from the active
library and all its gates.** It will be **replaced by the greenfield `v-rpc-tap`
effort** — do not build on, reuse, or cite the quarantined code.

**Why:** the prior tap was specified/built against the **now-retired
`CALLP^XWBBRK` `{XWB}` callback seam** (`XWB(2,"CAPI")` / `XWB(3,"P",*)`). Modern
CPRS dispatches through **`CALLP^XWBPRS` `[XWB]`** (a *different* contract:
`XWB(2,"RPC")` / `XWB(5,"P",*)`; `{XWB}` retired at `XWB*1.1*60`). The greenfield
design is fresh `VSLRT*` routines against live `XWBPRS` — see the `docs` repo
`proposals/v-rpc-tap-scalable.md` and its shared memory `v-rpc-tap-scalable`.

**What moved to `quarantine/`:** routines `VSLTAP VSLRPCTAP VSLRPCWRAP VSLS3
VSLHL7TAP VSLTAPFC VSLTAPHL`; their `*TST` suites + `*EX` examples + generated
module pages; guides `tap-architecture.md` / `traffic-tap-dibrg.md`;
`scripts/s3-testbed.sh`; the `vsltap-rpc-wrap.preimage.kids`.

**Active-library changes (all gate-green, `make check-fast`):**
- `kids/vsl.build.json` — 7 tap routines + all `VSL TAP *`/`VSL S3 *` param
  defs removed; **patch 4→5**. Routine set now **6** (`VSLCFG VSLFS VSLIO VSLLOG
  VSLSEC VSLTASK`).
- `Makefile` — `BARE_TESTS` = smoke + VSLSEC only; `test-s3`/`test-s3-matrix` +
  `S3_TESTBED` removed; `make ci` drops the S3 round-trip.
- `.github/workflows/ci.yml` — MinIO testbed + `test-s3` steps removed (both
  engine jobs).
- `tools/gen-skill.py` + `tools/skill-patterns.md` — tap/S3 trigger + pattern
  sections removed; all generated artifacts (manifest, ICR/namespace registries,
  module docs, skill, examples, `dist/kids/VSL.kids`) regenerated from the
  6-module source; `dist/icr-registry.json` now 14 ICRs / 5 modules.

**⚠ STATUS of the prior tap memory entries** — the following describe the
**RETIRED** implementation and are kept only as a journal; do **not** treat them
as current design: [[fu4-naked-ref-fence]], [[fu5a-schema-v1-capture]],
[[fu5b1-rpcwrap-glue]], [[fu8-fu9-ring]], [[phase4-fidelity-persist]],
[[phase5-ga-forward-port]], [[phase3-egress-fidelity]], [[phase2-vsltap]],
[[egress-hash-removed]], [[live-capture-fault-stdcrypto]],
[[bespoke-install-routines-removed]], [[kids-ship-all-routines]],
[[living-examples-e3]]/[[living-examples-e4]] (their tap-family arms).
See also org [[never-use-bespoke-installer]].
