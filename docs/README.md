# v-stdlib — documentation index

The VistA Standard Library (`VSL*` routines): VistA-specific M building blocks
layered on `m-stdlib`'s engine-neutral `STD*` primitives (the `v → m` waterline).

Standard vista-cloud-dev `docs/` layout — do not invent per-repo folders
(`tracking/`, `plans/`, `prompts/`, `historical/`).

```
docs/
  README.md   # this index
  guides/     # how-to for users of VSL*
  modules/    # GENERATED per-module reference (Regime B — built, never hand-edited)
  memory/     # auto-memory — durable facts only
  proposals/  # this repo's design proposals (live/in-progress)
  archive/    # retired docs from this repo — git mv'd, never deleted
```

## Key docs

- [`guides/quick-start.md`](guides/quick-start.md) — fastest path to calling `VSL*` code.
- [`guides/verification-surfaces.md`](guides/verification-surfaces.md) — what `tests/`, `examples/programs/*EX.m`, and the demos each verify, and where new code belongs (v-specifics + pointer to the canonical m-stdlib model).
- [`guides/m-doc-grammar.md`](guides/m-doc-grammar.md) — the `; doc:` tag grammar driving the generated manifest + `modules/`.
- [`modules/`](modules/) — generated per-module reference (one page per `VSL*` module).

## Proposals (live)

- [`proposals/v-stdlib-remediation-plan.md`](proposals/v-stdlib-remediation-plan.md) — completed R1–R8 remediation; kept live as the cross-repo source of truth cited by the central `docs` banners.
- [`proposals/vista-sysadmin-suite.md`](proposals/vista-sysadmin-suite.md) — forward roadmap (Tier 1→3, not yet built).
- [`proposals/vista-library-wrapping-baseline.md`](proposals/vista-library-wrapping-baseline.md) — wrapping-coverage baseline audit (open follow-ups).
