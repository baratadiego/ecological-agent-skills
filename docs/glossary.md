# Glossary — Quantitative Ecology

Trilingual reference (English / Portuguese / Spanish) for terms used across all 17 skills.
Entries are grouped by theme. Definitions are written for the analytical context of this repository.

---

## How to Use

Each entry lists:
- **Term** — canonical English term used in scripts and documentation
- **PT** — Portuguese equivalent (Brazilian usage)
- **ES** — Spanish equivalent
- **Definition** — brief definition in the analytical context of this repository
- **Skill** — the skill where this term most commonly appears

---

## 1. Occurrence Data & Data Quality

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **occurrence record** | registro de ocorrência | registro de ocurrencia | A documented observation of a species at a specific location and time | ecological-data-foundation |
| **presence-only data** | dados de presença apenas | datos solo de presencia | Records where only species presence is documented, not confirmed absence | ecological-data-foundation |
| **presence-absence data** | dados de presença-ausência | datos de presencia-ausencia | Records confirming both where a species was detected AND surveyed but not detected | ecological-data-foundation |
| **background points** | pontos de background | puntos de fondo | Pseudo-absences randomly sampled from the study area for presence-background models | species-distribution-modeling |
| **spatial thinning** | rarefação espacial | rarefacción espacial | Removing records that fall within the same grid cell to reduce spatial autocorrelation | ecological-data-foundation |
| **spatial autocorrelation** | autocorrelação espacial | autocorrelación espacial | Statistical dependence between observations that decreases with geographic distance | predictive-modeling-best-practices |
| **duplicate record** | registro duplicado | registro duplicado | Record sharing the same species, coordinates, and date as another record | ecological-data-foundation |
| **coordinate uncertainty** | incerteza de coordenadas | incertidumbre de coordenadas | The radius (in metres) within which the true observation location may lie | ecological-data-foundation |
| **georeferencing** | georreferenciamento | georreferenciación | The process of assigning geographic coordinates to a locality description | ecological-data-foundation |
| **QA flag** | marcador de qualidade | bandera de calidad | A label applied to a record indicating a data quality issue (e.g. COORD_ZERO) | ecological-data-foundation |
| **DOI (data citation)** | DOI de citação de dados | DOI de citación de datos | A persistent digital identifier for a GBIF dataset download, used in publications | ecological-data-foundation |

---

## 2. Species Distribution Modelling (SDM / ENM)

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **SDM** | MDE (modelo de distribuição de espécie) | MDE (modelo de distribución de especie) | Statistical model relating species occurrences to environmental predictors to produce a suitability map | species-distribution-modeling |
| **ENM** | MEN (modelagem de nicho ecológico) | MNE (modelado de nicho ecológico) | Approach that models the ecological niche of a species from occurrence data and environmental layers | species-distribution-modeling |
| **MaxEnt** | MaxEnt | MaxEnt | Maximum entropy algorithm for presence-background SDM; implemented in `maxnet` | species-distribution-modeling |
| **BRT** | BRT (árvores de regressão por boosting) | BRT (árboles de regresión potenciados) | Gradient Boosting Trees; ensemble ML method for SDM (Elith et al. 2008) | species-distribution-modeling |
| **ensemble model** | modelo ensemble | modelo ensamblado | Combination of predictions from multiple algorithms to reduce model uncertainty | species-distribution-modeling |
| **suitability map** | mapa de adequabilidade | mapa de idoneidad | Raster where each pixel represents the predicted habitat suitability for a species | species-distribution-modeling |
| **habitat suitability** | adequabilidade de habitat | idoneidad de hábitat | The degree to which a location's environmental conditions match species requirements | species-distribution-modeling |
| **calibration area (M)** | área de calibração (M) | área de calibración (M) | The geographic region accessible to a species and used to define background for SDM calibration | species-distribution-modeling |
| **regularisation multiplier (RM)** | multiplicador de regularização | multiplicador de regularización | MaxEnt parameter controlling model complexity; higher values produce smoother predictions | species-distribution-modeling |
| **feature class (FC)** | classe de feature | clase de característica | MaxEnt parameter controlling the shape of response curves (L, Q, P, H, T) | species-distribution-modeling |
| **variable importance** | importância de variável | importancia de variable | Relative contribution of each predictor to a model's predictions | predictive-modeling-best-practices |
| **partial response curve** | curva de resposta parcial | curva de respuesta parcial | Plot showing the modelled relationship between a predictor and suitability, holding others constant | species-distribution-modeling |
| **future projection** | projeção futura | proyección futura | Application of a calibrated SDM to future climate scenarios (SSP/RCP) | species-distribution-modeling |
| **climate scenario** | cenário climático | escenario climático | A standardised future climate trajectory (e.g. SSP2-4.5, SSP5-8.5) from CMIP6 | species-distribution-modeling |

