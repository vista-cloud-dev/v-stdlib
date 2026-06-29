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
  `when="@"` + un-KILLable wording (`c258fca`). KIDS patch at **14** (P1b bump).
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
- **All six suites green dual-engine** (vehu YDB + foia-t12 IRIS): VSLCFG 10/10,
  VSLFS 19/19, VSLIO 11/11, VSLLOG 19/19, VSLSEC 19/19, VSLTASK 10/10.
- Gates: `make check-fast` green; lint 0 findings.

---

## Backlog (priority order)

### P1 — Coverage-model test backfill (highest ROI; hardens existing surface)
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
- **De-circularize** VSLCFG `tGetEffectiveResolvesSys` (it asserts `getEffective ==`
  the `$$GET^XPAR("ALL")` it wraps — a tautology; make it catch an ALL→SYS regression).
- **Volume / residue** for the listers: VSLFS `$$list`/`$$find`, VSLLOG `$$query`
  with N≫1 throwaway records; assert count integrity + `^TMP("DILIST",$job)` cleanup.

### P2 — In-scope missing wrapped-API verbs (each its own TDD increment)
- **VSLTASK** (sharpest — the stop/retire/observe half is absent):
  `$$askStop` over `$$ASKSTOP^%ZTLOAD` (write side of the stop signal whose read
  side `$$S` is wrapped); `$$pclear`/`$$unpersist` over `PCLEAR^%ZTLOAD` (inverse of
  the wrapped `$$PSET`); `$$stat` over `STAT^%ZTLOAD` (listener liveness). All
  ICR 10063, Supported.
- **VSLFS:** `$$gets` over `GETS^DIQ` (whole-record / multi-field read — reading a
  record currently costs N single-field round-trips); `$$setWp`/WP support over
  `WP^DIE` (word-processing fields can't be filed through the scalar signature today),
  or scope the docstring to scalar fields.
- **VSLSEC:** `$$active` over `$$ACTIVE^XUSER()` — an authz decision should deny
  terminated/`DISUSER`'d principals even if a stale `^XUSEC` xref lingers.
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
