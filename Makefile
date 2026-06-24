# v-stdlib — VistA Standard Library (VSL* routines). Layer: v (VistA-specific;
# consumes the engine-neutral STD* base upward, per the m/v waterline).
#
# The `m` toolchain binary is built in the sibling m-cli repo; override M if
# your checkout lives elsewhere or `m` is on PATH (M=m).
M       ?= $(HOME)/vista-cloud-dev/m-cli/dist/m
SRC     := src
TESTS   := tests
# STDASSERT/STDHARN live in m-stdlib and are staged for engine-bound tests.
MSTDLIB ?= $(HOME)/vista-cloud-dev/m-stdlib
# v-pkg — the host tool that builds the VSL KIDS base from kids/vsl.build.json
# (VSL T1.3). Defaults to the sibling checkout's standalone binary; override
# with `make kids VPKG=/path/to/v-pkg`.
VPKG ?= $(HOME)/vista-cloud-dev/v-pkg/dist/v-pkg

# Engine selection for the engine-bound targets (test/coverage):
#   make test ENGINE=ydb  DOCKER=m-test-engine
#   make test ENGINE=iris DOCKER=m-test-iris
ENGINE ?=
DOCKER ?=
# Byte (M) charset by default: v-stdlib consumes byte-oriented m-stdlib modules
# (STDCRYPTO/STDB64/STDJSON assume one M char == one byte), so the engine runs in
# byte mode (the org rule m-stdlib also follows). YDB exports ydb_chset=M; IRIS
# treats --chset as a no-op. Override with CHSET= to disable.
CHSET  ?= m
ENGINE_FLAGS := $(if $(ENGINE),--engine $(ENGINE)) $(if $(DOCKER),--docker $(DOCKER)) $(if $(CHSET),--chset $(CHSET))

# Bare-engine-green suites — the traffic-tap + S3 + auth tier, which run on a
# plain M engine with NO VistA (no Kernel/FileMan). These are the engine-bound
# CI gate (`make ci`). The VistA-dependent suites (VSLBLD/VSLCFG/VSLFS/VSLIO/
# VSLLOG/VSLTASK — they need #-files + Kernel APIs and report 0/0 on a bare
# engine) are NOT here; run them via `make test` on a VistA-equipped engine.
# VSLS3E2ETST is the live round-trip — it runs in `make test-s3-matrix`, not here.
BARE_TESTS := tests/VSLSMOKETST.m tests/VSLSECTST.m \
              tests/VSLTAPTST.m tests/VSLRPCTAPTST.m tests/VSLTAPFENCETST.m \
              tests/VSLTAPHLTST.m tests/VSLTAPFCTST.m tests/VSLTAPBENCHTST.m \
              tests/VSLTAPV2TST.m tests/VSLRPCWRAPTST.m \
              tests/VSLTAPBOTST.m tests/VSLTAPRUNTST.m \
              tests/VSLHL7TAPTST.m tests/VSLS3TST.m tests/VSLS3DRAINTST.m

# The MinIO testbed for the live round-trip (vendored — see scripts/s3-testbed.sh).
S3_TESTBED := scripts/s3-testbed.sh

.PHONY: all check fmt fmt-check lint arch test test-bare test-s3 test-s3-matrix coverage clean \
        seams check-seams icr check-icr check-citations namespaces check-namespaces \
        pin check-msl-pin check-engine-access kids check-kids gates \
        manifest manifest-check manifest-golden frontmatter skill skill-check skill-install \
        docs-check docs-bodies docs-bodies-check check-frontmatter examples examples-check examples-coverage

all: check

# fmt style is driven by .m-cli.toml ([fmt] rules = "pythonic-lower").
fmt:
	$(M) fmt --write $(SRC) $(TESTS)

fmt-check:
	$(M) fmt --check $(SRC) $(TESTS)

# House lint gate: zero ERROR-severity findings (style/warning advisory), via
# scripts/m-lint-gate.sh — the Go `m` has no `--error-on=<severity>` flag and
# `--check` reds on ANY finding. Matches m-stdlib's gate (the global house rule).
lint:
	M=$(M) scripts/m-lint-gate.sh $(SRC) $(TESTS)

# m/v waterline gates. v-stdlib is layer v (root repo.meta.json); it passes
# G1/G2 trivially (v -> m, and VistA above the line, are allowed) but must
# declare its layer so the gates run everywhere with no exception.
arch:
	$(M) arch check .

