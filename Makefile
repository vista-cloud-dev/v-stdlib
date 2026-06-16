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

# Engine selection for the engine-bound targets (test/coverage):
#   make test ENGINE=ydb  DOCKER=m-test-engine
#   make test ENGINE=iris DOCKER=m-test-iris
ENGINE ?=
DOCKER ?=
ENGINE_FLAGS := $(if $(ENGINE),--engine $(ENGINE)) $(if $(DOCKER),--docker $(DOCKER))

.PHONY: all check fmt fmt-check lint arch test coverage clean \
        seams check-seams icr check-icr check-citations namespaces check-namespaces \
        pin check-msl-pin check-engine-access gates

all: check

# fmt style is driven by .m-cli.toml ([fmt] rules = "pythonic-lower").
fmt:
	$(M) fmt --write $(SRC) $(TESTS)

fmt-check:
	$(M) fmt --check $(SRC) $(TESTS)

lint:
	$(M) lint --check $(SRC) $(TESTS)

# m/v waterline gates. v-stdlib is layer v (root repo.meta.json); it passes
# G1/G2 trivially (v -> m, and VistA above the line, are allowed) but must
# declare its layer so the gates run everywhere with no exception.
arch:
	$(M) arch check .

# Engine-bound: stage STDASSERT (+ harness) from m-stdlib so VSL*TST suites
# resolve ^STDASSERT. Pass --engine ydb|iris and --docker <container>.
test:
	$(M) test $(ENGINE_FLAGS) --routines $(SRC) --routines $(MSTDLIB)/src $(TESTS)

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

# Aggregate of the engine-free drift gates (the four own-tier gates + the
# upward MSL pin + the transport-monopoly gate).
gates: check-seams check-icr check-citations check-namespaces check-msl-pin check-engine-access

# Engine-free gates (fmt/lint/arch + drift gates) + the engine-bound suite. CI
# runs the full set; `make check-fast` needs no engine.
check: fmt-check lint arch gates test

.PHONY: check-fast
check-fast: fmt-check lint arch gates

clean:
	rm -f test-results.tap *.lcov coverage.out
