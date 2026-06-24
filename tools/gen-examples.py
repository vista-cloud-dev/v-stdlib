#!/usr/bin/env python3
"""gen-examples (E1) — the living-examples generator.

Reads dist/<lib>-manifest.json and emits, per module, a self-verifying
runnable example program `examples/programs/<MOD>EX.m` from the module's
executable `@example` tags, plus a living-doc index `examples/index.md`
that surfaces every module's example coverage. Drift-gated (`--check`).

This is the E1 increment of the Living Executable Examples proposal
(docs `proposals/living-executable-examples.md`). It evolves the older
`gen-doctests.py` — same eligible-example classification — but writes to
the repo's `examples/` tree (the living-doc surface that travels with the
library) and adds the index. The richer surface (every label, `@raises`
error cases, `@fixture` sample data, live-VistA execution) is E2–E4; the
example PROGRAMS here subsume the `tests/*DOCTST.m` suites once E4 wires
their execution.

Engine-free; pure manifest-in, files-out; deterministic (sorted, no
timestamps). A byte-identical sibling between the stdlibs except the
manifest name (auto-discovered).

Usage:
  python3 tools/gen-examples.py            # regenerate examples/programs/ + index.md
  python3 tools/gen-examples.py --check    # drift gate
  python3 tools/gen-examples.py --coverage # E2 comprehensiveness report (advisory)
  python3 tools/gen-examples.py --coverage --strict  # exit 1 if <100% (flip-to-red, L5)
  python3 tools/gen-examples.py --self-test
  python3 tools/gen-examples.py --verbose  # trace classify decisions / list gaps
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_CANDIDATES = ("vsl-manifest.json", "stdlib-manifest.json")
EXAMPLES_DIR = REPO_ROOT / "examples"
PROGRAMS_DIR = EXAMPLES_DIR / "programs"
INDEX_PATH = EXAMPLES_DIR / "index.md"

# Pattern A (string): write <expr>  ; "<expected>"
PAT_WRITE_EXPECT_STR = re.compile(r'^\s*(?:write|w)\s+(.+?)\s+;\s*"((?:[^"\\]|\\.)*)"\s*$')
# Pattern A-num: write <expr>  ; <number>
PAT_WRITE_EXPECT_NUM = re.compile(r'^\s*(?:write|w)\s+(.+?)\s+;\s*(-?\d+(?:\.\d+)?)\s*$')


def manifest_path() -> Path | None:
    for name in MANIFEST_CANDIDATES:
        p = REPO_ROOT / "dist" / name
        if p.is_file():
            return p
    return None


def expression_is_self_contained(expr: str) -> bool:
    """True if expr references only literals + routine/intrinsic calls (no free vars)."""
    s = expr
    s = re.sub(r'"(?:[^"]|"")*"', "", s)
    s = re.sub(r"\$\$[A-Za-z%][A-Za-z0-9]*\^[A-Za-z%][A-Za-z0-9]*", "", s)
    s = re.sub(r"\$[A-Za-z]+", "", s)
    s = re.sub(r"\^[A-Za-z%][A-Za-z0-9]*", "", s)
    s = re.sub(r"-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?", "", s)
    return re.search(r"[A-Za-z]", s) is None


@dataclass(frozen=True)
class Example:
    module: str
    label: str
    expr: str
    expected: str
    is_prefix: bool
    is_numeric: bool = False

    @property
    def routine_name(self) -> str:
        safe = re.sub(r"[^A-Za-z0-9]", "", self.label) or "x"
        return "tExample" + safe[:1].upper() + safe[1:]

    @property
    def description(self) -> str:
        return f"example: {self.module}.{self.label}"


def classify(example: str) -> tuple[str, str, bool, bool] | None:
    s = example.strip()
    m = PAT_WRITE_EXPECT_STR.match(s)
    if m:
        expr = m.group(1).strip()
        if not expression_is_self_contained(expr):
            return None
        expected = m.group(2)
        is_prefix = expected.endswith("...")
        if is_prefix:
            expected = expected[:-3]
        return expr, expected, is_prefix, False
    m = PAT_WRITE_EXPECT_NUM.match(s)
    if m:
        expr = m.group(1).strip()
        if not expression_is_self_contained(expr):
            return None
        return expr, m.group(2), False, True
    return None


def collect(manifest: dict, *, verbose: bool = False) -> dict[str, list[Example]]:
    by_module: dict[str, list[Example]] = {}
    for module_name in sorted(manifest.get("modules", {})):
        labels = manifest["modules"][module_name].get("labels", {})
        for label_name in sorted(labels):
            for ex in labels[label_name].get("examples", []):
                cls = classify(ex)
                if cls is None:
                    if verbose:
                        print(f"  skip [{module_name}.{label_name}] {ex.strip()}", file=sys.stderr)
                    continue
                expr, expected, is_prefix, is_numeric = cls
                by_module.setdefault(module_name, []).append(
                    Example(module_name, label_name, expr, expected, is_prefix, is_numeric))
    return by_module


def m_string_literal(s: str) -> str:
    return '"' + s.replace('"', '""') + '"'


def render_program(module: str, examples: list[Example]) -> str:
    routine = f"{module}EX"
    indent = " " * 8

    def header(label: str, comment: str) -> str:
        return f"{label}{' ' * max(1, 8 - len(label))}{comment}"

    lines: list[str] = []
    lines.append(header(routine, f"; Living examples for {module} — generated from @example tags."))
    lines.append(f"{indent}; Generated by tools/gen-examples.py — DO NOT EDIT BY HAND.")
    lines.append(f"{indent}; Source: the {module} label @example tags (regenerate with `make examples`).")
    lines.append(f"{indent}; m-lint: disable-file=M-MOD-020,M-MOD-001,M-MOD-031")
    lines.append(f"{indent}new pass,fail")
    lines.append(f"{indent}do start^STDASSERT(.pass,.fail)")
    lines.append(f"{indent};")
    for ex in examples:
        lines.append(f"{indent}do {ex.routine_name}(.pass,.fail)")
    lines.append(f"{indent};")
    lines.append(f"{indent}do report^STDASSERT(pass,fail)")
    lines.append(f"{indent}quit")
    lines.append(f"{indent};")
    for ex in examples:
        desc = m_string_literal(ex.description)
        hdr = f"{ex.routine_name}(pass,fail)"
        lines.append(f"{hdr}{' ' * max(1, 32 - len(hdr))};@TEST {desc}")
        helper = "contains" if ex.is_prefix else "eq"
        expected_arg = ex.expected if ex.is_numeric else m_string_literal(ex.expected)
        lines.append(f"{indent}do {helper}^STDASSERT(.pass,.fail,{ex.expr},{expected_arg},{desc})")
        lines.append(f"{indent}quit")
        lines.append(f"{indent};")
    return "\n".join(lines) + "\n"


def render_index(manifest: dict, by_module: dict[str, list[Example]], lib: str) -> str:
    modules = manifest.get("modules", {})
    total_labels = sum(len(m.get("labels", {})) for m in modules.values())
    labels_with_exec = sum(len({e.label for e in by_module.get(name, [])}) for name in modules)
    n_programs = len(by_module)

    lines: list[str] = []
    lines.append("---")
    lines.append("title: Living examples — index")
    lines.append("doc_type: [INDEX]")
    lines.append(f"generated_from: dist/{lib}-manifest.json")
    lines.append("---")
    lines.append("")
    lines.append("# Living examples")
    lines.append("")
    lines.append(
        "Generated, self-verifying runnable example programs — one per module — built "
        "from each module's `@example` tags by `tools/gen-examples.py` (`make examples`). "
        "DO NOT edit by hand. Each `examples/programs/<MODULE>EX.m` runs as a suite "
        "(`do ^<MODULE>EX`) and asserts its own results."
    )
    lines.append("")
    pct = (100 * labels_with_exec // total_labels) if total_labels else 0
    lines.append(
        f"**Executable-example coverage: {labels_with_exec}/{total_labels} public labels "
        f"({pct}%)** across {n_programs} module program(s). The remaining labels carry no "
        "*executable* (`write … ; \"expected\"`, self-contained) example yet — closing that "
        "gap to 100% (with `@raises` error cases + sample data + live-VistA runs) is the "
        "Living Executable Examples roadmap (E2–E4)."
    )
    lines.append("")
    lines.append("| Module | Labels | With executable example | Program |")
    lines.append("|---|---|---|---|")
    for name in sorted(modules):
        labs = modules[name].get("labels", {})
        exec_labels = {e.label for e in by_module.get(name, [])}
        prog = f"[`{name}EX.m`](programs/{name}EX.m)" if name in by_module else "—"
        lines.append(f"| `{name}` | {len(labs)} | {len(exec_labels)} | {prog} |")
    lines.append("")
    return "\n".join(lines) + "\n"


def write_or_check(path: Path, content: str, *, check: bool) -> bool:
    if check:
        if not path.exists():
            print(f"DRIFT: missing {path.relative_to(REPO_ROOT)}", file=sys.stderr)
            return False
        if path.read_text(encoding="utf-8") != content:
            print(f"DRIFT: {path.relative_to(REPO_ROOT)} differs", file=sys.stderr)
            return False
        return True
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def run(check: bool, verbose: bool) -> int:
    mpath = manifest_path()
    if mpath is None:
        print("gen-examples: no dist/*-manifest.json — run `make manifest` first.", file=sys.stderr)
        return 2
    manifest = json.loads(mpath.read_text(encoding="utf-8"))
    lib = "vsl" if mpath.name.startswith("vsl") else "stdlib"
    by_module = collect(manifest, verbose=verbose)

    clean = True
    expected: set[Path] = set()
    for module in sorted(by_module):
        path = PROGRAMS_DIR / f"{module}EX.m"
        expected.add(path)
        clean &= write_or_check(path, render_program(module, by_module[module]), check=check)
    # orphan programs (a module that lost all eligible examples)
    if PROGRAMS_DIR.is_dir():
        for stale in set(PROGRAMS_DIR.glob("*EX.m")) - expected:
            if check:
                print(f"DRIFT: orphan {stale.relative_to(REPO_ROOT)}", file=sys.stderr)
                clean = False
            else:
                stale.unlink()
    clean &= write_or_check(INDEX_PATH, render_index(manifest, by_module, lib), check=check)

    if check:
        if clean:
            print(f"examples: clean — {len(by_module)} program(s) match the manifest")
        return 0 if clean else 1
    total = sum(len(v) for v in by_module.values())
    print(f"examples: wrote {len(by_module)} program(s), {total} example(s) + index")
    return 0


def raises_demonstrated(label_obj: dict, code: str) -> bool:
    """True if some @example in this label asserts `code` via raises^STDASSERT.

    The error-example contract (proposal §4): a `@raises CODE` is demonstrated by
    an example that triggers the path and asserts the code, e.g.
    `do raises^STDASSERT(.pass,.fail,"<trigger>","<CODE>","...")`. We detect it
    structurally: an example body that both calls raises^STDASSERT and names the
    code. Honest by construction — undemonstrated raises stay visible until E3
    authors the error-examples.
    """
    for body in label_obj.get("examples", []):
        if "raises^STDASSERT" in body and code in body:
            return True
    return False


@dataclass(frozen=True)
class Coverage:
    total: int
    executable: list[tuple[str, str]]
    illustrative: list[tuple[str, str, str]]
    uncovered: list[tuple[str, str]]
    raises_total: int
    raises_undemonstrated: list[tuple[str, str, str]]
    fixtures_referenced: int
    fixtures_missing: list[tuple[str, str, str]]
    fixtures_orphan: list[str]

    @property
    def clean(self) -> bool:
        return not (self.uncovered or self.raises_undemonstrated
                    or self.fixtures_missing or self.fixtures_orphan)


def gather_coverage(manifest: dict, by_module: dict[str, list[Example]]) -> Coverage:
    modules = manifest.get("modules", {})
    exec_labels = {name: {e.label for e in by_module.get(name, [])} for name in modules}
    total = 0
    executable: list[tuple[str, str]] = []
    illustrative: list[tuple[str, str, str]] = []
    uncovered: list[tuple[str, str]] = []
    raises_total = 0
    raises_undemonstrated: list[tuple[str, str, str]] = []
    referenced: set[str] = set()
    fixtures_missing: list[tuple[str, str, str]] = []

    for name in sorted(modules):
        labels = modules[name].get("labels", {})
        for label in sorted(labels):
            total += 1
            obj = labels[label]
            if label in exec_labels[name]:
                executable.append((name, label))
            elif obj.get("illustrative"):
                illustrative.append((name, label, obj["illustrative"]))
            else:
                uncovered.append((name, label))
            for r in obj.get("raises", []):
                raises_total += 1
                if not raises_demonstrated(obj, r["code"]):
                    raises_undemonstrated.append((name, label, r["code"]))
            for fx in obj.get("fixtures", []):
                path = fx["path"]
                referenced.add(path)
                if not (REPO_ROOT / path).is_file():
                    fixtures_missing.append((name, label, path))

    orphan: list[str] = []
    data_dir = EXAMPLES_DIR / "data"
    if data_dir.is_dir():
        for f in sorted(data_dir.rglob("*")):
            if f.is_file() and f.name != "README.md":
                rel = f.relative_to(REPO_ROOT).as_posix()
                if rel not in referenced:
                    orphan.append(rel)

    return Coverage(
        total=total, executable=executable, illustrative=illustrative, uncovered=uncovered,
        raises_total=raises_total, raises_undemonstrated=raises_undemonstrated,
        fixtures_referenced=len(referenced), fixtures_missing=fixtures_missing,
        fixtures_orphan=orphan,
    )


def coverage(strict: bool, verbose: bool) -> int:
    mpath = manifest_path()
    if mpath is None:
        print("gen-examples: no dist/*-manifest.json — run `make manifest` first.", file=sys.stderr)
        return 2
    manifest = json.loads(mpath.read_text(encoding="utf-8"))
    lib = "vsl" if mpath.name.startswith("vsl") else "stdlib"
    by_module = collect(manifest)
    cov = gather_coverage(manifest, by_module)

    n_exec, n_illus = len(cov.executable), len(cov.illustrative)
    n_covered = n_exec + n_illus
    pct = (100 * n_covered // cov.total) if cov.total else 0
    n_demo = cov.raises_total - len(cov.raises_undemonstrated)

    print(f"examples coverage — {lib}")
    print(f"  labels:   {n_covered}/{cov.total} covered ({pct}%)"
          f" — {n_exec} executable, {n_illus} illustrative, {len(cov.uncovered)} uncovered")
    print(f"  @raises:  {n_demo}/{cov.raises_total} demonstrated"
          f" — {len(cov.raises_undemonstrated)} undemonstrated")
    print(f"  @fixture: {cov.fixtures_referenced} referenced"
          f" — {len(cov.fixtures_missing)} missing, {len(cov.fixtures_orphan)} orphan")

    if verbose:
        for mod, lab in cov.uncovered:
            print(f"    uncovered: {mod}.{lab}", file=sys.stderr)
        for mod, lab, code in cov.raises_undemonstrated:
            print(f"    raises-undemonstrated: {mod}.{lab} → {code}", file=sys.stderr)
        for mod, lab, path in cov.fixtures_missing:
            print(f"    fixture-missing: {mod}.{lab} → {path}", file=sys.stderr)
        for path in cov.fixtures_orphan:
            print(f"    fixture-orphan: {path}", file=sys.stderr)

    if cov.clean:
        print("examples coverage: 100% — every label exampled, every @raises demonstrated, no orphan fixtures")
        return 0
    sys.stdout.flush()
    if strict:
        print("examples coverage: INCOMPLETE (strict) — see gaps above"
              " (re-run with --verbose to list them)", file=sys.stderr)
        return 1
    print("examples coverage: advisory — gaps above are the E3 backfill (not yet gating)")
    return 0


def self_test() -> int:
    failures: list[str] = []

    def expect(c, m):
        if not c:
            failures.append(m)

    expect(classify('write $$enc^STDB64("hi")  ; "aGk="') is not None, "Pattern-A string not classified")
    expect(classify("write $$n^STDX()  ; 42") is not None, "Pattern-A num not classified")
    expect(classify("write $$size^STDFS(path)  ; 5") is None, "free-var example must be skipped")
    expect(classify("do something") is None, "non-write example must be skipped")
    prog = render_program("STDFOO", [Example("STDFOO", "greet", '$$greet^STDFOO("x")', "hi, x", False)])
    expect(prog.startswith("STDFOOEX"), "program routine name")
    expect("eq^STDASSERT" in prog and "tExampleGreet" in prog, "program assertion shape")

    # coverage classification
    demo = {"examples": ['do raises^STDASSERT(.pass,.fail,"set x=$$f^STDFOO()","U-STDFOO-BAD","bad")'],
            "raises": [{"code": "U-STDFOO-BAD", "doc": "x"}]}
    expect(raises_demonstrated(demo, "U-STDFOO-BAD"), "@raises with matching error-example is demonstrated")
    expect(not raises_demonstrated(demo, "U-STDFOO-OTHER"), "@raises with no matching example is undemonstrated")
    expect(not raises_demonstrated({"examples": ['write $$f^STDFOO()  ; "1"'],
                                    "raises": []}, "U-STDFOO-BAD"),
           "a non-raises example does not demonstrate a raise")
    synth = {"modules": {"STDFOO": {"labels": {
        "a": {"examples": ['write $$a^STDFOO()  ; "1"'], "raises": []},
        "b": {"examples": [], "raises": [], "illustrative": "needs a live sink"},
        "c": {"examples": [], "raises": [{"code": "U-STDFOO-X", "doc": "x"}]},
    }}}}
    cov = gather_coverage(synth, collect(synth))
    expect(cov.total == 3, "coverage counts all labels")
    expect(len(cov.executable) == 1 and len(cov.illustrative) == 1 and len(cov.uncovered) == 1,
           "coverage buckets labels into executable / illustrative / uncovered")
    expect(cov.raises_total == 1 and len(cov.raises_undemonstrated) == 1,
           "coverage flags the undemonstrated raise")
    expect(not cov.clean, "synthetic coverage with gaps is not clean")
    if failures:
        for f in failures:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("gen-examples self-test OK")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--coverage", action="store_true")
    ap.add_argument("--strict", action="store_true", help="with --coverage: exit 1 if <100%")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if args.coverage:
        return coverage(args.strict, args.verbose)
    return run(args.check, args.verbose)


if __name__ == "__main__":
    sys.exit(main())
