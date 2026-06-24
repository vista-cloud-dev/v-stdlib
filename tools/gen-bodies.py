#!/usr/bin/env python3
"""Generate the delimited API-reference body block on each module page.

stdlib-docs Phase 4 / AC4. The module-page contract has two regions:

  1. A **generated API-reference block** — a signature table + per-label
     params / returns / raises / @example, rendered from the manifest.
     Maintained ONLY by this tool, between HTML-comment markers.
  2. Everything else on the page — the hand-written prose (intro, Status,
     architecture, gotchas, examples, See also, History). NEVER touched.

Because the generator owns ONLY the text between the markers, hand prose
survives every regeneration by construction (risk R-CLOBBER). Edit a
signature in `src/*.m`, run `make manifest docs-bodies`, and the block
updates on the next make; the prose block is preserved (AC4).

Placement: the block is inserted as the first `## ` section (after the
page intro, before the first existing `## ` heading); on regen it is
found by its markers and replaced in place. Idempotent.

Engine-free. A maintained byte-identical sibling shared between m-stdlib
and v-stdlib — the only per-repo difference is data (the manifest name,
auto-discovered).

Usage:
  python3 tools/gen-bodies.py            # rewrite the block on every page
  python3 tools/gen-bodies.py --check    # exit 1 if any page's block is stale
  python3 tools/gen-bodies.py --self-test
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_CANDIDATES = ("vsl-manifest.json", "stdlib-manifest.json")

BEGIN = ("<!-- BEGIN GENERATED API REFERENCE — managed by tools/gen-bodies.py "
         "(`make docs-bodies`); edits between these markers are overwritten. -->")
END = "<!-- END GENERATED API REFERENCE -->"


def manifest_path(root: Path) -> Path | None:
    for name in MANIFEST_CANDIDATES:
        p = root / "dist" / name
        if p.is_file():
            return p
    return None


def _lib_manifest_name(root: Path) -> str:
    p = manifest_path(root)
    return p.name if p else "the manifest"


# -----------------------------------------------------------------------------
# Render the block from one module's manifest entry
# -----------------------------------------------------------------------------


def render_block(name: str, mod: dict, manifest_name: str) -> str:
    labels = mod.get("labels", {})
    lines: list[str] = []
    lines.append(BEGIN)
    lines.append("## API reference")
    lines.append("")
    lines.append(
        f"_Generated from `dist/{manifest_name}` — the canonical,"
        " always-current signature / parameter / return / error surface."
        " Usage narrative and gotchas live in the prose sections._"
    )
    lines.append("")
    if not labels:
        lines.append("_This module exposes no public labels._")
        lines.append("")
        lines.append(END)
        return "\n".join(lines)

    # Signature index table.
    lines.append("| Label | Signature | Summary |")
    lines.append("|---|---|---|")
    for lname in sorted(labels):
        lab = labels[lname]
        sig = lab.get("signature") or f"{lname}^{name}"
        syn = _md_cell((lab.get("synopsis") or "").strip())
        lines.append(f"| `{lname}` | `{sig}` | {syn} |")
    lines.append("")

    # Per-label detail.
    for lname in sorted(labels):
        lab = labels[lname]
        sig = lab.get("signature") or f"{lname}^{name}"
        lines.append(f"### `{sig}`")
        lines.append("")
        syn = (lab.get("synopsis") or "").strip()
        if syn:
            lines.append(syn)
            lines.append("")
        if lab.get("deprecated"):
            lines.append(f"> **Deprecated.** {lab['deprecated']}")
            lines.append("")
        params = lab.get("params") or []
        if params:
            lines.append("**Parameters**")
            lines.append("")
            for p in params:
                pname = p.get("name", "?")
                ptype = p.get("type", "")
                pdoc = (p.get("doc") or "").strip()
                tpart = f" _({ptype})_" if ptype else ""
                dpart = f" — {pdoc}" if pdoc else ""
                lines.append(f"- `{pname}`{tpart}{dpart}")
            lines.append("")
        ret = lab.get("returns")
        if ret and (ret.get("type") or ret.get("doc")):
            rtype = ret.get("type", "")
            rdoc = (ret.get("doc") or "").strip()
            tpart = f"_{rtype}_" if rtype else ""
            sep = " — " if rtype and rdoc else ""
            lines.append(f"**Returns** {tpart}{sep}{rdoc}".rstrip())
            lines.append("")
        raises = lab.get("raises") or []
        if raises:
            lines.append("**Raises**")
            lines.append("")
            for r in raises:
                code = r.get("code", "?")
                rdoc = (r.get("doc") or "").strip()
                dpart = f" — {rdoc}" if rdoc else ""
                lines.append(f"- `{code}`{dpart}")
            lines.append("")
        examples = lab.get("examples") or []
        if examples:
            lines.append("**Example**")
            lines.append("")
            lines.append("```m")
            for ex in examples:
                lines.append(ex)
            lines.append("```")
            lines.append("")
    # trim a trailing blank before the END marker, keep exactly one
    while lines and lines[-1] == "":
        lines.pop()
    lines.append("")
    lines.append(END)
    return "\n".join(lines)


def _md_cell(s: str) -> str:
    """Make a one-line, pipe-safe table cell."""
    return s.replace("|", "\\|").replace("\n", " ")


# -----------------------------------------------------------------------------
# Splice the block into a page (insert or replace-in-place)
# -----------------------------------------------------------------------------


def splice(page: str, block: str) -> str:
    """Return `page` with `block` inserted or replaced between the markers."""
    if BEGIN in page and END in page:
        pre, rest = page.split(BEGIN, 1)
        _, post = rest.split(END, 1)
        return pre + block + post
    # No markers yet: insert as the first `## ` section (after the intro).
    lines = page.splitlines(keepends=True)
    insert_at = None
    for i, line in enumerate(lines):
        if line.startswith("## "):
            insert_at = i
            break
    chunk = block + "\n\n"
    if insert_at is None:
        body = page.rstrip("\n")
        return body + "\n\n" + block + "\n"
    head = "".join(lines[:insert_at]).rstrip("\n")
    tail = "".join(lines[insert_at:])
    return head + "\n\n" + chunk + tail


# -----------------------------------------------------------------------------
# Drive over all pages
# -----------------------------------------------------------------------------


def _page_path(root: Path, name: str) -> Path:
    return root / "docs" / "modules" / f"{name.lower()}.md"


def _rewrite_all(root: Path, check: bool) -> tuple[int, list[str]]:
    mpath = manifest_path(root)
    if mpath is None:
        raise FileNotFoundError("no dist/*-manifest.json — run `make manifest` first")
    manifest = json.loads(mpath.read_text(encoding="utf-8"))
    modules = manifest.get("modules", {})
    mname = mpath.name
    changed: list[str] = []
    n = 0
    for name in sorted(modules):
        page_path = _page_path(root, name)
        if not page_path.is_file():
            # docs-check owns "missing page"; skip here.
            continue
        n += 1
        page = page_path.read_text(encoding="utf-8")
        block = render_block(name, modules[name], mname)
        new = splice(page, block)
        if new != page:
            changed.append(str(page_path.relative_to(root)))
            if not check:
                page_path.write_text(new, encoding="utf-8")
    return n, changed


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--check", action="store_true", help="exit 1 if any block is stale")
    p.add_argument("--self-test", action="store_true", help="run the inline self-test")
    args = p.parse_args(argv)

    if args.self_test:
        return self_test()

    try:
        n, changed = _rewrite_all(REPO_ROOT, check=args.check)
    except FileNotFoundError as e:
        print(f"gen-bodies: {e}", file=sys.stderr)
        return 2

    if args.check:
        if changed:
            print("gen-bodies --check: STALE — these pages' API block does not match the "
                  "manifest (run `make docs-bodies` and commit):", file=sys.stderr)
            for c in changed:
                print(f"  - {c}", file=sys.stderr)
            return 1
        print(f"gen-bodies: clean — {n} page API blocks match the manifest")
        return 0

    if changed:
        for c in changed:
            print(f"  updated: {c}")
    print(f"gen-bodies: {len(changed)}/{n} page API blocks rewritten")
    return 0


# -----------------------------------------------------------------------------
# self-test — fabricate a page + manifest entry, prove the contract
# -----------------------------------------------------------------------------


def self_test() -> int:
    failures: list[str] = []

    def expect(cond, msg):
        if not cond:
            failures.append(msg)

    mod = {
        "labels": {
            "greet": {
                "signature": "$$greet^STDFOO(who)",
                "synopsis": "Greet `who`.",
                "params": [{"name": "who", "type": "string", "doc": "the name"}],
                "returns": {"type": "string", "doc": "the greeting"},
                "raises": [{"code": "U-STDFOO-EMPTY", "doc": "who is empty"}],
                "examples": ['write $$greet^STDFOO("world")  ; "hello, world"'],
            }
        }
    }
    block = render_block("STDFOO", mod, "stdlib-manifest.json")
    expect(block.startswith(BEGIN) and block.rstrip().endswith(END),
           "block must be wrapped in the markers")
    for needle in ("## API reference", "$$greet^STDFOO(who)", "U-STDFOO-EMPTY",
                   "**Parameters**", "**Returns**", "**Raises**", "**Example**"):
        expect(needle in block, f"block missing {needle!r}")

    # 1. insert into a page with no markers — prose preserved, block before first '## '.
    page = ("---\nmodule: STDFOO\n---\n\n# `STDFOO` — toy\n\nIntro prose.\n\n"
            "## Notes\n\nHand-written gotcha.\n")
    out = splice(page, block)
    expect("Intro prose." in out and "Hand-written gotcha." in out,
           "insert must preserve all prose")
    expect(out.index("## API reference") < out.index("## Notes"),
           "block must land before the first '## ' section")
    expect(out.index(BEGIN) > out.index("Intro prose."),
           "block must land after the intro")

    # 2. idempotent — second splice changes nothing.
    out2 = splice(out, block)
    expect(out2 == out, "splice must be idempotent")

    # 3. replace-in-place on a manifest change — block updates, prose preserved.
    mod["labels"]["greet"]["signature"] = "$$greet^STDFOO(who, loud)"
    block2 = render_block("STDFOO", mod, "stdlib-manifest.json")
    out3 = splice(out, block2)
    expect("$$greet^STDFOO(who, loud)" in out3, "edited signature must appear")
    expect("$$greet^STDFOO(who)" not in out3, "old signature must be gone")
    expect("Intro prose." in out3 and "Hand-written gotcha." in out3,
           "prose must survive a regen")
    # exactly one marker pair after replace
    expect(out3.count(BEGIN) == 1 and out3.count(END) == 1,
           "replace must not duplicate the block")

    # 4. a page with NO '## ' section — block appended after intro.
    stub = "---\nx\n---\n\n# `STDBAR` — bar\n\nJust an intro.\n"
    outs = splice(stub, render_block("STDBAR", {"labels": {}}, "stdlib-manifest.json"))
    expect("Just an intro." in outs and BEGIN in outs, "append must keep intro + add block")

    if failures:
        for f in failures:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("gen-bodies self-test OK (4 cases)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
