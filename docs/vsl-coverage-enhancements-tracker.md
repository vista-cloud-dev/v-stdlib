---
title: "VSL* coverage & wrapping enhancements — resume tracker"
status: proposed
created: 2026-06-28
last_modified: 2026-06-28
revisions: 1
doc_type: [PROPOSAL]
scope: the post-baseline enhancement backlog for the 6 VSL* modules (missing wrapped-API verbs, coverage-model test categories, corpus re-extraction, residual doc-accuracy items)
---

# VSL* coverage & wrapping enhancements — resume tracker

Live tracker (Tier D) for the **enhancement** work that follows the
[VistA library wrapping baseline](proposals/vista-library-wrapping-baseline.md). The
baseline's four **High defects are all CLOSED** (VSLSEC, VSLIO, VSLFS, VSLTASK —
green dual-engine). What remains is enhancement, not defect: complete the wrapped-API
surface, raise test coverage to the baseline's model, and clean up provenance.

---

## ▶ Resume prompt (paste into a NEW session, cwd `~/vista-cloud-dev/v-stdlib`)

> Resume the v-stdlib wrapping-baseline **enhancement** work. The four High defects
> are already fixed (see `docs/vsl-coverage-enhancements-tracker.md` + the baseline
> `docs/proposals/vista-library-wrapping-baseline.md`). Read those two docs and the
> memories `docs/memory/vsl-wrapping-baseline-audit.md` + `MEMORY.md` first.
>
> Then work the backlog below **in priority order, one increment per item, TDD**:
> write the test first (confirm red), implement, confirm green on **both** engines,
> regenerate artifacts, bump the KIDS patch, `make check-fast`, then run the
> Increment Protocol (memory + this tracker + commit/push to `main`). Start with
> **P1 (coverage-model test backfill)** unless I say otherwise — it hardens what
> exists before adding new surface.
>
> Hard constraints (all verified-working this session): engine access ONLY via the
> driver stack — `m test --engine ydb --docker vehu --chset m --routines src
> --routines ../m-stdlib/src tests/<SUITE>` and `m test --engine iris --docker
> foia-t12 --namespace VISTA --routines src --routines ../m-stdlib/src tests/<SUITE>`
> (never raw `docker exec`). No redundancy (R6): suite = sole assertions, `@example`
> = call-shape one-liner, `@illustrative` = non-demonstrable. To assert a call does
> NOT raise, use the engine-split `$$safeRun` helper already in `VSLSECTST.m` (plain
> `eq^STDASSERT` of a raising call aborts the whole suite 0/0). Stay off
> `.github/workflows/ci.yml` (owned by another session). `m` = `../m-cli/dist/m`,
> `v-pkg` = `../v-pkg/dist/v-pkg`.

---

## Status snapshot (2026-06-28)

- **Audit + 4 High fixes DONE:** VSLIO IRIS write flush (`0acedb0`), VSLSEC
  default-duz (`c56df66`), VSLFS internal-doc + lock-in test (`f0df013`), VSLTASK
  `when="@"` + un-KILLable wording (`c258fca`). KIDS patch at **19** (P1b→14 … P2-iii→18, P2-iv→19).
- **P1a exact-ecode DONE 2026-06-29:** every `raises^STDASSERT` across all six
  suites tightened from loose prefix (`"U-VSL-<MOD>"`) to the full delimited code
  (`",U-VSL-<MOD>-<OP>,"`) + a `$ECODE`-clears post-condition. All passed first run
  (no hidden defect — each routine raises exactly its declared code).
- **P1b default-arg DONE 2026-06-29:** found + fixed a VSLSEC-class UNDEF — VSLCFG
  `$$get`/`$$getEffective` evaluated an omitted `default` raw
  (`$select(v="":default,...)`) → UNDEF on an unset param with no default. Guarded
  with `$get(default)`; `tGetOmittedDefaultIsEmpty` added (TDD red→green). KIDS
  patch **13→14**, artifacts regenerated.
