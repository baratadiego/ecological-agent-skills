#!/usr/bin/env python3
"""
recovery_trajectory.py
Estimate post-disturbance vegetation recovery trajectory.
Usage: python recovery_trajectory.py <timeseries_csv> <disturbance_date> <output_dir>
Requires: pandas, numpy, scipy, matplotlib
"""
import sys
from pathlib import Path
from datetime import datetime
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

    dat = pd.read_csv(ts_file, parse_dates=[0])
    date_col = dat.columns[0]
    val_col  = "value" if "value" in dat.columns else dat.columns[-1]
    dist_dt  = pd.to_datetime(dist_date)

    pre  = dat[dat[date_col] <  dist_dt].copy()
    post = dat[dat[date_col] >= dist_dt].copy()
    print(f"Pre: {len(pre)} obs | Post: {len(post)} obs | Disturbance: {dist_date}")
    if len(pre) < 12:
        raise ValueError("Need ≥ 12 pre-disturbance observations.")

    # Baseline: last 24 pre-disturbance months
    recent_pre   = pre.tail(24)
    baseline_mean = recent_pre[val_col].mean()
    baseline_sd   = recent_pre[val_col].std()
    print(f"Baseline: {baseline_mean:.4f} ± {baseline_sd:.4f}")

    # Smoothed minimum
    smooth = uniform_filter1d(post[val_col].values, size=3)
    min_idx = np.nanargmin(smooth)
    min_val = smooth[min_idx]
    min_date = post[date_col].iloc[min_idx]
    print(f"Post-disturbance minimum: {min_val:.4f} at {min_date.date()}")

    # Recovery Indicator
    post = post.copy()
    post["RI"] = (post[val_col] - min_val) / (baseline_mean - min_val + 1e-10)
    post["t_months"] = ((post[date_col] - min_date).dt.days / 30.44).clip(lower=0)
    post.to_csv(output_dir / "recovery_indicator.csv", index=False)

    # Linear fit
    fit_df = post[post["t_months"] >= 0].dropna(subset=["RI"])
    slope, intercept, r, p_val, se = linregress(fit_df["t_months"], fit_df["RI"])
    r2 = r**2
    print(f"Linear fit: slope={slope:.5f}/month | R²={r2:.3f}")

    t_80  = round((0.80 - intercept) / slope, 1) if slope > 0 else None
    t_100 = round((1.00 - intercept) / slope, 1) if slope > 0 else None
    print(f"Estimated recovery: 80% at {t_80} months | 100% at {t_100} months")

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

    # Recovery plot
    t_range = np.linspace(0, fit_df["t_months"].max(), 200)
    ri_pred = intercept + slope * t_range
    fig, ax = plt.subplots(figsize=(8, 5))
    ax.axhline(1.0, linestyle="--", color="forestgreen", alpha=0.7, label="100% recovery")
    ax.axhline(0.8, linestyle="--", color="orange",      alpha=0.7, label="80% recovery")
    ax.scatter(fit_df["t_months"], fit_df["RI"], s=20, alpha=0.7, color="grey")
    ax.plot(fit_df["t_months"], fit_df["RI"], color="grey", linewidth=0.7)
    ax.plot(t_range, ri_pred, color="steelblue", linewidth=1.5,
            label=f"Linear fit R²={r2:.3f}")
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
    print(f"Outputs written to: {output_dir}")

if __name__ == "__main__":
    main()
