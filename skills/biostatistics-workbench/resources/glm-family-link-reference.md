# GLM Family and Link Function Reference

## Common Families and Links

| Family | Default link | Canonical use | R syntax |
|--------|-------------|---------------|---------|
| `gaussian` | identity | Continuous, normal | `glm(y ~ x, family = gaussian)` |
| `Gamma` | inverse | Positive continuous, right-skewed | `glm(y ~ x, family = Gamma(link="log"))` |
| `inverse.gaussian` | 1/mu² | Positive continuous, extreme skew | `glm(y ~ x, family = inverse.gaussian)` |
| `binomial` | logit | Binary (0/1), proportion (cbind) | `glm(y ~ x, family = binomial)` |
| `quasibinomial` | logit | Binary, overdispersed | `glm(y ~ x, family = quasibinomial)` |
| `poisson` | log | Count data | `glm(y ~ x, family = poisson)` |
| `quasipoisson` | log | Count, overdispersed | `glm(y ~ x, family = quasipoisson)` |
| `nbinom2` (glmmTMB) | log | Count, overdispersed (NB) | `glmmTMB(y ~ x, family = nbinom2)` |
| `tweedie` | log | Zero-inflated continuous (precipitation) | `glmmTMB(y ~ x, family = tweedie)` |
| `beta_family` | logit | Proportion (0,1) exclusive | `glmmTMB(y ~ x, family = beta_family)` |
| `ordbeta` | logit | Proportion including 0 and 1 | `glmmTMB(y ~ x, family = ordbeta)` |
| `truncated_poisson` | log | Count with no zeros | `glmmTMB(y ~ x, family = truncated_poisson)` |

## Checking Overdispersion (Poisson)

```r
# After fitting a Poisson GLM:
dispersion_ratio <- sum(residuals(model, type = "pearson")^2) / df.residual(model)
# If dispersion_ratio >> 1 (>1.5), switch to quasipoisson or negative binomial
```

## Checking Distributional Assumptions with DHARMa

```r
library(DHARMa)
sim_res <- simulateResiduals(fittedModel = model, plot = TRUE)
# Provides: QQ plot, residuals vs fitted, uniformity test
testDispersion(sim_res)
testZeroInflation(sim_res)
testOutliers(sim_res)
```

## Link Function Interpretation

| Link | Function | Interpretation of coefficient |
|------|----------|-------------------------------|
| identity | η = μ | 1-unit change in x → β change in y (additive) |
| log | η = log(μ) | 1-unit change in x → exp(β) multiplicative change in y |
| logit | η = log(μ/(1−μ)) | 1-unit change in x → exp(β) odds ratio |
| inverse | η = 1/μ | Less common; log link usually preferred for Gamma |
| sqrt | η = √μ | Intermediate between identity and log |
