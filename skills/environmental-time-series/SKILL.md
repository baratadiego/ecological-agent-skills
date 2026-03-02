---
skill_version: 1.0.0
---

# Skill: environmental-time-series

**Domain:** Trend · Seasonality · Breakpoints · Anomalies · Recovery  
**Phase:** 2 — Modeling  
**Used by:** build-fire-risk-map, analyze-environmental-change

---

## Purpose

Guides the agent through the analysis of environmental and ecological time series: trend detection, seasonal decomposition, structural breakpoint identification, anomaly detection, and post-disturbance recovery trajectory estimation.

---

## When to Invoke

- Analysing NDVI, EVI, LST, rainfall, or any environmental time series
- Detecting trend direction and magnitude in ecological indicators
- Identifying regime shifts or abrupt changes in a time series
- Characterising anomalies relative to historical baseline
- Estimating recovery time after a disturbance event

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Time-indexed environmental variable | CSV or GeoTIFF time stack | Yes |
| Time series frequency (daily, monthly, annual) | Text | Yes |
| Disturbance event date (for recovery) | Date | Conditional |
| Historical baseline period | Date range | Recommended |

---

## Outputs

| Output | Description |
|--------|-------------|
| `trend_results.csv` | Trend slope, magnitude, p-value per pixel or site |
| `seasonal_decomposition.png` | STL decomposition plot |
| `breakpoints.csv` | Detected breakpoint dates with confidence intervals |
| `anomaly_series.csv` | Standardised anomaly per time step |
| `recovery_metrics.csv` | Recovery rate and 80/100% recovery date |
| `timeseries_report.md` | Analysis narrative |

---

## Steps

### 1. Inspect and Clean the Series
- Plot raw series; identify obvious outliers, data gaps, sensor artifacts
- Interpolate short gaps (≤ 3 steps) if justified; document method
- Report temporal extent, frequency, and missing value rate

### 2. Trend Detection
- Mann-Kendall test for monotonic trend (non-parametric, handles non-normality)
- Sen's slope estimator for trend magnitude
- For raster: pixel-wise MK + Sen's slope
- Report τ (Kendall's tau), p-value, and slope in original units/year

### 3. Seasonal Decomposition
- STL decomposition (Seasonal-Trend decomposition using LOESS): robust to outliers
- Report seasonal amplitude, trend component, and remainder
- For annual data with no seasonality, skip this step

### 4. Breakpoint Detection
- BFAST (Breaks For Additive Season and Trend): simultaneous trend and breakpoint
- `strucchange` (R) for structural change tests
- Report: number of breakpoints, dates, 95% CIs
- Verify detected breakpoints against known events (fire, drought, deforestation)

### 5. Anomaly Detection
- Compute historical baseline (mean ± SD or percentiles) from reference period
- Standardised anomaly: z = (x − μ) / σ
- Flag values beyond ±2σ as anomalous
- For rainfall: SPI (Standardised Precipitation Index)
- For vegetation: VCI (Vegetation Condition Index) or zNDVI

### 6. Recovery Trajectory (post-disturbance)
- Define pre-disturbance baseline from N years before event
- Fit recovery curve: linear, exponential, or logistic
- Estimate: time to 80% recovery, time to full recovery
- Compute Recovery Indicator (RI) = (post − min) / (pre − min)

---

## Key Decisions to Document

- Baseline period definition
- Gap interpolation method
- Seasonal decomposition method and parameters
- Breakpoint detection method and significance level
- Anomaly threshold (z-score cutoff)
- Recovery model type

---

## Tools and Libraries

**R:** `bfast`, `strucchange`, `trend`, `zoo`, `terra`, `ggplot2`  
**Python:** `pymannkendall`, `ruptures`, `statsmodels.tsa`, `xarray`  
**Remote sensing:** Google Earth Engine (pixel-wise BFAST, trend)

---

## Resources

- `resources/bfast-parameter-guide.md` — how to set h, season, and type in BFAST
- `resources/anomaly-indices-reference.md` — SPI, VCI, zNDVI definitions
- `examples/` — worked BFAST and recovery analysis example

---

## Notes

- Autocorrelation in time series violates independence assumptions of standard tests; use MK which handles it
- BFAST requires at least 3 full seasonal cycles to be reliable
- For raster time series > 10 years monthly, consider GEE for computational efficiency
