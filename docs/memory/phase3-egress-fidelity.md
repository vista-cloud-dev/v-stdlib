---
name: phase3-egress-fidelity
description: Traffic-tap Phase 3 (M2) — VSLS3 (LDJSON envelope + drain) + VSLTAPFC (byte-equality comparator) + VSLTAP $$drainTo + VSLHL7TAP (HL7 store-tail) all dual-engine green; live MinIO round-trip GREEN on BOTH engines; G-HL7HOOK resolved by a live vehu probe.
metadata:
  type: project
---

**VSLHL7TAP — HL7 store-tail adapter DONE (2026-06-20, branch `phase3-egress-fidelity`/`ship-all-routines`, unmerged).** Plan §7 stage 3.3; the HL7 half of the tap. Unlike `VSLRPCTAP` (an in-line tee), HL7 traffic is ALREADY persisted by the HL7 package, so `VSLHL7TAP` is a passive **store-tailer** run from a separate flush process (like `VSLS3 $$drain`): `do tail()` is consumer-gated (`$$enabled^VSLTAP`) then forward-$ORDERs each store from a persisted cursor, reassembles the verbatim message, and tees it via `$$tee^VSLTAP` (so consumer-gating + fault-fence are inherited). Non-interference is **structural** (read-only of an existing store). Public API: `do tail()` / `tailLegacy()` / `tailHLO()`, `$$readLegacy(ien)` / `$$readHLO(ien)`, `$$cursor(store)` / `do setCursor`/`resetCursors`. Cursors ride in `^VSLTAP("hl7cur","772"|"778")`. **Dual-engine 17/17 (`VSLHL7TAPTST`); tap regression 144/144 both engines.** Shipped in the KIDS base (added to `kids/vsl.build.json`, now **14 routines**; namespace registry regenerated). Gates green (fmt/lint 0/arch/check-kids — the latter now GREEN, no longer pre-existing red).

**G-HL7HOOK RESOLVED — by a LIVE probe of `vehu` (YDB-VistA) through the driver stack (`m vista exec --engine ydb --transport docker --container vehu`) + the #772/#778/#777 DD (2026-06-20).** VistA keeps TWO parallel HL7 stores, both can carry live traffic, so the tail covers both. **Authoritative layout (load-bearing — expensive to reacquire):**
- **Legacy #772 `^HL(772,`:** entry header `^HL(772,IEN,0)` = `fmDateTime^…^^DIR^^MSGID^^IEN^STATUS^…` (p1 datetime, p4 I/O, p6 msgid). **Message text = `^HL(772,IEN,"IN",seq,0)`, one verbatim HL7 segment per node (seq 1..N)**, WP header `^HL(772,IEN,"IN",0)` = `^^lastseq^count^date^`. The `"IN"` multiple is **HL7-PACKAGE-managed, NOT a FileMan DD field** (the #772 DD has no "IN" node — fields sit at `0;1..0;14`,`1;1`,`2;1`,`P;1`). A purged entry keeps only node 0 (no `"IN"` body) → `$$readLegacy`="".
- **HLO #778 `^HLB(` / #777 `^HLA(`:** `^HLB(IEN,0)` = `MSGID^bodyIEN^^DIR^LINK` (.02 → #777 body IEN); MSH is **rebuilt from `^HLB(IEN,1)`_`^HLB(IEN,2)`** (DD fields 1+2 = "HDR SEGMENT components 1-6 / 7-end"); body segments = `^HLA(bodyIEN,1,seq,0)` (#777 field 1 "SEGMENTS NOT BATCHED" @ node `1;0`, MSH excluded). vehu had **no HLO data** (counts 0) so HLO is DD+corpus-grounded, not live-data-validated — a follow-up needs an HLO-active VistA.
- **CURSOR — the corpus warning confirmed live:** the file **0-node 3rd piece is STALE** (`^HL(772,0)`=`…^772DI^4589^` while the live entries keyed at ~2.23M). The reliable cursor is the **last present numeric IEN via `$ORDER`**; non-numeric top-level subs (the `B`/`C`/`AF`/`AI` cross-refs) collate after numerics and END the tail (`nextIen` stops at the first non-numeric). HLO assigns IENs from the `^HLC` counter, same `$ORDER` rule.

