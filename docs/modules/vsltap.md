---
module: VSLTAP
layer: v
since: 
stable: stable
synopsis: 'non-interference traffic-tap core (the safety gate)'
labels: ['append', 'appendRec', 'captureOn', 'cfg', 'disable', 'drainTo', 'enabled', 'hdr', 'hdrLine', 'healthy', 'isV2', 'offWindows', 'present', 'purgeNode', 'seed', 'seedMap', 'setAlwaysOn', 'state', 'tee', 'teeRec', 'write1', 'write1rec']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLTAP` — non-interference traffic-tap core (the safety gate)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `append` | `$$append^VSLTAP(rec)` | Gated, fault-fenced, bounded memory-copy append of a verbatim record. |
| `appendRec` | `$$appendRec^VSLTAP(rec)` | FU-5: gated, fault-fenced, bounded append of a RICH (cache layout v2) record. |
| `arm` | `do arm^VSLTAP()` | Operator: arm the tap (kill-switch ON) and clear any prior auto-disable. |
| `captureOn` | `$$captureOn^VSLTAP()` | FU-9 (D-6): 1 iff the RING should capture now — armed AND not auto-disabled. |
| `cfg` | `$$cfg^VSLTAP(key, default)` | Read a config knob from ^VSLTAP("cfg",key), else `default`. |
| `chunk` | `$$chunk^VSLTAP(seq, i)` | The i-th RAW payload chunk of a v2 record ("" if absent). |
| `disable` | `do disable^VSLTAP(reason)` | Auto-failover: disable the tap, record an off-window (explicit, never silent). |
| `disabled` | `$$disabled^VSLTAP()` | The auto-failover reason, or "" if armed/clean. |
| `drainTo` | `do drainTo^VSLTAP(seq)` | Post-ship trim: drop retained entries up to and including `seq`, advance tail. |
| `enabled` | `$$enabled^VSLTAP()` | 1 iff EGRESS should run now: capture-on AND a consumer/sink is present (D-5). |
| `hdr` | `$$hdr^VSLTAP(seq, out)` | Parse the v2 header at `seq` into out("schema_version"/...); return 1 iff a v2 record. |
| `head` | `$$head^VSLTAP()` | Highest written seq (0 if empty). |
| `healthy` | `$$healthy^VSLTAP()` | 1 iff the heartbeat is fresh within the staleness bound (k8s-style liveness). |
| `heartbeat` | `do heartbeat^VSLTAP()` | Stamp the liveness heartbeat (the watchdog beats this every N seconds). |
| `isV2` | `$$isV2^VSLTAP(seq)` | 1 iff the record at `seq` is a cache-layout-v2 record (a "p" or "g" child present). |
| `off` | `do off^VSLTAP()` | Operator: kill-switch OFF (state OFF; capture cannot run). |
| `offWindows` | `$$offWindows^VSLTAP(out)` | Populate out(1..N) with the recorded off-windows; return the count. |
| `present` | `$$present^VSLTAP(seq)` | 1 iff a data node exists at `seq` ($DATA'=0) — distinguishes an empty-string record from an absent/uncommitted slot. |
| `purgeNode` | `do purgeNode^VSLTAP()` | Write ^XTMP("VSLTAP",0)=purgedate^createdate^description so Kernel XQ82 reaps it. |
| `read` | `$$read^VSLTAP(seq)` | The verbatim record at `seq`, or "" if absent/overwritten. |
| `rearm` | `do rearm^VSLTAP()` | Re-arm after a clean cool-down (D-4): clear the disable + close the off-window. |
| `seed` | `do seed^VSLTAP()` | Populate ^VSLTAP("cfg",…) from the installed XPAR #8989.51 params (self-configuring install). |
| `seedMap` | `$$seedMap^VSLTAP(map)` | Map each installed XPAR param name to the ^VSLTAP("cfg") key the tap reads; return the count. |
| `setAlwaysOn` | `do setAlwaysOn^VSLTAP(flag)` | LEGACY/SUBSUMED (D-8 -> FU-9): kept for backward compatibility; no longer gates capture. |
| `setConsumer` | `do setConsumer^VSLTAP(present)` | Set the consumer-presence flag (D-5): no consumer -> egress/capture OFF. |
| `size` | `$$size^VSLTAP()` | Current ring entry count (head - tail). |
| `state` | `$$state^VSLTAP()` | The standby state-machine label (spec §8.1). |
| `tail` | `$$tail^VSLTAP()` | (lowest-retained seq) - 1 (0 if empty). |
| `tee` | `$$tee^VSLTAP(rec)` | The named capture seam the VSLRPC chokepoint calls (VSLRPCTAP) — fenced. |
| `teeRec` | `$$teeRec^VSLTAP(rec)` | The named rich-record capture seam the FU-5 wrap calls (via VSLRPCTAP) — fenced. |

### `$$append^VSLTAP(rec)`

Gated, fault-fenced, bounded memory-copy append of a verbatim record.

**Parameters**

- `rec` _(string)_ — the verbatim payload (no parse, no transform — D-1)

**Returns** _bool_ — 1 iff captured; 0 iff gated, auto-disabled, copy-cost-tripped, or fenced

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$append^VSLTAP("rpc-record"),1,"captures with no consumer (always-on ring)") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set zz=$$append^VSLTAP("TST^DUZ=1") do eq^STDASSERT(.pass,.fail,$$read^VSLTAP($$head^VSLTAP()),"TST^DUZ=1","the stored record is verbatim (no transform)") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^VSLTAP,^XTMP("VSLTAP") do off^VSLTAP() do eq^STDASSERT(.pass,.fail,$$append^VSLTAP("x"),0,"OFF -> gated, no append") kill ^VSLTAP,^XTMP("VSLTAP")
```

