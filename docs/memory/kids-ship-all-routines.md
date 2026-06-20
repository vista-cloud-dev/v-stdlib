---
name: kids-ship-all-routines
description: The VSL KIDS build (kids/vsl.build.json) now ships all 13 VSL* routines via allowLongNames; was a stale 8-routine subset.
metadata:
  type: project
---

`kids/vsl.build.json` (`VSL*1.0*2`) was a **stale 8-routine subset**. As of 2026-06-20 it ships
**all 13 `VSL*` production routines** (`src/VSL*.m`) so VSL installs in its entirety — adds the
tap/egress + S3 modules (`VSLRPCTAP VSLS3 VSLTAP VSLTAPFC VSLTAPHL`).

`VSLRPCTAP` (9 chars) exceeds the legacy 8-char cap, so the spec sets **`"allowLongNames": true`**
(engine-limit-31 policy; ADR `docs/background/routine-name-length-policy-adr.md` + v-pkg's
`AllowLongNames` field). `dist/kids/VSL.kids` rebuilt via `make kids` (48→100 KB); all 7 `make
gates` green (`check-kids` deterministic-build, `check-namespaces` 13 routines, etc.). The
`requiredBuilds` MSL prereq + the `VPNG GREETING` param def are unchanged.

Branch `ship-all-routines`, unmerged. Shared note: [[routine-name-length-policy]] (docs repo).
