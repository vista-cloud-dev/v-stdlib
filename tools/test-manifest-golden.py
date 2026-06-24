#!/usr/bin/env python3
"""Golden-file regression test for the adapted manifest generator (P1.7).

v-stdlib's `tools/gen-manifest.py` is a maintained sibling of m-stdlib's
(only the source glob, lib name, and output path differ — risk R-DRIFT).
This test freezes the *parser* contract independently of the live `src/`:
it parses one committed fixture module (`tools/fixtures/VSLGOLD.m`) and
diffs the resulting manifest slice against a committed golden JSON.

It pins the exact fields the prompt calls out — signature, params,
returns, raises, and `source.file:line` — so a future change to the tag
vocabulary or the parser that silently alters the manifest shape turns
this gate red instead of slipping through.

Engine-free (pure `python3`, no live engine). Mirrors the `--check` /
`--write` idiom of the repo's other generators.

Usage:
  python3 tools/test-manifest-golden.py            # --check (default)
  python3 tools/test-manifest-golden.py --check    # exit 1 on drift
  python3 tools/test-manifest-golden.py --write     # (re)generate the golden
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
FIXTURE = REPO_ROOT / "tools" / "fixtures" / "VSLGOLD.m"
GOLDEN = REPO_ROOT / "tools" / "fixtures" / "vslgold-manifest-slice.json"
GEN = REPO_ROOT / "tools" / "gen-manifest.py"


def _load_generator():
    """Import gen-manifest.py (hyphenated → not importable by name)."""
    spec = importlib.util.spec_from_file_location("gen_manifest", GEN)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _slice() -> dict:
    gen = _load_generator()
    return gen.parse_module_file(FIXTURE)


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--write", action="store_true", help="(re)generate the golden slice")
    p.add_argument("--check", action="store_true", help="diff parser output vs golden; exit 1 on drift")
    args = p.parse_args(argv)

    if not FIXTURE.is_file():
        print(f"golden-test: fixture missing — {FIXTURE}", file=sys.stderr)
        return 2

    actual = _slice()
    rendered = json.dumps(actual, indent=2, sort_keys=True, ensure_ascii=False) + "\n"

    if args.write:
        GOLDEN.write_text(rendered, encoding="utf-8")
        print(f"wrote {GOLDEN.relative_to(REPO_ROOT)}")
        return 0

    # default = --check
    if not GOLDEN.is_file():
        print(f"golden-test: golden missing — run `--write` ({GOLDEN})", file=sys.stderr)
        return 1
    expected = GOLDEN.read_text(encoding="utf-8")
    if rendered != expected:
        print("golden-test: DRIFT — parser output no longer matches the golden slice.", file=sys.stderr)
        print("  regenerate with `python3 tools/test-manifest-golden.py --write` if the change is intended.", file=sys.stderr)
        # Show a compact first-divergence hint.
        a, e = rendered.splitlines(), expected.splitlines()
        for i, (la, le) in enumerate(zip(a, e), 1):
            if la != le:
                print(f"  first diff at line {i}:\n    actual:   {la}\n    expected: {le}", file=sys.stderr)
                break
        return 1
    print("golden-test: clean (parser output matches the golden slice)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
