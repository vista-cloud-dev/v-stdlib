---
module: VSLRPCTAP
layer: v
since: 
stable: stable
synopsis: 'RPC tap adapter at the VSLRPC chokepoint (the fenced tee)'
labels: ['callId', 'capture', 'nakedRef', 'work']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLRPCTAP` — RPC tap adapter at the VSLRPC chokepoint (the fenced tee)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `callId` | `$$callId^VSLRPCTAP(station, ctr)` | Build a correlation call_id = station "-" $J "-" ctr (schema-lock §2). |
| `capture` | `do capture^VSLRPCTAP(rec)` | Fenced fire-and-forget tee of one RPC record (cache layout v2) into the rolling ring. |
| `nakedRef` | `$$nakedRef^VSLRPCTAP()` | (private) the caller's last global reference, dual-engine. "" at job start. |
| `work` | `do work^VSLRPCTAP(rec)` | (private) the global-touching side, DO-framed so a fault can never escape the boundary. |

### `$$callId^VSLRPCTAP(station, ctr)`

Build a correlation call_id = station "-" $J "-" ctr (schema-lock §2).

**Parameters**

- `station` _(string)_ — the originating station number
- `ctr` _(numeric)_ — a $J-scoped counter the wrap bumps ONCE per RPC invocation

**Returns** _string_ — the call_id shared by that RPC's req + resp records

**Example**

```m
do eq^STDASSERT(.pass,.fail,$$callId^VSLRPCTAP("500",7),"500-"_$job_"-7","callId builds station-$J-counter")
```

### `do capture^VSLRPCTAP(rec)`

Fenced fire-and-forget tee of one RPC record (cache layout v2) into the rolling ring.

**Parameters**

- `rec` _(array)_ — by-ref record descriptor (read-only; the tap never mutates it)

**Returns** _void_ — fire-and-forget — the result/$ECODE/$T/naked-ref of the RPC worker are untouched

**Example**

```m
new rec do off^VSLTAP(),arm^VSLTAP() kill ^XTMP("VSLTAP") set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="ORWU DT",rec("payload")="DUZ=10^NOW" do capture^VSLRPCTAP(.rec) do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"capture tees one record into the always-on ring") do off^VSLTAP() kill ^XTMP("VSLTAP")
```

### `$$nakedRef^VSLRPCTAP()`

(private) the caller's last global reference, dual-engine. "" at job start.

**Returns** _string_ — $REFERENCE (YDB) / $ZREFERENCE (IRIS) — the naked indicator

**Example**

```m
new zz set zz=$data(^VSLTAP("cfg")) do eq^STDASSERT(.pass,.fail,$$nakedRef^VSLRPCTAP(),"^VSLTAP(""cfg"")","nakedRef returns the caller's last global reference")
```

### `do work^VSLRPCTAP(rec)`

(private) the global-touching side, DO-framed so a fault can never escape the boundary.

**Parameters**

- `rec` _(array)_ — by-ref record descriptor (the caller's array is untouched)

**Example**

```m
new rec do off^VSLTAP(),arm^VSLTAP() kill ^XTMP("VSLTAP") set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="X",rec("payload")="P" do work^VSLRPCTAP(.rec) do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"work appends the record (the global-touching side)") do off^VSLTAP() kill ^XTMP("VSLTAP")
```

<!-- END GENERATED API REFERENCE -->
