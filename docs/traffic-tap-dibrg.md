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

> **Reversible install is the invariant.** Every install step has an exact
> reversal, and `$$verifyClean^VSLTAPBO` proves no residue remains. Engine access
> is **only** through the driver stack (`v-pkg`, `m vista exec`) — never raw
> `docker exec`/`iris session`.

---

## 0. What the tap installs (the footprint)

| Layer | Artifact | Installed by | Removed by |
|---|---|---|---|
| Routines | `VSLTAP`, `VSLRPCTAP`, `VSLHL7TAP`, `VSLTAPHL`, `VSLTAPFC`, `VSLS3`, `VSLTAPBO`, `VSLTAPRUN` (+ the VSL base) | `v-pkg install` (KIDS) | `v-pkg uninstall` (routines + #9.7/#9.6) |
| Config | 10 XPAR `#8989.51` PARAMETER DEFINITIONs (`$$params^VSLTAPBO`) | KIDS `parameterDefinitions` | **`VSLTAPBO` `cleanParams`** |
| Tasks | the periodic fidelity-run job (`run^VSLTAPRUN`) | `$$schedule^VSLTAPRUN` | **`VSLTAPBO` `cleanTasks`** |
| State | `^VSLTAP` control state + `^XTMP("VSLTAP",…)` rolling cache | runtime (arm + capture) | **`VSLTAPBO` `cleanState`** |

**Key fact (risk G-UNINST):** `v-pkg uninstall` is **routine-only** — it removes
the routines and the KIDS build records but **not** the config / tasks / cache /
state. `VSLTAPBO` is the dedicated back-out that removes that runtime footprint;
the full back-out is therefore **`v-pkg uninstall` + `do backout^VSLTAPBO()`**.

The 10 tap XPAR params:

| Param | Type | Purpose |
|---|---|---|
| `VSL TAP CAP` | numeric | rolling-ring capacity (records) |
| `VSL TAP MAXBYTES` | numeric | copy-cost ceiling (bytes) → auto-failover trip |
| `VSL TAP HBSTALE` | numeric | heartbeat staleness bound (seconds) |
| `VSL TAP RETAIN` | numeric | `^XTMP` cache retain days (Kernel auto-purge) |
| `VSL TAP ALWAYSON` | yes/no | always-on flight-recorder opt-in |
| `VSL TAP FIDELITY CADENCE` | numeric | periodic fidelity-run period (seconds) |
| `VSL S3 ENDPOINT` | free text | S3 endpoint override (empty = real AWS) |
| `VSL S3 BUCKET` | free text | target bucket |
| `VSL S3 REGION` | free text | SigV4 region (e.g. `us-gov-west-1`) |
| `VSL S3 PREFIX` | free text | per-station key prefix (fleet partition) |

---

## 1. Pre-install checks

1. **Driver reachability** — `m vista status --engine <ydb|iris> --transport docker`
   reports running/healthy.
2. **Environment** — the KIDS env-check (`VSLENV`) runs automatically at Load and
   Install (XPDENV); it aborts (XPDQUIT) if Kernel (XU) is absent and reports
   engine / version / Kernel level / TLS-config presence.
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

The KIDS install creates the 10 XPAR params (unset). Set the deployment values at
SYS (FileMan/XPAR, or `$$set^VSLCFG`); at minimum the S3 destination:

```
VSL S3 ENDPOINT  = ""                  ; empty = real AWS (set for MinIO/LocalStack)
VSL S3 BUCKET    = vista-traffic-<env>
VSL S3 REGION    = us-gov-west-1
VSL S3 PREFIX    = <station>
VSL TAP FIDELITY CADENCE = 3600
```

Then arm + start the periodic fidelity run:

```
do arm^VSLTAP()                ; operator kill-switch ON
set tsk=$$schedule^VSLTAPRUN() ; queue the periodic fidelity run (records the task)
```

> The tap is **consumer-gated** and **fail-safe-OFF**: with no consumer present
> (or any interference signal) capture/egress stays OFF. The operator console
> (`POST /traffic/tap action=off`) and per-host auto-failover are the kill
> switches.

## 5. Back-out (the reversal — risk G-UNINST)

Run the runtime back-out **first** (it reads the task numbers from `^VSLTAP`
before the state is removed), then the routine-level KIDS uninstall:

```
; 1. remove the runtime footprint (tasks -> XPAR params -> ^XTMP cache -> ^VSLTAP)
do backout^VSLTAPBO()

; 2. prove nothing is orphaned
set clean=$$verifyClean^VSLTAPBO(.detail)   ; clean=1, detail() empty

; 3. routine-level back-out (routines + #9.7/#9.6)
v-pkg uninstall --engine <ydb|iris> --transport docker dist/kids/VSL.kids
```

`backout^VSLTAPBO()` is idempotent and fault-fenced (each VistA leg is
`$text()`-guarded), so a partial install or a re-run is safe.

## 6. Verify-clean (the back-out exit gate)

`$$verifyClean^VSLTAPBO(.detail)` returns **1** iff:
- `^XTMP("VSLTAP")` and `^VSLTAP` are gone (globals),
- no tap `#8989.51` PARAMETER DEFINITION survives (params),
- no recorded fidelity/flush task record survives (tasks).

`detail("globals"/"params"/"tasks")` names any survivor. A non-clean result means
the back-out is incomplete — do not consider the system rolled back.

## 7. Rollback

A failed/partial install rolls back via §5 (back-out) + §6 (verify-clean) — the
same path. Because the in-app capture path is **host/instance/cloud-independent**
(risk G-HW), rollback is uniform across the fleet; the per-station S3 prefix
isolates blast radius. Re-install (§2) after correcting the fault.

---

## 8. Status & owed live validation

The back-out **logic** and `$$verifyClean` are bare-proven dual-engine
(`VSLTAPBOTST` 12/12); the periodic fidelity-run machinery is bare-proven
(`VSLTAPRUNTST` 8/8). **Owed:** the live `install → verify → back-out →
verify-clean` on both VistA engines (vehu + foia) over the driver — the real
G-UNINST exit gate — plus the patch bump and the XPAR→`^VSLTAP("cfg")` seed step
(so the hot-path knobs and the S3 config take effect from the installed params).
The live `liveReconcile` source seam (passive mirror / #772) lands with the
real-S3 increment (plan §9 stage 5.2).
