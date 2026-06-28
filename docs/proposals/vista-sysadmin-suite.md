---
title: "VistA System-Administration Suite — VSL* engine modules + paired `v` CLI domains"
status: draft
created: 2026-06-27
last_modified: 2026-06-27
revisions: 1
doc_type: [PROPOSAL]
layer: v
related_modules: [VSLCFG, VSLSEC, VSLTASK, VSLFS]
---

# VistA System-Administration Suite

> **One-line.** Turn `v-stdlib` from a set of *seam adapters* (plumbing for apps)
> into the engine half of a **VistA sysadmin tool suite**: a family of `VSL*`
> M modules that expose the highest-yield administrator tasks through Supported
> APIs, each paired with a thin **Go `v` CLI domain** that drives it over the
> `m-driver-sdk` seam. Build the API-backed spine first; wrap the no-API,
> high-friction domains over FileMan DBS second.

---

## Contents

- [1. Executive summary](#1-executive-summary)
- [2. Current state — `v-stdlib` is seam adapters, not admin verticals](#2-current-state--v-stdlib-is-seam-adapters-not-admin-verticals)
- [3. What a VistA sysadmin needs (grounded in the gold corpus)](#3-what-a-vista-sysadmin-needs-grounded-in-the-gold-corpus)
- [4. Gap analysis — need → coverage → action](#4-gap-analysis--need--coverage--action)
- [5. Architecture — the M-engine / Go-CLI vertical](#5-architecture--the-m-engine--go-cli-vertical)
- [6. Proposed engine modules (`VSL*`)](#6-proposed-engine-modules-vsl)
  - [Tier 1 — API-backed spine](#tier-1--api-backed-spine-dual-engine-testable-build-first)
  - [Tier 2 — FileMan-DBS wrappers](#tier-2--fileman-dbs-wrappers-no-supported-api-upstream-build-second)
  - [Tier 3 — monitors](#tier-3--monitors-upstream-partly-interactive-flag-limits)
- [7. Proposed host surface (`v` CLI domains)](#7-proposed-host-surface-v-cli-domains)
  - [7.1 Client-surface criteria — web vs CLI/TUI](#71-client-surface-criteria--web-vs-clitui)
  - [7.2 The vertical registry — one Go binary, busybox-style](#72-the-vertical-registry--one-go-binary-busybox-style)
- [8. Phased roadmap](#8-phased-roadmap)
- [9. Cross-cutting concerns & risks](#9-cross-cutting-concerns--risks)
- [10. Open questions](#10-open-questions)
- [11. Out of scope](#11-out-of-scope)
- [12. References (vdocs GOLD corpus)](#12-references-vdocs-gold-corpus)

---

## 1. Executive summary

A VistA system administrator spends the day on a small, stable set of operational
tasks — *who's on, list/inquire/create/deactivate users, allocate keys, review and
clean the error trap, requeue/dequeue TaskMan jobs, clear alerts, read and set
system parameters, audit sign-ons, manage devices, monitor HL7 links, install and
verify KIDS patches.* Today, almost all of this is reachable **only** through
interactive `Systems Manager Menu [EVE]` options driven by a human at a terminal.

`v-stdlib`'s six current modules are **infrastructure seams** (config, storage,
socket, audit-sink, identity, process) — building blocks for *applications*, not
administrator-facing verticals. None of the ranked top-15 sysadmin tasks is
delivered as a callable, scriptable, CI-testable operation today.

This proposal defines that missing layer as **two coordinated deliverables**:

1. **Engine side (this repo, `v-stdlib`):** a suite of ~8–10 new `VSL*` modules,
   each binding one administrator domain through a **Supported API** (or, where
   VistA exposes none, a carefully-built FileMan DBS wrapper). These reuse the
   existing seam modules (`VSLFS` for FileMan, `VSLSEC` for identity) and obey the
   m/v waterline.
2. **Host side (companion repo, the `v` CLI):** a suite of **plain-noun `v`
   domains** (`v user`, `v job`, `v alert`, `v config`, `v key`, `v error`,
   `v device`, `v audit`, `v hl7`, `v status`) — thin Go commands that reach the
   live engine **only** through `mdriver.Client`, calling the matching `VSL*`
   module. This is the "suite of vertical applications, each a Go CLI over a VistA
   module" shape requested.

**One binary, mixed surfaces.** Not every vertical wants the same client:
form-heavy provisioning and live dashboards are better as a **rich web UI**, while
scriptable, incident-context operations are better as **CLI/TUI**. So each vertical
carries a **client-type** assignment by an explicit rubric (§7.1), and the whole
host side is a **single registry-driven Go binary** — a busybox-style multiplexer
(§7.2) whose one declarative registry of verticals generates the CLI, the TUI, and
the web surfaces alike, keeping the suite syntactically and semantically coherent
as it grows.

The work is sequenced by **automatability**: the cleanly API-backed spine
(**XPAR · XQALERT · %ZTLOAD · ^XUSEC**) ships first and is fully dual-engine
testable; the no-Supported-API domains (user/device edit over `#200`/`#3.5`,
sign-on audit over `#3.081`) follow, built over FileMan DBS the way `VSLFS`
already is.

This proposal is **engine-suite + architecture**; the Go `v`-domain surface is
specified here at the command level and graduates to its own implementation plan
in the `v` CLI repo (one repo ↔ one session).

---

## 2. Current state — `v-stdlib` is seam adapters, not admin verticals

The six active modules (quarantine excluded) each bind a portable **seam** to a
VistA subsystem. They are correct and shipping, but they are *plumbing*:

| Module | Purpose (seam) | VistA binding | ICR | Admin-facing? |
|---|---|---|---|---|
| **VSLCFG** | config read/write (STDENV) at SYS entity | XPAR `$$GET^XPAR`/`EN^XPAR` | **2263** | partial — SYS get/set only |
| **VSLFS** | record store (STDKV) | FileMan DBS (`UPDATE^DIE`/`$$GET1^DIQ`/`FILE^DIE`) | DBS | no — generic CRUD primitive |
| **VSLIO** | TCP client (STDNET) | Kernel device handler `^%ZISTCP` | **2118** | no — transport |
| **VSLLOG** | audit sink | FileMan via VSLFS (v→v) | — | no — observability |
| **VSLSEC** | identity / authorization | `^XUSEC` key-check + `EN1^XUPSQRY` | **4575** + ref | partial — `$$hasKey`/`$$duz` |
| **VSLTASK** | persistent listener | TaskMan `^%ZTLOAD` (`$$PSET`/`$$TM`/`$$S`) | **10063** | no — listener lifecycle, not job ops |

**What this means for the suite.** Two of these modules are *foundations the suite
builds on*, not gaps:
- **VSLFS** is the FileMan-DBS pattern every no-API admin module (user, device,
  audit) will reuse — never re-bind `UPDATE^DIE` upward (waterline §9
  no-duplication).
- **VSLSEC** already owns `$$hasKey`/`$$duz`; the proposed **VSLKEY** *extends* it
  (enumerate, allocate) rather than duplicating it.

The remaining admin domains have **no** module at all.

---

## 3. What a VistA sysadmin needs (grounded in the gold corpus)

Source: VA Kernel & Toolkit documentation in the vdocs GOLD corpus. The
`Systems Manager Menu [EVE]` decomposes into 11 trees; the operational weight
concentrates in a handful. Ranked top tasks (menu prominence × dedicated SM guide ×
"frequently used" framing × clean-API availability):

| # | Task | Option(s) | File(s) | Automatable path | API status |
|---|---|---|---|---|---|
| 1 | **Who's on / live status** | `XUSTATUS`, `XUSTAT` | — | platform job table | engine-specific |
| 2 | **List / inquire / find users** | `XUSERLIST`, `XUSERINQ`, `XU FINDUSER`, `XUUSERSTATUS` | #200 | FileMan DBS / DIQ | direct-FM |
| 3 | **Create / edit user** | `XUSERNEW`, `XUSEREDIT` | #200 | FileMan DBS over #200 | **no Supported API** |
| 4 | **Deactivate / reactivate user** | `XUSERDEACT`, `XUSERREACT`, `XUAUTODEACTIVATE` | #200 | FileMan DBS (termination/DISUSER) | **no Supported API** |
| 5 | **Allocate / de-allocate keys** | `XUKEYALL`, `XUKEYDEALL`; check `^XUSEC` | #19.1 | `^XUSEC` (Supported ref) + DBS #19.1 | **partial** |
| 6 | **Review & clean error trap** | `^XTER`, `XUERTRP CLEAN`/`AUTO CLEAN` | #3.075 | `^%ZTER` rec; `^XTERPUR` purge | Supported/direct |
| 7 | **TaskMan list/requeue/dequeue/restart** | `XUTM INQ/REQ/DQ/RESTART` | #14.4, #19.2 | `^%ZTLOAD`, `KILL^%ZTLOAD`, `$$S^%ZTLOAD` | **Supported (10063)** |
| 8 | **View / clear / manage alerts** | `XQALERT`, `XQALERT DELETE OLD` | #8992 | `SETUP/GETACT/DELETE/DELETEA^XQALERT` | **Supported (10081)** |
| 9 | **View / set system parameters** | `XUSITEPARM`, `XPAREDIT` | #8989.3 | `$$GET^XPAR`/`ENVAL^XPAR`/`REP^XPAR` | **Supported (2263)** |
| 10 | **Sign-on / failed-access audit** | `XUSC LIST`, `XUFAIL` | #3.081 | read `^XUSEC(0,` (direct) | direct-global |
| 11 | **Device / printer management** | `XUDEVEDIT*` | #3.5 | FileMan DBS over #3.5 | **no Supported API** |
| 12 | **KIDS install + checksum verify** | `XPD MAIN`, `XTSUMBLD` | #9.7 | **already `v pkg` (v-pkg repo)** | covered elsewhere |
| 13 | **HLO interface monitoring** | HLO System Monitor (BS/DL) | #870, #777/#778 | read links/queues; **restart interactive-only** | read-only |
| 14 | **MailMan housekeeping** | `XMMGR` (disk/error/purge) | #4.x | partly interactive | mixed |
| 15 | **Capacity / RUM / KMPD** | `XTCM MAIN`, `KMPR RUM`, KMPD timing | — | run-routine options | report-driven |

**The automatable spine** (build first — every call is a documented Supported API
or a Supported direct-global reference, and all are dual-engine testable):
**XPAR (2263) · XQALERT (10081) · %ZTLOAD (10063) · ^XUSEC (Supported ref).**

**The high-friction, high-value gap** (build second — *no* Supported callable, so a
`VSL*` wrapper over FileMan DBS / the file DD earns its keep): **user
create/edit/deactivate (#200), device edit (#3.5), sign-on-log read (#3.081).**

**Out of this suite's scope:** KIDS install (already `v pkg`); the RPC traffic tap
(separate greenfield `v-rpc-tap`); read-only *navigation/knowledge* tools (those
belong to the **VistA-Copilot** org, not here — this suite *actuates/operates* a
live engine, which is exactly the vista-cloud-dev `v` test).

---

## 4. Gap analysis — need → coverage → action

| Domain | Need (ranked task) | Current `v-stdlib` coverage | Gap → proposed module |
|---|---|---|---|
| Parameters | #9 view/set params (multi-entity) | VSLCFG (SYS get/set only) | **VSLPARM** — full XPAR admin surface |
| TaskMan | #7 job ops | VSLTASK (listener lifecycle only) | **VSLJOB** — list/inquire/requeue/dequeue/delete/status |
| Alerts | #8 alert admin | none | **VSLALERT** — list/get/clear/clearall/forward |
| Keys | #5 key admin | VSLSEC (`$$hasKey`/`$$duz`) | **VSLKEY** — enumerate/who-holds/allocate/deallocate/rename |
| Error trap | #6 review/clean | none | **VSLERR** — summary/list/detail/purge |
| Users | #2–4 user admin | none (VSLFS is the substrate) | **VSLUSER** — list/inquire/find/status/deactivate/reactivate/(create/edit) |
| Devices | #11 device admin | none (VSLFS substrate) | **VSLDEV** — list/inquire/edit/status |
| Audit | #10 sign-on/failed-access | none | **VSLAUD** — sign-on log + failed-access read/report |
| HL7 | #13 link monitoring | none | **VSLHLO** — link status/queue depth/stats (read; restart flagged) |
| Status | #1 who's-on/resource | none | **VSLSTAT** — sessions/jobs/resource snapshot (engine-specific) |
| KIDS | #12 install/verify | **v-pkg / `v pkg`** | none — do not duplicate |

---

## 5. Architecture — the M-engine / Go-CLI vertical

Each vertical is **one VSL\* module + one `v` domain**, split exactly at the
waterline:

```
   host (Go, layer v)                         engine (M, layer v)
   ┌─────────────────────┐   m-driver-sdk    ┌──────────────────────┐
   │  v <domain> <verb>  │  ───envelope───▶  │  VSL<DOMAIN>          │
   │  (cobra command;    │   mdriver.Client  │  Supported API /      │
   │   flags, output,    │  ◀──JSON result── │  FileMan DBS binding  │
   │   format, exit code)│                   │  (no direct L4 write) │
   └─────────────────────┘                   └──────────────────────┘
        v-cli repo                                 v-stdlib repo (this)
```

**Binding rules (all enforced, not advisory):**

1. **One-way `v → m`, seam = the SDK envelope.** The Go command reaches the engine
   **only** through `mdriver.Client` (Rule 3 transport monopoly). No raw
   `docker exec`/`iris session`; dev/test/CI go through `m vista exec` /
   `m test --docker` per the engine-access rule.
2. **Engine knowledge stays in the VSL module.** XPAR/XQALERT/%ZTLOAD/FileMan-DD
   logic lives in `VSL*`; the Go side owns only flags, formatting, exit codes, and
   orchestration. No VistA file numbers or option names hand-coded in Go.
3. **Reuse downward, never duplicate up.** `VSLUSER`/`VSLDEV`/`VSLAUD` reuse
   `VSLFS` for FileMan; `VSLKEY` reuses `VSLSEC`. `STD*` primitives (JSON, datetime)
   come from m-stdlib.
4. **Every module is registry-gated.** Each ships `@icr`/`@call`/`@source` tags →
   `dist/icr-registry.json` (drift gate `make check-icr`), a manifest entry
   (`make manifest` → `docs-check`), and a namespace claim. Trust is earned by the
   tag→registry→gate triple, not review.
5. **Actuation safety.** Read verbs (`list`, `inquire`, `status`, `tail`) are
   default-safe; mutating verbs (`create`, `deactivate`, `requeue`, `clear`,
   `set`, `allocate`) require an explicit confirm flag and emit a `VSLLOG` audit
   record. PHI-bearing output (user identifiers, sign-on records) is
   names/IEN-minimal by default.

**Why these are legitimate vista-cloud-dev `v` domains** (not VistA-Copilot
navigator tools): every one *reaches a live engine through the driver seam to do or
observe an operational thing* — the accepted eligibility test
([[v-cli-domain-eligibility]]). Even the read-only monitors (`v error tail`,
`v hl7 links`, `v status`) operate against a live engine, not a static model.

---

## 6. Proposed engine modules (`VSL*`)

Sketched API surfaces follow the house idiom (lower-case labels, `$$`-extrinsics
return values, by-ref arrays for lists, loud `$ECODE` only on malformed calls,
`$$lastError^VSL<MOD>()` for detail). Signatures are indicative, to be locked in
each module's TDD plan.

### Tier 1 — API-backed spine (dual-engine testable; build first)

**VSLJOB — TaskMan job operations.** Binds `^%ZTLOAD` (ICR **10063**) +
read-only `#14.4 TASK`/`#19.2 OPTION SCHEDULING`.
- `do list^VSLJOB(.out,filter)` — active/queued tasks (task#, routine, desc, user, status, sched time)
- `$$inquire^VSLJOB(ztsk,.out)` — one task's detail
- `$$requeue^VSLJOB(ztsk,when)` — requeue (REQ); `$$dequeue^VSLJOB(ztsk)` — run now
- `$$delete^VSLJOB(ztsk)` — `KILL^%ZTLOAD`
- `$$tmStatus^VSLJOB()` — scheduler heartbeat (`$$TM^%ZTLOAD`)
- *Pairs `v job ls|show|requeue|run|rm|status`.*

**VSLALERT — alert administration.** Binds `XQALERT` (ICR **10081** for delete; SETUP/GETACT Supported), `#8992`.
- `do list^VSLALERT(.out,duz)` — pending alerts for a user (or all, with key)
- `$$get^VSLALERT(xqaid,.out)` — alert detail
- `$$clear^VSLALERT(xqaid,duz)` — `DELETE^XQALERT`; `$$clearAll^VSLALERT(duz)` — `DELETEA^XQALERT`
- `$$forward^VSLALERT(xqaid,toDuz)` — re-target (where supported)
- `$$create^VSLALERT(.spec)` — `SETUP^XQALERT` (ops/test notifications)
- *Pairs `v alert ls|show|clear|clear-all|forward`.*

**VSLPARM — full XPAR parameter administration.** Binds XPAR (ICR **2263**) across
all entities (extends VSLCFG's SYS-only seam).
- `$$get^VSLPARM(entity,param,instance,fmt)` — `$$GET^XPAR`
- `do enum^VSLPARM(.out,entity,param)` — all instances (`ENVAL^XPAR`)
- `$$set^VSLPARM(entity,param,instance,value)` — `EN^XPAR`/`REP^XPAR`
- `do list^VSLPARM(.out,prefix)` — parameter definitions (#8989.51) by namespace
- *Pairs `v config get|enum|set|ls`.* (Supersedes `v config` over VSLCFG; VSLCFG
  remains the STDENV seam adapter for *apps*.)

**VSLKEY — security-key administration.** Binds `^XUSEC` (Supported ref) +
`$$RENAME^XPDKEY` + `#19.1` via FileMan DBS; reuses VSLSEC.
- `do held^VSLKEY(.out,duz)` — keys a user holds
- `do holders^VSLKEY(.out,key)` — who holds a key (`^XUSEC(key,*)`)
- `$$allocate^VSLKEY(key,duz)` / `$$deallocate^VSLKEY(key,duz)` — DBS over #19.1 allocation
- `$$rename^VSLKEY(old,new)` — `$$RENAME^XPDKEY`
- *Pairs `v key held|holders|grant|revoke|rename`.*

**VSLERR — error-trap review & cleanup.** Binds `^%ZTER`/`#3.075` + `^XTERPUR`.
- `do summary^VSLERR(.out,since)` — counts by error/routine/date
- `do list^VSLERR(.out,since,max)` — recent entries (time, routine, $ECODE, user)
- `$$detail^VSLERR(n,.out)` — one entry's frame/locals
- `$$purge^VSLERR(days)` — purge older than N days (`^XTERPUR`)
- *Pairs `v error summary|tail|show|purge`.*

### Tier 2 — FileMan-DBS wrappers (no Supported API upstream; build second)

**VSLUSER — user / account administration over `#200`.** Reuses VSLFS (DBS pattern); **no Kernel callable exists**, so each verb is a guarded DD-aware DBS op.
- `do list^VSLUSER(.out,filter)` / `$$find^VSLUSER(name,.out)` — `$$GET1^DIQ`/DIC
- `$$inquire^VSLUSER(duz,.out)` — profile (name, title, menu, last sign-on, status)
- `$$status^VSLUSER(duz)` — active / terminated / DISUSER
- `$$deactivate^VSLUSER(duz,reason)` / `$$reactivate^VSLUSER(duz)` — termination date / DISUSER via `FILE^DIE`
- `$$create^VSLUSER(.spec)` / `$$edit^VSLUSER(duz,.fields)` — **carefully**, DD-validated, behind confirm (see §9 R-USER)
- *Pairs `v user ls|find|show|status|deactivate|reactivate|create|edit`.*

**VSLDEV — device / printer administration over `#3.5`.** Reuses VSLFS.
- `do list^VSLDEV(.out,type)` / `$$inquire^VSLDEV(dev,.out)`
- `$$edit^VSLDEV(dev,.fields)` — DBS over #3.5 (subtype-aware: HFS/spool/resource)
- `$$status^VSLDEV(dev)` — in/out of service
- *Pairs `v device ls|show|edit|status`.*

**VSLAUD — sign-on / failed-access audit.** Reads `#3.081 ^XUSEC(0,` (Supported direct ref) + failed-access; read-only.
- `do signon^VSLAUD(.out,since,duz)` — sign-on log slice
- `do failed^VSLAUD(.out,since)` — failed-access attempts (`XUFAIL` data)
- `$$summary^VSLAUD(.out,since)` — counts by user/device/outcome
- *Pairs `v audit signon|failed|summary`.* (No mutating verbs except sanctioned purge feed.)

### Tier 3 — monitors (upstream partly interactive; flag limits)

**VSLHLO — HL7/HLO link & queue monitoring.** Reads `#870 HL LOGICAL LINK`,
HLO message stores (#777/#778); **restart is interactive-only upstream** → not
exposed as a callable (flagged; revisit if a Supported control API surfaces).
- `do links^VSLHLO(.out)` — link state, up/down, last activity
- `do queues^VSLHLO(.out)` — queue depth per link
- `$$stats^VSLHLO(.out,since)` — message counts/throughput
- *Pairs `v hl7 links|queues|stats`.*

**VSLSTAT — system status / who's-on / resource snapshot.** **Engine-specific**
(YDB job table vs IRIS `$SYSTEM` / `%SS`); mirror the `$ZVERSION["IRIS"` arm
pattern. Highest portability risk — see §9 R-STAT.
- `do sessions^VSLSTAT(.out)` — active sign-on sessions / jobs
- `$$counts^VSLSTAT(.out)` — job/process counts, global growth where available
- *Pairs `v status sessions|counts`.*

> KIDS (`v pkg`) and capacity/RUM/KMPD are **not** new modules here: KIDS is owned
> by v-pkg; capacity is report-driven, low-frequency, and deferred to a future
> `VSLCAP`/`v capacity` increment if demand appears.

---

## 7. Proposed host surface (`v` CLI domains)

The Go deliverable is a suite of **plain-noun `v` domains**, one per module,
mounted in the `v` umbrella (the [`v` CLI platform](https://github.com/vista-cloud-dev)
plain-noun rule: a domain wraps an insider subsystem in a name a developer can
guess; the VA product name never appears in a command/flag). Each domain is a thin
cobra command calling its `VSL*` module via `mdriver.Client`.

| `v` domain | Verbs (indicative) | Engine module | Tier | Client (primary) |
|---|---|---|---|---|
| `v job` | `ls show requeue run rm status` | VSLJOB | 1 | CLI/TUI |
| `v alert` | `ls show clear clear-all forward` | VSLALERT | 1 | CLI/TUI |
| `v config` | `get enum set ls` | VSLPARM | 1 | CLI/TUI |
| `v key` | `held holders grant revoke rename` | VSLKEY | 1 | CLI/TUI |
| `v error` | `summary tail show purge` | VSLERR | 1 | CLI/TUI |
| `v user` | `ls find show status deactivate reactivate create edit` | VSLUSER | 2 | Web (+CLI) |
| `v device` | `ls show edit status` | VSLDEV | 2 | Web (+CLI) |
| `v audit` | `signon failed summary` | VSLAUD | 2 | Web (+CLI) |
| `v hl7` | `links queues stats` | VSLHLO | 3 | Web (+CLI) |
| `v status` | `sessions counts` | VSLSTAT | 3 | Web (+CLI) |

The **Client** column is the *primary* surface each vertical is built for first,
derived by the rubric in §7.1; the registry (§7.2) makes every verb CLI-reachable
regardless, so "Web" never means "not scriptable."

**Packaging decision (open — §10 Q2).** Because the host side is **one
registry-driven binary** (§7.2), this is a question of *which repo hosts the
registry*, not how many programs ship — there is one `v` busybox either way.
**(A)** the existing `v-cli` repo (org's established umbrella, shared `clikit`) vs
**(B)** a dedicated **`v-admin`** repo. Recommendation: **(A)** — one discoverable
`v` surface; split out only if the admin surface outgrows one repo. Either way the
Go work is a **companion effort in its own repo/session**, not in `v-stdlib`.

### 7.1 Client-surface criteria — web vs CLI/TUI

Not every admin operation wants the same front end. Score each vertical on six
axes; the dominant axes pick the **primary** surface. The registry (§7.2)
guarantees *every* verb is also CLI-addressable for automation, so **"Web" never
means "not scriptable"** — it means the recommended, primary surface is the web UI.

| Axis | Pushes to **Web** | Pushes to **CLI/TUI** |
|---|---|---|
| **Edit complexity** | many fields, DD validation, subtype branching, multi-step | single value / few flags |
| **Visualization** | dashboards, trends, topology/maps | flat tabular |
| **Real-time** | continuous live monitoring | point-in-time snapshot |
| **Scriptability** | — | cron / pipeline / CI / bulk (mandatory) |
| **Mutation risk + review** | high-risk, needs guarded review/approve UI | low-risk, reversible |
| **Operator context** | scheduled review at a desk, less-technical admin | incident response at a terminal / SSH |

**Derived assignment:**
- **Web-first:** `v user` (form-heavy `#200` provisioning, high review), `v device`
  (subtype-sensitive `#3.5` editor), `v audit` (compliance review + access-pattern
  visualization), `v hl7` (link topology + live throughput), `v status` (real-time
  who's-on / resource dashboard).
- **CLI/TUI-first:** `v job` (scriptable task ops + a live TUI monitor), `v error`
  (terminal-context tail + trend, incident response), `v config` (scriptable
  params), `v key` (scriptable grants + access-review), `v alert` (scriptable bulk
  clear).

The split is principled, not arbitrary: **mutation-heavy forms and visual/real-time
monitors → web; scriptable, incident-context operations → CLI/TUI.** Secondary
surfaces are cheap to add from the same registry later (a web trend view for
`v error`, a CLI quick-check for `v status`); the **Client** column names the
surface each vertical is built for *first*.

### 7.2 The vertical registry — one Go binary, busybox-style

To stay coherent as it expands, the host side is **not** ten independent CLIs plus a
separate web app. It is **one statically-linked Go binary** whose entire surface is
generated from a **single declarative registry of verticals** — busybox
multiplexing applied to VistA administration.

```go
// The single source of truth for every vertical. CLI, TUI, and web are derived.
type Vertical struct {
    Domain string     // plain noun, lint-gated: "job", "user", ...
    Module string     // engine binding: "VSLJOB"
    Tier   int        // 1..3 build order
    Client ClientType // CLITUI | Web — the PRIMARY surface (§7.1)
    Verbs  []Verb
}
type Verb struct {
    Name   string // "ls", "requeue", "create"
    Label  string // VSL label it invokes: "list^VSLJOB" (drift-gated)
    Safety Safety // Read | Mutate
    Args   []Arg
}
var Registry = []Vertical{ /* job, alert, config, key, error, user, device, audit, hl7, status */ }
```

One dispatcher serves all surfaces from `Registry`:
- **CLI (busybox):** `v <domain> <verb> [args]` resolves the verb, marshals args,
  runs `Verb.Label` on the engine via `mdriver.Client`, renders the result — every
  verb of every vertical reachable (the universal-CLI guarantee).
- **TUI:** `v <domain>` with no verb / `v top` opens a registry-rendered live view
  for `CLITUI` verticals.
- **Web:** `v serve` starts an HTTP server that, for every `Client == Web` vertical,
  mounts a JSON API (`GET /api/<domain>/<verb>` for `Read`, `POST` for `Mutate`
  behind a confirm token) and serves an **embedded SPA** — the same single binary,
  no second deployable. (Precedent: the retired Admin Web Suite's pivot — a single
  Go binary embedding a Web-Components SPA, reaching the engine only via
  `mdriver.Client`; its rendering pattern is reused, its scope is not.)

**Registry-driven gates** (the org `source-tag → registry → red-gate` discipline,
applied to the host surface — the "v CLI command surface" the org `CLAUDE.md`
already names as a generated, drift-gated artifact):
- **G-host-1 — verb↔label:** every `Verb.Label` must exist in `v-stdlib`'s
  `dist/vsl-manifest.json`; a host command cannot bind a nonexistent VSL label.
  Drift red-gates. This manifest contract is what keeps the two repos coherent
  across the waterline.
- **G-host-2 — plain-noun lint:** every `Domain` / `Verb.Name` passes the `v` CLI
  plain-language gate (no VA product names in the command surface).
- **G-host-3 — safety:** the dispatcher refuses to run a `Mutate` verb without a
  confirm token + `VSLLOG` audit; `Read` verbs are structurally side-effect-free.
- **G-host-4 — single-surface:** the registry is the *only* place a vertical is
  declared; CLI, TUI, and web are all derived — a gate rejects any hand-rolled
  command or HTTP route outside it.

This is what makes the suite expand coherently: a new vertical is **one registry
entry + its `VSL*` module**, and all three surfaces light up with zero bespoke
wiring. Adding `v capacity` later is a registry append, not a new program; whether
it renders as CLI or web is just its `Client` field.

---

## 8. Phased roadmap

Sequenced by automatability and dependency (leaf-first: engine module before its
`v` domain; spine before friction):

- **Phase 0 — foundation.** Confirm the `VSL<admin>` ⇄ `v <domain>` vertical
  pattern end-to-end with **one** thin slice: `VSLJOB.list` + `v job ls`
  (read-only, Supported API, dual-engine). Stand up the **vertical registry +
  busybox dispatcher** (§7.2) with `serve` scaffolded (G-host gates wired) so the
  web surface is purely additive later. Establishes the registry↔`mdriver.Client`↔
  `m vista exec` round-trip, the result-envelope shape, and the gate triple for the
  whole suite.
- **Phase 1 — API-backed spine.** VSLJOB, VSLALERT, VSLPARM, VSLKEY, VSLERR +
  their `v` domains (all `CLI/TUI`). All dual-engine testable (vehu + foia-t12).
  Mutating verbs behind confirm + `VSLLOG` audit.
- **Phase 2 — FileMan-DBS friction layer.** VSLUSER, VSLDEV, VSLAUD (all `Web`).
  Read verbs first (`ls`/`inquire`/`status`/`signon`); mutating user/device verbs
  last, DD-validated, with the strongest confirm + audit (R-USER, R-DEV).
- **Phase 3 — monitors.** VSLHLO, VSLSTAT (`Web`) — read-only; resolve the
  engine-specific portability work for VSLSTAT before exposing it.
- **Web surface (cross-cutting; lands with its verticals).** `v serve` + the
  embedded SPA come online as each **Web**-type vertical's engine module ships
  (user/device/audit in Phase 2, hl7/status in Phase 3). Because every surface is
  generated from the registry, no web code is needed until a web-type vertical
  exists — then it is additive, behind the auth/TLS gate (R-WEB).
- **Phase 4 — polish.** Output formats (table/JSON), `--format` parity across
  domains, completion, docs/skill generation, optional `VSLCAP`/capacity if
  demanded.

Each phase closes per the org Increment Protocol (memory + tracker + commit), run
**per repo** (engine slice in `v-stdlib`, host slice in the `v` CLI repo).

---

## 9. Cross-cutting concerns & risks

- **R-USER (highest).** `#200` has **no Supported create/edit API**; a DBS wrapper
  must respect the DD's input transforms, triggers, and the many identity/security
  fields. Mitigation: read verbs first; for `create`/`edit`, validate every field
  through FileMan DBS (never direct global), gate behind explicit confirm, audit
  every mutation, and scope v1 to a documented field subset — defer full
  provisioning parity.
- **R-DEV.** `#3.5` edits are subtype-sensitive (HFS/spool/resource/print-queue);
  a naïve flat editor can misconfigure a device. Mitigation: subtype-aware DBS,
  read-back verification, confirm + audit.
- **R-STAT (portability).** Who's-on/resource data is **engine-specific** (YDB job
  table vs IRIS `$SYSTEM`/`%SS`). Mitigation: explicit `$ZVERSION["IRIS"` arms (the
  established m-stdlib/VSLIO pattern); ship YDB first, IRIS arm as a tracked
  follow-up; never silently return partial data.
- **R-HLO.** No Supported link-*control* API surfaced — restart stays interactive
  upstream. Mitigation: ship **read-only** monitoring; document the gap; revisit if
  a control API appears.
- **PHI / least-disclosure.** User, sign-on, and alert data are PHI-adjacent.
  Default to IEN/name-minimal output; require an explicit flag for fuller detail;
  audit reads of sensitive logs.
- **R-WEB (web-surface security).** A web admin surface must have authn/authz + TLS
  before it touches PHI. Mitigation: gate `v serve` behind the token auth path (the
  M6.5 VSL/MSL auth stack — validate a signed token, not a PIV card) and real TLS;
  this depends on closing the **VSLIO TLS gap** (`$$INIT^XUTLS`, ICR 7616). Until
  then `v serve` is dev/loopback-only and the CLI/TUI surfaces (already over the
  driver seam) are the production path — another reason web is additive, not
  blocking.
- **No bespoke installer.** Any engine-side install of these modules is **strictly**
  `v pkg install`/`uninstall` of a drift-gated KIDS build — never a bespoke patcher
  ([[never-use-bespoke-installer]]). The suite ships as ordinary `VSL*` routines in
  the v-stdlib KIDS build.
- **Drift gates.** Every module adds its `@icr/@call/@source` tags
  (`make check-icr`), a manifest entry + module page (`docs-check`), and a
  namespace claim — same governance as the current six.
- **Verify-before-trust on Supported APIs.** Two corpus items to confirm before
  Phase 1 locks: the exact ICR for `SETUP^XQALERT` (DELETE is 10081; SETUP/GETACT
  documented Supported but ICR not captured), and the precise `#3.081` node map for
  VSLAUD. Cited as "verify" in §3, not assumed.

---

## 10. Open questions

1. **Web stack (§7.2).** Reuse the retired Admin Web Suite's
   Web-Components-SPA-embedded-in-a-Go-binary pattern for `v serve`, or a different
   embed? Recommend: reuse the pattern — one binary, one auth path.
2. **Registry / binary home (§7).** Which repo hosts the vertical registry + `v`
   busybox — `v-cli` (recommended) or a dedicated `v-admin`? One binary either way.
3. **Client-type edge cases (§7.1).** Are any "CLI/TUI" verticals worth a secondary
   web view at v1 (e.g. an `v error` trend dashboard, a `v key` holder-matrix), or
   defer all secondary surfaces? Recommend: defer; ship each vertical's primary
   surface first.
4. **`v config` overlap.** VSLPARM (admin, multi-entity) vs VSLCFG (app STDENV
   seam, SYS-only) — keep both (different audiences) or have `v config` call
   VSLPARM exclusively and leave VSLCFG purely as an internal seam? Recommend: keep
   both, `v config` → VSLPARM.
5. **Create/edit ambition for v1.** Full `#200` provisioning parity, or a
   documented field subset first (recommended)?
6. **Capacity domain.** Build `VSLCAP`/`v capacity` now or defer until a concrete
   reporting ask exists (recommended: defer)?

---

## 11. Out of scope

- **KIDS / package install** — already `v pkg` (v-pkg repo).
- **RPC traffic tap** — the separate greenfield `v-rpc-tap` effort.
- **Read-only VistA *navigation/knowledge* tools** (catalogs over static models or
  docs) — these belong to the **VistA-Copilot** org, not vista-cloud-dev.
- **The Go `v`-domain *implementation*** — specified here at the command level;
  graduates to its own plan in the `v` CLI repo.

---

## 12. References (vdocs GOLD corpus)

- Kernel & Toolkit Technical Manual — `XU/krn_8_0_tm` (EVE menu tree; `xuser`,
  `xutio`, `xutm-mgr`, `xusitemgr`, `xuspy`, `xuprog`; `kernel-system-parameters-89893-file`, `xparedit-routine`)
- TaskMan — `XU/krn_8_0_sm_taskman_ug` (requeue/dequeue/cleanup); `XU/krn_8_0_dg_taskman_ug` (`killztload-delete-a-task`, `tmztload-check-if-taskman-is-running`)
- Toolkit / XPAR — `XU/krn_8_0_dg_toolkit_ug` (`getxpar…` ICR 2263, `envalxpar…`, `repxpar…`, `compare-localnational-checksums-report-option`)
- Alerts — `XU/krn_8_0_dg_alerts_ug` (`overview`, `deletexqalert…` ICR 10081, `getactxqalert…`, `actionxqalert…`)
- Security keys — `XU/krn_8_0_dg_security_keys_ug/key-lookup` (`^XUSEC` Supported), `…/renamexpdkey…`
- Error processing — `XU/krn_8_0_dg_error_processing_ug/d-xter`; `XU/krn_8_0_sm_utilities_ug/clean-error-trap-option` (#3.075, `^%ZTER`)
- Sign-on / security — `XU/krn_8_0_sm_signon_security_ug/kernel-signon-auditing-files` (#3.081, `^XUSEC(0,`); `XU/krn8_0st/failed-access-attempts`, `…/general-information-about-users`
- Device handler — `XU/krn_8_0_sm_device_handler_ug/device-edit-menu`; `XU/krn_8_0_dg_device_handler_ug` (`callzistcp…` ICR 2118)
- KIDS — `XU/krn_8_0_sm_kids_ug/verify-package-integrity-option`
- MailMan — `XM/xm_8_0_techman/menu-diagram`, `XM/xm_8_0_sysmgmtguide/disk-space-management…`
- HL7 / HLO — `HL7/hlo_system_manager_manual` (`overview`, `bs--brief-status`, `dl--down-links`); `HL7/hl_1_6_126_tm/hl-logical-link-file-870`
- Capacity — `KMPR/kmpr2_0tm/rum-manager-menu`; `KMPD/kmpd3_0tm_r/options-with-parents`

---

*Companion: the Go `v`-domain suite (own plan, `v` CLI repo). Precedent patterns:
`VSLFS` (FileMan DBS), `VSLSEC` (identity), `VSLTASK` (TaskMan), the v-pkg `v pkg`
domain, and the accepted `v` CLI domain-eligibility ADR.*
