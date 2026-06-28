# R2 — VSLCFG loud `$$set` + `$$getEffective` (remediation plan)

**2026-06-28.** Second remediation item from
`docs/proposals/v-stdlib-remediation-plan.md` (R1 = the VSLSEC `$$user` fix).

## What shipped
- **`$$set^VSLCFG` is now loud.** Was `do EN^XPAR("SYS",key,1,value)` — no error
  arg, silent failure (the only loud-contract-less module). Now passes `.ERR`,
  reads XPAR's scalar return (`0` ok / `#^errortext`, `#` = FileMan DIALOG #.84),
  AND flag-traps a hard EN^XPAR fault; either maps to a clean `,U-VSL-CFG-SET,`
  with detail in `^TMP($job,"vslcfg","err")`.
- **`$$lastError^VSLCFG`** added (VSLFS/VSLLOG/VSLTASK posture; flag-based
  `$ETRAP`, never zgoto).
- **`$$getEffective^VSLCFG(key,default)`** added over `$$GET^XPAR("ALL",key,1)` —
  resolves the value across the parameter's own precedence multiple (#8989.51),
  first-found-wins. Plain `$$get` still reads only the SYS instance (the STDENV
  flat-read analog); header documents the distinction.

## Grounding (vdocs GOLD, Kernel Toolkit DG)
- `EN^XPAR(entity,parameter,instance,value,.error)` — `.error` is a **scalar**
  `0` / `#^errortext`, NOT a `DIERR` array. Test `+$get(ERR)>0`.
- `$$GET^XPAR("ALL",...)` = precedence resolution; entity-list delimiter is `^`
  (not `;`). `"SYS"` reads only the SYSTEM entity.
- Both EN^XPAR and $$GET^XPAR are Supported under **ICR #2263** (one ICR covers
  the whole Parameter Tools family incl. GETLST/ENVAL).

## Verification
`VSLCFGTST` 7/7 live on vehu (ydb) via the driver stack (`tGetEffectiveResolvesSys`
+ `tSetFailureIsLoud` added). Regenerated KIDS/manifest/icr/examples/skill/page;
`make check-fast` green. **IRIS (foia) arm OWED** — no foia container was up;
code is engine-neutral XPAR + IRIS-portable `$ETRAP`, expected green.

## Deferred (not built)
Entity-aware `$$set`/`$$list` (`GETLST^XPAR`/`ENVAL^XPAR`) → the suite's
`VSLPARM` module, which subsumes VSLCFG. Don't grow VSLCFG into VSLPARM.

## Gotcha
A red→green transition left a stale routine-cache on vehu: the first green run
read 0/0 (suite abort); re-running gave stable 7/7. Also: an external **nightly
cadence** automation deleted `quarantine/` from the working tree mid-session
(none of the `make` targets do — verified); restored with `git restore`.

See [[vslsec-user-regression-fix]] + the sysadmin-suite proposal `docs/proposals/vista-sysadmin-suite.md`.
