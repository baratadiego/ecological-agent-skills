#!/usr/bin/env bash
# ecological-agent-skills — Auto-generate docs/repository-statistics.md
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Usage: bash tests/generate_stats.sh          # update docs/repository-statistics.md
#        bash tests/generate_stats.sh --check  # exit 1 if file is outdated
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

OUT="docs/repository-statistics.md"
CHECK_MODE=false
[[ "${1:-}" == "--check" ]] && CHECK_MODE=true

# ── Counts ────────────────────────────────────────────────────────────────────
SKILL_COUNT=$(find skills/ -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
WORKFLOW_COUNT=$(find workflows/ -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
R_SCRIPTS=$(find skills/*/scripts/ -name "*.R" -type f 2>/dev/null | wc -l | tr -d ' ')
PY_SCRIPTS=$(find skills/*/scripts/ -name "*.py" -type f 2>/dev/null | wc -l | tr -d ' ')
EXAMPLES=$(find examples/ -name "*_example.md" -type f 2>/dev/null | wc -l | tr -d ' ')
RESOURCES=$(find skills/*/resources/ -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
DOCS_COUNT=$(find docs/ -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
TEST_CSVS=$(find tests/data/ -name "*.csv" -type f 2>/dev/null | wc -l | tr -d ' ')
PY_TESTS=$(find tests/python/ -name "test_*.py" -type f 2>/dev/null | wc -l | tr -d ' ')
R_TESTS=$(find tests/r/ -name "test-*.R" -type f 2>/dev/null | wc -l | tr -d ' ')
SMOKE_CASES=$(python3 -c "import json; print(len(json.load(open('tests/agent_smoke/smoke_test_cases.json'))['cases']))" 2>/dev/null || echo "?")

# CI checks (run ci_check.sh to get count)
CI_CHECKS="?"
if command -v bash >/dev/null 2>&1; then
  CI_LINE=$(bash tests/ci_check.sh 2>/dev/null | grep "Structure checks:" || true)
  if [[ -n "$CI_LINE" ]]; then
    CI_CHECKS=$(echo "$CI_LINE" | grep -oP '\d+/\d+' | head -1)
  fi
fi

# Version from CHANGELOG
VERSION=$(grep -m1 '^\## \[' CHANGELOG.md 2>/dev/null | sed 's/.*\[\(.*\)\].*/\1/' || echo "unknown")
TODAY=$(date '+%Y-%m-%d')

# ── Skill phases ──────────────────────────────────────────────────────────────
PHASE1="ecological-data-foundation, geoprocessing-for-ecology, biostatistics-workbench, predictive-modeling-best-practices, reproducible-ecology-pipeline"
PHASE2="model-validation-and-uncertainty, species-distribution-modeling, ecological-impact-assessment, environmental-time-series"
PHASE3="occupancy-and-detection, community-ecology-ordination, ecosystem-services-assessment"
PHASE4="camera-trap-processing, acoustic-monitoring, landscape-connectivity, population-viability-analysis, spatial-prioritization"

# ── Generate ──────────────────────────────────────────────────────────────────
GENERATED=$(cat <<STATS
# Repository Statistics

Generated: ${TODAY}
Version: ${VERSION}

---

## Content Summary

| Category | Count |
|----------|-------|
| Skills | ${SKILL_COUNT} |
| Workflows | ${WORKFLOW_COUNT} |
| R scripts | ${R_SCRIPTS} |
| Python scripts | ${PY_SCRIPTS} |
| Worked examples | ${EXAMPLES} |
| Resource documents | ${RESOURCES} |
| Documentation files (docs/) | ${DOCS_COUNT} |
| Test datasets (CSV) | ${TEST_CSVS} |

## Skill Breakdown

| Phase | Skills | Count |
|-------|--------|-------|
| Phase 1 (Foundation) | ${PHASE1} | 5 |
| Phase 2 (Modeling) | ${PHASE2} | 4 |
| Phase 3 (Specialist) | ${PHASE3} | 3 |
| Phase 4 (Advanced) | ${PHASE4} | 5 |

## CI Check Results

| Section | Checks |
|---------|--------|
| Structure checks | ${CI_CHECKS} passed |
| Skills verified | ${SKILL_COUNT} |
| Workflows verified | ${WORKFLOW_COUNT} |

## Test Suite

| Test type | Count |
|-----------|-------|
| CI structural checks | ${CI_CHECKS%%/*} |
| Python unit tests (pytest) | ${PY_TESTS} files |
| R unit tests (testthat) | ${R_TESTS} files |
| Agent smoke test cases | ${SMOKE_CASES} |
STATS
)

if $CHECK_MODE; then
  # Compare generated content summary section with existing
  CURRENT_R=$(grep "| R scripts |" "$OUT" 2>/dev/null | grep -oP '\d+' || echo "0")
  CURRENT_PY=$(grep "| Python scripts |" "$OUT" 2>/dev/null | grep -oP '\d+' || echo "0")
  if [[ "$CURRENT_R" != "$R_SCRIPTS" ]] || [[ "$CURRENT_PY" != "$PY_SCRIPTS" ]]; then
    echo "DRIFT DETECTED: docs/repository-statistics.md is outdated"
    echo "  R scripts: file says ${CURRENT_R}, actual ${R_SCRIPTS}"
    echo "  Python scripts: file says ${CURRENT_PY}, actual ${PY_SCRIPTS}"
    echo "Run: bash tests/generate_stats.sh"
    exit 1
  fi
  echo "docs/repository-statistics.md is up to date"
  exit 0
else
  echo "$GENERATED" > "$OUT"
  echo "Updated: $OUT"
fi
