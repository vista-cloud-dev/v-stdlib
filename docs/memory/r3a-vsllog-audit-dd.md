---
name: r3a-vsllog-audit-dd
description: Remediation R3a DONE — VSLLOG rebound from a single-`.01` placeholder to a dedicated multi-field VSL AUDIT file (#999001) with structured typed fields; dual-engine 11/11 (vehu+foia-t12). Unblocked by v-pkg B.2-a. Carries two reusable engine gotchas (VSLFS files INTERNAL/no-transform; IRIS helper-extrinsic trap unwind). R3b ($$query) deferred to the VSLFS finder.
metadata:
  type: project
---

# R3a — VSLLOG real audit DD (2026-06-28)

Remediation-plan item R3 (`docs/proposals/v-stdlib-remediation-plan.md`), split:
**R3a (done)** = the dedicated multi-field audit DD + structured `$$write`/`$$read`;
**R3b (deferred)** = `$$query`, which needs the VSLFS finder verbs (R-EXT-6) — a
query built now would walk the data global directly, which the VSLFS seam forbids.
Unblocked once v-pkg **B.2-a** (multi-field DD authoring) landed live-proven on
both engines (see [[multi-field-dd-emitter]] in the shared `docs/memory`).

## What shipped
- **`VSL AUDIT` file #999001** (`^DIZ(999001,`), declared in `kids/vsl.build.json`
  `components.files`, shipped via `v pkg` KIDS. Fields: `.01` EVENT (free text,
  the queryable key, B-xref), `1` TIMESTAMP (date+time), `2` USER NUMBER (numeric
  DUZ — **0 = system**, deliberately NOT a #200 pointer so a system record files
  with no NEW PERSON dependency), `3` HOST (free text $IO), `4` DETAIL (free text).
- **`$$write^VSLLOG(event,detail,duz,host)`** now OWNS the file — the `file` param
  was dropped (the "writes into a foreign file" defect). `$$read^VSLLOG(iens,.rec)`
  fills `rec("event"|"timestamp"|"user"|"host"|"detail")` and returns the EVENT.
  `$$auditFile^VSLLOG()` is the single source of the file number.
- File number is the VA test-range #999001 — the documented stopgap until v-pkg
  **B.2-b** ships permanent-namespace numbers (not on R3a's path).

## DURABLE GOTCHA 1 — VSLFS files INTERNAL (no input transform runs)
`$$set^VSLFS` calls `UPDATE^DIE("",...)` with **no `E` flag**, so FDA values are
filed as **INTERNAL** — FileMan input transforms do NOT run. Consequences a caller
must handle itself:
- A **date** field must be given a FileMan-INTERNAL value: file **`$$NOW^XLFDT`**,
  NOT the external `"NOW"` (the latter stores the literal string "NOW"). This adds
  the only L4 call in VSLLOG → tagged `@icr 10103 @call $$NOW^XLFDT @status
  Supported @custodian XU @source XU/krn_8_0_dg_xlf_fl_ug#nowxlfdt-current-date-and-time-va-fileman-format`.
- Free-text **length/required input transforms are NOT enforced on write** — an
  over-length `.01` files silently; only **structural** errors DIERR (nonexistent
  file/field, **empty `.01` on a `+1,` add** = required-field). So the loud-failure
  test triggers via an **empty `.01`** (not an over-length value).
- Free-text round-trips are byte-identical precisely because internal==external for
  free text — which is why the VSLFS suites never exposed this; a date field is the
  first place internal-vs-external is observable.

## DURABLE GOTCHA 2 — IRIS: never catch a raise from an intermediate `$$helper` frame
A flag-based `$ETRAP` that catches a VSLFS DIERR works only if the raising `$$set`
is called **directly in the trap's own frame**. Routing it through a helper —
`set iens=$$fileAll(...)` — works on **YDB** but on **IRIS** raises a SECONDARY
fault when the trap unwinds the helper extrinsic with **no return value**, which the
m-iris driver surfaces as **`could not parse iris session output`** (suite shows
`0/0`). Fix: inline every `$$set^VSLFS` in `write` with `if ok` guards (the proven
m4 idiom). Extends [[m4-vslsec-vsllog]]'s zgoto-$ETRAP gotcha: the rule is *single
risky statement in the trap frame, then `if ok quit`* — no helper extrinsic, no
zgoto.

## DURABLE GOTCHA 3 — an audit detail must be one line
A multi-field FileMan DIERR has multiple TEXT lines, joined by `$C(10)` in VSLFS's
`stashDierr`. A raw LF in the composed `$$lastError` both pollutes the audit record
and corrupts the IRIS session frame. `VSLLOG.oneLine` collapses CR/LF to spaces in
`raiseWrite` before stashing.

## Proof + gates
Dual-engine **11/11** (`m test --engine ydb --docker vehu` / `--engine iris
--docker foia-t12 --namespace VISTA`); the VSL AUDIT DD must be RESIDENT first
(`v pkg install dist/kids/VSL.kids --engine <e> --transport docker --skip-env-check`
— skip-env-check because the build's `MSL*0.1*1` required-build isn't enforced on
the test engines). `make check-fast` green; check-citations verified the XLFDT
citation (#10103) against the gold corpus. KIDS bumped `VSL*1.0*5`→`*6`.

Companion to [[m4-vslsec-vsllog]] (the original VSLLOG) and [[m3-vslfs]] (the DBS
binding it reuses).
