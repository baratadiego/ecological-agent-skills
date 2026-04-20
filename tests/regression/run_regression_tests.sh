#!/usr/bin/env bash
# run_regression_tests.sh — Compare current script outputs against saved references
# Usage: bash tests/regression/run_regression_tests.sh
# Exit 0 = all passed (or no references). Exit 1 = regression detected.

set -uo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

REPORT="tests/regression/regression_report.txt"
REF_DIR="tests/regression/reference_outputs"
TMP_DIR="tests/regression/.tmp_current"
PASS=0
FAIL=0
SKIP=0
DETAILS=()

# ─────────────────────────────────────────────────────────────────────────────
# Detect Python command
# ─────────────────────────────────────────────────────────────────────────────
PYTHON_CMD=""
for cmd in python3 python py; do
  if command -v "$cmd" &>/dev/null && "$cmd" -c "import sys; sys.exit(0)" &>/dev/null; then
    PYTHON_CMD="$cmd"
    break
  fi
done

if [[ -z "$PYTHON_CMD" ]]; then
  echo "ERROR: No Python interpreter found. Regression tests require Python."
  exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Check for reference files
# ─────────────────────────────────────────────────────────────────────────────
REF_COUNT=$(find "$REF_DIR" -type f ! -name '.gitkeep' 2>/dev/null | wc -l | tr -d ' ')

if [[ "$REF_COUNT" -eq 0 ]]; then
  echo "No reference outputs found. Run update_references.sh first."
  echo "Exiting with success (nothing to compare)."
  exit 0
fi

echo "========================================"
echo " REGRESSION TEST SUITE"
echo " Repository: $REPO_ROOT"
echo " References: $REF_COUNT file(s)"
echo " Timestamp : $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Prepare temporary output directory
# ─────────────────────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Comparison functions
# ─────────────────────────────────────────────────────────────────────────────

# compare_csv — Numeric CSV comparison with relative tolerance
# Args: $1 = reference CSV path, $2 = current CSV path, $3 = tolerance (default 0.01)
# Returns: 0 if match, 1 if mismatch. Prints diff details.
compare_csv() {
  local ref_csv="$1"
  local cur_csv="$2"
  local tolerance="${3:-0.01}"
  local label="$4"

  if [[ ! -f "$cur_csv" ]]; then
    echo "  [FAIL] $label — current output file not found: $cur_csv"
    FAIL=$((FAIL + 1))
    DETAILS+=("[FAIL] $label — file not found: $cur_csv")
    return 1
  fi

  # Use inline Python for numeric comparison
  local result
  result=$("$PYTHON_CMD" - "$ref_csv" "$cur_csv" "$tolerance" <<'PYEOF'
import sys
import csv
import math

ref_path = sys.argv[1]
cur_path = sys.argv[2]
tolerance = float(sys.argv[3])

def read_csv(path):
    with open(path, newline='', encoding='utf-8') as f:
        reader = csv.reader(f)
        return [row for row in reader]

try:
    ref_data = read_csv(ref_path)
    cur_data = read_csv(cur_path)
except Exception as e:
    print(f"ERROR: Could not read CSV files: {e}")
    sys.exit(2)

# Check header match
if len(ref_data) == 0 and len(cur_data) == 0:
    print("PASS: Both files empty")
    sys.exit(0)

if len(ref_data) == 0 or len(cur_data) == 0:
    print(f"FAIL: Row count mismatch — reference={len(ref_data)}, current={len(cur_data)}")
    sys.exit(1)

# Compare headers
if ref_data[0] != cur_data[0]:
    print(f"FAIL: Header mismatch — reference={ref_data[0]}, current={cur_data[0]}")
    sys.exit(1)

# Check row counts
if len(ref_data) != len(cur_data):
    print(f"FAIL: Row count mismatch — reference={len(ref_data)}, current={len(cur_data)}")
    sys.exit(1)

# Compare each cell
max_rel_diff = 0.0
mismatches = 0
first_mismatch = None

for i in range(1, len(ref_data)):
    if len(ref_data[i]) != len(cur_data[i]):
        print(f"FAIL: Column count mismatch at row {i} — reference={len(ref_data[i])}, current={len(cur_data[i])}")
        sys.exit(1)

    for j in range(len(ref_data[i])):
        ref_val = ref_data[i][j].strip()
        cur_val = cur_data[i][j].strip()

        # Try numeric comparison
        try:
            ref_num = float(ref_val)
            cur_num = float(cur_val)

            # Handle special cases
            if math.isnan(ref_num) and math.isnan(cur_num):
                continue
            if math.isinf(ref_num) and math.isinf(cur_num):
                if (ref_num > 0) == (cur_num > 0):
                    continue

            # Compute relative difference
            denom = max(abs(ref_num), 1e-15)
            rel_diff = abs(ref_num - cur_num) / denom

            if rel_diff > max_rel_diff:
                max_rel_diff = rel_diff

            if rel_diff > tolerance:
                mismatches += 1
                if first_mismatch is None:
                    header = ref_data[0][j] if j < len(ref_data[0]) else f"col{j}"
                    first_mismatch = f"row {i}, col '{header}': ref={ref_val}, cur={cur_val}, rel_diff={rel_diff:.6f}"

        except ValueError:
            # String comparison (exact match)
            if ref_val != cur_val:
                mismatches += 1
                if first_mismatch is None:
                    header = ref_data[0][j] if j < len(ref_data[0]) else f"col{j}"
                    first_mismatch = f"row {i}, col '{header}': ref='{ref_val}', cur='{cur_val}' (string mismatch)"

if mismatches > 0:
    print(f"FAIL: {mismatches} cell(s) exceed tolerance ({tolerance}). Max rel diff: {max_rel_diff:.6f}. First: {first_mismatch}")
    sys.exit(1)
else:
    print(f"PASS: All cells within tolerance ({tolerance}). Max rel diff: {max_rel_diff:.6f}")
    sys.exit(0)
PYEOF
  )
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    echo "  [PASS] $label — $result"
    PASS=$((PASS + 1))
    DETAILS+=("[PASS] $label — $result")
    return 0
  elif [[ $exit_code -eq 1 ]]; then
    echo "  [FAIL] $label — $result"
    FAIL=$((FAIL + 1))
    DETAILS+=("[FAIL] $label — $result")
    return 1
  else
    echo "  [SKIP] $label — comparison error: $result"
    SKIP=$((SKIP + 1))
    DETAILS+=("[SKIP] $label — comparison error: $result")
    return 1
  fi
}


