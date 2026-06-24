---
module: VSLTAPBO
layer: v
since: 
stable: stable
synopsis: 'traffic-tap back-out / verify-clean (the G-UNINST gate)'
labels: ['backout', 'cleanParams', 'cleanState', 'cleanTasks', 'delParam', 'dequeue', 'params', 'paramsResidue', 'verifyClean']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLTAPBO` — traffic-tap back-out / verify-clean (the G-UNINST gate)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `backout` | `do backout^VSLTAPBO()` | Full back-out: dequeue tasks, drop the XPAR params, kill the state. Idempotent. |
| `cleanParams` | `do cleanParams^VSLTAPBO()` | Drop every tap XPAR param: clear the SYS instance, delete the #8989.51 definition. |
| `cleanState` | `do cleanState^VSLTAPBO()` | Kill the rolling capture cache and ALL VSL control state. |
| `cleanTasks` | `do cleanTasks^VSLTAPBO()` | Dequeue every recorded flush/fidelity TaskMan job (read BEFORE cleanState). |
| `delParam` | `do delParam^VSLTAPBO(name)` | (private) clear the SYS-level instance, then delete the #8989.51 definition record. |
| `dequeue` | `do dequeue^VSLTAPBO(ztsk)` | (private) unschedule task `ztsk` via the Kernel ZTLOAD programmer API. Fenced. |
| `params` | `$$params^VSLTAPBO(out)` | Fill out(1..N) with the tap's XPAR #8989.51 param names; return N. |
| `paramsResidue` | `$$paramsResidue^VSLTAPBO(detail)` | (private) 1 iff any tap #8989.51 definition survives (fenced; bare -> 0). |
| `verifyClean` | `$$verifyClean^VSLTAPBO(detail)` | 1 iff no tap residue remains across all layers; detail() names any survivor. |

### `do backout^VSLTAPBO()`

Full back-out: dequeue tasks, drop the XPAR params, kill the state. Idempotent.

### `do cleanParams^VSLTAPBO()`

Drop every tap XPAR param: clear the SYS instance, delete the #8989.51 definition.

### `do cleanState^VSLTAPBO()`

Kill the rolling capture cache and ALL VSL control state.

### `do cleanTasks^VSLTAPBO()`

Dequeue every recorded flush/fidelity TaskMan job (read BEFORE cleanState).

### `do delParam^VSLTAPBO(name)`

(private) clear the SYS-level instance, then delete the #8989.51 definition record.

**Parameters**

- `name` _(string)_ — the XPAR parameter name (#8989.51 .01)

### `do dequeue^VSLTAPBO(ztsk)`

(private) unschedule task `ztsk` via the Kernel ZTLOAD programmer API. Fenced.

**Parameters**

- `ztsk` _(numeric)_ — the task number to remove from the schedule

### `$$params^VSLTAPBO(out)`

Fill out(1..N) with the tap's XPAR #8989.51 param names; return N.

**Parameters**

- `out` _(array)_ — by-ref; killed then filled out(1)=name … out(N)=name

**Returns** _numeric_ — the count of tap params (the KIDS build + the back-out share this list)

### `$$paramsResidue^VSLTAPBO(detail)`

(private) 1 iff any tap #8989.51 definition survives (fenced; bare -> 0).

### `$$verifyClean^VSLTAPBO(detail)`

1 iff no tap residue remains across all layers; detail() names any survivor.

**Parameters**

- `detail` _(array)_ — OUT by-ref; killed then filled detail(globals/params/tasks)

**Returns** _bool_ — 1 iff globals, XPAR params and tasks are all clean

<!-- END GENERATED API REFERENCE -->
