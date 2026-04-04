#!/usr/bin/env bash
# ecological-agent-skills — SKILL.md linter
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Validates that every SKILL.md follows the canonical structure:
#   - Frontmatter fields: name, description, skill_version
#   - Required h2 sections: Purpose, When to Invoke, Inputs, Outputs,
#     Steps, Decision Points, Tools and Libraries, Resources, Notes
#
# Usage: bash tests/lint_skill_md.sh
# Exit code: 0 if all pass, 1 if any fail

set -euo pipefail

REQUIRED_FRONTMATTER=("name" "description" "skill_version")
REQUIRED_SECTIONS=(
  "## Purpose"
  "## When to Invoke"
  "## Inputs"
  "## Outputs"
  "## Steps"
  "## Decision Points"
  "## Tools and Libraries"
  "## Resources"
  "## Notes"
)

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

  # ── Section checks ──────────────────────────────────────────────────────
  for section in "${REQUIRED_SECTIONS[@]}"; do
    if grep -qF "$section" "$skill_md" 2>/dev/null; then
      pass_count=$((pass_count + 1))
    else
      fail_count=$((fail_count + 1))
      errors+=("[FAIL] $skill_name: section '$section' missing")
    fi
  done
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
