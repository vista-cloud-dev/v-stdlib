---
name: t0b4-msl-seam-pin
description: VSL T0b.4 — v-stdlib pins the frozen MSL seam contract (cross-repo v→m drift gate)
metadata:
  type: project
---

# VSL T0b.4 — pin the frozen MSL seam contract (v-stdlib leg, 2026-06-15)

T0b.4 = "Freeze seam contract v1 — tag MSL; v-stdlib pins it." The m-stdlib
leg tagged MSL `v0.6.0` (seam contract frozen empty; see m-stdlib memory
`t0b4-seam-freeze`). This leg adds the **cross-repo pin + drift gate** that
makes "MSL changed a seam and VSL didn't notice" a red CI gate (coordination
plan §5.2/§6).

**The artifact:** `dist/msl-seam-pin.json` = `{ "msl_ref": "v0.6.0",
"seams": {<frozen copy of MSL's seams block> } }`. `msl_ref` is the one
hand-set knob (which MSL git tag to pin); `seams` is the synced copy.

**The gate:** `tools/msl_seam_pin.py` (`make pin` / `make check-msl-pin`):
1. well-formedness — `msl_ref` non-empty str, `seams` a dict of valid records;
2. drift — when MSL is REACHABLE, the committed `seams` must equal MSL's
   `dist/seam-snapshot.json` AT `msl_ref`; RED on mismatch.

**Reachability today = the sibling m-stdlib checkout** (`$MSTDLIB`, default
`~/vista-cloud-dev/m-stdlib`) read with `git show <ref>:dist/seam-snapshot.json`.
When the tag/sibling is absent (a fresh CI clone with no MSL repo) the gate
**SKIPs green** — the same cadence-degradation as `check-citations`. So in CI
today `check-msl-pin` SKIPs (m-ci.yml does not check out the sibling); it
asserts for real at dev-time against the local `v0.6.0` tag. **The network
fetch-at-tag path (fetch the published manifest in CI) is the T1.1 extension.**

**Proven (TDD red→green):** self-test OK; planted bogus seam → RED (drift);
malformed pin (missing ref) → RED; MSL unreachable → SKIP green; synced pin
→ GREEN. Wired into `make gates` + CI `engine-free-targets`.

**Note — two different seam-snapshots in this repo, don't conflate:**
`dist/seam-snapshot.json` = v-stdlib's OWN `VSL*` seams (empty, the T0b.3
mirror); `dist/msl-seam-pin.json` = the MSL contract v-stdlib CONSUMES. See
[[t0b3-drift-gates]]. The first real MSL seam (`STDENV`) arrives at T1.1 — at
which point `make pin` re-syncs and the gate asserts the real signature.
