---
title: v-stdlib module catalogue
doc_type: [INDEX]
generated_from: dist/vsl-manifest.json
---

# v-stdlib — module catalogue

v-stdlib unversioned; **17 modules**, **117 public labels**. Generated from `dist/vsl-manifest.json` by `tools/write-module-frontmatter.py` (`make frontmatter`) — do not edit by hand.

Every `VSL*` routine is **layer v** (VistA-specific): it MAY consume an `STD*` routine from m-stdlib, never the reverse (the m/v waterline). For the engine-neutral primitives see the `m-stdlib` catalogue.

| Module | Labels | Synopsis |
|---|---|---|
| [`VSLBLD`](vslbld.md) | 4 | the VSL KIDS base build definition + env-check binding (packaging seam) |
| [`VSLCFG`](vslcfg.md) | 2 | VistA configuration adapter over XPAR (Parameter Tools) |
| [`VSLENV`](vslenv.md) | 4 | the VSL KIDS environment-check routine (the XPDENV hook) |
| [`VSLFS`](vslfs.md) | 5 | VistA FileMan storage adapter (FileMan DBS record store) |
| [`VSLHL7TAP`](vslhl7tap.md) | 8 | HL7 store-tail adapter (decoupled, zero in-line) |
| [`VSLIO`](vslio.md) | 8 | VistA TCP transport adapter over the Kernel device handler |
| [`VSLLOG`](vsllog.md) | 3 | VistA FileMan audit-sink adapter (the S3 audit seam) |
| [`VSLRPCTAP`](vslrpctap.md) | 4 | RPC tap adapter at the VSLRPC chokepoint (the fenced tee) |
| [`VSLRPCWRAP`](vslrpcwrap.md) | 6 | the XWB broker-dispatch wrap glue (FU-5 / G-RPCHOOK) |
| [`VSLS3`](vsls3.md) | 12 | S3 egress sink: LDJSON envelope + the §11 bucket layout |
| [`VSLSEC`](vslsec.md) | 5 | VistA identity/authorization adapter (Kernel) |
| [`VSLTAP`](vsltap.md) | 22 | non-interference traffic-tap core (the safety gate) |
| [`VSLTAPBO`](vsltapbo.md) | 9 | traffic-tap back-out / verify-clean (the G-UNINST gate) |
| [`VSLTAPFC`](vsltapfc.md) | 8 | fidelity comparator: byte-equality proof, not assertion |
| [`VSLTAPHL`](vsltaphl.md) | 5 | tap health instrument + standby readiness (the watchdog) |
| [`VSLTAPRUN`](vsltaprun.md) | 6 | the periodic fidelity-run task (closes the console loop) |
| [`VSLTASK`](vsltask.md) | 6 | VistA TaskMan persistent-listener adapter (the process seam) |