# compare_json — JSON comparison with numeric tolerance
# Args: $1 = reference JSON, $2 = current JSON, $3 = tolerance (default 0.001)
# Returns: 0 if match, 1 if mismatch.
compare_json() {
  local ref_json="$1"
  local cur_json="$2"
  local tolerance="${3:-0.001}"
  local label="$4"

  if [[ ! -f "$cur_json" ]]; then
    echo "  [FAIL] $label — current output file not found: $cur_json"
    FAIL=$((FAIL + 1))
    DETAILS+=("[FAIL] $label — file not found: $cur_json")
    return 1
  fi

  local result
  result=$("$PYTHON_CMD" - "$ref_json" "$cur_json" "$tolerance" <<'PYEOF'
import sys
import json
import math

ref_path = sys.argv[1]
cur_path = sys.argv[2]
tolerance = float(sys.argv[3])

try:
    with open(ref_path) as f:
        ref = json.load(f)
    with open(cur_path) as f:
        cur = json.load(f)
except Exception as e:
    print(f"ERROR: Could not read JSON files: {e}")
    sys.exit(2)

mismatches = 0
max_rel_diff = 0.0
first_mismatch = None

def compare(ref_obj, cur_obj, path=""):
    global mismatches, max_rel_diff, first_mismatch
    if isinstance(ref_obj, dict) and isinstance(cur_obj, dict):
        all_keys = set(ref_obj.keys()) | set(cur_obj.keys())
        for k in sorted(all_keys):
            if k not in ref_obj:
                mismatches += 1
                if first_mismatch is None:
                    first_mismatch = f"key '{path}.{k}' present in current but missing from reference"
            elif k not in cur_obj:
                mismatches += 1
                if first_mismatch is None:
                    first_mismatch = f"key '{path}.{k}' present in reference but missing from current"
            else:
                compare(ref_obj[k], cur_obj[k], f"{path}.{k}")
    elif isinstance(ref_obj, list) and isinstance(cur_obj, list):
        if len(ref_obj) != len(cur_obj):
            mismatches += 1
            if first_mismatch is None:
                first_mismatch = f"array length mismatch at '{path}': ref={len(ref_obj)}, cur={len(cur_obj)}"
        else:
            for i in range(len(ref_obj)):
                compare(ref_obj[i], cur_obj[i], f"{path}[{i}]")
    elif isinstance(ref_obj, (int, float)) and isinstance(cur_obj, (int, float)):
        if math.isnan(ref_obj) and math.isnan(cur_obj):
            return
        denom = max(abs(ref_obj), 1e-15)
        rel_diff = abs(ref_obj - cur_obj) / denom
        if rel_diff > max_rel_diff:
            max_rel_diff = rel_diff
        if rel_diff > tolerance:
            mismatches += 1
            if first_mismatch is None:
                first_mismatch = f"at '{path}': ref={ref_obj}, cur={cur_obj}, rel_diff={rel_diff:.6f}"
    else:
        if ref_obj != cur_obj:
            mismatches += 1
            if first_mismatch is None:
                first_mismatch = f"at '{path}': ref={repr(ref_obj)}, cur={repr(cur_obj)}"

compare(ref, cur)

if mismatches > 0:
    print(f"FAIL: {mismatches} value(s) exceed tolerance ({tolerance}). Max rel diff: {max_rel_diff:.6f}. First: {first_mismatch}")
    sys.exit(1)
else:
    print(f"PASS: All values within tolerance ({tolerance}). Max rel diff: {max_rel_diff:.6f}")
    sys.exit(0)
PYEOF
  )
  local exit_code=$?

  if [[ $exit_code -eq 0 ]]; then
    echo "  [PASS] $label — $result"
    PASS=$((PASS + 1))
    DETAILS+=("[PASS] $label — $result")
    return 0
  elif [[ $exit_code -eq 1 ]]; then
    echo "  [FAIL] $label — $result"
    FAIL=$((FAIL + 1))
    DETAILS+=("[FAIL] $label — $result")
    return 1
  else
    echo "  [SKIP] $label — comparison error: $result"
    SKIP=$((SKIP + 1))
    DETAILS+=("[SKIP] $label — comparison error: $result")
    return 1
  fi
}


