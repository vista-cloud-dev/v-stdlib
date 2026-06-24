#!/usr/bin/env python3
"""Generate the v-stdlib AI skill from the manifest.

A maintained sibling of m-stdlib's tools/gen-skill.py — only the
lib-specific strings differ (lib name, namespace, triggers, install
path). Keep the two in step (risk R-DRIFT): fold structural improvements
across both rather than letting them fork.

Reads:
  - dist/vsl-manifest.json      (every public VSL* module + label)
  - dist/errors.json            (inverted U-VSL* index)
  - tools/skill-patterns.md     (hand-curated canonical idioms;
                                 copied through verbatim into the
                                 emitted patterns.md so the prose
                                 stays evolvable without re-running
                                 the generator)

Writes (into dist/skill/):
  - SKILL.md            entry point with skill frontmatter +
                        module catalogue
  - manifest-index.md   compact one-line-per-label reference
  - patterns.md         copy of skill-patterns.md with a generated
                        header
  - error-codes.md      every U-VSL* code grouped by module

The generator is deterministic: no timestamps, no walltime fields.
That keeps the CI-drift gate (`make skill-check`, mirroring `make
manifest-check`) tractable — drift = bug, not a clock.

Usage:
  python3 tools/gen-skill.py            # writes dist/skill/*.md
  python3 tools/gen-skill.py --check    # exits non-zero on drift
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DIST_DIR = REPO_ROOT / "dist"
MANIFEST_PATH = DIST_DIR / "vsl-manifest.json"
ERRORS_PATH = DIST_DIR / "errors.json"
PATTERNS_INPUT = REPO_ROOT / "tools" / "skill-patterns.md"
SKILL_OUT_DIR = DIST_DIR / "skill"

SYNOPSIS_PREFIX = "v-stdlib — "


def _load_manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


def _load_errors() -> dict:
    if ERRORS_PATH.is_file():
        return json.loads(ERRORS_PATH.read_text(encoding="utf-8"))
    return {}


def _strip_prefix(synopsis: str) -> str:
    if synopsis.startswith(SYNOPSIS_PREFIX):
        return synopsis[len(SYNOPSIS_PREFIX):]
    return synopsis


# -----------------------------------------------------------------------------
# SKILL.md — entry point
# -----------------------------------------------------------------------------


def _build_skill_md(manifest: dict, errors: dict) -> str:
    version = manifest.get("stdlib_version") or "unversioned"
    modules = manifest.get("modules", {})
    label_count = sum(len(m.get("labels", {})) for m in modules.values())

    triggers = [
        '"v-stdlib"',
        '"VSL"',
        '"VSLCFG"',
        '"VSLSEC"',
        '"VSLTAP"',
        '"$$get^VSLCFG"',
        '"$$bySecid^VSLSEC"',
        '"^VSL"',
    ]

    lines: list[str] = []
    lines.append("---")
    lines.append("name: v-stdlib")
    lines.append("type: knowledge")
    lines.append("description: >")
    lines.append("  v-stdlib is the VistA Standard Library — VistA-specific `VSL*` M")
    lines.append("  routines (layer v) that bind Kernel / FileMan / XPAR / Broker")
    lines.append("  surfaces to the engine-neutral m-stdlib (`STD*`) base, one-way")
    lines.append("  `v -> m` per the m/v waterline. Covers XPAR config, security-key")
    lines.append("  checks, the RPC/HL7 traffic tap, S3 egress, TaskMan, and KIDS")
    lines.append("  build helpers. Load when writing VistA-layer M code that calls any")
    lines.append(f"  VSL* module. Triggers: {', '.join(triggers)}.")
    lines.append("---")
    lines.append("")
    lines.append(f"# v-stdlib — pattern library and quick reference ({version})")
    lines.append("")
    lines.append(
        "Generated from v-stdlib's `dist/vsl-manifest.json` — every public"
    )
    lines.append(
        "module + label, the canonical-idiom library, and the full U-VSL* error"
    )
    lines.append("surface, all rendered for AI / agent context loading.")
    lines.append("")
    lines.append(
        f"**Catalogue:** {len(modules)} modules, {label_count} public labels,"
    )
    lines.append(f"{len(errors)} error codes.")
    lines.append("")
    lines.append("## When to use this skill")
    lines.append("")
    lines.append(
        "Load when the task references any `VSL*` module / `^VSL` symbol or"
    )
    lines.append(
        "when writing VistA-layer M code (Kernel / FileMan / XPAR / Broker)"
    )
    lines.append("that should consume the VSL bindings instead of re-deriving them.")
    lines.append("")
    lines.append("## Companion files")
    lines.append("")
    lines.append("| File | Use when |")
    lines.append("|---|---|")
    lines.append(
        "| [`patterns.md`](patterns.md) | "
        "Looking for a copy-paste idiom for a frequent task "
        "(XPAR config read, security-key check, the traffic-tap entry points). |"
    )
    lines.append(
        "| [`manifest-index.md`](manifest-index.md) | "
        "You know the module name and want the full label list with synopses; "
        "or grepping for a function by name. |"
    )
    lines.append(
        "| [`error-codes.md`](error-codes.md) | "
        "An $ETRAP fired with a `,U-VSL...-,` code and you need to know "
        "which module / label set it. |"
    )
    lines.append("")
    lines.append("## Module catalogue")
    lines.append("")
    for name in sorted(modules.keys()):
        mod = modules[name]
        synopsis = _strip_prefix((mod.get("synopsis") or "").strip())
        if synopsis:
            lines.append(f"- **`{name}`** — {synopsis}")
        else:
            lines.append(f"- **`{name}`**")
    lines.append("")
    lines.append("## Architectural rules")
    lines.append("")
    lines.append(
        "- **The m/v waterline is one-way: `v -> m`.** A `VSL*` routine MAY"
    )
    lines.append(
        "  call an `STD*` routine; an `STD*` routine MUST NOT call a `VSL*`"
    )
    lines.append(
        "  one. VistA vocabulary (FileMan, KIDS, XPAR, Broker) lives here,"
    )
    lines.append("  never below the line in m-stdlib.")
    lines.append(
        "- **VistA-specific.** v-stdlib needs Kernel / FileMan / KIDS; the"
    )
    lines.append(
        "  tap + S3 + auth tier (VSLTAP/VSLRPCTAP/VSLS3/VSLSEC) is bare-engine"
    )
    lines.append("  green, the rest needs a live VistA.")
    lines.append(
        "- **Each module is a flat routine; you `do`-call or `$$`-call public"
    )
    lines.append(
        "  labels.** No global registries, no init hooks, no DI."
    )
    lines.append("")
    lines.append("## Quick start")
    lines.append("")
    lines.append(
        "For a copy-paste idiom matching a high-frequency task, see"
    )
    lines.append(
        "`patterns.md`. For the full per-symbol detail (params, returns,"
    )
    lines.append(
        "raises, source location), the manifest `dist/vsl-manifest.json` is"
    )
    lines.append("the source of truth and `manifest-index.md` is its rendered index.")
    lines.append("")
    return "\n".join(lines) + "\n"


# -----------------------------------------------------------------------------
# manifest-index.md — compact reference
# -----------------------------------------------------------------------------


def _build_manifest_index(manifest: dict) -> str:
    version = manifest.get("stdlib_version") or "unversioned"
    modules = manifest.get("modules", {})
    label_count = sum(len(m.get("labels", {})) for m in modules.values())

    lines: list[str] = []
    lines.append("# v-stdlib — manifest index")
    lines.append("")
    lines.append(
        f"v-stdlib {version}; {len(modules)} modules; "
        f"{label_count} public labels."
    )
    lines.append("")
    lines.append(
        "Generated from `dist/vsl-manifest.json`. One entry per module"
    )
    lines.append(
        "with every public label: signature on the left, synopsis on the"
    )
    lines.append(
        "right. For full per-label detail (params, returns, raises,"
    )
    lines.append("examples, source location), read the manifest entry directly.")
    lines.append("")

    for name in sorted(modules.keys()):
        mod = modules[name]
        synopsis = _strip_prefix((mod.get("synopsis") or "").strip())
        lines.append(f"## `{name}`")
        lines.append("")
        if synopsis:
            lines.append(synopsis)
            lines.append("")
        labels = mod.get("labels", {})
        if not labels:
            lines.append("_no public labels_")
            lines.append("")
            continue
        for label_name in sorted(labels.keys()):
            label = labels[label_name]
            sig = label.get("signature") or f"{label_name}^{name}"
            label_syn = (label.get("synopsis") or "").strip()
            if label_syn:
                lines.append(f"- `{sig}` — {label_syn}")
            else:
                lines.append(f"- `{sig}`")
        # Per-module raises summary.
        errors = mod.get("errors") or []
        if errors:
            lines.append("")
            lines.append(
                f"_raises: {', '.join('`' + c + '`' for c in sorted(errors))}_"
            )
        lines.append("")
    return "\n".join(lines) + "\n"


# -----------------------------------------------------------------------------
# patterns.md — pass-through with header
# -----------------------------------------------------------------------------


def _build_patterns(manifest: dict) -> str:
    version = manifest.get("stdlib_version") or "unversioned"
    body = PATTERNS_INPUT.read_text(encoding="utf-8")
    header = (
        f"<!-- generated from tools/skill-patterns.md against v-stdlib "
        f"{version}; do not edit this file directly — edit the input. -->\n\n"
    )
    return header + body


# -----------------------------------------------------------------------------
# error-codes.md — inverted index by module
# -----------------------------------------------------------------------------


def _build_error_codes(errors: dict, manifest: dict) -> str:
    version = manifest.get("stdlib_version") or "unversioned"
    # Group codes by their producing module.
    by_module: dict[str, list[tuple[str, dict]]] = {}
    for code, info in errors.items():
        module = info.get("module", "?")
        by_module.setdefault(module, []).append((code, info))

    lines: list[str] = []
    lines.append("# v-stdlib — error codes")
    lines.append("")
    if not errors:
        lines.append(
            f"_v-stdlib {version} ships no `,U-VSL*-,` codes yet — this file"
        )
        lines.append("is a placeholder until a module declares an `@raises` tag._")
        lines.append("")
        return "\n".join(lines) + "\n"
    total = len(errors)
    lines.append(
        f"v-stdlib {version}; {total} error codes across {len(by_module)} modules."
    )
    lines.append("")
    lines.append(
        "Inverted index over the manifest's `@raises` arrays. Every"
    )
    lines.append(
        "`,U-VSL...-,` code a v-stdlib label sets via `set $ecode=`"
    )
    lines.append(
        "is listed with the labels that raise it. For an `$ETRAP` handler"
    )
    lines.append(
        "that needs to disambiguate sources, this is the lookup table."
    )
    lines.append("")
    for module in sorted(by_module.keys()):
        lines.append(f"## `{module}`")
        lines.append("")
        for code, info in sorted(by_module[module]):
            labels = info.get("labels") or []
            label_str = ", ".join(f"`{label}`" for label in labels) or "_none_"
            lines.append(f"- **`{code}`** — raised by: {label_str}")
        lines.append("")
    return "\n".join(lines) + "\n"


# -----------------------------------------------------------------------------
# Entry point
# -----------------------------------------------------------------------------


def _generate() -> dict[str, str]:
    manifest = _load_manifest()
    errors = _load_errors()
    return {
        "SKILL.md": _build_skill_md(manifest, errors),
        "manifest-index.md": _build_manifest_index(manifest),
        "patterns.md": _build_patterns(manifest),
        "error-codes.md": _build_error_codes(errors, manifest),
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Generate dist/skill/*.md from the manifest."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Compare freshly-generated output against committed dist/skill/; exit 1 on diff.",
    )
    args = parser.parse_args(argv)

    if not MANIFEST_PATH.is_file():
        print(
            f"gen-skill: {MANIFEST_PATH} missing — run `make manifest` first.",
            file=sys.stderr,
        )
        return 2
    if not PATTERNS_INPUT.is_file():
        print(
            f"gen-skill: {PATTERNS_INPUT} missing — patterns input required.",
            file=sys.stderr,
        )
        return 2

    rendered = _generate()

    if args.check:
        any_diff = False
        for name, body in rendered.items():
            committed = SKILL_OUT_DIR / name
            if not committed.is_file():
                print(f"gen-skill --check: missing committed {committed}", file=sys.stderr)
                any_diff = True
                continue
            existing = committed.read_text(encoding="utf-8")
            if existing != body:
                print(f"gen-skill --check: drift in {committed}", file=sys.stderr)
                any_diff = True
        return 1 if any_diff else 0

    SKILL_OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, body in rendered.items():
        path = SKILL_OUT_DIR / name
        path.write_text(body, encoding="utf-8")
        print(f"wrote {path.relative_to(REPO_ROOT)} ({len(body)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
