---
title: "VistA library wrapping baseline — adversarial audit of the VSL* modules + a coverage & stress-test policy"
status: proposed
created: 2026-06-28
last_modified: 2026-06-28
revisions: 1
doc_type: [PROPOSAL]
scope: the 6 shipped VSL* modules (VSLCFG/VSLFS/VSLIO/VSLLOG/VSLSEC/VSLTASK), their tests, their docs↔GOLD-corpus citations, and their behavior on both live engines (vehu YDB + foia-t12 IRIS)
---

# VistA library wrapping baseline

A fresh, comprehensive **adversarial audit** of all six `VSL*` modules along three
axes — **(A)** documentation vs. the vdocs GOLD corpus, **(B)** code vs. a live
VistA on **both** engines (YDB `vehu` + IRIS `foia-t12`, reached only through the
`m-driver-sdk → m-ydb/m-iris` stack), and **(C)** coverage of the VistA internal
library each module wraps — plus the deliverable the audit was for: a **rational
coverage model + stress-test policy** and a **baseline for how to properly wrap a
VistA library** with guaranteed coverage and no redundancy.

Produced by a 20-agent workflow (18 per-module analysts across the 3 axes +
synthesis + adversarial critique). Live results were re-verified by hand before
being recorded here.

> **This is an analysis/baseline document — no code or tests were changed.** It
> records findings and proposes fixes + a policy; acting on them is a separate,
> per-item decision. It supersedes nothing; the prerequisite library-fix tracker is
> [`v-stdlib-remediation-plan.md`](v-stdlib-remediation-plan.md) (R1–R8, complete),
> and the forward roadmap is [`vista-sysadmin-suite.md`](vista-sysadmin-suite.md).

---

## TL;DR — green suites, four real defects

All six modules carry green canonical suites on YDB, **but the green is partly an
illusion of weak suites**: corpus grounding and adversarial dual-engine probes
found four substantive defects that the existing `12/12`-style suites passed
straight over. Each is verified below.

