---
module: VSLLOG
layer: v
since: 
stable: stable
synopsis: 'VistA FileMan audit-sink adapter (the S3 audit seam)'
labels: ['lastError', 'read', 'write']
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
| `lastError` | `$$lastError^VSLLOG()` | The last VSLLOG error message (the composed FileMan detail). |
| `read` | `$$read^VSLLOG(file, iens)` | Read the audit line stored at (file,iens) .01, else "". |
| `write` | `do write^VSLLOG(file, event, detail)` | File one audit record into `file`; return the resolved IENS, else raise. |

### `$$lastError^VSLLOG()`

The last VSLLOG error message (the composed FileMan detail).

**Returns** _string_ — ^TMP($job,"vsllog","err"), or "" if none

### `$$read^VSLLOG(file, iens)`

Read the audit line stored at (file,iens) .01, else "".

**Parameters**

- `file` _(numeric)_ — FileMan audit-file number
- `iens` _(string)_ — IENS of the audit record

**Returns** _string_ — the stored audit line, or "" if absent

### `do write^VSLLOG(file, event, detail)`

File one audit record into `file`; return the resolved IENS, else raise.

**Parameters**

- `file` _(numeric)_ — FileMan audit-file number
- `event` _(string)_ — short event name (audit category)
- `detail` _(string)_ — free-text detail for the record

**Returns** _string_ — the resolved IENS of the new audit record

**Raises**

- `U-VSL-LOG-WRITE` — the FileMan write failed (detail in $$lastError)

<!-- END GENERATED API REFERENCE -->
