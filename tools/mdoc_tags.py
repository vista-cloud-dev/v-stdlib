"""mdoc_tags.py — the single source of truth for the M-doc tag grammar.

Canonical for BOTH stdlibs (STD* and VSL*) — a byte-identical sibling in
m-stdlib and v-stdlib. This is the registry the spec-from-code gate is built
on (docs/plans/grammar-spec-from-code-gate-plan.md):

  - tools/gen-manifest.py  derives KNOWN_TAGS (+ the @tier name) from here, so
                           the generator can never recognise a tag absent from
                           this registry, or miss one present (registry ≡
                           generator by construction).
  - tools/gen-grammar.py   renders the §5 tag table in docs/guides/m-doc-grammar.md
                           from here, and `--check` drift-gates it.

Editing the tag set means editing THIS file. The per-tag body PARSERS stay
hand-coded in gen-manifest.py (genuinely tag-specific); this registry owns the
tag *set* and the doc-facing metadata only. The registry tags handled by other
generators (@icr/@source/@call/@status/@custodian → gen-icr / check_citations)
are deliberately NOT here — different concern.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class Tag:
    name: str            # e.g. "@param"
    level: str           # "label" (a label's doc block) | "module" (routine header)
    multiplicity: str    # human-readable, e.g. "0..N", "0..1", "0..1 (1 for public)"
    body_syntax: str     # e.g. "NAME [TYPE] BODY"
    manifest_field: str  # where it lands in the manifest, e.g. "params", "seams"
    synopsis: str        # one-line description (matches the grammar §5 entry)
    example: str         # a canonical `; doc:`-stripped example body
    status: str = "stable"


# The eleven doc-manifest tags. Order = the grammar's §5 order.
TAGS: list[Tag] = [
    Tag("@param", "label", "0..N", "NAME [TYPE] BODY", "params",
        "Parameter declaration.",
        '@param text string  RFC-8259 JSON document text'),
    Tag("@returns", "label", "0..1", "[TYPE] BODY", "returns",
        "Return-value declaration.",
        '@returns bool  1 on success, 0 on failure'),
    Tag("@raises", "label", "0..N", "CODE [BODY]", "raises",
        "Error-code declaration.",
        '@raises U-STDJSON-PARSE  malformed input'),
    Tag("@example", "label", "0..N", "BODY", "examples",
        "A runnable usage example (consecutive @example lines join).",
        '@example do parse^STDJSON("[1,2,3]",.t)'),
    Tag("@since", "label", "0..1 (1 for public)", "VERSION", "since",
        "The first version this label appeared in.",
        '@since v0.2.0'),
    Tag("@stable", "label", "0..1 (1 for public)", "experimental|stable|deprecated",
        "stable",
        "API-stability tier.",
        '@stable stable'),
    Tag("@see", "label", "0..1", "SYMBOL[, SYMBOL]*", "see_also",
        "Cross-references to related symbols.",
        '@see $$valid^STDJSON, $$encode^STDJSON'),
    Tag("@deprecated", "label", "0..1", "VERSION BODY", "deprecated",
        "Deprecation version + replacement (requires @stable deprecated).",
        '@deprecated v0.5.0  use $$newThing^STDX'),
    Tag("@internal", "label", "0..1", "(no body)", "(excludes the label)",
        "Marks a documented label as NOT part of the public surface.",
        '@internal'),
    Tag("@seam", "label", "0..1", "NAME [vN]", "seams",
        "Marks a side-effecting seam entry point (a versioned contract).",
        '@seam STDENV v2'),
    Tag("@tier", "module", "0..1", "core|optional", "tier",
        "Classifies the whole module (routine-header tag).",
        '@tier optional'),
    Tag("@fixture", "label", "0..N", "PATH [BODY]", "fixtures",
        "Declares an example's sample-data fixture dependency (Living Examples).",
        '@fixture examples/data/stdcsv/people.csv  the input rows'),
    Tag("@illustrative", "label", "0..1", "REASON", "illustrative",
        "Marks a label whose example is illustrative-only — exempt from the "
        "executable-example coverage requirement; the reason is required.",
        '@illustrative needs a configured live S3 sink to run'),
]


def all_names() -> set[str]:
    return {t.name for t in TAGS}


def label_tags() -> set[str]:
    """The tag names valid inside a label's doc block (drives KNOWN_TAGS)."""
    return {t.name for t in TAGS if t.level == "label"}


def module_tags() -> set[str]:
    """The tag names valid in the routine header (e.g. @tier)."""
    return {t.name for t in TAGS if t.level == "module"}


def by_name(name: str) -> Tag | None:
    for t in TAGS:
        if t.name == name:
            return t
    return None
