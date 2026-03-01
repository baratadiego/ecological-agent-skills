# InVEST Model Configuration Guide

InVEST (Integrated Valuation of Ecosystem Services and Tradeoffs) is the most widely used open-source platform for ES assessment. Developed by Stanford Natural Capital Project.

## Available Models (most relevant for ecology)

| Model | ES assessed | Key inputs |
|-------|------------|-----------|
| Carbon Storage and Sequestration | Carbon stocks | LULC map + carbon pools table |
| Seasonal Water Yield | Water provisioning | LULC, DEM, soil, rainfall |
| Nutrient Delivery Ratio (NDR) | Water quality (N, P) | LULC, DEM, soil, streams |
| Sediment Delivery Ratio (SDR) | Erosion / sedimentation | LULC, DEM, soil, rainfall erosivity |
| Habitat Quality | Biodiversity / habitat | LULC, threat sources, sensitivity table |
| Pollination | Crop pollination | LULC, nesting habitat, floral resources |
| Recreation | Ecotourism / recreation | LULC, access points, visitor data |
| Coastal Blue Carbon | Mangrove/seagrass carbon | LULC (coastal), carbon pools |

## Carbon Storage Model

**Inputs:**
- `lulc_current.tif` — Land use/land cover raster (integer class codes)
- `carbon_pools.csv` — Carbon pool values per LULC class

**Carbon pools table format:**

| lucode | LULC_name | C_above | C_below | C_soil | C_dead |
|--------|-----------|---------|---------|--------|--------|
| 1 | Dense forest | 150 | 30 | 80 | 5 |
| 2 | Secondary forest | 60 | 15 | 50 | 3 |
| 3 | Cerrado | 30 | 20 | 40 | 2 |
| 4 | Pasture | 5 | 3 | 20 | 0 |
| 5 | Cropland | 3 | 1 | 15 | 0 |

Units: Mg C / ha. Sources: IPCC Tier 1 default values; REDD+ national forest inventories; MapBiomas biomass layer.

## Sediment Delivery Ratio (SDR) — Key Parameters

| Parameter | Typical range | Notes |
|-----------|--------------|-------|
| Threshold flow accumulation | 1000–5000 cells | Higher = fewer streams |
| k_param (USLE K) | 0.01–0.8 t·ha·h/ha/MJ/mm | Soil erodibility factor |
| l_max | 122 m | Maximum USLE L factor slope length |
| sdr_max | 0.8 | Maximum SDR value |

## Habitat Quality Model

**Threat sources table:**

| threat | max_dist | weight | decay |
|--------|---------|--------|-------|
| roads | 5 | 0.8 | exponential |
| agriculture | 8 | 0.6 | linear |
| urban | 10 | 1.0 | exponential |

**Sensitivity table** (access_weight per threat × LULC):

| LULC | L_threat_roads | L_threat_agriculture | L_threat_urban |
|------|---------------|---------------------|---------------|
| Forest | 0.5 | 0.4 | 0.7 |
| Savanna | 0.6 | 0.5 | 0.8 |
| Wetland | 0.7 | 0.6 | 0.9 |
| Pasture | 0.0 | 0.0 | 0.3 |

## Running InVEST from Python

```python
import natcap.invest.carbon

args = {
    'workspace_dir': 'outputs/invest_carbon',
    'lulc_cur_path': 'data/landcover_2022.tif',
    'carbon_pools_path': 'data/carbon_pools.csv',
    'calc_sequestration': False,
    'do_redd': False,
    'do_valuation': False,
}
natcap.invest.carbon.execute(args)
```

## Installation

```bash
pip install natcap.invest
```

Or via Conda: `conda install -c conda-forge natcap.invest`
