---
module: VSLSEC
layer: v
since: 
stable: stable
synopsis: 'VistA identity/authorization adapter (Kernel)'
labels: ['bySecid', 'duz', 'hasKey', 'lastError', 'user']
errors: ['U-VSL-SEC-ARG']
see_also: []
doc_type: [REFERENCE]
---

# `VSLSEC` — VistA identity/authorization adapter (Kernel)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `bySecid` | `$$bySecid^VSLSEC(secid)` | The #200 IEN for a SecID via EN1^XUPSQRY (RPC XUPS PERSONQUERY), else "". |
| `duz` | `$$duz^VSLSEC()` | The ambient principal — +$GET(DUZ), the caller's NEW PERSON (#200) IEN. |
| `hasKey` | `$$hasKey^VSLSEC(key, duz)` | 1 iff `duz` (default: the ambient DUZ) holds security key `key`. |
| `lastError` | `$$lastError^VSLSEC()` | The last VSLSEC error message (the composed malformed-call detail). |
| `user` | `$$user^VSLSEC(duz)` | The #200 NAME for `duz` (default: the ambient DUZ), resolved via VSLFS. |

### `$$bySecid^VSLSEC(secid)`

The #200 IEN for a SecID via EN1^XUPSQRY (RPC XUPS PERSONQUERY), else "".

**Parameters**

- `secid` _(string)_ — the IAM Security ID (SECID, NEW PERSON #200 field #205.1)

**Returns** _numeric_ — the #200 IEN bound to that SecID, or "" if none / not on a VistA engine

**Raises**

- `U-VSL-SEC-ARG` — the call is malformed (an empty SecID)

**Example**

```m
do raises^STDASSERT(.pass,.fail,"set x=$$bySecid^VSLSEC("""")","U-VSL-SEC-ARG","$$bySecid("""") raises U-VSL-SEC-...")
do:$text(EN1^XUPSQRY)'="" eq^STDASSERT(.pass,.fail,$$bySecid^VSLSEC("ZZNO-SUCH-SECID-99999"),"","an unprovisioned SecID resolves to no #200 IEN") do:$text(EN1^XUPSQRY)="" true^STDASSERT(.pass,.fail,1,"EN1^XUPSQRY absent (bare engine) - SecID lookup verified on vehu/foia")
```

### `$$duz^VSLSEC()`

The ambient principal — +$GET(DUZ), the caller's NEW PERSON (#200) IEN.

**Returns** _numeric_ — the ambient DUZ (0 when no signon context is set)

**Example**

```m
new DUZ set DUZ=1 do eq^STDASSERT(.pass,.fail,$$duz^VSLSEC(),1,"$$duz returns the ambient DUZ (NEWed, no side effect)")
```

### `$$hasKey^VSLSEC(key, duz)`

1 iff `duz` (default: the ambient DUZ) holds security key `key`.

**Parameters**

- `key` _(string)_ — security-key name (SECURITY KEY #19.1 .01)
- `duz` _(numeric)_ — the user's #200 IEN; defaults to +$GET(DUZ)

**Returns** _bool_ — 1 iff the user holds the key; 0 (a normal DENY) otherwise

**Raises**

- `U-VSL-SEC-ARG` — the call is malformed (an empty key name)

**Example**

```m
do eq^STDASSERT(.pass,.fail,$$hasKey^VSLSEC("ZZ NO SUCH KEY",1),0,"hasKey is 0 (a normal DENY) for an unheld key")
new k,d set k=$order(^XUSEC("")),d=$select(k'="":$order(^XUSEC(k,0)),1:"") do:k'=""&(d'="") eq^STDASSERT(.pass,.fail,$$hasKey^VSLSEC(k,d),1,"hasKey is 1 for an existing held ^XUSEC(key,duz) pair (probed read-only)") do:k=""!(d="") true^STDASSERT(.pass,.fail,1,"no ^XUSEC pairs present (bare engine) - held-key path verified on vehu/foia")
do raises^STDASSERT(.pass,.fail,"set x=$$hasKey^VSLSEC("""",1)","U-VSL-SEC-ARG","$$hasKey with an empty key raises U-VSL-SEC-...")
```

### `$$lastError^VSLSEC()`

The last VSLSEC error message (the composed malformed-call detail).

**Returns** _string_ — ^TMP($job,"vslsec","err"), or "" if none

**Example**

```m
new $etrap set $etrap="set $ecode=""""" do hasKey^VSLSEC("") do true^STDASSERT(.pass,.fail,$$lastError^VSLSEC()'="","lastError carries the malformed-call detail after a loud failure")
```

### `$$user^VSLSEC(duz)`

The #200 NAME for `duz` (default: the ambient DUZ), resolved via VSLFS.

**Parameters**

- `duz` _(numeric)_ — the user's #200 IEN; defaults to +$GET(DUZ)

**Returns** _string_ — the NEW PERSON (#200) .01 NAME, or "" if absent

<!-- END GENERATED API REFERENCE -->