- **P1c boundary (2 of 3) DONE 2026-06-29:** VSLFS ambiguous-`$$find`
  (`tFindAmbiguousIsEmpty`) + VSLLOG 80-char HOST truncation (`tHostTruncatedTo80`)
  boundary tests added — existing-correct behavior confirmed, no src change. VSLCFG
  empty-vs-unset deferred (XPAR `""` semantics need a live probe).
- **P1d volume/residue DONE 2026-06-29:** VSLFS `$$list` + VSLLOG `$$query` volume
  tests (count integrity + `^TMP("DILIST",$job)` zero-residue). The `$$query` volume
  test (dates omitted) **revealed a 3rd systemic UNDEF** — `query` referenced
  undefined `event`/`fromDt`/`toDt` formals; fixed by `set event=$get(event),...` on
  the first line. KIDS patch **14→15**.
- **P1e de-circularize DONE 2026-06-29:** VSLCFG `tGetEffectiveResolvesSys` no longer
  a tautology — asserts against known literals, with a real ALL→SYS regression branch.
  **P1 now COMPLETE** (only VSLCFG empty-vs-unset deferred, needs a live XPAR probe).
- **P2-i askStop DONE 2026-06-29:** `$$askStop^VSLTASK(ztsk)` over `$$ASKSTOP^%ZTLOAD`
  (ICR 10063) — the WRITE side of the cooperative stop. Arg-gate raises `,U-VSL-TASK-ARG,`;
  live-callable smoke test on both engines; the ask-a-real-task success path is
  soft-skipped (side-effecting, same posture as `$$persist`/`$$schedule`). KIDS 15→16.
- **P2-ii stat+pclear DONE 2026-06-29:** `$$stat^VSLTASK` over `STAT^%ZTLOAD`
  (read-only, returns the 0..5 status code; absent task = 0) and `pclear^VSLTASK` over
  `PCLEAR^%ZTLOAD` (void inverse of `$$persist`). VSLTASK P2 verbs complete. KIDS 16→17.
- **P2-iii active DONE 2026-06-29:** `$$active^VSLSEC(duz)` over `$$ACTIVE^XUSER`
  (ICR 2343) — fail-closed authz active-status check. KIDS 17→18.
- **P2-iv gets DONE 2026-06-29:** `$$gets^VSLFS(file,iens,fields,.out,flags)` over
  `GETS^DIQ` (ICR 2056) — whole-record/multi-field read, one round-trip, scalar flatten.
  KIDS 18→19.
- **All six suites green dual-engine** (vehu YDB + foia-t12 IRIS): VSLCFG 10/10,
  VSLFS 29/29, VSLIO 11/11, VSLLOG 22/22, VSLSEC 21/21, VSLTASK 21/21 (116 total).
- Gates: `make check-fast` green; lint 0 findings.

---

## Backlog (priority order)

### P1 — Coverage-model test backfill (highest ROI; hardens existing surface) — ✅ COMPLETE 2026-06-29 (1 item deferred: VSLCFG empty-vs-unset)
Apply the baseline's coverage model + stress policy to **all six** `VSL*TST.m`
suites. Each is an orthogonal NEW assertion (R6: do not restate happy-path):
- **✅ DONE 2026-06-29 — Exact-ecode, not prefix.** Tightened every
  `raises^STDASSERT(...,"U-VSL-<MOD>",...)` to the full `,U-VSL-<MOD>-<OP>,` code +
  a `$ECODE`-clears post-condition (execution-continues was already covered by the
  existing `$$lastError'=""` follow-ons, so not duplicated — R6). Sites: VSLCFG
  `tSetFailureIsLoud` (`,U-VSL-CFG-SET,`), VSLLOG `tWriteFailureIsLoud`
  (`,U-VSL-LOG-WRITE,`), VSLFS `tDierrIsLoud` (`,U-VSL-FS-DIERR,`), VSLIO
  `tTlsGapIsLoud` (`,U-VSLIO-NOTLS,`), VSLSEC hasKey+bySecid (`,U-VSL-SEC-ARG,`),
  VSLTASK persist+schedule (`,U-VSL-TASK-ARG,`). All green first run, dual-engine.
