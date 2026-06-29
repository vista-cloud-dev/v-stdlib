---
module: VSLTASK
layer: v
since: 
stable: stable
synopsis: 'VistA TaskMan persistent-listener adapter (the process seam)'
labels: ['lastError', 'persist', 'queue', 'running', 'schedule', 'stop']
errors: ['U-VSL-TASK-ARG', 'U-VSL-TASK-QUEUE']
see_also: []
doc_type: [REFERENCE]
---

# `VSLTASK` — VistA TaskMan persistent-listener adapter (the process seam)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `lastError` | `$$lastError^VSLTASK()` | The last VSLTASK error message (the composed malformed-call / fault detail). |
| `persist` | `$$persist^VSLTASK(ztsk)` | Mark queued task `ztsk` persistent so TaskMan self-restarts it on a lock drop. |
| `queue` | `$$queue^VSLTASK(entry, desc, when)` | (private) headless ^%ZTLOAD queue (no device); return the task number, else 0. |
| `running` | `$$running^VSLTASK()` | 1 iff the TaskMan scheduler is live (its ^%ZTSCH("RUN") heartbeat is fresh). |
| `schedule` | `$$schedule^VSLTASK(entry, desc, when)` | Headless-queue a persistent listener at `entry`; return its task number. |
| `stop` | `$$stop^VSLTASK()` | 1 iff a stop has been requested of the currently-running task (cooperative stop). |

### `$$lastError^VSLTASK()`

The last VSLTASK error message (the composed malformed-call / fault detail).

**Returns** _string_ — ^TMP($job,"vsltask","err"), or "" if none

### `$$persist^VSLTASK(ztsk)`

Mark queued task `ztsk` persistent so TaskMan self-restarts it on a lock drop.

**Parameters**

- `ztsk` _(numeric)_ — the task number (from $$schedule / ^%ZTLOAD)

**Returns** _bool_ — 1 iff the task was marked persistent, else 0 (task not queued)

**Raises**

- `U-VSL-TASK-ARG` — the call is malformed (no positive task number)

**Example**

```m
do raises^STDASSERT(.pass,.fail,"set x=$$persist^VSLTASK("""")","U-VSL-TASK-ARG","$$persist with no task# raises U-VSL-TASK-ARG")
```

### `$$queue^VSLTASK(entry, desc, when)`

(private) headless ^%ZTLOAD queue (no device); return the task number, else 0.

### `$$running^VSLTASK()`

1 iff the TaskMan scheduler is live (its ^%ZTSCH("RUN") heartbeat is fresh).

**Returns** _bool_ — 1 iff TaskMan is running (the self-heal precondition); 0 otherwise

**Example**

```m
do true^STDASSERT(.pass,.fail,($$running^VSLTASK()=0)!($$running^VSLTASK()=1),"$$running returns a clean boolean (resolves $$TM^%ZTLOAD)")
```

### `$$schedule^VSLTASK(entry, desc, when)`

Headless-queue a persistent listener at `entry`; return its task number.

**Parameters**

- `entry` _(string)_ — the task entry reference (TAG^ROUTINE)
- `desc` _(string)_ — a human description (optional)
- `when` _(string)_ — TaskMan ZTDTH start time (optional; default
$HOROLOG = run now). A full $H value (`days,secs`, e.g. $HOROLOG), not a
bare day number. NOTE: ZTDTH "@" means do NOT schedule (defer for later
manual scheduling) — it is NOT "ASAP"; omit `when` (or pass $HOROLOG) to
run a persistent listener now.

**Returns** _numeric_ — the queued task number

**Raises**

- `U-VSL-TASK-ARG` — no entry reference supplied
- `U-VSL-TASK-QUEUE` — the TaskMan queue / persist failed

**Example**

```m
do raises^STDASSERT(.pass,.fail,"set x=$$schedule^VSLTASK("""",""ZZ"")","U-VSL-TASK-ARG","$$schedule with no entry raises U-VSL-TASK-ARG")
```

### `$$stop^VSLTASK()`

1 iff a stop has been requested of the currently-running task (cooperative stop).

**Returns** _bool_ — 1 iff the listener loop should stop; 0 when not in a task / no stop pending

**Example**

```m
do true^STDASSERT(.pass,.fail,$$stop^VSLTASK()=0,"$$stop=0 when not running as a TaskMan task (the cooperative-stop check)")
```

<!-- END GENERATED API REFERENCE -->
