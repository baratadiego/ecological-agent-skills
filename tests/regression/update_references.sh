#!/usr/bin/env bash
# update_references.sh — Regenerate reference outputs for regression testing
# Usage: bash tests/regression/update_references.sh --confirm-update
# WARNING: This overwrites existing reference files.

set -euo pipefail

if [[ "${1:-}" != "--confirm-update" ]]; then
    echo "ERROR: This script overwrites reference outputs."
    echo "Usage: bash tests/regression/update_references.sh --confirm-update"
    echo ""
    echo "This will re-run analysis scripts with test data and save their outputs"
    echo "as the new reference baseline for regression testing."
    echo ""
    echo "Pass --confirm-update to proceed."
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

REF_DIR="tests/regression/reference_outputs"
LOG="tests/regression/REFERENCE_LOG.md"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
DATE_ONLY=$(date "+%Y-%m-%d")
TEST_DATA="tests/data"

# ─────────────────────────────────────────────────────────────────────────────
# Detect interpreters
# ─────────────────────────────────────────────────────────────────────────────
PYTHON_CMD=""
for cmd in python3 python py; do
  if command -v "$cmd" &>/dev/null && "$cmd" -c "import sys; sys.exit(0)" &>/dev/null; then
    PYTHON_CMD="$cmd"
    break
  fi
done

R_CMD=""
for cmd in Rscript; do
  if command -v "$cmd" &>/dev/null; then
    R_CMD="$cmd"
    break
  fi
done

echo "========================================"
echo " UPDATE REFERENCE OUTPUTS"
echo " Repository: $REPO_ROOT"
echo " Timestamp : $TIMESTAMP"
echo " Python    : ${PYTHON_CMD:-NOT FOUND}"
echo " R         : ${R_CMD:-NOT FOUND}"
echo "========================================"
echo ""

UPDATED=0
SKIPPED=0
FAILED=0
UPDATED_SCRIPTS=()

