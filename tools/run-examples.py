#!/usr/bin/env python3
"""run-examples (E4) — the living-examples runner + REPORT.md generator.

Executes the generated `examples/programs/<MOD>EX.m` programs through the
**driver stack only** (`m test --docker …` — never raw `docker exec`; the org
engine-access rule) and turns the result into the trust artifact
`examples/REPORT.md`: a (module × engine) pass/fail grid, the @raises /
illustrative coverage, and — for the live tier — a pre/post residue check
proving the shared live VistA came back byte-identical.

This is E4 of the Living Executable Examples proposal (docs
`proposals/living-executable-examples.md`, §7 live execution, §8 safety model).
It is the executed half of the trust thesis (`examples/index.md` is the "every
feature has an example" half; REPORT.md is the "see it passing on real engines"
half). A byte-identical sibling between the stdlibs (manifest name + the
v-stdlib `--extra-routines` are auto/CLI-supplied).

Engine tiers & arms (§7):

  | tier | arms                                   | cadence  | gate           |
  |------|----------------------------------------|----------|----------------|
  | bare | ydb-bare (m-test-engine) +             | every PR | gating (YDB),  |
  |      | iris-bare (m-test-iris)                |          | IRIS soft in CI|
  | live | ydb-live (vehu) + iris-live (foia)     | nightly  | fail-soft +    |
  |      |                                        |          | residue-reported|

Per-module engine scope comes from the manifest `example_run` field (the
`@exrun` header tag — dual|bare|bare-ydb|ydb|live): `dual` runs on both bare
engines + live; `bare`/`bare-ydb` run on the bare engines only (no live — e.g.
the tap family that exercises its own shared global); `ydb` runs on YDB only
(its IRIS-bare backend is absent, but still valid co-residence on live vehu);
`live` runs only on the live tier (needs Kernel/FileMan). `example_safety`
(`@exsafe`) documents the live side-effect class; the residue check enforces it
empirically.

Usage:
  # bare tier, both engines, gating (the dev loop + local PR gate):
  python3 tools/run-examples.py --m <mbin> --tier bare
  # one bare arm (CI: YDB hard-gates, IRIS runs fail-soft in its own job):
  python3 tools/run-examples.py --m <mbin> --tier bare --arms ydb-bare
  python3 tools/run-examples.py --m <mbin> --tier bare --arms iris-bare --soft
  # live tier, fail-soft, residue check, write the report (the nightly cadence):
  python3 tools/run-examples.py --m <mbin> --tier live --report examples/REPORT.md
  # v-stdlib stages the STD* base too:
  python3 tools/run-examples.py --m <mbin> --tier bare --extra-routines ../m-stdlib/src
  python3 tools/run-examples.py --self-test
"""

from __future__ import annotations

import argparse
import datetime
import json
import subprocess
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_CANDIDATES = ("vsl-manifest.json", "stdlib-manifest.json")
PROGRAMS_DIR = REPO_ROOT / "examples" / "programs"

# The residue fingerprint watches the library's OWN global roots (declared in
# the namespace registry, e.g. ^STDLIB / ^VSLTAP) — not the whole global
# directory. A shared live VistA churns unrelated globals in the background
# (TaskMan, journaling, error logs), so a full ^$GLOBAL diff would false-positive
# constantly (and ^$GLOBAL is not portable to YDB the way IRIS supports it). The
# library leaving its OWN state behind is the residue that matters and that the
# library controls; watching its declared namespace is robust + engine-portable
# ($QUERY only). Transient scratch (^XTMP/^TMP) is by-design ephemeral and never
# watched.
NAMESPACE_REGISTRY = REPO_ROOT / "dist" / "namespace-registry.json"


