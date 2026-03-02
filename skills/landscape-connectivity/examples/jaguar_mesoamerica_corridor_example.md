---
skill_id: landscape-connectivity
example_type: full_walkthrough
taxon: Jaguar (Panthera onca)
region: Mesoamerican Biological Corridor
---

# Jaguar Corridor Analysis — Mesoamerican Biological Corridor Walkthrough

## Study Context

**Location:** Guatemala–Honduras–Nicaragua corridor, Mesoamerican Biological Corridor (MBC)
**Objective:** Identify critical habitat patches and movement corridors for jaguars along the MBC; prioritise areas for protection and restoration
**Input data:**
- Forest cover 2023 (30-m resolution, derived from Global Forest Watch)
- Land cover map (11 classes, 30-m resolution)
- DEM (SRTM 30 m)
- Road network (OSM)
- 124 camera trap stations with jaguar detections (occupancy data)

---

## Step 1 — Build Resistance Surface

### Resistance table (jaguar-specific)

```
data/jaguar_resistance.csv:
lc_code, resistance, description
1,  1,   Dense tropical forest
2,  3,   Secondary forest
3,  5,   Riparian gallery forest
4,  8,   Cerrado/savanna
5, 15,   Shrubland
6, 25,   Pasture (low density)
7, 50,   Pasture (high density)
8, 80,   Paved road
9,200,   Highway
10,500,  Urban
11, 10,  Wetland/swamp
```

```bash
Rscript resistance_surface.R \
  data/landcover_2023_mbc.tif \
  data/jaguar_resistance.csv \
  outputs/resistance/ \
  data/dem_srtm_30m.tif \
  data/roads_osm.shp
```

**Output statistics:**

| Statistic | Value |
|-----------|-------|
| Min resistance | 1.0 |
| Median | 8.3 |
| Mean | 24.7 |
| Q95 | 95.4 |
| Max (capped) | 1000.0 |

**Decision:** Highway cells assigned resistance = 200 (not 1000) for this analysis, because jaguars have been documented crossing highways via culverts at night. Decision logged with citation (Quigley & Crawshaw 1992).

---

## Step 2 — Delineate Forest Patches

```r
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))

forest <- rast("data/forest_cover_2023_mbc.tif")
# Patches: connected forest cells ≥ 500 ha
patches_r <- patches(forest == 1, directions = 8)
# Compute patch sizes
patch_sizes <- freq(patches_r)
large_patches <- patch_sizes[patch_sizes$count * 0.09 >= 500, ]  # 30m² = 0.0009 ha
forest_patches <- as.polygons(patches_r %in% large_patches$value)
forest_patches_sf <- st_as_sf(forest_patches)
forest_patches_sf$area_ha <- as.numeric(st_area(forest_patches_sf)) / 1e4
```

**Result:** 214 forest patches ≥ 500 ha identified.
- Median patch area: 1,240 ha
- Largest patch: 312,000 ha (Maya Biosphere Reserve)
- Range: 502–312,000 ha

---

## Step 3 — Graph Connectivity Analysis

### Sensitivity analysis across dispersal distances

```bash
# Jaguar max dispersal: 50–500 km reported; use range 20–80 km
for dmax in 20000 50000 80000; do
  Rscript connectivity_metrics.R \
    data/forest_patches_500ha.shp \
    outputs/connectivity/dmax_${dmax}/ \
    $dmax \
    area_ha
done
```

**Sensitivity results:**

| dmax (m) | IIC | PC | n_components | Largest component |
|----------|-----|----|----|---|
| 20,000 | 0.0412 | 0.0389 | 18 | 71 patches |
| 50,000 | 0.0847 | 0.0814 | 7  | 142 patches |
| 80,000 | 0.1183 | 0.1156 | 3  | 198 patches |

**Interpretation:** At all dispersal distances, landscape connectivity is < 0.12 — indicating high fragmentation. The MBC is not functionally connected for jaguars across most of its length.

**Decision:** Analysis proceeds with dmax = 50,000 m (50 km), representing conservative mid-range jaguar dispersal (Rabinowitz & Zeller 2010).

### Top patches by dPC

```r
metrics <- read.csv("outputs/connectivity/dmax_50000/patch_metrics.csv")
head(metrics[, c("patch_id", "area_ha", "dPC_pct", "BC_norm")], 10)
```

| patch_id | area_ha | dPC (%) | BC (norm) |
|----------|---------|---------|-----------|
| P001 | 312,000 | 18.4 | 0.42 |
| P017 | 85,200  | 12.1 | 0.38 |
| P003 | 142,100 | 9.7  | 0.29 |
| P089 | 8,400   | **7.2** | **0.81** |
| P122 | 3,200   | 5.1  | 0.76 |
| P071 | 12,800  | 4.8  | 0.67 |

**Key finding:** Patch P089 (8,400 ha) has disproportionately high dPC (7.2%) and betweenness centrality (0.81) relative to its size. It is a **stepping stone** connecting the two largest forest blocks. High BC = critical corridor function.

---

## Step 4 — Circuitscape Current Flow