**GOTCHA (cost real time again — the [[phase2-vsltap]] / extrinsic-via-DO trap, 4th sighting):** `tee^VSLTAP` is an EXTRINSIC (`quit $$append`); calling it `do tee^VSLTAP(msg)` raised QUIT-with-arg-in-DO-frame on YDB → silent **0/0 suite abort** (IRIS tolerated it). Fixed to `set sent=$$tee^VSLTAP(msg)`. Also M-MOD-009 (≤3 commands/line) forced the house `$ORDER`-loop idiom — `for  do oneStep(.x,…) quit:x=""` (advance+body in the helper) or counted `for i=1:1 quit:'$data(@ref)`, never `for  set x=$O() quit:…  set/do` (=4 commands).

**EGRESS BLOCKERS — UPDATE (2026-06-20).** Resolved the IRIS egress blocker and ran
the live byte-exact round-trip: **`VSLS3E2ETST` is GREEN on IRIS, 6/6** (generate RPC
corpus → tap → `$$drain` ships LDJSON to MinIO → `$$readback` GET → `$$reconcile`
byte-for-byte). The "G-HTTP-IRIS-GET (`%Net` fails bodyless GET)" finding was a
**misdiagnosis** — the real causes were two **m-stdlib `STDS3` bugs** (fixed on
`m-stdlib` branch `phase1-s3-sigv4`, pushed): (1) `getObject`/`headObject`/
`deleteObject`/`listObjectsV2`/the multipart trio took **no `opt`** arg, so
`opt("endpoint")` never reached `buildRequest` — every read op signed+sent to **real
AWS** instead of MinIO (→ `sc=0`); now all seven request-building ops take `opt`
(breaking arity; callers updated). (2) `STDHTTP` `irisPerform` charset-translated
high bytes → signed-binary `x-amz-content-sha256` mismatch; now sets
`REQ.WriteRawMode=1`. v-stdlib side: **`VSLS3 $$readback` now takes `opt`** and the
harness threads it; the harness bucket points at the s3-testbed bucket
`vista-test-logs`. **YDB leg still blocked**, re-triaged as an **engine-image
call-out defect** (NOT M code): the `stdhttp` `$ZF` package fails to LOAD on
`m-test-engine` YDB r2.07 — every `$&stdhttp.*` fails to compile (`%YDB-E-EXPR`,
package-wide); `http.so`+`std_http.xc`+`ydb_xc_stdhttp`+libcurl are all present and
ldd-clean. Not buffer size (`std_compress.xc` uses the same `[1048576]` and works);
prime suspect = the **zero-arg `http_available()` table entry** (every working
call-out has ≥1 param). Fix + verify need the m-test-engine image rebake (no
compiler in-image; writing into the shared engine is correctly forbidden here). See
m-stdlib `docs/tracking/discoveries.md` (both 2026-06-19 P1 rows re-triaged) +
[[phase2-vsltap]]. **GOTCHA:** `m-test-iris` poisons the job after a failed `%Net.Send`
(a stale 0/0 abort lingers across suites) — `docker restart m-test-iris` clears it
(known m-cli runner discovery). Verification exfil trick: write `$zstatus`/error into
a MinIO object via the working PUT and read it off MinIO's host data dir (the engines
have no host mount).
---

**RPC+HL7→S3 traffic tap — Phase 3 / M2: egress-independent CORE DONE (2026-06-19,
branch `phase3-egress-fidelity`, unmerged).** Joins the two ends the gate waits behind
(spec `docs/proposals/implemented/rpc-traffic-s3-streaming.md` §9/§11/§12/§4.1.3/§7/§15; plan §7).
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

