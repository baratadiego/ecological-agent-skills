# Global Predictor Sources for Ecological Modelling

Reference guide for downloading environmental predictor layers used in Species Distribution Models (SDMs) and other ecological analyses. Each source includes access method, spatial resolution, temporal coverage, and recommended use cases.

---

## Summary Table

| Dataset | Type | Resolution | Coverage | Access | SDM Use |
|---------|------|-----------|----------|--------|---------|
| WorldClim v2.1 | Climate | 30s–10m | Global | Free | Bioclimatic variables (19 BIO) |
| CHELSA v2.1 | Climate | 30s | Global | Free | High-res bioclimatic variables |
| TerraClimate | Climate | ~4km | Global | Free | Monthly climate + water balance |
| ERA5-Land | Climate | ~9km | Global | Free (CDS) | Hourly/monthly reanalysis |
| MODIS | Remote sensing | 250m–1km | Global | Free (NASA) | NDVI, land cover, LST |
| Copernicus LC | Land cover | 100m | Global | Free | Land use / land cover |
| SoilGrids v2 | Soil | 250m | Global | Free | Soil properties (pH, SOC, clay) |
| MERIT DEM | Topography | ~90m | Global | Free | Elevation, slope, aspect |
| HydroSHEDS | Hydrology | 90m | Global | Free | River networks, catchments |
| GFW | Forest cover | 30m | Global | Free | Hansen tree cover change |
| ESA CCI LC | Land cover | 300m | Global | Free | Annual land cover 1992–2020 |
| Human Footprint | Anthropogenic | ~1km | Global | Free | Human pressure index |

---

## WorldClim v2.1

**URL**: https://worldclim.org/data/worldclim21.html
**DOI**: https://doi.org/10.1002/joc.5086
**Type**: Bioclimatic variables derived from temperature and precipitation
**Resolution**: 30 arc-seconds (~1 km), 2.5, 5, 10 arc-minutes
**Temporal coverage**: 1970–2000 (current); future SSP scenarios (CMIP6)
**Format**: GeoTIFF (.tif)

### Download (R — geodata package)
```r
library(geodata)
# 19 bioclimatic variables, 2.5 arc-minute resolution
bio <- worldclim_global(var = "bio", res = 2.5, path = "data/predictors/worldclim")
# Single variable: tmin, tmax, prec, srad, wind, vapr
tmax <- worldclim_global(var = "tmax", res = 2.5, path = "data/predictors/worldclim")
# Future scenario (CMIP6)
bio_fut <- cmip6_world(model = "MPI-ESM1-2-HR", ssp = "585", time = "2061-2080",
                        var = "bioc", res = 2.5, path = "data/predictors/worldclim")
```

### Download (Python — requests)
```python
import requests
from pathlib import Path
url = "https://biogeo.ucdavis.edu/data/worldclim/v2.1/base/wc2.1_2.5m_bio.zip"
Path("data/predictors/worldclim").mkdir(parents=True, exist_ok=True)
r = requests.get(url, stream=True, timeout=300)
with open("data/predictors/worldclim/wc2.1_2.5m_bio.zip", "wb") as f:
    for chunk in r.iter_content(chunk_size=65536):
        f.write(chunk)
```

**SDM guidance**: Use all 19 BIO variables, then apply collinearity screening (|r| > 0.7) to select non-redundant predictors. BIO1, BIO4, BIO12, BIO15 are often retained.

---

## CHELSA v2.1

**URL**: https://chelsa-climate.org/
**DOI**: https://doi.org/10.1038/s41597-021-01084-7
**Type**: High-resolution bioclimatic variables (superior to WorldClim in complex terrain)
**Resolution**: 30 arc-seconds (~1 km)
**Temporal coverage**: 1981–2010 (current); CMIP6 future scenarios
**Format**: NetCDF / GeoTIFF

### Download (R — direct URL)
```r
library(terra)
# CHELSA BIO1 (mean annual temperature)
url_bio1 <- "https://os.zhdk.cloud.switch.ch/envicloud/chelsa/chelsa_V2/GLOBAL/climatologies/1981-2010/bio/CHELSA_bio1_1981-2010_V.2.1.tif"
dir.create("data/predictors/chelsa", recursive = TRUE, showWarnings = FALSE)
download.file(url_bio1, destfile = "data/predictors/chelsa/CHELSA_bio1.tif",
              mode = "wb", quiet = FALSE)
r <- terra::rast("data/predictors/chelsa/CHELSA_bio1.tif")
```

### Download (Python)
```python
import requests
from pathlib import Path
base = "https://os.zhdk.cloud.switch.ch/envicloud/chelsa/chelsa_V2/GLOBAL/climatologies/1981-2010/bio"
out  = Path("data/predictors/chelsa")
out.mkdir(parents=True, exist_ok=True)
for i in range(1, 20):
    fname = f"CHELSA_bio{i}_1981-2010_V.2.1.tif"
    r = requests.get(f"{base}/{fname}", stream=True, timeout=600)
    r.raise_for_status()
    (out / f"CHELSA_bio{i}.tif").write_bytes(r.content)
```

