# Example Invocation Prompts — environmental-time-series

## NDVI Trend and Breakpoint Analysis

```
Load skill: environmental-time-series
Task: Analyse long-term NDVI trends in the Cerrado (2001–2023) from MODIS MOD13A3.

Input: data/ndvi_monthly_cerrado.csv
  Columns: date (YYYY-MM-DD), pixel_id, ndvi (0–1 scaled)

Steps:
1. STL decomposition (period = 12 months).
2. Mann-Kendall trend test + Sen's slope per pixel (or aggregated if single site).
3. BFAST breakpoint detection (h = 0.15, season = "harmonic").
4. Standardised anomaly relative to 2001–2010 baseline.
5. Report: trend slope (NDVI/year), breakpoint dates, anomaly time series.
Output: trend_results.csv, breakpoints.csv, decomposition_plot.png, anomaly_series.csv
```

## Post-Fire Recovery

```
Load skill: environmental-time-series
Task: Estimate vegetation recovery trajectory after the 2020 fires in the Pantanal.
Fire event date: 2020-07-01.
Pre-fire baseline: 2015-01-01 to 2020-06-30.
Data: data/ndvi_pantanal_recovery.csv (monthly NDVI per burned polygon, 2015–2023)

Fit recovery curve (logistic or exponential).
Compute: Recovery Indicator (RI) per year, estimated time to 80% and 100% recovery.
Output: recovery_metrics.csv, recovery_curves.png
```
