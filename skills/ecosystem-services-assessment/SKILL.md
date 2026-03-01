# Skill: ecosystem-services-assessment

**Domain:** ES indicators · Provisioning · Regulating · Cultural · Trade-offs  
**Phase:** 3 — Specialist  
**Used by:** assess-ecosystem-services

---

## Purpose

Guides the agent through the quantification and spatial representation of ecosystem services (ES): selecting appropriate indicators, computing biophysical ES estimates, mapping ES supply, and analysing trade-offs and synergies between services.

---

## When to Invoke

- Quantifying ecosystem services across a landscape or watershed
- Mapping ES supply and demand
- Analysing trade-offs between conservation and production services
- Supporting payments for ecosystem services (PES) design
- Environmental impact assessments requiring ES valuation

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Land cover / land use map | GeoTIFF, SHP | Yes |
| Biophysical data (rainfall, DEM, soil, biomass) | GeoTIFF, CSV | Yes |
| Socioeconomic data (population, demand) | GeoTIFF, CSV | Optional |
| Study area polygon | SHP, GPKG | Yes |

---

## Outputs

| Output | Description |
|--------|-------------|
| `es_indicator_maps/` | One raster per ES indicator |
| `es_summary_table.csv` | ES value per land cover class |
| `tradeoff_matrix.csv` | Pairwise ES correlation matrix |
| `tradeoff_plot.png` | Scatter plots or heatmap of ES trade-offs |
| `es_report.md` | Full ES assessment narrative |

---

## Steps

### 1. Define the ES Portfolio
Select relevant services for the context:

| Category | Examples |
|----------|---------|
| Provisioning | Timber, water, food, fibre, genetic resources |
| Regulating | Carbon sequestration, water regulation, erosion control, pollination |
| Cultural | Recreation, aesthetic value, spiritual significance |
| Supporting | Habitat, nutrient cycling (underlying processes) |

### 2. Select Indicators and Methods per Service
- **Carbon:** Above-ground biomass from REDD+ datasets or allometric models; soil carbon from SoilGrids
- **Water regulation:** Curve number (CN) approach; InVEST Seasonal Water Yield
- **Erosion control:** Revised Universal Soil Loss Equation (RUSLE); C-factor from land cover
- **Pollination:** Distance-weighted bee habitat index from land cover
- **Recreation:** Proximity index to natural areas weighted by accessibility

### 3. Compute Biophysical ES Values
- Apply selected method per service; store as raster layer
- Validate against field measurements or published benchmarks where possible
- Document all input parameters and data sources

### 4. Aggregate by Land Cover Class
- Zonal statistics: mean/total ES value per land cover polygon or raster class
- Build summary table: rows = land cover classes, columns = ES indicators
- Normalise to 0–1 for cross-service comparison

### 5. Trade-off and Synergy Analysis
- Compute pairwise Spearman correlations across pixels or land cover units
- Positive correlations = synergies; negative = trade-offs
- Visualise as correlation heatmap and scatter plots
- Identify land cover classes that maximise multiple services simultaneously

### 6. Beneficiary Mapping (optional)
- Map ES demand using population density, agricultural areas, or water intake points
- Overlay supply and demand to identify supply-demand gaps

---

## Key Decisions to Document

- ES portfolio selection rationale
- Method and data source per service
- Normalisation method for cross-service comparison
- Trade-off analysis unit (pixel, land cover class, watershed)

---

## Tools and Libraries

**R:** `raster`, `terra`, `dplyr`, `ggplot2`, `corrplot`  
**Python:** `rasterio`, `geopandas`, `seaborn`  
**Dedicated:** InVEST (Stanford Natural Capital Project), ARIES, Co$ting Nature

---

## Resources

- `resources/es-indicator-reference.md` — indicator definitions per service
- `resources/invest-parameter-guide.md` — InVEST model configuration
- `resources/rusle-coefficients.md` — RUSLE factor lookup tables
- `examples/` — worked carbon + water regulation example

---

## Notes

- ES assessment does not require monetary valuation; biophysical indicators are often sufficient and more defensible
- InVEST is the most widely used open-source platform; use it unless a specific method is required
- Always report uncertainty in ES estimates, especially for carbon stocks
