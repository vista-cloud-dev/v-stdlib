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
| `shipBatch` | `$$shipBatch^VSLS3(ctx, bucket, key, body, opt, resp)` | (private) ship one batch object; honour the capture-sink test seam. |

### `$$ctx^VSLS3(ctx, opt)`

Build the S3 credential ctx + opt(endpoint) from the ^VSLTAP config seam.

**Parameters**

- `ctx` _(array)_ — OUT by-ref: accessKey/secretKey/region/service[/sessionToken]
- `opt` _(array)_ — OUT by-ref: opt("endpoint") for path-style (MinIO/LocalStack)

**Returns** _string_ — the bucket name from the seam

### `$$drain^VSLS3(res)`

Flush the ^XTMP ring to S3 as one LDJSON batch, then trim the shipped entries.

**Parameters**

- `res` _(array)_ — OUT by-ref: res("shipped")/("key")/("body")/("status")

**Returns** _int_ — the number of records shipped (0 if gated/empty/failed)

### `$$envelope^VSLS3(rec, opt)`

Frame one captured record as a single schema-v1 LDJSON line.

**Parameters**

- `rec` _(array)_ — by-ref schema-v1 field array; rec("payload") = the RAW bytes,
plus event_id/call_id/ts/protocol/direction/station/seq/rpc/
duz/job/client[/denied|result_kind]/chunk_count/payload_encoding
- `opt` _(array)_ — by-ref: opt("ts") (default ts) / opt("base64") (default encoding)

**Returns** _string_ — one schema-v1 JSON object line, no trailing newline

### `$$fidelityKey^VSLS3(station, ymd)`

The per-day _fidelity manifest key (periodic VSLTAPFC results, §11).

**Parameters**

- `station` _(string)_ — the station partition
- `ymd` _(string)_ — YYYYMMDD day partition (default: today)

**Returns** _string_ — the S3 object key

### `$$gSerialize^VSLS3(seq)`

Serialize a v2 GLOBAL-ARRAY MERGE snapshot (^...,"g") to a deterministic, lossless blob.

**Parameters**

- `seq` _(numeric)_ — the ring sequence of a v2 record whose result_kind="global"

**Returns** _byte-string_ — one node per line: $$encode^STDJSON of {s:<subscripts>,v:<value>}

### `$$key^VSLS3(station, proto, seq, ymd)`

The object key for one traffic stream: traffic/<st>/<proto>/Y/M/D/<seq>.ndjson.

**Parameters**

- `station` _(string)_ — the station partition
- `proto` _(string)_ — protocol tag ("rpc"/"hl7")
- `seq` _(numeric)_ — the capture sequence number
- `ymd` _(string)_ — YYYYMMDD day partition (default: today)

**Returns** _string_ — the S3 object key

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

### `$$shipBatch^VSLS3(ctx, bucket, key, body, opt, resp)`

(private) ship one batch object; honour the capture-sink test seam.

<!-- END GENERATED API REFERENCE -->
