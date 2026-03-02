# MaxEnt Calibration Guide

Regularization, feature classes, model selection, and calibration grid for maxnet/ENMeval.

---

## 1. Regularization Multiplier (RM) and Feature Classes (FC)

MaxEnt (and its R equivalent **maxnet**) controls model complexity through two parameters:

### Regularization Multiplier (RM)

RM penalises model complexity. Think of it as a smoothing parameter:

| RM value | Effect |
|---|---|
| < 1 | Under-regularised — risk of **overfitting** (model memorises noise in occurrence data) |
| 1 (default) | Often appropriate for large, clean datasets |
| 1.5 – 2 | Recommended starting point for typical GBIF datasets |
| 3 – 6 | High smoothing — appropriate for very small n, noisy data, or wide-ranging species |

### Feature Classes (FC)

FC determines which response curve shapes are available to the model:

| FC code | Name | Response shape allowed | Risk |
|---|---|---|---|
| **L** | Linear | Monotonic linear relationship | Very simple; may underfit |
| **Q** | Quadratic | Unimodal response (bell curve) | Good default for most ecological variables |
| **H** | Hinge | Piecewise linear with breakpoint | Flexible; needs more data to fit reliably |
| **P** | Product | Interactions between pairs of predictors | Can model synergies; risk of overfitting |
| **T** | Threshold | Step function | Extreme flexibility; high overfitting risk |

Combinations are additive: `LQ` allows both linear and quadratic features; `LQHPT` allows all five.

**Typical recommendation:** Start with `LQ` or `LQH`; add `P` and `T` only with > 100 clean occurrences and only if AICc improves substantially.

---

## 2. Model Selection Criteria

### Why AUC alone is insufficient

AUC measures discrimination (can the model rank presences above absences?) but does **not**
detect overfitting to the calibration area. A highly over-fitted model can have AUC = 0.99
in calibration but fail completely in independent validation.

### Recommended criteria (in priority order)

| Criterion | What it measures | Threshold / rule |
|---|---|---|
| **OR10** (Omission Rate at 10%) | Whether the model omits 10% of training points at the selected threshold | Must be ≤ expected omission rate (0.10); lower is better |
| **AICc** | Model complexity-penalised fit (Akaike Information Criterion, corrected) | Select model(s) with lowest AICc; models within delta_AICc < 2 are equivalent |
| **Partial ROC** | AUC computed only over the biologically relevant part of the ROC curve | Ratio > 1 (compared to random); higher is better |
| **AUC (train)** | Training set AUC | Supplementary only — not a selection criterion |

