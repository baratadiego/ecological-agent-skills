# Ecosystem Services Indicator Reference

## Provisioning Services

| Service | Indicator | Unit | Data source |
|---------|-----------|------|-------------|
| Above-ground carbon | Biomass carbon density | MgC/ha | REDD+ / GEDI / allometric |
| Soil organic carbon | SOC stock | MgC/ha | SoilGrids 2.0 |
| Timber | Volume/basal area | m³/ha | NFI data |
| Water availability | Mean annual streamflow | mm/year | SWAT / InVEST |
| Food production | Agricultural yield index | — | MapBiomas + FAO |

## Regulating Services

| Service | Indicator | Unit | Method |
|---------|-----------|------|--------|
| Carbon sequestration | Net ecosystem productivity | MgC/ha/year | MODIS MOD17 |
| Water regulation | Baseflow index | — | InVEST Seasonal Water Yield |
| Erosion control | Avoided soil loss | t/ha/year | RUSLE C-factor reduction |
| Flood regulation | Curve number (CN) | — | USDA-NRCS method |
| Pollination | Habitat suitability index | 0–1 | Distance from natural habitat |
| Climate regulation | Evapotranspiration anomaly | mm/year | MOD16 |
| Water purification | Nutrient retention | kg/ha/year | InVEST Nutrient Delivery Ratio |

## Cultural Services

| Service | Indicator | Unit | Method |
|---------|-----------|------|--------|
| Recreation | Accessibility-weighted natural area | ha (weighted) | Proximity index |
| Aesthetic value | Viewshed from scenic areas | — | GIS viewshed |
| Ecotourism potential | Biodiversity + accessibility index | — | Composite |
| Spiritual | Indigenous territory presence | Binary | FUNAI / IBGE |

## RUSLE C-factor by Land Cover (Brazil)

| Land cover class | C-factor |
|-----------------|---------|
| Dense forest | 0.001 |
| Secondary forest | 0.01 |
| Savanna (Cerrado) | 0.05 |
| Planted pasture | 0.15 |
| Degraded pasture | 0.40 |
| Annual cropland | 0.25–0.45 |
| Bare soil | 1.00 |
| Water body | 0 |
