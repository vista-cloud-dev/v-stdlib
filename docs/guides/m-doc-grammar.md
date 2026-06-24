---
title: m-stdlib — M-doc tag grammar
status: live (v1; specification authoritative as of 2026-05-08)
audience: m-stdlib maintainers writing or editing `; doc:` blocks; toolchain
  authors implementing the manifest generator (WA4), the `M-DOC-001` lint
  rule (WA3), the `m doc` family (Wave B), the VS Code extension (Wave C),
  the AI skill (Wave D), or any other consumer of m-stdlib metadata.
plan: docs/plans/historical/discoverability-and-tooling-plan.md (the design rationale —
  this guide is the normative spec implementing § 3.1)
tracker: docs/tracking/discoverability-tracker.md (WA1 closes when this guide
  is reviewed; WA2 is the backfill that brings src/ into compliance)
created: 2026-05-08
last_modified: 2026-05-08
revisions: 1
doc_type: [SPEC]
---

# m-stdlib — M-doc tag grammar

This document specifies the **structured-tag grammar** that extends
m-stdlib's existing `; doc:` convention. Tags are optional — every
existing prose-only `; doc:` block remains valid. The grammar adds a
small, JSDoc-shaped tag vocabulary so a single source artefact (the
routine file) drives the manifest, the per-module markdown, the
`m doc` lookup output, the VS Code hover surface, and the AI skill.

## Contents

