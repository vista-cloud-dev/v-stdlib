---
module: VSLCFG
layer: v
since: 
stable: stable
synopsis: 'VistA configuration adapter over XPAR (Parameter Tools)'
labels: ['get', 'getEffective', 'lastError', 'set']
errors: ['U-VSL-CFG-SET']
see_also: []
doc_type: [REFERENCE]
---

# `VSLCFG` — VistA configuration adapter over XPAR (Parameter Tools)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `get` | `$$get^VSLCFG(key, default)` | Read parameter `key` at the SYS entity; return `default` when unset. |
| `getEffective` | `$$getEffective^VSLCFG(key, default)` | Read the effective value across the parameter's entity precedence; else `default`. |
| `lastError` | `$$lastError^VSLCFG()` | The last VSLCFG error message (the composed XPAR failure detail). |
| `set` | `do set^VSLCFG(key, value)` | Set parameter `key` to `value` at the SYS entity; raise on a failed write. |

### `$$get^VSLCFG(key, default)`

Read parameter `key` at the SYS entity; return `default` when unset.

**Parameters**

- `key` _(string)_ — XPAR parameter name (PARAMETER DEFINITION #8989.51)
- `default` _(string)_ — value returned when the parameter is unset (optional; empty when omitted)

**Returns** _string_ — the SYS-level value, or `default` when unset

**Example**

```m
do eq^STDASSERT(.pass,.fail,$$get^VSLCFG("ZZVSLCFGNOSUCH","fallback"),"fallback","get: unset parameter returns the default")
```

### `$$getEffective^VSLCFG(key, default)`

Read the effective value across the parameter's entity precedence; else `default`.

**Parameters**

- `key` _(string)_ — XPAR parameter name (PARAMETER DEFINITION #8989.51)
- `default` _(string)_ — value returned when the parameter is unset at every level (optional; empty when omitted)

**Returns** _string_ — the first value found in the parameter's precedence chain, or `default`

**Example**

```m
do eq^STDASSERT(.pass,.fail,$$getEffective^VSLCFG("ZZVSLCFGNOSUCH","fb"),"fb","getEffective: unset parameter returns the default")
```

### `$$lastError^VSLCFG()`

The last VSLCFG error message (the composed XPAR failure detail).

**Returns** _string_ — ^TMP($job,"vslcfg","err"), or "" if none

### `do set^VSLCFG(key, value)`

Set parameter `key` to `value` at the SYS entity; raise on a failed write.

**Parameters**

- `key` _(string)_ — XPAR parameter name (#8989.51)
- `value` _(string)_ — value to store at the SYS level

**Returns** _void_ — side-effecting; no return value (loud on failure)

**Raises**

- `U-VSL-CFG-SET` — the XPAR write failed (detail in $$lastError)

<!-- END GENERATED API REFERENCE -->