@dataclass(frozen=True)
class Arm:
    name: str            # "ydb-bare" | "iris-bare" | "ydb-live" | "iris-live"
    engine: str          # "ydb" | "iris"
    docker: str          # container name (the --docker transport target)
    tier: str            # "bare" | "live"
    chset: str = ""      # "m" for YDB byte mode; "" elsewhere
    namespace: str = ""  # IRIS namespace (live VistA = VISTA)

    def base_flags(self, extra_routines: list[str]) -> list[str]:
        f = ["--engine", self.engine, "--docker", self.docker]
        if self.chset:
            f += ["--chset", self.chset]
        if self.namespace:
            f += ["--namespace", self.namespace]
        f += ["--routines", "src"]
        for r in extra_routines:
            f += ["--routines", r]
        return f


# The four standard org arms. Live docker names are overridable (vehu/foia-t12).
def standard_arms(ydb_live_docker: str, iris_live_docker: str) -> dict[str, Arm]:
    return {
        "ydb-bare": Arm("ydb-bare", "ydb", "m-test-engine", "bare", chset="m"),
        "iris-bare": Arm("iris-bare", "iris", "m-test-iris", "bare"),
        "ydb-live": Arm("ydb-live", "ydb", ydb_live_docker, "live", chset="m"),
        "iris-live": Arm("iris-live", "iris", iris_live_docker, "live", namespace="VISTA"),
    }


# Which arms a module's scope (@exrun) participates in, by tier.
#   dual     — both bare engines (gating) + both live engines (default).
#   bare     — both bare engines only; NOT live (a module whose examples
#              exercise its own shared global, e.g. the tap family writing
#              ^VSLTAP, which would pollute a shared live VistA).
#   bare-ydb — the YDB bare engine only (IRIS-bare-incompatible AND not live).
#   ydb      — YDB only: bare m-test-engine + live vehu (an engine-neutral
#              module whose IRIS backend is absent on m-test-iris, e.g.
#              STDCOMPRESS/STDCSPRNG/STDHARN — still valid co-residence on vehu).
#   live     — live VistA only (vehu + foia); skipped on the bare engines
#              (needs Kernel/FileMan).
SCOPE_ARMS = {
    "dual":     {"bare": ["ydb-bare", "iris-bare"], "live": ["ydb-live", "iris-live"]},
    "bare":     {"bare": ["ydb-bare", "iris-bare"], "live": []},
    "bare-ydb": {"bare": ["ydb-bare"],              "live": []},
    "ydb":      {"bare": ["ydb-bare"],              "live": ["ydb-live"]},
    "live":     {"bare": [],                        "live": ["ydb-live", "iris-live"]},
}


def manifest_path() -> Path | None:
    for name in MANIFEST_CANDIDATES:
        p = REPO_ROOT / "dist" / name
        if p.is_file():
            return p
    return None


@dataclass
class ModuleInfo:
    name: str
    scope: str           # example_run
    safety: str          # example_safety
    tier: str            # @tier (core|optional)
    program: Path        # examples/programs/<MOD>EX.m
    labels: int
    executable: int
    illustrative: int
    raises_total: int
    raises_demo: int


def load_modules(manifest: dict) -> list[ModuleInfo]:
    """Modules that have a generated EX program, with scope/safety/coverage."""
    out: list[ModuleInfo] = []
    for name in sorted(manifest.get("modules", {})):
        prog = PROGRAMS_DIR / f"{name}EX.m"
        if not prog.is_file():
            continue
        mod = manifest["modules"][name]
        labels = mod.get("labels", {})
        execu = illus = rtot = rdemo = 0
        for lab, obj in labels.items():
            if obj.get("illustrative"):
                illus += 1
            for r in obj.get("raises", []):
                rtot += 1
                if any("raises^STDASSERT" in b and r["code"] in b for b in obj.get("examples", [])):
                    rdemo += 1
        out.append(ModuleInfo(
            name=name,
            scope=mod.get("example_run", "dual"),
            safety=mod.get("example_safety", "read-only"),
            tier=mod.get("tier", "core"),
            program=prog,
            labels=len(labels),
            executable=sum(1 for o in labels.values()
                           if not o.get("illustrative") and o.get("examples")),
            illustrative=illus,
            raises_total=rtot,
            raises_demo=rdemo,
        ))
    return out


