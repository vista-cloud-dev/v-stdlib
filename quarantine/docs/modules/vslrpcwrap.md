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

**Example**

```m
new rec,DUZ,XWBTIP,XWBTSKT set DUZ=168,XWBTIP="10.1.2.3",XWBTSKT=51001 do ctx^VSLRPCWRAP(.rec) do eq^STDASSERT(.pass,.fail,rec("client"),"10.1.2.3:51001","client = XWBTIP:XWBTSKT (FU-18)")
new rec,DUZ,XWBTIP,XWBTSKT set DUZ=168 do ctx^VSLRPCWRAP(.rec) do eq^STDASSERT(.pass,.fail,rec("duz"),168,"duz read from DUZ; job = $job")
```

### `$$params^VSLRPCWRAP()`

(private) join the broker's decoded input params XWB(3,"P",*) verbatim (no typing — §9).

**Returns** _byte-string_ — the params $C(1)-joined in subscript order (FU-16(c): inputs

**Example**

```m
new XWB set XWB(3,"P",1)="ALPHA",XWB(3,"P",2)="9",XWB(3,"P",3)="" do eq^STDASSERT(.pass,.fail,$$params^VSLRPCWRAP(),"ALPHA"_$char(1)_"9"_$char(1)_"","params $C(1)-joined verbatim in subscript order")
```

### `do req^VSLRPCWRAP()`

Request side-call: emit a dir=req record for EVERY RPC (incl. denied/errored).

**Returns** _void_ — fire-and-forget; the broker's result/$ECODE/$T/naked-ref are untouched.

**Example**

```m
new h,hdr,ok,XWB,XWBSEC tstart ():transactionid="batch" set XWB(2,"CAPI")="ORWPT LIST ALL",XWBSEC="",^VSLTAP("cfg","s3station")="500" do arm^VSLTAP(),setConsumer^VSLTAP(1),req^VSLRPCWRAP() set h=$$head^VSLTAP(),ok=$$hdr^VSLTAP(h,.hdr) do eq^STDASSERT(.pass,.fail,hdr("direction"),"req","req emits one dir=req record (rolled back via tstart/trollback)") trollback
```

### `do reqWork^VSLRPCWRAP()`

(private) DO-framed: gate, build the dir=req rec from broker vars, tee it.

**Example**

```m
new h,hdr,ok,XWB,XWBSEC tstart ():transactionid="batch" set XWB(2,"CAPI")="ORWU NEWPERS",XWBSEC="",^VSLTAP("cfg","s3station")="500" do arm^VSLTAP(),setConsumer^VSLTAP(1),reqWork^VSLRPCWRAP() set h=$$head^VSLTAP(),ok=$$hdr^VSLTAP(h,.hdr) do eq^STDASSERT(.pass,.fail,hdr("rpc"),"ORWU NEWPERS","reqWork builds the req rec carrying the XWB CAPI rpc name (rolled back)") trollback
```

### `do resp^VSLRPCWRAP()`

Result side-call: emit a dir=resp record on the dispatch-success path.

**Returns** _void_ — fenced exactly like req(); correlated to its request by call_id.

**Example**

```m
new h,hdr,ok,XWB,XWBSEC,XWBP,XWBPTYPE tstart ():transactionid="batch" set XWB(2,"CAPI")="ORWPT LIST ALL",XWBSEC="",XWBP="result",XWBPTYPE=1,^VSLTAP("cfg","s3station")="500" do arm^VSLTAP(),setConsumer^VSLTAP(1),req^VSLRPCWRAP(),resp^VSLRPCWRAP() set h=$$head^VSLTAP(),ok=$$hdr^VSLTAP(h,.hdr) do eq^STDASSERT(.pass,.fail,hdr("direction"),"resp","resp emits a dir=resp record on the success path (rolled back)") trollback
```

### `do result^VSLRPCWRAP(rec)`

(private) classify the result by XWBPTYPE (FU-16(c)) — scalar payload or a snapshot ref.

**Parameters**

- `rec` _(array)_ — by-ref: sets result_kind + (payload | gref)

**Example**

```m
new rec,XWBPTYPE,XWBP set XWBPTYPE=1,XWBP="hello" do result^VSLRPCWRAP(.rec) do eq^STDASSERT(.pass,.fail,rec("result_kind"),"scalar","XWBPTYPE=1 -> result_kind=scalar")
new rec,XWBPTYPE,XWBP set XWBPTYPE=1,XWBP="hello" do result^VSLRPCWRAP(.rec) do eq^STDASSERT(.pass,.fail,rec("payload"),"hello","scalar payload = the verbatim XWBP value")
new rec,XWBPTYPE,XWBP set XWBPTYPE=4,XWBP="^TMP($J,""X"")" do result^VSLRPCWRAP(.rec) do eq^STDASSERT(.pass,.fail,rec("result_kind"),"global","XWBPTYPE=4 -> result_kind=global, gref = the closed-root ref")
new rec,XWBPTYPE set XWBPTYPE=2 do result^VSLRPCWRAP(.rec) do eq^STDASSERT(.pass,.fail,rec("gref"),"XWBP","XWBPTYPE=2 (table) -> gref=XWBP (a LOCAL array tree)")
```

<!-- END GENERATED API REFERENCE -->
