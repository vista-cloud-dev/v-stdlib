---
title: Living examples — index
doc_type: [INDEX]
generated_from: dist/vsl-manifest.json
---

# Living examples

Generated, self-verifying runnable example programs — one per module — built from each module's `@example` tags by `tools/gen-examples.py` (`make examples`). DO NOT edit by hand. Each `examples/programs/<MODULE>EX.m` runs as a suite (`do ^<MODULE>EX`) and asserts its own results.

**Executable-example coverage: 17/36 public labels (47%)** across 6 module program(s). The remaining labels carry no *executable* (`write … ; "expected"`, self-contained) example yet — closing that gap to 100% (with `@raises` error cases + sample data + live-VistA runs) is the Living Executable Examples roadmap (E2–E4).

| Module | Labels | With executable example | Program |
|---|---|---|---|
| `VSLCFG` | 4 | 2 | [`VSLCFGEX.m`](programs/VSLCFGEX.m) |
| `VSLFS` | 7 | 2 | [`VSLFSEX.m`](programs/VSLFSEX.m) |
| `VSLIO` | 8 | 4 | [`VSLIOEX.m`](programs/VSLIOEX.m) |
| `VSLLOG` | 5 | 1 | [`VSLLOGEX.m`](programs/VSLLOGEX.m) |
| `VSLSEC` | 5 | 3 | [`VSLSECEX.m`](programs/VSLSECEX.m) |
| `VSLTASK` | 7 | 5 | [`VSLTASKEX.m`](programs/VSLTASKEX.m) |

