---
module: VSLRPCWRAP
layer: v
since: 
stable: stable
synopsis: 'the XWB broker-dispatch wrap glue (FU-5 / G-RPCHOOK)'
labels: ['ctx', 'params', 'req', 'reqWork', 'resp', 'result']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLRPCWRAP` — the XWB broker-dispatch wrap glue (FU-5 / G-RPCHOOK)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `ctx` | `do ctx^VSLRPCWRAP(rec)` | (private) FU-18 context read at the wrap depth (process scope; ancestor EN^XWBTCPC). |
| `params` | `$$params^VSLRPCWRAP()` | (private) join the broker's decoded input params XWB(3,"P",*) verbatim (no typing — §9). |
| `req` | `do req^VSLRPCWRAP()` | Request side-call: emit a dir=req record for EVERY RPC (incl. denied/errored). |
| `reqWork` | `do reqWork^VSLRPCWRAP()` | (private) DO-framed: gate, build the dir=req rec from broker vars, tee it. |
| `resp` | `do resp^VSLRPCWRAP()` | Result side-call: emit a dir=resp record on the dispatch-success path. |
| `result` | `do result^VSLRPCWRAP(rec)` | (private) classify the result by XWBPTYPE (FU-16(c)) — scalar payload or a snapshot ref. |

### `do ctx^VSLRPCWRAP(rec)`

(private) FU-18 context read at the wrap depth (process scope; ancestor EN^XWBTCPC).

**Parameters**

- `rec` _(array)_ — by-ref: sets duz/job/client/station

### `$$params^VSLRPCWRAP()`

(private) join the broker's decoded input params XWB(3,"P",*) verbatim (no typing — §9).

**Returns** _byte-string_ — the params $C(1)-joined in subscript order (FU-16(c): inputs

### `do req^VSLRPCWRAP()`

Request side-call: emit a dir=req record for EVERY RPC (incl. denied/errored).

**Returns** _void_ — fire-and-forget; the broker's result/$ECODE/$T/naked-ref are untouched.

### `do reqWork^VSLRPCWRAP()`

(private) DO-framed: gate, build the dir=req rec from broker vars, tee it.

### `do resp^VSLRPCWRAP()`

Result side-call: emit a dir=resp record on the dispatch-success path.

**Returns** _void_ — fenced exactly like req(); correlated to its request by call_id.

### `do result^VSLRPCWRAP(rec)`

(private) classify the result by XWBPTYPE (FU-16(c)) — scalar payload or a snapshot ref.

**Parameters**

- `rec` _(array)_ — by-ref: sets result_kind + (payload | gref)

<!-- END GENERATED API REFERENCE -->
