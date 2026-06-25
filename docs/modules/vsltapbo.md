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
| `cleanTasks` | `do cleanTasks^VSLTAPBO()` | Dequeue every recorded TaskMan job (read BEFORE cleanState). |
| `delParam` | `do delParam^VSLTAPBO(name)` | (private) clear the SYS-level instance, then delete the #8989.51 definition record. |
| `dequeue` | `do dequeue^VSLTAPBO(ztsk)` | (private) unschedule task `ztsk` via the Kernel ZTLOAD programmer API. Fenced. |
| `params` | `$$params^VSLTAPBO(out)` | Fill out(1..N) with the tap's XPAR #8989.51 param names; return N. |
| `paramsResidue` | `$$paramsResidue^VSLTAPBO(detail)` | (private) 1 iff any tap #8989.51 definition survives (fenced; bare -> 0). |
| `verifyClean` | `$$verifyClean^VSLTAPBO(detail)` | 1 iff no tap residue remains across all layers; detail() names any survivor. |

### `do backout^VSLTAPBO()`

Full back-out: dequeue tasks, drop the XPAR params, kill the state. Idempotent.

**Example**

```m
set ^XTMP("VSLTAP","data",1)="rec",^VSLTAP("hb")=$horolog do backout^VSLTAPBO() do true^STDASSERT(.pass,.fail,$$verifyClean^VSLTAPBO(.detail),"backout: a seeded footprint verifies clean afterward")
```

### `do cleanParams^VSLTAPBO()`

Drop every tap XPAR param: clear the SYS instance, delete the #8989.51 definition.

**Example**

```m
do cleanParams^VSLTAPBO() do true^STDASSERT(.pass,.fail,1,"cleanParams: the fenced XPAR leg returns without raising on a bare engine")
```

### `do cleanState^VSLTAPBO()`

Kill the rolling capture cache and ALL VSL control state.

**Example**

```m
set ^VSLTAP("cfg","mode")="armed",^XTMP("VSLTAP","data",1)="x" do cleanState^VSLTAPBO() do eq^STDASSERT(.pass,.fail,$data(^VSLTAP)+$data(^XTMP("VSLTAP")),0,"cleanState: both the cache and the control state are gone")
```

### `do cleanTasks^VSLTAPBO()`

Dequeue every recorded TaskMan job (read BEFORE cleanState).

**Example**

```m
do cleanTasks^VSLTAPBO() do true^STDASSERT(.pass,.fail,1,"cleanTasks: the fenced TaskMan leg returns without raising on a bare engine")
```

### `do delParam^VSLTAPBO(name)`

(private) clear the SYS-level instance, then delete the #8989.51 definition record.

**Parameters**

- `name` _(string)_ — the XPAR parameter name (#8989.51 .01)

**Example**

```m
do delParam^VSLTAPBO("VSL TAP CAP") do true^STDASSERT(.pass,.fail,1,"delParam: a not-present param is a clean no-op (fenced) on a bare engine")
```

### `do dequeue^VSLTAPBO(ztsk)`

(private) unschedule task `ztsk` via the Kernel ZTLOAD programmer API. Fenced.

**Parameters**

- `ztsk` _(numeric)_ — the task number to remove from the schedule

**Example**

```m
do dequeue^VSLTAPBO(0) do true^STDASSERT(.pass,.fail,1,"dequeue: a non-positive task number is a clean no-op")
```

### `$$params^VSLTAPBO(out)`

Fill out(1..N) with the tap's XPAR #8989.51 param names; return N.

**Parameters**

- `out` _(array)_ — by-ref; killed then filled out(1)=name … out(N)=name

**Returns** _numeric_ — the count of tap params (the KIDS build + the back-out share this list)

**Example**

```m
do true^STDASSERT(.pass,.fail,$$params^VSLTAPBO(.out)>0,"params: the tap ships at least one XPAR param")
new out do eq^STDASSERT(.pass,.fail,$$params^VSLTAPBO(.out)_"|"_out(7),"10|VSL S3 ENDPOINT","params: 10 knobs, the 7th is the S3 endpoint")
```

### `$$paramsResidue^VSLTAPBO(detail)`

(private) 1 iff any tap #8989.51 definition survives (fenced; bare -> 0).

**Example**

```m
do eq^STDASSERT(.pass,.fail,$$paramsResidue^VSLTAPBO(.detail),0,"paramsResidue: a bare engine (no FileMan) reports no surviving XPAR definitions")
```

### `$$verifyClean^VSLTAPBO(detail)`

1 iff no tap residue remains across all layers; detail() names any survivor.

**Parameters**

- `detail` _(array)_ — OUT by-ref; killed then filled detail(globals/params/tasks)

**Returns** _bool_ — 1 iff globals, XPAR params and tasks are all clean

**Example**

```m
kill ^XTMP("VSLTAP"),^VSLTAP do true^STDASSERT(.pass,.fail,$$verifyClean^VSLTAPBO(.detail),"verifyClean: an empty system verifies clean")
```

<!-- END GENERATED API REFERENCE -->
