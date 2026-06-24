---
module: VSLFS
layer: v
since: 
stable: stable
synopsis: 'VistA FileMan storage adapter (FileMan DBS record store)'
labels: ['exists', 'get', 'kill', 'lastError', 'set']
errors: ['U-VSL-FS-DIERR']
see_also: []
doc_type: [REFERENCE]
---

# `VSLFS` — VistA FileMan storage adapter (FileMan DBS record store)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `exists` | `$$exists^VSLFS(file, iens)` | Return 1 iff record (file,iens) exists (its .01 reads without a DIERR). |
| `get` | `$$get^VSLFS(file, iens, field, default)` | Read (file,iens,field) via $$GET1^DIQ; return value, else `default`. |
| `kill` | `$$kill^VSLFS(file, iens)` | Delete record (file,iens) via an FDA .01="@" through FILE^DIE; return 1. |
| `lastError` | `$$lastError^VSLFS()` | The last VSLFS error message (the composed FileMan DIERR detail). |
| `set` | `$$set^VSLFS(file, iens, field, value)` | File `value` into (file,iens,field); return the resolved IENS, else raise. |

### `$$exists^VSLFS(file, iens)`

Return 1 iff record (file,iens) exists (its .01 reads without a DIERR).

**Parameters**

- `file` _(numeric)_ — FileMan file number
- `iens` _(string)_ — IENS of the record

**Returns** _bool_ — 1 iff the record exists; 0 otherwise

**Example**

```m
set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do eq^STDASSERT(.pass,.fail,$$exists^VSLFS(200,"1,"),1,"exists: #200 IEN 1 (postmaster) exists")
set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do eq^STDASSERT(.pass,.fail,$$exists^VSLFS(200,"999999999,"),0,"exists: an absent record returns 0")
```

### `$$get^VSLFS(file, iens, field, default)`

Read (file,iens,field) via $$GET1^DIQ; return value, else `default`.

**Parameters**

- `file` _(numeric)_ — FileMan file number
- `iens` _(string)_ — IENS of the record
- `field` _(string)_ — field number
- `default` _(string)_ — value returned when the field/record is unset

**Returns** _string_ — the external field value, or `default`

**Example**

```m
set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do true^STDASSERT(.pass,.fail,$$get^VSLFS(200,"1,",".01","")'="","get: #200 IEN 1 (.01) reads a non-empty name")
set DUZ=1,DUZ(0)="@",U="^",DT=$$DT^XLFDT do eq^STDASSERT(.pass,.fail,$$get^VSLFS(200,"999999999,",".01","MISS"),"MISS","get: an absent record returns the default")
```

### `$$kill^VSLFS(file, iens)`

Delete record (file,iens) via an FDA .01="@" through FILE^DIE; return 1.

**Parameters**

- `file` _(numeric)_ — FileMan file number
- `iens` _(string)_ — IENS of the record to delete

**Returns** _bool_ — 1 (idempotent — a DIERR is recorded, not raised)

### `$$lastError^VSLFS()`

The last VSLFS error message (the composed FileMan DIERR detail).

**Returns** _string_ — ^TMP($job,"vslfs","err"), or "" if none

**Example**

```m
new prior,r set prior=$get(^TMP($job,"vslfs","err")),^TMP($job,"vslfs","err")="set: FileMan DIERR" set r=$$lastError^VSLFS() set ^TMP($job,"vslfs","err")=prior do eq^STDASSERT(.pass,.fail,r,"set: FileMan DIERR","lastError: returns the composed FileMan DIERR detail")
```

### `$$set^VSLFS(file, iens, field, value)`

File `value` into (file,iens,field); return the resolved IENS, else raise.

**Parameters**

- `file` _(numeric)_ — FileMan file number
- `iens` _(string)_ — IENS; "+1," (etc.) adds a new record
- `field` _(string)_ — field number within the file
- `value` _(string)_ — external value to file

**Returns** _string_ — the resolved IENS on success (the new IENS for an add)

**Raises**

- `U-VSL-FS-DIERR` — a FileMan DIERR (detail in $$lastError)

**Example**

```m
do raises^STDASSERT(.pass,.fail,"set DUZ=1,DUZ(0)=""@"",U=""^"",DT=$$DT^XLFDT set x=$$set^VSLFS(99999999,""+1,"","".01"",""ZZ"")","U-VSL-FS","set: a FileMan DIERR raises U-VSL-FS-DIERR")
```

<!-- END GENERATED API REFERENCE -->
