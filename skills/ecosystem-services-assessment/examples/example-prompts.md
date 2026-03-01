# Example Invocation Prompts — ecosystem-services-assessment

## Multi-Service Assessment

```
Load skill: ecosystem-services-assessment
Task: Assess three ecosystem services across the Mata Atlântica remnants in São Paulo state.

Services: (1) carbon storage, (2) erosion control, (3) pollination habitat
Inputs:
  - data/landcover_sp_2022.tif (MapBiomas, 30m)
  - data/biomass_mapbiomas.tif (above-ground biomass, MgC/ha)
  - data/dem_sp.tif (SRTM 30m)
  - data/rainfall_erosivity_sp.tif (R-factor, MJ·mm/ha/h/yr)
  - data/sp_boundary.shp

Steps:
1. Carbon: extract biomass values per land cover class.
2. Erosion control: compute RUSLE C-factor from land cover; compute avoided soil loss.
3. Pollination: compute distance-weighted natural habitat index (1 km radius).
4. Summarise ES per land cover class (zonal statistics).
5. Trade-off analysis: pairwise Spearman correlations across pixels.
Output: es_indicator_maps/, es_summary_table.csv, tradeoff_matrix.csv, es_report.md
```
