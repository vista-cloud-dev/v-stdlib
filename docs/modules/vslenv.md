---
module: VSLENV
layer: v
since: 
stable: stable
synopsis: 'the VSL KIDS environment-check routine (the XPDENV hook)'
labels: ['abort', 'check', 'kernelVer', 'tlsConfig']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLENV` — the VSL KIDS environment-check routine (the XPDENV hook)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `abort` | `do abort^VSLENV()` | (private) a genuine showstopper — Kernel (XU) is not present; abort the install. |
| `check` | `$$check^VSLENV(facts)` | Fill facts(engine,version,kernel,tls) from intrinsics + resident Kernel; return 1. |
| `kernelVer` | `$$kernelVer^VSLENV()` | (private) the Kernel (#9.4 XU) current version, "" if unavailable. |
| `tlsConfig` | `$$tlsConfig^VSLENV()` | (private) the DEFAULT TLS SERVER CONFIG Kernel System Parameter (presence), "" if unset. |

### `do abort^VSLENV()`

(private) a genuine showstopper — Kernel (XU) is not present; abort the install.

### `$$check^VSLENV(facts)`

Fill facts(engine,version,kernel,tls) from intrinsics + resident Kernel; return 1.

**Parameters**

- `facts` _(array)_ — (by ref) receives engine/version/kernel/tls facts

**Returns** _bool_ — always 1 (faultable reads are isolated + trapped)

### `$$kernelVer^VSLENV()`

(private) the Kernel (#9.4 XU) current version, "" if unavailable.

### `$$tlsConfig^VSLENV()`

(private) the DEFAULT TLS SERVER CONFIG Kernel System Parameter (presence), "" if unset.

<!-- END GENERATED API REFERENCE -->
