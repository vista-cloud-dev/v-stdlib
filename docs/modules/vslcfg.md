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
| `set` | `do set^VSLCFG(key, value)` | Set parameter `key` to `value` at the SYS entity. |

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

### `do set^VSLCFG(key, value)`

Set parameter `key` to `value` at the SYS entity.

**Parameters**

- `key` _(string)_ — XPAR parameter name (#8989.51)
- `value` _(string)_ — value to store at the SYS level

**Returns** _void_ — side-effecting; no return value

**Example**

```m
new k,i,r,d set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT,k="",d=0 for  set k=$order(^XTV(8989.51,"B",k)) quit:k=""!d  set i=+$order(^XTV(8989.51,"B",k,0)) if i,$extract($get(^XTV(8989.51,i,6)))="F",$$GET^XPAR("SYS",k,1)="" do EN^XPAR("SYS",k,1,"ZZP",.r) set r=$$GET^XPAR("SYS",k,1) do EN^XPAR("SYS",k,1,"@") if r="ZZP" do set^VSLCFG(k,"hi") do eq^STDASSERT(.pass,.fail,$$get^VSLCFG(k,"MISS"),"hi","set: stores a SYS value that $$get reads back") do EN^XPAR("SYS",k,1,"@") set d=1
```

<!-- END GENERATED API REFERENCE -->
