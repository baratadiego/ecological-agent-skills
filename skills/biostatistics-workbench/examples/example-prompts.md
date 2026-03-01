# Example Invocation Prompts — biostatistics-workbench

## GLM for Species Richness

```
Load skill: biostatistics-workbench
Task: I have species richness counts (count variable, integers) at 80 plots
across three vegetation types (factor: "forest", "savanna", "wetland").
Additional predictors: elevation (m), precipitation (mm/year), distance_to_edge (m).
Fit an appropriate GLM, check assumptions, select the best model by AICc,
and report effect sizes with 95% CIs.
Data file: data/processed/richness_data.csv
```

## BACI Mixed Model

```
Load skill: biostatistics-workbench
Task: BACI analysis of bird abundance before and after road construction.
Response: bird_abundance (count)
Fixed effects: period (before/after), treatment (control/impact), period:treatment interaction
Random effects: site (repeated measures)
Data: data/baci_birds.csv
Report: BACI interaction coefficient, 95% CI, p-value, Cohen's d.
```

## Assumption Checking

```
Load skill: biostatistics-workbench
Task: I fitted a Poisson GLM (model object saved in models/glm_poisson.rds).
Run a full assumption check using DHARMa:
  - Uniformity test
  - Dispersion test
  - Zero-inflation test
  - Outlier test
Save all diagnostic plots to outputs/diagnostics/.
If overdispersion detected, refit with negative binomial and compare AIC.
```
