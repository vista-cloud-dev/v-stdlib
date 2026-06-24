---
module: VSLS3
layer: v
since: 
stable: stable
synopsis: 'S3 egress sink: LDJSON envelope + the §11 bucket layout'
labels: ['ctx', 'drain', 'envelope', 'fidelityKey', 'gSerialize', 'key', 'list', 'offWindowsKey', 'readback', 'resolveRec', 'ship', 'shipBatch']
errors: []
see_also: []
doc_type: [REFERENCE]
---

# `VSLS3` — S3 egress sink: LDJSON envelope + the §11 bucket layout

<!-- Add hand-written prose (overview, rationale, gotchas, examples)
     here or below the generated API reference. The `## API reference`
     block is generated from the manifest by `make docs-bodies`. -->

<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py (`make docs-bodies`); edits between these markers are overwritten. -->
## API reference

_Generated from `dist/vsl-manifest.json` — the canonical, always-current signature / parameter / return / error surface. Usage narrative and gotchas live in the prose sections._

| Label | Signature | Summary |
|---|---|---|
| `ctx` | `$$ctx^VSLS3(ctx, opt)` | Build the S3 credential ctx + opt(endpoint) from the ^VSLTAP config seam. |
| `drain` | `$$drain^VSLS3(res)` | Flush the ^XTMP ring to S3 as one LDJSON batch, then trim the shipped entries. |
| `envelope` | `$$envelope^VSLS3(rec, opt)` | Frame one captured record as a single schema-v1 LDJSON line. |
| `fidelityKey` | `$$fidelityKey^VSLS3(station, ymd)` | The per-day _fidelity manifest key (periodic VSLTAPFC results, §11). |
| `gSerialize` | `$$gSerialize^VSLS3(seq)` | Serialize a v2 GLOBAL-ARRAY MERGE snapshot (^...,"g") to a deterministic, lossless blob. |
| `key` | `$$key^VSLS3(station, proto, seq, ymd)` | The object key for one traffic stream: traffic/<st>/<proto>/Y/M/D/<seq>.ndjson. |
| `list` | `$$list^VSLS3(ctx, bucket, prefix, opt, listing)` | LIST object keys under `prefix` via STDS3 listObjectsV2. |
| `offWindowsKey` | `$$offWindowsKey^VSLS3(station, ymd)` | The per-day _offwindows manifest key (explicit tap-off windows, §11). |
| `readback` | `$$readback^VSLS3(ctx, bucket, key, opt, resp)` | GET one object back from S3 / the S3-equivalent via STDS3. |
| `resolveRec` | `do resolveRec^VSLS3(seq, station, proto, erec)` | Build the schema-v1 field array for the record at `seq` (dual-mode: v2 header / v1 legacy). |
| `ship` | `$$ship^VSLS3(ctx, bucket, key, body, opt, resp)` | PUT one object to S3 / the S3-equivalent via STDS3. |

### `$$ctx^VSLS3(ctx, opt)`

Build the S3 credential ctx + opt(endpoint) from the ^VSLTAP config seam.

**Parameters**

- `ctx` _(array)_ — OUT by-ref: accessKey/secretKey/region/service[/sessionToken]
- `opt` _(array)_ — OUT by-ref: opt("endpoint") for path-style (MinIO/LocalStack)

**Returns** _string_ — the bucket name from the seam

**Example**

```m
new ctx,opt,b,save merge save=^VSLTAP("cfg") kill ^VSLTAP("cfg") set ^VSLTAP("cfg","s3bucket")="vista-traffic",^VSLTAP("cfg","s3endpoint")="http://m-s3-minio:9000" set b=$$ctx^VSLS3(.ctx,.opt) kill ^VSLTAP("cfg") merge ^VSLTAP("cfg")=save do eq^STDASSERT(.pass,.fail,b,"vista-traffic","bucket + endpoint read from the ^VSLTAP config seam (set-then-restore)")
```

### `$$drain^VSLS3(res)`

Flush the ^XTMP ring to S3 as one LDJSON batch, then trim the shipped entries.

**Parameters**

- `res` _(array)_ — OUT by-ref: res("shipped")/("key")/("body")/("status")

**Returns** _int_ — the number of records shipped (0 if gated/empty/failed)

**Example**

