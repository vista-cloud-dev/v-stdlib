# v-stdlib — the VistA Standard Library

`VSL*` M routines: the **VistA-specific** standard library, sibling to the
engine-neutral [`m-stdlib`](https://github.com/vista-cloud-dev/m-stdlib)
(`STD*`). v-stdlib sits **above the m/v waterline** — it requires
Kernel/FileMan/KIDS and binds VistA semantics (XPAR config, Broker, TaskMan,
FileMan storage, Kernel security) to portable `STD*` primitives consumed from
below.

- **Layer:** `v` (VistA-specific). Declared in
  [`dist/repo.meta.json`](dist/repo.meta.json); enforced by `m arch check`
  (the waterline G1 dependency-direction gate — `v → m` only).
- **Dual-engine:** YottaDB + IRIS, like m-stdlib.
- **Consumes:** `m-stdlib` (`STD*`) upward; never the reverse.

This is the **T0b.1 scaffold** — toolchain + gates wired, an empty (smoke-only)
suite green. The first real module, `VSLCFG` (XPAR-backed config), lands at M1.
See the VSL effort tracker in
[`m-stdlib/docs/tracking/vsl-implementation-tracker.md`](https://github.com/vista-cloud-dev/m-stdlib/blob/master/docs/tracking/vsl-implementation-tracker.md).

## Layout

| Path | Contents |
|---|---|
| `src/` | `VSL*` M routines (empty at scaffold) |
| `tests/` | hand-written `VSL*TST.m` suites (`^STDASSERT`) |
| `dist/repo.meta.json` | the committed meta artifact — carries `"layer": "v"` |

## Develop

```bash
make check-fast   # fmt-check + lint + arch (engine-free)
make check        # + engine-bound suite (needs YDB/IRIS; stages STDASSERT from m-stdlib)
make test M=m     # if `m` is on PATH
```

The `m` toolchain binary is built in the sibling `m-cli` repo; `M` defaults to
`$HOME/vista-cloud-dev/m-cli/dist/m`.
