---
name: m4-vslsec-vsllog
description: VSL/MSL M4 DONE — VSLSEC (security/authz seam S5) + VSLLOG (audit sink S3) in v-stdlib. Dual-engine GREEN 11/11 (vehu YDB + foia-t12 IRIS). VSLSEC = authz-only (NO Kernel hash — grounded: no portable Kernel generic-hash exists; crypto stays in STDCRYPTO): hasKey over ^XUSEC, duz (#200 IEN), user (#200 NAME via VSLFS reuse), loud ,U-VSL-SEC-ARG,. VSLLOG = first v→v composition (reuses VSLFS, no DBS re-bind), audit line via $$now^STDDATE, maps VSLFS DIERR → ,U-VSL-LOG-WRITE,. Lane A NO-OP (no MSL seam change; pin stays v0.9.0).
metadata:
  type: project
---

# VSL T-M4 — VSLSEC (security/authz S5) + VSLLOG (audit sink S3), 2026-06-16

The security + audit seams. Branch `m4-vslsec-vsllog` off `main` (M3 merged).
4th + 5th `VSL*` modules (after VSLCFG, VSLIO, VSLFS). **Dual-engine GREEN 11/11**
(VSLSEC 6 + VSLLOG 5) on `vehu` (YDB) + `foia-t12` (IRIS); full v-stdlib suite
**33/33** on vehu (no regression).

## Lane A was a NO-OP — no MSL seam change (the key design call)
M4 needed **no** new/changed MSL seam, so m-stdlib was untouched and **no
`v0.10.0` tag** was cut; `dist/msl-seam-pin.json` stays **`v0.9.0`**. Why:
- **VSLSEC is authz-only — it has no portable MSL counterpart.** The
  authorization decision (does DUZ hold a key / a context) cannot run on a bare
  engine, so there is nothing to put below the waterline (architecture §3.4:
  "portable token crypto stays in STD*; the VistA authorization decision lives
  in VSL"). Portable crypto already lives in `STDCRYPTO`.
- **STDLOG's sink** is process-local (stderr/global); VSLLOG does NOT hook it —
  it's an independent VistA audit-record writer. No STDLOG `@seam` was added.

## GROUNDED: there is NO portable Kernel generic-hash entry point (so VSLSEC binds none)
Resolved Q1 by probing both live engines through the driver stack:
- **`$$SHAHASH^XUSHSH(bits,str)`** (SHA hex, XU*8.0*655) is **ABSENT on vehu**
  (older FOIA) → ZLINK FILENOTFND; present on IRIS.
- **Classic top-level `^XUSHSH`** (X in/out) returns a **CONSTANT** on BOTH
  engines (probe: "distinct inputs distinct" assertion failed on both) — it is
  NOT a usable generic string hash.
So VSLSEC binds **no** Kernel hash; a consumer needing a digest calls
`STDCRYPTO` (libcrypto on YDB / `$SYSTEM.Encryption` on IRIS, dual-engine
proven). Do NOT re-open "wire a Kernel hash into VSLSEC" — it's a dead end.

## VSLSEC — the VistA authorization decision (3 bindings, all VistA-only)
- `$$hasKey^VSLSEC(key,duz)` → `''$D(^XUSEC(key,duz))`. The security-key
  decision. **A DENY is a normal `0`, NOT an error** (kickoff decision 4). `duz`
  defaults to `+$G(DUZ)` via `$$pduz`.
- `$$duz^VSLSEC()` → `+$G(DUZ)` — the ambient principal (the #200 IEN binding).
- `$$user^VSLSEC(duz)` → `$$get^VSLFS(200,duz_",",".01","")` — the principal→#200
  NAME, **reusing VSLFS** (v→v; no DBS re-bind).
- **Loud path = a malformed call:** `$$hasKey("")` → clean **`,U-VSL-SEC-ARG,`**
  `$ECODE` + detail in `^TMP($job,"vslsec","err")` (`$$lastError`). (Decision 4:
  "a malformed call or a Kernel fault is loud; a DENY is not.")
- **ICR:** `^XUSEC` is the documented **Supported reference** ("check the ^XUSEC
  global … do not reference SECURITY KEY #19.1" — Kernel DG Security Keys), no
  numeric DBIA in the corpus → tagged **notional** `@icr notional @call ^XUSEC
  @status Supported @custodian XU @source XU/krn_8_0_dg_security_keys_ug#key-lookup`.
  A `$D` **read** (not a set/kill), so the no-direct-global rule (writes only) is
  satisfied; the REF_RE scan still requires the declaration, which it has.

## VSLLOG — the first v→v composition (reuses VSLFS; no DBS re-bind)
- `$$write^VSLLOG(file,event,detail)` → `line=$$now^STDDATE()_" "_event_" "_detail`
  then `$$set^VSLFS(file,"+1,",".01",line)` → resolved IENS. Timestamp from
  `$$now^STDDATE` (portable, **v→m** call up). Value-add = the log-record→.01
  mapping + the loud error map.
- `$$read^VSLLOG(file,iens)` → `$$get^VSLFS(file,iens,".01","")`.
- **Loud map:** a VSLFS `,U-VSL-FS-DIERR,` is caught (flag-based `$ETRAP`, see
  gotcha) and re-raised as **`,U-VSL-LOG-WRITE,`** with the VSLFS detail in
  `^TMP($job,"vsllog","err")`.
- **No `@icr` in VSLLOG** — it makes NO direct L4 call (DIQ/DIE are inside
  VSLFS; STDDATE is `m`-layer). v→v + v→m is invisible to the ICR/no-direct-global
  gate, correct by construction. `m arch check` is happy with VSL*→VSL*.

## GOTCHA — `zgoto`-based `$ETRAP` aborts the resident harness (0/0)
First VSLLOG.write used the STDJSON idiom `set $etrap="set $ecode="""" zgoto
"_lvl_":writeFault"` — the suite **aborted 0/0 with NO diagnostic** (the
"unattributable rc=1" class in m-stdlib discoveries.md). Fix = the **flag-based
`$ETRAP`** (STDCSPRNG pattern), no zgoto:
```
new $etrap,iens,line,ok set ok=1
set $etrap="set ok=0,$ecode="""" quit"
set line=… set iens=$$set^VSLFS(…)
if ok quit iens
set $etrap="" do raiseWrite quit ""    ; clear OUR trap before re-raising
```
Must `set $etrap=""` before re-raising or write's own trap swallows the mapped
error. Keep ≤3 commands/line (M-MOD-009 — the Go `m --check` reds on any finding,
incl. *style*; same lesson as VSLFS's stashDierr).

## Test fixtures — EXISTING low-risk entries, probed read-only (Q3)
- **VSLSEC:** an existing `^XUSEC(key,duz)` pair found via `$O` (test ground
  truth) → assert `$$hasKey=1`; a bogus key → assert `0`. `#200` IEN 1 (the
  postmaster) for `$$user`. No keys granted/revoked; no users altered.
- **VSLLOG:** the same **#8989.51** free-text `.01` file VSLFS uses (uppercased,
  no other required fields) → a ZZ throwaway audit record, created + killed via
  VSLFS. Round-trip asserts the read-back **contains** event+detail (the
  timestamp is generated, and #8989.51 uppercases, so not byte-predictable).
  DD-install of a dedicated audit file stays the deferred v-pkg track.

## Gates (all green) + engine recipe
`make check-fast`: fmt/lint (0 findings) + `m arch check .` (layer v) +
check-seams (0 — both are consumers) + **check-icr (9: VSLCFG 2 + VSLIO 2 +
VSLFS 4 + VSLSEC 1)** + **check-citations (9 vs gold corpus — the new
`XU/krn_8_0_dg_security_keys_ug#key-lookup` verified)** + check-namespaces
(**5 routines**) + check-msl-pin (**v0.9.0**, unchanged) + check-engine-access.
Recipe (driver stack ONLY): `m test --engine ydb --docker vehu --chset m
--routines src --routines <m-stdlib>/src tests/VSLSECTST.m tests/VSLLOGTST.m`
(IRIS: `--engine iris --docker foia-t12 --namespace VISTA`).

## Owed / next
- **Optional MailMan alert** (kickoff "+optional") deliberately OMITTED —
  `SETUP^XQALERT` (ICR 10081, Supported) / `EN^XMB` (DBIA 10069) send a REAL
  alert/bulletin to a user (a side effect); deferred, not green-gating.
- **Context-option authz** (`$$inContext` via `CRCONTXT^XWBSEC`, ICR 4053,
  Controlled Subscription) deferred: it needs the **encrypted** B-type option
  name and sets context (side-effecting) — too fragile for a safe read-only
  probe. hasKey covers the authz-decision milestone. Next consumer can add it.
- **Next: M5** (VSLBLD/VSLTASK — KIDS build + TaskMan listener, §12.2) + the
  §6.2 worked examples (S3 log egress, FHIR façade).
Companion to [[m3-vslfs]] (VSLLOG reuses its DBS binding) + [[m2-vslio]] (adapter
rhythm) + shared [[notional-dbia-not-a-blocker]].
