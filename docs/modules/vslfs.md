---
module: VSLFS
layer: v
since: 
stable: stable
synopsis: 'VistA FileMan storage adapter (FileMan DBS record store)'
labels: ['exists', 'find', 'get', 'kill', 'lastError', 'list', 'set']
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
| `find` | `$$find^VSLFS(file, value, index)` | The IENS of the UNIQUE record whose `index` lookup equals `value`, else "". |
| `get` | `$$get^VSLFS(file, iens, field, default, flags)` | Read (file,iens,field) via $$GET1^DIQ; return value, else `default`. |
| `kill` | `$$kill^VSLFS(file, iens)` | Delete record (file,iens) via an FDA .01="@" through FILE^DIE; return 1. |
| `lastError` | `$$lastError^VSLFS()` | The last VSLFS error message (the composed FileMan DIERR detail). |
| `list` | `$$list^VSLFS(file, out, index)` | List the IENS of every record (via LIST^DIC) into out("ien,"); return the count. |
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

### `$$find^VSLFS(file, value, index)`

The IENS of the UNIQUE record whose `index` lookup equals `value`, else "".

**Parameters**

- `file` _(numeric)_ — FileMan file number
- `value` _(string)_ — the lookup value to match (exact)
- `index` _(string)_ — the cross-reference to search (default "B")

**Returns** _string_ — the IENS ("ien,") of the single match, else "" (absent or ambiguous)

### `$$get^VSLFS(file, iens, field, default, flags)`

Read (file,iens,field) via $$GET1^DIQ; return value, else `default`.

**Parameters**

- `file` _(numeric)_ — FileMan file number
- `iens` _(string)_ — IENS of the record
- `field` _(string)_ — field number
- `default` _(string)_ — value returned when the field/record is unset
- `flags` _(string)_ — $$GET1^DIQ flags: "" external (default), "I" internal

**Returns** _string_ — the field value (external, or internal if flags["I"]), or `default`

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

**Returns** _bool_ — 1 always (idempotent — a failed delete records a DIERR, never raises, unlike $$set)

### `$$lastError^VSLFS()`

The last VSLFS error message (the composed FileMan DIERR detail).

**Returns** _string_ — ^TMP($job,"vslfs","err"), or "" if none

### `$$list^VSLFS(file, out, index)`

List the IENS of every record (via LIST^DIC) into out("ien,"); return the count.

**Parameters**

- `file` _(numeric)_ — FileMan file number
- `out` _(array)_ — (by ref) set out("ien,")="" for each record found
- `index` _(string)_ — traversal cross-reference (default "B")

**Returns** _numeric_ — the number of records listed

**Raises**

- `U-VSL-FS-DIERR` — a FileMan DIERR (detail in $$lastError)

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

<!-- END GENERATED API REFERENCE -->
