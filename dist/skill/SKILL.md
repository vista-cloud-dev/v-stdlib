---
name: v-stdlib
type: knowledge
description: >
  v-stdlib is the VistA Standard Library — VistA-specific `VSL*` M
  routines (layer v) that bind Kernel / FileMan / XPAR / Broker
  surfaces to the engine-neutral m-stdlib (`STD*`) base, one-way
  `v -> m` per the m/v waterline. Covers XPAR config, security-key
  checks, FileMan storage, file I/O, audit-sink logging, TaskMan,
  and KIDS build helpers. Load when writing VistA-layer M code that calls any
  VSL* module. Triggers: "v-stdlib", "VSL", "VSLCFG", "VSLSEC", "$$get^VSLCFG", "$$bySecid^VSLSEC", "^VSL".
---

# v-stdlib — pattern library and quick reference (unversioned)

Generated from v-stdlib's `dist/vsl-manifest.json` — every public
module + label, the canonical-idiom library, and the full U-VSL* error
surface, all rendered for AI / agent context loading.

**Catalogue:** 6 modules, 39 public labels,
7 error codes.

## When to use this skill

Load when the task references any `VSL*` module / `^VSL` symbol or
when writing VistA-layer M code (Kernel / FileMan / XPAR / Broker)
that should consume the VSL bindings instead of re-deriving them.

## Companion library — m-stdlib (layer m, engine-neutral)

v-stdlib is the **VistA-specific** half (layer `v`). It sits ON the
engine-neutral base **m-stdlib** (`STD*`, layer `m`) — JSON, base64,
crypto, assertions, datetime, HTTP, S3, and the rest. The m/v waterline
is one-way (`v -> m`): a `VSL*` routine MAY call an `STD*` one, never the
reverse. For an engine-neutral primitive, load the **m-stdlib** skill:
<https://github.com/vista-cloud-dev/m-stdlib/blob/master/dist/skill/SKILL.md>.

## Companion files

| File | Use when |
|---|---|
| [`patterns.md`](patterns.md) | Looking for a copy-paste idiom for a frequent task (XPAR config read, security-key check, FileMan storage, TaskMan). |
| [`manifest-index.md`](manifest-index.md) | You know the module name and want the full label list with synopses; or grepping for a function by name. |
| [`error-codes.md`](error-codes.md) | An $ETRAP fired with a `,U-VSL...-,` code and you need to know which module / label set it. |

## Module catalogue

- **`VSLCFG`** — VistA configuration adapter over XPAR (Parameter Tools).
- **`VSLFS`** — VistA FileMan storage adapter (FileMan DBS record store).
- **`VSLIO`** — VistA TCP transport adapter over the Kernel device handler.
- **`VSLLOG`** — VistA FileMan audit sink (the dedicated VSL AUDIT file).
- **`VSLSEC`** — VistA identity/authorization adapter (Kernel).
- **`VSLTASK`** — VistA TaskMan persistent-listener adapter (the process seam).

## Architectural rules

- **The m/v waterline is one-way: `v -> m`.** A `VSL*` routine MAY
  call an `STD*` routine; an `STD*` routine MUST NOT call a `VSL*`
  one. VistA vocabulary (FileMan, KIDS, XPAR, Broker) lives here,
  never below the line in m-stdlib.
- **VistA-specific.** v-stdlib needs Kernel / FileMan / KIDS; the
  security token path (VSLSEC) is bare-engine green, the rest
  (VSLCFG/VSLFS/VSLIO/VSLLOG/VSLTASK) needs a live VistA.
- **Each module is a flat routine; you `do`-call or `$$`-call public
  labels.** No global registries, no init hooks, no DI.

## Quick start

For a copy-paste idiom matching a high-frequency task, see
`patterns.md`. For the full per-symbol detail (params, returns,
raises, source location), the manifest `dist/vsl-manifest.json` is
the source of truth and `manifest-index.md` is its rendered index.