---

## 3. Environmental Predictors

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **bioclimatic variable** | variável bioclimática | variable bioclimática | Derived climate variable (e.g. BIO1–BIO19) capturing ecologically meaningful signals | geoprocessing-for-ecology |
| **BIO1** | BIO1 — temperatura média anual | BIO1 — temperatura media anual | Mean Annual Temperature (deg C × 10 in raw WorldClim/CHELSA) | geoprocessing-for-ecology |
| **BIO12** | BIO12 — precipitação anual | BIO12 — precipitación anual | Annual Precipitation (mm) | geoprocessing-for-ecology |
| **predictor stack** | pilha de preditores | pila de predictores | Multi-layer raster containing all environmental variables aligned to the same grid | geoprocessing-for-ecology |
| **collinearity** | colinearidade | colinealidad | Strong correlation between predictors that inflates uncertainty and reduces interpretability | predictive-modeling-best-practices |
| **VIF** | VIF (fator de inflação da variância) | VIF (factor de inflación de varianza) | Variance Inflation Factor; values > 10 indicate problematic collinearity | predictive-modeling-best-practices |
| **CHELSA** | CHELSA | CHELSA | Climatologies at High resolution for the Earth's Land Surface Areas; 1 km global climate dataset | geoprocessing-for-ecology |
| **WorldClim** | WorldClim | WorldClim | Global climate data at 1 km resolution; widely used for SDM | geoprocessing-for-ecology |
| **ERA5-Land** | ERA5-Land | ERA5-Land | ECMWF reanalysis product providing hourly climate data at ~9 km resolution via Copernicus CDS | geoprocessing-for-ecology |
| **raster** | raster | raster | Grid of cells (pixels) covering a geographic area, each storing a value | geoprocessing-for-ecology |
| **CRS** | SRC (sistema de referência de coordenadas) | SRC (sistema de referencia de coordenadas) | Coordinate Reference System defining how geographic coordinates are projected | geoprocessing-for-ecology |
| **reprojection** | reprojeção | reproyección | Converting raster or vector data from one CRS to another | geoprocessing-for-ecology |
| **spatial resolution** | resolução espacial | resolución espacial | The size of each pixel in a raster, typically expressed in metres or decimal degrees | geoprocessing-for-ecology |

---

## 4. Model Validation & Uncertainty

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **AUC** | AUC (área sob a curva ROC) | AUC (área bajo la curva ROC) | Area Under the ROC Curve; ranges 0.5 (random) to 1.0 (perfect discrimination) | model-validation-and-uncertainty |
| **TSS** | TSS (true skill statistic) | TSS (estadístico de habilidad verdadera) | True Skill Statistic = sensitivity + specificity - 1; ranges -1 to 1, threshold-independent | model-validation-and-uncertainty |
| **partial ROC** | ROC parcial | ROC parcial | ROC analysis restricted to ecologically relevant omission rates (OR10 < 0.1) | model-validation-and-uncertainty |
| **omission rate** | taxa de omissão | tasa de omisión | Proportion of presence records incorrectly predicted as unsuitable; OR10 uses 10th percentile threshold | model-validation-and-uncertainty |
| **calibration** | calibração | calibración | Assessment of whether predicted probabilities match observed occurrence rates | model-validation-and-uncertainty |
| **cross-validation** | validação cruzada | validación cruzada | Model evaluation using multiple train/test splits to estimate generalisation performance | predictive-modeling-best-practices |
| **spatial cross-validation** | validação cruzada espacial | validación cruzada espacial | Cross-validation where folds are spatially blocked to avoid overly optimistic AUC estimates | predictive-modeling-best-practices |
| **k-fold** | k-fold | k-fold | Cross-validation strategy dividing data into k equally sized subsets | predictive-modeling-best-practices |
| **uncertainty map** | mapa de incerteza | mapa de incertidumbre | Raster showing the standard deviation of ensemble model predictions across pixels | model-validation-and-uncertainty |
| **MOP** | MOP (análise de mobilidade de preditores) | MOP (análisis de movilidad de predictores) | Multivariate Overlap Procedure; identifies where transfer conditions are outside training range | model-validation-and-uncertainty |
| **extrapolation risk** | risco de extrapolação | riesgo de extrapolación | Uncertainty arising when a model is applied to conditions outside its calibration range | model-validation-and-uncertainty |

---

