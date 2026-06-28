#!/usr/bin/env python3
"""Label fall-through / empty-body gate (remediation plan R6, R1's follow-up).

Red when any `src/*.m` label can **fall through** into the next label —
i.e. its body is empty (only doc/comment lines) or its last executable line
does not end in an unconditional control-transfer command
(`quit`/`q`/`goto`/`g`/`halt`/`h`). This is the mechanical guard for the R1
class of bug: a generated doc-edit silently deleted the only executable line
of `$$user^VSLSEC`, so the label fell through into `bySecid` and every call
raised. No gate caught it because none execute `$$user` on a live engine —
this one needs no engine, it reads the `.m` text.

Engine-free (pure `python3`, no live engine). It parses M command structure
just enough to answer one question per label: *after the last line runs, can
control reach the next label?* Strings and parens are respected so an embedded
`quit` inside a literal (e.g. a `$etrap` string) is never mistaken for a real
terminator, and a postconditional/`if`-gated quit never counts as an
unconditional transfer.

The library idiom this enforces (every label ends in an unconditional `quit`)
already holds across all 6 shipped modules, so the gate ships GREEN and goes
red the moment a label loses its terminator — exactly the R1 regression.

Usage:
  python3 tools/check-fallthrough.py            # --check (default): exit 1 on a fall-through
  python3 tools/check-fallthrough.py --check
  python3 tools/check-fallthrough.py --list      # print every label + its verdict
  python3 tools/check-fallthrough.py --self-test
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC_REL = "src"

# A label line: a name (optionally with a formal-parameter list) anchored at
# column 0. Anything at column 0 that begins with a letter/`%` is a label in M.
LABEL_RE = re.compile(r"^(?P<name>[%A-Za-z][A-Za-z0-9]*)(?P<params>\([^)]*\))?")

# Commands that transfer control out of the label (unconditionally, when last).
TRANSFER = {"quit", "q", "goto", "g", "halt", "h"}
# Commands that make the rest of the line conditional on $TEST — a trailing
# quit after one of these is NOT an unconditional transfer.
CONDITIONAL = {"if", "i", "else", "e"}


def _consume_arg(code: str, i: int) -> int:
    """Advance past one command argument (or a postconditional), stopping at the
    next top-level space. Strings (with `""` escapes) and parens are skipped."""
    n = len(code)
    depth = 0
    in_str = False
    while i < n:
        c = code[i]
        if in_str:
            if c == '"':
                if i + 1 < n and code[i + 1] == '"':
                    i += 2
                    continue
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            i += 1
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth = max(0, depth - 1)
        elif c == " " and depth == 0:
            break
        i += 1
    return i


def tokenize(code: str) -> list[tuple[str, bool]]:
    """Split a comment-stripped M line into (keyword, had_postconditional) per
    command. Best-effort but string/paren aware — enough to identify the last
    command and any leading conditional. Stops at a top-level `;` (comment)."""
    toks: list[tuple[str, bool]] = []
    i, n = 0, len(code)
    while i < n and code[i] in " \t":
        i += 1
    while i < n:
        if code[i] == ";":  # an inline comment that survived stripping
            break
        s = i
        while i < n and code[i].isalpha():
            i += 1
        kw = code[s:i].lower()
        if not kw:  # not a command keyword (punctuation/garbage) — give up
            break
        had_pc = False
        if i < n and code[i] == ":":
            had_pc = True
            i = _consume_arg(code, i)
        if i < n and code[i] == " ":
            if i + 1 < n and code[i + 1] != " ":  # single space → argument follows
                i = _consume_arg(code, i + 1)
            # else: argless command, the run of spaces is the separator
        toks.append((kw, had_pc))
        while i < n and code[i] in " \t":
            i += 1
    return toks


def strip_comment(code: str) -> str:
    """Return the code before a top-level `;` (string-aware)."""
    in_str = False
    i = 0
    while i < len(code):
        c = code[i]
        if in_str:
            if c == '"':
                if i + 1 < len(code) and code[i + 1] == '"':
                    i += 2
                    continue
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
        elif c == ";":
            return code[:i]
        i += 1
    return code


def line_code(line: str, label_end: int | None = None) -> str:
    """Executable code on a line, comment stripped. For a label line, pass
    `label_end` (the offset past `name(params)`) so the label token is dropped.
    Leading whitespace and M dot-block markers (`.`) are removed."""
    raw = line[label_end:] if label_end is not None else line
    code = strip_comment(raw).strip()
    while code.startswith("."):  # dot-block nesting markers
        code = code[1:].lstrip()
    return code


def transfers_control(code: str) -> bool:
    """True iff this line's last command is an unconditional quit/goto/halt."""
    toks = tokenize(code)
    if not toks:
        return False
    kw, had_pc = toks[-1]
    if kw not in TRANSFER or had_pc:
        return False
    return not any(k in CONDITIONAL for k, _ in toks[:-1])


