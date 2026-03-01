# RUSLE Factor Reference

The Revised Universal Soil Loss Equation estimates annual soil loss:

**A = R × K × LS × C × P**

where A = soil loss (t/ha/yr).

## R Factor — Rainfall Erosivity (MJ·mm/ha/h/yr)

| Region (Brazil) | Typical R range | Source |
|----------------|----------------|--------|
| Amazon (high rainfall) | 8,000–12,000 | Panagos et al. 2017 |
| Cerrado | 5,000–9,000 | Oliveira et al. 2013 |
| Atlantic Forest coast | 6,000–10,000 | |
| Semi-arid Northeast | 1,000–3,000 | |
| Southern Brazil | 5,000–8,000 | |

Available layer: Global Rainfall Erosivity Database (ESDAC / Panagos et al. 2017)  
DOI: 10.1016/j.scitotenv.2017.06.199

## K Factor — Soil Erodibility (t·ha·h/ha/MJ/mm)

| Soil texture | K range | Notes |
|-------------|---------|-------|
| Sandy / coarse | 0.01–0.10 | Low erodibility |
| Loamy sand | 0.05–0.15 | |
| Sandy loam | 0.10–0.25 | |
| Loam | 0.15–0.35 | Moderate |
| Silt loam | 0.25–0.45 | High |
| Clay loam | 0.20–0.40 | |
| Clay | 0.10–0.30 | Cohesive; lower K |
| Organic / Latosol | 0.01–0.08 | Low despite fine texture |

Source: SoilGrids 2.0 provides K factor globally at 250 m.

## LS Factor — Slope Length × Steepness

Computed from DEM using:

```r
library(terra)
library(whitebox)
dem <- rast("dem.tif")
wbt_slope(input = "dem.tif", output = "slope.tif", units = "degrees")
# LS factor: use standard RUSLE LS equations via saga or whitebox
```

Or use the pre-computed global LS factor from Panagos et al. 2015.

## C Factor — Cover Management (key for ES assessment)

The C factor represents the effect of land cover and management on soil erosion relative to bare fallow.

| Land cover (MapBiomas) | C factor |
|-----------------------|---------|
| Dense Amazon forest | 0.0001 |
| Open tropical forest | 0.001 |
| Savanna (Cerrado) | 0.01–0.05 |
| Secondary forest (old) | 0.005 |
| Secondary forest (young) | 0.05 |
| Planted pasture (good) | 0.01 |
| Planted pasture (degraded) | 0.25–0.50 |
| Annual crops (soy/corn) | 0.20–0.40 |
| Sugarcane | 0.15 |
| Natural wetland | 0.001 |
| Mangrove | 0.00001 |
| Bare soil / exposed rock | 1.00 |
| Urban | 0.00 (no erosion model) |

## P Factor — Support Practices

| Practice | P factor |
|---------|---------|
| No practice (default) | 1.00 |
| Contour farming | 0.50–0.75 |
| Terracing | 0.10–0.50 |
| Strip cropping | 0.35–0.70 |

Default P = 1.0 for natural landscapes (no agricultural support practices).

## Avoided Soil Loss (ES Indicator)

Erosion control service = A_bare − A_vegetated

where A_bare = soil loss if bare soil (C = 1, P = 1) and A_vegetated = actual soil loss.

This difference represents the erosion that the current vegetation is preventing.
