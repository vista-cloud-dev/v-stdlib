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
baseline's four High defects are CLOSED, and as of **2026-06-29 P1
(coverage-model backfill), P2 (missing wrapped-API verbs), and P4 (the
`KILL^%ZTLOAD`-vs-persistent-task discrepancy) are all COMPLETE** — plus two more
UNDEF defects fixed in passing (VSLCFG `$$get` default, VSLLOG `$$query`
dates). All six suites are **121/121 dual-engine**, KIDS patch **20**. What remains is
**P3** (provenance/corpus cleanup — the in-repo doc-accuracy items are doable here;
the GOLD-corpus empty-anchor re-extraction is **cross-repo vdocs**, not this session),
plus two deferred larger items (VSLFS `WP^DIE` write-support; entity-aware XPAR verbs →
a future `VSLPARM`).

---

## ▶ Resume prompt (paste into a NEW session, cwd `~/vista-cloud-dev/v-stdlib`)

> Resume the v-stdlib wrapping-baseline **enhancement** work. **P1 (coverage-model
> backfill), P2 (missing verbs), and P4 (the `KILL^%ZTLOAD`-vs-persistent-task
> discrepancy) are all DONE** — all six suites 121/121 dual-engine, KIDS 20. Read this
> tracker + the baseline `docs/proposals/vista-library-wrapping-baseline.md` + the
> memory `docs/memory/vsl-wrapping-baseline-audit.md` + the P4 verdict in
> `docs/memory/m5-vsltask-vslbld.md` (and `MEMORY.md`) first.
>
> Work the **remaining** backlog below, one increment per item, lightest-touch first:
> only **P3** (provenance/corpus cleanup) is left for this session — the in-repo
> doc-accuracy items (VSLIO `CALL^%ZISTCP` / TLS ICRs, VSLCFG `#^errortext` prose, VSLFS
> ICR-note) are doable here; the GOLD-corpus empty-anchor re-extraction is **cross-repo
> (vdocs)** — do that in the vdocs session, not here. The two deferred larger items
> (VSLFS `WP^DIE` write-support; entity-aware XPAR → `VSLPARM`) are new-surface,
> schedule separately. (P4 verdict: the live `KILL^%ZTLOAD` persistent-task guard is
> vestigial — it tests `^%ZTSCH("ZTSK",…)` which no TaskMan routine sets, whereas PSET
> writes `^%ZTSCH("TASK",…)`; the corpus's no-exemption contract was right. To re-read
> live Kernel source: `m vista exec --engine ydb --transport docker -o text '<$text
> scan>'` with `M_YDB_CONTAINER=vehu`/`_GBLDIR=/home/vehu/g/vehu.gld`/`_ROUTINES` set —
> those YDB knobs are NOT in `auth.env`, only `M_IRIS_*` is; and use `-o text` or
> `write` output is dropped.)
>
> For any NEW verb/test, TDD: write the test first; for a brand-new verb add a
> **safe-default stub** (`quit ""`/`quit 0`/void) FIRST so red shows per-test counts —
> a missing label aborts the suite 0/0. Confirm red, implement, confirm green on
> **both** engines. On any `src/*.m` change, bump the KIDS patch and regenerate the
> WHOLE cascade — `make icr manifest kids docs-bodies skill frontmatter examples` —
> then `git add` the artifacts (drift gates diff against the INDEX), then
> `make check-fast`, then the Increment Protocol (memory + this tracker + commit/push
> to `main`).
>
> Hard constraints (all verified-working): engine access ONLY via the driver stack —
> `m test --engine ydb --docker vehu --chset m --routines src --routines
> ../m-stdlib/src tests/<SUITE>` and `m test --engine iris --docker foia-t12
> --namespace VISTA --routines src --routines ../m-stdlib/src tests/<SUITE>` (never raw
> `docker exec`). New `@icr`/`@source` tags MUST cite a GOLD-corpus anchor (the
> `check-citations` gate verifies them) — use the `corpus-researcher` agent to get
> exact contracts + anchors before writing them. **Verify API edge cases LIVE** —
> Supported VistA APIs have undocumented edge behavior (e.g. ASKSTOP's absent-task
> value, DEL^XPAR non-idempotency); don't enshrine the corpus's nominal codes. No
> redundancy (R6): suite = sole assertions, `@example` = call-shape one-liner,
> `@illustrative` = non-demonstrable. To assert a call does NOT raise, use the
> engine-split `$$safeRun` helper in `VSLSECTST.m` (plain `eq^STDASSERT` of a raising
> call aborts the suite 0/0). Stay off `.github/workflows/ci.yml` (owned by another
> session). `m` = `../m-cli/dist/m`, `v-pkg` = `../v-pkg/dist/v-pkg`.