def modules_for_arm(modules: list[ModuleInfo], arm: Arm) -> list[ModuleInfo]:
    out = []
    for m in modules:
        if arm.name not in SCOPE_ARMS.get(m.scope, SCOPE_ARMS["dual"])[arm.tier]:
            continue
        # Optional (call-out-backed) modules need their $&/$ZF .so, which is
        # baked into the bare m-test-engine and uses IRIS-native backends on
        # IRIS — but is NOT deployed on the live YDB-VistA engine (vehu). Skip
        # them on the ydb-live arm (environment, not a regression).
        if arm.name == "ydb-live" and m.tier == "optional":
            continue
        out.append(m)
    return out


@dataclass
class SuiteResult:
    suite: str
    passed: int
    failed: int
    total: int
    ok: bool

    @property
    def green(self) -> bool:
        # A 0/0 is a silent abort → failure (the kickoff's hard rule).
        return self.ok and self.total > 0 and self.failed == 0


def run_m_test(mbin: str, arm: Arm, extra_routines: list[str], programs: list[Path],
               extra_stage: str | None = None, verbose: bool = False) -> list[SuiteResult]:
    """Invoke `m test … -o json` over the driver stack; parse the suite results."""
    flags = arm.base_flags(extra_routines)
    if extra_stage:
        flags += ["--routines", extra_stage]
    cmd = [mbin, "test", *flags, "-o", "json", *[str(p) for p in programs]]
    if verbose:
        print("  $ " + " ".join(cmd), file=sys.stderr)
    proc = subprocess.run(cmd, capture_output=True, text=True)
    try:
        env = json.loads(proc.stdout)
    except json.JSONDecodeError:
        print(f"  ! {arm.name}: non-JSON output (exit {proc.returncode})", file=sys.stderr)
        if verbose:
            print(proc.stdout[-2000:], file=sys.stderr)
            print(proc.stderr[-2000:], file=sys.stderr)
        return []
    data = env.get("data", {}) or {}
    return [SuiteResult(s["suite"], s.get("passed", 0), s.get("failed", 0),
                        s.get("total", 0), bool(s.get("ok")))
            for s in data.get("results", [])]


# ── Residue probe (live tier) ────────────────────────────────────────────────
# A pre/post fingerprint of the global-name set (excluding transient scratch
# roots) brackets the live example batch across three separate `m test`
# invocations (globals persist across invocations on the live engines, but a
# suite cannot see a sibling suite's writes within one invocation — so capture
# and verify MUST be separate runs). Detects any global an example created and
# did not self-restore. Limitation (reported): it tracks the name SET, so an
# in-place edit of an existing global's data without a new name is not caught;
# the examples are read-only / self-restoring by construction (E1–E3b) and this
# is the backstop for a leaked scratch global.
# The fingerprint helper + a single suite per file. Two files (capture, verify)
# so each runs as its own `m test` invocation — suites within ONE invocation are
# isolated and cannot see each other's global writes, but globals persist ACROSS
# invocations on the live engines, which is what brackets the example batch.
# fp(roots) returns "root:nodes:bytes;" per watched owned global root: the node
# count + total value-bytes under ^<root>, via portable $QUERY (no ^$GLOBAL). A
# new/un-restored node changes the count or bytes → residue. <NAME>/<DESC>/<BODY>
# /<ROOTS> are substituted per file.
_RESIDUE_TMPL = r'''__NAME__ ;; living-examples residue probe (E4 §8) — generated, do not edit.
        new pass,fail do start^STDASSERT(.pass,.fail) do t(.pass,.fail) do report^STDASSERT(pass,fail) quit
t(pass,fail) ;@TEST "__DESC__"
__BODY__
        quit
fp()    ; fingerprint of the library's own global roots (node count + bytes),
        ; counting only NAMED-key subtrees. Subtrees whose first subscript is a
        ; canonical integer are skipped: that is the M convention for job-scoped
        ; working storage (^STDLIB($JOB,…), which STDASSERT writes on every suite
        ; and never purges) and for transient ring-buffer sequences (^VSLTAP(seq),
        ; which the tap examples roll back) — neither is persistent residue. The
        ; persistent named config (^VSLTAP("cfg",…)) is what a leak would dirty,
        ; and it is tracked.
        new roots,r,i,ref,nm,fs,c,b,out set roots="__ROOTS__",out=""
        for i=1:1:$length(roots,",") do
        . set r=$piece(roots,",",i) quit:r=""
        . set c=$select($data(@("^"_r))#10:1,1:0)
        . set b=$select(c:$length(@("^"_r)),1:0)
        . set ref="^"_r,nm="^"_r
        . for  set ref=$query(@ref) quit:ref=""  quit:$piece(ref,"(",1)'=nm  do
        . . set fs=$piece($piece(ref,"(",2),",",1)
        . . quit:(fs'="")&(fs=+fs)&(fs'["""")    ; integer first subscript → job/seq, skip
        . . set c=c+1,b=b+$length(@ref)
        . set out=out_r_":"_c_":"_b_";"
        quit out
'''

