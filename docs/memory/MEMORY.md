# v-stdlib — per-repo memory index

One line per memory file. Content lives in the files, not here.

- [meta-root + owed VSLSEED filer](meta-root-and-owed.md) — layer declared in **root `repo.meta.json`** (migrated off `dist/` 2026-06-15, Phase B item 1); the owed `fileViaDie^VSLSEED` FileMan filer (re-homed from m-stdlib STDSEED per the G2 waterline decision) lands here when a v-layer seeding consumer needs it.
- [t0b3-drift-gates](t0b3-drift-gates.md) — VSL T0b.3 (v-stdlib leg, 2026-06-15): the **four drift gates** mirrored from m-stdlib (tools/ copied verbatim except gen-manifest's `VSL*` glob). All **green-empty** (no VSL* modules yet); red-on-violation proven. `repo.meta.json` gained `namespaces: {VSL}`; `ci.yml` runs them via an `m-ci.yml` caller with `engine-targets: ""` (engine-free). fmt/lint left out of CI (Makefile `M` default is a local path). Next: T0b.4 freeze+pin the seam contract.
