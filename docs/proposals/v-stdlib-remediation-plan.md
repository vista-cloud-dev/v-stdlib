---
title: "v-stdlib remediation plan — adversarial analysis findings + sysadmin extension roadmap"
status: proposed
created: 2026-06-28
last_modified: 2026-06-28
revisions: 1
doc_type: [PROPOSAL]
scope: the 6 shipped VSL* modules, tests, examples, generated docs, tooling, and the planning corpus (quarantine/ excluded)
---

# v-stdlib remediation plan

A whole-library adversarial review of v-stdlib (the 6 shipped `VSL*` modules,
their tests, examples, generated docs, KIDS build, Python tooling, and the
planning corpus in the `docs` repo). `quarantine/` is out of scope by
instruction. This document records the findings as a **prioritized remediation
plan** plus a **sysadmin-facing extension roadmap**.

> **R1 is already landed in the same change as this document.** The broken
> `$$user^VSLSEC` public API has been fixed and re-verified (12/12 live on
> `vehu`). Everything below R1 is proposed, not yet done.

## Contents

- [Verdict](#verdict)
- [Remediation items (severity-ranked)](#remediation-items-severity-ranked)
  - [R1 — BLOCKER (DONE): `$$user^VSLSEC` had no body; every call raised](#r1--blocker-done-uservslsec-had-no-body-every-call-raised)
  - [R2 — MAJOR: `VSLCFG` is silent-failing and SYS-scope-only, but named as a general config adapter](#r2--major-vslcfg-is-silent-failing-and-sys-scope-only-but-named-as-a-general-config-adapter)
  - [R3 — MAJOR: `VSLLOG` is not really an audit log](#r3--major-vsllog-is-not-really-an-audit-log)
  - [R4 — MINOR: `VSLIO` doc/code default mismatch](#r4--minor-vslio-doccode-default-mismatch)
  - [R5 — MINOR: `VSLTASK` `when` doc imprecise; `VSLFS.$$kill` asymmetry](#r5--minor-vsltask-when-doc-imprecise-vslfskill-asymmetry)
  - [R6 — STRUCTURAL: triple-duplicated assertions, over-long example lines, tooling overhead](#r6--structural-triple-duplicated-assertions-over-long-example-lines-tooling-overhead)
  - [R7 — STRUCTURAL: the published plan corpus is stale and misleading](#r7--structural-the-published-plan-corpus-is-stale-and-misleading)
  - [R8 — HYGIENE: uncommitted deletion on `main`](#r8--hygiene-uncommitted-deletion-on-main)
- [Are the existing plans worthwhile?](#are-the-existing-plans-worthwhile)
- [Sysadmin extension roadmap — defer to the existing suite proposal](#sysadmin-extension-roadmap--defer-to-the-existing-suite-proposal)
  - [Where this plan feeds the suite](#where-this-plan-feeds-the-suite)
  - [Net positioning](#net-positioning)
- [Recommended sequence](#recommended-sequence)
- [Appendix — findings table](#appendix--findings-table)

---

## Verdict

The core is **sound**: 6 thin, single-purpose adapters, each binding exactly
one VistA subsystem (XPAR, Kernel `^XUSEC`, FileMan DBS, `^%ZISTCP`, a FileMan
audit sink, TaskMan) to the engine-neutral `STD*` base, one-way `v → m`, with a
consistent loud-error contract and live dual-engine tests. The waterline
discipline holds. The risk is concentrated in (a) one shipped-and-broken public
API (now fixed), (b) a handful of smaller module defects, (c) heavy
generated-tooling overhead that already caused (a), and (d) a published plan
corpus that no longer matches the shipped 6-module reality.

Gate state at review: `make check-fast` is green (exit 0) apart from 16
non-error `M-MOD-001` style findings (see R6).

---

## Remediation items (severity-ranked)

### R1 — BLOCKER (DONE): `$$user^VSLSEC` had no body; every call raised

`$$user^VSLSEC(duz)` is a documented public API (module header, `VSLSECTST`,
the quick-start guide). Its implementation **did not exist**: the label at
`src/VSLSEC.m` was followed only by doc comments, so execution fell through into
`bySecid(secid)` and — with `secid` undefined — hit
`if $get(secid)="" do raiseArg(...) quit ""`, **raising `U-VSL-SEC-ARG` on every
call** (or, worse, returning a SecID-query IEN instead of a name if a caller had
`secid` leaked in scope).

**Root cause** (pickaxe-confirmed): commit `d13b9ac`
*"Living Examples E3 … coverage 0%→100%"* replaced the only executable line —

```diff
-	quit $$get^VSLFS(200,$$pduz(duz)_",",".01","")
+	; doc: @illustrative  resolves the #200 NAME via $$GET1^DIQ …
```

The example-backfill tooling deleted the function body while rewriting the doc
tags around it. No gate caught it because none execute `$$user` on a live
engine, and the "dual-engine green" claim in
`docs/memory/m6.5-vslsec-secid-binding.md` predates the regression.

**Fix applied:** restored `quit $$get^VSLFS(200,$$pduz(duz)_",",".01","")` (kept
the `@illustrative` doc line above it). Regenerated KIDS + manifest + module
page + examples + skill. Re-ran the live suite:
`VSLSECTST` **12/12 on `vehu` (ydb)**, including the previously-impossible
`$$user resolves the #200 NAME for IEN 1` assertion.

**Follow-up (proposed):** add a gate that fails on a public label whose body is
empty / falls through to the next label without an explicit `quit`. This class
of bug — a generated doc-edit silently deleting code — must be caught
mechanically, not by review. See R6.

### R2 — MAJOR: `VSLCFG` is silent-failing and SYS-scope-only, but named as a general config adapter

Two defects, both real:

1. **Silent failure.** `$$set^VSLCFG` calls `EN^XPAR("SYS",key,1,value)` with
   no error array and no `$$lastError`. It is the **only** module in the library
   with no loud-error contract — every other module raises a clean `,U-VSL-*-,`
   `$ECODE` and stashes detail for `$$lastError`. A bad parameter name or an
   XPAR validation failure vanishes silently.
2. **SYS-only, not "effective".** `$$get` reads `$$GET^XPAR("SYS",key,1)` — the
   SYS-level instance only, never XPAR's effective precedence resolution
   (`USR → SERVICE → DIV → SYS → PKG`). Labelled a "VistA configuration
   adapter," it is really a SYS-scope reader. A sysadmin asking "what is the
   effective value in this context?" gets the wrong answer.

**Proposed:**
- Add `$$lastError^VSLCFG` + capture the `EN^XPAR` error array; raise
  `,U-VSL-CFG-SET,` on a real XPAR failure (match the VSLFS/VSLLOG posture).
- Add `$$getEffective^VSLCFG(key,default)` over `$$GET^XPAR(entity,key)` with
  full precedence resolution, and an entity-aware `$$set`/`list`. Keep the
  existing SYS-only `$$get` (it is the faithful `STDENV` flat-read analog) but
  document the distinction in the header.

### R3 — MAJOR: `VSLLOG` is not really an audit log

`$$write^VSLLOG` concatenates `timestamp_" "_event_" "_detail` into a **single
FileMan `.01`** of whatever file you pass; the tests use #8989.51 PARAMETER
DEFINITION as the "audit file." There is no dedicated audit DD, no structured
fields (DUZ, host, event-type, timestamp-as-field), and no query path. As the
"audit log must never silently drop a record" capability it claims (plan §6.2),
today's `VSLLOG` is a placeholder — a fine v→v composition demo, inadequate as
an operational audit sink.

This is the **prerequisite** for every write-capable module in the sysadmin
suite (`VSLKEY`, `VSLALERT`, `VSLUSER`, `VSLAUD`): privileged writes must be
auditable. See the extension-roadmap section below.

**Proposed:** define a dedicated `VSL AUDIT` FileMan DD (fields: timestamp, DUZ,
host/$IO, event category, free-text detail) shipped in the VSL KIDS build via
`v pkg`, and rebind `$$write^VSLLOG` to file structured fields through VSLFS.
Add `$$query^VSLLOG` (date/event filters) over the VSLFS finder (R-EXT-6).

### R4 — MINOR: `VSLIO` doc/code default mismatch

`$$connect` doc says `timeout … (default 10)`; the code is `$get(timeout,30)`
(default 30). The public-API header omits the default entirely. Fix the doc to
30 (or the code to 10) and state it in the header. The TLS gap itself is handled
correctly (loud `,U-VSLIO-NOTLS,`, never a silent plaintext fallback) and stays
tracked as the existing gating item — no change beyond the doc.

### R5 — MINOR: `VSLTASK` `when` doc imprecise; `VSLFS.$$kill` asymmetry

- `VSLTASK.schedule` doc: *"MUST be ≤5-digit $H or `@`"*. The default is
  `$horolog` (full `days,secs`), which is the correct `ZTDTH` format; the
  "5-digit" phrasing is misleading. Reword.
- `VSLFS.$$kill` swallows a `DIERR` (idempotent) while `$$set` raises — a
  documented but trap-able asymmetry (a failed delete reads as success).
  Consider a `$$kill` variant (or flag) that raises, for callers that need
  delete-or-fail. Low priority.

### R6 — STRUCTURAL: triple-duplicated assertions, over-long example lines, tooling overhead

- **Triplication.** The same assertions exist in three places: the
  `@example`/`@illustrative` doc tags in each source module, the generated
  `examples/programs/VSL*EX.m`, and the hand-written `tests/VSL*TST.m`
  (compare `VSLTASKEX.m` to `VSLTASKTST.m` — near-identical). Three copies to
  keep in sync; **R1 proves the sync is fragile** — editing the doc-tag copy
  silently broke the real code.
- **Over-long lines.** All 16 lint findings are `M-MOD-001` (lines up to 356
  columns) caused by packing whole multi-statement M programs into `; doc:
  @example` comments. They pass only because the gate is `--error-on=error`.
  This is exactly the "exhaust" the org `org-knowledge-canonicalization`
  proposal targets.
- **Tooling-to-product ratio ≈ 6:1.** `tools/` holds ~200 KB of Python
  (`run-examples.py` 31 KB, `gen-manifest.py` 29 KB, `gen-examples.py` 24 KB,
  `gen-icr.py` 15 KB, …) supporting ~35 KB of M source across 6 modules. The
  drift-gate/generate discipline is the org standard, but at this scale the
  meta-machinery dwarfs the library and is itself a bug surface (it caused R1).

**Proposed:**
- Add the **empty-body / fall-through gate** from R1's follow-up — the single
  highest-ROI mechanical guard, since it would have caught R1 at commit time.
- Decide one source of truth for assertions. Preferred: the **test suites are
  canonical**; `@example` tags carry only short, genuinely self-contained
  one-liners (the rest become `@illustrative` pointers to the suite). This
  collapses the triplication to a duplication and removes the 356-column lines.
- Treat the tooling as a product with its own minimal test (the
  `tools/fixtures/` golden slice exists; extend it to cover the
  doc-tag-rewrite path that deleted R1).

### R7 — STRUCTURAL: the published plan corpus is stale and misleading

The `docs` repo `docs/vsl-msl/` (overview, plan, tracker, retrospective) froze
2026-06-18 and now asserts **8 VSL modules** (`…/VSLENV/VSLBLD`) at KIDS
`VSL*1.0*2`. Reality: **6 modules at patch 5** (VSLENV/VSLBLD deleted
2026-06-25; KIDS now `VSL*1.0*5`). The tracker never recorded the RPC/HL7→S3 tap
saga or its 2026-06-27 quarantine. The retrospective's headline "next move" (the
seven web clients) points at proposals **retired 2026-06-22**. Anyone trusting
that corpus is wrong on module count, patch level, and next steps.

**Proposed:** mark `docs/vsl-msl/{overview,plan,tracker,retrospective}` as
`superseded` (or reconcile them to: 6 modules, `VSL*1.0*5`, tap quarantined, web
clients retired, live next-thing = this plan + `v-rpc-tap`). This is an org-repo
edit; do it under the increment protocol in the `docs` session.

### R8 — HYGIENE: uncommitted deletion on `main`

`git status` showed a staged deletion of `docs/prompts/debug-live-capture-fault.md`
(tap-quarantine fallout) sitting uncommitted on `main`, contrary to the
increment protocol. Fold it into the next commit.

---

## Are the existing plans worthwhile?

| Thread | Keep? | Note |
|---|---|---|
| Core ladder M0a→M6 (`v pkg` lifecycle + 6 adapters) | **Yes** | Lean, shipped, grounded. The defensible heart. |
| Real TLS (`$$connectTls`) | **Yes — gating** | Already loud-stubbed; needed before any PHI transport. |
| Dedicated audit DD (real `VSLLOG`) | **Yes** | R3 — prerequisite for every write-capable sysadmin module. |
| RS256/JWKS, OAuth introspection (`VWEBAOI`) | Conditional | Only if the web-resource-server line is actually pursued. |
| RPC/HL7→S3 traffic tap | **Built then quarantined** | ~12 increments discarded (wrong broker seam). Replacement `v-rpc-tap` spec churned 5× in one day. High-risk, low-yield so far; out of scope here. |
| VSLENV / VSLBLD / VSLTAPRUN / egress hash | **Deleted** | Built, then ruled out (bespoke-installer ban / over-engineering). |
| The 7 web clients + quality framework | **Retired** | XL program-scale speculation, no shipped consumer. |

**Pattern:** the drift-gated *core* lands and holds; the *speculative* work above
the M6 line repeatedly builds-then-discards, and the published roadmap, the live
activity, and the canonical tracker point in three different directions. R7
closes that gap.

---

## Sysadmin extension roadmap — defer to the existing suite proposal

The "what new modules do sysadmins need" question is **already answered** by the
canonical `docs/proposals/vista-sysadmin-suite.md` (draft 2026-06-27, rev 2) — a
grounded 46 KB design that turns v-stdlib from seam adapters into the engine half
of a sysadmin suite, each `VSL*` module paired with a Go `v` CLI domain:

| Tier | Modules | Covers |
|---|---|---|
| 1 — API-backed spine (build first) | `VSLJOB`, `VSLALERT`, `VSLPARM`, `VSLKEY`, `VSLERR` | TaskMan ops, XQALERT, XPAR, `^XUSEC` keys, error trap |
| 2 — FileMan-DBS wrappers | `VSLUSER`, `VSLDEV`, `VSLAUD` | users, devices, audit |
| 3 — monitors | `VSLHLO`, `VSLSTAT` (`VSLCAP` deferred) | HL7 links, system status |

**This remediation plan does not re-propose those modules.** An earlier review
draft invented overlapping names (`VSLOPS`/`VSLTM`/`VSLHL7`) — that would have
been naming drift against an existing design, the exact inconsistency this review
exists to catch. Adopt the suite's registry. The items below are the
**prerequisite cleanup the suite assumes but does not itself cover**, plus the
dependency edges between the two documents.

### Where this plan feeds the suite

- **R1 (fixed) is foundational to the whole suite.** The suite's `VSLUSER` and
  `VSLKEY` explicitly *reuse* `VSLSEC` (identity / key check), and
  `VSLUSER`/`VSLDEV`/`VSLAUD` reuse `VSLFS`. A broken `$$user^VSLSEC` would have
  propagated into every Tier-2 module. **Fix the base before building on it** —
  R1 did.
- **R3 (real `VSLLOG` audit DD) is a hard prerequisite for the suite's write
  verbs.** The suite states every gated write audits through `VSLLOG`/`VSLAUD`;
  today's `VSLLOG` is a single-`.01` placeholder. Build R3 *before* any
  write-capable suite module (`VSLKEY`, `VSLALERT`, `VSLUSER`, `VSLJOB` writes).
  R3 and the suite's `VSLAUD` should be designed together (likely the same DD).
- **R2 (VSLCFG loud + effective resolution) overlaps the suite's `VSLPARM`.**
  Decide: fold R2 into `VSLPARM`'s design (preferred — one XPAR module,
  entity-aware, loud) or fix `VSLCFG` standalone first. Do **not** ship both a
  SYS-only silent `VSLCFG` and a separate `VSLPARM` with divergent contracts.
- **`VSLFS` finder verbs** (`$$find`/`list` over `$$FIND1^DIC`/`LIST^DIC`) are
  the missing query surface the suite's Tier-2 FileMan wrappers and the planned
  `v db` domain both need. Pull this forward as a VSLFS increment ahead of Tier 2.

### Net positioning

- **This document** = prerequisite remediation (R1–R8): fix what's broken, harden
  the contracts, add the empty-body gate, reconcile the stale corpus.
- **`vista-sysadmin-suite.md`** = the forward capability roadmap (new `VSL*`
  modules + `v` domains).
- Sequence the suite's Tier 1 → 2 → 3 **after** R3 lands (write auditing) and with
  R2 folded into `VSLPARM`.

---

## Recommended sequence

1. **R1** — `$$user` fix (DONE, in this change).
2. **R6 empty-body/fall-through gate** — cheap, and it would have caught R1.
3. **R7** — supersede/reconcile `docs/vsl-msl/` (org-repo edit, docs session).
4. **R3** — real `VSLLOG` audit DD (unblocks every suite write verb; co-design
   with the suite's `VSLAUD`).
5. **R2** — fix `VSLCFG` (loud + effective resolution), folded into `VSLPARM`.
6. **`VSLFS` finder verbs** — feeds the suite's Tier-2 wrappers and `v db`.
7. Then hand off to **`vista-sysadmin-suite.md`** Tier 1 → 2 → 3 (read verbs first
   within each tier; gated writes only after R3).
8. **R4 / R5 / R8** — minor contract docs + hygiene, folded into the next touch of
   each module.

Read-only, low-risk, highest-daily-value capabilities first; dangerous writes
deferred until the audit substrate (R3) exists.

---

## Appendix — findings table

| ID | Sev | Area | Finding | Status |
|---|---|---|---|---|
| R1 | BLOCKER | VSLSEC | `$$user` had no body → raised on every call | **Fixed + verified 12/12 live** |
| R2 | Major | VSLCFG | silent-fail `$$set`; SYS-only `$$get` mislabeled as "config" | Proposed |
| R3 | Major | VSLLOG | not a real audit log (single `.01`, no DD/fields/query) | Proposed |
| R4 | Minor | VSLIO | `$$connect` timeout default doc (10) ≠ code (30) | Proposed |
| R5 | Minor | VSLTASK/VSLFS | `when` doc imprecise; `$$kill` swallow-vs-raise asymmetry | Proposed |
| R6 | Structural | tests/examples/tooling | triplicated assertions; 356-col example lines; 6:1 tooling ratio; no empty-body gate | Proposed |
| R7 | Structural | docs/vsl-msl | published corpus stale (8 modules/`*1.0*2`; reality 6/`*1.0*5`) | Proposed |
| R8 | Hygiene | git | uncommitted staged deletion on `main` | Fold into next commit |
