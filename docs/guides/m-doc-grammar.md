---
title: M-doc tag grammar — see the canonical spec in m-stdlib
status: pointer
created: 2026-06-23
last_modified: 2026-06-23
doc_type: [POINTER]
---

# M-doc tag grammar (canonical spec lives in m-stdlib)

The `; doc:` tag grammar that v-stdlib's generators consume
(`tools/gen-manifest.py`, `tools/gen-bodies.py`, …) is **identical** to
m-stdlib's — it is engine-neutral and shared across both stdlibs. To avoid
three drifting copies (risk R-GRAMMAR), the **single canonical specification**
lives in m-stdlib:

> **<https://github.com/vista-cloud-dev/m-stdlib/blob/master/docs/guides/m-doc-grammar.md>**

v-stdlib follows it verbatim. This pointer replaces the former verbatim copy,
whose m-stdlib-relative cross-links did not resolve here (they pointed at
`docs/tracking/` and `docs/plans/` trackers that exist only in m-stdlib).

Per the two-regime documentation-governance ADR
(`docs/background/docs-governance-two-regimes-adr.md` in the `docs` repo), the
grammar is a **Regime-B (published reference)** artifact; published Regime-B docs
cross-reference via stable GitHub URLs so a single canonical copy serves every
repo and published location.
