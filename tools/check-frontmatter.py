#!/usr/bin/env python3
"""Validate generated module-page frontmatter against the Regime-B schema.

stdlib-docs governance (docs/background/docs-governance-two-regimes-adr.md):
the per-module reference pages (docs/modules/<module>.md) are MACHINE OUTPUT,
not prose docs. They are excluded from the doc-framework prose validator and
governed instead by this robust, machine-processable schema —
`tools/reference-frontmatter.schema.json` — enforced here.

This is the Regime-B frontmatter gate (`make check-frontmatter`). It red-gates
a page whose generated frontmatter is missing a required field, carries an
unknown field (additionalProperties: false catches typos), or has the wrong
type / pattern. A maintained byte-identical sibling shared between m-stdlib and
v-stdlib (one schema serves both; per-repo fields are optional).

Engine-free, dependency-light: uses PyYAML if importable, else a built-in
parser for the constrained frontmatter dialect the generators emit. The schema
check implements the JSON-Schema subset this schema uses (required, type,
pattern, enum, items, minLength, additionalProperties) — no external validator.

Usage:
  python3 tools/check-frontmatter.py            # validate docs/modules/*.md
  python3 tools/check-frontmatter.py --check
  python3 tools/check-frontmatter.py --self-test
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MODULES_DIR = REPO_ROOT / "docs" / "modules"
SCHEMA_PATH = REPO_ROOT / "tools" / "reference-frontmatter.schema.json"


# -----------------------------------------------------------------------------
# Frontmatter extraction + parse
# -----------------------------------------------------------------------------


def extract_frontmatter(text: str) -> str | None:
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end < 0:
        return None
    return text[4:end + 1]


def parse_frontmatter(block: str) -> dict:
    try:
        import datetime as _dt
        import yaml  # type: ignore
        data = yaml.safe_load(block)
        if not isinstance(data, dict):
            return {}
        # Normalise PyYAML's rich types to match the built-in parser (and the
        # schema's string fields): YAML auto-parses `created: 2026-05-05` to a
        # date and an empty `tag:` to None — coerce both back to plain strings.
        norm: dict = {}
        for k, v in data.items():
            if isinstance(v, (_dt.date, _dt.datetime)):
                norm[k] = v.isoformat()
            elif v is None:
                norm[k] = ""
            else:
                norm[k] = v
        return norm
    except Exception:
        pass
    # Built-in parser for the generators' constrained dialect: top-level
    # `key: scalar` / `key: 'quoted'` / `key: [a, b]` / `key: []` / `key: 5`.
    out: dict = {}
    for raw in block.splitlines():
        line = raw.rstrip()
        if not line or line.startswith("#"):
            continue
        m = re.match(r"^([A-Za-z0-9_]+):\s*(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        out[key] = _parse_scalar_or_list(val)
    return out


def _parse_scalar_or_list(val: str):
    if val == "":
        return ""
    if val.startswith("[") and val.endswith("]"):
        inner = val[1:-1].strip()
        if not inner:
            return []
        items = []
        for piece in _split_flow(inner):
            items.append(_unquote(piece.strip()))
        return items
    # integer?
    if re.fullmatch(r"-?\d+", val):
        return int(val)
    return _unquote(val)


def _split_flow(inner: str) -> list[str]:
    """Split a flow-list body on commas not inside quotes."""
    out, buf, q = [], [], None
    for ch in inner:
        if q:
            buf.append(ch)
            if ch == q:
                q = None
        elif ch in "'\"":
            q = ch
            buf.append(ch)
        elif ch == ",":
            out.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    if buf:
        out.append("".join(buf))
    return out


def _unquote(s: str) -> str:
    s = s.strip()
    if len(s) >= 2 and s[0] == s[-1] and s[0] in "'\"":
        body = s[1:-1]
        if s[0] == "'":
            body = body.replace("''", "'")
        return body
    return s


# -----------------------------------------------------------------------------
# Minimal JSON-Schema-subset validation
# -----------------------------------------------------------------------------


def _type_ok(value, jstype: str) -> bool:
    if jstype == "string":
        return isinstance(value, str)
    if jstype == "array":
        return isinstance(value, list)
    if jstype == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if jstype == "object":
        return isinstance(value, dict)
    return True


def validate(data: dict, schema: dict) -> list[str]:
    errors: list[str] = []
    props = schema.get("properties", {})
    required = schema.get("required", [])
    for r in required:
        if r not in data:
            errors.append(f"missing required field '{r}'")
    if schema.get("additionalProperties") is False:
        for k in data:
            if k not in props:
                errors.append(f"unknown field '{k}' (additionalProperties: false)")
    for key, value in data.items():
        spec = props.get(key)
        if not spec:
            continue
        jstype = spec.get("type")
        if jstype and not _type_ok(value, jstype):
            errors.append(f"field '{key}': expected {jstype}, got {type(value).__name__}")
            continue
        if jstype == "string":
            if "minLength" in spec and len(value) < spec["minLength"]:
                errors.append(f"field '{key}': shorter than minLength {spec['minLength']}")
            if "pattern" in spec and not re.search(spec["pattern"], value):
                errors.append(f"field '{key}': '{value}' does not match {spec['pattern']}")
            if "enum" in spec and value not in spec["enum"]:
                errors.append(f"field '{key}': '{value}' not in {spec['enum']}")
        if jstype == "array":
            item_spec = spec.get("items")
            if item_spec:
                for i, item in enumerate(value):
                    it = item_spec.get("type")
                    if it and not _type_ok(item, it):
                        errors.append(f"field '{key}'[{i}]: expected {it}")
                    elif it == "string" and "pattern" in item_spec and not re.search(item_spec["pattern"], item):
                        errors.append(f"field '{key}'[{i}]: '{item}' does not match {item_spec['pattern']}")
    return errors


# -----------------------------------------------------------------------------
# Drive over the pages
# -----------------------------------------------------------------------------


def _scan(modules_dir: Path, schema: dict) -> dict[str, list[str]]:
    findings: dict[str, list[str]] = {}
    for path in sorted(modules_dir.glob("*.md")):
        if path.name == "index.md":
            continue
        block = extract_frontmatter(path.read_text(encoding="utf-8"))
        if block is None:
            findings[path.name] = ["no frontmatter block"]
            continue
        data = parse_frontmatter(block)
        errs = validate(data, schema)
        # module must equal filename stem (upper).
        if data.get("module") and data["module"].lower() != path.stem.lower():
            errs.append(f"module '{data['module']}' != filename stem '{path.stem}'")
        if errs:
            findings[path.name] = errs
    return findings


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--check", action="store_true", help="exit 1 on any schema violation")
    p.add_argument("--self-test", action="store_true", help="run the inline self-test")
    args = p.parse_args(argv)

    if args.self_test:
        return self_test()

    if not SCHEMA_PATH.is_file():
        print(f"check-frontmatter: schema missing — {SCHEMA_PATH}", file=sys.stderr)
        return 2
    if not MODULES_DIR.is_dir():
        print(f"check-frontmatter: no docs/modules/ — nothing to validate")
        return 0
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    findings = _scan(MODULES_DIR, schema)
    n = len(list(MODULES_DIR.glob("*.md"))) - (1 if (MODULES_DIR / "index.md").exists() else 0)
    if findings:
        print("check-frontmatter: INVALID — pages violate reference-frontmatter.schema.json:",
              file=sys.stderr)
        for name, errs in findings.items():
            for e in errs:
                print(f"  - {name}: {e}", file=sys.stderr)
        return 1
    print(f"check-frontmatter: clean — {n} pages conform to reference-frontmatter.schema.json")
    return 0


# -----------------------------------------------------------------------------
# self-test
# -----------------------------------------------------------------------------


def self_test() -> int:
    failures: list[str] = []

    def expect(cond, msg):
        if not cond:
            failures.append(msg)

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8")) if SCHEMA_PATH.is_file() else {
        "additionalProperties": False,
        "required": ["module", "synopsis", "labels", "errors", "stable", "since", "see_also"],
        "properties": {
            "module": {"type": "string", "pattern": "^(STD|VSL)[A-Z0-9]+$"},
            "layer": {"type": "string", "enum": ["m", "v"]},
            "synopsis": {"type": "string", "minLength": 1},
            "labels": {"type": "array", "items": {"type": "string"}},
            "errors": {"type": "array", "items": {"type": "string", "pattern": "^U-"}},
            "see_also": {"type": "array"}, "stable": {"type": "string"},
            "since": {"type": "string"},
        },
    }

    # parser cases
    fm = parse_frontmatter(
        "module: STDFOO\nlayer: m\nsynopsis: 'hi, there'\nlabels: ['a', 'b']\n"
        "errors: []\nstable: stable\nsince: v0.1.0\nsee_also: ['STDBAR']\nrevisions: 3\n"
    )
    expect(fm["module"] == "STDFOO", f"module parse: {fm.get('module')!r}")
    expect(fm["synopsis"] == "hi, there", f"quoted scalar w/ comma: {fm.get('synopsis')!r}")
    expect(fm["labels"] == ["a", "b"], f"flow list: {fm.get('labels')!r}")
    expect(fm["errors"] == [], f"empty list: {fm.get('errors')!r}")
    expect(fm["revisions"] == 3, f"int: {fm.get('revisions')!r}")

    # valid record
    expect(validate(fm, schema) == [], f"valid record flagged: {validate(fm, schema)}")

    # missing required
    bad = dict(fm); del bad["synopsis"]
    expect(any("synopsis" in e for e in validate(bad, schema)), "missing-required not caught")

    # unknown field
    bad = dict(fm); bad["bogus"] = "x"
    expect(any("bogus" in e for e in validate(bad, schema)), "unknown field not caught")

    # bad module pattern
    bad = dict(fm); bad["module"] = "lowercase"
    expect(any("module" in e for e in validate(bad, schema)), "bad module pattern not caught")

    # wrong type (labels as string)
    bad = dict(fm); bad["labels"] = "notalist"
    expect(any("labels" in e for e in validate(bad, schema)), "wrong type not caught")

    # bad error-code item pattern
    bad = dict(fm); bad["errors"] = ["NOTUCODE"]
    expect(any("errors" in e for e in validate(bad, schema)), "bad error pattern not caught")

    if failures:
        for f in failures:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("check-frontmatter self-test OK")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