**SDM guidance**: Prefer CHELSA over WorldClim in mountains, coastal areas, and tropical regions where topographic correction matters. CHELSA and WorldClim BIO variables are on the same scale and can substitute directly.

---

## TerraClimate

**URL**: https://www.climatologylab.org/terraclimate.html
**DOI**: https://doi.org/10.1038/sdata.2017.191
**Type**: Monthly climate and water balance (1958–present)
**Resolution**: ~4 km (1/24 degree)
**Format**: NetCDF

### Download (R)
```r
library(terra)
# Download monthly PDSI (Palmer Drought Severity Index), 2010
url <- "https://climate.northwestknowledge.net/TERRACLIMATE-DATA/TerraClimate_PDSI_2010.nc"
download.file(url, "data/predictors/terraclimate_PDSI_2010.nc", mode = "wb")
r <- terra::rast("data/predictors/terraclimate_PDSI_2010.nc")
```

**Variables**: ppt (precip), tmax, tmin, aet, def, pdsi, pet, q, soil, srad, swe, vap, vpd, ws
**SDM guidance**: Useful for water-balance related species responses. Combine with WorldClim for multi-temporal analyses.

---

## ERA5-Land (Copernicus CDS)

**URL**: https://cds.climate.copernicus.eu/datasets/reanalysis-era5-land
**DOI**: https://doi.org/10.24381/cds.68d2bb30
**Type**: Monthly/hourly land surface reanalysis
**Resolution**: ~9 km (0.1 degree)
**Temporal coverage**: 1950–present
**Format**: NetCDF / GRIB

### Download (Python — cdsapi)
```python
import cdsapi
c = cdsapi.Client()  # requires ~/.cdsapirc with key
c.retrieve(
    "reanalysis-era5-land-monthly-means",
    {
        "variable": ["2m_temperature", "total_precipitation"],
        "product_type": "monthly_averaged_reanalysis",
        "year": [str(y) for y in range(1990, 2021)],
        "month": [f"{m:02d}" for m in range(1, 13)],
        "time": "00:00",
        "format": "netcdf",
    },
    "data/predictors/era5_land_temp_precip.nc"
)
```

**SDM guidance**: Best for recent time periods and when high temporal resolution is needed. Requires free Copernicus CDS account and cdsapi configuration.

---

## MODIS (NASA)

**URL**: https://lpdaac.usgs.gov/
**Type**: Remote sensing products (NDVI, EVI, land cover, LST, etc.)
**Resolution**: 250 m (NDVI/EVI), 500 m, 1 km (LST, land cover)
**Temporal coverage**: 2000–present (16-day composites)
**Format**: HDF / GeoTIFF

### Download (R — MODIStsp / terra)
```r
# MODIStsp for bulk MODIS download (requires NASA EarthData account)
# library(MODIStsp)
# MODIStsp()  # interactive GUI

# Alternative: direct download via APPEEARS or terra/STAC
library(terra)
# MODIS NDVI via STAC (Microsoft Planetary Computer)
# See: https://planetarycomputer.microsoft.com/dataset/modis-13A1-061
```

### Download (Python — pystac)
```python
import planetary_computer
import pystac_client
import stackstac
catalog = pystac_client.Client.open(
    "https://planetarycomputer.microsoft.com/api/stac/v1",
    modifier=planetary_computer.sign_inplace,
)
items = catalog.search(
    collections=["modis-13A1-061"],  # NDVI 500m 16-day
    bbox=[-80, -15, -34, 5],
    datetime="2020-01-01/2020-12-31",
).item_collection()
stack = stackstac.stack(items, assets=["500m_16_days_NDVI"])
```

**SDM guidance**: NDVI as a proxy for vegetation productivity. Use annual maximum NDVI or seasonal composites. Apply cloud-masking (QA layers) before use.

---

## Copernicus Global Land Cover

**URL**: https://lcviewer.vito.be/2019
**DOI**: https://doi.org/10.3390/rs12061044
**Type**: Annual global land cover
**Resolution**: 100 m
**Temporal coverage**: 2015–2019
**Format**: GeoTIFF

### Download (Python)
```python
# Available via Copernicus Land Service: https://land.copernicus.eu/global/products/lc
# Access requires free account; download per tile (20°x20°)
# Fractional cover layers: forest, shrub, grassland, cropland, urban, bare, water, permanent snow
```

**SDM guidance**: Use fractional cover layers (0–100%) as continuous predictors rather than discrete class rasters. This retains more variation and improves model performance.

---

## SoilGrids v2.0

**URL**: https://soilgrids.org/
**DOI**: https://doi.org/10.1371/journal.pone.0169748
**Type**: Global soil property predictions at 6 standard depths
**Resolution**: 250 m
**Format**: GeoTIFF (Cloud-Optimised GeoTIFF via WCS/STAC)

### Download (R — terra + WCS)
```r
library(terra)
# pH at 0-5 cm depth (mean)
url_ph <- "https://maps.isric.org/mapserv?map=/map/phh2o.map&SERVICE=WCS&VERSION=2.0.1&REQUEST=GetCoverage&COVERAGEID=phh2o_0-5cm_mean&FORMAT=image/tiff&SUBSET=X(-8237000,-7196000)&SUBSET=Y(-1308000,-40000)&SUBSETTINGCRS=http://www.opengis.net/def/crs/EPSG/0/152160"
download.file(url_ph, "data/predictors/soilgrids_ph_0-5cm.tif", mode = "wb")
```

