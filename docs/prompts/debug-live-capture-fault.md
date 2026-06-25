# Resume prompt — debug the live RPC-tap capture fault on vehu (FU-5 5B.2 live validation)

> **RESOLVED 2026-06-25 — root cause + fix landed.** The fault was
> `write1rec^VSLTAP` calling `$$sha256^STDCRYPTO` unconditionally while **STDCRYPTO
> is not installed on vehu** (`%YDB-E-ZLINKFILE, File STDCRYPTO.m not found`;
> `VSL*1.0*3` shipped only the `VSL*` routines). The append fence caught it →
> `disable("fault")`. Fix: best-effort `$$hashOf^VSLTAP` (hash only when crypto is
> usable, else `""`) — a missing crypto dep no longer disables capture. TDD
> red→green, 136/0. See `docs/memory/live-capture-fault-stdcrypto.md`.
>
> **Only the live CPRS smoke remains** (needs a mutating deploy to the shared vehu
> engine → explicit go-ahead): (1) `v pkg install --auto-snapshot` the fixed
> VSLTAP onto vehu; (2) `v pkg wrap-rpc install --commit` to re-splice the broker
> (currently `spliced:False`); (3) `scripts/rpc-tail.sh` + click CPRS tabs.

**Paste the section below into a fresh session started in `~/vista-cloud-dev/v-stdlib`.**

---

## Task

The v-stdlib RPC traffic tap is installed on the **vehu** YDB-VistA engine (patched
broker `XWBBRK` shipped as `VSL*1.0*3`, status 3; the two `VSLRPCWRAP` side-calls
are spliced into `CALLP^XWBBRK`). But **live capture self-disables with reason
`"fault"`** the moment a real RPC flows: `$$disabled^VSLTAP()="fault"`,
`^VSLTAP("_offwindows",1)="67746,60276^fault^"`, and `$$captureOn^VSLTAP()` then
returns 0 (fail-safe auto-failover). The ring never fills, so `rpc-tail.sh` shows
nothing when CPRS tabs are clicked.

**Goal:** find the runtime error that trips the fence, fix the VSL routine, re-test,
then complete the live CPRS smoke (click tabs in the VirtualBox `win10_x64` CPRS →
watch `scripts/rpc-tail.sh` print req/resp records live).

## Why it's hard to see (the core gap)

The capture path is **self-fenced to never touch the broker**: `$$teeRec^VSLTAP` →
`$$appendRec` → `write1rec`. The fence is:

```m
set $etrap="set ok=0,$ecode="""" quit"   ; first pass: swallow, mark not-written
...                                       ; (write1rec runs here)
set $etrap=""                             ; second pass (DO frame unwound)
do disable("fault")                       ; <- records reason="fault", NOT $ZSTATUS
```

So we get `disabled="fault"` but **the actual error text ($ZSTATUS) is thrown
away**. `reqWork^VSLRPCWRAP` *also* has `set $etrap="set $ecode="""" quit"`. Closing
this diagnostic gap is step 1.

## Plan

1. **Confirm the fault state** (driver stack only — see rules below):
   `m vista exec --engine ydb` →
   `S U="^" W $$disabled^VSLTAP(),"|",$G(^VSLTAP("_offwindows",1))`

