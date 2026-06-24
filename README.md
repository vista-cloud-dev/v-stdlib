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

**17 `VSL*` modules** ship today — config (`VSLCFG`), security (`VSLSEC`),
FileMan storage (`VSLFS`), TaskMan (`VSLTASK`), and the headline feature: the
**RPC + HL7 → S3 traffic tap** (`VSLTAP` / `VSLRPCTAP` / `VSLRPCWRAP` / `VSLS3` /
`VSLHL7TAP` / `VSLTAPFC` / …), a non-interfering, reversibly-installable capture
proven byte-for-byte on a live VistA.

- **New here?** [`docs/guides/quick-start.md`](docs/guides/quick-start.md) (5 min).
- **The tap, explained:** [`docs/guides/tap-architecture.md`](docs/guides/tap-architecture.md);
  deploy / back-out runbook: [`docs/guides/traffic-tap-dibrg.md`](docs/guides/traffic-tap-dibrg.md).
- **Per-module API:** [`docs/modules/index.md`](docs/modules/index.md) (generated from source).
- **Effort tracker:** [`docs/vsl-msl/vsl-implementation-tracker.md`](https://github.com/vista-cloud-dev/docs/blob/main/vsl-msl/vsl-implementation-tracker.md).

## Layout

| Path | Contents |
|---|---|
| `src/` | `VSL*` M routines (17 modules) |
| `examples/` | runnable demos (e.g. `vslcfg-demo.m`) |
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
