#!/usr/bin/env bash
# ecological-agent-skills — SKILL.md linter
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Validates that every SKILL.md follows the canonical structure:
#   - Frontmatter fields: name, description, skill_version
#   - Required h2 sections: see tests/allowed_headings.json (each group accepts
#     any declared synonym; the first entry is the canonical heading).
#
# Usage: bash tests/lint_skill_md.sh
# Exit code: 0 if all pass, 1 if any fail

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

HEADINGS_JSON="tests/allowed_headings.json"
REQUIRED_FRONTMATTER=("name" "description" "skill_version")

if [[ ! -f "$HEADINGS_JSON" ]]; then
  echo "ERROR: $HEADINGS_JSON not found" >&2
  exit 2
fi

PYTHON_CMD=""
for cmd in python3 python py; do
  if command -v "$cmd" &>/dev/null && "$cmd" -c "import sys" &>/dev/null; then
    PYTHON_CMD="$cmd"
    break
  fi
done
if [[ -z "$PYTHON_CMD" ]]; then
  echo "ERROR: No Python interpreter found (required to parse $HEADINGS_JSON)" >&2
  exit 2
fi

pass_count=0
fail_count=0
errors=()

for skill_md in skills/*/SKILL.md; do
  skill_name="$(basename "$(dirname "$skill_md")")"

  # ── Frontmatter checks ──────────────────────────────────────────────────
  for field in "${REQUIRED_FRONTMATTER[@]}"; do
    if grep -q "^${field}:" "$skill_md" 2>/dev/null; then
      pass_count=$((pass_count + 1))
    else
      fail_count=$((fail_count + 1))
      errors+=("[FAIL] $skill_name: frontmatter field '$field' missing")
    fi
  done

  # ── Section checks (one per group declared in allowed_headings.json) ────
  # The Python helper prints one line per group: "PASS <canonical>" or
  # "FAIL <canonical>: none of [syn1, syn2, ...] found".
  while IFS= read -r line; do
    case "$line" in
      "PASS "*)
        pass_count=$((pass_count + 1))
        ;;
      "FAIL "*)
        fail_count=$((fail_count + 1))
        errors+=("[FAIL] $skill_name: ${line#FAIL }")
        ;;
    esac
  done < <(
    "$PYTHON_CMD" - "$HEADINGS_JSON" "$skill_md" <<'PYEOF'
import json
import re
import sys

headings_path, skill_path = sys.argv[1], sys.argv[2]

with open(headings_path, encoding="utf-8") as f:
    groups = json.load(f)["sections"]

with open(skill_path, encoding="utf-8") as f:
    # Strip trailing whitespace; h2 detection is anchored to start of line.
    h2_lines = {
        line.rstrip()
        for line in f
        if line.startswith("## ")
    }

for canonical, synonyms in groups.items():
    hit = next(
        (s for s in synonyms if f"## {s}" in h2_lines),
        None,
    )
    if hit is not None:
        print(f"PASS {canonical}")
    else:
        print(f"FAIL section '{canonical}' missing: none of {synonyms} found")
PYEOF
  )
done

# ── Report ────────────────────────────────────────────────────────────────────
total=$((pass_count + fail_count))
echo "========================================="
echo " SKILL.md Lint Report"
echo " Checks: ${pass_count}/${total} passed"
echo "========================================="

if [ ${#errors[@]} -gt 0 ]; then
  echo ""
  echo " Failures:"
  for err in "${errors[@]}"; do
    echo "   $err"
  done
  echo ""
  echo " Status: FAIL"
  exit 1
else
  echo " Status: PASS — all SKILL.md files are valid"
  exit 0
fi
