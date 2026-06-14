# v-stdlib — Claude Project Context

The **VistA Standard Library**: `VSL*` M routines, the VistA-specific sibling
of the engine-neutral `m-stdlib` (`STD*`). Defers to
`~/vista-cloud-dev/CLAUDE.md` (org rules: increment protocol, m/v waterline,
in-org memory routing) and `~/.claude/CLAUDE.md` (global).

## Layer — this repo is `v` (above the waterline)

v-stdlib is **VistA-specific** (needs Kernel/FileMan/KIDS). The waterline rule
(`docs/background/m-v-waterline-adr.md` in the `docs` repo) is binding:

- **Dependency is one-way: `v → m`.** A `VSL*` routine MAY call an `STD*`
  routine; an `STD*` routine MUST NOT call a `VSL*` routine. Never invert it.
- Layer is declared in `dist/repo.meta.json` (`"layer": "v"`) and enforced by
  `m arch check` (G1). v-stdlib passes G1 trivially but must keep the tag.
- VistA vocabulary (FileMan globals, KIDS, XPAR, Broker) lives **here**, never
  below the waterline in m-stdlib.

## Conventions

- **Modern style** (pythonic-lower, `.m-cli.toml` `rules = "modern"`) — not
  VistA-compact. New library, modern idiom.
- **TDD — hard rule:** write `tests/VSL*TST.m` first (`^STDASSERT`, staged from
  m-stdlib), confirm red, implement, confirm green. TDD-red stubs return safe
  defaults, never `$ECODE`.
- **Dual-engine:** YDB + IRIS; keep IRIS-portable (mirror m-stdlib's
  `$ZVERSION["IRIS"` arms where engine syntax diverges).
- **Gates before commit:** `make check-fast` (fmt/lint/arch, engine-free) +
  `make test` (engine-bound). Lint `--error-on=error` zero findings.

## Status

**T0b.1 scaffold** (2026-06-13): toolchain + gates wired, smoke suite green.
No `VSL*` modules yet — `VSLCFG` (XPAR config, binds `STDENV`) is first at M1.
Tracker: the `docs` repo `docs/vsl-msl/vsl-implementation-tracker.md`.