- **✅ DONE 2026-06-29 — Default-arg / contract-shape.** VSLCFG omitted-`default`
  was a real VSLSEC-class UNDEF (now fixed; `tGetOmittedDefaultIsEmpty`). VSLTASK
  omitted-`when` arg-shape is already safe (`$get`-guarded in `schedule`/`queue`;
  the omit path is exercised by `tScheduleRejectsBadArg`, and the success path is the
  soft-skipped live queue) — no new test needed (R6). VSLSEC was already done
  (`tHasKeyDefaultsDuz` etc.). ("omitted-format for VSLCFG" was a misnomer — the
  real contract-shape gap was the omitted `default`.)
- **🔶 PARTIAL 2026-06-29 — Boundary / ambiguous / absent.** ✅ VSLFS ambiguous
  `$$find` (>1 match → "", `tFindAmbiguousIsEmpty`); ✅ VSLLOG 80-char HOST
  truncation (`tHostTruncatedTo80`, the `$extract(...,1,80)` path). ⏳ DEFERRED:
  VSLCFG empty-stored vs unset — XPAR's `""` semantics (store-empty vs delete) are
  engine/filer-dependent; needs a live probe to pin down before asserting (not
  guessed).
- **✅ DONE 2026-06-29 — De-circularize** VSLCFG `tGetEffectiveResolvesSys`. Was a
  tautology (`getEffective == $$GET^XPAR("ALL")`, the very call it wraps). Now reads
  `ALL` once and asserts `getEffective` against a KNOWN literal, branching on the
  resolution: `seen="howdy"` (SYS participates), `seen=""` (SYS omitted → must be the
  default, NOT the SYS value — the genuine ALL→SYS regression catcher), or a dominant
  higher level. The regression branch only fires when setup picks a SYS-omitting
  param (documented; engine/param-dependent).
- **✅ DONE 2026-06-29 — Volume / residue** for the listers: VSLFS `$$list`
  (`tListVolumeNoResidue`) + VSLLOG `$$query` (`tQueryVolumeExactCount`) with 5
  throwaway records — count integrity + `^TMP("DILIST",$job)` zero-residue asserted.
  Found + fixed the `$$query` omitted-optional UNDEF (event/fromDt/toDt) in passing.

### P2 — In-scope missing wrapped-API verbs (each its own TDD increment)
- **✅ VSLTASK COMPLETE 2026-06-29** (the stop/retire/observe half is now bound):
  ✅ `$$askStop` over `$$ASKSTOP^%ZTLOAD` (P2-i); ✅ `$$stat` over `STAT^%ZTLOAD`
  (read-only status code 0..5; absent task → deterministic 0; P2-ii); ✅ `pclear`
  over `PCLEAR^%ZTLOAD` (void inverse of `$$persist`; P2-ii). All ICR 10063, Supported.
  Arg-gate raises tested for each; the live success paths (ask/clear a real task) are
  soft-skipped (side-effecting); `$$stat` undefined-task probe is asserted live (read-only).
