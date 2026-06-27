---
title: "DIBRG — VSL Traffic-Tap: Deploy / Install / Back-out / Rollback Guide"
status: draft
created: 2026-06-21
doc_type: [OPERATIONS]
package: VSL (RPC + HL7 → S3 traffic tap)
spec: docs/proposals/implemented/rpc-traffic-s3-streaming.md (in the docs repo)
plan: docs/proposals/implemented/rpc-traffic-s3-streaming-implementation-plan.md §9 (GA)
---

# DIBRG — VSL Traffic-Tap deploy / install / back-out / rollback

The operational runbook for installing, configuring, **backing out**, and rolling
back the VistA RPC + HL7 → S3 traffic tap on a live VistA. The tap is shipped as
the **VSL KIDS build** (`dist/kids/VSL.kids`); everything below the waterline is
already proven (capture core, egress, fidelity, console). This guide is the GA
deployment contract.

> **Install and back-out are strictly v-pkg.** The tap ships as one KIDS build;
> `v-pkg install`/`uninstall` (snapshot/restore class-aware) are the ONLY install
> and reversal methods — there is no bespoke M installer or back-out routine.
> Engine access is **only** through the driver stack (`v-pkg`, `m vista exec`) —
> never raw `docker exec`/`iris session`.

---

## 0. What the tap installs (the footprint)

