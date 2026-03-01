#!/usr/bin/env python3
"""
trend_analysis.py
Mann-Kendall trend + Sen's slope + anomaly detection.
Usage: python trend_analysis.py <timeseries_csv> <output_dir> [frequency]
Requires: pandas, numpy, pymannkendall, matplotlib, scipy
"""
import sys
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats

try:
    import pymannkendall as mk
    HAS_MK = True
except ImportError:
    HAS_MK = False
    print("pymannkendall not installed. pip install pymannkendall")

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

    dat = pd.read_csv(ts_file)
    val_col = "value" if "value" in dat.columns else dat.columns[-1]
    values = dat[val_col].values.astype(float)
    print(f"Series length: {len(values)} | Frequency: {freq}")

    # Mann-Kendall
    if HAS_MK:
        res = mk.original_test(values)
        print(f"\nMann-Kendall: tau = {res.Tau:.4f} | p = {res.p:.4f} | slope = {res.slope:.6f}/obs")
        trend_df = pd.DataFrame({"tau": [res.Tau], "p_value": [res.p],
                                  "sens_slope": [res.slope],
                                  "trend": [res.trend]})
        trend_df.to_csv(output_dir / "trend_results.csv", index=False)
    else:
        slope, intercept, r, p, se = stats.linregress(np.arange(len(values)), values)
        print(f"\nLinear regression (MK unavailable): slope = {slope:.6f} | p = {p:.4f}")

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

    # Anomalies
    baseline_n = min(freq * 10, len(values) // 2)
    anomalies = compute_anomalies(values, baseline_n)
    dat["anomaly_z"] = anomalies
    dat.to_csv(output_dir / "anomaly_series.csv", index=False)

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
    print(f"Outputs written to: {output_dir}")

if __name__ == "__main__":
    main()
