#!/usr/bin/env bash
# ci_check.sh — Structural integrity check for ecological-agent-skills repository
# Usage: bash tests/ci_check.sh
# Run from the repository root directory.
# Exit code 0 = all checks passed. Exit code 1 = one or more checks failed.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PASS=0
FAIL=0
FAILED_CHECKS=()

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); FAILED_CHECKS+=("$1"); }

echo "========================================"
echo " ecological-agent-skills CI CHECK"
echo " Repository: $REPO_ROOT"
echo "========================================"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1 — Required root-level files
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Section 1: Required root files ---"

ROOT_FILES=(
  "README.md"
  "CATALOG.md"
  "CHANGELOG.md"
  "CONTRIBUTING.md"
  "AGENT_CONTEXT.md"
  "renv.lock"
  "environment.yaml"
  "skills/SKILL_INDEX.json"
)

for f in "${ROOT_FILES[@]}"; do
  if [[ -f "$f" ]]; then
    pass "Root file exists: $f"
  else
    fail "Root file missing: $f"
  fi
done

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2 — Skill directory structure
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Section 2: Skill directory structure ---"

SKILL_COUNT=0
for skill_dir in skills/*/; do
  [[ "$skill_dir" == "skills/*/" ]] && continue
  skill_name=$(basename "$skill_dir")

  # Skip non-directories and SKILL_INDEX.json
  [[ -d "$skill_dir" ]] || continue

  SKILL_COUNT=$((SKILL_COUNT + 1))

  # SKILL.md
  if [[ -f "${skill_dir}SKILL.md" ]]; then
    pass "Skill $skill_name: SKILL.md exists"
  else
    fail "Skill $skill_name: SKILL.md missing"
  fi

  # resources/ with at least 1 file
  if [[ -d "${skill_dir}resources" ]] && [[ $(ls -1 "${skill_dir}resources/" 2>/dev/null | wc -l) -ge 1 ]]; then
    pass "Skill $skill_name: resources/ has ≥1 file"
  else
    fail "Skill $skill_name: resources/ missing or empty"
  fi

  # examples/example-prompts.md
  if [[ -f "${skill_dir}examples/example-prompts.md" ]]; then
    pass "Skill $skill_name: examples/example-prompts.md exists"
  else
    fail "Skill $skill_name: examples/example-prompts.md missing"
  fi

  # scripts/ with at least 1 file
  if [[ -d "${skill_dir}scripts" ]] && [[ $(ls -1 "${skill_dir}scripts/" 2>/dev/null | wc -l) -ge 1 ]]; then
    pass "Skill $skill_name: scripts/ has ≥1 file"
  else
    fail "Skill $skill_name: scripts/ missing or empty"
  fi
done

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3 — Workflow directory structure
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Section 3: Workflow directory structure ---"

WORKFLOW_COUNT=0
for wf_dir in workflows/*/; do
  [[ "$wf_dir" == "workflows/*/" ]] && continue
  [[ -d "$wf_dir" ]] || continue
  wf_name=$(basename "$wf_dir")
  WORKFLOW_COUNT=$((WORKFLOW_COUNT + 1))

  if [[ -f "${wf_dir}WORKFLOW.md" ]]; then
    pass "Workflow $wf_name: WORKFLOW.md exists"
  else
    fail "Workflow $wf_name: WORKFLOW.md missing"
  fi
done

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4 — No empty files (.md, .R, .py)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Section 4: No empty files ---"

EMPTY_FILES=()
while IFS= read -r -d '' f; do
  size=$(wc -c < "$f" 2>/dev/null || echo 0)
  if [[ "$size" -lt 100 ]]; then
    EMPTY_FILES+=("$f (${size} bytes)")
  fi
done < <(find skills/ workflows/ templates/ -type f \( -name "*.md" -o -name "*.R" -o -name "*.py" \) -print0 2>/dev/null)

