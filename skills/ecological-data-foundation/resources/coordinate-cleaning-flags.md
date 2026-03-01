# Coordinate Cleaning Flag Reference

Based on the `CoordinateCleaner` R package flag system.

## Flag Codes and Descriptions

| Flag | Description | Default threshold | Action |
|------|-------------|------------------|--------|
| `.cap` | Coordinates at capital city | 0.1° radius | Flag and investigate |
| `.cen` | Coordinates at country centroid | 0.1° radius | Flag and investigate |
| `.gbif` | Coordinates at GBIF headquarters | 0.1° radius | Remove |
| `.inst` | Coordinates at known herbarium/museum | 0.1° radius | Flag and investigate |
| `.sea` | Coordinates in the ocean (for terrestrial taxa) | — | Flag and investigate |
| `.val` | Coordinates outside valid range | lat [-90,90], lon [-180,180] | Remove |
| `.zero` | Coordinates exactly at (0, 0) | — | Remove |
| `.equ` | Identical lat and lon values | — | Flag and investigate |
| `.dup` | Identical coordinates to another record | — | Flag; keep one |
| `.env` | Environmental outlier (extreme value in predictor space) | Mahalanobis distance p < 0.025 | Flag and investigate |
| `.out` | Spatial outlier (geographic distance from main cluster) | 7 MADs from median | Flag and investigate |

## Recommended Workflow (R)

```r
library(CoordinateCleaner)

flags <- clean_coordinates(
  x = occ_df,
  lon = "decimalLongitude",
  lat = "decimalLatitude",
  species = "species",
  tests = c("capitals", "centroids", "equal", "gbif",
            "institutions", "seas", "urban", "validity", "zeros"),
  capitals_rad = 10000,   # 10 km radius
  centroids_rad = 1000,   # 1 km radius
  seas_ref = "buffland"   # use buffered land polygon
)

# Inspect flags
summary(flags)
occ_clean <- occ_df[flags$.summary, ]
occ_flagged <- occ_df[!flags$.summary, ]
```

## Known Country Centroid Coordinates (South America)

| Country | Approx centroid lat | Approx centroid lon |
|---------|--------------------|--------------------|
| Brazil | -10.333 | -53.200 |
| Colombia | 4.099 | -72.888 |
| Peru | -9.190 | -75.016 |
| Bolivia | -16.290 | -63.589 |
| Argentina | -34.000 | -64.000 |
| Paraguay | -23.442 | -58.444 |

## Ocean Check for Terrestrial Taxa

Use `cc_sea()` with a buffered land polygon (0.5–1° buffer) to avoid incorrectly flagging coastal records:

```r
occ_sea_checked <- cc_sea(
  x = occ_df,
  lon = "decimalLongitude",
  lat = "decimalLatitude",
  ref = buffland  # load from CoordinateCleaner package
)
```
