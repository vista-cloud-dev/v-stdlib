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

**`fidelityNow^VSLTAPRUN` redefined (the one judgment call):** in production there
is no source corpus to byte-compare against, so its per-object check was the
intrinsic hash. With the hash gone, `tallyLine` now counts a readback object as
matched iff it PARSES as a well-formed schema-v1 envelope (`$$parse^STDJSON`) —
the honest crypto-free residual (catches gross storage/truncation corruption, not
tampering). The STRONG byte-fidelity proof stays the `$$reconcile` byte-equality
round-trip in the test/CI harness (VSLS3E2ETST §15.2).

**Capture path (earlier, same day):** `write1rec^VSLTAP` already stopped hashing
(`set hash=""`, no `hc` node) — see [[live-capture-fault-stdcrypto]]. The capture
header keeps an empty piece-18 slot for layout stability; nothing emits a digest.

**Gates:** affected suites green on m-test-engine (VSLS3TST 44, VSLTAPFCTST 29,
VSLTAPRUNTST 8, VSLTAPV2TST 28, VSLTAPTST 44, VSLRPCWRAPTST 33). `dist/kids/
VSL.kids` + `dist/vsl-manifest.json` regenerated; lint 0-error; arch clean.
Pre-existing reds (VSLS3E2ETST needs live MinIO; VSL{BLD,CFG,FS,IO,LOG,TASK}TST
are 0/0 future-module stubs) are unrelated.