### `$$appendRec^VSLTAP(rec)`

FU-5: gated, fault-fenced, bounded append of a RICH (cache layout v2) record.

**Parameters**

- `rec` _(array)_ — by-ref record descriptor (dir/rpc/payload/gref/call_id/...; read-only)

**Returns** _bool_ — 1 iff captured; 0 iff gated, auto-disabled, copy-cost-tripped, or fenced

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") set rec("dir")="resp",rec("call_id")="500-1-1",rec("rpc")="ORWPT INFO",rec("payload")="body",rec("result_kind")="scalar" do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$appendRec^VSLTAP(.rec),1,"a rich v2 record is captured when armed") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^VSLTAP,^XTMP("VSLTAP") set rec("payload")="body" do off^VSLTAP() do eq^STDASSERT(.pass,.fail,$$appendRec^VSLTAP(.rec),0,"OFF -> gated, no v2 append") kill ^VSLTAP,^XTMP("VSLTAP")
```

### `do arm^VSLTAP()`

Operator: arm the tap (kill-switch ON) and clear any prior auto-disable.

**Example**

```m
kill ^VSLTAP do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$cfg^VSLTAP("mode","off"),"armed","arm sets mode=armed") kill ^VSLTAP
kill ^VSLTAP set ^VSLTAP("disabled")="fault" do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"","arm clears a prior auto-disable") kill ^VSLTAP
```

### `$$captureOn^VSLTAP()`

FU-9 (D-6): 1 iff the RING should capture now — armed AND not auto-disabled.

**Returns** _bool_ — the ALWAYS-ON capture gate. The ring records whenever the tap

**Example**

```m
kill ^VSLTAP do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$captureOn^VSLTAP(),1,"armed + clean -> capture ON regardless of consumer") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP(),disable^VSLTAP("fault") do eq^STDASSERT(.pass,.fail,$$captureOn^VSLTAP(),0,"auto-failover -> capture OFF (fail-safe)") kill ^VSLTAP
```

### `$$cfg^VSLTAP(key, default)`

Read a config knob from ^VSLTAP("cfg",key), else `default`.

**Parameters**

- `key` _(string)_ — config key (mode/consumer/alwayson/cap/maxbytes/latbound/hbstale/retain)
- `default` _(string)_ — value when unset

**Returns** _string_ — the configured value or the default

**Example**

```m
do eq^STDASSERT(.pass,.fail,$$cfg^VSLTAP("nosuchkey","fallback"),"fallback","unset key returns the default")
set ^VSLTAP("cfg","cap")=750 do eq^STDASSERT(.pass,.fail,$$cfg^VSLTAP("cap",1000),750,"a set cfg knob reads back") kill ^VSLTAP("cfg","cap")
```

### `$$chunk^VSLTAP(seq, i)`

The i-th RAW payload chunk of a v2 record ("" if absent).

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") set rec("dir")="resp",rec("payload")="chunkbody",rec("result_kind")="scalar" do arm^VSLTAP() set zz=$$appendRec^VSLTAP(.rec) do eq^STDASSERT(.pass,.fail,$$chunk^VSLTAP($$head^VSLTAP(),1),"chunkbody","the first RAW payload chunk reads back verbatim") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^XTMP("VSLTAP") do eq^STDASSERT(.pass,.fail,$$chunk^VSLTAP(99,1),"","absent chunk -> empty string")
```

