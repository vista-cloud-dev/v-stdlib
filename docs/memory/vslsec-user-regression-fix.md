# VSLSEC $$user regression — fixed + remediation plan

**2026-06-28.** Adversarial whole-library review of v-stdlib (6 modules, tests,
examples, docs, tooling; `quarantine/` excluded).

## The blocker (fixed)
`$$user^VSLSEC(duz)` — a documented public API — had **no executable body**. The
label fell through into `bySecid(secid)` with `secid` undefined → raised
`U-VSL-SEC-ARG` on every call. Root cause (pickaxe): commit `d13b9ac`
"Living Examples E3" replaced `quit $$get^VSLFS(200,$$pduz(duz)_",",".01","")`
with a `; doc: @illustrative` line — the example-backfill tooling deleted the
function body while rewriting doc tags. No gate executes `$$user` live, so
nothing caught it; the "dual-engine green" claim in `m6.5-vslsec-secid-binding`
predates the regression.

**Fix:** restored the `quit $$get^VSLFS(...)` line (kept the `@illustrative`
doc). Regenerated KIDS (`VSL*1.0*5`) + manifest + module page + examples + skill.
Live re-run: `VSLSECTST` **12/12 on vehu (ydb)** via the driver stack, including
the `$$user resolves the #200 NAME for IEN 1` assertion.

## Lesson / proposed gate
A generated doc-edit silently deleted code and survived every gate. Highest-ROI
guard: a lint rule that fails on a public label with an empty body / fall-through
to the next label without an explicit `quit`. (R6 in the remediation plan.)

## Remediation plan
Full findings + sysadmin extension roadmap:
`docs/proposals/v-stdlib-remediation-plan.md`. Headlines beyond R1:
- R2 VSLCFG silent-fail `$$set` + SYS-only `$$get` (only loud-contract-less module).
- R3 VSLLOG is not a real audit log (single `.01`, no DD) — blocks write-capable modules.
- R7 the `docs/vsl-msl/` corpus is stale (claims 8 modules/`*1.0*2`; reality 6/`*1.0*5`) — supersede in the docs session.

Sysadmin extensions are NOT re-proposed here — they already live in
`docs/proposals/vista-sysadmin-suite.md` (VSLJOB/VSLALERT/VSLPARM/VSLKEY/VSLERR
Tier 1; VSLUSER/VSLDEV/VSLAUD Tier 2; VSLHLO/VSLSTAT Tier 3). The remediation
plan supplies the **prerequisite edges**: R3 (real audit DD) gates every suite
write verb (co-design with VSLAUD); R2 (VSLCFG loud+effective) folds into VSLPARM;
a VSLFS finder feeds the Tier-2 wrappers + `v db`. Don't duplicate the suite.

See the proposal `docs/proposals/vista-sysadmin-suite.md` (above), [[m6.5-vslsec-secid-binding]], [[m4-vslsec-vsllog]].
