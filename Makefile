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

.PHONY: all check fmt fmt-check lint arch test coverage clean

all: check

# fmt style is driven by .m-cli.toml ([fmt] rules = "pythonic-lower").
fmt:
	$(M) fmt --write $(SRC) $(TESTS)

fmt-check:
	$(M) fmt --check $(SRC) $(TESTS)

lint:
	$(M) lint --check $(SRC) $(TESTS)

# m/v waterline G1 gate (dependency-direction). v-stdlib is layer v
# (dist/repo.meta.json); it passes G1 trivially (v -> m is allowed) but must
# declare its layer so the gate runs everywhere with no exception.
arch:
	$(M) arch check .

# Engine-bound: stage STDASSERT (+ harness) from m-stdlib so VSL*TST suites
# resolve ^STDASSERT. Pass --engine ydb|iris and --docker <container>.
test:
	$(M) test $(ENGINE_FLAGS) --routines $(MSTDLIB)/src $(TESTS)

coverage:
	$(M) coverage $(ENGINE_FLAGS) --routines $(MSTDLIB)/src --min-percent=85 $(SRC) $(TESTS)

# Engine-free gates (fmt/lint/arch) + the engine-bound suite. CI runs the full
# set; `make check-fast` (fmt-check lint arch) needs no engine.
check: fmt-check lint arch test

.PHONY: check-fast
check-fast: fmt-check lint arch

clean:
	rm -f test-results.tap *.lcov coverage.out