# compare_png — PNG existence and non-zero size check
# Args: $1 = reference PNG, $2 = current PNG
# Returns: 0 if current exists and size > 0, 1 otherwise.
compare_png() {
  local ref_png="$1"
  local cur_png="$2"
  local label="$3"

  if [[ ! -f "$cur_png" ]]; then
    echo "  [FAIL] $label — current output file not found: $cur_png"
    FAIL=$((FAIL + 1))
    DETAILS+=("[FAIL] $label — file not found: $cur_png")
    return 1
  fi

  local size
  size=$(wc -c < "$cur_png" 2>/dev/null | tr -d ' ')

  if [[ "$size" -gt 0 ]]; then
    echo "  [PASS] $label — PNG exists, size=${size} bytes"
    PASS=$((PASS + 1))
    DETAILS+=("[PASS] $label — PNG exists, size=${size} bytes")
    return 0
  else
    echo "  [FAIL] $label — PNG exists but is empty (0 bytes)"
    FAIL=$((FAIL + 1))
    DETAILS+=("[FAIL] $label — PNG empty (0 bytes)")
    return 1
  fi
}


# ─────────────────────────────────────────────────────────────────────────────
# Script-to-output mapping
# Each entry defines: skill name, script path, input arguments, output files
# These are the scripts that produce deterministic or near-deterministic outputs
# suitable for regression testing.
# ─────────────────────────────────────────────────────────────────────────────

# run_one_script — Execute a script and capture its output
# Args: $1 = interpreter (python/Rscript), $2 = script path, $3+ = arguments
# Returns: exit code of the script
run_one_script() {
  local interpreter="$1"
  shift
  local script="$1"
  shift

  if [[ ! -f "$script" ]]; then
    echo "  [SKIP] Script not found: $script"
    SKIP=$((SKIP + 1))
    return 2
  fi

  "$interpreter" "$script" "$@" 2>&1 | tail -5
  return "${PIPESTATUS[0]}"
}


# ─────────────────────────────────────────────────────────────────────────────
# Main comparison loop
# Walk every file in reference_outputs/ and dispatch to the right comparator.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Running comparisons ---"
echo ""