## 5. Statistical Methods

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **GLM** | GLM (modelo linear generalizado) | GLM (modelo lineal generalizado) | Generalised Linear Model; extends linear regression to non-normal response distributions | biostatistics-workbench |
| **GLMM** | GLMM (modelo misto generalizado) | GLMM (modelo mixto generalizado) | GLM with random effects to account for grouped or repeated-measures data | biostatistics-workbench |
| **AIC** | AIC (critério de informação de Akaike) | AIC (criterio de información de Akaike) | Model selection criterion balancing fit and complexity; lower is better | biostatistics-workbench |
| **BACI** | BACI (antes-depois, controle-impacto) | BACI (antes-después, control-impacto) | Before-After Control-Impact design; standard framework for detecting ecological impacts | ecological-impact-assessment |
| **PERMANOVA** | PERMANOVA | PERMANOVA | Permutational MANOVA; tests for differences in multivariate composition between groups | community-ecology-ordination |
| **NMDS** | NMDS (escalonamento multidimensional não-métrico) | NMDS (escalamiento multidimensional no métrico) | Non-metric Multidimensional Scaling; ordination technique for community composition data | community-ecology-ordination |
| **PCA** | PCA (análise de componentes principais) | PCA (análisis de componentes principales) | Principal Component Analysis; linear dimensionality reduction | biostatistics-workbench |
| **beta diversity** | diversidade beta | diversidad beta | Variation in species composition between sites; complement to alpha diversity | community-ecology-ordination |
| **Mann-Kendall** | Mann-Kendall | Mann-Kendall | Non-parametric test for monotonic trends in time series; robust to non-normality | environmental-time-series |
| **BFAST** | BFAST | BFAST | Breaks For Additive Season and Trend; detects structural breakpoints in time series | environmental-time-series |

---

## 6. Occupancy & Detection

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **occupancy (psi)** | ocupância (psi) | ocupancia (psi) | Probability that a site is occupied by a species (ψ); estimated separately from detection | occupancy-and-detection |
| **detection probability (p)** | probabilidade de detecção (p) | probabilidad de detección (p) | Probability that a species is detected given that it is present at a site | occupancy-and-detection |
| **imperfect detection** | detecção imperfeita | detección imperfecta | The common situation where p < 1, meaning absences may be false negatives | occupancy-and-detection |
| **detection history** | histórico de detecção | historial de detección | Matrix of 1/0/NA values encoding whether a species was detected on each visit to each site | occupancy-and-detection |
| **naive occupancy** | ocupância ingênua | ocupancia ingenua | Simple proportion of sites where species was detected, ignoring imperfect detection | occupancy-and-detection |
| **single-season model** | modelo de temporada única | modelo de temporada única | Occupancy model assuming sites are closed to colonisation/extinction within the survey season | occupancy-and-detection |
| **RAI** | IAR (índice de atividade relativa) | IAI (índice de actividad relativa) | Relative Activity Index for camera traps: detections per 100 trap-nights | camera-trap-processing |
| **independence threshold** | limiar de independência | umbral de independencia | Minimum time interval between events of the same species at the same station (default 30 min) | camera-trap-processing |

---

## 7. Acoustic Monitoring

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **ACI** | ACI (índice de complexidade acústica) | ACI (índice de complejidad acústica) | Acoustic Complexity Index; measures heterogeneity in amplitude changes within a recording | acoustic-monitoring |
| **NDSI** | NDSI (índice de sonoridade diel normalizado) | NDSI (índice normalizado de sonoridad) | Normalised Difference Soundscape Index; ratio of biophony to anthrophony | acoustic-monitoring |
| **ADI** | ADI (índice de diversidade acústica) | ADI (índice de diversidad acústica) | Acoustic Diversity Index; analogous to Shannon diversity computed over frequency bands | acoustic-monitoring |
| **biophony** | biofonia | biofonía | Sounds produced by living organisms; one component of soundscape | acoustic-monitoring |
| **anthrophony** | antropofonia | antropofonía | Human-generated noise; estimated at high-frequency bands in NDSI | acoustic-monitoring |
| **soundscape** | paisagem sonora | paisaje sonoro | All the sounds within a defined area; characterised through acoustic indices | acoustic-monitoring |
| **BirdNET** | BirdNET | BirdNET | Deep-learning classifier for bird species identification from audio recordings | acoustic-monitoring |

---

