# Worked Example: Grey Wolf SDM & Recolonization Projection in Western Europe

**Workflow:** run-sdm-study
**Species:** Canis lupus (grey wolf)
**Study area:** Western Europe (Italy, France, Germany, Spain, Poland + neighbouring countries)
**Predictors:** WorldClim v2.1 (bio1, bio4, bio12, bio15) + elevation (SRTM) + forest cover (Copernicus Tree Cover Density) + distance to urban areas (Corine Land Cover 2018)
**Special focus:** Range-expanding species; recolonization projection; conflict analysis (habitat suitability vs. livestock density)

---

## Step 1 — Data Sources

| Dataset | Source | Records |
|---------|--------|---------|
| GBIF occurrence (Italy, France, Germany, Spain, Poland) | doi:10.15468/dl.yy7k4w | 8,412 raw |
| EuroLargeCarnivores monitoring database | eurolargecarnivores.eu | 2,103 raw |
| Field data 2018--2024 (GPS collars + camera traps) | Own collection / collaborators | 340 raw |
| **Total after cleaning** | -- | **3,214** |
| **After 20 km thinning** | -- | **582** |

**Note on range-expanding species:** Thinning distance set at 20 km (larger than the 10 km default) to reduce spatial clustering in the Italian Apennines and Polish Carpathians where monitoring effort is highest. This reduces sampling bias in the core range and improves model transferability to unoccupied areas.

## Step 2 — QA Results Summary

| Issue | Count | Action |
|-------|-------|--------|
| Zero or null coordinates | 14 | Removed |
| Country centroid matches | 23 | Removed |
| Records before 2000 (pre-recolonization phase) | 1,847 | Removed (retain 2000--2024 only) |
| Outside study area polygon | 68 | Removed |
| Taxonomy: synonyms (C. l. italicus, C. l. signatus) | 412 | Resolved to Canis lupus |
| Exact duplicates across datasets | 1,290 | Deduplicated |
| Captive/zoo records (coordinate match to known facilities) | 31 | Removed |
| Sea/water body coordinates (>1 km offshore) | 6 | Removed |
| After cleaning | **3,214** | Retained |

**Temporal filter rationale:** Records before 2000 were excluded because the species was near extirpation in Western Europe during the mid-20th century. Retaining only post-2000 data captures the current recolonization niche rather than the historical refugial niche.

## Step 3 — Collinearity Results

Final predictor set after VIF reduction (threshold VIF < 5, |r| < 0.7):

| Variable | VIF | Decision |
|----------|-----|----------|
| bio1 (Mean Annual Temperature) | 2.3 | Keep |
| bio4 (Temperature Seasonality) | 3.1 | Keep |
| bio12 (Mean Annual Precipitation) | 2.7 | Keep |
| bio15 (Precipitation Seasonality) | 1.9 | Keep |
| elevation (SRTM 90 m) | 3.8 | Keep |
| forest_cover (Copernicus TCD) | 2.4 | Keep |
| distance_to_urban (Corine CLC18) | 1.6 | Keep |
| bio5 (Max Temp Warmest Month) | 8.7 | **Remove** (collinear with bio1, r = 0.89) |
| bio6 (Min Temp Coldest Month) | 9.1 | **Remove** (collinear with bio1, r = 0.92) |
| bio13 (Prec. Wettest Month) | 7.4 | **Remove** (collinear with bio12, r = 0.85) |

**Ecological rationale for retained variables:**
- **forest_cover** -- wolves in Europe preferentially select forested landscapes for denning and movement corridors
- **distance_to_urban** -- human avoidance is a primary constraint on wolf settlement in fragmented European landscapes
- **elevation** -- mountain refugia (Alps, Apennines, Carpathians) served as recolonization nuclei
- **bio4** -- continental vs. oceanic climate gradient separates Iberian and Alpine/Central European populations

## Step 4 — Calibration Area