### `do disable^VSLTAP(reason)`

Auto-failover: disable the tap, record an off-window (explicit, never silent).

**Parameters**

- `reason` _(string)_ — the interference signal (fault/copycost/latency/pressure)

**Example**

```m
kill ^VSLTAP do arm^VSLTAP(),disable^VSLTAP("pressure") do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"pressure","disable records the reason") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP(),disable^VSLTAP("latency") do true^STDASSERT(.pass,.fail,$$offWindows^VSLTAP(.zo)'<1,"disable opens an off-window (explicit, never silent)") kill ^VSLTAP
```

### `$$disabled^VSLTAP()`

The auto-failover reason, or "" if armed/clean.

**Example**

```m
kill ^VSLTAP do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"","armed/clean -> empty reason") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP(),disable^VSLTAP("fault") do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"fault","reports the auto-failover reason") kill ^VSLTAP
```

### `do drainTo^VSLTAP(seq)`

Post-ship trim: drop retained entries up to and including `seq`, advance tail.

**Parameters**

- `seq` _(numeric)_ — the highest shipped sequence (bounded to head)

**Returns** _void_ — the drain self-KILLs shipped entries (spec §4.1.3)

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set zz=$$append^VSLTAP("r1"),zz=$$append^VSLTAP("r2"),zz=$$append^VSLTAP("r3"),zz=$$append^VSLTAP("r4"),zz=$$append^VSLTAP("r5") do drainTo^VSLTAP(3) do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),2,"after draining through seq 3, 2 of 5 remain") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set zz=$$append^VSLTAP("a") do drainTo^VSLTAP(99) do eq^STDASSERT(.pass,.fail,$$tail^VSLTAP(),$$head^VSLTAP(),"drainTo is bounded to head (never advances past it)") kill ^VSLTAP,^XTMP("VSLTAP")
```

### `$$enabled^VSLTAP()`

1 iff EGRESS should run now: capture-on AND a consumer/sink is present (D-5).

**Returns** _bool_ — the EGRESS gate. The drain ships and $$state reports ACTIVE only

**Example**

```m
kill ^VSLTAP do arm^VSLTAP(),setConsumer^VSLTAP(1) do eq^STDASSERT(.pass,.fail,$$enabled^VSLTAP(),1,"capture-on + consumer -> egress enabled") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$enabled^VSLTAP(),0,"capture-on but no consumer -> egress gated off") kill ^VSLTAP
```

### `$$hdr^VSLTAP(seq, out)`

Parse the v2 header at `seq` into out("schema_version"/...); return 1 iff a v2 record.

**Parameters**

- `seq` _(numeric)_ — the ring sequence
- `out` _(array)_ — OUT by-ref: the 18 header fields keyed by their schema-v1 names

**Returns** _bool_ — 1 iff `seq` is a v2 record (else `out` is killed, returns 0)

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set zz=$$append^VSLTAP("flat") do eq^STDASSERT(.pass,.fail,$$hdr^VSLTAP(1,.zo),0,"a v1 record has no v2 header -> 0") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^VSLTAP,^XTMP("VSLTAP") set zr=$name(^TMP($job,"V2")),@zr@("a")="x",rec("dir")="resp",rec("rpc")="ORWU GLOBAL",rec("gref")=zr,rec("result_kind")="global" do arm^VSLTAP() set zz=$$appendRec^VSLTAP(.rec) set zz=$$hdr^VSLTAP($$head^VSLTAP(),.zo) do eq^STDASSERT(.pass,.fail,zo("rpc")_"/"_zo("direction")_"/"_zo("schema_version"),"ORWU GLOBAL/resp/1","header parses rpc, direction and schema_version") kill ^VSLTAP,^XTMP("VSLTAP"),@zr
```

