---
name: fu5a-schema-v1-capture
description: Traffic-tap FU-5 increment 5A — the rich capture path emits schema v1 (FU-14/15/17/18 built, dual-engine green); the live wrap is 5B
metadata:
  type: project
---

# FU-5 increment 5A — schema-v1 capture path (FU-14/15/17/18)

**DONE 2026-06-23.** Branch `s3tap-fu5a-schema-v1` (stacked on the FU-8/FU-9 tip,
which is on FU-4). The bare-engine, TDD-able half of FU-5 — the live `CALLP^XWBBRK`
wrap + non-interference proof + FU-21 back-out are **5B (next increment)**. The
contract is the schema lock: `docs/design/s3tap-envelope-schema-lock.md` (schema v1)
+ `s3tap-envelope.v1.schema.json`. Grounded in [[fu8-fu9-ring]] / [[fu4-naked-ref-fence]]
/ [[phase2-vsltap]]; shared running memory [[rpc-traffic-s3-streaming-proposal]].

## What was built (all in v-stdlib `src/`)

- **`VSLTAP` cache layout v2** — a *second*, structured ring record beside the v1
  string record (kept intact):
  - `^XTMP("VSLTAP","data",seq)` = an **18-piece `^`-header** (schema_version ^
    event_id ^ call_id ^ direction ^ protocol ^ rpc ^ result_kind ^ wire_len ^
    chunk_count ^ payload_encoding ^ duz ^ job ^ client ^ ts ^ tag ^ nam ^ denied ^
    payload_sha256; **no field may contain `^`** — the payload, which can, lives in
    the subtree).
  - `…,seq,"p",i` = RAW payload chunk(s) (chunk_count=1 this increment; FU-2 splits later),
    `…,"hc",i` = per-chunk sha256, `…,"g"` = a GLOBAL-ARRAY MERGE snapshot (FU-17).
  - New API: `$$appendRec(.rec)` / `$$teeRec(.rec)` (gated + self-disabling `$ETRAP`,
    DO-framed `write1rec` so the trap's arg-less QUIT is legal — same idiom as `write1`),
    `$$hdr(seq,.out)` / `$$isV2(seq)` / `$$chunk(seq,i)` readers.
  - **`KILL` is recursive** → the existing `dropOldest`/`trim` already reaps the whole
    v2 subtree; no change needed.
- **`VSLRPCTAP`** — `capture(rec)` now takes a **by-ref record descriptor** (dir / rpc /
  payload / gref / result_kind / call_id / duz / job / client / station / denied / tag /
  nam / protocol / ts) instead of a flat string. The **FU-4 caller-state fence is
  unchanged** (naked-ref + $TEST save/restore around a DO-framed `work` → `$$teeRec`).
  The arg stays **scratch** (read, never written — derived `event_id` is built downstream,
  not injected back). New `$$callId(station,ctr)` = `station-$J-ctr` (FU-14; a $J-scoped
  **local** counter the wrap bumps once per RPC — no global hot node).
- **`VSLS3`** — `$$envelope(.rec,.opt)` reconciled to the **schema-v1 wire members**
  (renames `enc/hash/len/proto/dir`; adds schema_version/event_id/call_id/rpc/duz/job/
  client/denied/result_kind/chunk_count). **One shape, `direction` discriminates**: a req
  emits `denied`, a resp emits `result_kind` (matches the schema's allOf). wire_len +
  payload_sha256 are computed **over the RAW bytes** in the envelope (the expensive op
  stays off the in-path). **Dual-mode `$$drain`** → `resolveRec` frames a v2 record from
  its header (a global is serialized off-path by `$$gSerialize` and base64'd) **and** a
  legacy v1 string record (the synthetic demonstrator / `VSLS3DRAINTST` path).
- **`VSLTAPFC`** — `payloadOf`/`verify` read the v1 member names (`payload_encoding`,
  `payload_sha256`); new `$$drops(.envs,.res)` classifies **`rpc_error`** (req with no
  resp) vs **`rpc_denied`** (req with `denied=1`) by `call_id` reconcile (FU-15) →
  surfaced as `_fidelity` manifest counts (they do NOT clear `ok` — expected, accounted).

## Decisions / gotchas worth keeping

- **The ring stores RAW payload bytes; the wire encoding (base64/raw) and a global's
  serialize/hash are deferred to the DRAIN** (off the in-path, §6.1). The header's
  `payload_encoding` records the intended wire encoding (default `raw` this increment;
  the base64-default flip is FU-1). Scalar payloads hash in-path (small); a GLOBAL ARRAY
  is one `MERGE` with `chunk_count=0`/`wire_len=0`/empty hash — all computed at drain.
- **FU-17 in-path = exactly one `MERGE ^XTMP(…,"g")=@gref`** (gref = the broker's closed
  global root, XWBP/XWBY). The broker spares `^XTMP(` roots (FU-16) so the snapshot can't
  collide. `$$gSerialize` walks the snapshot with `$QUERY` (M-collation → deterministic),
  one JSON `{s:subscripts,v:value}` line per node (lossless via STDJSON escaping). The
  exact-vs-SNDDATA wire form is FU-11's concern; here it need only be deterministic +
  byte-faithful for the §15.2 round-trip.
- **`$name` prefix-matching gotcha** (in `gSerialize`): a `$name(^…,"g")` root ends with
  `")"`; comparing a descendant against the *full* root mismatches (descendants continue
  with `","`). Compare against the **root minus its trailing `)`** (`pfx`), and treat a
  node beginning `pfx_","` as in-subtree. The `for do gStep quit:nref=""` idiom keeps the
  walk ≤3 commands/line (M-MOD-009).
- **Lint:** `M-MOD-036` (tainted-into-indirection) fires on the FU-17 `MERGE @gref` and on
  `gSerialize`'s `@root/@nref` → these are internal closed `^XTMP` refs, not external input
  → a `disable-next-line` (VSLTAP) + `disable-file` (VSLS3, two sites) with justification.
  `M-MOD-024` (read-before-defined) on `hdr` populated by-ref by `$$hdr^VSLTAP` →
  `disable-file` (same pattern VSLTAPFC already documents).
- Routine bodies changed → the KIDS artifact drifted → `make kids` regenerated
  `dist/kids/VSL.kids` (still 14 routines, deterministic golden gate green).

## Verification

Dual-engine **190/190** on the changed suites (YDB m-test-engine `--chset m` + IRIS
m-test-iris); full **bare suite green both engines** (0 failures); all engine-free gates
(`make check-fast` + KIDS) green; **IRIS coverage 96.6%** over the 4 changed modules.
New `VSLTAPV2TST` (scalar+global round-trip, FU-18 context, mixed v1/v2 drain); rewritten
`VSLS3TST` / `VSLRPCTAPTST` / `VSLTAPFCTST`.

## NEXT: FU-5 5B
Splice the two fenced side-calls into the active broker `CALLP^XWBBRK` (request after
`:153` once `XWBSEC` is known → `dir=req`/`denied`; result after the `:158` `CAPI`
return → `dir=resp`, snapshot a GLOBAL-ARRAY result before `SNDDATA^XWBRW:60`). Read
`XWBTIP`/`XWBTSKT` directly for `client` (FU-18 OPEN-2). KIDS-install over the driver
path; re-run the non-interference proof against the REAL dispatch (IRIS first); FU-21 =
restore-to-stock `CALLP` + a per-XWB-patch re-pin hook.
