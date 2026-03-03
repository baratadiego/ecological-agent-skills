#!/usr/bin/env python3
"""
recovery_trajectory.py
Estimate post-disturbance vegetation recovery trajectory.
Usage: python recovery_trajectory.py <timeseries_csv> <disturbance_date> <output_dir>
Requires: pandas, numpy, scipy, matplotlib
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
from scipy.stats import linregress
from scipy.ndimage import uniform_filter1d


def main():
    ts_file    = sys.argv[1] if len(sys.argv) > 1 else "tests/data/ndvi_monthly_series.csv"
    dist_date  = sys.argv[2] if len(sys.argv) > 2 else "2010-01-01"
    output_dir = Path(sys.argv[3]) if len(sys.argv) > 3 else Path("outputs/recovery")
    output_dir.mkdir(parents=True, exist_ok=True)

    log_decision("ts_file", ts_file, "Input time series CSV")
    log_decision("dist_date", dist_date, "Disturbance event date for pre/post split")
    log_decision("output_dir", str(output_dir), "Directory for recovery outputs")

    if not Path(ts_file).exists():
        logger.error(
            "Input nao encontrado: %s\n"
            "  Causa provavel: passo anterior nao concluiu.\n"
            "  Skill anterior que deveria ter produzido este input: geoprocessing-for-ecology",
            ts_file
        )
        sys.exit(1)

    try:
        log_step(1, "Loading and splitting time series at disturbance date")
        dat = pd.read_csv(ts_file, parse_dates=[0])
        date_col = dat.columns[0]
        val_col  = "value" if "value" in dat.columns else dat.columns[-1]
        dist_dt  = pd.to_datetime(dist_date)

        pre  = dat[dat[date_col] <  dist_dt].copy()
        post = dat[dat[date_col] >= dist_dt].copy()
        logger.info("Pre: %d obs | Post: %d obs | Disturbance: %s", len(pre), len(post), dist_date)
        if len(pre) < 12:
            raise ValueError("Need >= 12 pre-disturbance observations.")
        if len(post) == 0:
            logger.warning("No post-disturbance observations found. Recovery metrics will be empty.")

        log_step(2, "Computing pre-disturbance baseline (last 24 months)")
        # Baseline: last 24 pre-disturbance months
        recent_pre   = pre.tail(24)
        baseline_mean = recent_pre[val_col].mean()
        baseline_sd   = recent_pre[val_col].std()
        log_decision("baseline_window", 24,
                     "Last 24 pre-disturbance observations used as baseline reference period")
        logger.info("Baseline: %.4f +/- %.4f", baseline_mean, baseline_sd)

        log_step(3, "Detecting post-disturbance minimum via smoothed series")
        # Smoothed minimum
        smooth = uniform_filter1d(post[val_col].values, size=3)
        min_idx = np.nanargmin(smooth)
        min_val = smooth[min_idx]
        min_date = post[date_col].iloc[min_idx]
        logger.info("Post-disturbance minimum: %.4f at %s", min_val, min_date.date())

        log_step(4, "Computing Recovery Indicator (RI) and linear fit")
        # Recovery Indicator
        post = post.copy()
        post["RI"] = (post[val_col] - min_val) / (baseline_mean - min_val + 1e-10)
        post["t_months"] = ((post[date_col] - min_date).dt.days / 30.44).clip(lower=0)
        post.to_csv(output_dir / "recovery_indicator.csv", index=False)

        # Linear fit
        fit_df = post[post["t_months"] >= 0].dropna(subset=["RI"])
        slope, intercept, r, p_val, se = linregress(fit_df["t_months"], fit_df["RI"])
        r2 = r**2
        logger.info("Linear fit: slope=%.5f/month | R2=%.3f", slope, r2)

        t_80  = round((0.80 - intercept) / slope, 1) if slope > 0 else None
        t_100 = round((1.00 - intercept) / slope, 1) if slope > 0 else None
        logger.info("Estimated recovery: 80%% at %s months | 100%% at %s months", t_80, t_100)
        if slope <= 0:
            logger.warning(
                "Recovery slope is non-positive (slope=%.5f). "
                "Vegetation may not be recovering — review disturbance date or data quality.",
                slope
            )

        log_step(5, "Saving recovery metrics CSV")
        metrics = pd.DataFrame([{
            "baseline_mean": round(baseline_mean, 4),
            "baseline_sd":   round(baseline_sd, 4),
            "disturbance_date": dist_date,
            "post_minimum_value": round(float(min_val), 4),
            "post_minimum_date": str(min_date.date()),
            "magnitude_decline_pct": round((baseline_mean - min_val)/baseline_mean*100, 2),
            "RI_current": round(float(post["RI"].iloc[-1]), 4),
            "slope_linear": round(slope, 6),
            "r2_linear": round(r2, 4),
            "t_to_80pct_months": t_80,
            "t_to_100pct_months": t_100,
        }])
        metrics.to_csv(output_dir / "recovery_metrics.csv", index=False)

        log_step(6, "Generating recovery trajectory and context plots")
        # Recovery plot
        t_range = np.linspace(0, fit_df["t_months"].max(), 200)
        ri_pred = intercept + slope * t_range
        fig, ax = plt.subplots(figsize=(8, 5))
        ax.axhline(1.0, linestyle="--", color="forestgreen", alpha=0.7, label="100% recovery")
        ax.axhline(0.8, linestyle="--", color="orange",      alpha=0.7, label="80% recovery")
        ax.scatter(fit_df["t_months"], fit_df["RI"], s=20, alpha=0.7, color="grey")
        ax.plot(fit_df["t_months"], fit_df["RI"], color="grey", linewidth=0.7)
        ax.plot(t_range, ri_pred, color="steelblue", linewidth=1.5,
                label=f"Linear fit R2={r2:.3f}")
        ax.set_xlabel("Months since post-disturbance minimum")
        ax.set_ylabel("Recovery Indicator (RI)")
        ax.set_title(f"Recovery Trajectory — disturbance: {dist_date}")
        ax.legend(); plt.tight_layout()
        plt.savefig(output_dir / "recovery_trajectory.png", dpi=150)
        plt.close()

        # Context plot
        fig2, ax2 = plt.subplots(figsize=(10, 4))
        ax2.plot(dat[date_col], dat[val_col], color="grey", linewidth=0.8)
        ax2.axvline(dist_dt, color="red", linestyle="--", linewidth=1, label="Disturbance")
        ax2.axhline(baseline_mean, color="forestgreen", linestyle=":", linewidth=1,
                    label=f"Baseline ({baseline_mean:.3f})")
        ax2.set_xlabel("Date"); ax2.set_ylabel(val_col)
        ax2.set_title("Full Time Series with Disturbance Event")
        ax2.legend(); plt.tight_layout()
        plt.savefig(output_dir / "timeseries_context.png", dpi=150)
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
        logger.error("Unexpected error in recovery trajectory analysis: %s", e)
        raise

if __name__ == "__main__":
    main()
