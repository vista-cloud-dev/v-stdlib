---
name: r3b-vslfs-finder-query
description: Remediation R3b + R-EXT-6 DONE — VSLFS gained finder verbs ($$find via FIND1^DIC, $$list via LIST^DIC) + a $$get "I" internal-read flag; VSLLOG gained $$query (event + FileMan date-range filters) over the finder. Dual-engine green (VSLFSTST 12/12, VSLLOGTST 15/15, vehu+foia-t12). Carries reusable LIST^DIC parsing + $order-loop-advance gotchas.
metadata:
  type: project
---

# R3b + R-EXT-6 — VSLFS finder verbs + VSLLOG $$query (2026-06-28)

Closes remediation-plan R3 (R3a was the audit DD; this is R3b, the query) and the
plan's R-EXT-6 (VSLFS finder verbs). `$$query` MUST read through the seam, so
R-EXT-6 (the finder) landed first in the same increment.

## What shipped
- **`$$find^VSLFS(file,value,index)`** — `$$FIND1^DIC` with the `X` (exact) flag;
  returns the **IENS form `"ien,"`** of the unique match (or "" for absent/ambiguous),
  consistent with the I/O verbs that take IENS. For the suite's unique lookups.
- **`$$list^VSLFS(file,.out,index)`** — `LIST^DIC`; sets `out("ien,")=""` for every
  record, returns the count. Loud (`,U-VSL-FS-DIERR,`) on DIERR.
- **`$$get^VSLFS(...,flags)`** — optional 5th param passed to `$$GET1^DIQ`; `"I"`
  reads the **internal** value (default "" external). Needed for date comparison.
- **`$$query^VSLLOG(.out,event,fromDt,toDt)`** — `$$list`s the audit file, filters by
  exact event (.01) and/or inclusive FileMan-internal date range; `out("ien,")=event`,
  returns count.

## DURABLE GOTCHA — LIST^DIC output parsing
- Use it **unpacked** (no `P` flag). The `P` (packed) flag changes the output shape
  and leaves the per-record nodes I parse empty.
- `FIELDS="@"` alone (IEN only) does **not** populate `^TMP("DILIST",$J,2,seq)` — the
  IEN node is absent. Include `.01` (`FIELDS="@;.01"`) and the IEN lands in
  `^TMP("DILIST",$J,2,seq)`; count is `+^TMP("DILIST",$J,0)`. Captured fields (when
  requested) are in `^TMP("DILIST",$J,"ID",seq,<field>)` and the field-order map in
  `,0,"MAP")`. `seq` is the list sequence, not the IEN — map seq→IEN via `,2,seq`.

## DURABLE GOTCHA — date fields need INTERNAL reads for range filters
`$$get^VSLFS` returns EXTERNAL by default (`JUN 28,2026@18:05`), which does **not**
sort chronologically. A date-range query must read the FileMan **internal** date
(`3260628.180522`, numerically comparable) — hence the `$$get(...,"I")` flag, and
`$$query` passes `fromDt`/`toDt` as FileMan internal dates (e.g. `$$DT^XLFDT`).

## DURABLE GOTCHA — advance the $order cursor BEFORE the filter quits
`$$query`'s record loop captures `cur=iens` and advances `iens=$order(all(iens))` at
the **top** of the dot block, *then* applies the `quit:` filter postconditionals on
`cur`. Advancing after the filters would re-read the same subscript forever whenever a
record is skipped — a classic `$order`-loop infinite loop.

## Citations + fixtures
Both finder calls are notional FileMan DBS: `@icr DBS @status Supported @custodian DI`,
`$$FIND1^DIC` → `DI/fm22_2dg#find1dic-finder-single-record`, `LIST^DIC` →
`DI/fm22_2dg#listdic-lister` (corpus-verified). VSLFS finder tested on **#999000
ZZVSLFS** (reinstalled — was not resident); `$$query` on **#999001 VSL AUDIT**.
KIDS `VSL*1.0*6`→`*7`; `make check-fast` green (18 citations).

Companion to [[r3a-vsllog-audit-dd]] (the audit DD this queries) and [[m3-vslfs]]
(the VSLFS adapter these verbs extend).
