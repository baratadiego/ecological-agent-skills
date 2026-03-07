#!/usr/bin/env python3
# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

"""
trend_analysis.py
Mann-Kendall trend + Sen's slope + anomaly detection.
Usage: python trend_analysis.py <timeseries_csv> <output_dir> [frequency]
Requires: pandas, numpy, pymannkendall, matplotlib, scipy
"""
import logging
import sys
from datetime import datetime
from pathlib import Path

SKILL_NAME = "environmental-time-series"
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

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats

try:
    import pymannkendall as mk
    HAS_MK = True
except ImportError:
    HAS_MK = False
    logger.warning("pymannkendall not installed. Falling back to linear regression. pip install pymannkendall")


def seasonal_decompose_simple(values, freq):
    """Simple additive seasonal decomposition."""
    n = len(values)
    trend = pd.Series(values).rolling(window=freq, center=True, min_periods=1).mean().values
    detrended = values - trend
    seasonal = np.array([np.nanmean(detrended[i::freq]) for i in range(freq)])
    seasonal_full = np.tile(seasonal, n // freq + 1)[:n]
    remainder = values - trend - seasonal_full
    return trend, seasonal_full, remainder

def compute_anomalies(values, baseline_n):
    mu = np.nanmean(values[:baseline_n])
    sd = np.nanstd(values[:baseline_n])
    return (values - mu) / (sd + 1e-10)

def main():
    ts_file    = sys.argv[1] if len(sys.argv) > 1 else "data/ndvi_series.csv"
    output_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("outputs/timeseries")
    freq       = int(sys.argv[3]) if len(sys.argv) > 3 else 12
    output_dir.mkdir(parents=True, exist_ok=True)

    log_decision("ts_file", ts_file, "Input time series CSV")
    log_decision("freq", freq, "Expected seasonal frequency (12 = monthly annual cycle)")
    log_decision("output_dir", str(output_dir), "Directory for trend analysis outputs")

    if not Path(ts_file).exists():
        logger.error(
            "Input nao encontrado: %s\n"
            "  Causa provavel: passo anterior nao concluiu.\n"
            "  Skill anterior que deveria ter produzido este input: geoprocessing-for-ecology",
            ts_file
        )
        sys.exit(1)

    try:
        log_step(1, "Loading time series data")
        dat = pd.read_csv(ts_file)
        val_col = "value" if "value" in dat.columns else dat.columns[-1]
        values = dat[val_col].values.astype(float)
        logger.info("Series length: %d | Frequency: %d", len(values), freq)

        n_nan = int(np.sum(np.isnan(values)))
        if n_nan > 0:
            logger.warning(
                "%d NaN values detected in series. These will be ignored in statistical tests.",
                n_nan
            )

        log_step(2, "Running trend test (Mann-Kendall or linear regression)")
        # Mann-Kendall
        if HAS_MK:
            res = mk.original_test(values)
            logger.info(
                "Mann-Kendall: tau = %.4f | p = %.4f | slope = %.6f/obs",
                res.Tau, res.p, res.slope
            )
            log_decision("trend_method", "Mann-Kendall",
                         "Preferred non-parametric test for monotonic trends in ecological series")
            trend_df = pd.DataFrame({"tau": [res.Tau], "p_value": [res.p],
                                      "sens_slope": [res.slope],
                                      "trend": [res.trend]})
            trend_df.to_csv(output_dir / "trend_results.csv", index=False)
        else:
            log_decision("trend_method", "linear regression",
                         "Fallback — pymannkendall not available")
            slope, intercept, r, p, se = stats.linregress(np.arange(len(values)), values)
            logger.info(
                "Linear regression (MK unavailable): slope = %.6f | p = %.4f", slope, p
            )

        log_step(3, "Seasonal decomposition")
        # Decomposition
        if len(values) >= 2 * freq:
            trend_comp, seasonal_comp, remainder = seasonal_decompose_simple(values, freq)
            fig, axes = plt.subplots(4, 1, figsize=(10, 10), sharex=True)
            for ax, data, title in zip(axes, [values, trend_comp, seasonal_comp, remainder],
                                       ["Observed", "Trend", "Seasonal", "Remainder"]):
                ax.plot(data); ax.set_title(title); ax.grid(alpha=0.3)
            plt.suptitle("Time Series Decomposition")
            plt.tight_layout()
            plt.savefig(output_dir / "decomposition_plot.png", dpi=150)
            plt.close()
            logger.info("Decomposition plot saved to: %s", output_dir / "decomposition_plot.png")
        else:
            logger.warning(
                "Series length (%d) < 2 * freq (%d). Skipping seasonal decomposition.",
                len(values), 2 * freq
            )

        log_step(4, "Computing anomaly Z-scores")
        # Anomalies
        baseline_n = min(freq * 10, len(values) // 2)
        log_decision("baseline_n", baseline_n,
                     "First N observations used as anomaly baseline (min of 10 cycles, half series)")
        anomalies = compute_anomalies(values, baseline_n)
        dat["anomaly_z"] = anomalies

        n_extreme = int(np.sum(np.abs(anomalies) > 2))
        if n_extreme > 0:
            logger.warning(
                "%d observations exceed ±2 SD anomaly threshold — review for data quality or ecological extremes.",
                n_extreme
            )

        dat.to_csv(output_dir / "anomaly_series.csv", index=False)

        log_step(5, "Generating anomaly bar plot")
        fig, ax = plt.subplots(figsize=(10, 4))
        ax.bar(range(len(anomalies)), anomalies,
               color=np.where(anomalies < 0, "#d6604d", "#4393c3"), alpha=0.8)
        ax.axhline(-1.5, color="orange", linestyle="--", label="±1.5σ")
        ax.axhline(1.5, color="orange", linestyle="--")
        ax.axhline(-2, color="red", linestyle="--", label="±2σ")
        ax.axhline(2, color="red", linestyle="--")
        ax.set_xlabel("Time step"); ax.set_ylabel("Standardised anomaly (z)")
        ax.set_title(f"Anomalies (baseline = first {baseline_n} obs)")
        ax.legend(); plt.tight_layout()
        plt.savefig(output_dir / "anomaly_plot.png", dpi=150)
        plt.close()
        logger.info("Outputs written to: %s", output_dir)

    except FileNotFoundError as e:
        logger.error(
            "Input file not found: %s\n"
            "  Expected output from: geoprocessing-for-ecology\n"
            "  Check that previous step completed.",
            e
        )
        raise
    except Exception as e:
        logger.error("Unexpected error in trend analysis: %s", e)
        raise

if __name__ == "__main__":
    main()
