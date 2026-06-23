---
name: fu4-naked-ref-fence
description: Traffic-tap FU-4 — the R-NAKED $REFERENCE/$ZREFERENCE fence in capture^VSLRPCTAP; the dual-engine naked-ref SVN gotcha (YDB $REFERENCE vs IRIS $ZREFERENCE) + XECUTE workaround.
metadata:
  type: project
---

**RPC→S3 traffic tap — FU-4 (R-NAKED fence) DONE 2026-06-23, branch
`s3tap-fu4-naked-ref-fence`, unmerged.** The correctness keystone of the tap (spec
§6.1.1; plan §12.1 FU-4 + AC-1…AC-7). The tap's in-path `^XTMP` SETs **mutate the
caller's naked reference**, so without a restore the wrapped RPC's next `^(sub)` would
silently hit `^XTMP` — a silent, patient-safety-adjacent corruption. The fence saves the
caller's naked indicator at the `capture^VSLRPCTAP` boundary and re-establishes it on
**every** exit (success, gated, swallowed fault) via one benign full reference
`set zz=$data(@nref)` — the LAST global op before return.

**NON-OBVIOUS GOTCHA — the naked-reference SVN name DIFFERS BY ENGINE (5th cross-engine
gotcha in this tap; see [[phase2-vsltap]] for the DO-frame + `new $test` ones).** The
plan assumed "`$ZREFERENCE` on both engines" — **WRONG**. Probed live on the bare
engines:
- **YDB** (m-test-engine, r2.07): the naked indicator is **`$REFERENCE`**. `$zreference`
  → `%YDB-E-INVSVN Invalid special variable name` (it links OK but throws at RUN time —
  YDB defers SVN validation to runtime). `$zr` is a different (numeric) ISV — NOT the ref.
- **IRIS** (m-test-iris): the naked indicator is **`$ZREFERENCE`** (Caché/ObjectScript
  spelling). It does not accept `$REFERENCE`.

Neither engine reliably compiles the other's token, so a literal-SVN `$select` arm risks
a load failure on the wrong engine. **Solution: read the SVN via `XECUTE`** of an
engine-selected assignment, so no literal SVN token is compiled into the routine:
```
nakedRef()  ; (private) caller's last global ref, dual-engine; "" at job start
 new nr,cmd set nr=""
 set cmd="set nr="_$select($zversion["IRIS":"$zreference",1:"$reference")
 xecute cmd
 quit nr
```
XECUTE keeps the current naked-reference context and a function call does not reset it,
so this returns the CALLER's last reference. (Init `nr=""` first — the linter can't see
the XECUTE define it: M-MOD-024.) **Engine-neutral → a candidate to promote to an
m-stdlib `STD*` primitive** (e.g. `$$nakedRef^STDSYS`) since `$zversion["IRIS"` forking
recurs; filed as a follow-up, not done here (leaf-first sequencing).

**Fence structure (`capture^VSLRPCTAP`):** save `$TEST` (by hand — `new $test` aborts on
IRIS) + `nref=$$nakedRef()` at entry (before any global ref) → `do work($get(rec))`
(the global-touching tee, in a **DO-framed** sub with its own swallowing `$ETRAP` — MUST
stay `do`-invoked, never `$$`, or the arg-less QUIT trap raises M17 NOTEXTRINSIC) →
**finally:** `if nref'="" set zz=$data(@nref)` (restore naked ref, last global op), then
`if t` (restore $TEST). The `nref'=""` guard handles a job-start empty indicator (AC-2).

**Test = `VSLTAPFENCETST` (TDD red→green), in `BARE_TESTS`.** Probe technique: after the
fenced call do ONE naked reference `set ^(N)=...` and snapshot WHERE it landed into a
LOCAL **before** any STDASSERT call (asserts touch globals). A new **post-write**
fault-injection seam in `write1^VSLTAP` (`faultinjectpost`, inert unless configured)
fires AFTER the `^XTMP` SET so AC-1 proves restore even once the tap dirtied the
indicator. **Dual-engine GREEN: 12/12 on YDB AND IRIS** (incl. the IRIS extended/
namespace-ref case AC-7); full bare suite **186/186** both engines, no regression; lint/
fmt/arch green; **IRIS coverage 98%** (VSLRPCTAP 16/17, VSLTAP 96/97). NB: YDB's coverage
collector returns 0 in m-test-engine (env limitation — measure coverage on IRIS).

**Documented limitation:** AC-7 extended/namespace-ref restoration is exercised on
**IRIS only** (current-namespace `^|"nsp"|...`); YDB extended-*region* refs are a no-op
placeholder pass — so the bit-identical R-NAKED guarantee for extended refs is scoped to
IRIS (the primary engine). Revisit if a YDB-VistA extended-region ref must be proven.

**Gates FU-5** (the XWB wrap at `CALLP^XWBBRK`): per the schema-lock + plan §12.1.1,
FU-5 must not merge until AC-1…AC-7 are green — now they are. Shared workstream memory:
[[rpc-traffic-s3-streaming-proposal]] (docs repo). Next build step: FU-8 (atomic
`$INCREMENT` seq) + FU-9 (always-on ring / egress-gate split) before the wrap.
