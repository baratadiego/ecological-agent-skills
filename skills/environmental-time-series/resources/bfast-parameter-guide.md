# BFAST Parameter Guide

BFAST (Breaks For Additive Season and Trend) detects breakpoints in both the seasonal and trend components of a time series simultaneously.

## Key Parameters

### `h` — Minimum Segment Size
Minimum proportion of observations between two consecutive breakpoints.
- Default: `h = 0.15` (15% of n observations)
- Example: for n = 120 monthly observations, h = 0.15 means ≥ 18 observations per segment (≥ 1.5 years)
- **Set smaller** if breakpoints may occur close together
- **Set larger** to avoid detecting noise as breakpoints

### `season` — Seasonal Model
- `"harmonic"`: Fourier terms (sine + cosine); recommended for MODIS NDVI, temperature
- `"dummy"`: Dummy variables for each period; less flexible
- `"none"`: No seasonal component; for annual time series

### `max.iter` — Maximum Iterations
- Default: `max.iter = 10`
- Increase to 20–50 for complex time series that do not converge quickly

### `breaks` — Maximum Number of Breakpoints
- Default: `NULL` (auto-select by BIC)
- Set `breaks = 1` to force detection of at most 1 breakpoint
- Set `breaks = 5` for long series with multiple expected events

### `type` — Type of Breakpoint Test
- `"OLS-MOSUM"` (default): Fast; appropriate for most cases
- `"OLS-CUSUM"`: More sensitive to gradual changes
- `"DYNP"`: Dynamic programming; exact but slow for large n

## Typical MODIS NDVI Configuration

```r
library(bfast)

# Monthly NDVI time series (16-day composites aggregated to monthly)
ts_ndvi <- ts(ndvi_vector, start = c(2000, 1), frequency = 12)

fit <- bfast(ts_ndvi,
             h        = 0.15,
             season   = "harmonic",
             max.iter = 20,
             breaks   = NULL)

# Extract results
if (fit$output[[1]]$Tt.bp > 0) {  # breakpoints detected
  bp_dates <- fit$output[[1]]$bp.Vt$breakpoints
  cat("Breakpoints at observations:", bp_dates, "\n")
}

plot(fit)
```

## Interpreting Outputs

| Component | Meaning |
|-----------|---------|
| `Tt` | Trend component with breakpoints |
| `St` | Seasonal component with breakpoints |
| `Nt` | Remainder (noise) |
| `bp.Vt` | Trend breakpoints (indices) |
| `bp.Wt` | Seasonal breakpoints (indices) |

## Minimum Series Length
- At least **3 full seasonal cycles** are required
- For monthly data: ≥ 36 observations (3 years)
- For 16-day MODIS: ≥ 69 observations (≥ 3 years)
