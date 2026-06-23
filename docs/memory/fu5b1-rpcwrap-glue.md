---
name: fu5b1-rpcwrap-glue
description: Traffic-tap FU-5 increment 5B.1 — the VSLRPCWRAP broker-dispatch wrap glue + the live CALLP^XWBBRK splice re-pin (bare-engine TDD; the live install + non-interference proof are 5B.2)
metadata:
  type: project
---

# FU-5 increment 5B.1 — VSLRPCWRAP broker glue + splice re-pin

**DONE 2026-06-23.** The bare-engine, TDD-able half of FU-5 5B. The live patched-XWBBRK
KIDS install + the non-interference proof + FU-21 are **5B.2 (next)**. Stacked on the 5A
capture path [[fu5a-schema-v1-capture]]; shared running memory [[rpc-traffic-s3-streaming-proposal]].
Splice design: `docs/discoveries/fu-5b-callp-splice.md` (docs repo).

## Built — `src/VSLRPCWRAP.m` (the glue the splice calls)

A thin `v` routine so the national-code diff is exactly **two `D` lines**; all broker-var
reading + rec-building lives here (FU-21 re-validates it independently of XWBBRK).
- `req()` / `resp()` — the two fenced side-calls. Each **owns the FU-4 fence** (reusing
  `$$nakedRef^VSLRPCTAP`), gates on `$$captureOn^VSLTAP` from inside it, builds a schema-v1
  record descriptor, and tees via `$$teeRec^VSLTAP`.
- `req`: `dir=req`, `rpc`=XWB CAPI node, `payload`=`XWB(3,"P",*)` `$C(1)`-joined verbatim
  (no typing), `denied`=`+$L($G(XWBSEC))`, FU-18 context (DUZ/$J/XWBTIP:XWBTSKT).
- `resp`: `dir=resp`, reuses the call_id, classifies the result by **`XWBPTYPE`**
  (1=scalar→`XWBP` verbatim; 2/3=table/WP→`gref="XWBP"`; 4=global→`gref=$G(XWBP)` the
  closed-root ref) — FU-17's one in-path MERGE.
- Correlation: a **`$J`-scoped LOCAL** counter `VSLWCC` bumped once per RPC in `req`;
  `VSLWCID` (the call_id) reused by `resp`. Locals → naked-ref-free; VSL-namespaced so a
  future XWB patch can't collide.

## The splice (re-pinned live, byte-identical YDB↔IRIS)

`CALLP^XWBBRK`: `req` **after :153** (denial known — `XWBSEC` set at the `CHKPRMIT^XWBSEC:152`
check; the only point that sees a deny); `resp` **inside the :155 `IF…D` success block after
the :158 `CAPI` call** (success path only; before :160 `K XWB`).

### Load-bearing design decisions / gotchas
- **The splice line is UNCONDITIONAL (`D req^VSLRPCWRAP`), NOT `D:$G(^flag) req^…`.** A
  global-flag guard in the broker line would move the broker's **naked indicator** to the
  flag global *before* the FU-4 fence runs → corrupts the broker's next naked reference. A
  plain `DO routine` is naked-ref-neutral, so the wrap entry owns the fence and reads the
  enable gate from inside it. (This is why `req`/`resp` re-implement the ~4-line fence
  skeleton rather than relying on a guard or on capture's fence — they must read globals,
  the gate + cfg station, *after* saving the naked indicator.)
- **`XUS SET SHARED` (`CALLP^XWBBRK:148`) early-`Q`s before :153** → never captured (a
  documented coverage gap; session-setup RPC, low value).
- **FU-18 var scope:** `XWBTIP`/`XWBTSKT`/`DUZ` are formal params of `EN^XWBTCPC:17`
  (ancestor frame → process scope at the wrap); `XWBPTYPE` is set at `PRSA^XWBBRK:76`.
  Read directly. Empirical live confirm still owed at install (5B.2).
- **TEST GOTCHA (cost me a debug loop):** in M, a `"` inside a string literal is escaped by
  **doubling** (`""`), NOT C-style `\"`. A `\"` in an assertion **desc** terminated the
  string → the whole test routine failed to COMPILE → `m test` showed **0/0** (suite
  aborted, not a per-assertion fail) and `m lint` did **not** catch it. When a suite reports
  0/0, suspect a compile error (a raise before `report^STDASSERT`), and note the harness
  hides assertion `desc`/values — trap `$ZSTATUS` into a global or assert on observable
  state to localize it.

## Verification
`VSLRPCWRAPTST` simulates the live broker by setting its process vars, then drives req/resp.
Proves: dir=req/resp records, denied flag, req↔resp call_id correlation, scalar + GLOBAL-ARRAY
(one MERGE, byte-equal snapshot), counter-per-RPC, and the **naked-indicator preservation**
property (the probe idiom from VSLTAPFENCETST). **Dual-engine 33/33; full bare suite green
both engines; IRIS coverage 98.2% on VSLRPCWRAP; all engine-free gates + KIDS (now 15
routines) + namespace registry green.**

## NEXT: FU-5 5B.2
Patched-`XWBBRK` KIDS artifact (whole routine + the two `D` lines) → live install over the
driver path (M0a pattern) → non-interference proof vs the REAL dispatch (IRIS first; wrap
ON/OFF byte-identical + FU-4 property + bounded resource deltas) → FU-21 (restore-to-stock
`CALLP` + per-XWB-patch re-pin hook).
