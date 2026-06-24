#!/usr/bin/env bash
# scripts/m-lint-gate.sh — House lint gate over the Go `m` toolchain.
#
# The Go `m` (github.com/vista-cloud-dev/m-cli) has no `--error-on=<severity>`
# flag: `m lint --check` fails (exit 3) on ANY finding regardless of severity.
# The house gate is narrower — "zero ERROR-severity findings" — letting
# style/warning findings be reported without reding CI (the same semantics the
# legacy Python m-cli's `m lint --error-on=error` provided).
#
# This wrapper reproduces that: run `m lint -o json` (which exits 0 and emits
# every diagnostic), print all findings for visibility, and exit non-zero only
# if any finding is severity "error".
#
# Usage:  M=<path-to-go-m> scripts/m-lint-gate.sh src/ tests/
# (M defaults to `m` on $PATH — same convention as the Makefile.)
#
# Residual: once the Go `m` grows a native `--error-on=<severity>` (or
# `--fail-on`) flag, replace this wrapper with that flag in the Makefile.
set -euo pipefail

M="${M:-m}"

LINT_JSON="$("$M" lint -o json "$@")"
export LINT_JSON

python3 - <<'PY'
import json, os, sys

doc = json.loads(os.environ["LINT_JSON"])
diags = doc.get("diagnostics") or []

by_sev = {}
for d in diags:
    by_sev[d.get("severity", "?")] = by_sev.get(d.get("severity", "?"), 0) + 1
    print(
        f'  {d.get("severity","?"):8} {d.get("file","?")}:'
        f'{d.get("line","?")}:{d.get("col","?")}  '
        f'{d.get("rule","?")}  {d.get("message","")}',
        file=sys.stderr,
    )

errors = by_sev.get("error", 0)
summary = ", ".join(f"{n} {s}" for s, n in sorted(by_sev.items())) or "none"
print(f"lint: {len(diags)} finding(s) [{summary}]; {errors} error-severity", file=sys.stderr)

# House gate: error-severity findings fail; style/warning are advisory.
sys.exit(1 if errors else 0)
PY
