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
| `readHLO` | `$$readHLO^VSLHL7TAP(ien)` | Reassemble the verbatim message for HLO #778 entry `ien` (MSH + body). |
| `readLegacy` | `$$readLegacy^VSLHL7TAP(ien)` | Reassemble the verbatim CR-delimited message for #772 entry `ien`. |
| `resetCursors` | `do resetCursors^VSLHL7TAP()` | Clear both cursors (re-tail from the beginning of each store). |
| `setCursor` | `do setCursor^VSLHL7TAP(store, ien)` | Persist the high-water IEN for a store. |
| `tail` | `do tail^VSLHL7TAP()` | Tail both HL7 stores once: ship every newly-persisted message into the ring. |
| `tailHLO` | `do tailHLO^VSLHL7TAP()` | Tail #778/#777 forward from its cursor, teeing each new verbatim message. |
| `tailLegacy` | `do tailLegacy^VSLHL7TAP()` | Tail #772 forward from its cursor, teeing each new verbatim message. |

### `$$cursor^VSLHL7TAP(store)`

The persisted high-water IEN for a store ("772" | "778"); 0 if unset.

**Parameters**

- `store` _(string)_ — the store key

**Returns** _numeric_ — the last IEN tailed

**Example**

```m
kill ^VSLTAP("hl7cur","772")  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),0,"an unset cursor reads as 0")
set ^VSLTAP("hl7cur","778")=4242  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("778"),4242,"cursor returns the persisted high-water IEN")  kill ^VSLTAP("hl7cur","778")
```

### `$$readHLO^VSLHL7TAP(ien)`

Reassemble the verbatim message for HLO #778 entry `ien` (MSH + body).

**Parameters**

- `ien` _(numeric)_ — the #778 (^HLB) entry IEN

**Returns** _string_ — the MSH (^HLB(ien,1)_^HLB(ien,2)) then the #777 body

**Example**

```m
set ^HLB(50,0)="MSGID123^900^^O^link",^HLB(50,1)="MSH|^~\&|APP|FAC|",^HLB(50,2)="DEST|FAC2",^HLA(900,1,1,0)="EVN|A01",^HLA(900,1,2,0)="PID|1||12345"  do eq^STDASSERT(.pass,.fail,$$readHLO^VSLHL7TAP(50),"MSH|^~\&|APP|FAC|DEST|FAC2"_$char(13)_"EVN|A01"_$char(13)_"PID|1||12345","MSH(nodes 1+2) prepended to the #777 body segments, CR-delimited, byte-verbatim")
```

### `$$readLegacy^VSLHL7TAP(ien)`

Reassemble the verbatim CR-delimited message for #772 entry `ien`.

**Parameters**

- `ien` _(numeric)_ — the #772 entry IEN

**Returns** _string_ — segments ^HL(772,ien,"IN",seq,0) joined by $C(13),

**Example**

```m
set ^HL(772,100,"IN",1,0)="MSH|^~\&|ROR SITE",^HL(772,100,"IN",2,0)="PID|1||0",^HL(772,100,"IN",3,0)="CSR|VA HEPC"  do eq^STDASSERT(.pass,.fail,$$readLegacy^VSLHL7TAP(100),"MSH|^~\&|ROR SITE"_$char(13)_"PID|1||0"_$char(13)_"CSR|VA HEPC","the three #772 'IN' segments rejoin byte-verbatim, CR-delimited")
set ^HL(772,200,0)="3170717.234501^^^^^5002230648"  do eq^STDASSERT(.pass,.fail,$$readLegacy^VSLHL7TAP(200),"","a purged #772 entry (header only, no 'IN' body) returns the empty string")
```

### `do resetCursors^VSLHL7TAP()`

Clear both cursors (re-tail from the beginning of each store).

**Example**

```m
set ^VSLTAP("hl7cur","772")=5,^VSLTAP("hl7cur","778")=9  do resetCursors^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772")+$$cursor^VSLHL7TAP("778"),0,"resetCursors clears both cursors back to 0")
```

### `do setCursor^VSLHL7TAP(store, ien)`

Persist the high-water IEN for a store.

**Parameters**

- `store` _(string)_ — the store key ("772" | "778")
- `ien` _(numeric)_ — the high-water IEN to persist

**Example**

```m
do setCursor^VSLHL7TAP("772",99)  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),99,"setCursor persists the high-water IEN, read back by $$cursor")  kill ^VSLTAP("hl7cur","772")
```

### `do tail^VSLHL7TAP()`

Tail both HL7 stores once: ship every newly-persisted message into the ring.

**Returns** _void_ — consumer-gated at the top (no consumer -> no tail, cursors

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP"),^HL(772),^HLB,^HLA  do arm^VSLTAP(),setConsumer^VSLTAP(1)  set ^HL(772,10,0)="3170627.01^^^O^^L1^^10^D",^HL(772,10,"IN",1,0)="MSH|leg",^HL(772,10,"IN",0)="^^1^1^3170627^"  set ^HLB(3,0)="H1^200^^O^link",^HLB(3,1)="MSH|^~\&|",^HLB(3,2)="|ADT",^HLA(200,1,1,0)="EVN|hlo",^HLA(200,1,0)="^^1^1^3170627^"  do tail^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),2,"one tail pass drains both the legacy and the HLO store")
kill ^VSLTAP,^XTMP("VSLTAP"),^HL(772)  do arm^VSLTAP()  set ^HL(772,10,0)="3170627^^^O^^L1^^10^D",^HL(772,10,"IN",1,0)="MSH|x",^HL(772,10,"IN",0)="^^1^1^3170627^"  do tail^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"no consumer -> zero capture, cursor frozen for catch-up on re-arm")
```

### `do tailHLO^VSLHL7TAP()`

Tail #778/#777 forward from its cursor, teeing each new verbatim message.

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP"),^HLB,^HLA  do arm^VSLTAP(),setConsumer^VSLTAP(1)  set ^HLB(7,0)="MID^400^^O^link",^HLB(7,1)="MSH|^~\&|X|",^HLB(7,2)="Y||ADT^A01|MID|P|2.4",^HLA(400,1,1,0)="EVN|A01",^HLA(400,1,0)="^^1^1^3170627^"  do tailHLO^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("778"),7,"the #778 cursor advances after tailing the HLO entry")
```

### `do tailLegacy^VSLHL7TAP()`

Tail #772 forward from its cursor, teeing each new verbatim message.

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP"),^HL(772)  do arm^VSLTAP(),setConsumer^VSLTAP(1)  set ^HL(772,2230625,0)="3170627.01^^^O^^ID1^^2230625^D",^HL(772,2230625,"IN",1,0)="MSH|^~\&|A",^HL(772,2230625,"IN",0)="^^1^1^3170627^"  set ^HL(772,2230648,0)="3170627.01^^^I^^ID2^^2230648^D",^HL(772,2230648,"IN",1,0)="MSH|^~\&|B",^HL(772,2230648,"IN",0)="^^1^1^3170627^"  do tailLegacy^VSLHL7TAP()  do eq^STDASSERT(.pass,.fail,$$cursor^VSLHL7TAP("772"),2230648,"the #772 cursor advances to the last IEN after tailing both entries")
```

<!-- END GENERATED API REFERENCE -->