# Engine-bound: stage STDASSERT (+ harness) from m-stdlib so VSL*TST suites
# resolve ^STDASSERT. Pass --engine ydb|iris and --docker <container>.
# NOTE: the integration harness tests/VSLS3E2ETST.m needs a live MinIO sink +
# engine HTTP egress — run it via `make test-s3`, not here (carved, like
# m-stdlib's STDS3MINIOTST).
test:
	$(M) test $(ENGINE_FLAGS) --routines $(SRC) --routines $(MSTDLIB)/src $(TESTS)

# Engine-bound but VistA-FREE: the bare-engine-green suite set ($(BARE_TESTS)) —
# the traffic-tap + S3 + auth tier. Green on a plain m-test-engine / m-test-iris
# with no VistA. This is what `make ci` runs per engine.
test-bare:
	$(M) test $(ENGINE_FLAGS) --routines $(SRC) --routines $(MSTDLIB)/src $(BARE_TESTS)

# Integration: the end-to-end round-trip fidelity harness (spec §15.2) against a
# LIVE S3-equivalent (MinIO/LocalStack). NOT in `make test`/`make ci` — it needs
# engine HTTP egress (G-HTTP-YDB: bake stdhttp.so+libcurl into m-test-engine;
# G-HTTP-IRIS-GET: STDHTTP %Net signed-bodyless-GET fix). Bring up the m-stdlib
# s3-testbed MinIO first (shared docker network, host m-s3-minio:9000), e.g.
#   ( cd $(MSTDLIB) && scripts/s3-testbed.sh up )
# then: make test-s3 ENGINE=iris DOCKER=m-test-iris
test-s3:
	$(M) test $(ENGINE_FLAGS) --routines $(SRC) --routines $(MSTDLIB)/src tests/VSLS3E2ETST.m

# The Option-A round-trip MATRIX gate (spec §15.2, plan stage 3.4): the live
# byte-exact harness VSLS3E2ETST run against MinIO on BOTH engines (the A ×
# {YDB,IRIS} matrix). Self-contained — stands up the MinIO testbed, runs each
# engine, and tears it down on the way out (trap, even on failure). A HARD gate:
# fails if either engine's corpus→tap→drain→ship→read-back→reconcile is not
# byte-exact. Part of `make ci`. Needs docker (MinIO + the two test engines).
test-s3-matrix:
	@rc=0; \
	trap '$(S3_TESTBED) down' EXIT; \
	$(S3_TESTBED) up || exit 1; \
	echo "── Option A round-trip · YDB ──"; \
	$(M) test --engine ydb  --docker m-test-engine --chset m --routines $(SRC) --routines $(MSTDLIB)/src tests/VSLS3E2ETST.m || rc=1; \
	echo "── Option A round-trip · IRIS ──"; \
	$(M) test --engine iris --docker m-test-iris            --routines $(SRC) --routines $(MSTDLIB)/src tests/VSLS3E2ETST.m || rc=1; \
	exit $$rc

coverage:
	$(M) coverage $(ENGINE_FLAGS) --routines $(MSTDLIB)/src --min-percent=85 $(SRC) $(TESTS)

# ── VSL T0b.3 drift gates (registry-driven; pure Python, engine-free) ──
# The same four `source-tag → generate → registry → red-gate` gates m-stdlib
# carries, mirrored here for the VSL* tier (coordination plan §5.2/§5.4/§5.5/§9):
#   seams      — @seam → dist/seam-snapshot.json + git-HEAD bump-forcer
#   icr        — @icr  → dist/icr-registry.json + DBIA/no-direct-global gate
#   citations  — @source cited doc_keys vs the vdocs gold corpus (SKIP if absent)
#   namespaces — repo.meta.json prefixes vs discovered VSL* routines/globals
# All green on the (currently empty) VSL* source; they go red on a planted
# violation, so the contract machinery is in place before VSLCFG (M1) lands.
seams:
	python3 tools/seam_contract.py --write

check-seams:
	@python3 tools/seam_contract.py --check

icr:
	python3 tools/gen-icr.py --write

check-icr:
	@python3 tools/gen-icr.py --check

check-citations:
	@python3 tools/check_citations.py --check

namespaces:
	python3 tools/gen_namespace_registry.py --write

check-namespaces:
	@python3 tools/gen_namespace_registry.py --check

# ── VSL T0b.4: the cross-repo MSL seam-contract pin (v -> m) ──
# v-stdlib pins the frozen MSL seam contract it built against (a git tag in
# m-stdlib) and asserts it has not drifted (coordination plan §5.2/§6). `pin`
# syncs dist/msl-seam-pin.json from the sibling MSL @ msl_ref; `check-msl-pin`
# is the gate — well-formedness + drift, SKIP-green when MSL is unreachable
# (override the checkout with MSTDLIB=...). The network fetch-at-tag path is
# the T1.1 extension.
pin:
	python3 tools/msl_seam_pin.py --write

