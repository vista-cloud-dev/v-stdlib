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
| `captureOn` | `$$captureOn^VSLTAP()` | FU-9 (D-6): 1 iff the RING should capture now — armed AND not auto-disabled. |
| `cfg` | `$$cfg^VSLTAP(key, default)` | Read a config knob from ^VSLTAP("cfg",key), else `default`. |
| `disable` | `do disable^VSLTAP(reason)` | Auto-failover: disable the tap, record an off-window (explicit, never silent). |
| `drainTo` | `do drainTo^VSLTAP(seq)` | Post-ship trim: drop retained entries up to and including `seq`, advance tail. |
| `enabled` | `$$enabled^VSLTAP()` | 1 iff EGRESS should run now: capture-on AND a consumer/sink is present (D-5). |
| `hdr` | `$$hdr^VSLTAP(seq, out)` | Parse the v2 header at `seq` into out("schema_version"/...); return 1 iff a v2 record. |
| `hdrLine` | `$$hdrLine^VSLTAP(seq, rec, kind, wl, cc, enc, hash)` | (private) assemble the cache-layout-v2 ^-delimited header. |
| `healthy` | `$$healthy^VSLTAP()` | 1 iff the heartbeat is fresh within the staleness bound (k8s-style liveness). |
| `isV2` | `$$isV2^VSLTAP(seq)` | 1 iff the record at `seq` is a cache-layout-v2 record (a "p" or "g" child present). |
| `offWindows` | `$$offWindows^VSLTAP(out)` | Populate out(1..N) with the recorded off-windows; return the count. |
| `present` | `$$present^VSLTAP(seq)` | 1 iff a data node exists at `seq` ($DATA'=0) — distinguishes an empty-string record from an absent/uncommitted slot. |
| `purgeNode` | `do purgeNode^VSLTAP()` | Write ^XTMP("VSLTAP",0)=purgedate^createdate^description so Kernel XQ82 reaps it. |
| `seed` | `do seed^VSLTAP()` | Populate ^VSLTAP("cfg",…) from the installed XPAR #8989.51 params (self-configuring install). |
| `seedMap` | `$$seedMap^VSLTAP(map)` | Map each installed XPAR param name to the ^VSLTAP("cfg") key the tap reads; return the count. |
| `setAlwaysOn` | `do setAlwaysOn^VSLTAP(flag)` | LEGACY/SUBSUMED (D-8 -> FU-9): kept for backward compatibility; no longer gates capture. |
| `state` | `$$state^VSLTAP()` | The standby state-machine label (spec §8.1). |
| `tee` | `$$tee^VSLTAP(rec)` | The named capture seam the VSLRPC chokepoint calls (VSLRPCTAP) — fenced. |
| `teeRec` | `$$teeRec^VSLTAP(rec)` | The named rich-record capture seam the FU-5 wrap calls (via VSLRPCTAP) — fenced. |
| `write1` | `do write1^VSLTAP(rec, wrote)` | (private) the ring write, DO-invoked so the append fence's QUIT is legal. |
| `write1rec` | `do write1rec^VSLTAP(rec, wrote)` | (private) write one cache-layout-v2 record, DO-invoked so the fence's QUIT is legal. |

### `$$append^VSLTAP(rec)`

Gated, fault-fenced, bounded memory-copy append of a verbatim record.

**Parameters**

- `rec` _(string)_ — the verbatim payload (no parse, no transform — D-1)

**Returns** _bool_ — 1 iff captured; 0 iff gated, auto-disabled, copy-cost-tripped, or fenced

### `$$appendRec^VSLTAP(rec)`

FU-5: gated, fault-fenced, bounded append of a RICH (cache layout v2) record.

**Parameters**

- `rec` _(array)_ — by-ref record descriptor (dir/rpc/payload/gref/call_id/...; read-only)

**Returns** _bool_ — 1 iff captured; 0 iff gated, auto-disabled, copy-cost-tripped, or fenced

### `$$captureOn^VSLTAP()`

FU-9 (D-6): 1 iff the RING should capture now — armed AND not auto-disabled.

**Returns** _bool_ — the ALWAYS-ON capture gate. The ring records whenever the tap

### `$$cfg^VSLTAP(key, default)`

Read a config knob from ^VSLTAP("cfg",key), else `default`.

**Parameters**

- `key` _(string)_ — config key (mode/consumer/alwayson/cap/maxbytes/latbound/hbstale/retain)
- `default` _(string)_ — value when unset

**Returns** _string_ — the configured value or the default

### `do disable^VSLTAP(reason)`

Auto-failover: disable the tap, record an off-window (explicit, never silent).

**Parameters**

- `reason` _(string)_ — the interference signal (fault/copycost/latency/pressure)

### `do drainTo^VSLTAP(seq)`

Post-ship trim: drop retained entries up to and including `seq`, advance tail.

**Parameters**

- `seq` _(numeric)_ — the highest shipped sequence (bounded to head)

**Returns** _void_ — the drain self-KILLs shipped entries (spec §4.1.3)

### `$$enabled^VSLTAP()`

1 iff EGRESS should run now: capture-on AND a consumer/sink is present (D-5).

**Returns** _bool_ — the EGRESS gate. The drain ships and $$state reports ACTIVE only

### `$$hdr^VSLTAP(seq, out)`

Parse the v2 header at `seq` into out("schema_version"/...); return 1 iff a v2 record.

**Parameters**

- `seq` _(numeric)_ — the ring sequence
- `out` _(array)_ — OUT by-ref: the 18 header fields keyed by their schema-v1 names

**Returns** _bool_ — 1 iff `seq` is a v2 record (else `out` is killed, returns 0)

### `$$hdrLine^VSLTAP(seq, rec, kind, wl, cc, enc, hash)`

(private) assemble the cache-layout-v2 ^-delimited header.

### `$$healthy^VSLTAP()`

1 iff the heartbeat is fresh within the staleness bound (k8s-style liveness).

**Returns** _bool_ — a stale/absent heartbeat -> 0 (UNHEALTHY) even with zero traffic

### `$$isV2^VSLTAP(seq)`

1 iff the record at `seq` is a cache-layout-v2 record (a "p" or "g" child present).

### `$$offWindows^VSLTAP(out)`

Populate out(1..N) with the recorded off-windows; return the count.

**Parameters**

- `out` _(array)_ — by-ref; killed then filled with open^reason^close rows

### `$$present^VSLTAP(seq)`

1 iff a data node exists at `seq` ($DATA'=0) — distinguishes an empty-string record from an absent/uncommitted slot.

**Returns** _bool_ — The drain ships only the CONTIGUOUS COMMITTED prefix using this:

### `do purgeNode^VSLTAP()`

Write ^XTMP("VSLTAP",0)=purgedate^createdate^description so Kernel XQ82 reaps it.

### `do seed^VSLTAP()`

Populate ^VSLTAP("cfg",…) from the installed XPAR #8989.51 params (self-configuring install).

### `$$seedMap^VSLTAP(map)`

Map each installed XPAR param name to the ^VSLTAP("cfg") key the tap reads; return the count.

**Parameters**

- `map` _(array)_ — OUT by-ref: map(i,"param")=XPAR name, map(i,"cfg")=cfg key

**Returns** _numeric_ — the number of param->cfg mappings (the fidelity cadence is read direct)

### `do setAlwaysOn^VSLTAP(flag)`

LEGACY/SUBSUMED (D-8 -> FU-9): kept for backward compatibility; no longer gates capture.

### `$$state^VSLTAP()`

The standby state-machine label (spec §8.1).

**Returns** _string_ — OFF | AUTO-DISABLED | UNHEALTHY | ACTIVE | ARMED-IDLE

### `$$tee^VSLTAP(rec)`

The named capture seam the VSLRPC chokepoint calls (VSLRPCTAP) — fenced.

**Parameters**

- `rec` _(string)_ — the verbatim payload

**Returns** _bool_ — the $$append result (0 if gated or a fault was fenced)

### `$$teeRec^VSLTAP(rec)`

The named rich-record capture seam the FU-5 wrap calls (via VSLRPCTAP) — fenced.

**Parameters**

- `rec` _(array)_ — by-ref record descriptor

**Returns** _bool_ — the $$appendRec result (0 if gated or a fault was fenced)

### `do write1^VSLTAP(rec, wrote)`

(private) the ring write, DO-invoked so the append fence's QUIT is legal.

**Parameters**

- `rec` _(string)_ — the verbatim payload
- `wrote` _(bool)_ — by-ref; set 1 iff the record was appended

### `do write1rec^VSLTAP(rec, wrote)`

(private) write one cache-layout-v2 record, DO-invoked so the fence's QUIT is legal.

**Parameters**

- `rec` _(array)_ — by-ref record descriptor (read-only)
- `wrote` _(bool)_ — by-ref; set 1 iff the record was appended

<!-- END GENERATED API REFERENCE -->
