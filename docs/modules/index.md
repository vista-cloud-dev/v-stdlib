---
title: v-stdlib module catalogue
doc_type: [INDEX]
generated_from: dist/vsl-manifest.json
---

# v-stdlib — module catalogue

v-stdlib unversioned; **6 modules**, **38 public labels**. Generated from `dist/vsl-manifest.json` by `tools/write-module-frontmatter.py` (`make frontmatter`) — do not edit by hand.

Every `VSL*` routine is **layer v** (VistA-specific): it MAY consume an `STD*` routine from m-stdlib, never the reverse (the m/v waterline). For the engine-neutral primitives see the `m-stdlib` catalogue.

| Module | Labels | Synopsis |
|---|---|---|
| [`VSLCFG`](vslcfg.md) | 4 | VistA configuration adapter over XPAR (Parameter Tools) |
| [`VSLFS`](vslfs.md) | 7 | VistA FileMan storage adapter (FileMan DBS record store) |
| [`VSLIO`](vslio.md) | 8 | VistA TCP transport adapter over the Kernel device handler |
| [`VSLLOG`](vsllog.md) | 5 | VistA FileMan audit sink (the dedicated VSL AUDIT file) |
| [`VSLSEC`](vslsec.md) | 5 | VistA identity/authorization adapter (Kernel) |
| [`VSLTASK`](vsltask.md) | 9 | VistA TaskMan persistent-listener adapter (the process seam) |

