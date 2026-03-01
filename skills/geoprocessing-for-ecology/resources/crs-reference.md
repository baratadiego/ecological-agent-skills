# CRS Reference — South American Biomes

## When to Use Each CRS

| Use Case | Recommended CRS | EPSG |
|----------|----------------|------|
| Global or continental analysis | WGS 84 Geographic | 4326 |
| Brazil national (planar, metres) | SIRGAS 2000 / UTM | varies by zone |
| Area calculations, Amazon biome | SIRGAS 2000 UTM Zone 20S | 31980 |
| Area calculations, Cerrado | SIRGAS 2000 UTM Zone 22S | 31982 |
| Area calculations, Atlantic Forest | SIRGAS 2000 UTM Zone 23S | 31983 |
| Area calculations, Pantanal | SIRGAS 2000 UTM Zone 21S | 31981 |
| Equal-area, continental South America | South America Albers Equal Area | 102033 |
| Distance calculations | WGS 84 / World Mercator | 3395 |
| Remote sensing (MODIS native) | Sinusoidal | 6842 |
| Landsat / Sentinel (Brazil) | WGS84 UTM zone (varies) | 32718–32724 |

## UTM Zone Reference — Brazil

| Zone | Longitude Range | States |
|------|----------------|--------|
| 18S (32718) | 72°W – 66°W | Far western Acre |
| 19S (32719) | 66°W – 60°W | Acre, Amazonas W |
| 20S (32720) | 60°W – 54°W | Amazonas, Pará W, Rondônia |
| 21S (32721) | 54°W – 48°W | MT, MS, PA centre |
| 22S (32722) | 48°W – 42°W | GO, TO, MG W |
| 23S (32723) | 42°W – 36°W | SP, RJ, ES, MG E |
| 24S (32724) | 36°W – 30°W | BA, SE, AL coast |
| 25S (32725) | 30°W – 24°W | Fernando de Noronha |

## Reprojection Commands

### R (terra)
```r
library(terra)
r <- rast("layer.tif")
r_proj <- project(r, "EPSG:31982")   # Bilinear for continuous; near for categorical
```

### Python (rasterio + pyproj)
```python
import rasterio
from rasterio.warp import reproject, Resampling, calculate_default_transform

with rasterio.open("layer.tif") as src:
    transform, width, height = calculate_default_transform(
        src.crs, "EPSG:31982", src.width, src.height, *src.bounds)
```

### GDAL CLI
```bash
gdalwarp -t_srs EPSG:31982 -r bilinear input.tif output.tif
```

## Resampling Method Guide

| Data Type | Method | Note |
|-----------|--------|------|
| Continuous (elevation, temperature) | Bilinear | Smooth interpolation |
| Categorical (land cover, soil class) | Nearest neighbour | Preserves class values |
| Count or integer | Nearest neighbour or mode | |
| High-precision DEM | Cubic | Smoother gradients |
