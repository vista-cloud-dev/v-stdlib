---
name: egress-hash-removed
description: The RPC tap is now fully crypto-free — payload_sha256 removed from the VSLS3 egress envelope (and the capture path earlier); fidelity is byte-equality against the source, not a hash.
metadata:
  type: project
---

**The RPC traffic tap is fully STDCRYPTO-free (2026-06-25, owner directive).**
The owner's design rule: capture raw real RPC traffic with NO embellishments —
add only REQUIRED features, never nice-to-haves. Hashing is not required (RPCs are
plain ASCII the tap only OBSERVES; encryption/integrity belongs to the S3 PHI
boundary, not the tap), so the payload digest is removed everywhere.

**What was removed:**
- `VSLS3.envelope` no longer emits `payload_sha256` (was
  `"s:"_$$sha256^STDCRYPTO(raw)`). The schema-v1 envelope is now header + raw
  payload only. STDCRYPTO dropped from VSLS3's consumes list.
- `$$verify^VSLTAPFC` (intrinsic re-hash check) **deleted**. Public label count
  124 (was 125).
- `$$matches^VSLTAPFC` is now pure byte-equality (`$$payloadOf=source`), dropping
  the `&$$verify`. `$$reconcile` (which uses `$$matches`) unchanged in behavior —
  it is the required, crypto-free fidelity proof.
- Tamper-detection tests deleted (the tap doesn't detect tampering — it just ships
  raw): `tVerifyIntrinsicHash`/`tVerifyDetectsTamper`+`retamper` (VSLTAPFCTST),
  `tEnvelopeHashAnchorsRawBytes` (VSLS3TST, replaced by `tEnvelopeHasNoHashField`
  which locks the no-digest contract), `tFidelityNowCatchesTamper`+`tamperLine`
  (VSLS3E2ETST).

**`VSLTAPRUN` deleted entirely (2026-06-25, owner: "delete fidelityNow, it was
over-engineered, I never asked for it").** The whole periodic production
fidelity-run task is gone — `fidelityNow` + its sampler (`nextKey`/`verifyObject`/
`tallyLine`) + the scheduler that only ran it (`run`/`schedule`/`cadence`/
`reschedule`/`nextRun`) + `reconcilePersist`. Also removed: the routine from the
KIDS build (16 routines, was 17), the `VSL TAP FIDELITY CADENCE` XPAR param,
`tests/VSLTAPRUNTST.m`, the E2E `tFidelityNowVerifiesShipped` test, the
`docs/modules/vsltaprun.md` page + example program, and the VSLTAPRUN rows in the
two tap guides. `VSLTAPBO.cleanTasks` is generic (iterates `^VSLTAP("task",*)`) so
it needed no code change. The STRONG byte-fidelity proof was never in VSLTAPRUN —
it is the `$$reconcile^VSLTAPFC` byte-equality round-trip in the e2e/CI harness
(VSLS3E2ETST §15.2), which is retained. `persist`/`lastFidelity`/`manifest` stay
in VSLTAPFC (used by that round-trip test).

**Capture path (earlier, same day):** `write1rec^VSLTAP` already stopped hashing
(`set hash=""`, no `hc` node) — see [[live-capture-fault-stdcrypto]]. The capture
header keeps an empty piece-18 slot for layout stability; nothing emits a digest.

**Gates:** affected suites green on m-test-engine (VSLS3TST 44, VSLTAPFCTST 29,
VSLTAPRUNTST 8, VSLTAPV2TST 28, VSLTAPTST 44, VSLRPCWRAPTST 33). `dist/kids/
VSL.kids` + `dist/vsl-manifest.json` regenerated; lint 0-error; arch clean.
Pre-existing reds (VSLS3E2ETST needs live MinIO; VSL{BLD,CFG,FS,IO,LOG,TASK}TST
are 0/0 future-module stubs) are unrelated.
