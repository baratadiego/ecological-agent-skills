# Example Invocation Prompts — geoprocessing-for-ecology

## Stack and Extract

```
Load skill: geoprocessing-for-ecology
Task: I have 19 WorldClim v2.1 rasters (bio1–bio19) at 2.5 arcmin resolution
and a set of jaguar occurrence points (occ_clean.csv).
Study area: Amazon biome polygon (amazon_biome.shp).
1. Reproject everything to EPSG:4326 (already geographic, just check).
2. Clip rasters to Amazon extent + 1° buffer.
3. Extract bioclim values at occurrence and 10,000 background points.
4. Output: predictors_stack.tif, points_with_env.csv.
```

## Reprojection and Masking

```
Load skill: geoprocessing-for-ecology
Task: Reproject landcover_mapbiomas_2022.tif from SIRGAS2000 (EPSG:4674)
to WGS84 UTM 22S (EPSG:32722). Then mask to the study area polygon
(cerrado_boundary.gpkg). Use nearest-neighbour resampling. Target resolution: 30m.
```

## Buffer and Intersection

```
Load skill: geoprocessing-for-ecology
Task: Create a 5 km buffer around all hydroelectric dam points (dams.shp).
Intersect with the Atlantic Forest remnant polygons (af_remnants.gpkg).
Report: total forest area within 5 km of dams (ha), and number of dam-affected patches.
```
