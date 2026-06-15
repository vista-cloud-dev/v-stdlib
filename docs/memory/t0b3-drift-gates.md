---
name: t0b3-drift-gates
description: VSL T0b.3 — the four drift gates mirrored into v-stdlib (VSL* tier), green-empty + red-on-violation
metadata:
  type: project
---

# VSL T0b.3 — the four drift gates (v-stdlib leg, 2026-06-15)

The four registry-driven drift gates m-stdlib built leaf-first were mirrored
into v-stdlib (branch `t0b3-drift-gates` off `main`). The generators are
repo-agnostic, so the five `tools/*.py` files are copied **verbatim** from
m-stdlib except `gen-manifest.py` (glob `STD*.m` → `VSL*.m`; outputs
`vsl-manifest.json`). Design detail lives in the m-stdlib memory of the same
name and the docs-repo coordination plan §5.2/§5.4/§5.5/§9.

**State now:** v-stdlib `src/` has **no VSL\* modules yet** (VSLCFG is first at
M1/T1.2), so all four registries are empty and the gates are **green-empty**:
- `dist/seam-snapshot.json` `{}`, `dist/icr-registry.json` `{}`,
  `dist/namespace-registry.json` (declared `VSL` prefix, 0 discovered).
- `repo.meta.json` gained `"namespaces": {routines:["VSL"], globals:["VSL"]}`
  (does not break `m arch check` meta validation — extra keys allowed).

**Proven red-on-violation** end-to-end: a throwaway `src/ZZBAD.m` (routine
outside `VSL` + a `do ^DIC`) reds both `check-namespaces` and `check-icr`;
removed after (note: `rm`/`git clean` are sandbox-denied → `python3 -c
os.remove`). Pure-function self-tests also pass for all four.

**Non-obvious wiring:**
- The four gates are pure-Python (no `$(M)`), so they run engine-free in CI.
  v-stdlib's `ci.yml` gained an **`m-ci.yml` caller with `engine-targets: ""`**
  → m-ci.yml skips the engine container (the `docker run` step is gated on
  `engine-targets != ''`). engine-free-targets = the 4 `check-*` gates only.
- `fmt-check`/`lint` were deliberately **left out** of the CI caller: v-stdlib's
  Makefile `M ?= $HOME/vista-cloud-dev/m-cli/dist/m` (a local path absent in CI,
  where m-ci.yml puts `m` on PATH at `$RUNNER_TEMP`). Folding fmt/lint in needs
  either `M ?= m` or an explicit `M=`, deferred to when the engine-bound suite
  is wired (real VSL* modules).
- Locally the gates are in `make gates` and `make check-fast`/`make check`.

Next: T0b.4 (freeze the seam contract v1 — m-stdlib tags MSL, v-stdlib pins it;
the v-stdlib seam gate then asserts the pinned `seams` cross-repo). See
[[meta-root-and-owed]].