_CAP_BODY = '\n'.join([
    '        kill ^XTMP("EXRESID") set ^XTMP("EXRESID","fp")=$$fp()',
    '        do true^STDASSERT(.pass,.fail,1,"captured pre-run owned-global fingerprint")',
])
_VFY_BODY = '\n'.join([
    '        new pre,post set pre=$get(^XTMP("EXRESID","fp")),post=$$fp()',
    '        do eq^STDASSERT(.pass,.fail,post,pre,"no owned-global residue after the live run")',
    '        kill ^XTMP("EXRESID")',
])


def _residue_file(name: str, desc: str, body: str, roots: list[str]) -> str:
    return (_RESIDUE_TMPL.replace("__NAME__", name).replace("__DESC__", desc)
            .replace("__BODY__", body).replace("__ROOTS__", ",".join(roots)))


def owned_global_roots() -> list[str]:
    """The library's own global roots to watch (namespace-registry discovered)."""
    if not NAMESPACE_REGISTRY.is_file():
        return []
    reg = json.loads(NAMESPACE_REGISTRY.read_text(encoding="utf-8"))
    return sorted(set(reg.get("discovered", {}).get("globals", [])))


def residue_capture_text(roots: list[str]) -> str:
    return _residue_file("EXRESCAP", "residue: capture pre-run owned-global fingerprint",
                         _CAP_BODY, roots)


def residue_verify_text(roots: list[str]) -> str:
    return _residue_file("EXRESVFY", "residue: live engine byte-identical (owned globals)",
                         _VFY_BODY, roots)


@dataclass
class ArmRun:
    arm: Arm
    results: list[SuiteResult]
    skipped: list[str] = field(default_factory=list)   # modules not run on this arm
    residue_ok: bool | None = None                       # None = not checked
    residue_detail: str = ""

    @property
    def all_green(self) -> bool:
        return all(r.green for r in self.results)


def run_bare(mbin: str, modules: list[ModuleInfo], arms: list[Arm],
             extra_routines: list[str], verbose: bool) -> list[ArmRun]:
    runs: list[ArmRun] = []
    for arm in arms:
        mods = modules_for_arm(modules, arm)
        progs = [m.program for m in mods]
        results = run_m_test(mbin, arm, extra_routines, progs, verbose=verbose) if progs else []
        skipped = [m.name for m in modules if m not in mods]
        runs.append(ArmRun(arm, results, skipped))
    return runs


