# Example Invocation Prompts — ecological-impact-assessment

## BACI Analysis

```
Load skill: ecological-impact-assessment
Task: BACI analysis of deforestation impact on stream macroinvertebrate richness.

Data: data/baci_invertebrates.csv
Columns: site_id, treatment (control/impact), period (before/after), richness (count), date

Model: richness ~ period * treatment + (1|site), family = negative binomial
Check parallel trends using pre-disturbance data only.
Report: BACI interaction estimate, 95% CI, p-value, % change on original scale.
Generate: before/after comparison plots for control and impact sites.
```

## Fragmentation Analysis

```
Load skill: ecological-impact-assessment
Task: Compute landscape fragmentation metrics for Atlantic Forest before (2000) and after (2022) period.

Input layers:
  - data/landcover_2000.tif (MapBiomas class 3 = Atlantic Forest)
  - data/landcover_2022.tif (same classification)
  - data/spatial/study_area.shp

Metrics: total area (ha), number of patches, mean patch size, largest patch index,
  edge density, COHESION, MESH (effective mesh size).
Report change between years. Output: fragmentation_metrics.csv, fragmentation_plots.png
```