```m
new res,save,csave merge save=^XTMP("VSLTAP") merge csave=^VSLTAP("cfg") kill ^XTMP("VSLTAP"),^VSLTAP("cfg") set ^VSLTAP("cfg","s3sink")="capture",^VSLTAP("cfg","mode")="armed",^VSLTAP("cfg","consumer")=1,^VSLTAP("cfg","s3station")="500" set ^XTMP("VSLTAP","head")=1,^XTMP("VSLTAP","tail")=0,^XTMP("VSLTAP","data",1)="ONELINE" set n=$$drain^VSLS3(.res) kill ^XTMP("VSLTAP"),^VSLTAP("cfg") merge ^XTMP("VSLTAP")=save merge ^VSLTAP("cfg")=csave do eq^STDASSERT(.pass,.fail,n,1,"capture-sink seam drains the 1-record ring without a live PUT (status 200)")
```

### `$$envelope^VSLS3(rec, opt)`

Frame one captured record as a single schema-v1 LDJSON line.

**Parameters**

- `rec` _(array)_ — by-ref schema-v1 field array; rec("payload") = the RAW bytes,
plus event_id/call_id/ts/protocol/direction/station/seq/rpc/
duz/job/client[/denied|result_kind]/chunk_count/payload_encoding
- `opt` _(array)_ — by-ref: opt("ts") (default ts) / opt("base64") (default encoding)

**Returns** _string_ — one schema-v1 JSON object line, no trailing newline

**Example**

```m
new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="hello world" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"the line is well-formed JSON") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("payload")),"hello world","payload round-trips byte-exact")
new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="x" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("event_id")),"500-1-7:resp","event_id = call_id ':' direction")
new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="hello world" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("wire_len")),11,"wire_len = byte length of the RAW payload")
new rec,opt,line,t set rec("direction")="req",rec("call_id")="500-1-8",rec("seq")=8,rec("denied")=1,rec("payload")="p" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("denied")),1,"a req carries denied, not result_kind")
new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-9",rec("seq")=9,rec("payload")="v" set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("result_kind")),"scalar","a resp carries result_kind, not denied")
new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")=("a"_$char(9)_"b"_""""_"q") set opt("base64")=1 set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$decode^STDB64($$valueOf^STDJSON(t("payload"))),"a"_$char(9)_"b"_""""_"q","base64 switch decodes byte-exact")
new rec,opt,line,t set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="hi" set opt("base64")=1 set line=$$envelope^VSLS3(.rec,.opt) do true^STDASSERT(.pass,.fail,$$parse^STDJSON(line,.t),"well-formed") do eq^STDASSERT(.pass,.fail,$$valueOf^STDJSON(t("payload_sha256")),$$sha256^STDCRYPTO("hi"),"payload_sha256 anchors the RAW bytes, even under base64")
new rec,opt,a,b set rec("direction")="resp",rec("call_id")="500-1-7",rec("seq")=7,rec("payload")="hello world" set a=$$envelope^VSLS3(.rec,.opt),b=$$envelope^VSLS3(.rec,.opt) do eq^STDASSERT(.pass,.fail,a,b,"deterministic: same fixture frames byte-identical (M-collation key order)")
```

### `$$fidelityKey^VSLS3(station, ymd)`

The per-day _fidelity manifest key (periodic VSLTAPFC results, §11).

**Parameters**

- `station` _(string)_ — the station partition
- `ymd` _(string)_ — YYYYMMDD day partition (default: today)

**Returns** _string_ — the S3 object key

**Example**

```m
write $$fidelityKey^VSLS3("500","20260619")  ; "traffic/500/_fidelity/2026/06/19.json"
```

### `$$gSerialize^VSLS3(seq)`

Serialize a v2 GLOBAL-ARRAY MERGE snapshot (^...,"g") to a deterministic, lossless blob.

**Parameters**

- `seq` _(numeric)_ — the ring sequence of a v2 record whose result_kind="global"

**Returns** _byte-string_ — one node per line: $$encode^STDJSON of {s:<subscripts>,v:<value>}

**Example**

```m
new save,b merge save=^XTMP("VSLTAP","data",991,"g") kill ^XTMP("VSLTAP","data",991,"g") set ^XTMP("VSLTAP","data",991,"g","DPT",1)="ONE",^XTMP("VSLTAP","data",991,"g","DPT",2)="TWO" set b=$$gSerialize^VSLS3(991) kill ^XTMP("VSLTAP","data",991,"g") merge ^XTMP("VSLTAP","data",991,"g")=save do eq^STDASSERT(.pass,.fail,$length(b,$char(10)),2,"one JSON node line per descendant of the g MERGE snapshot")
```