---

## Status snapshot (2026-06-28)

- **Audit + 4 High fixes DONE:** VSLIO IRIS write flush (`0acedb0`), VSLSEC
  default-duz (`c56df66`), VSLFS internal-doc + lock-in test (`f0df013`), VSLTASK
  `when="@"` + un-KILLable wording (`c258fca`). KIDS patch at **20** (P1b→14 … P2-iv→19, P2-v→20).
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
- **P2-v delete DONE 2026-06-29:** `$$delete^VSLCFG(key)` over `DEL^XPAR` (ICR 2263) —
  clear the SYS instance, loud on failure; DEL^XPAR not idempotent (missing instance
  raises). Settles the deferred empty-vs-unset item (deleted reads as default). **P2
  effectively complete** (only the larger VSLFS `WP^DIE` write-support deferred). KIDS 19→20.
- **All six suites green dual-engine** (vehu YDB + foia-t12 IRIS): VSLCFG 15/15,
  VSLFS 29/29, VSLIO 11/11, VSLLOG 22/22, VSLSEC 21/21, VSLTASK 21/21 (121 total).
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
  VSLCFG empty-stored vs unset — ✅ SETTLED 2026-06-29 by P2-v `$$delete`: a
  cleared/deleted param reads exactly like a never-set one (`$$get` → default); XPAR
  stores no distinct empty value (the `@` sentinel deletes). See `tDeleteClears`.
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

### P2 — In-scope missing wrapped-API verbs (each its own TDD increment) — ✅ COMPLETE 2026-06-29 (1 larger item deferred: VSLFS WP^DIE write-support)
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
- **✅ VSLCFG `$$delete` DONE 2026-06-29 (P2-v):** clears the SYS instance via
  `DEL^XPAR("SYS",key,1,.err)` (ICR 2263, Supported); loud on failure
  (`,U-VSL-CFG-DEL,`, via the generalized `raiseXpar(op,...)` helper). GOTCHA: DEL^XPAR
  is NOT idempotent — deleting a non-existent instance raises (verified live; corpus
  silent on this). This also **settles the deferred empty-vs-unset P1 item**: a deleted
  param reads exactly like a never-set one (`$$get` → default); XPAR has no distinct
  stored-empty. (Entity-aware verbs stay deferred to a future `VSLPARM`.)

### P3 — Provenance / corpus cleanup — in-repo doc-accuracy ✅ DONE 2026-06-29 (corpus re-extraction still cross-repo vdocs)
The three in-repo doc-accuracy items are DONE (one increment, KIDS 20→21, all
corpus-grounded via the `corpus-researcher` agent). The GOLD-corpus empty-anchor
re-extraction stays the only open P3 item, and it's **cross-repo (vdocs)**.
- **GOLD-corpus empty-body anchors** ⏳ (cross-repo vdocs, NOT this session): all five
  VSLFS DBS anchors (`updatedie-updater`, `get1diq…`, `filedie-filer`, `find1dic…`,
  `listdic-lister`), `VSLCFG set()` (`enxpar-add-change-delete-parameters`), `VSLLOG
  $$NOW^XLFDT`, `VSLTASK queue()` resolve but return empty text → `@status Supported`
  not corpus-confirmable. One **vdocs pipeline re-extraction** task, or repoint each to
  a citable sibling (e.g. a `#example-N`). (Corpus-researcher confirmed these bodies are
  still header-only as of 2026-06-29.)
- **✅ VSLIO doc-accuracy DONE 2026-06-29:** Q1 — corpus DOES document the input-variable
  convention (`IPADDRESS/SOCKET/TIMEOUT`, bare `CALL^%ZISTCP`), but the LIVE routine is a
  procedure `CALL(IP,SOCK,TO)` invoked positionally (re-verified live: `$text(CALL^%ZISTCP)`
  = `CALL(IP,SOCK,TO)`) — our code is right, the corpus device-handler guide is stale. Header
  M-MOD-024 rationale corrected (the real lint-suppressed I/O vars are `IO`/`POP`, not the
  input vars) + a corpus-vs-live note added. Q2 — TLS ICRs **#7616/#7617 do NOT exist** in
  the corpus; the real documented TLS agreement is **RPC "XU START TLS" / `INITRPC^XUTLS` =
  ICR #7615** (XU*8*787); routine-level `INIT^XUTLS`/`ISTLSSERVERCONF^XUSUDO` carry no
  published ICR. Header + `noTlsMsg` remediation text corrected.
