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

### `$$abcheck^VSLTAPHL(base, tapped)`

1 iff (tapped - base) exceeds the pre-registered D-7 latency bound.

**Parameters**

- `base` _(numeric)_ — baseline (tap OFF) latency
- `tapped` _(numeric)_ — tapped (tap ON) latency

**Returns** _bool_ — the exact signal the §6.2 watchdog trips on

### `$$canary^VSLTAPHL()`

Synthetic byte-exact round-trip of a tagged record through ^XTMP — touches no real RPC.

**Returns** _bool_ — 1 iff the capture substrate round-trips byte-exact on standby

### `$$pctl^VSLTAPHL(p)`

The p-th percentile (nearest-rank) of the latency-sample window; 0 if none.

**Parameters**

- `p` _(numeric)_ — percentile 0..100

**Returns** _numeric_ — the nearest-rank sample value

### `$$ready^VSLTAPHL()`

Standby readiness probe: 1 iff a gated/idle tap COULD capture if a consumer appeared.

**Returns** _bool_ — checks (1) armed (2) not auto-disabled (3) heartbeat fresh

### `do record^VSLTAPHL(us, bytes, denied)`

Record one capture sample: a denial, or a write (+bytes, +optional latency).

**Parameters**

- `us` _(numeric)_ — capture latency in microseconds (0 -> no latency sample)
- `bytes` _(numeric)_ — bytes copied into the buffer
- `denied` _(bool)_ — 1 iff the consumer-gate denied this capture (no write)

<!-- END GENERATED API REFERENCE -->