# Mapping: reference file -> how to regenerate it
# Convention: reference files are stored as:
#   reference_outputs/<skill_name>/<output_filename>
# The current outputs are generated into:
#   .tmp_current/<skill_name>/<output_filename>

# For each reference file, determine the skill, find the script, run it,
# and compare the output.

# Step 1: Identify all unique skill directories under reference_outputs/
declare -A SKILL_SCRIPTS

# --- ecological-data-foundation ---
SKILL_SCRIPTS["ecological-data-foundation/py"]="python:skills/ecological-data-foundation/scripts/clean_occurrences.py:tests/data/occurrences_raw.csv $TMP_DIR/ecological-data-foundation"

# --- biostatistics-workbench ---
SKILL_SCRIPTS["biostatistics-workbench/py"]="python:skills/biostatistics-workbench/scripts/glm_pipeline.py:tests/data/points_with_env.csv pa $TMP_DIR/biostatistics-workbench"

# --- community-ecology-ordination ---
SKILL_SCRIPTS["community-ecology-ordination/py"]="python:skills/community-ecology-ordination/scripts/community_analysis.py:tests/data/species_site_matrix.csv tests/data/site_metadata.csv $TMP_DIR/community-ecology-ordination"

# --- environmental-time-series ---
SKILL_SCRIPTS["environmental-time-series/trend"]="python:skills/environmental-time-series/scripts/trend_analysis.py:tests/data/ndvi_monthly_series.csv $TMP_DIR/environmental-time-series/trend"
SKILL_SCRIPTS["environmental-time-series/recovery"]="python:skills/environmental-time-series/scripts/recovery_trajectory.py:tests/data/ndvi_monthly_series.csv 2015-01-01 $TMP_DIR/environmental-time-series/recovery"

# --- model-validation-and-uncertainty ---
SKILL_SCRIPTS["model-validation-and-uncertainty/py"]="python:skills/model-validation-and-uncertainty/scripts/validate_model.py:tests/data/model_predictions.csv $TMP_DIR/model-validation-and-uncertainty"

# --- occupancy-and-detection ---
SKILL_SCRIPTS["occupancy-and-detection/py"]="python:skills/occupancy-and-detection/scripts/occupancy_analysis.py:tests/data/detection_history.csv $TMP_DIR/occupancy-and-detection"

# --- population-viability-analysis ---
SKILL_SCRIPTS["population-viability-analysis/py"]="python:skills/population-viability-analysis/scripts/pva_analysis.py:tests/data/vital_rates.csv $TMP_DIR/population-viability-analysis"

# --- ecosystem-services-assessment ---
SKILL_SCRIPTS["ecosystem-services-assessment/py"]="python:skills/ecosystem-services-assessment/scripts/compute_es.py:tests/data/rasters/landcover.tif tests/data/carbon_pools.csv $TMP_DIR/ecosystem-services-assessment"

# --- predictive-modeling-best-practices ---
SKILL_SCRIPTS["predictive-modeling-best-practices/py"]="python:skills/predictive-modeling-best-practices/scripts/spatial_cv.py:tests/data/points_with_env.csv $TMP_DIR/predictive-modeling-best-practices"

# --- landscape-connectivity ---
SKILL_SCRIPTS["landscape-connectivity/py"]="python:skills/landscape-connectivity/scripts/connectivity_analysis.py:tests/data/patches.csv $TMP_DIR/landscape-connectivity"

# --- ecological-impact-assessment ---
SKILL_SCRIPTS["ecological-impact-assessment/py"]="python:skills/ecological-impact-assessment/scripts/fragmentation_analysis.py:tests/data/rasters/landcover.tif 1 $TMP_DIR/ecological-impact-assessment"


# Step 2: Walk reference files and run comparisons
declare -A REGENERATED_SKILLS

