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

**Example**

```m
new envs,res,rq,rs,oq,os,rd,od,re,oe set rq("direction")="req",rq("call_id")="A",rq("seq")=1,rq("denied")=0,rq("payload")="p" set envs(1)=$$envelope^VSLS3(.rq,.oq) set rs("direction")="resp",rs("call_id")="A",rs("seq")=2,rs("payload")="r" set envs(2)=$$envelope^VSLS3(.rs,.os) set rd("direction")="req",rd("call_id")="B",rd("seq")=3,rd("denied")=1,rd("payload")="p" set envs(3)=$$envelope^VSLS3(.rd,.od) set re("direction")="req",re("call_id")="C",re("seq")=4,re("denied")=0,re("payload")="p" set envs(4)=$$envelope^VSLS3(.re,.oe) do eq^STDASSERT(.pass,.fail,$$drops^VSLTAPFC(.envs,.res)_"|"_res("rpc_denied")_"|"_res("rpc_error"),"2|1|1","a denied req-no-resp is rpc_denied, an errored req-no-resp is rpc_error, the clean pair is not a drop")
```

### `$$lastFidelity^VSLTAPFC()`

The last persisted _fidelity manifest line, or "" when no run has run yet.

**Returns** _string_ — the JSON manifest stored by persist, or "" (console: "pending")

**Example**

```m
new res,save,had set had=$data(^VSLTAP("fc","last")),save=$get(^VSLTAP("fc","last")) set res("matched")=5,res("mismatch")=0,res("missing")=0,res("extra")=0 do persist^VSLTAPFC(.res,"65800,1") do true^STDASSERT(.pass,.fail,$$lastFidelity^VSLTAPFC()'="","after a persisted run lastFidelity returns the stored manifest line") if had set ^VSLTAP("fc","last")=save
```

### `$$manifest^VSLTAPFC(res, ts)`

Serialise a fidelity run to a single JSON manifest line (the _fidelity object).

**Parameters**

- `res` _(array)_ — by-ref: res("matched"/"mismatch"/"missing"/"extra")
- `ts` _(string)_ — capture timestamp (default $H)

**Returns** _string_ — one RFC-8259 JSON object summarising the run

**Example**

```m
new res,t set res("matched")=10,res("mismatch")=0,res("missing")=0,res("extra")=0 do true^STDASSERT(.pass,.fail,$$parse^STDJSON($$manifest^VSLTAPFC(.res,"65800,43200"),.t)&($$valueOf^STDJSON(t("matched"))=10)&($$type^STDJSON(t("ok"))="true"),"a clean run serialises to well-formed JSON with matched=10 and ok=true")
new res,t set res("matched")=3,res("mismatch")=2,res("missing")=0,res("extra")=0 do eq^STDASSERT(.pass,.fail,$$parse^STDJSON($$manifest^VSLTAPFC(.res,"65800,43200"),.t)_"|"_$$type^STDJSON(t("ok")),"1|false","a run with a mismatch serialises ok=false")
```

### `$$matches^VSLTAPFC(line, source)`

1 iff the decoded payload byte-equals `source` AND the hash anchor is intact.

**Parameters**