| # | Module | Defect | Severity | How verified |
|---|--------|--------|----------|--------------|
| 1 | **VSLSEC** | The documented **default-principal contract is broken**: single-arg `$$hasKey(key)` / `$$user()` raise `UNDEF` on **both** engines — `$$pduz(duz)` evaluates an omitted formal *by value* before its own `$get` guard. The suite masks it by always passing an explicit `duz`. | **High** | Code inspection (`pduz` at `src/VSLSEC.m:107`) — fix is `$$pduz($get(duz))` / `.duz` |
| 2 | **VSLIO** | **A true dual-engine failure: `VSLIOTST` is RED on IRIS (9/10, exit 3)** while green on YDB. `$$write` does `use id write buf` with **no `$ZVERSION["IRIS"` flush arm**, so client→server bytes are silently dropped on IRIS. A stale "STDNET is YDB-only" soft-skip had been hiding it. | **High** | Re-ran live: `m test --engine iris --docker foia-t12 …` → exit 3, 9/10; YDB → exit 0, 10/10 |
| 3 | **VSLFS** | `$$set` documents its value as an **"external value"** but calls `UPDATE^DIE` with **no `E` flag**, which the FileMan corpus requires to mean **INTERNAL**. Only the free-text `.01` test fixture round-trips, masking silent wrong-value filing for DATE/POINTER/SET fields. | **High** | Corpus (FileMan DBS) + the known "VSLFS files INTERNAL" gotcha (`docs/memory/r3a-vsllog-audit-dd.md`) |
| 4 | **VSLTASK** | `schedule()`'s docstring says `when="@"` means **"ASAP"** — the TaskMan corpus says `"@"` means **do NOT schedule**, the opposite, and fatal for a persistent listener. | **High** | Corpus `XU/krn_8_0_dg_taskman_ug#example-7`: `S ZTDTH="@" ;Don't schedule the task to run` |

> **Provenance honesty note:** finding (4) is wording **this effort introduced** in
> R5a ("`@` for ASAP"). The audit caught its own house's error — exactly what an
> adversarial, corpus-grounded pass is for.

The throughline: **wrapped-API coverage is honestly *classified*, but TEST coverage
under-specifies the contracts** (prefix-only `$ECODE` matches, circular assertions,
explicit-arg-only paths, transform-invariant fixtures) — and that is precisely
where the real defects hid. The rest of this doc turns that lesson into a policy.

---

## Method

- **Axis A — docs ↔ corpus** (`corpus-researcher` agents, one per module): every
  `@icr`/`@call`/`@status`/`@custodian`/`@source` citation and every prose API
  claim re-checked against the vdocs GOLD corpus (`~/data/vdocs/index.db`,
  325 MB). Never from memory.
- **Axis B — code ↔ live VistA** (one agent per module): each `VSL*TST.m` suite run
  on **both** engines via the driver stack, plus up to three read-only /
  self-restoring adversarial probes per module. Engine access **only** through
  `m test --engine ydb --docker vehu …` and `m test --engine iris --docker
  foia-t12 --namespace VISTA …` — never raw `docker exec`.
- **Axis C — wrapped-API coverage** (`corpus-researcher` agents): enumerate the
  *full* documented Supported surface of each wrapped library, compare to what the
  module wraps, classify each gap `missing` / `deferred` / `na`.
- **Synthesis + critique**: a high-effort synthesis built the policy below; an
  adversarial critic then checked it for gaps and overstatement (and caught a
  module mislabel in the draft, corrected here).

### Live dual-engine results (re-verified by hand)

| Module | YDB (vehu) | IRIS (foia-t12) | Divergence |
|--------|-----------|-----------------|------------|
| VSLCFG | 7/7 ✅ | 7/7 ✅ | none |
| VSLFS | 12/12 ✅ | 12/12 ✅ | none |
| **VSLIO** | 10/10 ✅ | **9/10 ❌ (exit 3)** | **outbound `^%ZISTCP` write not delivered on IRIS** |
| VSLLOG | 15/15 ✅ | 15/15 ✅ | none in the shipped surface (a probe reproduced the IRIS extrinsic-`$etrap` fault the **shipped code already avoids** by design) |
| VSLSEC | 12/12 ✅ | 12/12 ✅ | none — but both green suites **mask** the default-duz UNDEF (defect 1) |
| VSLTASK | 8/8 ✅ | 8/8 ✅ | none |

**Correction vs. prior records:** earlier R-series notes treated VSLIO as
dual-engine green. That was never actually exercised on IRIS — the suite
soft-skipped the loopback assuming `$$available^STDNET()` was YDB-only. It is now
`1` on IRIS, the arm runs, and it fails. VSLIO is **committed RED on a supported
engine** today.

---

## The coverage model — what "comprehensive coverage" means for a VistA wrapper

Seven categories. A wrapper is "covered" only when **all seven** are satisfied — a
green happy-path suite is necessary but, per this audit, **not sufficient**.

| Category | Covers | Applies to |
|----------|--------|-----------|
| **1. Citation / provenance contract** | Every wrapped call carries `@icr/@call/@status/@custodian/@source`; the `@source` anchor **resolves to a non-empty** GOLD-corpus section; the status label (Supported vs Controlled Subscription) is correct; the signature matches. Empty-body anchors + unbackable prose are *flagged, not asserted*. | Every docblock at the call site (axis A) — the drift-gate analogue of `source-tag→generate→registry→red-gate`. |
| **2. Happy-path / seam contract** | The advertised verbs return the documented result against a live engine. | All modules; the core of each suite. Necessary, not sufficient. |
| **3. Loud-error contract** | A wrapped-library failure raises the **EXACT** namespaced `,U-VSL-<MOD>-<OP>,` (not a `U-VSL-<MOD>` prefix), stashes `$$lastError` detail, then behaves as documented. Distinguishes raise-on-malformed from documented silent-DENY / idempotent-no-raise. | Every module with a write/destructive path or an argument gate. **Assert the exact code, not a substring.** |
| **4. Dual-engine parity** | Identical observable behavior on YDB + IRIS for the full suite **and** every probe; every engine-divergent construct (socket flush, `$etrap` in extrinsic vs do-frame, `$H`/format) carries a `$ZVERSION["IRIS"` arm and the suite **actually runs that arm on both**. Divergence is a defect unless documented + gated. | Every module (binding per `CLAUDE.md`). The single most under-tested category — VSLIO's IRIS write gap lived here. |
| **5. Wrapped-API surface coverage** | Enumerate the wrapped library's full Supported surface; classify each unwrapped entry `missing`/`deferred`/`na`. "Adequate" = in-scope verbs complete **and** out-of-scope ones consciously classified — not silently absent. | Axis C, every module. Drives the "add this verb" recs. |
| **6. Boundary / argument contract** | Documented **default-argument forms** (omitted `duz`/`when`), optional paths, limit/truncation values (80-char HOST), empty-vs-absent, ambiguous lookups (>1 match → `""`), not-found branches. Exercises the forms callers actually use. | Every module. Where VSLSEC's default-duz UNDEF and VSLFS's internal/external distinction hide. |
| **7. Idempotency / residue** | Repeatable ops behave identically on re-run; every probe/fixture is **self-restoring** (kills throwaway `^DIZ`/`^TMP`); destructive ops on absent targets are safe. | Write-bearing modules. Required so stress/probes can run repeatedly against shared live engines. |

---

## The stress-test policy — rational, and explicitly non-redundant

Stress testing here means **new dimensions the contract suite does not assert** —
*not* re-running the happy-path on both engines (that is the dual-engine parity
contract, already owned by the suite). Each dimension states what to test **and
what NOT to**.

| Dimension | Rationale | Test | Do NOT |
|-----------|-----------|------|--------|
| **Volume / many-records** | Listers return counts in a `0`-node and stage in `^TMP`; off-by-one + residue only appear at N≫1. | For `VSLFS $$list/$$find`, `VSLLOG $$query`: populate N≫1 in a throwaway DD; assert correct **count**, no truncation, and `^TMP("DILIST",$job)` fully cleaned. | Re-assert single-record CRUD at scale. |
| **Boundary / limit values** | Internal-vs-external, truncation, unique-or-empty are structurally untestable with today's transform-invariant fixtures. | Field-length truncation (VSLLOG 80-char HOST), ambiguous lookup → `""` (VSLFS dup `.01`), empty-stored vs unset (VSLCFG), a **transformed field** (DATE/SET) so internal ≠ external is provable. | Re-test mid-range valid values. |
| **Error-injection** | Several suites assert only a `U-VSL-<MOD>` prefix; a wrong `-OP` suffix would still pass. | Force the loud path (bogus file/IEN, undefined param, connect POP, empty/non-numeric args); assert the **exact** `$ECODE`, the `$$lastError` prefix, and post-fault continuation/clearing. | Re-run success cases; settle for a substring match. |
| **Engine-divergence** | The one genuine dual-engine failure lived in an **unmirrored I/O arm** the YDB-green suite never ran on IRIS. | The arms where M semantics diverge: socket flush (VSLIO), `$etrap` extrinsic vs do-frame (VSLLOG), ANSI `$ECODE` normalization, capability drift (`$$available^STDNET` now true on IRIS). Run every probe on **both**; any divergence is red. | Re-run identical happy-path asserts on both and call it "stress." |
| **Idempotency / residue** | Probes hit shared `vehu`/`foia-t12`; a non-restoring test poisons later runs. | Run write/delete probes twice; assert run 2 == run 1; scan for leftover `^DIZ(999000/999001)` / `^TMP($job)`; destructive op on absent target is a safe no-op that still records `lastError`. | Assert single-shot correctness (that's happy-path/error-injection). |
| **Argument-default / contract-shape** | VSLSEC's default-duz is broken yet 12/12 green, solely because every assertion passes an explicit `duz`. | The **documented default-argument forms** callers use: single-arg `$$hasKey(key)`/`$$user()`, omitted `when` (VSLTASK), omitted format (VSLCFG). Assert they resolve per docstring, not fault. | Only exercise the explicit-arg form. |
| **Concurrency (only where the seam claims it)** | Concurrency stress is meaningful only against an explicit concurrency contract. | For seams that claim concurrent safety: record-level locking (`LOCK^DILF`), persistent-task lifecycle (start→stop→un-persist). | Fabricate concurrency tests for single-writer/read-only seams (VSLSEC, VSLCFG) or a seam that defers locking (VSLFS today). |

---

## Anti-redundancy rules (build on R6 — examples ≠ generated programs ≠ assertions)

1. **Single canonical assertion source (R6, binding):** the `VSL*TST.m` suite is the
   ONLY place runnable assertions live. `@example` doc-tags + generated example
   programs MUST NOT duplicate a suite assertion — they show call **shape**, the
   suite proves **behavior**.
2. **`@example` = a short self-contained one-liner** of the call signature + a
   representative return. Documentation, never executed, never load-bearing for
   coverage. If it needs setup/teardown to run, it is not an `@example`.
3. **`@illustrative` = a genuinely non-demonstrable scenario** (VSLTASK's
   un-KILLable persistent self-restart; VSLIO's unwired TLS). Never executed, never
   asserted; it documents *why* a path is unverified — not a fake passing test.
4. **Probes live OUTSIDE the suite** (`ZZPRB*` routines). Promoting a durable probe
   into the suite must add an **orthogonal** assertion (exact ecode vs prefix,
   default-arg vs explicit, ambiguous vs absent, transformed-field round-trip) —
   never a copy of an existing one.
5. **Stress tests assert NEW dimensions** (volume, boundary, residue,
   engine-divergent arms). "Stress == re-running the contract on both engines" is
   forbidden — that is the dual-engine parity contract.
6. **Coverage grows by adding orthogonal categories** from the model, not by
   restating one in a new file. Before adding any assertion, name which model
   category it newly satisfies; if none, it is redundant and rejected.
7. **Citations are the single source of provenance truth.** A fact in a docblock
   must be either backed by a resolving non-empty `@source` anchor or explicitly
   marked unverified/engine-scoped. Repeating a corpus fact in prose without the
   anchor (VSLIO TLS ICRs, VSLCFG `#^errortext`) is provenance drift — cite once, at
   the call site.

---

## The baseline — how to properly wrap a VistA library

Nine gates. Each is a **gate, not a guideline**.

1. **Seam binding.** Reach the engine ONLY through the `m-driver-sdk → m-ydb/m-iris`
   stack. Call the wrapped Supported library by its **public entry point** — never
   read/write its globals directly (VSLSEC's `$D(^XUSEC(key,DUZ))` is the documented
   exception the corpus itself blesses).
2. **Provenance at the call site.** Every wrapped call carries the five citation
   tags; the `@source` anchor **resolves to a non-empty** corpus section; the
   `@status` label is exact (Supported vs Controlled Subscription — VSLSEC `bySecid`
   is correctly Controlled, ICR 4575). Anything the corpus cannot back is marked
   unverified, not stated as fact.
3. **Loud-error contract.** Wrapped-library failure → exact `,U-VSL-<MOD>-<OP>,` +
   `$$lastError` detail, then documented behavior. Documented non-raising paths
   (read/DENY/idempotent) stay silent with a clean `$ECODE`.
4. **Dual-engine parity.** Identical behavior on YDB + IRIS for suite **and** probes;
   every engine-divergent construct carries a `$ZVERSION["IRIS"` arm, and the suite
   **actually runs it on both** — no stale soft-skip silently disabling the IRIS arm
   (VSLIO's lesson).
5. **Waterline.** `v→m` one-way; engine-neutral logic stays in `STD*`; VistA
   vocabulary stays here. Don't duplicate a capability available from `m` or a
   sibling `v` module (VSLSEC reuses `$$get^VSLFS` for #200 NAME).
6. **Wrapped-API surface coverage.** Enumerate the full Supported surface; classify
   every unwrapped entry. The docstring must not over-promise beyond what is wrapped
   (VSLFS "record store" vs scalar-only reality).
7. **Test coverage per the model.** Satisfy all seven categories — exact ecode (not
   prefix), documented **default-arg** forms (not only explicit args), a
   discriminating fixture (transformed field so internal ≠ external),
   boundary/ambiguous/absent branches, self-restoring probes. A green suite that
   only exercises explicit-arg, valid-input, transform-invariant paths does **not**
   meet baseline.
8. **No redundancy (R6).** Suite = sole assertion source; `@example` = call-shape
   one-liner; `@illustrative` = documented non-demonstrable; probes/stress add
   orthogonal assertions only.
9. **Residue-safe on shared engines.** All writes against `vehu`/`foia-t12` are
   self-restoring; destructive ops on absent targets are safe no-ops.

---

## Per-module recommendations

Prioritized; **High** = a verified defect. None applied yet (analysis-only).

### VSLCFG — solid; one minor surface gap
- Add `$$delete`/`$$unset` over `EN^XPAR("SYS",key,1,"@")` so the read/**write**
  scalar seam can clear a value without waiting for `VSLPARM` (the one real gap —
  `DEL^XPAR`).
- **Fix the circular test:** `tGetEffectiveResolvesSys` asserts `getEffective ==`
  the `$$GET^XPAR("ALL")` it wraps — a tautology that can't catch an ALL→SYS
  regression. Replace with a non-circular precedence probe.
- Tighten `tSetFailureIsLoud` from the `U-VSL-CFG` substring to the exact
  `,U-VSL-CFG-SET,` + assert `$ECODE` clears and execution continues.
- Repoint/supplement the `set()` `@source` (`#enxpar-add-change-delete-parameters`
  resolves but its **body is empty** in the corpus) to a citable anchor (e.g.
  `#example-13`); soften the `#^errortext` / DIALOG #.84 prose (not citable).

### VSLFS — green both engines; a High doc/code defect + real verbs missing
- **High — resolve the `E`-flag contradiction:** `$$set` says "external value" but
  files INTERNAL (`UPDATE^DIE` no `E`). Either pass `E` (and validate) or change the
  param doc to "internal value." Today only free-text `.01` round-trips;
  DATE/POINTER/SET fields would file wrong values silently.
- Add a **transformed field** (DATE/SET) to the `#999000` throwaway DD so the
  internal-vs-external claim and `flags="I"` branch are provably distinct.
- Add **`GETS^DIQ`** (whole-record / multi-field read) — the most natural missing
  verb; reading a record currently costs N single-field round-trips. Add **`WP^DIE`**
  for word-processing fields, or scope the docstring to scalar fields.
- **Provenance:** all **five** cited FileMan DBS anchors (`updatedie-updater`,
  `get1diq…`, `filedie-filer`, `find1dic…`, `listdic-lister`) resolve to **empty
  bodies** in the corpus — `@status Supported` is not corpus-confirmable for the
  entire VSLFS citation surface. Reword the ICR note (FileMan DBS *does* have real
  ICRs, e.g. 10150) and see the consolidated corpus action below.

### VSLIO — committed RED on IRIS (High) + provenance softness
- **High — fix the IRIS outbound-write path:** `$$write` has no `$ZVERSION["IRIS"`
  flush arm, so client→server bytes drop on IRIS and `VSLIOTST` is RED (9/10, exit
  3). Add the IRIS flush mirror `CLAUDE.md` mandates for engine-divergent I/O.
- **Medium — fix the stale suite assumption:** the loopback soft-skips on IRIS
  assuming "STDNET is YDB-only," but `$$available^STDNET()=1` on IRIS now.
- Mark TLS ICRs **#7616 / #7617 as unverified** (both routines exist in the corpus;
  neither number appears anywhere in it) or back them from an ICR registry.
- Reconcile the **`CALL^%ZISTCP` calling form**: the wrapper calls it positionally
  `(host,port,timeout)` but the cited source documents only the parameterless
  `IPADDRESS/SOCKET/TIMEOUT` input-variable convention — fix the docstring or the
  call. Keep the TLS loud-gap as-is (verified identical on both engines).

### VSLLOG — clean; the IRIS divergence is correctly handled, not a defect
- The probe that aborted the IRIS suite reproduced the **helper-extrinsic +
  arg-less `QUIT` in `$etrap`** fault — which the shipped module **already avoids**
  by calling `$$set^VSLFS` directly in-frame. The design note (lines 63–67) is
  load-bearing and correct; **keep it.**
- Fold three probe assertions into `VSLLOGTST`: absent-read → `""`, the **exact**
  `,U-VSL-LOG-WRITE,` + `write:` `$$lastError` prefix (suite only substring-matches),
  and 80-char HOST truncation — all hold identically on both engines.
- When v-pkg **B.2-b** lands, migrate `#999001`/`^DIZ(999001,)` to the permanent
  namespace number (update `$$auditFile` + both engine DDs in lockstep).

### VSLSEC — green both engines but a High masked defect
- **High — fix the default-duz UNDEF:** single-arg `$$hasKey(key)` / `$$user()`
  raise `UNDEF (,M6,)` on both engines because `$$pduz(duz)` evaluates the omitted
  formal by value before its `$get`. Use `$$pduz($get(duz))` (or default in
  `hasKey`/`user` before the call). `$$bySecid`/`$$duz` unaffected.
- Add **single-arg test cases** for `$$hasKey`/`$$user` (red against current code,
  green after the fix) + the `$$duz` "0 when no signon" branch — the suite passes an
  explicit `duz` everywhere, which is how the defect stayed hidden.
- Add an **active-user gate** `$$active^VSLSEC` over `$$ACTIVE^XUSER()` — the one
  genuine surface gap; an authz decision should deny terminated/`DISUSER`'d
  principals even if a stale `^XUSEC` cross-reference lingers.
- Reword the header SHAHASH claim — `$$SHAHASH^XUSHSH` **is** documented (ICR 6189);
  scope the absence to the specific pre-`XU*8.0*655` test engine, not "no portable
  Kernel generic-hash entry point."

### VSLTASK — green both engines; a High doc defect + a thin lifecycle half
- **High — fix the `schedule()` docstring:** drop "`@` for ASAP" — the corpus says
  `ZTDTH="@"` means **do-NOT-schedule** (the opposite); a listener queued with
  `when="@"` would never run. For ASAP use `$HOROLOG` (already the code default).
- Drop the unsupported "persistent task is deliberately un-KILLable" wording —
  `KILL^%ZTLOAD` (Supported, ICR 10063) has no persistence exemption in the corpus;
  the cleanup-difficulty rationale stands on its own.
- **Coverage is honestly classified but thin on the stop/retire/observe half.** Add
  `$$askStop` over `$$ASKSTOP^%ZTLOAD` (the WRITE side of the stop signal whose READ
  side `$$S` is already wrapped — the sharpest gap), `$$pclear`/`$$unpersist` over
  `PCLEAR^%ZTLOAD` (inverse of the wrapped `$$PSET`), and `$$stat` over
  `STAT^%ZTLOAD` (listener liveness — `$$running` only reports the scheduler).
- Keep success-path tests `@illustrative` until the v-pkg resident-install path
  exists.

---

## Consolidated cross-cutting action — GOLD corpus empty-body anchors

A recurring, **systematic** issue independent of any one module: cited `@source`
anchors that **resolve but whose section bodies are empty** in the GOLD corpus —
`VSLCFG set()`, `VSLLOG $$NOW^XLFDT`, `VSLTASK queue()`, and **all five** VSLFS
FileMan DBS anchors. The ICR numbers/status are corroborated via the entry-point
tables and sibling Example sections, but the cited sections' own prose is not
retrievable. This is one **vdocs pipeline re-extraction** task (flag empty-body
sections for re-ingest), not six separate doc edits. Until then, citations to those
anchors should point to a citable sibling (e.g. an `#example-N`) or be marked
provenance-soft. Provenance for the ICR *numbers/status* of the six core tags
(2263, 2118, 10103, 10063, 4575, and `^XUSEC`) is otherwise solid.

---

## Recommendations & next steps

1. **Fix the four High defects** (VSLSEC default-duz, VSLIO IRIS write, VSLFS
   `E`-flag doc/code, VSLTASK `@`) — each as its own TDD increment (write the
   red single-arg / IRIS-arm / transformed-field / corrected-doc test first).
   **VSLIO is the most urgent** — the committed suite is RED on a supported engine
   (CI red), so the dual-engine gate is currently not actually green.
2. **Adopt the coverage model + stress policy + 9-gate baseline** as the standard
   for every existing and future VSL module, and add the missing test categories
   (exact-ecode, default-arg, transformed-fixture, volume/residue) to the six
   suites.
3. **Close the in-scope surface gaps** the audit classified `missing` (VSLFS
   `GETS^DIQ`/`WP^DIE`, VSLSEC `$$ACTIVE^XUSER`, VSLTASK `$$ASKSTOP`/`PCLEAR`/`STAT`,
   VSLCFG `DEL^XPAR`) — or consciously defer each with a rationale.
4. **File the corpus re-extraction** task for the empty-body anchors.

These are inputs to the next library increment; this document is the **baseline**
against which "properly wrapped, fully covered" is now measured.

---

## Appendix — audit provenance

- **Workflow:** `vsl-wrapper-baseline-audit` — 20 agents (18 per-module across 3
  axes + synthesis + adversarial critique), ~1.04 M agent tokens, 308 tool calls,
  ~15 min.
- **Engines:** YDB `vehu` and IRIS `foia-t12`, both reached only via
  `m test … --docker …` over the `m-driver-sdk → m-ydb/m-iris` stack. No raw
  `docker exec`.
- **Corpus:** vdocs GOLD `~/data/vdocs/index.db` (325 MB), queried with `vdocs
  search` / `vdocs section`.
- **Hand-verification before recording:** VSLIO IRIS red (live re-run, exit 3),
  VSLSEC default-duz (code inspection of `pduz`), VSLTASK `@` (corpus
  `XU/krn_8_0_dg_taskman_ug#example-7`), VSLFS `E`-flag (corpus + the `docs/memory/r3a-vsllog-audit-dd.md` "VSLFS files INTERNAL" note).
- **Critic correction applied:** the synthesis draft mislabeled the dual-engine
  runtime failure as VSLFS; it is **VSLIO** (VSLFS is green 12/12 on both engines).
  Corrected throughout.