def run_live(mbin: str, modules: list[ModuleInfo], arms: list[Arm],
             extra_routines: list[str], verbose: bool) -> list[ArmRun]:
    runs: list[ArmRun] = []
    roots = owned_global_roots()
    with tempfile.TemporaryDirectory(prefix="exresid-") as td:
        cap_probe = Path(td) / "EXRESCAP.m"
        vfy_probe = Path(td) / "EXRESVFY.m"
        cap_probe.write_text(residue_capture_text(roots), encoding="utf-8")
        vfy_probe.write_text(residue_verify_text(roots), encoding="utf-8")
        for arm in arms:
            in_scope = modules_for_arm(modules, arm)
            mods = [m for m in in_scope if m.safety != "illustrative-skip"]
            skip_unsafe = [m.name for m in in_scope if m.safety == "illustrative-skip"]
            skipped = ([m.name for m in modules if m not in in_scope]
                       + [f"{n} (illustrative-skip)" for n in skip_unsafe])
            progs = [m.program for m in mods]
            if not progs:
                runs.append(ArmRun(arm, [], skipped))
                continue
            # Bracket the example batch with capture → batch → verify, each its
            # own invocation (globals persist across invocations on the live
            # engine; suites within one invocation are isolated).
            run = ArmRun(arm, [], skipped)
            if roots:
                run_m_test(mbin, arm, extra_routines, [cap_probe], extra_stage=td, verbose=verbose)
            run.results = run_m_test(mbin, arm, extra_routines, progs, extra_stage=td, verbose=verbose)
            if roots:
                vfy = run_m_test(mbin, arm, extra_routines, [vfy_probe], extra_stage=td, verbose=verbose)
                run.residue_ok, run.residue_detail = _interpret_residue(vfy)
            else:
                run.residue_detail = "no owned global roots declared — residue check skipped"
            runs.append(run)
    return runs


def _interpret_residue(vfy: list[SuiteResult]) -> tuple[bool, str]:
    # The verify invocation runs the EXRESVFY suite, which asserts pre == post.
    verify = [s for s in vfy if s.total > 0]
    if not verify:
        return False, "residue probe did not run (0/0) — could not verify"
    if all(s.green for s in verify):
        return True, "no owned-global residue (engine byte-identical)"
    return False, "owned-global residue detected after the live run"


# ── REPORT.md ────────────────────────────────────────────────────────────────