- **VSLFS:** ✅ `$$gets` over `GETS^DIQ` DONE 2026-06-29 (P2-iv) — whole-record /
  multi-field read in one DBS round-trip (ICR 2056, Supported); flattens top-level
  SCALAR fields into `out(field)=value`, default external / `"I"` internal; DIERR →
  `,U-VSL-FS-DIERR,`. ⏳ `$$setWp`/WP support over `WP^DIE` (word-processing fields
  can't be filed through the scalar signature today) — still open; `$$gets` is
  explicitly scoped to scalar fields (WP/sub-multiple out of scope).
- **✅ VSLSEC `$$active` DONE 2026-06-29 (P2-iii):** over `$$ACTIVE^XUSER` (ICR 2343,
  Supported) — `+` collapses ""/0/0^DISUSER/0^TERMINATED to 0, 1^NEW/1^ACTIVE to 1;
  fail-closed (absent routine → 0). Read-only, so the non-existent-IEN deny (→0) is
  asserted live deterministically; the postmaster (IEN 1) clean-boolean smoke confirms
  the live binding. An authz decision now denies terminated/`DISUSER`'d principals even
  if a stale `^XUSEC` xref lingers.
- **VSLCFG:** `$$delete`/`$$unset` over `EN^XPAR("SYS",key,1,"@")` — the read/**write**
  scalar seam can't clear a value today (`DEL^XPAR` gap). (Entity-aware verbs stay
  deferred to a future `VSLPARM`.)

### P3 — Provenance / corpus cleanup
- **GOLD-corpus empty-body anchors** (systematic): all five VSLFS DBS anchors
  (`updatedie-updater`, `get1diq…`, `filedie-filer`, `find1dic…`, `listdic-lister`),
  `VSLCFG set()` (`enxpar-add-change-delete-parameters`), `VSLLOG $$NOW^XLFDT`,
  `VSLTASK queue()` resolve but return empty text → `@status Supported` not
  corpus-confirmable. One **vdocs pipeline re-extraction** task (cross-repo: vdocs),
  or repoint each to a citable sibling (e.g. a `#example-N`).
- **VSLIO doc-accuracy:** reconcile `CALL^%ZISTCP` positional `(host,port,timeout)`
  call vs the cited input-variable (`IPADDRESS/SOCKET/TIMEOUT`) convention; mark TLS
  ICRs **#7616/#7617** unverified (routines exist in corpus; numbers don't) or back
  from an ICR registry.
- **VSLCFG doc-accuracy:** soften the `#^errortext` / DIALOG #.84 prose (corpus backs
  only "by-reference, >0 = failure").
- **VSLFS ICR-note:** FileMan DBS calls DO have real published ICRs (e.g. 10150) —
  the "notional" wording understates it.
- **VSLTASK ASKSTOP return (corpus vs live):** the corpus documents `$$ASKSTOP^%ZTLOAD`
  as returning 0/1/2 (incl. 1 = "task missing"), but on BOTH live engines an
  absent/never-scheduled task returns a different, undocumented multi-char value (found
  while adding `$$askStop`, P2-i). The adapter's `@returns` documents the 0/1/2 contract
  for a KNOWN task and scopes the absent-task value as engine-specific. Lesson: verify
  return-value contracts against the live engine — corpus code enumerations may not cover
  edge inputs.

### P4 — Unresolved factual discrepancy to settle
- **`KILL^%ZTLOAD` vs persistent tasks.** The corpus `KILL^%ZTLOAD` contract
  documents only success/invalid-task (no persistence exemption), but
  `docs/memory/m5-vsltask-vslbld.md` carries a *code-derived* claim that `KILL`
  refuses a persistent task (`I $D(^%ZTSCH("ZTSK",ZTSK,"P")) Q`). VSLTASK.m's doc was
  left **neutral** pending resolution. Verify against the live `^%ZTLOAD` routine
  (read-only) and reconcile the memory ⇄ corpus ⇄ doc.

---

## Working constraints (carry into every increment)
- **Engine access via the driver stack only** (commands in the resume prompt above).
  Raw `docker exec` is harness-DENIED.
- **TDD hard rule**, **dual-engine green** before commit, **R6 no-redundancy**,
  **waterline** `v→m`. Bump the KIDS patch on any `src/*.m` change; regenerate
  (`make icr manifest docs-bodies frontmatter examples skill kids`) and `git add` the
  artifacts (drift gates diff against the index).
- **Increment Protocol per item:** memory (`docs/memory/`, update the audit file or a
  per-effort file) + this tracker + commit/push to `main`. Archive this tracker to
  `docs/archive/` when the backlog is exhausted.
- **One session ↔ one repo:** P3's corpus re-extraction and the v-pkg `#999000`
  DATE-field option are **cross-repo** (vdocs / v-pkg) — do them in those repos'
  sessions, not here.