```
Method: Biogeographic regions where Canis lupus has been documented 1950-present
Regions: Alpine, Continental, Mediterranean, Atlantic (partial), Boreal (southern fringe)
Buffer: 200 km beyond documented range boundary
Total M area: ~3,420,000 km²
Background points: 10,000 (random within M, excluding 1 km buffer around presences)
```

**Rationale:** Using the 1950--present documentation window (broader than the 2000--2024 occurrence filter) ensures the calibration area captures both the historical refugial range and current expansion fronts. The 200 km buffer allows projection into areas the species has not yet reached but could plausibly colonise.

## Step 5 — Spatial CV Configuration

```
Block size: 400 km (exceeds SAC range of ~320 km estimated from variogram)
Folds: 5
Presences per fold: 104--128
Background per fold: 1,800--2,200
Spatial autocorrelation range (variogram): ~320 km
```

**Note:** The large block size (400 km) is critical for range-expanding species. Smaller blocks would allow spatially autocorrelated presences from the same expansion front (e.g., western Alps) to appear in both training and test sets, inflating performance metrics.

## Step 6 — Model Performance

| Algorithm | AUC (CV) | TSS (CV) | Boyce (test) |
|-----------|---------|---------|-------------|
| MaxEnt (fc=LQH, rm=1.5) | 0.891 | 0.712 | 0.89 |
| BRT (n=2000, lr=0.005, tc=5) | 0.903 | 0.729 | 0.92 |
| Random Forest (n=500, mtry=3) | 0.878 | 0.698 | 0.86 |
| GLM (stepwise AIC, quadratic terms) | 0.864 | 0.671 | 0.83 |
| **Ensemble (weighted avg, TSS-weighted)** | **0.912** | **0.741** | **0.94** |

**Model selection note:** GLM was retained in the ensemble despite lower performance because it provides interpretable response curves useful for policy communication. Ensemble weights: BRT 0.31, MaxEnt 0.28, RF 0.23, GLM 0.18.

## Step 7 — Variable Importance (Ensemble)

| Variable | Importance (%) | Primary ecological role |
|----------|--------------|----------------------|
| forest_cover | 28.1 | Cover for denning, movement, prey |
| bio4 (Temp. Seasonality) | 21.3 | Continental-oceanic gradient |
| elevation | 17.6 | Mountain refugia and corridors |
| distance_to_urban | 14.2 | Human avoidance threshold |
| bio12 (MAP) | 10.8 | Prey productivity (ungulate biomass) |
| bio1 (MAT) | 5.4 | Thermal tolerance envelope |
| bio15 (Prec. Seasonality) | 2.6 | Seasonal resource availability |

**Response curve highlights:**
- **forest_cover:** Suitability increases sharply above 30% cover, plateaus at 60--80%
- **distance_to_urban:** Suitability near zero within 5 km of urban areas, peaks at 25--40 km
- **elevation:** Bimodal response -- high suitability at 400--1,200 m (forested mountains) and moderate at 100--300 m (lowland forests of Poland/Germany)

## Step 8 — Recolonization Projection

Binary suitability map (MaxTSS threshold = 0.44) projected to all of Western/Central Europe:

| Zone | Description | Area (km²) | Current status |
|------|------------|-----------|---------------|
| Core occupied range | Italy, Poland, eastern Germany, eastern France | 412,000 | Established packs |
| Alps--Pyrenees corridor | Swiss/Austrian Alps through southern France to eastern Pyrenees | 87,000 | Dispersers detected; no established packs west of Rh&ocirc;ne |
| Scottish Highlands | Cairngorms, Grampians, NW Highlands | 14,200 | Unoccupied; high suitability (>0.65 mean) |
| Scandinavian expansion front | Southern Sweden, southern Norway | 53,000 | Sparse packs expanding southward |
| Central German Uplands | Harz, Thuringian Forest, Bavarian Forest | 28,400 | Recent colonization (2020--2024) |
| **Total suitable but unoccupied** | -- | **182,600** | -- |

**Key finding:** The Alps--Pyrenees corridor represents the most important connectivity gap in Western Europe. Suitability is high (mean 0.62) but the corridor narrows to <30 km width in the Rh&ocirc;ne valley, creating a potential bottleneck for gene flow between Italian and Iberian populations.