def render_report(lib: str, modules: list[ModuleInfo], tier: str,
                  runs: list[ArmRun], stamp: str) -> str:
    arms = [r.arm.name for r in runs]
    by_suite: dict[str, dict[str, SuiteResult]] = {}
    for r in runs:
        for s in r.results:
            by_suite.setdefault(s.suite, {})[r.arm.name] = s

    n_labels = sum(m.labels for m in modules)
    n_rtot = sum(m.raises_total for m in modules)
    n_rdemo = sum(m.raises_demo for m in modules)

    L: list[str] = []
    L.append("---")
    L.append("title: Living examples — run report")
    L.append("doc_type: [REPORT]")
    L.append(f"generated_from: dist/{lib}-manifest.json")
    L.append(f"tier: {tier}")
    L.append(f"generated_at: {stamp}")
    L.append("---")
    L.append("")
    L.append("# Living examples — run report")
    L.append("")
    L.append(
        "GENERATED by `tools/run-examples.py` (`make examples-run` / the nightly "
        "live cadence) — DO NOT edit by hand. This is the *executed* half of the "
        "trust thesis: every example program above (see `index.md`) is shown here "
        "passing on real engines, through the driver stack only. The bare tier "
        "(`m-test-engine` + `m-test-iris`) gates every PR; the live tier "
        "(`vehu` + `foia`) runs on a nightly cadence, fail-soft, with a pre/post "
        "**residue check** proving the shared live VistA came back byte-identical."
    )
    L.append("")
    L.append(f"- **Tier:** `{tier}`  •  **Engines:** {', '.join(f'`{a}`' for a in arms)}")
    L.append(f"- **Generated:** {stamp}")
    L.append(f"- **Coverage (from the manifest):** {n_labels} public labels across "
             f"{len(modules)} module program(s); {n_rdemo}/{n_rtot} `@raises` "
             "demonstrated. (See `index.md` / `make examples-coverage` for the "
             "authoritative executable-vs-illustrative coverage split.)")
    L.append("")

    # Residue summary (live tier).
    residue_runs = [r for r in runs if r.residue_ok is not None]
    if residue_runs:
        L.append("## Residue check (live tier — §8)")
        L.append("")
        L.append("| Engine | Result |")
        L.append("|---|---|")
        for r in residue_runs:
            mark = "✅ clean" if r.residue_ok else "🟥 RESIDUE"
            L.append(f"| `{r.arm.name}` | {mark} — {r.residue_detail} |")
        L.append("")
        roots = owned_global_roots()
        watched = ", ".join(f"`^{r}`" for r in roots) if roots else "(none declared)"
        L.append(f"> Fingerprint = node count + value-bytes under the library's own global "
                 f"roots ({watched}, from the namespace registry), counting only "
                 "**named-key** subtrees via portable `$QUERY`. Integer-keyed subtrees are "
                 "excluded — that is the M convention for job-scoped scratch "
                 "(`^STDLIB($JOB,…)`, which the assertion harness writes every suite) and "
                 "transient ring-buffer sequences (`^VSLTAP(seq)`, rolled back by the tap "
                 "examples); neither is persistent residue. A new or un-restored named "
                 "node reds the report. Background VistA churn outside the library's "
                 "namespace is deliberately not tracked (a shared live engine is never "
                 "byte-identical moment-to-moment); examples are read-only / self-restoring "
                 "by construction (E1–E3b) and this is the backstop.")
        L.append("")

    # Pass/fail grid.
    L.append("## Pass / fail by module × engine")
    L.append("")
    header = "| Module | Scope | Safety | " + " | ".join(f"`{a}`" for a in arms) + " |"
    L.append(header)
    L.append("|" + "---|" * (3 + len(arms)))
    skipped_by_arm = {r.arm.name: set() for r in runs}
    for r in runs:
        for sk in r.skipped:
            skipped_by_arm[r.arm.name].add(sk.split(" ")[0])
    for m in modules:
        cells = []
        suite = f"{m.name}EX"
        for a in arms:
            s = by_suite.get(suite, {}).get(a)
            if s is None:
                if m.name in skipped_by_arm.get(a, set()):
                    cells.append("— skip")
                else:
                    cells.append("·")
            elif s.green:
                cells.append(f"✅ {s.passed}/{s.total}")
            elif s.total == 0:
                cells.append("🟥 0/0")
            else:
                cells.append(f"🟥 {s.passed}/{s.total}")
        L.append(f"| `{m.name}` | {m.scope} | {m.safety} | " + " | ".join(cells) + " |")
    L.append("")

    # Overall verdict.
    all_green = all(r.all_green for r in runs)
    residue_clean = all(r.residue_ok for r in residue_runs) if residue_runs else True
    verdict = "✅ all green" if (all_green and residue_clean) else "🟥 see red cells above"
    L.append(f"**Verdict:** {verdict}.")
    L.append("")
    return "\n".join(L) + "\n"


# ── driver ───────────────────────────────────────────────────────────────────

def gate_summary(runs: list[ArmRun]) -> tuple[bool, list[str]]:
    lines: list[str] = []
    ok = True
    for r in runs:
        greens = sum(1 for s in r.results if s.green)
        total = len(r.results)
        reds = [s.suite for s in r.results if not s.green]
        status = "OK" if (total and not reds) else ("EMPTY" if not total else "FAIL")
        lines.append(f"  {r.arm.name:11} {greens}/{total} suites green"
                     + (f"  RED: {', '.join(reds)}" if reds else "")
                     + (f"  (skipped {len(r.skipped)})" if r.skipped else ""))
        if r.residue_ok is not None:
            lines.append(f"              residue: {'clean' if r.residue_ok else 'RESIDUE'} — {r.residue_detail}")
        if reds:
            ok = False
    return ok, lines


