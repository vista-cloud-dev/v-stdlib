#!/usr/bin/env python3
"""Documentation completeness gate (stdlib-docs Phase 2 / AC2).

Red when any `src/*.m` module lacks (a) a manifest entry **or** (b) a
`docs/modules/<module>.md` page — the exact failure the trailing,
page-less modules represent. This is the "docs always track newest code"
enforcement: add a module to `src/` without regenerating the manifest or
writing a page, and the gate goes red.

Engine-free (pure `python3`, no live engine). A maintained sibling shared
byte-for-byte between m-stdlib and v-stdlib: the only per-repo difference
is **data** — the manifest filename (auto-discovered) and a documented
allow-list.

Allow-list (`tools/docs-check-allow.txt`, one module per line, `#`
comments): modules whose page is *known-pending* (e.g. m-stdlib's 5
newest modules, authored in Phase 3). The gate ships GREEN with the
allow-list and goes red the moment an *unlisted* module drifts — so it
never blocks unrelated work (risk R-GATEBLOCK) yet still catches a real
regression. A missing allow file = no exemptions (v-stdlib's case).

Usage:
  python3 tools/check-docs.py            # --check (default): exit 1 on a real gap
  python3 tools/check-docs.py --check
  python3 tools/check-docs.py --list     # print the full coverage table
  python3 tools/check-docs.py --self-test
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_CANDIDATES = ("vsl-manifest.json", "stdlib-manifest.json")
ALLOW_REL = Path("tools") / "docs-check-allow.txt"


def manifest_path(root: Path) -> Path | None:
    for name in MANIFEST_CANDIDATES:
        p = root / "dist" / name
        if p.is_file():
            return p
    return None


def load_allow(root: Path) -> set[str]:
    allow_file = root / ALLOW_REL
    if not allow_file.is_file():
        return set()
    allow: set[str] = set()
    for line in allow_file.read_text(encoding="utf-8").splitlines():
        token = line.split("#", 1)[0].strip()
        if token:
            allow.add(token.upper())
    return allow


def scan(root: Path) -> list[dict] | None:
    """One row per src module: {module, manifest: bool, page: bool}."""
    mpath = manifest_path(root)
    if mpath is None:
        return None
    man_modules = set(json.loads(mpath.read_text(encoding="utf-8")).get("modules", {}))
    src_dir = root / "src"
    modules_dir = root / "docs" / "modules"
    src_modules = sorted(p.stem for p in src_dir.glob("*.m"))
    pages = {p.stem.lower() for p in modules_dir.glob("*.md")} if modules_dir.is_dir() else set()
    rows = []
    for m in src_modules:
        rows.append({
            "module": m,
            "manifest": m in man_modules,
            "page": m.lower() in pages,
        })
    return rows


def evaluate(root: Path) -> tuple[list[tuple[str, list[str]]], list[tuple[str, list[str]]], list[str]]:
    """Return (gaps, pending, stale_allow).

    gaps          modules with a missing entry/page that are NOT allow-listed → red.
    pending       allow-listed modules still missing something → green, reported.
    stale_allow   allow entries that are now complete or no longer in src → tidy-up.
    """
    rows = scan(root) or []
    allow = load_allow(root)
    present_modules = {r["module"].upper() for r in rows}
    incomplete: set[str] = set()
    gaps: list[tuple[str, list[str]]] = []
    pending: list[tuple[str, list[str]]] = []
    for r in rows:
        missing = []
        if not r["manifest"]:
            missing.append("manifest entry")
        if not r["page"]:
            missing.append("docs/modules page")
        if not missing:
            continue
        incomplete.add(r["module"].upper())
        if r["module"].upper() in allow:
            pending.append((r["module"], missing))
        else:
            gaps.append((r["module"], missing))
    stale_allow = sorted(
        a for a in allow if a not in incomplete or a not in present_modules
    )
    return gaps, pending, stale_allow


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--check", action="store_true", help="exit 1 on a real (unlisted) gap")
    p.add_argument("--list", action="store_true", help="print the coverage table and exit 0")
    p.add_argument("--self-test", action="store_true", help="run the inline behaviour self-test")
    args = p.parse_args(argv)

    if args.self_test:
        return self_test()

    if manifest_path(REPO_ROOT) is None:
        print("check-docs: no dist/*-manifest.json — run `make manifest` first.", file=sys.stderr)
        return 2

    rows = scan(REPO_ROOT) or []
    gaps, pending, stale = evaluate(REPO_ROOT)

    if args.list:
        print(f"docs coverage — {len(rows)} src modules:")
        for r in sorted(rows, key=lambda r: r["module"]):
            mark = "ok " if r["manifest"] and r["page"] else "GAP"
            print(f"  [{mark}] {r['module']}  manifest={int(r['manifest'])} page={int(r['page'])}")
        return 0

    for module, missing in pending:
        print(f"check-docs: pending (allow-listed): {module} — missing {', '.join(missing)}")
    if stale:
        print(f"check-docs: NOTE allow-list entries no longer needed (remove from "
              f"{ALLOW_REL}): {', '.join(stale)}", file=sys.stderr)
    if gaps:
        print("check-docs: INCOMPLETE — module(s) missing a manifest entry and/or a "
              "docs/modules page:", file=sys.stderr)
        for module, missing in gaps:
            print(f"  - {module}: missing {', '.join(missing)}", file=sys.stderr)
        print("  Fix: `make manifest frontmatter` (regenerate), then author the page; "
              "or add a known-pending module to tools/docs-check-allow.txt.", file=sys.stderr)
        return 1

    covered = len(rows) - len(pending)
    suffix = f" ({len(pending)} known-pending, allow-listed)" if pending else ""
    print(f"check-docs: clean — {covered}/{len(rows)} src modules fully documented{suffix}")
    return 0


# -----------------------------------------------------------------------------
# self-test — fabricate a tiny repo layout and assert green/red behaviour
# -----------------------------------------------------------------------------


def self_test() -> int:
    import shutil
    import tempfile

    failures: list[str] = []

    def expect(cond, msg):
        if not cond:
            failures.append(msg)

    def make_repo(tmp: Path, modules: list[str], pages: list[str],
                  manifest_modules: list[str], allow: list[str] | None) -> None:
        (tmp / "src").mkdir(parents=True, exist_ok=True)
        (tmp / "docs" / "modules").mkdir(parents=True, exist_ok=True)
        (tmp / "dist").mkdir(parents=True, exist_ok=True)
        (tmp / "tools").mkdir(parents=True, exist_ok=True)
        for m in modules:
            (tmp / "src" / f"{m}.m").write_text(f"{m}\t; fixture\n", encoding="utf-8")
        for m in pages:
            (tmp / "docs" / "modules" / f"{m.lower()}.md").write_text("---\n---\n", encoding="utf-8")
        (tmp / "dist" / "vsl-manifest.json").write_text(
            json.dumps({"modules": {m: {} for m in manifest_modules}}), encoding="utf-8")
        if allow is not None:
            (tmp / ALLOW_REL).write_text("\n".join(allow) + "\n", encoding="utf-8")

    tmp = Path(tempfile.mkdtemp())
    try:
        # 1. fully documented → no gaps, no pending.
        r = tmp / "complete"
        make_repo(r, ["VSLA", "VSLB"], ["VSLA", "VSLB"], ["VSLA", "VSLB"], None)
        gaps, pending, stale = evaluate(r)
        expect(not gaps, f"complete repo should have no gaps, got {gaps}")
        expect(not pending, f"complete repo should have no pending, got {pending}")

        # 2. a module missing its page, NOT allow-listed → a gap (red).
        r = tmp / "missing_page"
        make_repo(r, ["VSLA", "VSLB"], ["VSLA"], ["VSLA", "VSLB"], None)
        gaps, pending, stale = evaluate(r)
        expect([g for g in gaps if g[0] == "VSLB"], f"VSLB missing page should be a gap, got {gaps}")

        # 3. the same missing page, allow-listed → pending, NOT a gap (green).
        r = tmp / "missing_page_allowed"
        make_repo(r, ["VSLA", "VSLB"], ["VSLA"], ["VSLA", "VSLB"], ["VSLB"])
        gaps, pending, stale = evaluate(r)
        expect(not gaps, f"allow-listed missing page should not be a gap, got {gaps}")
        expect([p for p in pending if p[0] == "VSLB"], f"VSLB should be pending, got {pending}")

        # 4. a module missing its manifest entry (stale manifest) → a gap.
        r = tmp / "missing_manifest"
        make_repo(r, ["VSLA", "VSLB"], ["VSLA", "VSLB"], ["VSLA"], None)
        gaps, pending, stale = evaluate(r)
        expect([g for g in gaps if g[0] == "VSLB" and "manifest entry" in g[1]],
               f"VSLB missing manifest entry should be a gap, got {gaps}")

        # 5. a stale allow entry (module now complete) → reported as stale.
        r = tmp / "stale_allow"
        make_repo(r, ["VSLA"], ["VSLA"], ["VSLA"], ["VSLA"])
        gaps, pending, stale = evaluate(r)
        expect("VSLA" in stale, f"complete-but-allow-listed VSLA should be stale, got {stale}")

        if failures:
            for f in failures:
                print(f"FAIL: {f}", file=sys.stderr)
            return 1
        print("check-docs self-test OK (5 cases)")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
