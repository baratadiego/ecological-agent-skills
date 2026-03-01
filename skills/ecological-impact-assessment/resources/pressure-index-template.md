# Anthropogenic Pressure Index — Template and Data Sources

## Concept

A composite pressure index aggregates multiple threatening processes into a single spatial layer representing cumulative human impact on biodiversity. Each pressure layer is normalised (0–1) and combined as a weighted sum.

## Standard Pressure Layers

| Pressure | Proxy variable | Resolution | Source |
|---------|---------------|-----------|--------|
| Land conversion | % natural habitat remaining | 30 m | MapBiomas / ESA CCI |
| Road proximity | Distance to paved roads (inverted) | 100 m | OpenStreetMap / DNIT |
| Human density | Population density | 100 m | WorldPop |
| Agricultural intensity | Cropland + pasture density | 30 m | MapBiomas |
| Fire frequency | Fire count per year (MODIS/VIIRS) | 500 m | INPE BDQueimadas |
| Deforestation rate | Annual forest loss | 30 m | PRODES / Hansen GFC |
| Human footprint | Composite human impact | 1 km | Wildlife Conservation Society (2022) |
| Night-time lights | Light pollution (VIIRS DNB) | 500 m | NASA Black Marble |
| Fragmentation | 1 − MESH (normalised) | Derived | landscapemetrics |

## Normalisation Method

For each pressure layer P_i:

P_norm = (P_i − P_min) / (P_max − P_min)

where P_min and P_max are the 1st and 99th percentiles of values within the study area (use percentiles to reduce outlier influence).

For distance-based layers (e.g., distance to roads), invert after normalisation:
P_norm = 1 − [(dist − dist_min) / (dist_max − dist_min)]

## Weighted Combination

```
Pressure_Index = Σ(w_i × P_norm_i) / Σ(w_i)
```

Default equal weights: w_i = 1 for all layers.

Justify custom weights with literature or expert elicitation. Document all weights in `params.yaml`.

## Classification Thresholds (default)

| Pressure class | Pressure_Index range |
|---------------|---------------------|
| Low | 0.00 – 0.25 |
| Moderate | 0.25 – 0.50 |
| High | 0.50 – 0.75 |
| Critical | 0.75 – 1.00 |

## R Code Template

```r
library(terra)

# Load normalised pressure layers (all same extent, CRS, resolution)
layers <- rast(c("road_proximity_norm.tif",
                 "pop_density_norm.tif",
                 "fire_frequency_norm.tif",
                 "deforestation_norm.tif",
                 "habitat_loss_norm.tif"))

# Equal weights
weights <- rep(1, nlyr(layers))
pressure_index <- weighted.mean(layers, w = weights)

# Classify
m <- matrix(c(0, 0.25, 1,
              0.25, 0.50, 2,
              0.50, 0.75, 3,
              0.75, 1.00, 4), ncol = 3, byrow = TRUE)
pressure_class <- classify(pressure_index, m)
levels(pressure_class) <- data.frame(id = 1:4,
  class = c("Low", "Moderate", "High", "Critical"))

writeRaster(pressure_index, "outputs/pressure_index.tif", overwrite = TRUE)
writeRaster(pressure_class, "outputs/pressure_class.tif", overwrite = TRUE)
```