- `line` _(string)_ — one VSLS3 envelope line
- `source` _(byte-string)_ — the captured source record (the tee, the #772 message)

**Returns** _bool_ — the byte-equality proof (RPC tee-vs-mirror; HL7 vs #772)

**Example**

```m
new rec,opt,line set rec("direction")="resp",rec("call_id")="500-1-5",rec("seq")=5,rec("payload")="hello world" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$matches^VSLTAPFC(line,"hello world"),"decoded payload byte-equals the source AND the hash is intact")
new rec,opt,line set rec("direction")="resp",rec("call_id")="500-1-5",rec("seq")=5,rec("payload")="hello world" set line=$$envelope^VSLS3(.rec,.opt) do eq^STDASSERT(.pass,.fail,$$matches^VSLTAPFC(line,"hello WORLD"),0,"any drift from the source fails byte-equality")
```

### `$$payloadOf^VSLTAPFC(line)`

Decode one LDJSON envelope line back to the verbatim captured bytes.

**Parameters**

- `line` _(string)_ — one VSLS3 schema-v1 envelope line (raw or base64 payload)

**Returns** _byte-string_ — the raw payload, byte-exact (escaping/base64 reversed)

**Example**

```m
new rec,opt,line set rec("direction")="resp",rec("call_id")="500-1-1",rec("seq")=1,rec("payload")=("a"_$char(9)_"b\c"_""""_"q") set line=$$envelope^VSLS3(.rec,.opt) do eq^STDASSERT(.pass,.fail,$$payloadOf^VSLTAPFC(line),"a"_$char(9)_"b\c"_""""_"q","inline payload decodes byte-exact")
new rec,opt,line set rec("direction")="resp",rec("call_id")="500-1-1",rec("seq")=1,rec("payload")=("a"_$char(9)_"b"_""""_"q") set opt("base64")=1 set line=$$envelope^VSLS3(.rec,.opt) do eq^STDASSERT(.pass,.fail,$$payloadOf^VSLTAPFC(line),"a"_$char(9)_"b"_""""_"q","base64 payload decodes byte-exact")
write $$payloadOf^VSLTAPFC("not json at all")  ; ""
```

### `do persist^VSLTAPFC(res, ts)`

Store the last fidelity run so the console can read it (no live run on request).

**Parameters**

- `res` _(array)_ — by-ref: res("matched"/"mismatch"/"missing"/"extra")
- `ts` _(string)_ — capture timestamp (default $H)

**Returns** _void_ — writes the manifest line to ^VSLTAP("fc","last")

**Example**

```m
new res,t,save,had set had=$data(^VSLTAP("fc","last")),save=$get(^VSLTAP("fc","last")) set res("matched")=8,res("mismatch")=0,res("missing")=0,res("extra")=0 do persist^VSLTAPFC(.res,"65800,43200") do eq^STDASSERT(.pass,.fail,$$parse^STDJSON($$lastFidelity^VSLTAPFC(),.t)_"|"_$$valueOf^STDJSON(t("matched")),"1|8","persist stores a readable manifest carrying the matched count") if had set ^VSLTAP("fc","last")=save
```

### `$$reconcile^VSLTAPFC(corpus, envs, res)`

Reconcile a generated corpus against the read-back envelopes, by sequence.

**Parameters**

- `corpus` _(array)_ — by-ref: corpus(seq) = the generated verbatim record
- `envs` _(array)_ — by-ref: envs(seq)   = the read-back envelope line
- `res` _(array)_ — OUT by-ref: res("matched"/"mismatch"/"missing"/"extra")

**Returns** _bool_ — 1 iff EVERY corpus record is present exactly once,
byte-equal + hash-matched, with no missing and no extra

**Example**

```m
new corpus,envs,res,r1,r2,o1,o2 set corpus(1)="record-1",corpus(2)="record-2" set r1("direction")="resp",r1("call_id")="c1",r1("seq")=1,r1("payload")="record-1" set envs(1)=$$envelope^VSLS3(.r1,.o1) set r2("direction")="resp",r2("call_id")="c2",r2("seq")=2,r2("payload")="record-2" set envs(2)=$$envelope^VSLS3(.r2,.o2) do true^STDASSERT(.pass,.fail,$$reconcile^VSLTAPFC(.corpus,.envs,.res),"a faithful round-trip reconciles fully")
new corpus,envs,res,r1,o1 set corpus(1)="record-1",corpus(2)="record-2" set r1("direction")="resp",r1("call_id")="c1",r1("seq")=1,r1("payload")="record-1" set envs(1)=$$envelope^VSLS3(.r1,.o1) do eq^STDASSERT(.pass,.fail,$$reconcile^VSLTAPFC(.corpus,.envs,.res)_"|"_res("matched")_"|"_res("missing"),"0|1|1","a dropped record (seq 2) is flagged missing, reconcile fails")
```

### `$$verify^VSLTAPFC(line)`

1 iff the envelope's payload re-hashes to the sha256 anchor it carries (§7).

**Parameters**

- `line` _(string)_ — one VSLS3 schema-v1 envelope line

**Returns** _bool_ — intrinsic integrity — the shipped object equals what was captured

**Example**

```m
new rec,opt,line set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="hello world" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$verify^VSLTAPFC(line),"a faithfully shipped payload re-hashes to its own sha256 anchor")
write $$verify^VSLTAPFC("not a json envelope")  ; 0
```

<!-- END GENERATED API REFERENCE -->
