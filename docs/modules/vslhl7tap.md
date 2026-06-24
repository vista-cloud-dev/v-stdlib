---
module: VSLHL7TAP
layer: v
since: 
stable: stable
synopsis: 'HL7 store-tail adapter (decoupled, zero in-line)'
labels: ['cursor', 'nextIen', 'read1', 'readHLO', 'readLegacy', 'tail', 'tailOne', 'tailStore']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLHL7TAP` — HL7 store-tail adapter (decoupled, zero in-line)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `cursor` | `$$cursor^VSLHL7TAP(store)` | The persisted high-water IEN for a store ("772" \| "778"); 0 if unset. |
| `nextIen` | `$$nextIen^VSLHL7TAP(store, ien)` | (private) the next numeric IEN after `ien`, or "" at the first cross-ref. |
| `read1` | `do read1^VSLHL7TAP(store, ien, msg, ok)` | (private) fenced reassembly of one entry (DO-framed so the trap QUIT is legal). |
| `readHLO` | `$$readHLO^VSLHL7TAP(ien)` | Reassemble the verbatim message for HLO #778 entry `ien` (MSH + body). |
| `readLegacy` | `$$readLegacy^VSLHL7TAP(ien)` | Reassemble the verbatim CR-delimited message for #772 entry `ien`. |
| `tail` | `do tail^VSLHL7TAP()` | Tail both HL7 stores once: ship every newly-persisted message into the ring. |
| `tailOne` | `do tailOne^VSLHL7TAP(store, ien, cur)` | (private) one tail step: advance, read-fenced, tee, persist the cursor. |
| `tailStore` | `do tailStore^VSLHL7TAP(store)` | (private) forward-only $ORDER over numeric IENs of one store. |

### `$$cursor^VSLHL7TAP(store)`

The persisted high-water IEN for a store ("772" | "778"); 0 if unset.

**Parameters**

- `store` _(string)_ — the store key

**Returns** _numeric_ — the last IEN tailed

### `$$nextIen^VSLHL7TAP(store, ien)`

(private) the next numeric IEN after `ien`, or "" at the first cross-ref.

### `do read1^VSLHL7TAP(store, ien, msg, ok)`

(private) fenced reassembly of one entry (DO-framed so the trap QUIT is legal).

**Parameters**

- `msg` _(string)_ — by-ref OUT: the verbatim message ("" on fault/purged)
- `ok` _(bool)_ — by-ref OUT: 0 iff a fault was fenced

### `$$readHLO^VSLHL7TAP(ien)`

Reassemble the verbatim message for HLO #778 entry `ien` (MSH + body).

**Parameters**

- `ien` _(numeric)_ — the #778 (^HLB) entry IEN

**Returns** _string_ — the MSH (^HLB(ien,1)_^HLB(ien,2)) then the #777 body

### `$$readLegacy^VSLHL7TAP(ien)`

Reassemble the verbatim CR-delimited message for #772 entry `ien`.

**Parameters**

- `ien` _(numeric)_ — the #772 entry IEN

**Returns** _string_ — segments ^HL(772,ien,"IN",seq,0) joined by $C(13),

### `do tail^VSLHL7TAP()`

Tail both HL7 stores once: ship every newly-persisted message into the ring.

**Returns** _void_ — consumer-gated at the top (no consumer -> no tail, cursors

### `do tailOne^VSLHL7TAP(store, ien, cur)`

(private) one tail step: advance, read-fenced, tee, persist the cursor.

**Parameters**

- `ien` _(numeric)_ — by-ref: advanced to the next IEN ("" ends the loop)
- `cur` _(numeric)_ — by-ref: the persisted high-water cursor

### `do tailStore^VSLHL7TAP(store)`

(private) forward-only $ORDER over numeric IENs of one store.

**Parameters**

- `store` _(string)_ — "772" (legacy) | "778" (HLO)

<!-- END GENERATED API REFERENCE -->
