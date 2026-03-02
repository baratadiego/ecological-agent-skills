---
skill_version: 1.0.0
---

# Skill: biostatistics-workbench

**Domain:** Hypothesis testing · GLM/GLMM · Assumptions · Effect sizes · CIs  
**Phase:** 1 — Foundation  
**Used by:** assess-ecological-impact, analyze-community-structure, run-occupancy-analysis, assess-ecosystem-services

---

## Purpose

Guides the agent through the selection, execution, and interpretation of statistical methods appropriate for ecological data. Covers classical tests, generalised linear models, mixed models, assumption diagnostics, effect size estimation, and model selection.

---

## When to Invoke

- Choosing a statistical test for a specific research question and data structure
- Fitting GLM or GLMM with ecological response variables
- Checking distributional assumptions (normality, homoscedasticity, independence)
- Reporting effect sizes and confidence intervals
- Performing model selection (AIC, LRT, cross-validation)

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Response variable(s) | Numeric or count vector | Yes |
| Predictor variable(s) | Numeric, categorical, or both | Yes |
| Random effects structure (if any) | Description or formula | Conditional |
| Study design description | Text | Recommended |

---

## Outputs

| Output | Description |
|--------|-------------|
| `model_summary.txt` | Full model output (coefficients, SE, z/t, p) |
| `model_selection_table.csv` | AIC/BIC/ΔAIC comparison across candidate models |
| `assumption_diagnostics/` | Residual plots, QQ plots, variance inflation factors |
| `effect_sizes.csv` | Effect size estimates with 95% CIs |
| `stats_report.md` | Plain-language interpretation of results |

---

## Steps

### 1. Define the Research Question and Data Structure
- Clarify the response variable type: continuous, count, binary, proportion, ordinal
- Clarify the predictor types: fixed categorical, fixed continuous, random grouping
- Identify the sampling design: independent, nested, repeated measures, spatial

### 2. Select the Appropriate Method

| Response | Distribution | Recommended model |
|----------|-------------|------------------|
| Continuous, normal | Gaussian | LM / LMM |
| Continuous, non-normal | Log-normal, Gamma | GLM Gamma / LM on log |
| Count, no excess zeros | Poisson | GLM Poisson |
| Count, overdispersed | Negative binomial | GLM NB |
| Count, zero-inflated | ZIP / ZINB | Zero-inflated model |
| Binary (0/1) | Binomial | GLM logistic |
| Proportion (0–1) | Beta | Beta regression |
| Ordinal | Ordered | Proportional odds model |

### 3. Check Assumptions Before Fitting
- Collinearity: compute VIF for all predictors (flag VIF > 5; critical > 10)
- Sample size adequacy: events-per-variable rule (EPV ≥ 10 for logistic)
- Independence: confirm no pseudoreplication; identify random effects structure

### 4. Fit Model(s)
- Fit the global model first
- Fit a set of candidate models based on a priori hypotheses
- Avoid purely data-driven stepwise selection; document candidate model rationale

### 5. Check Assumptions After Fitting
- Residual plots (Pearson, deviance, randomised quantile residuals for GLMs)
- QQ plot of residuals
- Residuals vs fitted values
- Scale-location plot for heteroscedasticity
- Cook's distance for influential observations

### 6. Model Selection
- Compute AIC/AICc/BIC for all candidate models
- Report ΔAIC and Akaike weights
- Use LRT for nested model comparison
- Avoid selecting models based on p-value alone

### 7. Report Effect Sizes and CIs
- Report standardised coefficients (βstd) for comparability
- Report 95% CI for all estimates (profile likelihood preferred over Wald for GLMs)
- Report R²m and R²c for LMMs (marginal and conditional)

### 8. Generate Outputs
- Write model summary to `model_summary.txt`
- Write model selection table to `model_selection_table.csv`
- Save all diagnostic plots to `assumption_diagnostics/`
- Write `stats_report.md` with plain-language interpretation

---

## Key Decisions to Document

- Response variable distribution and link function
- Random effects structure and rationale
- Candidate model set and justification
- Model selection criterion used
- Effect size metric chosen

---

## Tools and Libraries

**R:** `lme4`, `glmmTMB`, `MuMIn`, `DHARMa`, `emmeans`, `performance`, `effectsize`  
**Python:** `statsmodels`, `pymer4`, `pingouin`, `scipy.stats`

---

## Resources

- `resources/test-selection-guide.md` — flowchart for test selection
- `resources/glm-family-link-reference.md` — GLM family and link function guide
- `resources/effect-size-reference.md` — which effect size to report per test
- `examples/` — worked GLM and GLMM examples

---

## Notes

- Never report p-values without effect sizes
- Multiple comparisons: apply Bonferroni or FDR correction when testing many hypotheses
- Overdispersion in Poisson models must always be checked (dispersion parameter)