# ─────────────────────────────────────────────────────────────────────────────
# Helper: run a script and save outputs as references
# Args: $1 = label, $2 = interpreter, $3 = script path,
#        $4 = output subdir under REF_DIR, $5+ = script arguments
# ─────────────────────────────────────────────────────────────────────────────
run_and_save() {
  local label="$1"
  local interpreter="$2"
  local script="$3"
  local ref_subdir="$4"
  shift 4
  local args=("$@")

  echo "--- $label ---"

  if [[ -z "$interpreter" ]]; then
    echo "  [SKIP] Interpreter not available"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  if [[ ! -f "$script" ]]; then
    echo "  [SKIP] Script not found: $script"
    SKIPPED=$((SKIPPED + 1))
    return 0
  fi

  # Create output directory for this run (temporary)
  local tmp_out="tests/regression/.tmp_update/$ref_subdir"
  mkdir -p "$tmp_out"

  echo "  Running: $interpreter $script ${args[*]}"

  # Replace the output dir argument with our temporary directory
  # Convention: last argument is the output directory
  local new_args=()
  for ((i=0; i<${#args[@]}-1; i++)); do
    new_args+=("${args[$i]}")
  done
  new_args+=("$tmp_out")

  if "$interpreter" "$script" "${new_args[@]}" > /dev/null 2>&1; then
    # Copy outputs to reference directory
    local dest="$REF_DIR/$ref_subdir"
    mkdir -p "$dest"

    local file_count
    file_count=$(find "$tmp_out" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [[ "$file_count" -gt 0 ]]; then
      cp -r "$tmp_out"/* "$dest/"
      echo "  [OK] Saved $file_count file(s) to $dest/"
      UPDATED=$((UPDATED + 1))
      UPDATED_SCRIPTS+=("$label")
    else
      echo "  [WARN] Script ran but produced no output files"
      SKIPPED=$((SKIPPED + 1))
    fi
  else
    echo "  [FAIL] Script exited with error"
    FAILED=$((FAILED + 1))
  fi

  echo ""
}


# ─────────────────────────────────────────────────────────────────────────────
# Script registry
# Each entry: label, interpreter, script path, reference subdir, arguments...
# The LAST argument should be the output directory placeholder (will be replaced).
#
# NOTE: Scripts requiring packages not in the base environment are listed but
# may fail. This is expected — the update script reports what succeeded and
# what was skipped. Install required packages to generate all references.
# ─────────────────────────────────────────────────────────────────────────────

echo "=== Python scripts ==="
echo ""

# --- ecological-data-foundation: clean_occurrences.py ---
# Requires: pandas, numpy
# Inputs: occurrences_raw.csv
# Outputs: data_clean.csv, flagged_records.csv, qa_report.md
run_and_save \
  "ecological-data-foundation/clean_occurrences.py" \
  "$PYTHON_CMD" \
  "skills/ecological-data-foundation/scripts/clean_occurrences.py" \
  "ecological-data-foundation" \
  "$TEST_DATA/occurrences_raw.csv" \
  "__OUTPUT__"

# --- biostatistics-workbench: glm_pipeline.py ---
# Requires: pandas, numpy, statsmodels, scipy, matplotlib, seaborn
# Inputs: points_with_env.csv, response variable name
# Outputs: model comparison CSV, diagnostic plots
run_and_save \
  "biostatistics-workbench/glm_pipeline.py" \
  "$PYTHON_CMD" \
  "skills/biostatistics-workbench/scripts/glm_pipeline.py" \
  "biostatistics-workbench" \
  "$TEST_DATA/points_with_env.csv" \
  "pa" \
  "__OUTPUT__"

# --- community-ecology-ordination: community_analysis.py ---
# Requires: pandas, numpy, scipy, skbio, matplotlib
# Inputs: species_site_matrix.csv, site_metadata.csv
# Outputs: beta diversity CSV, ordination CSV, plots
run_and_save \
  "community-ecology-ordination/community_analysis.py" \
  "$PYTHON_CMD" \
  "skills/community-ecology-ordination/scripts/community_analysis.py" \
  "community-ecology-ordination" \
  "$TEST_DATA/species_site_matrix.csv" \
  "$TEST_DATA/site_metadata.csv" \
  "__OUTPUT__"

# --- environmental-time-series: trend_analysis.py ---
# Requires: pandas, numpy, pymannkendall, matplotlib, scipy
# Inputs: ndvi_monthly_series.csv
# Outputs: trend results CSV, anomaly CSV, plots
run_and_save \
  "environmental-time-series/trend_analysis.py" \
  "$PYTHON_CMD" \
  "skills/environmental-time-series/scripts/trend_analysis.py" \
  "environmental-time-series/trend" \
  "$TEST_DATA/ndvi_monthly_series.csv" \
  "__OUTPUT__"

# --- environmental-time-series: recovery_trajectory.py ---
# Requires: pandas, numpy, scipy, matplotlib
# Inputs: ndvi_monthly_series.csv, disturbance_date
# Outputs: recovery metrics CSV, plots
run_and_save \
  "environmental-time-series/recovery_trajectory.py" \
  "$PYTHON_CMD" \
  "skills/environmental-time-series/scripts/recovery_trajectory.py" \
  "environmental-time-series/recovery" \
  "$TEST_DATA/ndvi_monthly_series.csv" \
  "2015-01-01" \
  "__OUTPUT__"

# --- model-validation-and-uncertainty: validate_model.py ---
# Requires: pandas, numpy, scikit-learn, matplotlib
# Inputs: model_predictions.csv
# Outputs: validation metrics CSV/JSON, calibration plots
run_and_save \
  "model-validation-and-uncertainty/validate_model.py" \
  "$PYTHON_CMD" \
  "skills/model-validation-and-uncertainty/scripts/validate_model.py" \
  "model-validation-and-uncertainty" \
  "$TEST_DATA/model_predictions.csv" \
  "__OUTPUT__"

# --- occupancy-and-detection: occupancy_analysis.py ---
# Requires: pandas, numpy, scipy, matplotlib
# Inputs: detection_history.csv
# Outputs: occupancy estimates CSV, detection summary
run_and_save \
  "occupancy-and-detection/occupancy_analysis.py" \
  "$PYTHON_CMD" \
  "skills/occupancy-and-detection/scripts/occupancy_analysis.py" \
  "occupancy-and-detection" \
  "$TEST_DATA/detection_history.csv" \
  "__OUTPUT__"

# --- population-viability-analysis: pva_analysis.py ---
# Requires: pandas, numpy, matplotlib
# Inputs: vital_rates.csv (stage-structured demographic matrix)
# Outputs: PVA results CSV, trajectory plots
run_and_save \
  "population-viability-analysis/pva_analysis.py" \
  "$PYTHON_CMD" \
  "skills/population-viability-analysis/scripts/pva_analysis.py" \
  "population-viability-analysis" \
  "$TEST_DATA/vital_rates.csv" \
  "__OUTPUT__"

# --- ecosystem-services-assessment: compute_es.py ---
# Requires: pandas, numpy, rasterio, geopandas
# Inputs: rasters/landcover.tif, carbon_pools.csv
# Outputs: carbon/erosion/pollination rasters, es_summary_table.csv
run_and_save \
  "ecosystem-services-assessment/compute_es.py" \
  "$PYTHON_CMD" \
  "skills/ecosystem-services-assessment/scripts/compute_es.py" \
  "ecosystem-services-assessment" \
  "$TEST_DATA/rasters/landcover.tif" \
  "$TEST_DATA/carbon_pools.csv" \
  "__OUTPUT__"

# --- predictive-modeling-best-practices: spatial_cv.py ---
# Requires: pandas, numpy, scikit-learn, matplotlib
# Inputs: points_with_env.csv
# Outputs: cross-validation results CSV
run_and_save \
  "predictive-modeling-best-practices/spatial_cv.py" \
  "$PYTHON_CMD" \
  "skills/predictive-modeling-best-practices/scripts/spatial_cv.py" \
  "predictive-modeling-best-practices" \
  "$TEST_DATA/points_with_env.csv" \
  "__OUTPUT__"

# --- geoprocessing-for-ecology: stack_and_extract.py ---
# Requires: rasterio, geopandas, pandas
# NOTE: Requires raster input files not available in test data
# TODO: Add when raster test fixtures are created
# run_and_save \
#   "geoprocessing-for-ecology/stack_and_extract.py" \
#   "$PYTHON_CMD" \
#   "skills/geoprocessing-for-ecology/scripts/stack_and_extract.py" \
#   "geoprocessing-for-ecology" \
#   "<raster_dir>" \
#   "<points_csv>" \
#   "__OUTPUT__"

# --- landscape-connectivity: connectivity_analysis.py ---
# Requires: networkx, numpy, matplotlib
# Inputs: patches.csv (patch_id, x, y, area_ha)
# Outputs: patch_metrics.csv, landscape_summary.csv, connectivity_graph.png
run_and_save \
  "landscape-connectivity/connectivity_analysis.py" \
  "$PYTHON_CMD" \
  "skills/landscape-connectivity/scripts/connectivity_analysis.py" \
  "landscape-connectivity" \
  "$TEST_DATA/patches.csv" \
  "__OUTPUT__"

# --- ecological-impact-assessment: fragmentation_analysis.py ---
# Requires: rasterio, numpy, matplotlib
# Inputs: rasters/landcover.tif, habitat_class (e.g. 1 = forest)
# Outputs: fragmentation metrics CSV, plots
run_and_save \
  "ecological-impact-assessment/fragmentation_analysis.py" \
  "$PYTHON_CMD" \
  "skills/ecological-impact-assessment/scripts/fragmentation_analysis.py" \
  "ecological-impact-assessment" \
  "$TEST_DATA/rasters/landcover.tif" \
  "1" \
  "__OUTPUT__"

# --- species-distribution-modeling: sdm_pipeline.py ---
# Requires: scikit-learn, rasterio, geopandas, etc.
# NOTE: Requires raster predictor layers not available in test data
# TODO: Add when raster test fixtures are created
# run_and_save \
#   "species-distribution-modeling/sdm_pipeline.py" \
#   "$PYTHON_CMD" \
#   "skills/species-distribution-modeling/scripts/sdm_pipeline.py" \
#   "species-distribution-modeling" \
#   "<occurrences_csv>" \
#   "<predictor_dir>" \
#   "__OUTPUT__"

echo ""
echo "=== R scripts ==="
echo ""
echo "NOTE: R scripts require Rscript and the corresponding R packages."
echo "Uncomment entries below as packages become available."
echo ""

# --- ecological-data-foundation: clean_occurrences.R ---
# Requires: tidyverse, CoordinateCleaner
# run_and_save \
#   "ecological-data-foundation/clean_occurrences.R" \
#   "$R_CMD" \
#   "skills/ecological-data-foundation/scripts/clean_occurrences.R" \
#   "ecological-data-foundation-r" \
#   "$TEST_DATA/occurrences_raw.csv" \
#   "__OUTPUT__"

# --- biostatistics-workbench: glm_pipeline.R ---
# Requires: MASS, lme4, DHARMa, MuMIn, ggplot2
# run_and_save \
#   "biostatistics-workbench/glm_pipeline.R" \
#   "$R_CMD" \
#   "skills/biostatistics-workbench/scripts/glm_pipeline.R" \
#   "biostatistics-workbench-r" \
#   "$TEST_DATA/points_with_env.csv" \
#   "richness" \
#   "__OUTPUT__"

# --- community-ecology-ordination: community_analysis.R ---
# Requires: vegan, ggplot2, ape
# run_and_save \
#   "community-ecology-ordination/community_analysis.R" \
#   "$R_CMD" \
#   "skills/community-ecology-ordination/scripts/community_analysis.R" \
#   "community-ecology-ordination-r" \
#   "$TEST_DATA/species_site_matrix.csv" \
#   "$TEST_DATA/site_metadata.csv" \
#   "__OUTPUT__"

# --- environmental-time-series: trend_analysis.R ---
# Requires: Kendall, trend, ggplot2
# run_and_save \
#   "environmental-time-series/trend_analysis.R" \
#   "$R_CMD" \
#   "skills/environmental-time-series/scripts/trend_analysis.R" \
#   "environmental-time-series-r/trend" \
#   "$TEST_DATA/ndvi_monthly_series.csv" \
#   "__OUTPUT__"

# --- occupancy-and-detection: occupancy_analysis.R ---
# Requires: unmarked, ggplot2
# run_and_save \
#   "occupancy-and-detection/occupancy_analysis.R" \
#   "$R_CMD" \
#   "skills/occupancy-and-detection/scripts/occupancy_analysis.R" \
#   "occupancy-and-detection-r" \
#   "$TEST_DATA/detection_history.csv" \
#   "$TEST_DATA/occ_site_covariates.csv" \
#   "__OUTPUT__"

# --- model-validation-and-uncertainty: validate_sdm.R ---
# Requires: dismo, PresenceAbsence, ggplot2
# run_and_save \
#   "model-validation-and-uncertainty/validate_sdm.R" \
#   "$R_CMD" \
#   "skills/model-validation-and-uncertainty/scripts/validate_sdm.R" \
#   "model-validation-and-uncertainty-r" \
#   "$TEST_DATA/model_predictions.csv" \
#   "__OUTPUT__"

# --- population-viability-analysis: matrix_pva.R ---
# Requires: popbio, ggplot2
# run_and_save \
#   "population-viability-analysis/matrix_pva.R" \
#   "$R_CMD" \
#   "skills/population-viability-analysis/scripts/matrix_pva.R" \
#   "population-viability-analysis-r" \
#   "$TEST_DATA/richness_data.csv" \
#   "__OUTPUT__"

# --- ecological-impact-assessment: baci_analysis.R ---
# Requires: lme4, ggplot2, emmeans
# run_and_save \
#   "ecological-impact-assessment/baci_analysis.R" \
#   "$R_CMD" \
#   "skills/ecological-impact-assessment/scripts/baci_analysis.R" \
#   "ecological-impact-assessment-r" \
#   "$TEST_DATA/baci_data.csv" \
#   "__OUTPUT__"

# --- species-distribution-modeling: run_ensemble_sdm.R ---
# Requires: biomod2, terra, sf, dismo
# NOTE: Requires raster predictor layers
# TODO: Add when raster test fixtures are created
# run_and_save \
#   "species-distribution-modeling/run_ensemble_sdm.R" \
#   "$R_CMD" \
#   "skills/species-distribution-modeling/scripts/run_ensemble_sdm.R" \
#   "species-distribution-modeling-r" \
#   "<occurrences_csv>" \
#   "<predictor_dir>" \
#   "__OUTPUT__"

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Clean up temporary directory
# ─────────────────────────────────────────────────────────────────────────────
rm -rf "tests/regression/.tmp_update"

# ─────────────────────────────────────────────────────────────────────────────
# Update REFERENCE_LOG.md
# ─────────────────────────────────────────────────────────────────────────────
if [[ $UPDATED -gt 0 ]]; then
  for script_label in "${UPDATED_SCRIPTS[@]}"; do
    echo "| $DATE_ONLY | $script_label | Updated | Reference regenerated via update_references.sh |" >> "$LOG"
  done
  echo ""
  echo "Updated REFERENCE_LOG.md with $UPDATED entries."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " UPDATE SUMMARY"
echo "========================================"
echo " Updated : $UPDATED script(s)"
echo " Skipped : $SKIPPED script(s)"
echo " Failed  : $FAILED script(s)"
echo ""

if [[ $UPDATED -gt 0 ]]; then
  echo " Updated scripts:"
  for s in "${UPDATED_SCRIPTS[@]}"; do
    echo "   - $s"
  done
  echo ""
fi

if [[ $FAILED -gt 0 ]]; then
  echo " WARNING: Some scripts failed. Check that required packages are installed."
  echo " Install Python packages: pip install -r requirements.txt (or conda env)"
  echo " Install R packages: see renv.lock or environment.yaml"
fi

echo "========================================"
echo " Reference outputs saved to: $REF_DIR/"
echo "========================================"
