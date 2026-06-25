---
name: live-capture-fault-stdcrypto
description: The live RPC-tap capture fault (disabled="fault" on vehu) root-caused to a missing STDCRYPTO dependency; fixed by making the payload hash best-effort.
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
but silent: capture never worked. (STDCRYPTO also needs `STDHEX` + a YDB libcrypto
C call-out, so "just install it" is non-trivial and engine-specific.)

**Fix (best-effort hash):** new private `$$hashOf^VSLTAP(data)` — returns the
sha256 only when crypto is actually usable, else `""`, so a missing/unconfigured
crypto callout NEVER disables capture (the `payload_sha256` anchor is OPTIONAL
provenance, not a capture precondition; keeps the tap portable to IRIS / engines
without the callout). Guards (each its own `IF`, no short-circuit reliance):
`'+$$cfg("payloadhash",1)` (knob, default on) → `$text(available^STDCRYPTO)=""`
(routine absent → vehu case) → `'$$available^STDCRYPTO()` (callout not loaded).
`write1rec:320` now calls `$$hashOf(pl)`.

**TDD:** `tHashBestEffortDoesNotDisable` (VSLTAPV2TST) — with `payloadhash=0`,
`$$appendRec` still returns 1, `$$disabled`="", header piece-18 (payload_sha256)
empty. Red→green; 136/0 across VSLTAPTST/V2/RPCWRAP/FC on m-test-engine (incl. the
`hashOf` @example bare-tier doc-test).

**Still owed (live CPRS smoke):** deploy the fixed VSLTAP to vehu (via `v pkg
install --auto-snapshot` — the new class-aware patch path), re-splice the broker
(`wrap-rpc install --commit`; it is currently spliced:False per [[verify-drift]]),
run `scripts/rpc-tail.sh`, click CPRS tabs. Blocked only by the shared-engine
write-guardrail (mutating installs on vehu need explicit go-ahead). The capture
fault itself is RESOLVED. See `docs/prompts/debug-live-capture-fault.md`.
