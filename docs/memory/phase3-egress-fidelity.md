---
name: phase3-egress-fidelity
description: Traffic-tap Phase 3 (M2) egress-independent core — VSLS3 (LDJSON envelope + drain) + VSLTAPFC (byte-equality comparator) + VSLTAP $$drainTo, dual-engine green; the live MinIO round-trip carved (blocked on G-HTTP-*).
metadata:
  type: project
---

**RPC+HL7→S3 traffic tap — Phase 3 / M2: egress-independent CORE DONE (2026-06-19,
branch `phase3-egress-fidelity`, unmerged).** Joins the two ends the gate waits behind
(spec `docs/proposals/rpc-traffic-s3-streaming.md` §9/§11/§12/§4.1.3/§7/§15; plan §7).
Built leaf-first, TDD red-first, **dual-engine GREEN: YDB (m-test-engine) + IRIS
(m-test-iris) — 62/62 new** (VSLS3 28 + VSLTAPFC 19 + drain 15) **+ 148/148 with the
Phase-2 set** (no regression). Kickoff: `docs/prompts/phase3-egress-fidelity-kickoff.md`.

**Three deliverables (layer v; consume `m` down — STDJSON/STDCRYPTO/STDB64/STDS3/
STDSIGV4/STDDATE — never up; VSLS3→VSLTAP is v→v one-way, no cycle):**
- **`VSLS3`** — the egress sink. `$$envelope(rec,proto,dir,station,seq,opt)` frames ONE
  LDJSON line carrying the **raw verbatim payload** (escaped-inline default, base64 a
  per-stream `opt("base64")` switch) + a per-record **sha256 anchor** over the RAW
  bytes; built as a STDJSON **node** and serialised by the PUBLIC `$$encode^STDJSON`
  (escaping never hand-rolled; keys emit in M collation order → deterministic). `$$key`/
  `$$offWindowsKey`/`$$fidelityKey` = the §11 `traffic/<station>/…` layout. `$$ctx`
  builds the S3 cred ctx + `opt("endpoint")` from the **`^VSLTAP("cfg",…)` config seam**
  (`s3accesskey`/`s3secretkey`/`s3region`/`s3endpoint`/`s3bucket`/`s3station`/…) — point
  it at real S3 or MinIO with no code change. `$$ship`/`$$readback` wrap `$$putObject`/
  `$$getObject^STDS3` (the transport monopoly). **`$$drain(res)`** = the §4.1.3 flush:
  consumer-gated + auto-failover-aware (`$$enabled^VSLTAP`), $ORDER the ring `(tail,head]`
  into ONE LDJSON batch, ship via a `$$shipBatch` seam, then `$$drainTo^VSLTAP(h)` trim
  on a 200 (leave intact on any other status, for retry). Runs in the SEPARATE flush
  process — never the RPC CPU.
- **`VSLTAPFC`** — the fidelity comparator (§7), proves byte-equality, doesn't assert it.
  `$$payloadOf` decodes an envelope back to raw bytes; `$$verify` re-hashes the payload
  to its own sha256 anchor (intrinsic integrity); `$$matches(line,source)` = byte-equal
  to the captured source AND verifies (RPC tee-vs-mirror; HL7 vs #772); `$$reconcile`
  rolls a corpus vs the read-back envelopes into matched/mismatch/missing/extra (the
  §15.2 round-trip core); `$$manifest` serialises a run to the `_fidelity` JSON object.
- **`VSLTAP $$drainTo(seq)`** — the only new core entry: post-ship trim (drop `(tail,seq]`,
  advance tail), reusing the existing `dropOldest`. Called by the flush, never the RPC path.

**Carried/new (`make`, harness):** `make` now runs the engine in **byte mode by default**
(`--chset m` in `ENGINE_FLAGS`) — v-stdlib consumes byte-oriented `STD*` (crypto/b64/json),
like m-stdlib; YDB exports `ydb_chset=M`, IRIS no-ops; ASCII suites unaffected. **The live
end-to-end round-trip harness `VSLS3E2ETST` (deterministic RPC corpus → drive → drain →
ship to MinIO → read back → `$$reconcile` byte-for-byte) is WRITTEN but CARVED into
`make test-s3` (NOT `make ci`/`make test`)** — it needs engine HTTP egress, still blocked
by **G-HTTP-YDB** (m-test-engine lacks the stdhttp/libcurl callout → bake it in, mirror
the B1 crypto bake) and **G-HTTP-IRIS-GET** (STDHTTP `%Net` fails signed bodyless GET).
Mirrors Phase 1's `make test-s3` carving exactly (live PUT proven, GET blocked).

**GOTCHAS — dual-engine portability, all in TEST code, none in the shipped routines
(extends [[phase2-vsltap]]):**
1. **Calling an EXTRINSIC (`$$…`, quits with a value) via `DO` raises QUIT-with-arg-in-
   DO-frame on YDB and aborts the suite 0/0** (IRIS tolerates it). `do parse^STDJSON` /
   `do append^VSLTAP` / `do drain^VSLS3` are wrong — must be `$$`. This bit THREE times.
2. **Passing a SUBSCRIPTED local by reference (`$$valueOf^STDJSON(.t("x"))`) is invalid
   YDB syntax → 0/0 abort.** For a leaf node, pass the VALUE (`t("x")`, no dot) — `valueOf`
   reads it directly. (STDJSON's own encodeObject comment documents this.)
3. **A parsed line missing an expected member → bare `t("x")` raises UNDEF on BOTH
   engines.** Wrap comparator reads in `$get(t("x"))` so the public `$$verify`/`$$payloadOf`
   return safely (m-reviewer caught this; suites missed it — every fixture is complete).

**Gates:** fmt/lint(**0**)/arch(layer-v, G1–G4)/seams(0)/icr(18, no new L4)/citations(18)/
namespaces(13 routines, regenerated)/msl-pin(v0.9.0)/engine-access all green. **m-reviewer
pass** before commit → fixed the `$get` UNDEF guard + made the drain ship empty-but-present
records (no silent drop). `make check-kids` is **pre-existing red on main** (v-pkg KIDS
drift; SKIPs in CI) — the tap routines are correctly NOT in the VSL KIDS base. Left untouched.

**REMAINS for M2 (next session):** resolve **G-HTTP-YDB/IRIS-GET** → run `make test-s3`
to close the byte-exact round-trip on both engines; **`VSLHL7TAP`** (#772 store-tail) +
**G-HL7HOOK** (confirm #772 vs HLO #777x vs subscriber-protocol against the gold corpus +
a live engine); **Option B** (socket→sidecar) behind the D-10 flag; live-periodic fidelity
hook + ship the `_offwindows`/`_fidelity` manifests. Companion shared note:
`docs` repo `docs/memory/rpc-traffic-s3-streaming-proposal.md`. Next phase: Phase 4 (M3)
the `v-web` SSE health/fidelity console — `docs/prompts/phase4-console-kickoff.md`.
