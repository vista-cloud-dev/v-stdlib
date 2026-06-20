---
name: phase2-vsltap
description: Traffic-tap Phase 2 (M1) — the non-interference VSLTAP core + VSLRPCTAP + VSLTAPHL, dual-engine green; the DO-framed fence + IRIS new-$test gotchas.
metadata:
  type: project
---

**RPC+HL7→S3 traffic tap — Phase 2 / M1 DONE (2026-06-19, branch `phase2-vsltap`,
unmerged).** The non-interference capture core — THE safety gate everything
downstream waits behind (spec `docs/proposals/rpc-traffic-s3-streaming.md`
§6/§4.1/§8.1; plan §6). **Dual-engine GREEN: YDB (m-test-engine) 73/73 + IRIS
(m-test-iris) 73/73**, on BARE engines (no VistA, no S3, no network — Phase 2 is
egress-independent by design; the Phase-1 G-HTTP-* blockers don't touch it).

**Three new `VSL*` routines (layer v; consume `m` down — STDDATE/STDPROF — never up):**
- **`VSLTAP`** — the core. Rolling `^XTMP("VSLTAP","data",seq)` ring (bounded,
  overwrite-oldest via head/tail; `,0)` = `purgedate^createdate^desc` FileMan dates
  so Kernel `XQ82`/`XQ XUTL $J NODES` auto-purges it — **no FileMan file**, §4.1.1).
  The gate `$$enabled` = armed AND not auto-disabled AND (consumer OR always-on)
  (fail-safe-OFF; consumer-gated default D-8). `$$append` is **self-fenced** +
  bounded; auto-failover `disable(reason)`/`rearm` records explicit `_offwindows`;
  triggers = fault / copy-cost ceiling / latency-Δ / pressure. State machine
  `$$state` = OFF/ARMED-IDLE/ACTIVE/AUTO-DISABLED/UNHEALTHY; `$$healthy` heartbeat.
- **`VSLRPCTAP`** — `do capture^VSLRPCTAP(.rec)`, the fenced fire-and-forget tee the
  (unbuilt) `VSLRPC` chokepoint will call beside `D TAG^ROUTINE`. VSLRPC is a **seam,
  not a dependency** this session — proven against an INJECTED chokepoint (the bench's
  synthetic dispatch loop + the tests). Real VSLRPC wiring = one line, owed.
- **`VSLTAPHL`** — always-on counters (writes/bytes/denied) + nearest-rank latency
  `$$pctl`, the A/B watchdog (`$$abcheck`/`watchLatency` → auto-failover), and the
  standby readiness probe `$$ready` + synthetic `$$canary` (byte-exact round-trip
  through `^XTMP`, touches no real ring) — idle is provably healthy, not dead (§8.1).

**Config/state in `^VSLTAP` (control state); the capture cache in `^XTMP("VSLTAP",…)`
(SAC scratch global).** XPAR config source, the VSLRPC chokepoint, and the Kernel
purge-schedule are all production SEAMS — Phase 2 reads plain globals so the gate runs
on a bare engine. The 3-arm non-interference benchmark (`VSLTAPBENCHTST`: OFF /
ON+consumer / ON always-on no-consumer + large 50KB payload + µs/SET microbench) is a
**`make ci` gate** (added), pre-registered D-7 bounds 250µs small / 2500µs large.

**GOTCHAS (the two that cost real time — both dual-engine portability):**
1. **An argument-less `QUIT` in a flag-`$ETRAP` trap fired inside an EXTRINSIC (`$$`)
   frame raises M17 NOTEXTRINSIC and aborts the suite 0/0** — NOT a swallow. (STDASSERT
   `raises()` documents this; it's why it uses zgoto/try-catch.) The VSLLOG/VSLTASK
   `set $etrap="set ok=0,$ecode="""" quit"` pattern only works because the erroring op
   sits in a **DO**-invoked frame. Fix: the risky ring write runs in a DO-invoked
   private (`write1`) that `$$append` fences; the trap's arg-less QUIT is then legal and
   unwinds it. Extends the M4 zgoto-aborts-the-harness gotcha [[m4-vslsec-vsllog]].
2. **`new $test` ABORTS on IRIS** (m-test-iris) — the YDB suites pass, the IRIS suites
   that route through it go 0/0. Preserve a caller's `$TEST` across a side-call by hand:
   `set t=$test … <work> … if t` (restores the 0/1 exactly). Dual-engine portable; no
   `new $test`.

**Gates:** fmt/lint(0)/arch(layer-v)/seams/icr(no new L4)/citations/namespaces/
msl-pin/engine-access all green. Added `^XTMP` to `tools/gen_namespace_registry.py`
SCRATCH_GLOBAL_RE (Kernel's SAC scratch global, owned by no app namespace).
**`make check-kids` is PRE-EXISTING red on `main`** (committed `dist/kids/VSL.kids` ≠
a fresh `v-pkg` build — version drift; SKIPs green in CI where v-pkg is absent) — NOT a
Phase-2 regression; my routines are correctly NOT in the VSL KIDS base. Left untouched.

Companion shared note: the `docs` repo `docs/memory/rpc-traffic-s3-streaming-proposal.md`.
Next: **Phase 3 (M2)** — egress wiring (`VSLS3`→`STDS3`, drain `^XTMP`), `VSLTAPFC`
byte-equality fidelity comparator, `VSLHL7TAP` (#772 tail), e2e round-trip harness;
resolve the Phase-1 G-HTTP-* egress blockers there. Kickoff: `docs/prompts/phase3-*`.
