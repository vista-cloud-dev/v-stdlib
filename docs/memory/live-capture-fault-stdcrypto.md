---
name: live-capture-fault-stdcrypto
description: The live RPC-tap capture fault (disabled="fault" on vehu) root-caused to a missing STDCRYPTO dependency; fixed by removing crypto from the capture path entirely (RPC traffic is plain ASCII; the tap only observes, never hardens).
metadata:
  type: project
---

**Live-capture fault — root-caused + fixed (2026-06-25).** Symptom: on vehu the
tap self-disabled (`$$disabled^VSLTAP()="fault"`, `^VSLTAP("_offwindows",1)=
"...^fault^"`) the moment capture ran, so the ring never filled. NOT
fault-injection (`faultinject=0`).

**Root cause:** `write1rec^VSLTAP` (scalar/req path) called
`set hash=$$sha256^STDCRYPTO(pl)` UNCONDITIONALLY, but **STDCRYPTO is not installed
on vehu** — `VSL*1.0*3` shipped only the `VSL*` routines, not the m-stdlib `STD*`
dependency. Proven via the driver stack: `m vista exec --engine ydb --transport
docker 'S X=$$sha256^STDCRYPTO("body")'` → `%YDB-E-ZLINKFILE ... File STDCRYPTO.m
not found`. The fence (`set $etrap="set ok=0,$ecode='''' quit"` in `appendRec`)
caught the ZLINKFILE and called `disable("fault")` — fail-safe (broker untouched)
but silent: capture never worked.

**Fix (remove crypto from the capture path entirely).** Per the design decision
(2026-06-25): the RPC tap **only observes** plain-ASCII broker traffic — it does
NOT harden the broker or its traffic, so it must not add a crypto "feature" VistA
itself doesn't have. RPCs are encrypted only once they land in the S3 bucket under
PHI controls. So `write1rec` no longer hashes at all: `set hash=""`, no `"hc"`
node. The capture hot path is now dependency-free (portable to IRIS / any engine
without the m-stdlib callout) and can never self-disable on a missing crypto dep.

**Why this is safe (the stored capture-time hash was DEAD):** nothing downstream
read it. The integrity anchor `payload_sha256` is (re)computed ONCE at egress —
`envelope^VSLS3` does `env("payload_sha256")="s:"_$$sha256^STDCRYPTO(raw)` from the
raw bytes at the S3 boundary, which `VSLTAPFC.verify` checks for round-trip
fidelity. The capture-time hash + header piece-18 + `hc` node were redundant and
never consulted. (This supersedes the earlier best-effort `$$hashOf^VSLTAP`
approach — that helper has been deleted.)

**TDD:** `tCaptureIsCryptoFree` (VSLTAPV2TST) — `$$appendRec` returns 1,
`$$disabled`="", no `hc` node (`$data(...,"hc")=0`), header piece-18 empty.
Red→green; **137/0** across VSLTAPTST/V2/RPCWRAP/FC on m-test-engine. `dist/kids/
VSL.kids` regenerated (drift gate green).

**Egress hash ALSO removed (2026-06-25, owner directive):** the tap captures raw
real RPC traffic with NO embellishments — only required features. Hashing is not
required (RPCs are plain ASCII the tap only observes; encryption/integrity is the
S3 PHI-controlled boundary's job, not the tap's), so `payload_sha256` is gone from
the `VSLS3` envelope too. `$$verify^VSLTAPFC` (intrinsic re-hash) and the
tamper-detection tests are deleted; `$$matches`/`$$reconcile` prove fidelity by
BYTE-EQUALITY against the captured source (the required, crypto-free proof).
`fidelityNow^VSLTAPRUN` now confirms each readback parses as a well-formed
envelope (no crypto). **v-stdlib's tap is now fully STDCRYPTO-free.** See
[[egress-hash-removed]].

**Still owed (live CPRS smoke):** deploy the fixed VSLTAP to vehu (via `v pkg
install --auto-snapshot` — the new class-aware patch path), re-splice the broker
(`wrap-rpc install --commit`; it is currently spliced:False per [[verify-drift]]),
run `scripts/rpc-tail.sh`, click CPRS tabs. Blocked only by the shared-engine
write-guardrail (mutating installs on vehu need explicit go-ahead). The capture
fault itself is RESOLVED. See `docs/prompts/debug-live-capture-fault.md`.
