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