### `$$head^VSLTAP()`

Highest written seq (0 if empty).

**Example**

```m
kill ^XTMP("VSLTAP") do eq^STDASSERT(.pass,.fail,$$head^VSLTAP(),0,"empty ring -> head 0")
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set zz=$$append^VSLTAP("a"),zz=$$append^VSLTAP("b") do eq^STDASSERT(.pass,.fail,$$head^VSLTAP(),2,"two appends -> head 2") kill ^VSLTAP,^XTMP("VSLTAP")
```

### `$$healthy^VSLTAP()`

1 iff the heartbeat is fresh within the staleness bound (k8s-style liveness).

**Returns** _bool_ — a stale/absent heartbeat -> 0 (UNHEALTHY) even with zero traffic

**Example**

```m
kill ^VSLTAP do arm^VSLTAP(),heartbeat^VSLTAP() do eq^STDASSERT(.pass,.fail,$$healthy^VSLTAP(),1,"fresh heartbeat -> healthy") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP() set ^VSLTAP("hb")=0 do eq^STDASSERT(.pass,.fail,$$healthy^VSLTAP(),0,"stale heartbeat -> not healthy") kill ^VSLTAP
kill ^VSLTAP do eq^STDASSERT(.pass,.fail,$$healthy^VSLTAP(),0,"absent heartbeat -> not healthy")
```

### `do heartbeat^VSLTAP()`

Stamp the liveness heartbeat (the watchdog beats this every N seconds).

**Example**

```m
kill ^VSLTAP do arm^VSLTAP(),heartbeat^VSLTAP() do true^STDASSERT(.pass,.fail,$$healthy^VSLTAP()=1,"a fresh heartbeat -> healthy") kill ^VSLTAP
```

### `$$isV2^VSLTAP(seq)`

1 iff the record at `seq` is a cache-layout-v2 record (a "p" or "g" child present).

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set zz=$$append^VSLTAP("flat") do eq^STDASSERT(.pass,.fail,$$isV2^VSLTAP(1),0,"a legacy v1 string record is not v2") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^VSLTAP,^XTMP("VSLTAP") set zr=$name(^TMP($job,"V2")),@zr@("a")="x",rec("dir")="resp",rec("gref")=zr,rec("result_kind")="global" do arm^VSLTAP() set zz=$$appendRec^VSLTAP(.rec) do true^STDASSERT(.pass,.fail,$$isV2^VSLTAP($$head^VSLTAP()),"a record with a g child is v2") kill ^VSLTAP,^XTMP("VSLTAP"),@zr
```

### `do off^VSLTAP()`

Operator: kill-switch OFF (state OFF; capture cannot run).

**Example**

```m
kill ^VSLTAP do arm^VSLTAP(),off^VSLTAP() do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"OFF","kill-switch -> state OFF") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP(),off^VSLTAP() do eq^STDASSERT(.pass,.fail,$$captureOn^VSLTAP(),0,"OFF -> capture gate cannot run") kill ^VSLTAP
```

### `$$offWindows^VSLTAP(out)`

Populate out(1..N) with the recorded off-windows; return the count.

**Parameters**

- `out` _(array)_ — by-ref; killed then filled with open^reason^close rows

**Example**

```m
kill ^VSLTAP do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$offWindows^VSLTAP(.zo),0,"no failover yet -> zero off-windows") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP(),disable^VSLTAP("pressure") set zz=$$offWindows^VSLTAP(.zo) do eq^STDASSERT(.pass,.fail,$piece(zo(1),"^",2),"pressure","the recorded off-window carries its reason") kill ^VSLTAP
```

### `$$present^VSLTAP(seq)`

1 iff a data node exists at `seq` ($DATA'=0) — distinguishes an empty-string record from an absent/uncommitted slot.

**Returns** _bool_ — The drain ships only the CONTIGUOUS COMMITTED prefix using this:

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set zz=$$append^VSLTAP("x") do eq^STDASSERT(.pass,.fail,$$present^VSLTAP(1),1,"a committed slot is present") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^XTMP("VSLTAP") do eq^STDASSERT(.pass,.fail,$$present^VSLTAP(99),0,"an absent slot is not present")
```