**OPTION-A MATRIX GATE WIRED INTO `make ci` (2026-06-20, stage 3.4).** New self-contained
`test-s3-matrix` Makefile target: `trap`-guarded `scripts/s3-testbed.sh up` → `VSLS3E2ETST` on YDB
(`m-test-engine`) **and** IRIS (`m-test-iris`) → `down`. Vendored `scripts/s3-testbed.sh` from
m-stdlib (byte-compatible) so the gate needs no MSL checkout. Restructured `make ci` (was `: check`,
red on bare engines) → **`check-fast` + `test-bare` (the 10 bare-engine-green suites, both engines,
incl. the `VSLTAPBENCH` non-interference gate) + `test-s3-matrix`** — **green end-to-end, exit 0**
(bare suites + YDB 6/6 + IRIS 6/6 round-trip; MinIO torn down). `BARE_TESTS` excludes the
VistA-dependent suites (VSLBLD/CFG/FS/IO/LOG/TASK — 0/0 on a bare engine, need Kernel/FileMan; run via
`make check`/`make test` on a VistA box) and `VSLS3E2ETST` (the live one, in the matrix gate).
**GOTCHA:** `check-engine-access` flagged the vendored script's COMMENT for the literal token
`docker exec` — reworded to "execs into an engine" (the regex `docker\s+(?:-\S+\s+)*exec\b` is
text-blind). **GitHub `ci.yml` ENGINE-CI WIRED (2026-06-20).** Two self-contained jobs (the reusable `m-ci.yml`
starts only one engine, has no MinIO, checks out only the caller — can't host this): **`engine-ydb`
HARD** (build `m` from m-cli@main → clone m-stdlib@`master` for `STD*` routines → start
`ghcr.io/m-dev-tools/m-test-engine:0.2.0` → vendored `scripts/s3-testbed.sh up` → `make test-bare`
+ `make test-s3` ENGINE=ydb → teardown) and **`engine-iris` fail-soft (continue-on-error, PRs only)**
on `intersystemsdc/iris-community` with `ENGINE_FLAGS='--engine iris --docker m-test-iris --chset m
--namespace USER'` (best-effort, org IRIS posture). The drift gates stay in the reusable engine-free
`ci` job (NOT re-run in engine-ydb — else `check-msl-pin` would actually execute against the cloned
MSL and could drift-fail). **Deps verified present:** `m-test-engine:0.2.0` pullable; m-stdlib@master
carries the STDS3 read-op `opt`-threading fix (`getObject(...,opt,resp)`, #20). **CONFIRMED GREEN in Actions** on
draft **PR #13** (run 27890221864, 2026-06-21): `engine-ydb` bare **165/0** + round-trip
`VSLS3E2ETST` **6/6**; `engine-iris` (fail-soft) ALSO bare 165/0 + round-trip 6/6 — iris-community
connected with `--namespace USER` + default creds and did the `%Net` egress to MinIO with **no
tuning** (better than expected; the curated-local-vs-CI-iris worry didn't bite). Jobs ran in
~50–70s (runner pulled `m-test-engine:0.2.0` fast). (`ENGINE_FLAGS=` overrides the Makefile `:=`
default on the command line — that's how the iris job injects `--namespace USER`.)

**REMAINS for M2 (next session):** the HLO leg of `VSLHL7TAP` live-data-validated against an HLO-active VistA (vehu had none);
`VSLTAPFC` HL7 live-periodic fidelity hook (shipped-vs-#772 via `$$readLegacy^VSLHL7TAP`); ship the
`_offwindows`/`_fidelity` manifests. **Option B (socket→sidecar, stage 3.5) DEFERRED** (decision
2026-06-20) until a site mandates ZERO DB writes — A covers the technical need at near-zero footprint
(`^XTMP`, no FileMan file; §4.1.1), and B's per-host collector reintroduces the AWS-Traffic-Mirroring
operational dependency this effort exists to escape; re-enters scope on demand behind the D-10 flag
(pipeline already B-ready). **DONE since:** egress blockers G-HTTP-YDB/IRIS-GET resolved (round-trip
GREEN both engines, m-test-engine 0.2.0); **`VSLHL7TAP` + G-HL7HOOK** (this session). Companion shared note:
`docs` repo `docs/memory/rpc-traffic-s3-streaming-proposal.md`. Next phase: Phase 4 (M3)
the `v-web` SSE health/fidelity console — `docs/prompts/phase4-console-kickoff.md`.