def analyze(text: str) -> list[dict]:
    """One row per label: {name, line, ok, reason}. ok=False means it can fall
    through into the next label (or off the end without a terminator)."""
    lines = text.splitlines()
    labels: list[tuple[int, str, int]] = []  # (index, name, label_token_end)
    for idx, line in enumerate(lines):
        m = LABEL_RE.match(line)
        if m:
            labels.append((idx, m.group("name"), m.end()))

    rows: list[dict] = []
    for li, (idx, name, tok_end) in enumerate(labels):
        end = labels[li + 1][0] if li + 1 < len(labels) else len(lines)
        last: str | None = None
        for j in range(idx, end):
            code = line_code(lines[j], label_end=tok_end if j == idx else None)
            if code:
                last = code
        if last is None:
            rows.append({"name": name, "line": idx + 1, "ok": False,
                         "reason": "empty body (only comments) — falls through to the next label"})
        elif not transfers_control(last):
            rows.append({"name": name, "line": idx + 1, "ok": False,
                         "reason": f"last line is not an unconditional quit/goto/halt: {last!r}"})
        else:
            rows.append({"name": name, "line": idx + 1, "ok": True, "reason": ""})
    return rows


def scan(root: Path) -> dict[str, list[dict]]:
    """{module: rows} for every src/*.m."""
    out: dict[str, list[dict]] = {}
    for p in sorted((root / SRC_REL).glob("*.m")):
        out[p.stem] = analyze(p.read_text(encoding="utf-8"))
    return out


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--check", action="store_true", help="exit 1 on a fall-through (default)")
    p.add_argument("--list", action="store_true", help="print every label + verdict, exit 0")
    p.add_argument("--self-test", action="store_true", help="run the inline behaviour self-test")
    args = p.parse_args(argv)

    if args.self_test:
        return self_test()

    src_dir = REPO_ROOT / SRC_REL
    if not src_dir.is_dir():
        print(f"check-fallthrough: no {SRC_REL}/ directory.", file=sys.stderr)
        return 2

    results = scan(REPO_ROOT)

    if args.list:
        nlabels = sum(len(rows) for rows in results.values())
        print(f"fall-through scan — {len(results)} modules, {nlabels} labels:")
        for module, rows in results.items():
            for r in rows:
                mark = "ok " if r["ok"] else "FALL"
                print(f"  [{mark}] {module}:{r['line']} {r['name']}"
                      + ("" if r["ok"] else f" — {r['reason']}"))
        return 0

    bad = [(m, r) for m, rows in results.items() for r in rows if not r["ok"]]
    if bad:
        print("check-fallthrough: FALL-THROUGH — label(s) can fall into the next "
              "label (the R1 class of bug):", file=sys.stderr)
        for module, r in bad:
            print(f"  - {module}:{r['line']} {r['name']} — {r['reason']}", file=sys.stderr)
        print("  Fix: end the label body with an unconditional `quit` (or goto/halt).",
              file=sys.stderr)
        return 1

    nlabels = sum(len(rows) for rows in results.values())
    print(f"check-fallthrough: clean — {nlabels} labels across {len(results)} "
          "modules all terminate")
    return 0