- **✅ VSLCFG doc-accuracy DONE 2026-06-29:** corpus supports NEITHER the `#^errortext` /
  DIALOG-#.84 form NOR even ">0 = failure" (the `.error` body is header-only). Reworded to
  the OBSERVED contract: scalar by-reference, `0`/empty success, positive = failure (what
  `$$set` enforces), explicitly noting the code-provenance is not corpus-cited.
- **✅ VSLFS ICR-note DONE 2026-06-29:** "notional" understated it — real published DBIA
  numbers exist (ROR Tech-Manual DBIA table): **LIST^DIC/FIND1^DIC = 2051, UPDATE^DIE/
  FILE^DIE = 2053, $$GET1^DIQ/GETS^DIQ = 2056**. (NOTE: **#10150 is ScreenMan `DDSUTL`,
  NOT DBS** — the earlier "e.g. 10150" guess was wrong.) Kept the `@icr DBS` marker (our
  `@source` `DI/fm22_2dg` carries the API contract, not the per-call number) but the prose
  now lists the real ROR numbers so "DBS" means "no number in the cited doc," not "no real ICR."
- **VSLTASK ASKSTOP return (corpus vs live):** the corpus documents `$$ASKSTOP^%ZTLOAD`
  as returning 0/1/2 (incl. 1 = "task missing"), but on BOTH live engines an
  absent/never-scheduled task returns a different, undocumented multi-char value (found
  while adding `$$askStop`, P2-i). The adapter's `@returns` documents the 0/1/2 contract
  for a KNOWN task and scopes the absent-task value as engine-specific. Lesson: verify
  return-value contracts against the live engine — corpus code enumerations may not cover
  edge inputs.

### P4 — Factual discrepancy to settle — ✅ RESOLVED 2026-06-29 (live read; no code change)
- **`KILL^%ZTLOAD` vs persistent tasks — SETTLED.** Read the live resident Kernel
  source over the driver (`m vista exec --engine ydb --transport docker -o text`, with
  `M_YDB_CONTAINER=vehu`/`_GBLDIR`/`_ROUTINES` exported — those YDB knobs are NOT in
  `~/data/vista-cloud-dev/auth.env`, only `M_IRIS_*` is). **Verdict: the memory's
  code-derived "`KILL` refuses a persistent task" claim is REFUTED operationally.** The
  guard `I $D(^%ZTSCH("ZTSK",ZTSK,"P")) Q` ("Don't kill running persistent tasks") does
  exist in `KILL^%ZTLOAD`, but its node `^%ZTSCH("ZTSK",n,"P")` is **read at that one
  site and set by NO TaskMan routine** (scanned `%ZTLOAD*`/`%ZTM*`/`XUTM*`) and is
  absent from the live `^%ZTSCH` even while persistent listeners run. PSET stores
  persistence at a **different** node `^%ZTSCH("TASK",n,"P")` (verified live on the HL
  AUTOSTART LINK MANAGER, task 1808). So the guard is **vestigial/dead** — the corpus's
  no-exemption contract matches observable behavior, and KILL's decline path (when it
  fired) is a silent `ZTSK(0)=0` no-op, not a raise. **No code change** — VSLTASK does
  not wrap `KILL`; VSLTASK.m's header `^%ZTSCH("TASK",n,"P")` PSET line is correct.
  Full write-up: the P4 VERDICT block in `docs/memory/m5-vsltask-vslbld.md`; audit note
  in `docs/memory/vsl-wrapping-baseline-audit.md` updated to RESOLVED. **Durable lesson:**
  verify a "the engine does X" code-derived claim against the *running* globals, not
  just the source text — a guard can test a node nothing populates.

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
- **IRIS (foia-t12) VSLFS fixture prerequisite:** `VSLFSTST` needs the throwaway
  **`#999000 ZZVSLFS` test-file DD resident** (installed via `v pkg install`, then
  backed out). As of **2026-06-29 that DD is NOT resident on foia-t12**, so an IRIS
  `VSLFSTST` run aborts **0/0 ok:false** at setup (confirmed pre-existing — HEAD `VSLFS`
  reproduces it; YDB/vehu is 29/29 because its DD persists). A `VSLFS` IRIS `0/0` while
  `VSLCFG`/`VSLIO` pass = the test DD is missing, NOT a code regression. Re-install the
  `#999000` DD on foia-t12 before relying on a dual-engine `VSLFS` run.
