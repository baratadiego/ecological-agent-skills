# Calibration Area (M Area) Selection Guide

The calibration area (M, accessible area, or training region) defines the geographic extent from which background or pseudo-absence points are sampled and within which the model is calibrated. It is one of the most consequential decisions in SDM.

## Why M Matters

- Background points sampled outside M misrepresent the environmental conditions available to the species
- An M that is too large includes environments never accessible to the species → inflated model performance, incorrect niche characterisation
- An M that is too small may omit accessible habitats → truncated niche, poor transferability

## Common Delimitation Methods

### 1. Biotic Region / Biome
Use biogeographic boundaries (biome, ecoregion) that match the species' known biogeographic history.
- **Best for:** Continental or regional studies with well-known biogeographic context
- **R:** IBGE biome polygons, WWF Ecoregions (rnaturalearth)

### 2. Minimum Convex Hull (MCP) + Buffer
Convex hull around all occurrence points, expanded by a fixed buffer distance (e.g., 200–500 km).
- **Best for:** Species with limited occurrence data; simple implementation
- **Caution:** Can include barriers (oceans, mountain ranges) that limit dispersal

```r
library(sf)
occ_sf <- st_as_sf(occ, coords = c("decimalLongitude","decimalLatitude"), crs = 4326)
hull   <- st_convex_hull(st_union(occ_sf))
M_area <- st_buffer(hull, dist = 200000)  # 200 km buffer
```

### 3. Dispersal Simulation (Circuitscape / BioModelos)
Model the area reachable by the species over a defined time period given dispersal rate and landscape permeability.
- **Best for:** Species with known dispersal capacity; connectivity studies

### 4. Watershed / Drainage Basin (aquatic species)
- **Best for:** Freshwater fish, invertebrates, plants with hydrological dispersal

### 5. Political / Administrative Unit
Use only when the species is genuinely limited to that unit (e.g., island endemics).
- **Avoid for:** Most terrestrial species with cross-border ranges

## Recommended Workflow

1. Start with the known biome or ecoregion containing all occurrences
2. Expand by one adjacent ecoregion or 200–500 km buffer to include accessible but unsampled habitats
3. Clip to ecologically meaningful barriers (e.g., remove ocean from terrestrial species M)
4. Verify that the background environment within M spans the full range of occurrence conditions (convex hull check in environmental space)

## Environmental Space Check

```r
library(terra)
env_bg   <- extract(predictor_stack, bg_points)
env_occ  <- extract(predictor_stack, occ_points)

# Check: are all occurrence environmental conditions within the background range?
for (v in names(env_bg)) {
  occ_range <- range(env_occ[[v]], na.rm = TRUE)
  bg_range  <- range(env_bg[[v]], na.rm = TRUE)
  cat(v, "| occ:", round(occ_range, 2),
      "| bg:", round(bg_range, 2), "\n")
}
# If occ range exceeds bg range → M is too small for that variable
```

## Reporting

Always report:
- M delimitation method and rationale
- Area of M in km²
- Proportion of occurrences inside M (should be 100%)
- Environmental coverage (does bg span all occurrence conditions?)
