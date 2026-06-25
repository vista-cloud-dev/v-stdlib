---
name: bespoke-install-routines-removed
description: VSLTAPBO (bespoke back-out) and VSLBLD (bespoke KIDS build self-description) deleted — install/back-out is strictly and exclusively the generic v-pkg lifecycle.
metadata:
  type: project
---

**Bespoke install/back-out M routines removed (2026-06-25, owner directive: "we
are using strictly and exclusively the v-pkg methods").** Both were called by
nothing but their own tests — pure redundancy with the v-pkg lifecycle + the
`kids/vsl.build.json` artifact.

**Deleted:**
- **`VSLTAPBO`** — the bespoke traffic-tap back-out (`backout`/`verifyClean`/
  `cleanState`/`cleanParams`/`cleanTasks`/`params`). Reversal is now strictly
  `v-pkg uninstall` (routines + `#9.7/#9.6` + the `#8989.51` PARAMETER
  DEFINITIONs). The tap's only un-removed footprint is the RUNTIME globals
  `^XTMP("VSLTAP",…)` (auto-purges on the Kernel `RETAIN` horizon) and `^VSLTAP`
  control state — both transient, not shipped data; an operator can
  `kill ^VSLTAP,^XTMP("VSLTAP")` to drop them immediately.
- **`VSLBLD`** — the bespoke KIDS base-build self-description (`manifest`/
  `requireBase`/`envCheck`/`lastError`). The build is the drift-gated
  `kids/vsl.build.json` → `dist/kids/VSL.kids`, owned by v-pkg; the M-side
  duplicate added nothing.
- Their tests, `docs/modules/*` pages, and example programs.

**`VSLENV` ALSO removed (2026-06-25, owner confirmed "yes").** Initially kept as
the KIDS env-check hook, but the owner opted to drop the env-check entirely —
strictly v-pkg, no install-time M machinery. Deleted `src/VSLENV.m` + its module
page + example program (it had no dedicated test), removed `"envCheck": "VSLENV"`
from `kids/vsl.build.json`, and dropped `VSLENV` from the routine list. The KIDS
build now has no environment-check routine; v-pkg install just installs. (If a
target lacks Kernel/FileMan the install simply fails on the missing APIs rather
than aborting via XPDQUIT — acceptable for a single-writer, known-target fleet.)

**Result:** KIDS routine list **13** (was 16); the `VSL TAP FIDELITY CADENCE` XPAR
param was already gone with [[egress-hash-removed]]'s VSLTAPRUN deletion. Updated
the DIBRG/quick-start/tap-architecture guides to the v-pkg-only install/back-out
contract. `make test-bare` green, `examples-run-ydb` 8/8, all drift gates +
lint(0-error)+arch green, all generated artifacts regenerated. `VSLTAPBO`'s `params`
list was the comment-cited source for the tap XPAR names; the single source of
truth is now `kids/vsl.build.json` `parameterDefinitions`.

**Host-side `wrap-rpc` ALSO deleted (2026-06-25, same owner directive).** The
companion removal happened in **v-pkg**: the `v pkg wrap-rpc status|install|backout`
command and `internal/wrapsplice` (the content-anchored `CALLP^XWBBRK` splice) were
deleted. So the directive now covers **both** sides — no bespoke M install/back-out
routines here, and no bespoke host patcher there. Installing/backing-out the tap is
**strictly** `v pkg install` / `v pkg uninstall` of `kids/vsl.build.json`. The
guides `traffic-tap-dibrg` + the `debug-live-capture-fault` prompt were repointed
off `wrap-rpc`. Canonical org directive: shared `never-use-bespoke-installer`.