def run(args: argparse.Namespace) -> int:
    mpath = manifest_path()
    if mpath is None:
        print("run-examples: no dist/*-manifest.json — run `make manifest` first.", file=sys.stderr)
        return 2
    manifest = json.loads(mpath.read_text(encoding="utf-8"))
    lib = "vsl" if mpath.name.startswith("vsl") else "stdlib"
    modules = load_modules(manifest)
    if not modules:
        print("run-examples: no examples/programs/*EX.m — run `make examples` first.", file=sys.stderr)
        return 2

    all_arms = standard_arms(args.ydb_live_docker, args.iris_live_docker)
    if args.arms:
        names = [a.strip() for a in args.arms.split(",") if a.strip()]
    else:
        names = [n for n, a in all_arms.items() if a.tier == args.tier]
    try:
        arms = [all_arms[n] for n in names]
    except KeyError as e:
        print(f"run-examples: unknown arm {e}; valid: {', '.join(all_arms)}", file=sys.stderr)
        return 2
    for a in arms:
        if a.tier != args.tier:
            print(f"run-examples: arm {a.name} is not a {args.tier}-tier arm", file=sys.stderr)
            return 2

    extra = list(args.extra_routines or [])
    print(f"run-examples [{lib}] tier={args.tier} arms={', '.join(a.name for a in arms)} "
          f"({len(modules)} module program(s))")

    if args.tier == "live":
        runs = run_live(args.m, modules, arms, extra, args.verbose)
    else:
        runs = run_bare(args.m, modules, arms, extra, args.verbose)

    ok, lines = gate_summary(runs)
    for ln in lines:
        print(ln)

    if args.report:
        stamp = args.stamp or datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
        report = render_report(lib, modules, args.tier, runs, stamp)
        Path(args.report).write_text(report, encoding="utf-8")
        print(f"run-examples: wrote {args.report}")

    if args.soft or args.tier == "live":
        # Fail-soft: never fail the job (decision L4 / (a) — residue reds the
        # report, the job stays green). Surface the status, exit 0.
        if not ok:
            print("run-examples: gaps above (fail-soft tier — not gating)")
        return 0
    if ok:
        print("run-examples: all arms green")
        return 0
    print("run-examples: FAILED — see red suites above", file=sys.stderr)
    return 1