## 8. Landscape Ecology & Connectivity

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **habitat patch** | fragmento de habitat | parche de hábitat | Contiguous area of suitable habitat separated from other patches by a matrix | landscape-connectivity |
| **resistance surface** | superfície de resistência | superficie de resistencia | Raster where pixel values represent the cost of movement through each land cover type | landscape-connectivity |
| **corridor** | corredor | corredor | Strip of habitat facilitating animal movement between patches | landscape-connectivity |
| **IIC** | IIC (índice de conectividade integral) | IIC (índice de conectividad integral) | Integral Index of Connectivity; graph-theoretic metric combining area and link importance | landscape-connectivity |
| **dPC** | dPC | dPC | Node removal importance metric based on Probability of Connectivity (PC); used to rank patches | landscape-connectivity |
| **Circuitscape** | Circuitscape | Circuitscape | Circuit theory-based tool for modelling landscape connectivity; identifies pinchpoints | landscape-connectivity |
| **fragmentation** | fragmentação | fragmentación | Process by which a habitat is divided into smaller, more isolated patches | ecological-impact-assessment |
| **MESH** | MESH (habitat efetivo de malha) | MESH (hábitat efectivo de malla) | Effective Mesh Size; fragmentation metric inversely proportional to isolation | ecological-impact-assessment |

---

## 9. Population Ecology

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **lambda (lambda)** | taxa de crescimento populacional (lambda) | tasa de crecimiento poblacional (lambda) | Finite rate of population increase; lambda > 1 = growing, < 1 = declining | population-viability-analysis |
| **elasticity** | elasticidade | elasticidad | Proportional change in lambda resulting from a proportional change in a vital rate | population-viability-analysis |
| **sensitivity** | sensibilidade | sensibilidad | Absolute change in lambda from an absolute change in a vital rate | population-viability-analysis |
| **PVA** | AVP (análise de viabilidade populacional) | AVP (análisis de viabilidad poblacional) | Population Viability Analysis; simulation-based method to estimate extinction probability | population-viability-analysis |
| **quasi-extinction threshold** | limiar de quase-extinção | umbral de cuasi-extinción | Population size below which a population is considered functionally extinct | population-viability-analysis |
| **Leslie matrix** | matriz de Leslie | matriz de Leslie | Age-structured population projection matrix | population-viability-analysis |
| **Lefkovitch matrix** | matriz de Lefkovitch | matriz de Lefkovitch | Stage-structured population projection matrix | population-viability-analysis |
| **IUCN Criterion E** | Critério E da IUCN | Criterio E de la UICN | Quantitative extinction risk criterion using PVA; >= 20% probability of extinction in 20 yrs = EN | population-viability-analysis |

---

## 10. Conservation Planning

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **planning unit** | unidade de planejamento | unidad de planificación | Spatial unit (polygon or raster cell) that can be included or excluded in a reserve network | spatial-prioritization |
| **representation target** | meta de representação | meta de representación | The proportion of a feature's distribution that should be captured within selected planning units | spatial-prioritization |
| **BLM** | BLM (modificador de comprimento de borda) | BLM (modificador de longitud de límite) | Boundary Length Modifier; penalty for fragmented solutions in Marxan/prioritizr | spatial-prioritization |
| **irreplaceability** | insubstituibilidade | irreemplazabilidad | Frequency with which a planning unit appears in all near-optimal solutions | spatial-prioritization |
| **minimum set problem** | problema de conjunto mínimo | problema de conjunto mínimo | Conservation planning objective: meet all targets at minimum cost | spatial-prioritization |
| **30x30** | 30x30 | 30x30 | Global biodiversity target to protect 30% of land and sea by 2030 (Kunming-Montreal GBF) | spatial-prioritization |
| **locked-in area** | área bloqueada (inclusão) | área bloqueada (inclusión) | Planning unit forced into the solution regardless of cost (e.g. existing protected area) | spatial-prioritization |
| **locked-out area** | área bloqueada (exclusão) | área bloqueada (exclusión) | Planning unit excluded from the solution regardless of cost (e.g. urban, legally unavailable) | spatial-prioritization |

---

## 11. Reproducibility & Provenance

| Term | PT | ES | Definition | Skill |
|------|----|----|------------|-------|
| **decision log** | registro de decisões | registro de decisiones | File documenting analytical choices, rationale, and alternatives at each pipeline step | reproducible-ecology-pipeline |
| **parameter manifest** | manifesto de parâmetros | manifiesto de parámetros | Complete record of all settings used to produce a given model or output file | reproducible-ecology-pipeline |
| **provenance** | procedência | procedencia | Traceable history of how a dataset or output was produced, from raw data to final result | reproducible-ecology-pipeline |
| **ODMAP** | ODMAP | ODMAP | Overview, Data, Model, Assessment, Prediction — standard SDM reporting protocol (Zurell et al. 2020) | reproducible-ecology-pipeline |
| **DOI** | DOI | DOI | Digital Object Identifier; persistent link to a citable dataset or publication | ecological-data-foundation |
| **renv** | renv | renv | R package for project-level dependency management and reproducible environments | reproducible-ecology-pipeline |
| **SPDX** | SPDX | SPDX | Software Package Data Exchange standard for expressing license information in source files | reproducible-ecology-pipeline |
