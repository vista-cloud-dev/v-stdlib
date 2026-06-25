---
module: VSLTAPRUN
layer: v
since: 
stable: stable
synopsis: 'the periodic fidelity-run task (closes the console loop)'
labels: ['cadence', 'fidelityNow', 'nextKey', 'reconcilePersist', 'run', 'schedule']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLTAPRUN` — the periodic fidelity-run task (closes the console loop)

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `cadence` | `$$cadence^VSLTAPRUN()` | The fidelity-run period in seconds: XPAR VSL TAP FIDELITY CADENCE, default 3600. |
| `fidelityNow` | `$$fidelityNow^VSLTAPRUN()` | Sample recently-shipped objects, confirm each reads back as a well-formed envelope, persist the result -> count. |
| `nextKey` | `do nextKey^VSLTAPRUN(k, seen, listing, ctx, bucket, opt, res)` | (private) step to the previous listed subscript; verify its object if it's a real key. |
| `reconcilePersist` | `$$reconcilePersist^VSLTAPRUN(corpus, envs)` | Reconcile the corpus vs the read-back envelopes, persist the result, return ok. |
| `run` | `do run^VSLTAPRUN()` | The scheduled task body: gate -> sample+persist -> re-queue. Fenced (never aborts TaskMan). |
| `schedule` | `$$schedule^VSLTAPRUN()` | Queue run^VSLTAPRUN at now+cadence; record the task# (so back-out can dequeue it); return it. |

### `$$cadence^VSLTAPRUN()`

The fidelity-run period in seconds: XPAR VSL TAP FIDELITY CADENCE, default 3600.

**Returns** _numeric_ — a positive number of seconds between fidelity runs

**Example**

```m
write $$cadence^VSLTAPRUN()  ; 3600
```

### `$$fidelityNow^VSLTAPRUN()`

Sample recently-shipped objects, confirm each reads back as a well-formed envelope, persist the result -> count.

**Returns** _numeric_ — the count of shipped objects that read back as well-formed
schema-v1 envelopes; -1 if no egress / nothing sampled

**Example**

```m
write $$fidelityNow^VSLTAPRUN()  ; -1
```

### `do nextKey^VSLTAPRUN(k, seen, listing, ctx, bucket, opt, res)`

(private) step to the previous listed subscript; verify its object if it's a real key.

### `$$reconcilePersist^VSLTAPRUN(corpus, envs)`

Reconcile the corpus vs the read-back envelopes, persist the result, return ok.

**Parameters**

- `corpus` _(array)_ — by-ref: corpus(seq) = the source record
- `envs` _(array)_ — by-ref: envs(seq)   = the read-back envelope line

**Returns** _bool_ — 1 iff the sample reconciles byte-perfect (ok=true persisted)

**Example**

```m
new corpus,envs,rec,opt,save set save=$get(^VSLTAP("fc","last")) set rec("direction")="resp",rec("call_id")="500-1-1",rec("seq")=1,rec("payload")="hello world",corpus(1)="hello world",envs(1)=$$envelope^VSLS3(.rec,.opt) do eq^STDASSERT(.pass,.fail,$$reconcilePersist^VSLTAPRUN(.corpus,.envs),1,"a byte-perfect 1-record sample reconciles ok=true") set ^VSLTAP("fc","last")=save
```

### `do run^VSLTAPRUN()`

The scheduled task body: gate -> sample+persist -> re-queue. Fenced (never aborts TaskMan).

**Example**

```m
new save set save=$get(^VSLTAP("fc","last")) do off^VSLTAP() set ^VSLTAP("fc","last")="{""sentinel"":1}" do run^VSLTAPRUN() do eq^STDASSERT(.pass,.fail,$$lastFidelity^VSLTAPFC(),"{""sentinel"":1}","a disabled tap skips the live work and leaves the last result untouched") set ^VSLTAP("fc","last")=save
```

### `$$schedule^VSLTAPRUN()`

Queue run^VSLTAPRUN at now+cadence; record the task# (so back-out can dequeue it); return it.

**Returns** _numeric_ — the queued task number, or 0 when there is no TaskMan (bare/no-queue)

**Example**

```m
write $$schedule^VSLTAPRUN()  ; 0
```

<!-- END GENERATED API REFERENCE -->