| Layer | Artifact | Installed by | Removed by |
|---|---|---|---|
| Routines | `VSLTAP`, `VSLRPCTAP`, `VSLHL7TAP`, `VSLTAPHL`, `VSLTAPFC`, `VSLS3` (+ the VSL base) | `v-pkg install` (KIDS) | `v-pkg uninstall` (routines + #9.7/#9.6) |
| Config | XPAR `#8989.51` PARAMETER DEFINITIONs | KIDS `parameterDefinitions` | `v-pkg uninstall` (drops the #8989.51 defs) |
| State | `^VSLTAP` control state + `^XTMP("VSLTAP",…)` rolling cache | runtime (arm + capture) | transient — `^XTMP` auto-purges (Kernel, `RETAIN` horizon); `^VSLTAP` is runtime control state |

**Reversal is `v-pkg uninstall`.** It removes the routines, the `#9.7/#9.6` build
records, and the `#8989.51` PARAMETER DEFINITIONs. The only thing it does not touch
is the tap's **runtime** footprint — the `^XTMP("VSLTAP",…)` rolling cache (which
auto-purges on the Kernel `RETAIN` horizon) and the `^VSLTAP` control state — both
transient runtime globals, not shipped data. There is **no** bespoke M back-out
routine; if an operator wants the runtime globals gone immediately rather than on
the purge horizon, `kill ^VSLTAP,^XTMP("VSLTAP")`.

The tap XPAR params:

| Param | Type | Purpose |
|---|---|---|
| `VSL TAP CAP` | numeric | rolling-ring capacity (records) |
| `VSL TAP MAXBYTES` | numeric | copy-cost ceiling (bytes) → auto-failover trip |
| `VSL TAP HBSTALE` | numeric | heartbeat staleness bound (seconds) |
| `VSL TAP RETAIN` | numeric | `^XTMP` cache retain days (Kernel auto-purge) |
| `VSL TAP ALWAYSON` | yes/no | always-on flight-recorder opt-in |
| `VSL S3 ENDPOINT` | free text | S3 endpoint override (empty = real AWS) |
| `VSL S3 BUCKET` | free text | target bucket |
| `VSL S3 REGION` | free text | SigV4 region (e.g. `us-gov-west-1`) |
| `VSL S3 PREFIX` | free text | per-station key prefix (fleet partition) |

---

## 1. Pre-install checks

1. **Driver reachability** — `m vista status --engine <ydb|iris> --transport docker`
   reports running/healthy.
2. **Environment** — confirm the target is a VistA engine (Kernel + FileMan
   present); the VSL package is VistA-specific.
3. **Required build** — the VSL build declares a Required Build on the MSL base
   (`MSL*0.1*1`, action *leave global*); the MSL `STD*` library must be present.

## 2. Install

Build the transport (deterministic, drift-gated) and install over the driver.

```sh
# Build the KIDS transport (or use the committed dist/kids/VSL.kids)
make kids                                   # -> dist/kids/VSL.kids

# YDB-VistA (e.g. vehu):
M_YDB_CONTAINER=vehu \
M_YDB_GBLDIR=/home/vehu/g/vehu.gld \
M_YDB_ROUTINES='<vehu gtmroutines>' \
  v-pkg install --engine ydb --transport docker dist/kids/VSL.kids

# IRIS-VistA (e.g. foia-t12):
M_IRIS_TRANSPORT=docker M_IRIS_CONTAINER=foia-t12 \
M_IRIS_NAMESPACE=VISTA M_IRIS_IRIS_INSTANCE=IRIS \
  v-pkg install --engine iris --transport docker dist/kids/VSL.kids
```

## 3. Verify

```sh
v-pkg verify --engine <ydb|iris> --transport docker dist/kids/VSL.kids
```
Expect `#9.7` install status **3** (Install Completed) and every routine present.
A smoke check: `m vista exec … 'W $$state^VSLTAP()'` → `OFF` (armed only by the
operator/console).

## 4. Configure (self-configuring + operator)

The KIDS install creates the tap XPAR params (unset). Set the deployment values at
SYS (FileMan/XPAR, or `$$set^VSLCFG`); at minimum the S3 destination:

```
VSL S3 ENDPOINT  = ""                  ; empty = real AWS (set for MinIO/LocalStack)
VSL S3 BUCKET    = vista-traffic-<env>
VSL S3 REGION    = us-gov-west-1
VSL S3 PREFIX    = <station>
```

Then arm the tap:

```
do arm^VSLTAP()                ; operator kill-switch ON
```

> The tap is **consumer-gated** and **fail-safe-OFF**: with no consumer present
> (or any interference signal) capture/egress stays OFF. The operator console
> (`POST /traffic/tap action=off`) and per-host auto-failover are the kill
> switches.

## 5. Back-out (strictly v-pkg)

Disarm the tap, then reverse the install with the generic v-pkg lifecycle. The tap
is class-1 pure-overwrite of the broker splice (snapshot/restore handles that), and
the VSL package itself uninstalls routines + `#9.7/#9.6` + the `#8989.51`
PARAMETER DEFINITIONs:

```
; 1. disarm (operator kill-switch OFF) so capture/egress stops
do off^VSLTAP()

; 2. reverse the install — routines + #9.7/#9.6 + #8989.51 param defs
v-pkg uninstall --engine <ydb|iris> --transport docker dist/kids/VSL.kids

; 3. (optional) drop the transient runtime globals immediately rather than
;    waiting for the ^XTMP Kernel purge horizon
kill ^VSLTAP,^XTMP("VSLTAP")
```

Reversal is **entirely** the `v pkg uninstall` in step 2 — it removes the shipped
routines, the `#9.7`/`#9.6` build records, and the `#8989.51` parameter
definitions. There is **no** bespoke broker-wrap back-out and **no** bespoke M
back-out routine: bespoke installers/patchers are forbidden org-wide (the old
`v pkg wrap-rpc` splice was deleted — see the `never-use-bespoke-installer`
directive). Install and back-out are strictly the generic `v pkg install` /
`v pkg uninstall` KIDS lifecycle.

## 6. Rollback

A failed/partial install rolls back via §5 — the same path. Because the in-app
capture path is **host/instance/cloud-independent** (risk G-HW), rollback is
uniform across the fleet; the per-station S3 prefix isolates blast radius.
Re-install (§2) after correcting the fault.

---

## 7. Status & owed live validation

Install/back-out are the generic v-pkg lifecycle (snapshot/restore class-aware),
exercised by the v-pkg suite. **Owed:** the live `install → verify → uninstall`
on both VistA engines (vehu + foia) over the driver, plus the patch bump and the
XPAR→`^VSLTAP("cfg")` seed step (so the hot-path knobs and the S3 config take
effect from the installed params). The live `liveReconcile` source seam (passive
mirror / #772) lands with the real-S3 increment (plan §9 stage 5.2).
