---
name: geoprocessing-for-ecology
description: "Handles spatial data operations: reprojection, raster stacking, clipping, extraction, and environmental predictor downloads for ecological analyses. Use this skill when the user needs CRS reprojection, raster masking or cropping, spatial extraction, buffer creation, raster resampling, spatial joins, GeoTIFF processing, shapefile operations, WorldClim/CHELSA/ERA5 predictor downloads, GDAL operations, or predictor stack preparation."
skill_version: 1.0.0
---

# Skill: geoprocessing-for-ecology

**Domain:** Spatial analysis · CRS · Raster · Vector · Extraction  
**Phase:** 1 — Foundation  
**Used by:** run-sdm-study, assess-ecological-impact, build-fire-risk-map, analyze-environmental-change, assess-ecosystem-services

---

## Purpose

Guides the agent through spatial data operations needed in quantitative ecology: coordinate reference system management, raster and vector processing, spatial masking, buffer creation, intersection, and extraction of environmental values at occurrence or sample points.

---

## When to Invoke

- Reprojecting layers to a common CRS
- Clipping rasters or shapefiles to a study area
- Extracting environmental variables at point locations
- Creating buffers around sites or features
- Computing landscape metrics from a land cover layer
- Stacking multi-band rasters for modeling

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Occurrence / sample points | CSV with lat/lon, SHP, GPKG | Yes |
| Study area polygon | SHP, GPKG, GeoJSON | Yes |
| Environmental rasters | GeoTIFF, NetCDF | Yes |
| Land cover or habitat layer | GeoTIFF, SHP | Optional |

---

## Outputs

| Output | Description |
|--------|-------------|
| `layers_reprojected/` | All layers in common CRS |
| `predictors_stack.tif` | Aligned, masked raster stack |
| `points_with_env.csv` | Points with extracted environmental values |
| `study_area_buffered.gpkg` | Study area with optional buffer |
| `spatial_qa_report.md` | CRS audit and alignment report |

---

## Steps

### 1. CRS Audit
- Identify the CRS of each input layer
- Define the project CRS (default: EPSG:4326 for global; UTM zone for regional)
- Reproject all layers to the project CRS
- Document the CRS choice and rationale

### 2. Extent and Resolution Alignment
- Define the study area extent from the provided polygon
- Clip all rasters to the study area extent
- Resample rasters to a common resolution (define target resolution explicitly)
- Apply the study area mask to remove cells outside the polygon

### 3. Vector Operations
- Dissolve or simplify study area polygon if needed
- Create buffers (specify distance and unit)
- Perform intersection or spatial join between occurrence points and polygon layers
- Check for topology errors (self-intersections, gaps)

### 4. Environmental Extraction
- Extract raster values at occurrence and background/pseudo-absence points
- Handle NA values (edge cells, masked areas): document strategy
- Check for spatial autocorrelation in extracted values if relevant

### 5. Raster Stack QA
- Verify all rasters share the same extent, resolution, CRS, and NA mask
- Report NA cell counts per layer
- Visualise layer histograms for anomaly detection

### 6. Generate Outputs
- Write reprojected layers to `layers_reprojected/`
- Write stacked predictor raster to `predictors_stack.tif`
- Write points with environmental values to `points_with_env.csv`
- Write spatial QA report

---

## Decision Points

| Condition | Diagnosis | Recommended Action |
|-----------|-----------|-------------------|
| Layers have mismatched CRS | Spatial operations will fail or produce incorrect results | Reproject all layers to a common CRS before any operation; document chosen EPSG in `decision_log.md` |
| Rasters have different resolutions | Extraction or stacking will fail | Resample to the coarsest resolution; prefer bilinear for continuous data, nearest-neighbour for categorical |
| Extents do not overlap | Study area definition error or wrong file | Verify study area shapefile; clip all layers to intersection; warn if intersection is < 50% of study area |
| NoData fraction > 30% after masking | Data gap too large for reliable analysis | Report NoData extent; consult alternative data source; do not interpolate silently |

---

## Key Decisions to Document

- Project CRS (EPSG code)
- Target raster resolution (and rationale)
- Resampling method (nearest, bilinear, cubic)
- NA handling strategy
- Buffer distance (if used)

---

## Tools and Libraries

**R:** `terra`, `sf`, `landscapemetrics`  
**Python:** `rasterio`, `geopandas`, `pyproj`, `rasterstats`, `fiona`  
**CLI:** `GDAL/OGR` (gdalwarp, ogr2ogr, gdal_calc)

---

## Resources

- `resources/crs-reference.md` — common CRS codes for South American biomes
- `resources/resampling-methods.md` — when to use each resampling method
- `examples/` — example extraction workflows

---

## Notes

- Always keep original layers intact; write outputs to separate directories
- Document the GDAL version used for reproducibility
- For very large rasters (>4 GB), use tiled/chunked processing