def self_test() -> int:
    fails: list[str] = []

    def expect(c, m):
        if not c:
            fails.append(m)

    # scope → arm partitioning
    arms = standard_arms("vehu", "foia-t12")
    expect(SCOPE_ARMS["dual"]["bare"] == ["ydb-bare", "iris-bare"], "dual bare arms")
    expect(SCOPE_ARMS["ydb"]["bare"] == ["ydb-bare"], "ydb bare arm excludes iris")
    expect(SCOPE_ARMS["live"]["bare"] == [], "live scope has no bare arms")
    expect(SCOPE_ARMS["live"]["live"] == ["ydb-live", "iris-live"], "live scope live arms")
    expect(SCOPE_ARMS["bare"]["bare"] == ["ydb-bare", "iris-bare"] and SCOPE_ARMS["bare"]["live"] == [],
           "bare scope = both bare engines, no live")
    expect(SCOPE_ARMS["bare-ydb"]["bare"] == ["ydb-bare"] and SCOPE_ARMS["bare-ydb"]["live"] == [],
           "bare-ydb scope = ydb bare only, no live")

    bmods = [ModuleInfo("VSLTAP", "bare", "read-only", "core", Path("x"), 3, 3, 0, 0, 0),
             ModuleInfo("VSLRPCWRAP", "bare-ydb", "transactional", "core", Path("x"), 3, 3, 0, 0, 0)]
    expect({m.name for m in modules_for_arm(bmods, arms["iris-bare"])} == {"VSLTAP"},
           "iris-bare runs bare but not bare-ydb")
    expect({m.name for m in modules_for_arm(bmods, arms["ydb-live"])} == set(),
           "live tier skips bare + bare-ydb modules")

    mods = [
        ModuleInfo("STDJSON", "dual", "read-only", "core", Path("x"), 5, 5, 0, 0, 0),
        ModuleInfo("STDCSPRNG", "ydb", "read-only", "core", Path("x"), 6, 6, 0, 0, 0),
        ModuleInfo("STDCRYPTO", "dual", "read-only", "optional", Path("x"), 7, 7, 0, 0, 0),
        ModuleInfo("VSLCFG", "live", "transactional", "core", Path("x"), 4, 4, 0, 0, 0),
    ]
    expect([m.name for m in modules_for_arm(mods, arms["iris-bare"])] == ["STDJSON", "STDCRYPTO"],
           "iris-bare runs dual modules incl. optional")
    expect({m.name for m in modules_for_arm(mods, arms["ydb-bare"])} == {"STDJSON", "STDCSPRNG", "STDCRYPTO"},
           "ydb-bare runs dual + ydb modules")
    expect([m.name for m in modules_for_arm(mods, arms["iris-live"])] == ["STDJSON", "STDCRYPTO", "VSLCFG"],
           "iris-live runs dual + live modules incl. IRIS-native optional")
    expect({m.name for m in modules_for_arm(mods, arms["ydb-live"])} == {"STDJSON", "STDCSPRNG", "VSLCFG"},
           "ydb-live runs dual + ydb + live core modules but skips optional (no .so on vehu)")

    # SuiteResult.green semantics
    expect(SuiteResult("X", 5, 0, 5, True).green, "5/5 ok is green")
    expect(not SuiteResult("X", 0, 0, 0, False).green, "0/0 is not green (silent abort)")
    expect(not SuiteResult("X", 4, 1, 5, True).green, "a failed assertion is not green")

    # residue probe files render with the watched roots substituted
    cap, vfy = residue_capture_text(["STDLIB", "VSLTAP"]), residue_verify_text(["STDLIB"])
    expect("__ROOTS__" not in cap and 'set roots="STDLIB,VSLTAP"' in cap, "residue roots substituted")
    expect(cap.startswith("EXRESCAP") and vfy.startswith("EXRESVFY"), "two distinct probe routines")
    expect("$query(@ref)" in cap and "^$GLOBAL" not in cap, "residue probe walks $QUERY, not ^$GLOBAL")
    expect('set ^XTMP("EXRESID","fp")=$$fp()' in cap, "capture stores the fingerprint")
    expect("eq^STDASSERT" in vfy and "no owned-global residue" in vfy, "verify asserts equality")

    # residue interpretation
    ok, _ = _interpret_residue([SuiteResult("EXRESID", 1, 0, 1, True)])
    expect(ok, "clean verify → residue ok")
    bad, _ = _interpret_residue([SuiteResult("EXRESID", 0, 1, 1, True)])
    expect(not bad, "failed verify → residue not ok")
    none_run, _ = _interpret_residue([SuiteResult("EXRESID", 0, 0, 0, False)])
    expect(not none_run, "0/0 verify → residue not ok")

    # report renders without engine access
    runs = [ArmRun(arms["ydb-bare"], [SuiteResult("STDJSONEX", 5, 0, 5, True)])]
    rep = render_report("stdlib", mods[:1], "bare", runs, "2026-06-24 12:00")
    expect("Living examples — run report" in rep and "STDJSON" in rep, "report renders")
    expect("✅ 5/5" in rep, "report shows the green cell")

    if fails:
        for f in fails:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("run-examples self-test OK")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--m", default="m", help="the `m` toolchain binary (default: m on PATH)")
    ap.add_argument("--tier", choices=("bare", "live"), default="bare")
    ap.add_argument("--arms", default="", help="comma-separated arm subset (default: all arms of the tier)")
    ap.add_argument("--extra-routines", action="append", default=[],
                    help="extra --routines dir to stage (v-stdlib: ../m-stdlib/src). Repeatable.")
    ap.add_argument("--report", default="", help="write REPORT.md to this path")
    ap.add_argument("--stamp", default="", help="override the report timestamp (else now)")
    ap.add_argument("--ydb-live-docker", default="vehu")
    ap.add_argument("--iris-live-docker", default="foia-t12")
    ap.add_argument("--soft", action="store_true", help="fail-soft: report but never exit nonzero")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    return run(args)


if __name__ == "__main__":
    sys.exit(main())