check-msl-pin:
	@python3 tools/msl_seam_pin.py --check

# Transport-monopoly gate: no committed test/script/Makefile may hand-roll engine
# access (raw docker-exec into an engine, iris-session, gtm-dist, etc.). All
# engine work goes through the m-driver-sdk -> m-ydb/m-iris stack (`m test
# --docker`, `m vista exec`). The committed-artifact backstop to the PreToolUse
# engine-stack-guard hook. Org CLAUDE.md §"m/v waterline" -> "Engine access".
check-engine-access:
	@python3 tools/check_engine_access.py --check

# ── VSL T1.3: the VSL KIDS base build (drift-gated artifact) ──────────
# kids/vsl.build.json declares the VSL layer as an installable KIDS build:
# the VSLCFG routine + the VPNG GREETING #8989.51 PARAMETER DEFINITION (SYS)
# + a Required Build on the MSL base (MSL*0.1*1). `make kids` builds the
# deterministic, normalized .KID via v-pkg; `make check-kids` re-gates it —
# a fresh rebuild must be byte-identical (deterministic-build invariant) AND
# match the committed dist/kids/VSL.kids (drift gate), same discipline as
# m-stdlib's check-kids. Engine-free — needs only the v-pkg binary. SKIP-green
# when v-pkg is absent (mirrors check-citations) so CI without it stays green.
kids:
	$(VPKG) build kids/vsl.build.json --src $(SRC) --out dist/kids/VSL.kids

check-kids:
	@if [ ! -x "$(VPKG)" ]; then \
	  echo "check-kids: v-pkg not found at $(VPKG) — SKIP (build it in v-pkg or set VPKG=…)"; \
	  exit 0; \
	fi
	@tmp=$$(mktemp); \
	$(VPKG) build kids/vsl.build.json --src $(SRC) --out $$tmp >/dev/null; \
	if diff -q $$tmp dist/kids/VSL.kids >/dev/null 2>&1; then \
	  echo "check-kids: dist/kids/VSL.kids matches a fresh deterministic build ✓"; \
	  rm -f $$tmp; \
	else \
	  echo "ERROR: dist/kids/VSL.kids drifted from kids/vsl.build.json + src/ — run 'make kids' and commit" >&2; \
	  rm -f $$tmp; exit 1; \
	fi

# ── Stdlib documentation pipeline (engine-free; mirrors m-stdlib) ──────
# The discoverability half of the org's source-tag → generate → registry →
# red-gate discipline, activated for the VSL* tier (stdlib-docs Phase 1 / AC1).
# Pure python3, no engine — it reads `.m` source text only. Keep the
# generators maintained siblings of m-stdlib's (risk R-DRIFT); fold structural
# improvements across both rather than letting them fork.
#   manifest         VSL* `; doc:` tags → dist/vsl-manifest.json + dist/errors.json
#   manifest-check   drift gate: regenerate + git-diff the two artifacts
#   manifest-golden  parser golden-file regression (tools/fixtures/VSLGOLD.m)
#   frontmatter      docs/modules/<module>.md stubs + index.md (idempotent)
#   skill            dist/skill/{SKILL,manifest-index,patterns,error-codes}.md
#   skill-check      drift gate for dist/skill/
#   skill-install    install dist/skill/ to ~/claude/skills/v-stdlib/
manifest:
	python3 tools/gen-manifest.py

manifest-check: manifest
	@git diff --exit-code -- dist/vsl-manifest.json \
		|| { echo "ERROR: dist/vsl-manifest.json out of date — run 'make manifest' and commit."; exit 1; }
	@git diff --exit-code -- dist/errors.json \
		|| { echo "ERROR: dist/errors.json out of date — run 'make manifest' and commit."; exit 1; }
	@echo "manifest: clean"

manifest-golden:
	@python3 tools/test-manifest-golden.py --check

frontmatter:
	python3 tools/write-module-frontmatter.py

skill:
	python3 tools/gen-skill.py

skill-check:
	@python3 tools/gen-skill.py --check \
		|| { echo "ERROR: dist/skill/ is out of date — run 'make skill' and commit."; exit 1; }
	@echo "skill: clean"

skill-install: skill
	@mkdir -p $(HOME)/claude/skills/v-stdlib
	cp -f dist/skill/SKILL.md $(HOME)/claude/skills/v-stdlib/SKILL.md
	cp -f dist/skill/manifest-index.md $(HOME)/claude/skills/v-stdlib/manifest-index.md
	cp -f dist/skill/patterns.md $(HOME)/claude/skills/v-stdlib/patterns.md
	cp -f dist/skill/error-codes.md $(HOME)/claude/skills/v-stdlib/error-codes.md
	@echo "skill installed at $(HOME)/claude/skills/v-stdlib/"

