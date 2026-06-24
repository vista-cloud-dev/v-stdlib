---
module: VSLTAPFC
layer: v
since: 
stable: stable
synopsis: 'fidelity comparator: byte-equality proof, not assertion'
labels: ['drops', 'lastFidelity', 'manifest', 'matches', 'payloadOf', 'persist', 'reconcile', 'verify']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLTAPFC` — fidelity comparator: byte-equality proof, not assertion

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `drops` | `$$drops^VSLTAPFC(envs, res)` | Classify the loss taxonomy by grouping the shipped envelopes on call_id (FU-15). |
| `lastFidelity` | `$$lastFidelity^VSLTAPFC()` | The last persisted _fidelity manifest line, or "" when no run has run yet. |
| `manifest` | `$$manifest^VSLTAPFC(res, ts)` | Serialise a fidelity run to a single JSON manifest line (the _fidelity object). |
| `matches` | `$$matches^VSLTAPFC(line, source)` | 1 iff the decoded payload byte-equals `source` AND the hash anchor is intact. |
| `payloadOf` | `$$payloadOf^VSLTAPFC(line)` | Decode one LDJSON envelope line back to the verbatim captured bytes. |
| `persist` | `do persist^VSLTAPFC(res, ts)` | Store the last fidelity run so the console can read it (no live run on request). |
| `reconcile` | `$$reconcile^VSLTAPFC(corpus, envs, res)` | Reconcile a generated corpus against the read-back envelopes, by sequence. |
| `verify` | `$$verify^VSLTAPFC(line)` | 1 iff the envelope's payload re-hashes to the sha256 anchor it carries (§7). |

### `$$drops^VSLTAPFC(envs, res)`

Classify the loss taxonomy by grouping the shipped envelopes on call_id (FU-15).

**Parameters**

- `envs` _(array)_ — by-ref: envs(k) = one shipped schema-v1 envelope line (any key)
- `res` _(array)_ — OUT by-ref: res("rpc_error")/res("rpc_denied") counts

**Returns** _int_ — the total number of accounted drops (rpc_error + rpc_denied)

### `$$lastFidelity^VSLTAPFC()`

The last persisted _fidelity manifest line, or "" when no run has run yet.

**Returns** _string_ — the JSON manifest stored by persist, or "" (console: "pending")

### `$$manifest^VSLTAPFC(res, ts)`

Serialise a fidelity run to a single JSON manifest line (the _fidelity object).

**Parameters**

- `res` _(array)_ — by-ref: res("matched"/"mismatch"/"missing"/"extra")
- `ts` _(string)_ — capture timestamp (default $H)

**Returns** _string_ — one RFC-8259 JSON object summarising the run

### `$$matches^VSLTAPFC(line, source)`

1 iff the decoded payload byte-equals `source` AND the hash anchor is intact.

**Parameters**

- `line` _(string)_ — one VSLS3 envelope line
- `source` _(byte-string)_ — the captured source record (the tee, the #772 message)

**Returns** _bool_ — the byte-equality proof (RPC tee-vs-mirror; HL7 vs #772)

### `$$payloadOf^VSLTAPFC(line)`

Decode one LDJSON envelope line back to the verbatim captured bytes.

**Parameters**

- `line` _(string)_ — one VSLS3 schema-v1 envelope line (raw or base64 payload)

**Returns** _byte-string_ — the raw payload, byte-exact (escaping/base64 reversed)

### `do persist^VSLTAPFC(res, ts)`

Store the last fidelity run so the console can read it (no live run on request).

**Parameters**

- `res` _(array)_ — by-ref: res("matched"/"mismatch"/"missing"/"extra")
- `ts` _(string)_ — capture timestamp (default $H)

**Returns** _void_ — writes the manifest line to ^VSLTAP("fc","last")

### `$$reconcile^VSLTAPFC(corpus, envs, res)`

Reconcile a generated corpus against the read-back envelopes, by sequence.

**Parameters**

- `corpus` _(array)_ — by-ref: corpus(seq) = the generated verbatim record
- `envs` _(array)_ — by-ref: envs(seq)   = the read-back envelope line
- `res` _(array)_ — OUT by-ref: res("matched"/"mismatch"/"missing"/"extra")

**Returns** _bool_ — 1 iff EVERY corpus record is present exactly once,
byte-equal + hash-matched, with no missing and no extra

### `$$verify^VSLTAPFC(line)`

1 iff the envelope's payload re-hashes to the sha256 anchor it carries (§7).

**Parameters**

- `line` _(string)_ — one VSLS3 schema-v1 envelope line

**Returns** _bool_ — intrinsic integrity — the shipped object equals what was captured

<!-- END GENERATED API REFERENCE -->