### `$$key^VSLS3(station, proto, seq, ymd)`

The object key for one traffic stream: traffic/<st>/<proto>/Y/M/D/<seq>.ndjson.

**Parameters**

- `station` _(string)_ — the station partition
- `proto` _(string)_ — protocol tag ("rpc"/"hl7")
- `seq` _(numeric)_ — the capture sequence number
- `ymd` _(string)_ — YYYYMMDD day partition (default: today)

**Returns** _string_ — the S3 object key

**Example**

```m
write $$key^VSLS3("500","rpc",42,"20260619")  ; "traffic/500/rpc/2026/06/19/42.ndjson"
write $$key^VSLS3("442","hl7",1,"20260101")  ; "traffic/442/hl7/2026/01/01/1.ndjson"
```

### `$$list^VSLS3(ctx, bucket, prefix, opt, listing)`

LIST object keys under `prefix` via STDS3 listObjectsV2.

**Parameters**

- `ctx` _(array)_ — the credential context (from $$ctx), by-ref
- `bucket` _(string)_ — the source bucket
- `prefix` _(string)_ — the key prefix to list under ("" = whole bucket)
- `opt` _(array)_ — by-ref: opt("endpoint") — REQUIRED to reach the S3-equivalent
- `listing` _(array)_ — OUT by-ref: listing(1..n,"key"/"size"/"etag") + ("truncated"/"next")

**Returns** _int_ — HTTP status (200 ok); 0 on transport failure

### `$$offWindowsKey^VSLS3(station, ymd)`

The per-day _offwindows manifest key (explicit tap-off windows, §11).

**Parameters**

- `station` _(string)_ — the station partition
- `ymd` _(string)_ — YYYYMMDD day partition (default: today)

**Returns** _string_ — the S3 object key

**Example**

```m
write $$offWindowsKey^VSLS3("500","20260619")  ; "traffic/500/_offwindows/2026/06/19.json"
```

### `$$readback^VSLS3(ctx, bucket, key, opt, resp)`

GET one object back from S3 / the S3-equivalent via STDS3.

**Parameters**

- `ctx` _(array)_ — the credential context (from $$ctx), by-ref
- `bucket` _(string)_ — the source bucket
- `key` _(string)_ — the object key
- `opt` _(array)_ — by-ref: opt("endpoint") — REQUIRED to reach the S3-equivalent
- `resp` _(array)_ — OUT by-ref: resp("body") holds the bytes on 200

**Returns** _int_ — HTTP status (200 ok); 0 on transport failure

### `do resolveRec^VSLS3(seq, station, proto, erec)`

Build the schema-v1 field array for the record at `seq` (dual-mode: v2 header / v1 legacy).

**Parameters**

- `seq` _(numeric)_ — the ring sequence
- `station` _(string)_ — the station partition (authoritative for the §11 key)
- `proto` _(string)_ — default protocol when the record carries none
- `erec` _(array)_ — OUT by-ref: the schema-v1 fields incl. erec("payload") = RAW bytes

**Example**

```m
new erec,save merge save=^XTMP("VSLTAP") kill ^XTMP("VSLTAP") set ^XTMP("VSLTAP","data",993)="RAWBYTES" do resolveRec^VSLS3(993,"500","rpc",.erec) kill ^XTMP("VSLTAP") merge ^XTMP("VSLTAP")=save do eq^STDASSERT(.pass,.fail,erec("payload"),"RAWBYTES","a legacy v1 record resolves to a plain payload under the station/proto key (set-then-restore)")
```

### `$$ship^VSLS3(ctx, bucket, key, body, opt, resp)`

PUT one object to S3 / the S3-equivalent via STDS3.

**Parameters**

- `ctx` _(array)_ — the credential context (from $$ctx), by-ref
- `bucket` _(string)_ — the target bucket
- `key` _(string)_ — the object key (from $$key)
- `body` _(byte-string)_ — the LDJSON body (one or more envelope lines)
- `opt` _(array)_ — by-ref: opt("endpoint") + contentType
- `resp` _(array)_ — OUT by-ref: resp("header",*)/("error",*)

**Returns** _int_ — HTTP status (200 ok); 0 on transport failure

<!-- END GENERATED API REFERENCE -->
