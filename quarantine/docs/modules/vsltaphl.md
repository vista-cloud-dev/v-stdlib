---
module: VSLTAPHL
layer: v
since: 
stable: stable
synopsis: 'tap health instrument + standby readiness (the watchdog)'
labels: ['abcheck', 'canary', 'pctl', 'ready', 'record']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLTAPHL` — tap health instrument + standby readiness (the watchdog)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `abcheck` | `$$abcheck^VSLTAPHL(base, tapped)` | 1 iff (tapped - base) exceeds the pre-registered D-7 latency bound. |
| `canary` | `$$canary^VSLTAPHL()` | Synthetic byte-exact round-trip of a tagged record through ^XTMP — touches no real RPC. |
| `pctl` | `$$pctl^VSLTAPHL(p)` | The p-th percentile (nearest-rank) of the latency-sample window; 0 if none. |
| `ready` | `$$ready^VSLTAPHL()` | Standby readiness probe: 1 iff a gated/idle tap COULD capture if a consumer appeared. |
| `record` | `do record^VSLTAPHL(us, bytes, denied)` | Record one capture sample: a denial, or a write (+bytes, +optional latency). |
| `watchLatency` | `do watchLatency^VSLTAPHL(base, tapped)` | Trip auto-failover OFF when the tapped-vs-baseline delta breaches the bound. |

### `$$abcheck^VSLTAPHL(base, tapped)`

1 iff (tapped - base) exceeds the pre-registered D-7 latency bound.

**Parameters**

- `base` _(numeric)_ — baseline (tap OFF) latency
- `tapped` _(numeric)_ — tapped (tap ON) latency

**Returns** _bool_ — the exact signal the §6.2 watchdog trips on

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") set ^VSLTAP("cfg","latbound")=100 do eq^STDASSERT(.pass,.fail,$$abcheck^VSLTAPHL(10,60),0,"tapped-base=50 <= 100 bound -> clean")
kill ^VSLTAP,^XTMP("VSLTAP") set ^VSLTAP("cfg","latbound")=100 do eq^STDASSERT(.pass,.fail,$$abcheck^VSLTAPHL(10,510),1,"tapped-base=500 > 100 bound -> trip")
```

### `$$canary^VSLTAPHL()`

Synthetic byte-exact round-trip of a tagged record through ^XTMP — touches no real RPC.

**Returns** _bool_ — 1 iff the capture substrate round-trips byte-exact on standby

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),beat^VSLTAPHL() do true^STDASSERT(.pass,.fail,$$canary^VSLTAPHL()=1,"canary proves capture-substrate works on standby (byte-exact round-trip)")
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),beat^VSLTAPHL() set %=$$canary^VSLTAPHL() do eq^STDASSERT(.pass,.fail,$$size^VSLTAP(),0,"the canary leaves the real ring empty (no clinical-traffic perturbation)")
```

### `$$pctl^VSLTAPHL(p)`

The p-th percentile (nearest-rank) of the latency-sample window; 0 if none.

**Parameters**

- `p` _(numeric)_ — percentile 0..100

**Returns** _numeric_ — the nearest-rank sample value

**Example**

```m
new i kill ^VSLTAP,^XTMP("VSLTAP") for i=1:1:100 do record^VSLTAPHL(i,1,0)  do true^STDASSERT(.pass,.fail,($$pctl^VSLTAPHL(50)'<1)&($$pctl^VSLTAPHL(50)'>100),"p50 of 1..100 falls within [1,100]")
new i kill ^VSLTAP,^XTMP("VSLTAP") for i=1:1:100 do record^VSLTAPHL(i,1,0)  do true^STDASSERT(.pass,.fail,$$pctl^VSLTAPHL(95)'<$$pctl^VSLTAPHL(50),"p95 >= p50 (percentiles are monotonic)")
```

### `$$ready^VSLTAPHL()`

Standby readiness probe: 1 iff a gated/idle tap COULD capture if a consumer appeared.

**Returns** _bool_ — checks (1) armed (2) not auto-disabled (3) heartbeat fresh

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),beat^VSLTAPHL() do true^STDASSERT(.pass,.fail,$$ready^VSLTAPHL()=1,"readiness probe green while idle (substrate writable, fence armed, heartbeat fresh)")
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),beat^VSLTAPHL() set ^VSLTAP("hb")=0 do true^STDASSERT(.pass,.fail,$$ready^VSLTAPHL()=0,"a stale heartbeat flips readiness red even with zero traffic")
```

### `do record^VSLTAPHL(us, bytes, denied)`

Record one capture sample: a denial, or a write (+bytes, +optional latency).

**Parameters**

- `us` _(numeric)_ — capture latency in microseconds (0 -> no latency sample)
- `bytes` _(numeric)_ — bytes copied into the buffer
- `denied` _(bool)_ — 1 iff the consumer-gate denied this capture (no write)

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do record^VSLTAPHL(120,50,0),record^VSLTAPHL(80,40,0),record^VSLTAPHL(0,0,1) do eq^STDASSERT(.pass,.fail,$$writes^VSLTAPHL(),2,"two capture writes counted (the denied sample is not a write)")
kill ^VSLTAP,^XTMP("VSLTAP") do record^VSLTAPHL(120,50,0),record^VSLTAPHL(80,40,0) do eq^STDASSERT(.pass,.fail,$$bytes^VSLTAPHL(),90,"bytes-to-buffer summed across writes")
kill ^VSLTAP,^XTMP("VSLTAP") do record^VSLTAPHL(0,0,1) do eq^STDASSERT(.pass,.fail,$$denied^VSLTAPHL(),1,"one consumer-gate denial counted")
```

### `do watchLatency^VSLTAPHL(base, tapped)`

Trip auto-failover OFF when the tapped-vs-baseline delta breaches the bound.

**Parameters**

- `base` _(numeric)_ — baseline (tap OFF) latency
- `tapped` _(numeric)_ — tapped (tap ON) latency

**Example**

```m
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),setConsumer^VSLTAP(1) set ^VSLTAP("cfg","latbound")=100 do watchLatency^VSLTAPHL(10,10) do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"","a within-bound sample does not disable the tap")
kill ^VSLTAP,^XTMP("VSLTAP") do arm^VSLTAP(),setConsumer^VSLTAP(1) set ^VSLTAP("cfg","latbound")=100 do watchLatency^VSLTAPHL(10,500) do eq^STDASSERT(.pass,.fail,$$disabled^VSLTAP(),"latency","an over-bound sample self-disables with reason latency")
```

<!-- END GENERATED API REFERENCE -->