**Variables**: clay, sand, silt content; soil organic carbon (SOC); pH (H₂O); bulk density; cation exchange capacity (CEC); available water content
**Depths**: 0–5, 5–15, 15–30, 30–60, 60–100, 100–200 cm
**SDM guidance**: Use surface horizon (0–5 cm) for most terrestrial SDMs. SOC and pH are the most ecologically meaningful for plant and invertebrate distributions.

---

## MERIT DEM

**URL**: http://hydro.iis.u-tokyo.ac.jp/~yamadai/MERIT_DEM/
**DOI**: https://doi.org/10.1029/2017WR021187
**Type**: Multi-Error-Removed Improved-Terrain DEM
**Resolution**: 3 arc-seconds (~90 m)
**Format**: GeoTIFF

### Derived topographic variables (R)
```r
library(terra)
dem <- terra::rast("data/predictors/merit_dem.tif")
slope  <- terra::terrain(dem, v = "slope",  unit = "degrees")
aspect <- terra::terrain(dem, v = "aspect", unit = "degrees")
tpi    <- terra::terrain(dem, v = "TPI")    # Topographic Position Index
tri    <- terra::terrain(dem, v = "TRI")    # Terrain Ruggedness Index
```

**SDM guidance**: Elevation, slope, and aspect are key predictors for montane species. Topographic wetness index (TWI) can be derived using the `RSAGA` or `whitebox` packages.

---

## HydroSHEDS

**URL**: https://www.hydrosheds.org/
**DOI**: https://doi.org/10.1002/hyp.9936
**Type**: Hydrological datasets derived from SRTM
**Resolution**: 90 m (river network), 3 arc-min (basins)
**Format**: GeoTIFF / Shapefile

**Layers**: flow accumulation, flow direction, river network, sub-basins, catchments
**SDM guidance**: Essential for freshwater species SDMs. Use flow accumulation as a proxy for river size, and sub-basin polygons for spatial blocks in cross-validation.

---

## Global Forest Watch (Hansen)

**URL**: https://www.globalforestwatch.org/
**DOI**: https://doi.org/10.1126/science.1244693
**Type**: Annual forest cover change (2000–present)
**Resolution**: 30 m
**Format**: GeoTIFF (tiles)

### Download (R — gfwr or direct tiles)
```r
library(terra)
# Download canopy cover tile (e.g., 00N_070W)
url <- "https://storage.googleapis.com/earthenginepartners-hansen/GFC-2023-v1.11/Hansen_GFC-2023-v1.11_treecover2000_00N_070W.tif"
download.file(url, "data/predictors/hansen_treecover_00N_070W.tif", mode = "wb")
tc  <- terra::rast("data/predictors/hansen_treecover_00N_070W.tif")
```

**SDM guidance**: Use tree cover (%) as a continuous predictor. For change analyses, compute forest loss as cumulative annual loss to a given year. Threshold at 30% canopy cover for closed-canopy forest definition.

---

## ESA CCI Land Cover

**URL**: https://climate.esa.int/en/projects/land-cover/
**DOI**: https://doi.org/10.1016/j.rse.2017.07.028
**Type**: Annual global land cover classification
**Resolution**: 300 m
**Temporal coverage**: 1992–2020
**Format**: NetCDF

**SDM guidance**: Use for long time-series land cover change analyses. Reclassify the 37-class legend to broader categories meaningful for the taxon group. Consider using temporal stack for detectability analyses.

---

## Human Footprint Index

**URL**: https://wcshumanfootprint.org/
**DOI**: https://doi.org/10.1038/s41467-020-18509-4
**Type**: Cumulative human pressure index
**Resolution**: ~1 km
**Temporal coverage**: 2009, 2017
**Format**: GeoTIFF

**SDM guidance**: Strong predictor for threatened species with habitat sensitivity. Include in models for species with documented human disturbance responses. Standardise to [0,1] before use.

---

## Notes for SDM Use

1. **Resolution matching**: Resample all layers to the same resolution (usually the coarsest) before stacking. Use bilinear interpolation for continuous variables, nearest-neighbour for categorical.

2. **Collinearity**: Always run collinearity screening before modelling. Remove one variable from each pair with |r| > 0.7 (Spearman). Prefer variables with stronger ecological justification.

3. **Extent**: Clip all layers to a consistent modelling extent before extraction. A buffer of 200–500 km around occurrence points is typical for regional SDMs.

4. **Projection**: Reproject to a geographic CRS (WGS84 / EPSG:4326) for SDM unless the study area is small and a projected CRS is more appropriate.

5. **Future projections**: Match the time period and SSP scenario of future climate layers to the same GCM used for baseline calibration. Use ensembles of ≥5 GCMs to quantify projection uncertainty.

6. **Citation**: Always cite the specific dataset version and access date. Most datasets use DOI-based citation.