### `do purgeNode^VSLTAP()`

Write ^XTMP("VSLTAP",0)=purgedate^createdate^description so Kernel XQ82 reaps it.

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do purgeNode^VSLTAP() do eq^STDASSERT(.pass,.fail,$length($get(^XTMP("VSLTAP",0)),"^"),3,"purge node is purgedate^createdate^description") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^VSLTAP,^XTMP("VSLTAP") do purgeNode^VSLTAP() do true^STDASSERT(.pass,.fail,+$piece(^XTMP("VSLTAP",0),"^",1)'<+$piece(^XTMP("VSLTAP",0),"^",2),"purgedate >= createdate (FileMan internal dates)") kill ^VSLTAP,^XTMP("VSLTAP")
```

### `$$read^VSLTAP(seq)`

The verbatim record at `seq`, or "" if absent/overwritten.

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set zz=$$append^VSLTAP("hello") do eq^STDASSERT(.pass,.fail,$$read^VSLTAP(1),"hello","reads back the verbatim record at seq 1") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^XTMP("VSLTAP") do eq^STDASSERT(.pass,.fail,$$read^VSLTAP(99),"","absent seq -> empty string")
```

### `do rearm^VSLTAP()`

Re-arm after a clean cool-down (D-4): clear the disable + close the off-window.

**Example**

```m
kill ^VSLTAP do arm^VSLTAP(),disable^VSLTAP("pressure"),rearm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"","re-arm clears the disable reason") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP(),disable^VSLTAP("pressure"),rearm^VSLTAP() set zz=$$offWindows^VSLTAP(.zo) do true^STDASSERT(.pass,.fail,$piece(zo(1),"^",3)'="","re-arm closes the off-window (sets the close stamp)") kill ^VSLTAP
```

### `do seed^VSLTAP()`

Populate ^VSLTAP("cfg",…) from the installed XPAR #8989.51 params (self-configuring install).

### `$$seedMap^VSLTAP(map)`

Map each installed XPAR param name to the ^VSLTAP("cfg") key the tap reads; return the count.

**Parameters**

- `map` _(array)_ — OUT by-ref: map(i,"param")=XPAR name, map(i,"cfg")=cfg key

**Returns** _numeric_ — the number of param->cfg mappings (the fidelity cadence is read direct)

**Example**

```m
new m do eq^STDASSERT(.pass,.fail,$$seedMap^VSLTAP(.m),9,"nine param->cfg mappings")
new m,n set n=$$seedMap^VSLTAP(.m) do eq^STDASSERT(.pass,.fail,m(1,"param")_"="_m(1,"cfg"),"VSL TAP CAP=cap","first row maps the CAP param to the cap key")
```

### `do setAlwaysOn^VSLTAP(flag)`

LEGACY/SUBSUMED (D-8 -> FU-9): kept for backward compatibility; no longer gates capture.

**Example**

```m
kill ^VSLTAP do setAlwaysOn^VSLTAP(1) do eq^STDASSERT(.pass,.fail,$$cfg^VSLTAP("alwayson",0),1,"the legacy flag is still written/readable") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP(),setAlwaysOn^VSLTAP(0) do eq^STDASSERT(.pass,.fail,$$captureOn^VSLTAP(),1,"SUBSUMED: alwayson=0 no longer gates the always-on ring") kill ^VSLTAP
```

### `do setConsumer^VSLTAP(present)`

Set the consumer-presence flag (D-5): no consumer -> egress/capture OFF.

**Example**

```m
kill ^VSLTAP do arm^VSLTAP(),setConsumer^VSLTAP(1) do eq^STDASSERT(.pass,.fail,$$enabled^VSLTAP(),1,"consumer present -> egress enabled") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP(),setConsumer^VSLTAP(0) do eq^STDASSERT(.pass,.fail,$$enabled^VSLTAP(),0,"no consumer -> egress gated off") kill ^VSLTAP
```

### `$$size^VSLTAP()`

Current ring entry count (head - tail).

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set zz=$$append^VSLTAP("a") do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),1,"one record -> size 1") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^XTMP("VSLTAP") do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"empty ring -> size 0")
```

### `$$state^VSLTAP()`

The standby state-machine label (spec §8.1).

**Returns** _string_ — OFF | AUTO-DISABLED | UNHEALTHY | ACTIVE | ARMED-IDLE

**Example**

```m
kill ^VSLTAP do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"OFF","unconfigured -> OFF")
kill ^VSLTAP do arm^VSLTAP(),heartbeat^VSLTAP(),setConsumer^VSLTAP(1) do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"ACTIVE","armed + healthy + consumer -> ACTIVE") kill ^VSLTAP
kill ^VSLTAP do arm^VSLTAP(),heartbeat^VSLTAP(),disable^VSLTAP("latency") do eq^STDASSERT(.pass,.fail,$$state^VSLTAP(),"AUTO-DISABLED","failover -> AUTO-DISABLED") kill ^VSLTAP
```

### `$$tail^VSLTAP()`

(lowest-retained seq) - 1 (0 if empty).

**Example**

```m
kill ^XTMP("VSLTAP") do eq^STDASSERT(.pass,.fail,$$tail^VSLTAP(),0,"empty ring -> tail 0")
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() set ^VSLTAP("cfg","cap")=2,zz=$$append^VSLTAP("r1"),zz=$$append^VSLTAP("r2"),zz=$$append^VSLTAP("r3"),zz=$$append^VSLTAP("r4") do eq^STDASSERT(.pass,.fail,$$tail^VSLTAP(),2,"cap=2 after 4 appends -> tail advanced to 2 (oldest 2 dropped)") kill ^VSLTAP,^XTMP("VSLTAP")
```

### `$$tee^VSLTAP(rec)`

The named capture seam the VSLRPC chokepoint calls (VSLRPCTAP) — fenced.

**Parameters**

- `rec` _(string)_ — the verbatim payload

**Returns** _bool_ — the $$append result (0 if gated or a fault was fenced)

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$tee^VSLTAP("rec"),1,"tee adapts to $$append -> 1 when armed") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^VSLTAP,^XTMP("VSLTAP") do off^VSLTAP() do eq^STDASSERT(.pass,.fail,$$tee^VSLTAP("rec"),0,"tee returns 0 when gated off") kill ^VSLTAP,^XTMP("VSLTAP")
```

### `$$teeRec^VSLTAP(rec)`

The named rich-record capture seam the FU-5 wrap calls (via VSLRPCTAP) — fenced.

**Parameters**

- `rec` _(array)_ — by-ref record descriptor

**Returns** _bool_ — the $$appendRec result (0 if gated or a fault was fenced)

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") set rec("payload")="b",rec("result_kind")="scalar" do arm^VSLTAP() do eq^STDASSERT(.pass,.fail,$$teeRec^VSLTAP(.rec),1,"teeRec adapts to $$appendRec -> 1 when armed") kill ^VSLTAP,^XTMP("VSLTAP")
kill ^VSLTAP,^XTMP("VSLTAP") set rec("payload")="b" do off^VSLTAP() do eq^STDASSERT(.pass,.fail,$$teeRec^VSLTAP(.rec),0,"teeRec returns 0 when gated off") kill ^VSLTAP,^XTMP("VSLTAP")
```

<!-- END GENERATED API REFERENCE -->
