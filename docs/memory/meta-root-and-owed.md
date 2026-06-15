---
name: meta-root-and-owed
description: v-stdlib declares its layer in root repo.meta.json (migrated off dist/); the owed fileViaDie^VSLSEED FileMan filer lands here
metadata:
  type: project
---

**Meta location (Phase B item 1, 2026-06-15):** v-stdlib's layer tag lives in
the **root `repo.meta.json`** (`"layer": "v"`), migrated off `dist/repo.meta.json`
now that `m arch check` reads the meta root-first. The meta must keep the four
required fields (id, layer, language, verification_commands) — `m arch check`
validates the shape (`Gate:"META"`). v-stdlib passes G1/G2 trivially (v → m, and
VistA above the line, are allowed) and runs G3/G4 + meta like every repo.

**Owed — `fileViaDie^VSLSEED`:** when m-stdlib's STDSEED was made engine-neutral
for the waterline G2 (the FileMan default filer `do FILE^DIE` removed; filer now
required), the FileMan-backed filer was re-homed to the **v layer** here as
`fileViaDie^VSLSEED`. It is **not yet implemented** — deferred because (a) no
v-layer seeding consumer exists yet, and (b) a real test needs a live FOIA VistA
(FileMan isn't on the bare m-test engines). Land it with its first consumer or as
a dedicated FOIA-up increment. m-stdlib's `docs/modules/stdseed.md` + the org
docs `docs/vsl-msl/` already forward-reference the name. See m-stdlib memory
`stdseed-g2-engine-neutral`.