# -----------------------------------------------------------------------------
# self-test — fabricate M snippets and assert the verdict
# -----------------------------------------------------------------------------


def self_test() -> int:
    failures: list[str] = []

    def expect(cond, msg):
        if not cond:
            failures.append(msg)

    def bad_labels(text):
        return {r["name"] for r in analyze(text) if not r["ok"]}

    # 1. The R1 regression: a label with only doc comments falls through.
    r1 = (
        "user(duz)\t; resolve the #200 NAME\n"
        "\t; doc: @param duz numeric\n"
        "\t; doc: @illustrative resolves via VSLFS\n"
        "bySecid(secid)\t; next label\n"
        "\tquit $$lookup(secid)\n"
    )
    expect("user" in bad_labels(r1), "R1 empty body should be flagged")
    expect("bySecid" not in bad_labels(r1), "bySecid (ends in quit) should be clean")

    # 2. The R1 fix: restoring the quit clears it.
    fixed = (
        "user(duz)\t; resolve the #200 NAME\n"
        "\t; doc: @illustrative resolves via VSLFS\n"
        "\tquit $$get^VSLFS(200,duz_\",\",\".01\",\"\")\n"
        "bySecid(secid)\t; next label\n"
        "\tquit $$lookup(secid)\n"
    )
    expect(not bad_labels(fixed), f"the restored body should be clean, got {bad_labels(fixed)}")

    # 3. A body whose last line is a bare set falls through.
    setlast = "foo()\t; c\n\tset x=1\nbar()\t; c\n\tquit\n"
    expect("foo" in bad_labels(setlast), "a trailing set should fall through")

    # 4. A trailing quit reached only via `if` is conditional → still a fall-through.
    cond = "foo()\t; c\n\tif x quit 1\nbar()\t; c\n\tquit\n"
    expect("foo" in bad_labels(cond), "an if-gated quit is not an unconditional transfer")

    # 5. A real terminator mid-line (set ... do ... quit "") is fine.
    midquit = 'write(f)\t; c\n\tset ok=1\n\tset $etrap="" do raiseWrite quit ""\nx()\t;\n\tquit\n'
    expect("write" not in bad_labels(midquit), "a trailing `quit \"\"` after set/do should be clean")

    # 6. An embedded `quit` inside a string is NOT a terminator.
    instr = 'foo()\t; c\n\tset $etrap="set ok=0 quit"\nbar()\t;\n\tquit\n'
    expect("foo" in bad_labels(instr), "a `quit` inside a string literal must not count")

    # 7. A postconditional quit (quit:cond) can fall through.
    pc = "foo()\t; c\n\tquit:done x\nbar()\t;\n\tquit\n"
    expect("foo" in bad_labels(pc), "a postconditional quit:cond can fall through")

    # 8. goto and halt are valid terminators.
    goto = "foo()\t; c\n\tgoto bar\nbar()\t;\n\thalt\n"
    expect(not bad_labels(goto), f"goto/halt should be valid terminators, got {bad_labels(goto)}")

    # 9. A routine header label ending in quit, then a real label.
    header = "VSLX\t; header\n\t; doc\n\tquit\n\t;\nfoo()\t; c\n\tquit 1\n"
    expect(not bad_labels(header), f"a header that quits should be clean, got {bad_labels(header)}")

    # 10. Argless quit on its own line.
    argless = "raise(c)\t; c\n\tset $ecode=\",U-X,\"\n\tquit\n"
    expect(not bad_labels(argless), f"an argless quit should be a terminator, got {bad_labels(argless)}")

    if failures:
        for f in failures:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1
    print("check-fallthrough self-test OK (10 cases)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
