#!/usr/bin/env bash
# ecological-agent-skills — Environment verification harness
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Functional smoke test for the geospatial stack. Runs before the unit
# test suite to catch GDAL/GEOS/PROJ misconfiguration that otherwise
# surfaces as confusing errors deep inside `terra::project()` or
# `rasterio.warp.reproject()`.
#
# What it does:
#   1. System-library check        (setup/check_system_deps.sh, warn-only)
#   2. Python smoke test           (tests/verify_env.py, mandatory if python present)
#   3. R smoke test                (tests/verify_env.R,  mandatory if Rscript present)
#
# Exit codes:
#   0 — all available checks passed
#   1 — at least one functional check failed
#   2 — unable to run any smoke test (no python or R found)
#
# Runs cleanly on DevContainer, WSL2 (Ubuntu), macOS, and Git Bash/Windows.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  GREEN='\033[32m'; RED='\033[31m'; YELLOW='\033[33m'; BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; BOLD=''; RESET=''
fi

banner() {
  printf "\n${BOLD}=== %s ===${RESET}\n" "$1"
}

PY_RAN=0; PY_OK=0
R_RAN=0;  R_OK=0
SYS_RAN=0

# ── 1. System libraries (warn-only) ────────────────────────────────────────────
banner "System libraries"
if [[ -x "setup/check_system_deps.sh" || -f "setup/check_system_deps.sh" ]]; then
  SYS_RAN=1
  if bash setup/check_system_deps.sh; then
    printf "${GREEN}System dependencies OK${RESET}\n"
  else
    printf "${YELLOW}System-deps check reported missing items — see above.${RESET}\n"
    printf "${YELLOW}Continuing: Python/R wheels sometimes ship the libs themselves.${RESET}\n"
  fi
else
  printf "${YELLOW}setup/check_system_deps.sh not found — skipping.${RESET}\n"
fi

# ── 2. Python smoke test ──────────────────────────────────────────────────────
banner "Python smoke test"
PYTHON_CMD=""
for cmd in python3 python py; do
  if command -v "$cmd" &>/dev/null && "$cmd" -c "import sys" &>/dev/null; then
    PYTHON_CMD="$cmd"
    break
  fi
done
if [[ -n "$PYTHON_CMD" ]]; then
  PY_RAN=1
  if "$PYTHON_CMD" tests/verify_env.py; then
    PY_OK=1
  fi
else
  printf "${YELLOW}No Python interpreter found — Python checks skipped.${RESET}\n"
fi

# ── 3. R smoke test ───────────────────────────────────────────────────────────
banner "R smoke test"
if command -v Rscript &>/dev/null; then
  R_RAN=1
  if Rscript tests/verify_env.R; then
    R_OK=1
  fi
else
  printf "${YELLOW}Rscript not found — R checks skipped.${RESET}\n"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
banner "verify-env summary"
printf "  System libs    : %s\n" "$([[ $SYS_RAN -eq 1 ]] && echo 'ran (warn-only)' || echo 'skipped')"
printf "  Python smoke   : %s\n" "$([[ $PY_RAN -eq 0 ]] && echo 'skipped' || ([[ $PY_OK -eq 1 ]] && printf 'PASS' || printf 'FAIL'))"
printf "  R smoke        : %s\n" "$([[ $R_RAN -eq 0 ]] && echo 'skipped' || ([[ $R_OK -eq 1 ]] && printf 'PASS' || printf 'FAIL'))"
printf "\n"

if [[ $PY_RAN -eq 0 && $R_RAN -eq 0 ]]; then
  printf "${RED}No interpreters available — nothing to verify.${RESET}\n"
  exit 2
fi
if [[ $PY_RAN -eq 1 && $PY_OK -eq 0 ]] || [[ $R_RAN -eq 1 && $R_OK -eq 0 ]]; then
  printf "${RED}Environment verification FAILED.${RESET}\n"
  exit 1
fi

printf "${GREEN}Environment verification PASSED.${RESET}\n"
exit 0
