---
module: VSLCFG
layer: v
since: 
stable: stable
synopsis: 'VistA configuration adapter over XPAR (Parameter Tools)'
labels: ['get', 'set']
errors: []
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
- `default` _(string)_ — value returned when the parameter is unset

**Returns** _string_ — the SYS-level value, or `default` when unset

**Example**

```m
do eq^STDASSERT(.pass,.fail,$$get^VSLCFG("ZZVSLCFGNOSUCH","fallback"),"fallback","get: unset parameter returns the default")
new k,i,r,d set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT,k="",d=0 for  set k=$order(^XTV(8989.51,"B",k)) quit:k=""!d  set i=+$order(^XTV(8989.51,"B",k,0)) if i,$extract($get(^XTV(8989.51,i,6)))="F",$$GET^XPAR("SYS",k,1)="" do EN^XPAR("SYS",k,1,"ZZP",.r) set r=$$GET^XPAR("SYS",k,1) do EN^XPAR("SYS",k,1,"@") if r="ZZP" do set^VSLCFG(k,"hi") do eq^STDASSERT(.pass,.fail,$$get^VSLCFG(k,"MISS"),"hi","get: $$set then $$get round-trips a SYS value") do EN^XPAR("SYS",k,1,"@") set d=1
```

### `$$getEffective^VSLCFG(key, default)`

Read the effective value across the parameter's entity precedence; else `default`.

**Parameters**

- `key` _(string)_ — XPAR parameter name (PARAMETER DEFINITION #8989.51)
- `default` _(string)_ — value returned when the parameter is unset at every level

**Returns** _string_ — the first value found in the parameter's precedence chain, or `default`

**Example**

```m
do eq^STDASSERT(.pass,.fail,$$getEffective^VSLCFG("ZZVSLCFGNOSUCH","fb"),"fb","getEffective: unset parameter returns the default")
```

### `$$lastError^VSLCFG()`

The last VSLCFG error message (the composed XPAR failure detail).

**Returns** _string_ — ^TMP($job,"vslcfg","err"), or "" if none

**Example**

```m
new prior,r set prior=$get(^TMP($job,"vslcfg","err")),^TMP($job,"vslcfg","err")="set: x" set r=$$lastError^VSLCFG() set ^TMP($job,"vslcfg","err")=prior do eq^STDASSERT(.pass,.fail,r,"set: x","lastError: returns the stashed XPAR detail")
```

### `do set^VSLCFG(key, value)`

Set parameter `key` to `value` at the SYS entity; raise on a failed write.

**Parameters**

- `key` _(string)_ — XPAR parameter name (#8989.51)
- `value` _(string)_ — value to store at the SYS level

**Returns** _void_ — side-effecting; no return value (loud on failure)

**Raises**

- `U-VSL-CFG-SET` — the XPAR write failed (detail in $$lastError)

**Example**

```m
set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do raises^STDASSERT(.pass,.fail,"do set^VSLCFG(""ZZNOSUCHVSLCFGPARAM"",""x"")","U-VSL-CFG","set: an undefined parameter raises U-VSL-CFG-...")
```

<!-- END GENERATED API REFERENCE -->
