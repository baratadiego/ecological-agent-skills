# Effect Size Reference for Ecological Statistics

Effect sizes quantify the **magnitude** of an effect independently of sample size. Always report them alongside p-values.

## Continuous Response (t-tests, ANOVA, LMM)

| Measure | Formula | Interpretation | R function |
|---------|---------|---------------|-----------|
| Cohen's d | (μ₁ − μ₂) / SD_pooled | 0.2 = small, 0.5 = medium, 0.8 = large | `effectsize::cohens_d()` |
| Hedges' g | Cohen's d × correction factor | Preferred for unequal n | `effectsize::hedges_g()` |
| η² (eta-squared) | SS_effect / SS_total | % variance explained by factor | `effectsize::eta_squared()` |
| ω² (omega-squared) | Bias-corrected η² | Preferred over η² for small n | `effectsize::omega_squared()` |
| partial η² | SS_effect / (SS_effect + SS_residual) | For multiple predictors | `effectsize::eta_squared(partial=TRUE)` |
| R² / R²_adj | Model variance explained | 0.01 = tiny, 0.09 = small, 0.25 = large | `performance::r2()` |
| R²_m, R²_c | Marginal / conditional R² for LMMs | R²_m = fixed only; R²_c = fixed + random | `performance::r2()` |

## Binary Response (logistic regression, GLM binomial)

| Measure | Interpretation | How to compute |
|---------|---------------|----------------|
| Odds ratio (OR) | exp(β); OR = 1 means no effect | `exp(coef(model))` |
| OR 95% CI | exp(confint(model)) | `exp(confint(model))` |
| Risk ratio (RR) | More interpretable than OR when prevalence is high | Compute from marginal predictions |
| Cohen's h | h = 2arcsin(√p₁) − 2arcsin(√p₂) | `effectsize::cohens_h()` |
| Cramér's V | For chi-square tests; 0–1 | `effectsize::cramers_v()` |

## Count Response (Poisson, negative binomial)

| Measure | Interpretation |
|---------|---------------|
| Rate ratio (IRR) | exp(β); multiplicative effect on count |
| % change | (exp(β) − 1) × 100% |
| McFadden's pseudo-R² | 1 − LL_model/LL_null; > 0.2 = good fit |

## Non-Parametric Tests

| Test | Effect size | Measure | Range |
|------|------------|---------|-------|
| Mann-Whitney U | Rank-biserial r | r = 1 − 2U/(n₁×n₂) | -1 to 1 |
| Wilcoxon signed-rank | r = Z/√N | | -1 to 1 |
| Kruskal-Wallis | η²_H = (H − k + 1) / (n − k) | | 0 to 1 |
| Spearman | ρ (rho) | | -1 to 1 |

## Multivariate (PERMANOVA)

| Measure | Interpretation |
|---------|---------------|
| R² from adonis2 | Proportion of dissimilarity explained by the factor |
| Partial R² | For models with multiple terms |

**Note:** PERMANOVA R² tends to be modest even for ecologically strong effects; R² = 0.15–0.30 is typical and meaningful in community ecology.

## Benchmarks Summary

| Size | d | r | R² | OR |
|------|---|---|----|----|
| Negligible | < 0.2 | < 0.10 | < 0.01 | < 1.5 |
| Small | 0.2–0.5 | 0.10–0.30 | 0.01–0.09 | 1.5–3.0 |
| Medium | 0.5–0.8 | 0.30–0.50 | 0.09–0.25 | 3.0–6.0 |
| Large | > 0.8 | > 0.50 | > 0.25 | > 6.0 |

## R Package: effectsize

```r
library(effectsize)
library(lme4)

# From a t-test
t_result <- t.test(group1, group2)
cohens_d(group1, group2)

# From a linear model
m <- lm(richness ~ land_use + elevation, data = dat)
eta_squared(m)          # η² for each term
omega_squared(m)        # bias-corrected

# From a GLM
m_glm <- glm(presence ~ forest_cover, family = binomial, data = dat)
exp(coef(m_glm))        # odds ratios
exp(confint(m_glm))     # 95% CI for ORs
```
