---
title: Living examples — index
doc_type: [INDEX]
generated_from: dist/vsl-manifest.json
---

# Living examples

Generated, self-verifying runnable example programs — one per module — built from each module's `@example` tags by `tools/gen-examples.py` (`make examples`). DO NOT edit by hand. Each `examples/programs/<MODULE>EX.m` runs as a suite (`do ^<MODULE>EX`) and asserts its own results.

**Executable-example coverage: 107/118 public labels (90%)** across 16 module program(s). The remaining labels carry no *executable* (`write … ; "expected"`, self-contained) example yet — closing that gap to 100% (with `@raises` error cases + sample data + live-VistA runs) is the Living Executable Examples roadmap (E2–E4).

| Module | Labels | With executable example | Program |
|---|---|---|---|
| `VSLBLD` | 4 | 4 | [`VSLBLDEX.m`](programs/VSLBLDEX.m) |
| `VSLCFG` | 2 | 2 | [`VSLCFGEX.m`](programs/VSLCFGEX.m) |
| `VSLENV` | 4 | 3 | [`VSLENVEX.m`](programs/VSLENVEX.m) |
| `VSLFS` | 5 | 4 | [`VSLFSEX.m`](programs/VSLFSEX.m) |
| `VSLHL7TAP` | 8 | 8 | [`VSLHL7TAPEX.m`](programs/VSLHL7TAPEX.m) |
| `VSLIO` | 8 | 5 | [`VSLIOEX.m`](programs/VSLIOEX.m) |
| `VSLLOG` | 3 | 3 | [`VSLLOGEX.m`](programs/VSLLOGEX.m) |
| `VSLRPCTAP` | 4 | 4 | [`VSLRPCTAPEX.m`](programs/VSLRPCTAPEX.m) |
| `VSLRPCWRAP` | 6 | 6 | [`VSLRPCWRAPEX.m`](programs/VSLRPCWRAPEX.m) |
| `VSLS3` | 11 | 8 | [`VSLS3EX.m`](programs/VSLS3EX.m) |
| `VSLSEC` | 5 | 4 | [`VSLSECEX.m`](programs/VSLSECEX.m) |
| `VSLTAP` | 30 | 29 | [`VSLTAPEX.m`](programs/VSLTAPEX.m) |
| `VSLTAPBO` | 9 | 9 | [`VSLTAPBOEX.m`](programs/VSLTAPBOEX.m) |
| `VSLTAPFC` | 7 | 7 | [`VSLTAPFCEX.m`](programs/VSLTAPFCEX.m) |
| `VSLTAPHL` | 6 | 6 | [`VSLTAPHLEX.m`](programs/VSLTAPHLEX.m) |
| `VSLTASK` | 6 | 5 | [`VSLTASKEX.m`](programs/VSLTASKEX.m) |

