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

**Live-validated on vehu 2026-06-25 (driver stack only).** Deployed the fixed
crypto-free stack as **VSL\*1.0\*4** (`v pkg install --auto-snapshot`, status 3,
13 routines overwritten — bumped from \*3 because content changed and the \*3
#9.7 record blocked a same-patch reinstall). Cleared the stale `disabled="fault"`
state; a direct `$$appendRec` then a synthetic RPC pair through the wrap glue
(`req^VSLRPCWRAP`/`resp^VSLRPCWRAP` with the broker vars) both captured with
**`disabled=""`, `captureOn=1`** — the fault is gone. Re-spliced the broker
(`v pkg wrap-rpc install --commit` → `spliced:true`, 215 lines, stock pre-image
captured). Drove 2 RPCs → **4 ring records** (req+resp, duz=168 context, piece-18
sha **empty** = crypto-free). The ring is always-on (capture = armed AND
not-disabled, independent of consumer; consumer only gates egress). **Only the
human CPRS tab-click in the win10 VM remains** — run `scripts/rpc-tail.sh --engine
ydb --transport docker` and click. (`$$state`=UNHEALTHY is the VSLTAPHL watchdog
— stale heartbeat / no egress consumer — NOT a capture gate; self-heals on
traffic.) **A v-pkg bug surfaced + fixed:** `validRoutineName` capped names at 8
chars, blocking the 9-char `VSLHL7TAP` pre-image probe → raised to 31 (v-pkg
`ae1814f`). See `docs/prompts/debug-live-capture-fault.md`.
