---
name: vista-sysadmin-suite-proposal
description: PROPOSAL (draft 2026-06-27) — VSL* sysadmin engine modules + paired `v` CLI domains; gap analysis of the 6 current seam adapters vs VistA admin needs
metadata:
  type: project
---

PROPOSAL `docs/proposals/vista-sysadmin-suite.md` (DRAFT, 2026-06-27) — the first
proposal in v-stdlib (created `docs/proposals/`). Reframes v-stdlib's next growth:
the **6 current modules are SEAM ADAPTERS** (VSLCFG=XPAR/STDENV, VSLFS=FileMan-DBS,
VSLIO=device-handler TCP, VSLLOG=audit sink, VSLSEC=identity, VSLTASK=listener
lifecycle) — *plumbing for apps*, NOT administrator verticals. None of the ranked
top-15 VistA sysadmin tasks is a callable today.

**Core proposal:** a suite of ~8–10 new `VSL*` admin modules, each paired with a
plain-noun **Go `v` CLI domain**, split at the m/v waterline (Go reaches engine
ONLY via `mdriver.Client`; VistA knowledge stays in the VSL module; reuse VSLFS/
VSLSEC downward). Each vertical = one VSL module + one `v <domain>`.

**Sequenced by automatability (the load-bearing finding, gold-corpus-grounded):**
- **Tier 1 — API-backed spine, build first** (all Supported APIs, dual-engine
  testable): **VSLJOB** (TaskMan ops/`^%ZTLOAD` ICR 10063 → `v job`), **VSLALERT**
  (`XQALERT` DELETE=ICR 10081 → `v alert`), **VSLPARM** (full multi-entity XPAR/
  ICR 2263 → `v config`), **VSLKEY** (`^XUSEC` Supported ref + `$$RENAME^XPDKEY` →
  `v key`), **VSLERR** (`^%ZTER`/#3.075 + `^XTERPUR` → `v error`).
- **Tier 2 — FileMan-DBS wrappers, NO Supported API upstream** (reuse VSLFS):
  **VSLUSER** (#200 → `v user`), **VSLDEV** (#3.5 → `v device`), **VSLAUD** (sign-on
  log #3.081 `^XUSEC(0,` → `v audit`).
- **Tier 3 — monitors** (upstream partly interactive): **VSLHLO** (#870/HLO links,
  read-only; restart is interactive-only upstream → not exposed), **VSLSTAT**
  (who's-on/resource — ENGINE-SPECIFIC YDB vs IRIS, portability risk).

**Client surface (added 2026-06-27 rev 2):** each vertical carries a **Client
(primary)** column, assigned by a 6-axis rubric (§7.1: edit-complexity,
visualization, real-time, scriptability, mutation-risk+review, operator-context).
**Web-first** = `v user`/`v device` (form-heavy #200/#3.5 editors) + `v audit`/
`v hl7`/`v status` (compliance review / live dashboards). **CLI/TUI-first** = `v job`/
`v error` (incident-context) + `v config`/`v key`/`v alert` (scriptable). Rule:
mutation-heavy forms + visual/real-time monitors → Web; scriptable/incident ops →
CLI/TUI. **The host side is ONE registry-driven Go binary — busybox-style** (§7.2):
a single declarative `Registry []Vertical{Domain,Module,Tier,Client,Verbs[]}`
generates CLI + TUI + web (`v serve`, embedded SPA per the retired Admin-Web-Suite
pattern) — no separate web app, no per-vertical bespoke wiring. "Web" never means
"not scriptable" — every verb is CLI-reachable. **G-host gates** (tag→registry→
red-gate applied to host): G1 verb↔label vs `dist/vsl-manifest.json` (the waterline
contract across the 2 repos), G2 plain-noun lint, G3 mutate=confirm+VSLLOG-audit,
G4 single-surface (registry is the only declaration site). R-WEB: `v serve` needs
token-auth (M6.5 stack) + TLS (blocked on VSLIO `$$INIT^XUTLS`/ICR 7616) → web is
additive/loopback-only until then; CLI/TUI is the production path.

**Industry grounding (added 2026-06-27 rev 3, §11 — web-researched, 3 parallel
agents):** both VistA and **Epic** are single-integrated-MUMPS-DB EHRs (VistA on
GT.M/YottaDB/IRIS; Epic "Chronicles" on Caché→IRIS) administered as ONE unit (one
journal/backup/namespace/change-surface → system-wide blast radius). 8-group common
core with **(P)latform vs (A)pplication** split: the suite targets the **application**
core (interfaces/users-security-audit/batch fully; env/monitoring/patch partially)
and leaves **engine/infra** ops (journaling, freeze-thaw backups, IRIS mirroring/
YottaDB replication, integrity, ECP, buffer/capacity tuning) BELOW the waterline
(YottaDB MUPIP / IRIS Mgmt Portal / m-* + driver) — reinforces the m/v split.
Epic↔VistA analog table proves the verticals aren't VistA-parochial (TaskMan↔IRIS
Task Manager, ^XUSEC keys↔Epic security classes, ^%ZTER↔messages.log, XQALERT↔In
Basket, #3.081 audit↔Epic audit+Break-the-Glass, HLO↔Bridges/Interconnect-FHIR,
RUM↔System-Pulse/^mgstat). Daily reality = mundane/ticket-shaped (unlocks, resets,
printer issues, interface-queue triage, job/ETL babysitting, monitoring) → validates
Tier-1-spine-first + the client-type rubric. **Authoritative refs:** InterSystems
IRIS docs (journaling/WIJ/backup/mirroring/ECP/^mgstat/RBAC), YottaDB AdminOps
(MUPIP), VA VDL (Kernel SM/TaskMan/KIDS/Signon/HL7/RUM, Handbook 6500.8), HIPAA
45 CFR §164.308/.312; Epic via public corroboration (login-gated internally —
flagged [secondary]). Section is §11; TOC + numbering shifted Out-of-scope→§12,
References→§13 (23 anchors verified, gates green).

**Explicitly out of scope:** KIDS install (already `v pkg`/v-pkg); the RPC tap
(separate greenfield `v-rpc-tap`); read-only navigation/knowledge tools (those are
the **VistA-Copilot** org, not vista-cloud-dev — this suite *actuates a live engine*,
the accepted `v`-domain test, see [[v-cli-domain-eligibility]]).

**Key risks:** R-USER (#200 has NO Supported create/edit API — DBS wrapper must
honor the DD; read verbs first, mutations DD-validated + confirm + audit);
R-STAT (VSLSTAT portability — `$ZVERSION["IRIS"` arms, YDB first); R-HLO (no
Supported link-control API → read-only only). **Verify-before-Phase-1:** exact ICR
for `SETUP^XQALERT` (DELETE=10081 confirmed; SETUP Supported but ICR uncaptured) +
the precise #3.081 node map.

**Open Qs:** Go packaging — domains in existing `v-cli` (recommended) vs a separate
`v-admin` repo (the "separate repo with a Go CLI" the owner mentioned); keep VSLCFG
(app seam) alongside VSLPARM (admin). Gates green when added (docs-check 6/6,
check-frontmatter clean — both scoped to src modules / docs/modules, so the new
proposal doc is gate-safe). NOT BUILT — design only. Companion Go plan graduates to
the `v` CLI repo (one repo ↔ one session). See [[never-use-bespoke-installer]] for
the install contract.
