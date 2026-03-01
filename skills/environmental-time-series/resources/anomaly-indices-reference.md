# Environmental Anomaly Indices Reference

## Standardised Precipitation Index (SPI)

Measures rainfall deficit/surplus relative to a long-term distribution, at multiple time scales.

| SPI value | Category |
|-----------|---------|
| > 2.0 | Extremely wet |
| 1.5 to 2.0 | Very wet |
| 1.0 to 1.5 | Moderately wet |
| -1.0 to 1.0 | Near normal |
| -1.5 to -1.0 | Moderately dry |
| -2.0 to -1.5 | Severely dry |
| < -2.0 | Extremely dry |

Time scales: SPI-1 (monthly), SPI-3 (seasonal), SPI-6, SPI-12 (annual drought).

```r
library(SPEI)
data(wichita)  # example dataset
spi_3 <- spi(wichita$PRCP, scale = 3)
plot(spi_3)
```

## Standardised Precipitation Evapotranspiration Index (SPEI)

Like SPI but accounts for evapotranspiration (temperature effect). Better for drought assessment under warming climate.

```r
spei_12 <- spei(wichita$PRCP - wichita$PET, scale = 12)
```

## Vegetation Condition Index (VCI)

Normalises NDVI relative to historical minimum and maximum for the same period of year.

VCI = 100 × (NDVI − NDVI_min) / (NDVI_max − NDVI_min)

| VCI | Vegetation condition |
|-----|---------------------|
| 0–10 | Extreme stress |
| 10–20 | Severe stress |
| 20–40 | Moderate stress |
| 40–60 | Good condition |
| 60–80 | Very good |
| 80–100 | Excellent |

```python
import numpy as np
# NDVI time stack (time × lat × lon)
vci = 100 * (ndvi - ndvi.min(axis=0)) / (ndvi.max(axis=0) - ndvi.min(axis=0) + 1e-6)
```

## Standardised NDVI Anomaly (zNDVI)

zNDVI = (NDVI_i − μ_NDVI) / σ_NDVI

where μ and σ are computed per pixel over the baseline period (same calendar period).

Interpretation: zNDVI < -1.5 indicates vegetation stress; zNDVI < -2.0 indicates severe anomaly.

## Temperature Anomaly

T_anomaly = T_i − T_climatological_mean (for the same month/season)

## Recovery Indicator (RI)

Post-disturbance vegetation recovery relative to pre-disturbance baseline:

RI_t = (NDVI_t − NDVI_min) / (NDVI_pre − NDVI_min)

- RI = 0: at the lowest post-disturbance value
- RI = 1: full recovery to pre-disturbance level
- RI < 0: further decline after disturbance
- RI > 1: exceeds pre-disturbance level (e.g., fire-stimulated flush)

## Reference Datasets

| Variable | Product | Resolution | Source |
|----------|---------|-----------|--------|
| NDVI (8-day) | MODIS MOD13Q1 | 250 m | NASA LP DAAC |
| NDVI (monthly) | MODIS MOD13A3 | 1 km | NASA LP DAAC |
| NDVI (daily, 10 m) | Sentinel-2 (Harmonized) | 10 m | Copernicus / GEE |
| Rainfall | CHIRPS v2.0 | 5 km | UCSB Climate Hazards Group |
| Rainfall | ERA5-Land | 9 km | ECMWF |
| LST | MODIS MOD11A2 | 1 km | NASA LP DAAC |
| SPI | Global SPEI Database | 0.5° | CSIC Spain |