## Step 9 — Conflict Analysis

Overlay of ensemble suitability (>0.5) with livestock density from FAO Gridded Livestock of the World v3 (GLW3, cattle + sheep + goats):

| Category | Suitability | Livestock density | Area (km²) | % of suitable area | Example regions |
|----------|------------|------------------|-----------|-------------------|----------------|
| Low conflict | >0.5 | <50 heads/km² | 298,000 | 52.4 | Carpathian forests, Scottish Highlands, Scandinavian boreal |
| Moderate conflict | >0.5 | 50--150 heads/km² | 168,000 | 29.6 | Central Alps, eastern France, Cantabrian Mountains |
| High conflict | >0.5 | >150 heads/km² | 102,000 | 18.0 | Swiss Plateau fringe, Pyrenean valleys, Bavarian foothills |
| **Total suitable (>0.5)** | -- | -- | **568,000** | **100** | -- |

**Conflict hotspot detail:**

| Hotspot | Area (km²) | Mean suitability | Mean livestock density (heads/km²) | Dominant livestock |
|---------|-----------|-----------------|----------------------------------|-------------------|
| Pyrenean pastoral valleys | 12,400 | 0.58 | 210 | Sheep (transhumant) |
| Swiss Plateau -- Jura fringe | 8,700 | 0.54 | 245 | Cattle (dairy) |
| Bavarian Alpine foothills | 6,200 | 0.61 | 185 | Cattle (mixed) |
| Cantabrian -- Asturian valleys | 9,100 | 0.63 | 195 | Cattle, goats |
| Southern French pre-Alps | 7,800 | 0.57 | 170 | Sheep |

## Ecological Interpretation

Forest cover emerged as the strongest predictor, reflecting the European wolf's dependence on continuous forest for denning, pup-rearing, and movement between pack territories. Unlike North American wolves that occupy open tundra and grassland, European wolves operate in a human-dominated landscape where forest provides the critical refugium from disturbance.

The high importance of distance to urban areas (14.2%) underlines a key difference between modelling range-expanding species and stable-range species. Wolves are not physiologically excluded from peri-urban areas; rather, persecution and road mortality create a functional exclusion zone. This has two implications for interpretation: (1) the current niche model captures a realized niche strongly shaped by human pressure, not the fundamental niche, and (2) as legal protection strengthens, wolves may colonize areas currently predicted as unsuitable, meaning the model may underestimate future range.

The recolonization projection identifies 182,600 km² of suitable but currently unoccupied habitat. The Alps--Pyrenees corridor is of particular conservation significance because it represents the only plausible route for natural connectivity between the Italian/Alpine population and the remnant Iberian population. Genetic isolation of the Iberian population (currently ~350 breeding pairs) is a documented concern, and natural recolonization through this corridor could restore gene flow within 2--3 wolf generations if anthropogenic barriers (highways, pastoral conflict) are mitigated.

The conflict analysis reveals that 18% of suitable habitat (102,000 km²) overlaps with high livestock density (>150 heads/km²). This is not a reason to exclude these areas from conservation planning, but rather an indication of where targeted coexistence measures (livestock guarding dogs, electric fencing, compensation schemes) must be deployed proactively before wolf packs establish.

## Recommendations

1. **Alps--Pyrenees corridor:** Prioritize habitat connectivity measures in the Rh&ocirc;ne valley bottleneck (wildlife crossings over A7/A43 motorways, forest restoration along riverine corridors). This single corridor determines whether Western European wolf populations remain genetically fragmented or reconnect.

2. **Proactive conflict mitigation:** Deploy livestock protection measures in the five identified high-conflict hotspots *before* wolf colonization, not after. Evidence from Italy and Germany shows that reactive compensation schemes alone do not reduce social conflict; prevention infrastructure must be in place prior to pack establishment.