if [[ ${#EMPTY_FILES[@]} -eq 0 ]]; then
  pass "No empty or near-empty files found (all ≥100 bytes)"
else
  for ef in "${EMPTY_FILES[@]}"; do
    fail "File too small (<100 bytes): $ef"
  done
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5 — R script quality
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Section 5: R script quality ---"

SCRIPT_COUNT=0
while IFS= read -r -d '' rfile; do
  SCRIPT_COUNT=$((SCRIPT_COUNT + 1))
  relpath="${rfile#$REPO_ROOT/}"

  # Must start with # Usage:
  first_line=$(head -1 "$rfile" 2>/dev/null || echo "")
  if echo "$first_line" | grep -q "^# Usage:"; then
    pass "R script has Usage comment on line 1: $relpath"
  else
    fail "R script missing '# Usage:' on line 1: $relpath"
  fi

  # Must contain suppressPackageStartupMessages
  if grep -q "suppressPackageStartupMessages" "$rfile" 2>/dev/null; then
    pass "R script uses suppressPackageStartupMessages: $relpath"
  else
    fail "R script missing suppressPackageStartupMessages: $relpath"
  fi
done < <(find skills/*/scripts/ -name "*.R" -type f -print0 2>/dev/null)

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6 — Python script quality
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Section 6: Python script quality ---"

while IFS= read -r -d '' pyfile; do
  relpath="${pyfile#$REPO_ROOT/}"

  # Must contain "Usage:" in a docstring (within first 10 lines)
  if head -10 "$pyfile" | grep -q "Usage:"; then
    pass "Python script has 'Usage:' in header: $relpath"
  else
    fail "Python script missing 'Usage:' in header docstring: $relpath"
  fi

  # Must contain if __name__ == "__main__"
  if grep -q '__name__ == "__main__"' "$pyfile" 2>/dev/null || grep -q "__name__ == '__main__'" "$pyfile" 2>/dev/null; then
    pass "Python script has __main__ guard: $relpath"
  else
    fail "Python script missing 'if __name__ == \"__main__\"': $relpath"
  fi
done < <(find skills/*/scripts/ -name "*.py" -type f -print0 2>/dev/null)

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7 — SKILL.md quality
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Section 7: SKILL.md content quality ---"

REQUIRED_SECTIONS=("Purpose" "When to Invoke" "Inputs" "Outputs" "Steps" "Notes")

for skill_dir in skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")
  skill_md="${skill_dir}SKILL.md"
  [[ -f "$skill_md" ]] || continue

  for section in "${REQUIRED_SECTIONS[@]}"; do
    if grep -q "## $section" "$skill_md" 2>/dev/null; then
      pass "SKILL.md $skill_name: section '## $section' present"
    else
      fail "SKILL.md $skill_name: section '## $section' missing"
    fi
  done

  if grep -q "skill_version" "$skill_md" 2>/dev/null; then
    pass "SKILL.md $skill_name: skill_version field present"
  else
    fail "SKILL.md $skill_name: skill_version field missing"
  fi
done

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8 — SKILL_INDEX.json consistency
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Section 8: SKILL_INDEX.json consistency ---"

PYTHON_CMD=""
for cmd in py python python3; do
  if command -v "$cmd" &>/dev/null && "$cmd" -c "import sys; sys.exit(0)" &>/dev/null; then
    PYTHON_CMD="$cmd"; break
  fi
done

if [[ -n "$PYTHON_CMD" ]] && [[ -f "skills/SKILL_INDEX.json" ]]; then
  # Validate JSON
  if "$PYTHON_CMD" -m json.tool skills/SKILL_INDEX.json > /dev/null 2>&1; then
    pass "SKILL_INDEX.json is valid JSON"
  else
    fail "SKILL_INDEX.json is NOT valid JSON"
  fi

  # Check each skill_id has a matching directory
  "$PYTHON_CMD" - <<'PYEOF'
import json, sys, os

with open("skills/SKILL_INDEX.json") as f:
    index = json.load(f)

skills = index.get("skills", [])
failed = 0

for skill in skills:
    sid = skill.get("skill_id", "")
    skill_dir = f"skills/{sid}"
    if os.path.isdir(skill_dir):
        print(f"[PASS] SKILL_INDEX skill_id '{sid}' matches directory")
    else:
        print(f"[FAIL] SKILL_INDEX skill_id '{sid}' has no matching directory at {skill_dir}")
        failed += 1

    # Check called_by_workflows exist
    for wf in skill.get("called_by_workflows", []):
        wf_path = f"workflows/{wf}"
        if os.path.isdir(wf_path):
            print(f"[PASS] Workflow '{wf}' referenced in '{sid}' exists")
        else:
            print(f"[FAIL] Workflow '{wf}' referenced in '{sid}' not found at {wf_path}")
            failed += 1

sys.exit(failed)
PYEOF
  python3_exit=$?
  if [[ $python3_exit -ne 0 ]]; then
    FAIL=$((FAIL + python3_exit))
  fi
else
  fail "python not available or SKILL_INDEX.json missing — skipping JSON consistency check"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 9 — Test coverage (name-based matching)
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Section 9: Test coverage ---"

# R scripts → tests/r/test-<skill>.R
for skill_dir in skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")

  r_scripts=$(find "${skill_dir}scripts/" -name "*.R" -type f 2>/dev/null | wc -l)
  if [[ "$r_scripts" -gt 0 ]]; then
    # Look for any test file matching the skill name (partial match)
    slug=$(echo "$skill_name" | sed 's/[^a-z0-9]/-/g')
    test_match=$(find tests/r/ -name "test-*.R" 2>/dev/null | grep -i "${slug%%-*}" | wc -l)
    if [[ "$test_match" -gt 0 ]]; then
      pass "R test coverage: skill '$skill_name' has matching test in tests/r/"
    else
      fail "R test coverage: skill '$skill_name' has .R scripts but no matching test in tests/r/"
    fi
  fi
done

# Python scripts → tests/python/test_<skill>.py
for skill_dir in skills/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill_name=$(basename "$skill_dir")

  py_scripts=$(find "${skill_dir}scripts/" -name "*.py" -type f 2>/dev/null | wc -l)
  if [[ "$py_scripts" -gt 0 ]]; then
    slug=$(echo "$skill_name" | tr '-' '_')
    first_word=$(echo "$slug" | cut -d'_' -f1)
    test_match=$(find tests/python/ -name "test_*.py" 2>/dev/null | grep -i "$first_word" | wc -l)
    if [[ "$test_match" -gt 0 ]]; then
      pass "Python test coverage: skill '$skill_name' has matching test in tests/python/"
    else
      fail "Python test coverage: skill '$skill_name' has .py scripts but no matching test in tests/python/"
    fi
  fi
done

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# FINAL REPORT
# ─────────────────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))

echo "========================================"
echo " === CI REPORT ==="
echo " Checks passed: ${PASS}/${TOTAL}"
echo " Skills verified: ${SKILL_COUNT}"
echo " Workflows verified: ${WORKFLOW_COUNT}"
echo " R scripts verified: ${SCRIPT_COUNT}"
echo " Empty files: ${#EMPTY_FILES[@]}"

if [[ ${#FAILED_CHECKS[@]} -gt 0 ]]; then
  echo ""
  echo " Failed checks:"
  for fc in "${FAILED_CHECKS[@]}"; do
    echo "   - $fc"
  done
fi

echo "========================================"

if [[ $FAIL -gt 0 ]]; then
  echo " RESULT: FAILED ($FAIL check(s) did not pass)"
  exit 1
else
  echo " RESULT: ALL CHECKS PASSED"
  exit 0
fi