- [1. Purpose and design constraints](#1-purpose-and-design-constraints)
- [2. Relationship to the existing `; doc:` convention](#2-relationship-to-the-existing--doc-convention)
- [3. Lexical structure](#3-lexical-structure)
- [4. The synopsis line](#4-the-synopsis-line)
- [5. Tag reference](#5-tag-reference)
- [6. Worked example — `parse^STDJSON`](#6-worked-example--parsestdjson)
- [7. Parsing contract for downstream tools](#7-parsing-contract-for-downstream-tools)
- [8. Edge cases and lint rules](#8-edge-cases-and-lint-rules)
- [9. What does NOT change](#9-what-does-not-change)
- [10. Cross-references](#10-cross-references)

---

## 1. Purpose and design constraints

The grammar exists to make m-stdlib's public surface
**machine-extractable** without sacrificing the prose-readability the
existing `; doc:` convention already gives. Three constraints
governed every design choice:

1. **Optional, additive.** A label with no tags is still valid; lint
   warns at most. Backfill (WA2) can land one module at a time
   without breaking the others.
2. **Tiny vocabulary.** Nine tags total. They map 1-to-1 onto JSDoc /
   rustdoc / Python type-hint concepts, so AI assistants and human
   readers from those ecosystems pick the grammar up by reflex.
3. **Trivially parsable.** The grammar is a flat per-line lexicon —
   a `; doc:` prefix, an optional `@tag` first token, a free-form
   tail. ~30 lines of M (or one tree-sitter-m query) handle it.

The grammar deliberately does **not** specify markup inside tag
bodies (no Markdown subset, no inline links). Tag bodies are plain
text. Future extensions can add formatting; v1 prioritises
implementer simplicity.

## 2. Relationship to the existing `; doc:` convention

Existing convention (unchanged):

```m
parse(text,root)        ; Parse `text` into `root`. Returns 1/0.
        ; doc: Kills `root` first. On failure, $$lastError() holds the
        ; doc: "line:col: msg" diagnostic and the partial tree is killed.
```

After this grammar is adopted (the WA2 backfill state):

```m
parse(text,root)        ; Parse `text` into `root`. Returns 1/0.
        ; doc: @param text   string  RFC-8259 JSON document
        ; doc: @param root   array   caller-owned destination (killed first)
        ; doc: @returns      bool    1 on success, 0 on failure
        ; doc: @raises       U-STDJSON-PARSE  malformed input
        ; doc: @example      do parse^STDJSON("[1,2,3]",.t) write $$type^STDJSON(.t)  ; "array"
        ; doc: @since        v0.2.0
        ; doc: @stable       stable
        ; doc: @see          valid^STDJSON, lastError^STDJSON
        ; doc: Kills `root` first. On failure, $$lastError() holds the
        ; doc: "line:col: msg" diagnostic and the partial tree is killed.
```

The header comment on the label line (`; Parse \`text\` into \`root\`.
Returns 1/0.`) is still the **synopsis** (§ 4). The prose `; doc:`
lines remain as the long description. Only the tag block is new.

## 3. Lexical structure

A **doc block** is a contiguous run of lines, each matching:

```
<INDENT> ; doc: <BODY>
```

where `<INDENT>` is the routine's standard 8-space (or tab-aligned)
indent and `<BODY>` is the rest of the line after the `; doc:`
prefix and one separating space.

A doc block belongs to the **immediately preceding label line**. The
label line itself is the line beginning at column 1 (or column
non-whitespace) with the form `<name>` or `<name>(<formal-list>)`,
optionally followed by an inline comment.

Within a doc block, each line is one of:

- **A tagged line.** First non-whitespace token in `<BODY>` matches
  `@<word>`. The token is the **tag name**; the rest of `<BODY>`
  (after the tag and one separating space) is the **tag body**.
- **A continuation line.** No `@<word>` first token. The line's
  `<BODY>` is appended (with a newline) to the most recent tag
  body, or to the **free-form description** if no tag has yet
  appeared in the block.

Empty `; doc:` lines (just the prefix, no body) terminate the
current tag's continuation but do not end the doc block. Use them
sparingly — they're permitted but unidiomatic. Prefer one tag per
line and a single description paragraph.

## 4. The synopsis line

The **synopsis** is the first non-tag, non-empty unit of prose for
the label. It is one sentence that summarises the label. By
convention — and matching godoc — the synopsis goes on the **label
line itself**, as the inline comment after the formal-list:

```m
parse(text,root)        ; Parse `text` into `root`. Returns 1/0.
```

The manifest generator extracts everything after the first `;` on
the label line (trimmed) as `synopsis`. It is consumed by:

- `m doc --short` (godoc-style one-liner).
- The hover-popup first line in the VS Code extension.
- The first column in `m search` results.

**Style.** One sentence, present-tense, ends with a period.
Backticks for code identifiers. ≤ 80 characters where possible.

If the label line has no inline comment, the **first non-tag
sentence in the doc block** is the synopsis (godoc fallback). This
fallback exists so legacy labels render correctly during the WA2
backfill, but it is not preferred — every public label should have
a synopsis on its label line.

## 5. Tag reference

Nine tags. Each entry below specifies syntax, multiplicity, and
semantics.

### 5.1 `@param NAME [TYPE] BODY`

Parameter declaration.

- **Multiplicity.** Zero or more. At most one `@param` per
  `NAME`. Order should match the formal-list left-to-right.
- **Required when.** Label has a non-empty formal-list. Each name
  in the formal-list MUST appear as exactly one `@param`.
- **`NAME`.** Bare identifier. MUST match a name in the
  formal-list (`M-DOC-001` lint).
- **`TYPE`.** Free-form type label, single token. Recommended
  vocabulary: `string`, `int`, `num`, `bool`, `array`, `node`,
  `path`, `iso8601`, `horolog`, `byte-string`, `mref` (M
  reference), `cb` (callback). The grammar does not type-check —
  the label is for human / AI readers.
- **`BODY`.** One-line description. Continuation lines append.

### 5.2 `@returns [TYPE] BODY`

Return-value declaration.

- **Multiplicity.** Zero or one.
- **Required when.** Any code path in the label body does
  `quit <expression>` (returns a value). Forbidden when every
  `quit` is value-less.
- **`TYPE`.** Same vocabulary as `@param`. Use `void` if the type
  is intentionally polymorphic (rare).
- **`BODY`.** Description of the value's meaning, including the
  failure indicator if the function uses an in-band failure
  signal (e.g. `1 on success, 0 on failure`).

### 5.3 `@raises CODE [BODY]`

Error-code declaration.

- **Multiplicity.** Zero or more. One per distinct `CODE`.
- **Required when.** The label (or any helper it transitively
  calls and does not catch) sets `$ECODE` to a `,U-STDxxx-NAME,`
  value. (Not required for engine-set `$ECODE`s the label propagates
  blindly — those are not part of the documented surface.)
- **`CODE`.** The error code without the surrounding commas:
  `U-STDJSON-PARSE` not `,U-STDJSON-PARSE,`. The manifest emits
  it without commas; consumers add them when comparing against
  `$ECODE`.
- **`BODY`.** Optional one-line description of when the code is
  raised. Continuation lines append.

### 5.4 `@example BODY`

A runnable usage example.

- **Multiplicity.** Zero or more. Recommended: ≥ 1 for every
  `@stable stable` label.
- **`BODY`.** A line of M code that exercises the label.
  Continuation lines append (with newline) — multi-line examples
  are supported. The example MUST run cleanly under `m test`
  context (no global side-effects beyond `^STDLIB($job,...)`
  scratch space, no opens against arbitrary paths).
- **Two recognised shapes.** Either form is legal:

  1. **Self-asserting.** `do eq^STDASSERT(.p,.f, $$x^MOD(...),
     "expected", "doc example")` — uses STDASSERT plumbing the
     way an ordinary test does.
  2. **Annotated I/O.** A `write` statement followed by an inline
     `; "expected"` comment. The doctest generator (WD2) compares
     captured output against the comment.

  The self-asserting form is preferred because it composes with
  existing test plumbing without special-case parsing.

### 5.5 `@since VERSION`

The first version this label appeared in.

- **Multiplicity.** Exactly one for every public label.
- **`VERSION`.** A SemVer string with leading `v` (`v0.2.0`).
  Must match a tag in `CHANGELOG.md`.
- **Source of truth.** Cross-checked against the `## [vX.Y.Z]`
  heading that introduced the label in `CHANGELOG.md` (a future
  lint rule, not gated in v1).

### 5.6 `@stable LEVEL`

API-stability tier.

- **Multiplicity.** Exactly one for every public label.
- **`LEVEL`.** One of:
  - `experimental` — may change without a major version bump.
    No SemVer guarantee.
  - `stable` — guarded by SemVer. Removal or breaking signature
    change requires a major bump.
  - `deprecated` — slated for removal. Use the replacement named
    in `@see`. The label MUST still work as documented until
    its removal version.
- **Default.** Absent `@stable` is treated as `experimental` by
  consumers, with a warning from the lint rule. Public labels
  SHOULD be tagged explicitly.

The tier is informational in v1 — there is no CI gate enforcing
SemVer against the tier (deferred per `module-tracker.md` D2).
Annotating now lets a future gate switch on without backfill.

### 5.7 `@see SYMBOL[, SYMBOL]*`

Cross-references to related symbols.

- **Multiplicity.** Zero or one. Multiple references are
  comma-separated.
- **`SYMBOL`.** M call-site form: `label^MODULE`,
  `$$label^MODULE`, `^MODULE` (whole-routine ref), or a free-text
  external reference (e.g. `RFC 8259 §6`).
- **Use.** Renders as a "See also" line in `m doc`, hover, and
  the per-module markdown.

### 5.8 `@deprecated VERSION BODY`

Required iff `@stable deprecated`. Identifies the version the
deprecation took effect and gives the replacement plan.

- **Multiplicity.** Zero or one. Forbidden unless `@stable
  deprecated` is also set.
- **`VERSION`.** Version (`vX.Y.Z`) where the deprecation began.
- **`BODY`.** One sentence explaining the replacement; usually
  paired with `@see` pointing at it.

### 5.9 `@internal`

Marks a labeled-and-documented routine point as not part of the
public surface.

- **Multiplicity.** Zero or one. Boolean — body is ignored.
- **Use.** A label that has a `; doc:` block (because the prose
  is useful to maintainers) but should not appear in the
  manifest, in `m doc`, in hover, or in the AI skill. Examples in
  current src/: `parseFail^STDJSON`, `parseFileEof^STDJSON`,
  `encodeFail^STDJSON` — labels reached only via ZGOTO traps
  whose `; doc:` blocks explain the unwind contract.
- **Caution.** Labels with NO `; doc:` block are already invisible
  to the manifest generator. `@internal` is only needed when a
  label has documentation but is not for external use.

## 6. Worked example — `parse^STDJSON`

The current `src/STDJSON.m` definition (verbatim, for reference):

```m
parse(text,root)        ; Parse `text` into `root`. Returns 1/0.
        ; doc: Kills `root` first. On failure, $$lastError() holds the
        ; doc: "line:col: msg" diagnostic and the partial tree is killed.
        ; doc: Internal recursion can fire $ETRAP at arbitrary extrinsic
        ; doc: depth; ZGOTO N:label unwinds the M-stack to parse()'s own
        ; doc: level before the GOTO so parseFail's `quit 0` always
        ; doc: executes in extrinsic context (avoids M17 NOTEXTRINSIC).
        new ctx,$etrap,parseLvl
        ...
```

The same label after WA2 backfill — full-grammar form:

```m
parse(text,root)        ; Parse `text` into `root`. Returns 1/0.
        ; doc: @param text   string  RFC-8259 JSON document text
        ; doc: @param root   array   caller-owned destination subtree;
        ; doc:   killed before population so callers may pass a partially
        ; doc:   populated array safely
        ; doc: @returns      bool    1 on success, 0 on failure (caller
        ; doc:   inspects $$lastError^STDJSON for the diagnostic)
        ; doc: @raises       U-STDJSON-PARSE  set on malformed input;
        ; doc:   the partial tree is killed before this raises
        ; doc: @example      new t,p,f
        ; doc: @example      do start^STDASSERT(.p,.f)
        ; doc: @example      do eq^STDASSERT(.p,.f,$$parse^STDJSON("[1,2,3]",.t),1,"valid array parses")
        ; doc: @example      do eq^STDASSERT(.p,.f,$$type^STDJSON(.t),"array","root is array")
        ; doc: @since        v0.2.0
        ; doc: @stable       stable
        ; doc: @see          $$valid^STDJSON, $$lastError^STDJSON, $$encode^STDJSON
        ; doc: Kills `root` first. On failure, $$lastError() holds the
        ; doc: "line:col: msg" diagnostic and the partial tree is killed.
        ; doc: Internal recursion can fire $ETRAP at arbitrary extrinsic
        ; doc: depth; ZGOTO N:label unwinds the M-stack to parse()'s own
        ; doc: level before the GOTO so parseFail's `quit 0` always
        ; doc: executes in extrinsic context (avoids M17 NOTEXTRINSIC).
```

Reading the example:

- The synopsis is `Parse \`text\` into \`root\`. Returns 1/0.` — the
  inline comment on the label line, **unchanged**.
- The tag block records `@param` for each formal-list entry (`text`
  and `root`), `@returns`, `@raises`, four `@example` lines forming
  one self-asserting STDASSERT snippet, `@since`, `@stable`, and a
  `@see` pointing at related labels.
- The original prose paragraph (the ZGOTO unwind explanation)
  stays verbatim as the **free-form description** at the end of
  the doc block. Tags can precede or follow the prose; ordering
  is a style choice (recommended: tags first, prose second, since
  tags are scanned by tools and prose is read by humans).

The manifest entry derived from the above:

```json
"parse": {
  "form": "extrinsic",
  "signature": "$$parse^STDJSON(text, .root)",
  "synopsis": "Parse `text` into `root`. Returns 1/0.",
  "params": [
    {"name": "text", "type": "string", "doc": "RFC-8259 JSON document text"},
    {"name": "root", "type": "array",  "doc": "caller-owned destination subtree; killed before population so callers may pass a partially populated array safely"}
  ],
  "returns": {"type": "bool", "doc": "1 on success, 0 on failure (caller inspects $$lastError^STDJSON for the diagnostic)"},
  "raises": [{"code": "U-STDJSON-PARSE", "doc": "set on malformed input; the partial tree is killed before this raises"}],
  "examples": [
    "new t,p,f\ndo start^STDASSERT(.p,.f)\ndo eq^STDASSERT(.p,.f,$$parse^STDJSON(\"[1,2,3]\",.t),1,\"valid array parses\")\ndo eq^STDASSERT(.p,.f,$$type^STDJSON(.t),\"array\",\"root is array\")"
  ],
  "since": "v0.2.0",
  "stable": "stable",
  "see_also": ["$$valid^STDJSON", "$$lastError^STDJSON", "$$encode^STDJSON"],
  "description": "Kills `root` first. On failure, $$lastError() holds the \"line:col: msg\" diagnostic and the partial tree is killed. Internal recursion can fire $ETRAP at arbitrary extrinsic depth; ZGOTO N:label unwinds the M-stack to parse()'s own level before the GOTO so parseFail's `quit 0` always executes in extrinsic context (avoids M17 NOTEXTRINSIC).",
  "source": {"file": "src/STDJSON.m", "line": 39}
}
```

The four `@example` lines collapse into one multi-line example
because they are consecutive `@example` tags forming one
self-contained snippet. Two distinct examples would be expressed
as two `@example` blocks separated by another tag (or by an empty
`; doc:` line).

## 7. Parsing contract for downstream tools

Three artefacts in the m-stdlib and m-cli toolchain consume this
grammar. They MUST agree on the parsing rules below.

### 7.1 `tools/gen-manifest.m` (WA4)

- Reads `src/STD*.m`. For each routine: emit a module entry.
- For each label that has a non-empty `; doc:` block: emit a label
  entry, **unless** the block contains `@internal`.
- The label's `synopsis` is the inline comment on the label line
  (preferred) or the first prose sentence in the doc block
  (fallback).
- Tags are extracted into the schema fields shown in § 6.
- `@example` lines that are consecutive collapse into one example
  body (newline-joined). A non-`@example` tag (or an empty
  `; doc:` line) terminates the current example.
- The label's `signature` is reconstructed from the formal-list:
  `$$<name>^<MODULE>(<params>)` for extrinsics, `do
  <name>^<MODULE>(<params>)` for procedures. The form is
  determined by static analysis of the label body (`quit
  <expression>` anywhere → extrinsic).
- `source.file` is the routine path; `source.line` is the
  label-line number (1-indexed).

### 7.2 `M-DOC-001` lint rule (WA3)

Severity: **warn** in v1. Promote to error after WA2 backfill is
complete and stays clean across at least one release cycle.

The rule fires on a public label (one that has any `; doc:` content
and is not `@internal`) when ANY of the following hold:

- A name in the formal-list has no `@param`.
- A `@param` has a name not in the formal-list.
- The label body contains `quit <expression>` and there is no
  `@returns`.
- The label body contains a `set $ecode=",U-STDxxx-...,"` line and
  the corresponding `@raises U-STDxxx-...` is missing.
- `@stable` is missing.
- `@since` is missing.
- `@stable deprecated` is set without an accompanying
  `@deprecated` tag.

The rule does NOT fire on:

- Internal labels (no `; doc:` block, or `@internal` set).
- Routines whose entire file is opted out via
  `; m-lint: disable-file=M-DOC-001` (escape hatch for legacy
  routines pending backfill).

### 7.3 `m doc` and friends (Wave B), VS Code (Wave C), AI skill (Wave D)

These consumers read the **manifest**, not the source. They never
re-parse `; doc:` blocks. Any new tag added to this grammar must
be reflected in the manifest schema first (WA4), then the
consumers pick it up automatically.

## 8. Edge cases and lint rules

| Situation | Behaviour |
|---|---|
| Tag name unknown (e.g. `@todo`) | Manifest generator: ignore (drop with no warning). Lint rule: warn `M-DOC-002` (future) — keeps the grammar closed. |
| `@param` for a name not in the formal-list | `M-DOC-001` warn. Manifest: drop the entry. |
| Two `@param` with the same name | `M-DOC-001` warn (treat as ambiguous). Manifest: keep the first; drop the rest. |
| `@returns` on a label whose every `quit` is value-less | `M-DOC-001` warn. Manifest: keep (consumers may render it as `void` advice). |
| `@raises` for a code the label can't raise | `M-DOC-001` warn (over-claim). Manifest: keep the entry. |
| Missing `@example` on a `@stable stable` label | `M-DOC-001` warn (best-practice nudge). |
| `@stable experimental` with `@example` | Allowed. Examples for experimental labels are still useful. |
| `@deprecated` without `@stable deprecated` | `M-DOC-001` warn. Manifest: still emits both. |
| `@internal` plus other tags | The other tags are dropped from the manifest (the label is excluded entirely). Tags remain in the source for maintainer reading. |
| Doc block before any label (i.e. routine-level prose) | Belongs to the **routine**, not a label. Manifest emits as `module.description`. |

## 9. What does NOT change

The following remain exactly as they were in the v0.4.0 codebase:

- The **routine-header block** at the top of every `STDxxx.m`
  file (the `Public API` summary, storage convention,
  error-codes list). It is read by humans glancing at the source
  and by the manifest generator as the module-level description.
- The **`; doc:` prefix** (lower-case, single space after the
  colon, indented to the routine's standard column).
- The **inline-synopsis convention** on the label line.
- The **`,U-STDxxx-NAME,` error namespace**.
- The **`STD*` six-or-fewer-character routine prefix**.
- The **TDD discipline**, the per-module acceptance gate, and
  every existing lint rule.

The grammar is purely additive to comment content. It does not
require a single `set`, `quit`, or label rename anywhere in the
codebase.

## 10. Cross-references

- [Discoverability & tooling plan, § 3.1](../plans/historical/discoverability-and-tooling-plan.md#31-formalise-an-m-doc-grammar-extends-does-not-replace--doc) — the design rationale this guide implements.
- [Discoverability tracker, WA1–WA4](../tracking/discoverability-tracker.md#wa1--specify-m-doc-tag-grammar) — work items: WA1 ships this guide; WA2 backfills tags into src/; WA3 implements `M-DOC-001`; WA4 ships the manifest generator that consumes the grammar.
- [Module tracker D2](../tracking/module-tracker.md#deferred-decisions--revisit-triggers) — the `@stable` SemVer CI gate is deferred; annotating now keeps the option open.
- [STDJSON source — `parse` label](../../src/STDJSON.m) — the worked example in § 6 is sourced from this file.
- [JSDoc reference](https://jsdoc.app/) — the closest existing-ecosystem analogue. Tag names match where they overlap.
- [godoc commentary reference](https://go.dev/doc/comment) — the synopsis-line convention (§ 4) follows godoc.
- [rustdoc book](https://doc.rust-lang.org/rustdoc/) — the per-tag stability tier (`@stable`) borrows the `#[stable]` / `#[unstable]` distinction.
