# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""predict_distribution.py — Predict species suitability from a trained sklearn model.

Usage:
    python predict_distribution.py <model_pkl> <predictor_tif> <output_dir>
                                   [--threshold MaxTSS|P10|MTP] [--scenario current]

Outputs:
    suitability_{scenario}.tif   Continuous suitability [0,1]
    binary_{scenario}.tif        Binary presence/absence
    mess_{scenario}.tif          Multivariate environmental similarity
    prediction_summary.csv       Area statistics
"""

import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "species-distribution-modeling"
_LOG_DIR   = Path("logs")
_LOG_DIR.mkdir(parents=True, exist_ok=True)
_log_file  = _LOG_DIR / f"skill_{SKILL_NAME}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] [" + SKILL_NAME + "] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(_log_file, encoding="utf-8"),
    ],
)
logger = logging.getLogger(SKILL_NAME)


def log_step(n: int, desc: str) -> None:
    logger.info("-- STEP %d: %s", n, desc)


def log_decision(var: str, val, why: str) -> None:
    logger.info("DECISION | %s = %s | %s", var, val, why)


import argparse
import csv
import pickle
import warnings

import numpy as np

try:
    import rasterio
    from rasterio.transform import from_bounds
except ImportError:
    logger.error("rasterio not installed. Run: pip install rasterio")
    sys.exit(1)

# ── Arguments ─────────────────────────────────────────────────────────────────
parser = argparse.ArgumentParser(description="SDM suitability prediction")
parser.add_argument("model_pkl",      help="Path to trained model (.pkl or .joblib)")
parser.add_argument("predictor_tif",  help="Multi-band GeoTIFF predictor stack")
parser.add_argument("output_dir",     help="Directory for outputs")
parser.add_argument("--threshold", default="MaxTSS",
                    choices=["MaxTSS", "P10", "MTP"],
                    help="Threshold method for binary map")
parser.add_argument("--scenario", default="current",
                    help="Label appended to output filenames")
args = parser.parse_args()

log_decision("threshold", args.threshold,
             "MaxTSS balances sensitivity/specificity; P10 conservative; MTP permissive")
log_decision("scenario", args.scenario, "Embedded in output filenames")

# ── Precondition checks ───────────────────────────────────────────────────────
if not Path(args.model_pkl).exists():
    logger.error(
        "Model file not found: %s\n"
        "  Causa provavel: sdm_pipeline.py nao foi executado ou falhou.\n"
        "  Skill anterior que deveria ter produzido este input: species-distribution-modeling",
        args.model_pkl,
    )
    sys.exit(1)

if not Path(args.predictor_tif).exists():
    logger.error(
        "Predictor stack not found: %s\n"
        "  Causa provavel: stack nao preparado.\n"
        "  Skill anterior que deveria ter produzido este input: geoprocessing-for-ecology",
        args.predictor_tif,
    )
    sys.exit(1)

Path(args.output_dir).mkdir(parents=True, exist_ok=True)

# ── Step 1: Load model ────────────────────────────────────────────────────────
log_step(1, "Loading model")
try:
    if args.model_pkl.endswith(".joblib"):
        import joblib
        model_obj = joblib.load(args.model_pkl)
    else:
        with open(args.model_pkl, "rb") as f:
            model_obj = pickle.load(f)
    logger.info("Model loaded: %s", type(model_obj).__name__)
except Exception as e:
    logger.error(
        "Falha ao carregar modelo: %s\n"
        "  Causa provavel: arquivo corrompido ou versao incompativel do sklearn.\n"
        "  Verifique: o modelo foi salvo com a mesma versao do sklearn.",
        e,
    )
    raise

# Support dict with 'model', 'threshold_values', 'training_ranges', 'feature_names'
if isinstance(model_obj, dict):
    model       = model_obj.get("model", model_obj)
    thresh_vals = model_obj.get("threshold_values", {})
    train_ranges= model_obj.get("training_ranges", None)
    feat_names  = model_obj.get("feature_names", None)
else:
    model       = model_obj
    thresh_vals = {}
    train_ranges= None
    feat_names  = None

# ── Step 2: Load predictor stack ──────────────────────────────────────────────
log_step(2, "Loading predictor raster stack")
try:
    with rasterio.open(args.predictor_tif) as src:
        meta        = src.meta.copy()
        band_data   = src.read()            # shape: (n_bands, rows, cols)
        nodata      = src.nodata
        transform   = src.transform
        crs         = src.crs
        band_names  = [src.descriptions[i] or f"band{i+1}" for i in range(src.count)]
    logger.info("Stack: %d bands, shape %s, CRS=%s", band_data.shape[0], band_data.shape[1:], crs)
except Exception as e:
    logger.error("Falha ao ler predictor stack: %s\n  Verifique: arquivo GeoTIFF valido com multiplas bandas.", e)
    raise

n_bands, rows, cols = band_data.shape
X = band_data.reshape(n_bands, -1).T        # (n_pixels, n_bands)

# Mask NoData pixels
if nodata is not None:
    valid_mask = ~np.any(band_data == nodata, axis=0).ravel()
else:
    valid_mask = ~np.any(np.isnan(band_data), axis=0).ravel()

log_decision("valid_pixels", int(valid_mask.sum()), "Pixels without NoData in all bands")

# ── Step 3: Predict suitability ───────────────────────────────────────────────
log_step(3, "Predicting suitability")
suitability = np.full(rows * cols, np.nan, dtype=np.float32)

try:
    X_valid = X[valid_mask]
    if hasattr(model, "predict_proba"):
        proba = model.predict_proba(X_valid)
        # Take probability of class 1 (presence)
        pos_idx = list(model.classes_).index(1) if hasattr(model, "classes_") else 1
        suitability[valid_mask] = proba[:, pos_idx].astype(np.float32)
    elif hasattr(model, "decision_function"):
        # SVM / similar — normalise to [0,1] with sigmoid
        raw = model.decision_function(X_valid)
        suitability[valid_mask] = (1 / (1 + np.exp(-raw))).astype(np.float32)
    else:
        suitability[valid_mask] = model.predict(X_valid).astype(np.float32)
    logger.info("Suitability range: [%.4f, %.4f]",
                float(np.nanmin(suitability)), float(np.nanmax(suitability)))
except Exception as e:
    logger.error("Unexpected error in suitability prediction: %s", e)
    raise

suit_map = suitability.reshape(rows, cols)

# Write suitability raster
suit_meta = meta.copy()
suit_meta.update(count=1, dtype="float32", nodata=-9999.0)
suit_file = Path(args.output_dir) / f"suitability_{args.scenario}.tif"
try:
    with rasterio.open(suit_file, "w", **suit_meta) as dst:
        suit_out = suit_map.copy()
        suit_out[~valid_mask.reshape(rows, cols)] = -9999.0
        dst.write(suit_out[np.newaxis, :, :])
    logger.info("Suitability raster saved: %s", suit_file)
except Exception as e:
    logger.error("Falha ao salvar suitability raster: %s\n  Verifique: permissao de escrita em %s.", e, args.output_dir)
    raise

# ── Step 4: Threshold → binary map ───────────────────────────────────────────
log_step(4, f"Binarising with threshold method: {args.threshold}")
if thresh_vals and args.threshold in thresh_vals:
    thresh = thresh_vals[args.threshold]
else:
    thresh = float(np.nanpercentile(suitability[valid_mask], 10))
    logger.warning("No threshold_values in model; using 10th percentile of suitability (%.4f)", thresh)

log_decision("threshold_value", round(thresh, 4), f"Derived via {args.threshold}")

binary_map = (suit_map >= thresh).astype(np.uint8)
binary_map[~valid_mask.reshape(rows, cols)] = 255   # nodata

bin_meta = meta.copy()
bin_meta.update(count=1, dtype="uint8", nodata=255)
bin_file = Path(args.output_dir) / f"binary_{args.scenario}.tif"
with rasterio.open(bin_file, "w", **bin_meta) as dst:
    dst.write(binary_map[np.newaxis, :, :])
logger.info("Binary map saved: %s (threshold=%.4f)", bin_file, thresh)

# ── Step 5: MESS ──────────────────────────────────────────────────────────────
log_step(5, "Computing MESS")
if train_ranges is not None:
    try:
        mess_vals = np.full(rows * cols, np.nan, dtype=np.float32)
        X_v       = X[valid_mask]
        in_range  = np.ones(len(X_v), dtype=np.float32)
        for j, nm in enumerate(feat_names or band_names):
            if nm in train_ranges:
                lo, hi = train_ranges[nm]["min"], train_ranges[nm]["max"]
                in_range *= ((X_v[:, j] >= lo) & (X_v[:, j] <= hi)).astype(np.float32)
        # in_range==0 → novel; map to negative score for convention
        mess_score = 2 * in_range - 1   # +1 = analogue, -1 = novel
        mess_vals[valid_mask] = mess_score

        mess_map_arr = mess_vals.reshape(rows, cols)
        mess_meta    = meta.copy()
        mess_meta.update(count=1, dtype="float32", nodata=-9999.0)
        mess_file = Path(args.output_dir) / f"mess_{args.scenario}.tif"
        with rasterio.open(mess_file, "w", **mess_meta) as dst:
            dst.write(mess_map_arr[np.newaxis, :, :])

        pct_novel = float(np.mean(mess_score < 0) * 100)
        if pct_novel > 20:
            logger.warning("%.1f%% of prediction area is in novel climate space (MESS < 0). Extrapolation risk is HIGH.", pct_novel)
        else:
            logger.info("MESS: %.1f%% novel climate space", pct_novel)
        logger.info("MESS raster saved: %s", mess_file)
    except Exception as e:
        logger.warning("MESS computation failed: %s. Skipping.", e)
else:
    logger.warning("No training_ranges in model object; MESS not computed.")

# ── Step 6: Summary CSV ───────────────────────────────────────────────────────
log_step(6, "Computing summary statistics")
total_px    = int(valid_mask.sum())
suitable_px = int(np.sum(binary_map[valid_mask.reshape(rows, cols)] == 1))

# Pixel area (approximate: assumes metres if large values, else degrees)
px_size_x = abs(transform.a)
px_size_y = abs(transform.e)
if px_size_x > 1:   # metres
    px_area_km2 = px_size_x * px_size_y / 1e6
else:               # degrees → rough km² at equator
    px_area_km2 = px_size_x * 111 * px_size_y * 111

area_total_km2 = total_px    * px_area_km2
area_suit_km2  = suitable_px * px_area_km2
pct_suit       = 100.0 * suitable_px / total_px if total_px > 0 else 0.0
mean_suit      = float(np.nanmean(suitability[valid_mask]))

summary = {
    "scenario":           args.scenario,
    "threshold_method":   args.threshold,
    "threshold_value":    round(thresh, 4),
    "total_area_km2":     round(area_total_km2, 1),
    "suitable_area_km2":  round(area_suit_km2, 1),
    "pct_suitable":       round(pct_suit, 2),
    "mean_suitability":   round(mean_suit, 4),
}

sum_file = Path(args.output_dir) / "prediction_summary.csv"
with open(sum_file, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(summary.keys()))
    w.writeheader(); w.writerow(summary)

logger.info("Suitable area: %.1f km2 (%.1f%% of %.1f km2)", area_suit_km2, pct_suit, area_total_km2)
logger.info("Summary saved: %s", sum_file)

log_step(7, "Done — all outputs in: %s", args.output_dir)


if __name__ == "__main__":
    pass   # argparse executed at module level above
