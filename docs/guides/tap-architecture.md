---
title: v-stdlib — traffic-tap architecture overview
status: live
created: 2026-06-24
last_modified: 2026-06-24
revisions: 1
doc_type: [GUIDE, ARCHITECTURE]
---

# v-stdlib — traffic-tap architecture overview

An end-user / developer's map of the VSL traffic tap: what it captures, how the
data flows, and **why it cannot perturb the VistA it observes**. For the
step-by-step deploy / install / back-out procedure see the operations runbook
[`traffic-tap-dibrg.md`](traffic-tap-dibrg.md) (DIBRG); for the full design
see the spec + plan in the `docs` repo
(`proposals/implemented/rpc-traffic-s3-streaming*.md`).

## What it is

An **observe-only** capture of a live VistA's **RPC Broker** and **HL7** traffic,
shipped to **S3** as batched newline-delimited JSON (LDJSON). It runs *inside*
the engine (no host-OS / AWS / network change — it ships through the normal KIDS
pipeline the VistA team controls), and its prime invariant is **non-interference:
the tap never changes the behaviour, result, or timing envelope of the call it
captures.** Fidelity is *proven* (byte-equality), not asserted.

## The data flow

```
RPC path:
  CALLP^XWBBRK (national broker dispatch)
    │  ┌─ req^VSLRPCWRAP   (before dispatch — sees request + a denial)
    └──┤
       └─ resp^VSLRPCWRAP  (after a successful dispatch — sees the result)
            │
            ▼  fire-and-forget, fault-fenced, naked-ref-fenced
       $$teeRec^VSLTAP ──▶ VSLRPCTAP (the fenced tee at the VSLRPC chokepoint)
            │
            ▼  bounded, ALWAYS-ON memory ring
       ^XTMP("VSLTAP", …)  (schema-v1 records; ^XTMP auto-purges, journal-light)
            │
            ▼  drain (only when a sink is configured — the egress gate)
       $$drain^VSLS3 ──▶ LDJSON envelope ──▶ STDS3 (SigV4) ──▶ S3 bucket

HL7 path:
  VSLHL7TAP.tail()  tails #772 (legacy) + #778/#777 (HLO) from a persisted
  cursor  ──▶ $$tee^VSLTAP ──▶ (same ring → drain → S3)
```

- **`VSLRPCWRAP`** — the only splice into national code: the patched
  `CALLP^XWBBRK` calls `D req^VSLRPCWRAP` (before dispatch, where a CHKPRMIT
  denial is already known) and `D resp^VSLRPCWRAP` (inside the success block,
  after the `CAPI^XWBBRK2` dispatch, before the broker kills its scratch). Two
  unconditional `D` lines — nothing else in the broker changes.
- **`VSLRPCTAP`** — the fenced tee. Builds a schema-v1 record from the broker's
  process vars and hands it to the ring. Every exit path runs behind the FU-4
  **naked-reference fence** (saves/restores the engine's naked indicator —
  `$REFERENCE` on YDB, `$ZREFERENCE` on IRIS) and a DO-framed worker so a fault
  can never escape into the broker.
- **`VSLTAP`** — the non-interference core: the bounded rolling `^XTMP` ring, the
  three-way capture gate, the self-fenced bounded append, auto-failover (disable
  + record an off-window), and the standby state machine. **Capture is always-on
  and cheap; egress is separately gated** on a configured sink.
- **`VSLS3`** — frames each record as one schema-v1 LDJSON line and drains the
  ring to S3 via `STDS3` (the engine-neutral AWS client in m-stdlib). Owns only
  the VistA-side framing + config; the SigV4 signing and HTTP go through `STD*`.
- **`VSLHL7TAP`** — the decoupled HL7 store-tailer: a consumer-gated, fenced
  `$ORDER` walk over the persisted HL7 files from a high-water cursor (the HL7
  store is replayable, unlike the ephemeral RPC ring).

## Why it can't perturb VistA (the safety model)

1. **Fire-and-forget tee.** The wrap never blocks or alters the call; it copies
   and returns. The result the broker sends is untouched.
2. **Fault fence.** The risky work runs in a **DO-framed** worker with its own
   `$ETRAP`; a fault disables the tap and is swallowed, never propagated.
3. **Naked-reference fence.** The capture saves and restores the caller's naked
   indicator on every exit — the global the broker was mid-reference-to is
   preserved byte-for-byte (engine-neutral; the SVN differs YDB vs IRIS).
4. **Bounded memory.** The ring caps bytes per record and overall; an oversized
   payload is rejected, not buffered unboundedly.
5. **Auto-failover.** Any anomaly disables capture and records an explicit
   off-window (so a fidelity run reports honest gaps rather than silent loss).
6. **Off-the-hot-path serialisation.** The ring stores raw bytes; encode /
   hash / serialize happen at **drain** time, not in the captured call.

The non-interference claim is enforced, not assumed: `VSLTAPBENCHTST` is a
3-arm benchmark gate (off / armed / drain) with pre-registered latency bounds,
and the live install ran a wrap-on/wrap-off byte-identical proof.

## Fidelity, health, lifecycle

- **`VSLTAPFC`** — the fidelity comparator: decode a shipped LDJSON envelope back
  to the captured bytes and prove **byte-equality** against the source
  (plus a loss taxonomy — `rpc_error` / `rpc_denied`). Proof, not assertion; no hash.
- **`VSLTAPHL`** — the watchdog: heartbeat liveness, latency percentiles, a
  synthetic round-trip canary, and a standby-readiness probe.
- **`VSLTASK`** — the TaskMan persistent-listener seam (`^%ZTLOAD`); **`VSLCFG`**
  — the XPAR (`#8989.51`) config seam that arms the tap and names the sink.

## Supporting adapters

`VSLSEC` (identity / security-key checks over Kernel), `VSLFS` (FileMan DBS
storage), `VSLIO` (Kernel TCP transport), `VSLLOG` (FileMan audit sink),
`VSLENV` (the KIDS env-check hook, run by the v-pkg-driven install). Each is the
VistA binding of an engine-neutral `STD*` seam, consumed one-way `v → m`.

## Where next

- **Deploy / back-out:** [`traffic-tap-dibrg.md`](traffic-tap-dibrg.md).
- **Per-module API:** [`../modules/index.md`](../modules/index.md).
- **Quick start:** [`quick-start.md`](quick-start.md).