2. **Add a TEMPORARY $ZSTATUS capture** so the swallowed error is recorded. In
   `src/VSLTAP.m`, in BOTH fault fences (`append` and `appendRec`), before
   `do disable("fault")` add:
   `set ^VSLTAP("_lastfault",$horolog)=$ZSTATUS`
   (and consider one in `reqWork^VSLRPCWRAP`'s trap too). This is debug-only
   instrumentation — **remove it before the final commit** (or keep behind a
   `$$cfg("capturefaulttrace",0)` knob if it proves generally useful; decide at the
   end). Rebuild + reinstall the patched routines onto vehu via the v-pkg installer
   (NOT raw docker — see rules).

3. **Drive one real RPC through the splice** and read the trace:
   - Either click a tab in live CPRS, or fire a synthetic call via `m vista exec`:
     set the broker process vars the wrap reads (`XWB(2,"CAPI")`, `XWBSEC`,
     `XWB(3,"P",*)`, `XWBPTYPE`, `XWBP`, `DUZ`, `XWBTIP`, `XWBTSKT`), the config
     (`^VSLTAP("cfg","s3station")="500"`), `do arm^VSLTAP(),setConsumer^VSLTAP(1)`,
     then `do req^VSLRPCWRAP()` and `do resp^VSLRPCWRAP()`.
   - Read `^VSLTAP("_lastfault",*)` → the real `$ZSTATUS`. **That error is the bug.**

4. **Root-cause candidates to check** (the fence hides which one):
   - A global reference inside the capture path executing under vehu's real
     environment where a var the wrap reads is undefined in a way `$GET` doesn't
     cover (e.g. an unsubscripted `XWB` vs `XWB(...)` shape mismatch on real broker
     state vs the test fixture).
   - `$$callId^VSLRPCTAP` / `$$cfg^VSLTAP` / `$$nakedRef^VSLRPCTAP` behaving
     differently on the live naked-indicator state than in the bare-ydb fixture.
   - `^XTMP("VSLTAP")` ring root not initialized / a `$ZCHSET`/encoding issue on the
     real payload bytes (CPRS sends real wire data; tests use ASCII fixtures).
   - A `setConsumer`/`s3station` cfg node missing on vehu so a downstream egress
     path errors (note from prior session: synthetic `req^VSLRPCWRAP` gave an empty
     record until `setConsumer^VSLTAP(1)` + `^VSLTAP("cfg","s3station")` were set).

5. **Fix the VSL routine** (TDD: add a `VSL*TST.m` test that reproduces the fault
   shape against a bare engine first → red → fix → green). Keep IRIS-portable.

6. **Re-run** step 3; confirm `$$captureOn^VSLTAP()=1` stays 1 and the ring fills.

7. **Live smoke:** start `scripts/rpc-tail.sh`, click CPRS tabs in the VM, confirm
   req/resp records stream. This closes the owed **FU-5 5B.2 live validation**.

8. **Clean up:** remove the temporary `_lastfault` instrumentation (or gate it),
   run gates (`make check-fast` + `make test`), commit per the Increment Protocol.

## Hard rules (do not violate)

- **Engine access through the driver stack ONLY.** Use `m vista exec --engine ydb`,
  `m test --engine ydb --docker vehu`, `m coverage`, or the v-pkg installer. **NEVER**
  `docker exec vehu … mumps` / bare `mumps -direct` — the `engine-stack-guard.sh`
  PreToolUse hook DENIES it and org `m-ci.yml` red-gates it.
- **Env for `m vista exec` against vehu:** `M_YDB_CONTAINER=vehu`,
  `M_YDB_ROUTINES=<vehu gtmroutines>`, `M_YDB_GBLDIR=/home/vehu/g/vehu.gld`. In the
  exec body `S U="^"` first (no VistA signon env, `U` is undefined otherwise).
- **Reinstall patched routines** via the v-pkg installer
  (`~/vista-cloud-dev/v-pkg/dist/v-pkg` — the NEWER build; the v-cli `dist/v` had an
  older pkgcli that rejected `allowLongNames`). Build artifact = the patched-XWBBRK
  KIDS (`VSL*1.0*3`).
- **Stock broker backup** (for restore if needed): `XWBBRK.stock.m` was dumped to a
  scratchpad before patching; if gone, read stock via `v pkg wrap-rpc status` or the
  `readRoutineSource` path — do not hand-edit the live routine.

## Key files / context

- `src/VSLRPCWRAP.m` — `req()/resp()/reqWork()/respWork()/result()/ctx()/params()`.
  The fence pattern + the broker vars it reads are documented in its header.
- `src/VSLTAP.m` — the ring + gates: `append()/appendRec()/write1()/write1rec()`
  (the fault fences live here), `disable()/disabled()/rearm()`, `captureOn()`,
  `cfg()`. Fault-injection seams: `$$cfg("faultinject")` / `"faultinjectpost"`.
- `src/VSLRPCTAP.m` — `$$nakedRef`, `$$callId`, the FU-4 caller-state fence helpers.
- `scripts/rpc-tail.sh` — live ring viewer (tails `^XTMP("VSLTAP")` via `m vista exec`).
- Memory: `docs/memory/fu5b2-xwbbrk-wrapsplice.md` (the splice + install history).
- Splice doc: `docs/discoveries/fu-5b-callp-splice.md`.

## Definition of done

- Root cause of the `"fault"` identified (the real `$ZSTATUS`) and recorded in memory.
- VSL routine fixed with a regression test; gates green on both engines if portable.
- Live CPRS tab-clicks stream req/resp records through `rpc-tail.sh` (the smoke test
  the whole FU-5 effort was for).
- Temporary instrumentation removed/gated; increment committed + pushed.
