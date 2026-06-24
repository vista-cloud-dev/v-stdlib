---
name: v-stdlib
type: knowledge
description: >
  v-stdlib is the VistA Standard Library — VistA-specific `VSL*` M
  routines (layer v) that bind Kernel / FileMan / XPAR / Broker
  surfaces to the engine-neutral m-stdlib (`STD*`) base, one-way
  `v -> m` per the m/v waterline. Covers XPAR config, security-key
  checks, the RPC/HL7 traffic tap, S3 egress, TaskMan, and KIDS
  build helpers. Load when writing VistA-layer M code that calls any
  VSL* module. Triggers: "v-stdlib", "VSL", "VSLCFG", "VSLSEC", "VSLTAP", "$$get^VSLCFG", "$$bySecid^VSLSEC", "^VSL".
---

# v-stdlib — pattern library and quick reference (unversioned)

Generated from v-stdlib's `dist/vsl-manifest.json` — every public
module + label, the canonical-idiom library, and the full U-VSL* error
surface, all rendered for AI / agent context loading.

**Catalogue:** 17 modules, 117 public labels,
7 error codes.

## When to use this skill

Load when the task references any `VSL*` module / `^VSL` symbol or
when writing VistA-layer M code (Kernel / FileMan / XPAR / Broker)
that should consume the VSL bindings instead of re-deriving them.

## Companion files

| File | Use when |
|---|---|
| [`patterns.md`](patterns.md) | Looking for a copy-paste idiom for a frequent task (XPAR config read, security-key check, the traffic-tap entry points). |
| [`manifest-index.md`](manifest-index.md) | You know the module name and want the full label list with synopses; or grepping for a function by name. |
| [`error-codes.md`](error-codes.md) | An $ETRAP fired with a `,U-VSL...-,` code and you need to know which module / label set it. |

## Module catalogue

- **`VSLBLD`** — the VSL KIDS base build definition + env-check binding (packaging seam).
- **`VSLCFG`** — VistA configuration adapter over XPAR (Parameter Tools).
- **`VSLENV`** — the VSL KIDS environment-check routine (the XPDENV hook).
- **`VSLFS`** — VistA FileMan storage adapter (FileMan DBS record store).
- **`VSLHL7TAP`** — HL7 store-tail adapter (decoupled, zero in-line).
- **`VSLIO`** — VistA TCP transport adapter over the Kernel device handler.
- **`VSLLOG`** — VistA FileMan audit-sink adapter (the S3 audit seam).
- **`VSLRPCTAP`** — RPC tap adapter at the VSLRPC chokepoint (the fenced tee).
- **`VSLRPCWRAP`** — the XWB broker-dispatch wrap glue (FU-5 / G-RPCHOOK).
- **`VSLS3`** — S3 egress sink: LDJSON envelope + the §11 bucket layout.
- **`VSLSEC`** — VistA identity/authorization adapter (Kernel).
- **`VSLTAP`** — non-interference traffic-tap core (the safety gate).
- **`VSLTAPBO`** — traffic-tap back-out / verify-clean (the G-UNINST gate).
- **`VSLTAPFC`** — fidelity comparator: byte-equality proof, not assertion.
- **`VSLTAPHL`** — tap health instrument + standby readiness (the watchdog).
- **`VSLTAPRUN`** — the periodic fidelity-run task (closes the console loop).
- **`VSLTASK`** — VistA TaskMan persistent-listener adapter (the process seam).

## Architectural rules

- **The m/v waterline is one-way: `v -> m`.** A `VSL*` routine MAY
  call an `STD*` routine; an `STD*` routine MUST NOT call a `VSL*`
  one. VistA vocabulary (FileMan, KIDS, XPAR, Broker) lives here,
  never below the line in m-stdlib.
- **VistA-specific.** v-stdlib needs Kernel / FileMan / KIDS; the
  tap + S3 + auth tier (VSLTAP/VSLRPCTAP/VSLS3/VSLSEC) is bare-engine
  green, the rest needs a live VistA.
- **Each module is a flat routine; you `do`-call or `$$`-call public
  labels.** No global registries, no init hooks, no DI.

## Quick start

For a copy-paste idiom matching a high-frequency task, see
`patterns.md`. For the full per-symbol detail (params, returns,
raises, source location), the manifest `dist/vsl-manifest.json` is
the source of truth and `manifest-index.md` is its rendered index.

