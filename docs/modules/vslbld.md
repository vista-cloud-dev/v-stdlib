---
module: VSLBLD
layer: v
since: 
stable: stable
synopsis: 'the VSL KIDS base build definition + env-check binding (packaging seam)'
labels: ['envCheck', 'lastError', 'manifest', 'requireBase']
errors: ['U-VSL-BLD-ARG']
see_also: []
doc_type: [REFERENCE]
---

# `VSLBLD` — the VSL KIDS base build definition + env-check binding (packaging seam)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `envCheck` | `$$envCheck^VSLBLD(facts)` | The environment facts (engine/version/Kernel/TLS) via the self-contained VSLENV (v->v). |
| `lastError` | `$$lastError^VSLBLD()` | The last VSLBLD error message (the composed malformed-call detail). |
| `manifest` | `$$manifest^VSLBLD(out)` | Fill out() with the VSL base's routines, its Required Build and patch identity; return the routine count. |
| `requireBase` | `$$requireBase^VSLBLD(build)` | 1 iff KIDS build `build` is installed on this system (the R6 version-skew check). |

### `$$envCheck^VSLBLD(facts)`

The environment facts (engine/version/Kernel/TLS) via the self-contained VSLENV (v->v).

**Parameters**

- `facts` _(array)_ — (by ref) receives engine/version/kernel/tls facts

**Returns** _bool_ — 1 on success

### `$$lastError^VSLBLD()`

The last VSLBLD error message (the composed malformed-call detail).

**Returns** _string_ — ^TMP($job,"vslbld","err"), or "" if none

### `$$manifest^VSLBLD(out)`

Fill out() with the VSL base's routines, its Required Build and patch identity; return the routine count.

**Parameters**

- `out` _(array)_ — (by ref) out("routines",n)=routine; out("requiredBuild"); out("patch")

**Returns** _numeric_ — the number of routines the VSL base ships

### `$$requireBase^VSLBLD(build)`

1 iff KIDS build `build` is installed on this system (the R6 version-skew check).

**Parameters**

- `build` _(string)_ — a KIDS build/patch identity (e.g. "MSL*0.1*1")

**Returns** _bool_ — 1 iff installed; 0 (a normal not-installed result) otherwise

**Raises**

- `U-VSL-BLD-ARG` — the call is malformed (an empty build name)

<!-- END GENERATED API REFERENCE -->