**Peterson et al. 2008** showed that omission rate is a more ecologically meaningful
criterion than AUC for evaluating niche model performance.
DOI: [10.1016/j.ecolmodel.2007.11.008](https://doi.org/10.1016/j.ecolmodel.2007.11.008)

**Warren & Seifert 2011** introduced the OR_AICc approach: select models with low
omission rate AND low AICc to balance predictive accuracy and parsimony.
DOI: [10.1890/10-1171.1](https://doi.org/10.1890/10-1171.1)

### OR_AICc selection rule (recommended)

1. Filter all models where `OR10 <= 0.10 + tolerance` (tolerance = 0.05 recommended)
2. Among passing models, select those with `delta_AICc < 2`
3. If multiple models pass, report ensemble or select the most parsimonious (fewest parameters)

---

## 3. Recommended Calibration Grid

Use this 35-model grid as the default for `tune_maxnet.R`:

```
RM  = c(0.5, 1, 1.5, 2, 3, 4, 6)
FC  = c("L", "LQ", "LQH", "LQHP", "LQHPT")
```

Total combinations: 7 × 5 = **35 models**

For species with n_clean < 50, restrict to:
```
RM = c(1, 2, 3, 4, 6)
FC = c("L", "LQ", "LQH")
```

---

## 4. kuenm vs ENMeval + maxnet

| Feature | kuenm (maxent.jar) | ENMeval + maxnet |
|---|---|---|
| Engine | MaxEnt Java `.jar` | maxnet (R-native, no Java) |
| Java required | **Yes** | **No** |
| CRAN installable | No (manual download) | **Yes** |
| Calibration parallelism | Yes (via Java threads) | Yes (via `parallel` package) |
| Output metrics | OR, AUC, AICc, pROC | OR, AUC, AICc |
| Partial ROC | Built-in | Separate `ENMeval::eval.stats()` |
| Reproducibility | Depends on MaxEnt version | Fully reproducible in R |
| Recommended for this repo | No | **Yes** |

**Why ENMeval in this repo:**
- No Java dependency → simpler CI, reproducible environments
- `maxnet` produces identical predictions to MaxEnt (Phillips et al. 2017)
- `ENMeval >= 2.0` provides a standardised, tidy interface
- Easily integrated with `terra` and `sf` pipelines

---

## 5. Interpreting Calibration Results

### delta_AICc table

```
delta_AICc < 2     → Model is equivalent to best model; all are candidates
delta_AICc 2–7     → Some support for this model; use with caution
delta_AICc > 7     → Little to no support; exclude from ensemble
```

### Omission rate × AUC plot

```
Good model: low OR10 (y-axis) + high AUC (x-axis) → lower-right quadrant
Overfitted: very low OR10 (memorised training data) + moderate validation AUC
Underfitted: OR10 > 0.15 (misses known occurrences)
```

When reading the plot: **prioritise OR10 first, then AUC**. A model with OR10 = 0.08
and AUC = 0.82 is better than OR10 = 0.02 and AUC = 0.91 (the latter is likely overfitted).

### Quick-reference checklist

| Check | Pass condition |
|---|---|
| OR10 ≤ 0.15 | Model does not severely omit known occurrences |
| delta_AICc < 2 for selected model | Model is parsimonious |
| Training AUC > 0.70 | Model performs above random |
| No single FC dominates (e.g., all T features) | Model not over-complex |
| Selected RM in middle of grid (not 0.5 or 6) | RM not at boundary — extend grid if needed |

---

## 6. R Code Example

```r
suppressPackageStartupMessages(library(ENMeval))
suppressPackageStartupMessages(library(terra))

# Load data
occ  <- read.csv("tests/data/points_with_env.csv")
env  <- rast("data/predictors/env_stack.tif")

occ_pts  <- occ[, c("decimalLongitude", "decimalLatitude")]
env_vals <- as.data.frame(extract(env, occ_pts))

# Background points (10,000 random within study area)
bg <- spatSample(env, size = 10000, method = "random",
                 na.rm = TRUE, as.df = TRUE, xy = TRUE)
bg_pts <- bg[, c("x", "y")]

# Calibration grid
eval_out <- ENMevaluate(
  occs      = occ_pts,
  envs      = env,
  bg        = bg_pts,
  algorithm = "maxnet",
  partitions = "block",          # spatial cross-validation
  tune.args  = list(
    rm = c(0.5, 1, 1.5, 2, 3, 4, 6),
    fc = c("L", "LQ", "LQH", "LQHP", "LQHPT")
  )
)

# View results table
res <- eval.results(eval_out)
head(res[order(res$AICc), ])

# Select best model by OR_AICc criterion
best <- res[res$or.10p.avg <= 0.15 & res$delta.AICc < 2, ]
```

---

## 7. Common Pitfalls

- **RM too low (e.g., 0.5):** model memorises training localities; performs poorly in
  independent validation. Symptom: very jagged, patchy suitability map.
- **RM too high (e.g., 6):** model is overly smooth and may miss real habitat patches.
  Symptom: very broad, featureless map regardless of species ecology.
- **Using AUC as the sole selection criterion:** rewards discrimination but not calibration.
  Always pair with OR10.
- **Not running spatial CV:** random k-fold CV inflates AUC due to spatial autocorrelation.
  Always use `partitions="block"` or `"checkerboard"` in ENMeval.
- **Grid boundary effects:** if best RM is 0.5 or 6 (grid edges), extend the grid and re-run.
- **Not checking layer names:** maxnet uses column names from the training data to match
  projection layers. Mismatch causes silent errors or wrong predictions.

---

## 8. References

| Citation | DOI |
|---|---|
| Peterson et al. 2008. Ecol. Model. 213: 63–72 | [10.1016/j.ecolmodel.2007.11.008](https://doi.org/10.1016/j.ecolmodel.2007.11.008) |
| Warren & Seifert 2011. Ecol. Apps. 21: 335–342 | [10.1890/10-1171.1](https://doi.org/10.1890/10-1171.1) |
| Phillips et al. 2017. Ecography 40: 913–922 (maxnet) | [10.1111/ecog.03049](https://doi.org/10.1111/ecog.03049) |
| Muscarella et al. 2014. Meth. Ecol. Evol. (ENMeval v1) | [10.1111/2041-210X.12261](https://doi.org/10.1111/2041-210X.12261) |
| Kass et al. 2021. Meth. Ecol. Evol. (ENMeval v2) | [10.1111/2041-210X.13628](https://doi.org/10.1111/2041-210X.13628) |
