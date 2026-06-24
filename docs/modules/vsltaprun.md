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
| `fidelityNow` | `$$fidelityNow^VSLTAPRUN()` | Sample recently-shipped objects, integrity-verify each, persist the result -> matched count. |
| `nextKey` | `do nextKey^VSLTAPRUN(k, seen, listing, ctx, bucket, opt, res)` | (private) step to the previous listed subscript; verify its object if it's a real key. |
| `reconcilePersist` | `$$reconcilePersist^VSLTAPRUN(corpus, envs)` | Reconcile the corpus vs the read-back envelopes, persist the result, return ok. |
| `run` | `do run^VSLTAPRUN()` | The scheduled task body: gate -> sample+persist -> re-queue. Fenced (never aborts TaskMan). |
| `schedule` | `$$schedule^VSLTAPRUN()` | Queue run^VSLTAPRUN at now+cadence; record the task# (so back-out can dequeue it); return it. |

### `$$cadence^VSLTAPRUN()`

The fidelity-run period in seconds: XPAR VSL TAP FIDELITY CADENCE, default 3600.

**Returns** _numeric_ — a positive number of seconds between fidelity runs

### `$$fidelityNow^VSLTAPRUN()`

Sample recently-shipped objects, integrity-verify each, persist the result -> matched count.

**Returns** _numeric_ — the count of shipped envelopes whose payload re-hashes to its
sha256 anchor (round-trip integrity match); -1 if no egress / nothing sampled

### `do nextKey^VSLTAPRUN(k, seen, listing, ctx, bucket, opt, res)`

(private) step to the previous listed subscript; verify its object if it's a real key.

### `$$reconcilePersist^VSLTAPRUN(corpus, envs)`

Reconcile the corpus vs the read-back envelopes, persist the result, return ok.

**Parameters**

- `corpus` _(array)_ — by-ref: corpus(seq) = the source record
- `envs` _(array)_ — by-ref: envs(seq)   = the read-back envelope line

**Returns** _bool_ — 1 iff the sample reconciles byte-perfect (ok=true persisted)

### `do run^VSLTAPRUN()`

The scheduled task body: gate -> sample+persist -> re-queue. Fenced (never aborts TaskMan).

### `$$schedule^VSLTAPRUN()`

Queue run^VSLTAPRUN at now+cadence; record the task# (so back-out can dequeue it); return it.

**Returns** _numeric_ — the queued task number, or 0 when there is no TaskMan (bare/no-queue)

<!-- END GENERATED API REFERENCE -->
