---
name: stdlib-docs-phase2
description: Stdlib-docs Phase 2 / AC2 DONE — the docs-check completeness gate, byte-identical sibling in v-stdlib + m-stdlib, baked org-wide into m-ci.yml.
metadata:
  type: project
---

# Stdlib documentation system — Phase 2 / AC2 (completeness gate)

**DONE 2026-06-23** (cross-repo: v-stdlib `main`, m-stdlib `master`, `.github`
`main`). Plan: docs repo `stdlib-documentation-system-implementation-plan.md` §6
(P2.1–P2.4). Built on [[stdlib-docs-phase1]].

**What.** `make docs-check` — red when any `src/*.m` module lacks a manifest
entry OR a `docs/modules/<module>.md` page. The "docs always track newest code"
enforcement: add a module to `src/` without regenerating the manifest or writing
a page → red.

**Non-obvious decisions:**
- **One byte-identical gate, per-repo difference is DATA.** `tools/check-docs.py`
  is identical in v-stdlib and m-stdlib. It auto-discovers the manifest
  (`dist/vsl-manifest.json` OR `dist/stdlib-manifest.json` — D4 left the names
  divergent) and reads an optional `tools/docs-check-allow.txt`. Keeps it one
  maintained tool, no fork.
- **Allow-list ships m-stdlib GREEN (R-GATEBLOCK).** m-stdlib has 40 modules but
  only 35 pages; the 5 page-less ones (STDHTTPD, STDHTTPMSG, STDJWT, STDS3,
  STDSIGV4) are in m-stdlib's `tools/docs-check-allow.txt` → reported as
  known-pending, NOT red. So the gate lands green and only goes red on an
  *unlisted* drift. Phase 3 authors those 5 and REMOVES them from the list (the
  gate flags a now-stale allow entry to force the cleanup). v-stdlib has NO allow
  file (all 17 stubs exist from Phase 1) → green at 17/17.
- **P2.4 wired into `m-ci.yml`, not per-caller.** Added a guarded auto-step
  (`grep -qE '^docs-check:' Makefile` → `make docs-check`) right after the
  engine-free gates, mirroring the engine-access gate. Every M caller inherits it
  WITHOUT listing it in `engine-free-targets` (so no double-run); Go/doc-less
  repos skip cleanly. **GOTCHA: `.github` had a stale local branch
  `engine-access-gate`** (its only delta *downgraded* the engine image 0.2.0→0.1.0
  — dead branch); landed the auto-step on `main` instead (origin/main already
  carried the engine-access gate + 0.2.0). Don't commit onto those stale
  `.github` feature branches.
- The gate has a `--self-test` (5 fabricated-repo cases: complete→green,
  missing-page→red, missing-page-allowed→green, missing-manifest→red,
  stale-allow→reported) — the plan's "completeness gate gets a test."

**Wiring:** v-stdlib `docs-check` target + added to `make gates`; m-stdlib
`docs-check` target (CI-only posture, like its other `-check` gates). NOT added to
either caller's `engine-free-targets` (the m-ci.yml auto-step covers CI).

**NEXT: Phase 3** — author m-stdlib's 5 missing pages + finish the ~20% `; doc:`
backfill, then REMOVE the 5 from `docs-check-allow.txt` (the gate turns their
absence red again). Shared: see the docs-repo tracker §7.
