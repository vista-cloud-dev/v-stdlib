---
title: v-stdlib — 5-minute quick start
status: live
created: 2026-06-24
last_modified: 2026-06-24
revisions: 1
doc_type: [GUIDE]
---

# v-stdlib — 5-minute quick start

`VSL*` is the **VistA-specific** standard library (layer `v`) — it binds Kernel /
FileMan / XPAR / Broker to the engine-neutral [`m-stdlib`](https://github.com/vista-cloud-dev/m-stdlib)
(`STD*`) base, one-way `v → m`.

> The prior RPC + HL7 → S3 traffic tap has been **quarantined** (see
> [`../../quarantine/`](../../quarantine/)) pending its greenfield rewrite as
> `v-rpc-tap` against the live `CALLP^XWBPRS` path. This guide covers the
> current six-module library.

## 1. Two tiers — what needs VistA, what doesn't

- **Bare-engine green** (no Kernel/FileMan): `VSLSEC` (the token path) + the
  smoke suite — these run on a plain `m-test-engine` / `m-test-iris`.
- **VistA-dependent**: `VSLCFG` (XPAR), `VSLFS` (FileMan), `VSLIO` (Kernel TCP),
  `VSLLOG`, `VSLTASK` — need a live VistA (Kernel + FileMan).

## 2. Run the suite (30 sec)

`VSL*TST` suites use `m test` + `^STDASSERT` (staged from m-stdlib):

```bash
cd ~/vista-cloud-dev/v-stdlib
make check-fast                                   # fmt + lint + arch + drift gates (engine-free)
make test-bare ENGINE=ydb DOCKER=m-test-engine    # the bare-engine (no-VistA) suite set
make test ENGINE=ydb DOCKER=m-test-engine         # full set (needs a VistA-equipped engine)
```

## 3. Call something (1 min)

XPAR-backed config (the simplest VSL idiom; needs a VistA engine):

```m
set greeting=$$get^VSLCFG("VPNG GREETING","hello")   ; SYS-level value, else default
do set^VSLCFG("VPNG GREETING","howdy")               ; write at SYS scope
```

Security-key + identity over Kernel:

```m
if '$$hasKey^VSLSEC("XUPROG") write "not a programmer",! quit
set name=$$user^VSLSEC($$duz^VSLSEC())               ; the ambient principal's #200 NAME
```

For copy-paste idioms across the VSL modules see the skill pattern library
([`../../dist/skill/patterns.md`](../../dist/skill/patterns.md)), and a runnable
demo under [`../../examples/`](../../examples/).

## 4. Install (the VSL KIDS build)

The library ships as the **VSL KIDS build** (`dist/kids/VSL.kids`), installed
and backed-out **strictly via v-pkg** (`v-pkg install`/`uninstall`,
snapshot/restore class-aware) — no bespoke installer.

> The prior RPC/HL7→S3 tap (its `tap-architecture.md` / `traffic-tap-dibrg.md`
> runbooks and engine code) now lives under [`../../quarantine/`](../../quarantine/).
> Its replacement is the greenfield `v-rpc-tap` (a separate `VSL RPC TAP`
> package; see the `docs` repo `proposals/v-rpc-tap-scalable.md`).

## 5. Where next

- **Living, executable examples:** [`../../examples/index.md`](../../examples/index.md)
  — a runnable, self-verifying example for every public `VSL*` label (generated
  from the `@example` tags). The last live run, [`../../examples/REPORT.md`](../../examples/REPORT.md),
  shows them passing on real VistA engines (`vehu` + `foia`) with a byte-identical
  residue check.
- **Per-module API:** [`../modules/index.md`](../modules/index.md) (every `VSL*`
  module, generated from source).
- **The engine-neutral base:** [m-stdlib](https://github.com/vista-cloud-dev/m-stdlib)
  (`STD*`) — JSON, base64, crypto, assertions, HTTP, S3, datetime, and the rest.