3. **Scottish Highlands assessment:** The model identifies 14,200 km² of suitable habitat with very low conflict potential. However, wolves are absent from Great Britain and natural recolonization is impossible (English Channel). Any consideration of reintroduction should be treated as a separate feasibility study using this SDM as one input layer among many (social acceptance surveys, prey density, road density).

4. **Monitoring network expansion:** Current monitoring is strongly biased toward the Italian Apennines and Polish Carpathians. To validate recolonization projections, camera trap and genetic sampling effort should be expanded to the Alps--Pyrenees corridor, Central German Uplands, and southern Scandinavia.

5. **Model updating:** Given the rapid pace of wolf range expansion in Europe (~30 km/year along some fronts), this SDM should be re-calibrated every 3--5 years with updated occurrence data to capture changes in the realized niche as the species encounters novel landscape configurations.

## References

1. Chapron, G., Kaczensky, P., Linnell, J.D.C., et al. (2014). Recovery of large carnivores in Europe's modern human-dominated landscapes. *Science*, 346(6216), 1517--1519. doi:[10.1126/science.1257553](https://doi.org/10.1126/science.1257553)

2. Fick, S.E. & Hijmans, R.J. (2017). WorldClim 2: new 1-km spatial resolution climate surfaces for global land areas. *International Journal of Climatology*, 37(12), 4302--4315. doi:[10.1002/joc.5086](https://doi.org/10.1002/joc.5086)

3. Gilbert, M., Nicolas, G., Cinardi, G., et al. (2018). Global distribution data for cattle, buffaloes, horses, sheep, goats, pigs, chickens and ducks in 2010. *Scientific Data*, 5, 180227. doi:[10.1038/sdata.2018.227](https://doi.org/10.1038/sdata.2018.227)

4. Linnell, J.D.C., Cretois, B., Nilsen, E.B., et al. (2020). The challenges and opportunities of coexisting with wild ungulates in the human-dominated landscapes of Europe's Anthropocene. *Biological Conservation*, 244, 108500. doi:[10.1016/j.biocon.2020.108500](https://doi.org/10.1016/j.biocon.2020.108500)

5. Marucco, F., Avanzinelli, E., & Boitani, L. (2012). Non-invasive integrated sampling design to monitor the wolf population in Piemonte, Italian Alps. *Hystrix*, 23(1), 5--13. doi:[10.4404/hystrix-23.1-4584](https://doi.org/10.4404/hystrix-23.1-4584)

6. Muscarella, R., Galante, P.J., Soley-Guardia, M., et al. (2014). ENMeval: An R package for conducting spatially independent evaluations and estimating optimal model complexity for Maxent ecological niche models. *Methods in Ecology and Evolution*, 5(11), 1198--1205. doi:[10.1111/2041-210X.12261](https://doi.org/10.1111/2041-210X.12261)

7. Ripari, L., Premier, J., Belotti, E., et al. (2022). Human disturbance is the most limiting factor driving habitat selection of a large carnivore throughout Continental Europe. *Biological Conservation*, 266, 109446. doi:[10.1016/j.biocon.2021.109446](https://doi.org/10.1016/j.biocon.2021.109446)

8. Roberts, D.R., Bahn, V., Ciuti, S., et al. (2017). Cross-validation strategies for data with temporal, spatial, hierarchical, or phylogenetic structure. *Ecography*, 40(8), 913--929. doi:[10.1111/ecog.02881](https://doi.org/10.1111/ecog.02881)

9. Thuiller, W., Lafourcade, B., Engler, R., & Araujo, M.B. (2009). BIOMOD -- a platform for ensemble forecasting of species distributions. *Ecography*, 32(3), 369--373. doi:[10.1111/j.1600-0587.2008.05742.x](https://doi.org/10.1111/j.1600-0587.2008.05742.x)

10. Valente, A.M., Acevedo, P., Figueiredo, A.M., et al. (2020). Dear These days wolves in Europe: distribution, status, challenges and opportunities. *Mammal Review*, 50(3), 1--17. doi:[10.1111/mam.12220](https://doi.org/10.1111/mam.12220)
