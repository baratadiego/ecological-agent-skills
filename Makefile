# ecological-agent-skills — convenience Makefile
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Thin wrapper around bash test scripts. Nothing here is required to use
# the repo — every target just forwards to an existing script so Windows
# users without `make` can still run everything manually.
#
# Usage:
#   make verify-env        # geospatial stack smoke test (run first)
#   make test              # full test suite (CI + python + R + regression + lint)
#   make test-python       # pytest only
#   make test-r            # testthat only
#   make ci                # structural CI checks
#   make lint              # SKILL.md linter
#   make regression        # regression tests against reference outputs
#   make stats-check       # detect drift in docs/repository-statistics.md
#   make clean             # remove generated logs + temp files

SHELL         := bash
PYTHON        ?= python3
RSCRIPT       ?= Rscript
# Git Bash on Windows ships POSIX with a C locale that breaks grep -P.
# Force a UTF-8 locale for all targets.
export LC_ALL ?= C.UTF-8

.PHONY: help verify-env test test-python test-r ci lint regression \
        regression-update stats stats-check clean

help:
	@echo "Targets:"
	@echo "  verify-env        — functional geospatial smoke test (run this first)"
	@echo "  test              — full suite: ci + lint + python + regression (+ R if available)"
	@echo "  test-python       — pytest only"
	@echo "  test-r            — testthat only"
	@echo "  ci                — structural CI checks (tests/ci_check.sh)"
	@echo "  lint              — SKILL.md linter"
	@echo "  regression        — regression tests against reference outputs"
	@echo "  regression-update — regenerate regression reference outputs"
	@echo "  stats             — regenerate docs/repository-statistics.md"
	@echo "  stats-check       — verify the stats file is up to date"
	@echo "  clean             — remove generated logs and temp files"

verify-env:
	@bash tests/verify_env.sh

ci:
	@bash tests/ci_check.sh

lint:
	@bash tests/lint_skill_md.sh

regression:
	@bash tests/regression/run_regression_tests.sh

regression-update:
	@bash tests/regression/update_references.sh --confirm-update

stats:
	@bash tests/generate_stats.sh

stats-check:
	@bash tests/generate_stats.sh --check

test-python:
	@$(PYTHON) -m pytest tests/python/

test-r:
	@if command -v $(RSCRIPT) >/dev/null 2>&1; then \
	  $(RSCRIPT) tests/r/run_all_tests.R; \
	else \
	  echo "Rscript not found — skipping R tests"; \
	fi

test: verify-env ci lint test-python regression test-r
	@echo ""
	@echo "=== Full test suite complete ==="

clean:
	@rm -rf logs/ tests/regression/.tmp_current tests/regression/.tmp_update
	@find . -type d -name __pycache__ -prune -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "Cleaned logs, __pycache__, and temp test directories."