```r
source("scripts/run_circuitscape.R")

# Use top 20 patches by dPC as focal nodes
focal_patches <- metrics[1:20, "patch_id"]
focal_shp <- forest_patches_sf[forest_patches_sf$patch_id %in% focal_patches, ]
st_write(focal_shp, "data/focal_nodes.shp", delete_dsn = TRUE)

cur_map <- run_circuitscape(
  resistance_tif  = "outputs/resistance/resistance_combined.tif",
  focal_points_shp = "data/focal_nodes.shp",
  output_dir      = "outputs/circuitscape/",
  scenario        = "pairwise"
)
```

**Pinch point extraction:**

```r
cur <- rast("outputs/circuitscape/cs_output_cum_curmap.asc")
q95 <- quantile(values(cur), 0.95, na.rm = TRUE)
pinch <- cur >= q95
writeRaster(pinch, "outputs/circuitscape/pinchpoints.tif", overwrite = TRUE)
# Extract pinch point polygons for reporting
pinch_poly <- as.polygons(pinch)
```

**Results:** 23 pinch point clusters identified, totalling ~180 km². Top 5:

| Pinch point | Area (km²) | Location | Threat |
|-------------|-----------|----------|--------|
| PP01 | 42 | Petén–Alta Verapaz junction | Active deforestation |
| PP02 | 31 | Río Motagua corridor | Highway CA-9 |
| PP03 | 18 | Honduras–Nicaragua border | Cattle expansion |
| PP04 | 12 | Caribbean lowlands Guatemala | Oil palm |
| PP05 | 8  | Bay Islands bridge | Tourism development |

---

## Step 5 — Scenario Analysis: Corridor Protection

**Question:** If PP01 (42 km²) were protected and restored to forest, how much would PC increase?

```r
# Create scenario patch: add PP01 as new forest patch
pp01 <- data.frame(
  patch_id = "PP01_restored",
  x = centroid_x, y = centroid_y,
  area_ha = 4200
)
patches_scenario <- rbind(patches_original, pp01)

# Recompute connectivity
python_cmd <- sprintf(
  "python connectivity_analysis.py data/patches_scenario.csv outputs/scenario/ --dmax 50000"
)
system(python_cmd)

pc_scenario <- read.csv("outputs/scenario/landscape_summary.csv")
pc_baseline <- 0.0814
pc_new <- pc_scenario$value[pc_scenario$metric == "PC"]
cat(sprintf("PC improvement: %.4f → %.4f (+%.1f%%)\n",
            pc_baseline, pc_new, (pc_new - pc_baseline) / pc_baseline * 100))
```

**Result:** Restoring PP01 increases PC from 0.0814 to 0.1021 (+25.4%). This is the single highest-leverage restoration action in the landscape.

---

## Step 6 — Final Outputs

```
outputs/
├── resistance/
│   ├── resistance_lc.tif
│   ├── resistance_combined.tif    # LC + slope + road proximity
│   └── resistance_stats.csv
├── connectivity/
│   └── dmax_50000/
│       ├── patch_metrics.csv      # 214 patches, ranked by dPC
│       ├── landscape_summary.csv
│       └── connectivity_graph.png
├── circuitscape/
│   ├── cs_output_cum_curmap.asc   # Cumulative current flow
│   ├── pinchpoints.tif            # Top 5% current cells
│   └── pinchpoints.shp            # Polygon pinch points
└── scenario/
    └── landscape_summary.csv      # PC after PP01 restoration
```

---

## Summary Table

| Metric | Baseline | PP01 restored | Change |
|--------|---------|--------------|--------|
| IIC | 0.0847 | 0.1094 | +29.2% |
| PC | 0.0814 | 0.1021 | +25.4% |
| n components | 7 | 6 | −1 |
| Largest component (patches) | 142 | 158 | +16 |

---

## Decision Log

```yaml
- date: 2025-01-20
  skill_id: landscape-connectivity
  decision: "Highway resistance set to 200, not 1000"
  rationale: "Culvert crossings documented; Quigley & Crawshaw (1992)"
  outputs: ["outputs/resistance/resistance_combined.tif"]

- date: 2025-01-21
  skill_id: landscape-connectivity
  decision: "Dispersal distance set to 50 km for main analysis"
  rationale: "Conservative mid-range; sensitivity shows IIC robust ±20% across 20-80km"
  outputs: ["outputs/connectivity/dmax_50000/landscape_summary.csv"]

- date: 2025-01-22
  skill_id: landscape-connectivity
  decision: "Patch P089 flagged as critical stepping stone"
  rationale: "High BC (0.81) despite small area; bridges components 3 and 4"
  outputs: ["outputs/connectivity/dmax_50000/patch_metrics.csv"]
```

---

## References

- Rabinowitz, A. & Zeller, K.A. (2010). A range-wide model of landscape connectivity and conservation for the jaguar. *Biological Conservation*, 143(4), 939–945. DOI: 10.1016/j.biocon.2010.01.002
- Pascual-Hortal, L. & Saura, S. (2006). Comparison and development of new graph-based landscape connectivity indices. *Landscape Ecology*, 21(7), 959–967. DOI: 10.1007/s10980-006-0013-z
- McRae, B.H. et al. (2008). Using circuit theory to model connectivity in ecology. *Ecology*, 89(10), 2712–2724. DOI: 10.1890/07-1861.1
- Zeller, K.A. et al. (2012). Estimating landscape resistance to movement. *Landscape Ecology*, 27(6), 777–797. DOI: 10.1007/s10980-012-9737-0
