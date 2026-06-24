#!/usr/bin/env python3
"""Generate per-module doc stubs + the browsable index for v-stdlib.

A sibling of m-stdlib's tools/write-module-frontmatter.py. The structural
difference is intentional: m-stdlib *backfills* frontmatter onto pages
that already exist, while v-stdlib has **zero** module pages today, so
this variant also **creates** the stub page when one is absent. Phase 1
only needs the stubs to *exist* with synced frontmatter — the API-section
bodies are generated in Phase 4 and the human prose authored in Phase 3.

Reads:
  - dist/vsl-manifest.json     (synopsis, labels, errors, see_also per module)

Writes (under docs/modules/):
  - <module>.md                stub page (frontmatter + placeholder body) when
                               absent; frontmatter re-synced with --force
  - index.md                   the browsable per-repo catalogue (regenerated)

Idempotent. A page that already starts with `---` (frontmatter present) is
left untouched unless `--force` is given, so re-running never tramples a
hand-authored body. index.md is always regenerated from the manifest.

Frontmatter schema:
  module:     VSLXXX
  layer:      v                (the m/v waterline tag — metadata for Phase 5)
  since:      vX.Y.Z           (manifest version; "" until v-stdlib tags)
  stable:     stable
  synopsis:   one-line summary from the routine header
  labels:     public label names (from manifest)
  errors:     U-VSL* codes raised (from manifest)
  see_also:   related modules (aggregated from per-label @see tags) or []
  doc_type:   [REFERENCE]

Usage:
  python3 tools/write-module-frontmatter.py            # create missing stubs + index
  python3 tools/write-module-frontmatter.py --force    # also re-sync existing frontmatter
  python3 tools/write-module-frontmatter.py --dry-run  # report without writing
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MODULES_DIR = REPO_ROOT / "docs" / "modules"
INDEX_PATH = MODULES_DIR / "index.md"
MANIFEST_PATH = REPO_ROOT / "dist" / "vsl-manifest.json"

SYNOPSIS_PREFIX = "v-stdlib — "
MODULE_TOKEN_RE = re.compile(r"\bVSL[A-Z0-9]+\b")


def yaml_str(s: str) -> str:
    """Render a string as a single-quoted YAML scalar (colons, dashes safe)."""
    if not s:
        return '""'
    return "'" + s.replace("'", "''") + "'"


def yaml_list(items: list[str]) -> str:
    if not items:
        return "[]"
    return "[" + ", ".join(yaml_str(i) for i in items) + "]"


def clean_synopsis(raw: str) -> str:
    synopsis = (raw or "").strip()
    if synopsis.startswith(SYNOPSIS_PREFIX):
        synopsis = synopsis[len(SYNOPSIS_PREFIX):]
    if synopsis.endswith("."):
        synopsis = synopsis[:-1]
    return synopsis


def module_see_also(name: str, mod: dict) -> list[str]:
    """Aggregate sibling-module references from per-label @see tags."""
    sees: set[str] = set()
    for label in mod.get("labels", {}).values():
        for ref in label.get("see_also", []) or []:
            for tok in MODULE_TOKEN_RE.findall(ref):
                if tok != name:
                    sees.add(tok)
    return sorted(sees)


def render_frontmatter(name: str, mod: dict, version: str) -> str:
    synopsis = clean_synopsis(mod.get("synopsis", ""))
    labels = sorted(mod.get("labels", {}).keys())
    errors = sorted(mod.get("errors", []) or [])
    sees = module_see_also(name, mod)
    lines = [
        "---",
        f"module: {name}",
        "layer: v",
        f"since: {version}",
        "stable: stable",
        f"synopsis: {yaml_str(synopsis)}",
        f"labels: {yaml_list(labels)}",
        f"errors: {yaml_list(errors)}",
        f"see_also: {yaml_list(sees)}",
        "doc_type: [REFERENCE]",
        "---",
        "",
        "",
    ]
    return "\n".join(lines)


def stub_body(name: str, mod: dict) -> str:
    synopsis = clean_synopsis(mod.get("synopsis", ""))
    title = f"# `{name}` — {synopsis}" if synopsis else f"# `{name}`"
    return (
        f"{title}\n\n"
        "> **Stub.** The generated API section (signatures, params, returns,\n"
        "> errors) lands in Phase 4 and the human-prose sections (rationale,\n"
        "> gotchas) in Phase 3. Until then the frontmatter above — synced from\n"
        "> `dist/vsl-manifest.json` — is the source of truth for this module's\n"
        "> public labels and error codes, and\n"
        "> [`../../dist/skill/manifest-index.md`](../../dist/skill/manifest-index.md)\n"
        "> renders every signature with its synopsis.\n"
    )


def write_page(path: Path, name: str, mod: dict, version: str, force: bool, dry_run: bool) -> str:
    fm = render_frontmatter(name, mod, version)
    if not path.exists():
        if dry_run:
            return "would create"
        path.write_text(fm + stub_body(name, mod), encoding="utf-8")
        return "created"

    content = path.read_text(encoding="utf-8")
    has_fm = content.startswith("---\n")
    if has_fm and not force:
        return "skip-has-fm"
    if has_fm and force:
        end = content.find("\n---\n", 4)
        if end < 0:
            return "skip-malformed-fm"
        body = content[end + len("\n---\n"):].lstrip("\n")
        new = fm + body
        action = "force-resynced"
    else:
        new = fm + content
        action = "prepended-fm"
    if dry_run:
        return f"would {action}"
    path.write_text(new, encoding="utf-8")
    return action


def render_index(manifest: dict) -> str:
    version = manifest.get("stdlib_version") or "unversioned"
    modules = manifest.get("modules", {})
    label_count = sum(len(m.get("labels", {})) for m in modules.values())

    lines: list[str] = []
    lines.append("---")
    lines.append("title: v-stdlib module catalogue")
    lines.append("doc_type: [INDEX]")
    lines.append("generated_from: dist/vsl-manifest.json")
    lines.append("---")
    lines.append("")
    lines.append("# v-stdlib — module catalogue")
    lines.append("")
    lines.append(
        f"v-stdlib {version}; **{len(modules)} modules**, "
        f"**{label_count} public labels**. Generated from "
        "`dist/vsl-manifest.json` by `tools/write-module-frontmatter.py` "
        "(`make frontmatter`) — do not edit by hand."
    )
    lines.append("")
    lines.append(
        "Every `VSL*` routine is **layer v** (VistA-specific): it MAY consume "
        "an `STD*` routine from m-stdlib, never the reverse (the m/v "
        "waterline). For the engine-neutral primitives see the `m-stdlib` "
        "catalogue."
    )
    lines.append("")
    lines.append("| Module | Labels | Synopsis |")
    lines.append("|---|---|---|")
    for name in sorted(modules.keys()):
        mod = modules[name]
        synopsis = clean_synopsis(mod.get("synopsis", ""))
        n_labels = len(mod.get("labels", {}))
        page = f"{name.lower()}.md"
        lines.append(f"| [`{name}`]({page}) | {n_labels} | {synopsis} |")
    lines.append("")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--force", action="store_true", help="Re-sync frontmatter on existing pages.")
    p.add_argument("--dry-run", action="store_true", help="Report what would change without writing.")
    args = p.parse_args(argv)

    if not MANIFEST_PATH.exists():
        print(f"manifest missing — run `make manifest` first ({MANIFEST_PATH})", file=sys.stderr)
        return 2

    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    version = manifest.get("stdlib_version") or ""
    modules = manifest.get("modules", {})

    MODULES_DIR.mkdir(parents=True, exist_ok=True)

    created = synced = skipped = 0
    for name in sorted(modules.keys()):
        path = MODULES_DIR / f"{name.lower()}.md"
        action = write_page(path, name, modules[name], version, args.force, args.dry_run)
        if action.startswith("skip"):
            skipped += 1
        elif "create" in action:
            created += 1
        else:
            synced += 1
        if not action.startswith("skip"):
            print(f"  {action}: {path.relative_to(REPO_ROOT)}")

    # index.md is always regenerated (no hand-prose to preserve).
    if args.dry_run:
        print(f"  would write: {INDEX_PATH.relative_to(REPO_ROOT)}")
    else:
        INDEX_PATH.write_text(render_index(manifest), encoding="utf-8")
        print(f"  wrote: {INDEX_PATH.relative_to(REPO_ROOT)}")

    print(f"\ncreated: {created}, synced: {synced}, skipped (already had FM): {skipped}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
