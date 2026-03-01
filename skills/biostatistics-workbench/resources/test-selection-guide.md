# Statistical Test Selection Guide

## Step 1 — What is your goal?

```
Compare groups → Step 2
Assess relationship → Step 5
Predict a response → Step 7
Describe distribution → Step 9
```

## Step 2 — Comparing Groups: How many?

```
2 groups → Step 3
3+ groups → Step 4
```

## Step 3 — Comparing 2 Groups

| Data type | Independent? | Parametric? | Test |
|-----------|-------------|-------------|------|
| Continuous | Yes | Yes (normal, equal var) | t-test (Student's) |
| Continuous | Yes | Yes (normal, unequal var) | t-test (Welch's) |
| Continuous | Yes | No | Mann-Whitney U |
| Continuous | No (paired) | Yes | Paired t-test |
| Continuous | No (paired) | No | Wilcoxon signed-rank |
| Binary proportion | Yes | — | Chi-square / Fisher's exact |
| Count | Yes | — | Poisson test |

## Step 4 — Comparing 3+ Groups

| Data type | Design | Test | Post-hoc |
|-----------|--------|------|---------|
| Continuous, normal, equal var | 1 factor | One-way ANOVA | Tukey HSD |
| Continuous, non-normal | 1 factor | Kruskal-Wallis | Dunn's |
| Continuous | 2 factors | Two-way ANOVA | Tukey / emmeans |
| Continuous, repeated measures | 1 factor | Repeated-measures ANOVA | emmeans |
| Count data | Groups | GLM Poisson | emmeans on log scale |
| Binary | Groups | GLM Binomial | emmeans |

## Step 5 — Association / Correlation

| Data type | Test | Coefficient |
|-----------|------|-------------|
| Continuous vs continuous, linear | Pearson | r |
| Continuous vs continuous, non-linear / ranks | Spearman | ρ |
| Ordinal vs ordinal | Kendall | τ |
| Binary vs binary | Chi-square | φ (phi) |
| Continuous vs binary | Point-biserial | r_pb |

## Step 6 — Multivariate Association

| Goal | Method |
|------|--------|
| Community similarity | Bray-Curtis / Jaccard dissimilarity |
| Community differences between groups | PERMANOVA |
| Gradient ordination | NMDS, PCA, RDA |
| Taxon association network | Co-occurrence analysis |

## Step 7 — Predicting a Response

| Response type | Distribution | Model |
|--------------|-------------|-------|
| Continuous, normal | Gaussian | LM / LMM |
| Continuous, positive skew | Log-normal or Gamma | GLM Gamma |
| Count, no excess zeros | Poisson | GLM Poisson |
| Count, overdispersed | Negative binomial | GLM NB (glmmTMB) |
| Count, zero-inflated | Zero-inflated Poisson/NB | glmmTMB |
| Binary (presence/absence) | Binomial | GLM Logistic |
| Proportion (0–1) | Beta | betareg |
| Ordinal | Ordered logistic | polr / clm |
| Multivariate community | — | RDA, CCA, mvabund |

## Step 8 — Random Effects?

Add random effects if:
- Data are nested (plots within sites within regions)
- Data are repeated measures on the same individual/site
- Groups are a random sample of a larger population

Use `lme4::lmer()` (Gaussian) or `lme4::glmer()` / `glmmTMB::glmmTMB()` (non-Gaussian).

## Step 9 — Normality Tests

| Test | Use | Package |
|------|-----|---------|
| Shapiro-Wilk | n < 50 (most powerful for small n) | base R `shapiro.test()` |
| Kolmogorov-Smirnov | Large samples | base R `ks.test()` |
| Lilliefors | Large samples, unknown μ/σ | `nortest::lillie.test()` |
| Q-Q plot | Visual, any n | base R `qqnorm()` |

**Note:** Normality tests are sensitive to n. For large datasets, trivial departures become significant. Always inspect Q-Q plots in addition to test p-values.
