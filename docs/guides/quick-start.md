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
(`STD*`) base, one-way `v → m`. The headline feature is the **RPC + HL7 → S3
traffic tap**; see [`tap-architecture.md`](tap-architecture.md) for the design
and [`../traffic-tap-dibrg.md`](../traffic-tap-dibrg.md) for deploy / back-out.

## 1. Two tiers — what needs VistA, what doesn't

- **Bare-engine green** (no Kernel/FileMan): the tap + S3 + auth core —
  `VSLTAP`, `VSLRPCTAP`, `VSLRPCWRAP`, `VSLS3`, `VSLTAPFC`, `VSLTAPHL`,
  `VSLHL7TAP`, `VSLSEC` (token path). These run on a plain `m-test-engine` /
  `m-test-iris`.
- **VistA-dependent**: `VSLCFG` (XPAR), `VSLFS` (FileMan), `VSLIO` (Kernel TCP),
  `VSLLOG`, `VSLTASK`, `VSLBLD`, `VSLENV` — need a live VistA (Kernel + FileMan).

## 2. Run the suite (30 sec)

`VSL*TST` suites use `m test` + `^STDASSERT` (staged from m-stdlib):

```bash
cd ~/vista-cloud-dev/v-stdlib
make check-fast                                   # fmt + lint + arch + drift gates (engine-free)
make test-bare ENGINE=ydb DOCKER=m-test-engine    # the bare-engine tap/S3/auth tier
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

## 4. The traffic tap (the headline feature)

The tap captures broker RPC + HL7 traffic and ships it to S3 as LDJSON, with
**non-interference** as the prime invariant (it never perturbs the captured
call). It is shipped as the **VSL KIDS build** (`dist/kids/VSL.kids`) and is
**reversibly installable** — `$$verifyClean^VSLTAPBO` proves no residue after
back-out.

- **Understand it:** [`tap-architecture.md`](tap-architecture.md) — data flow +
  the safety model.
- **Deploy / back out:** [`../traffic-tap-dibrg.md`](../traffic-tap-dibrg.md).

## 5. Where next

- **Per-module API:** [`../modules/index.md`](../modules/index.md) (every `VSL*`
  module, generated from source).
- **The engine-neutral base:** [m-stdlib](https://github.com/vista-cloud-dev/m-stdlib)
  (`STD*`) — JSON, base64, crypto, assertions, HTTP, S3, datetime, and the rest.
