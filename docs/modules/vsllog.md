---
module: VSLLOG
layer: v
since: 
stable: stable
synopsis: 'VistA FileMan audit sink (the dedicated VSL AUDIT file)'
labels: ['auditFile', 'lastError', 'query', 'read', 'write']
errors: ['U-VSL-LOG-WRITE']
see_also: []
doc_type: [REFERENCE]
---

# `VSLLOG` — VistA FileMan audit-sink adapter (the S3 audit seam)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `auditFile` | `$$auditFile^VSLLOG()` | The dedicated VSL AUDIT FileMan file number (single source of truth). |
| `lastError` | `$$lastError^VSLLOG()` | The last VSLLOG error message (the composed FileMan detail). |
| `query` | `$$query^VSLLOG(out, event, fromDt, toDt)` | Filter audit records by event and/or FileMan date range into out("ien,")=event; return the count. |
| `read` | `$$read^VSLLOG(iens, rec)` | Read the audit record's typed fields into rec(); return the EVENT (.01), else "". |
| `write` | `do write^VSLLOG(event, detail, duz, host)` | File one structured audit record; return the resolved IENS, else raise. |

### `$$auditFile^VSLLOG()`

The dedicated VSL AUDIT FileMan file number (single source of truth).

**Returns** _numeric_ — the VSL AUDIT file number (#999001)

**Example**

```m
do eq^STDASSERT(.pass,.fail,$$auditFile^VSLLOG(),999001,"the dedicated VSL AUDIT file number")
```

### `$$lastError^VSLLOG()`

The last VSLLOG error message (the composed FileMan detail).

**Returns** _string_ — ^TMP($job,"vsllog","err"), or "" if none

### `$$query^VSLLOG(out, event, fromDt, toDt)`

Filter audit records by event and/or FileMan date range into out("ien,")=event; return the count.

**Parameters**

- `out` _(array)_ — (by ref) set out("ien,")=event for each matching record
- `event` _(string)_ — exact event (.01) to match; "" or omitted = any event
- `fromDt` _(numeric)_ — inclusive lower bound on TIMESTAMP (FileMan internal date); "" or omitted = no lower bound
- `toDt` _(numeric)_ — inclusive upper bound on TIMESTAMP (FileMan internal date); "" or omitted = no upper bound

**Returns** _numeric_ — the number of matching records

### `$$read^VSLLOG(iens, rec)`

Read the audit record's typed fields into rec(); return the EVENT (.01), else "".

**Parameters**

- `iens` _(string)_ — IENS of the audit record
- `rec` _(array)_ — (by ref) filled: rec("event"|"timestamp"|"user"|"host"|"detail")

**Returns** _string_ — the stored EVENT (.01), or "" if the record is absent

### `do write^VSLLOG(event, detail, duz, host)`

File one structured audit record; return the resolved IENS, else raise.

**Parameters**

- `event` _(string)_ — short event name (the .01; 1-30 chars)
- `detail` _(string)_ — free-text detail (filed only when non-empty)
- `duz` _(numeric)_ — acting principal #200 IEN; defaults to +$GET(DUZ); 0 = system
- `host` _(string)_ — originating host/$IO; defaults to $IO (filed only when non-empty)

**Returns** _string_ — the resolved IENS of the new audit record

**Raises**

- `U-VSL-LOG-WRITE` — the FileMan write failed (detail in $$lastError)

<!-- END GENERATED API REFERENCE -->