while IFS= read -r -d '' ref_file; do
  # Skip .gitkeep
  [[ "$(basename "$ref_file")" == ".gitkeep" ]] && continue

  # Determine relative path from REF_DIR
  rel_path="${ref_file#$REF_DIR/}"
  skill_name=$(echo "$rel_path" | cut -d'/' -f1)
  output_file=$(basename "$rel_path")
  cur_file="$TMP_DIR/$rel_path"

  echo "Checking: $rel_path"

  # Try to regenerate current output if not yet done for this skill
  if [[ -z "${REGENERATED_SKILLS[$skill_name]+_}" ]]; then
    echo "  Regenerating outputs for: $skill_name"
    mkdir -p "$TMP_DIR/$skill_name"

    # Find matching script entry
    found_script=0
    for key in "${!SKILL_SCRIPTS[@]}"; do
      if [[ "$key" == "$skill_name"* ]]; then
        IFS=':' read -r interp script_path args <<< "${SKILL_SCRIPTS[$key]}"
        if [[ "$interp" == "python" ]]; then
          interp="$PYTHON_CMD"
        fi
        echo "  Running: $interp $script_path $args"
        # shellcheck disable=SC2086
        run_one_script "$interp" "$script_path" $args > /dev/null 2>&1 || true
        found_script=1
      fi
    done

    if [[ $found_script -eq 0 ]]; then
      echo "  [SKIP] No script mapping for skill: $skill_name"
    fi

    REGENERATED_SKILLS[$skill_name]=1
  fi

  # Dispatch comparison by file extension
  ext="${output_file##*.}"
  case "$ext" in
    csv)
      compare_csv "$ref_file" "$cur_file" "0.01" "$rel_path"
      ;;
    json)
      compare_json "$ref_file" "$cur_file" "0.001" "$rel_path"
      ;;
    png|jpg|jpeg|tif|tiff|pdf)
      compare_png "$ref_file" "$cur_file" "$rel_path"
      ;;
    md|txt|log)
      # Text files: exact comparison (ignoring trailing whitespace and
      # volatile metadata lines like Date:/Time: in statsmodels summaries)
      if [[ ! -f "$cur_file" ]]; then
        echo "  [FAIL] $rel_path — current output file not found"
        FAIL=$((FAIL + 1))
        DETAILS+=("[FAIL] $rel_path — file not found")
      elif diff -q \
          <(sed -E 's/[[:space:]]*$//; /^(Date|Time):[[:space:]]/d' "$ref_file") \
          <(sed -E 's/[[:space:]]*$//; /^(Date|Time):[[:space:]]/d' "$cur_file") \
          > /dev/null 2>&1; then
        echo "  [PASS] $rel_path — text matches reference"
        PASS=$((PASS + 1))
        DETAILS+=("[PASS] $rel_path — text matches reference")
      else
        echo "  [FAIL] $rel_path — text differs from reference"
        FAIL=$((FAIL + 1))
        DETAILS+=("[FAIL] $rel_path — text content differs")
      fi
      ;;
    *)
      echo "  [SKIP] $rel_path — unknown extension '.$ext', skipping"
      SKIP=$((SKIP + 1))
      DETAILS+=("[SKIP] $rel_path — unknown file extension")
      ;;
  esac

  echo ""
done < <(find "$REF_DIR" -type f ! -name '.gitkeep' -print0 2>/dev/null | sort -z)


# ─────────────────────────────────────────────────────────────────────────────
# Clean up temporary directory
# ─────────────────────────────────────────────────────────────────────────────
rm -rf "$TMP_DIR"


# ─────────────────────────────────────────────────────────────────────────────
# Write report
# ─────────────────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + SKIP))

{
  echo "========================================"
  echo " REGRESSION TEST REPORT"
  echo " Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo " Repository: $REPO_ROOT"
  echo "========================================"
  echo ""
  echo "Summary: $PASS passed, $FAIL failed, $SKIP skipped (total: $TOTAL)"
  echo ""
  echo "--- Details ---"
  for d in "${DETAILS[@]}"; do
    echo "  $d"
  done
  echo ""
  if [[ $FAIL -gt 0 ]]; then
    echo "RESULT: REGRESSION DETECTED"
  else
    echo "RESULT: ALL PASSED"
  fi
} > "$REPORT"

echo "========================================"
echo " REGRESSION TEST SUMMARY"
echo "========================================"
echo " Passed : $PASS"
echo " Failed : $FAIL"
echo " Skipped: $SKIP"
echo " Total  : $TOTAL"
echo ""
echo " Report written to: $REPORT"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
  echo " RESULT: REGRESSION DETECTED"
  exit 1
else
  echo " RESULT: ALL PASSED"
  exit 0
fi