# docs-check (stdlib-docs Phase 2 / AC2): the completeness gate — red when any
# src/VSL*.m module lacks a manifest entry OR a docs/modules/<module>.md page.
# Engine-free; the same gate m-stdlib runs (one maintained sibling). It also
# runs org-wide via the reusable m-ci.yml (a guarded auto-step), so every M
# caller inherits it; listed here too for the local dev loop. Ships green in
# v-stdlib because Phase 1 generated all 17 stub pages.
docs-check:
	@python3 tools/check-docs.py --check

# docs-bodies (stdlib-docs Phase 4 / AC4): regenerate the delimited
# `## API reference` block on every docs/modules/<module>.md from the manifest
# (signatures/params/returns/raises/examples). The generator owns ONLY the text
# between its markers — hand prose is preserved on every regen (risk R-CLOBBER).
# `docs-bodies-check` is the drift gate: red when a `.m` signature edit hasn't
# been propagated to the page (run `make manifest docs-bodies` and commit).
# Byte-identical sibling of m-stdlib's gen-bodies.py.
docs-bodies:
	python3 tools/gen-bodies.py

docs-bodies-check:
	@python3 tools/gen-bodies.py --check

# check-frontmatter (Regime-B governance — docs-governance-two-regimes ADR): the
# generated module pages (docs/modules/) are machine output, excluded from the
# doc-framework prose validator and governed instead by their OWN robust schema,
# tools/reference-frontmatter.schema.json. This validates every page's frontmatter
# against it. Engine-free; byte-identical sibling of m-stdlib's check-frontmatter.py.
check-frontmatter:
	@python3 tools/check-frontmatter.py --check

# examples / examples-check (Living Executable Examples, E1 — docs proposal
# proposals/living-executable-examples.md): generated, self-verifying runnable
# example programs (examples/programs/<MOD>EX.m) + the living-doc index
# (examples/index.md), built from each module's @example tags. Engine-free.
# v-stdlib executable-example coverage starts at 0/117 — the index surfaces the
# gap; the backfill (mostly live-VistA, side-effect-safe) is E2-E3.
examples:
	python3 tools/gen-examples.py

examples-check:
	@python3 tools/gen-examples.py --check

# examples-coverage (Living Executable Examples, E2 — the comprehensiveness
# report): executable-example coverage = (executable @example OR @illustrative)/
# total labels, every @raises demonstrated by an error-example, every @fixture
# present + referenced. ADVISORY (exit 0); v-stdlib starts at 0/117 — the E3
# backfill (mostly live-VistA, side-effect-safe) is the long pole. Flip to red
# per-repo with --strict at 100% (proposal L5).
examples-coverage:
	@python3 tools/gen-examples.py --coverage

# Aggregate of the engine-free drift gates (the four own-tier gates + the
# upward MSL pin + the transport-monopoly gate + the KIDS-build drift gate +
# the doc-pipeline manifest/skill/golden gates).
gates: check-seams check-icr check-citations check-namespaces check-msl-pin check-engine-access check-kids \
       manifest-check manifest-golden skill-check docs-check docs-bodies-check check-frontmatter examples-check

# Engine-free gates (fmt/lint/arch + drift gates) + the engine-bound suite. CI
# runs the full set; `make check-fast` needs no engine.
check: fmt-check lint arch gates test

.PHONY: check-fast
check-fast: fmt-check lint arch gates

# CI entrypoint — self-contained, green on the bare test engines (no VistA). It
# runs the engine-free gates, then the bare-engine-green suite set on BOTH
# engines (incl. the VSLTAPBENCHTST 3-arm non-interference benchmark, spec
# §6.4/§7 D-7), then the Option-A round-trip MATRIX (VSLS3E2ETST × {YDB,IRIS}
# against MinIO, plan stage 3.4). The VistA-dependent functional suites
# (VSLCFG/VSLFS/VSLIO/VSLLOG/VSLBLD/VSLTASK) are NOT here — they need a real
# VistA; run the full set with `make check` on a VistA-equipped engine.
# Just `make ci` (no ENGINE= needed — it drives both test engines + MinIO).
.PHONY: ci
ci:
	$(MAKE) check-fast
	$(MAKE) test-bare ENGINE=ydb  DOCKER=m-test-engine
	$(MAKE) test-bare ENGINE=iris DOCKER=m-test-iris
	$(MAKE) test-s3-matrix

clean:
	rm -f test-results.tap *.lcov coverage.out
