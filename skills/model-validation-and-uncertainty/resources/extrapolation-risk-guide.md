# Extrapolation Risk Guide

Assessing environmental novelty before interpreting model projections.

---

## 1. Interpolation vs Extrapolation in Environmental Space

A species distribution model learns relationships between occurrence records and
environmental predictors within the **calibration area** (M area). When a model
is projected to a new region or time period, every prediction pixel falls into one
of two categories:

| Category | Definition | Risk |
|---|---|---|
| **Interpolation** | Pixel lies within the multivariate environmental range seen at calibration | Low — model is working within its learned space |
| **Extrapolation (strict)** | Pixel has at least one predictor value outside the full range observed in calibration | High — model must extrapolate; response is undefined |
| **Extrapolation (combinatorial)** | Pixel has individual values within calibration range, but their *combination* was not observed | Medium-High — subtler but still novel |

**Key principle:** All three methods below (MOP, ExDet, MESS) detect different
aspects of environmental novelty. None of them tells you *whether* the model will
extrapolate correctly — only that it *is* extrapolating.

---

## 2. MOP — Mobility-Oriented Parity

**Reference:** Owens et al. 2013. Constraints on interpretation of ecological niche
models by limited environmental ranges on calibration areas.
*Ecological Modelling* 263: 10–18.
DOI: [10.1016/j.ecolmodel.2013.04.011](https://doi.org/10.1016/j.ecolmodel.2013.04.011)

### What MOP measures

MOP computes, for each projection pixel, the proportion of calibration points that
fall *closer* (in multivariate Euclidean space) than the projection pixel itself.

- **Scale:** 0 to 1
- **MOP = 1:** pixel is well within calibration environmental range
- **MOP = 0:** strict extrapolation — the pixel is more extreme than *all* calibration points in at least one predictor dimension
- **MOP = 0.1:** only 10% of calibration points are environmentally similar

### Interpretation

| MOP value | Interpretation | Action |
|---|---|---|
| > 0.75 | Safe interpolation | Interpret predictions normally |
| 0.50 – 0.75 | Moderate novelty | Report with caution |
| 0.25 – 0.50 | High novelty | Flag in figure caption |
| < 0.25 | Very high novelty | Strong caveat; consider masking |
| = 0 | Strict extrapolation | Mask in publication figures |

### R implementation (terra)

```r
# MOP function using terra (no Java required)
calc_mop <- function(train_stack, proj_stack, prop = 0.1) {
  suppressPackageStartupMessages(library(terra))

  # Extract calibration values
  cal_vals <- as.data.frame(train_stack, na.rm = TRUE)
  proj_vals <- as.data.frame(proj_stack, na.rm = TRUE)
  n_cal <- nrow(cal_vals)
  n_vars <- ncol(cal_vals)

  # For each projection pixel, compute proportion of calibration points
  # that are "closer" (Euclidean distance in scaled predictor space)
  cal_scaled <- scale(cal_vals)
  center <- attr(cal_scaled, "scaled:center")
  sdev   <- attr(cal_scaled, "scaled:scale")

  proj_scaled <- sweep(sweep(proj_vals, 2, center, "-"), 2, sdev, "/")

  mop_vals <- apply(proj_scaled, 1, function(px) {
    if (any(is.na(px))) return(NA)
    d_px_to_cal <- sqrt(rowSums(sweep(cal_scaled, 2, px, "-")^2))
    d_cal_centroid <- sqrt(rowSums(cal_scaled^2))
    # proportion of calibration points less extreme than projection pixel
    sum(d_cal_centroid < quantile(d_px_to_cal, prop)) / n_cal
  })

  # Place back into raster
  mop_rast <- proj_stack[[1]]
  values(mop_rast) <- mop_vals
  names(mop_rast) <- "MOP"
  return(mop_rast)
}
```

---

## 3. ExDet — Extrapolation Detection

**Reference:** Mesgaran et al. 2014. Here be dragons: a tool for quantifying novelty
due to covariate range and collinearity extrapolation when predicting species
distributions. *Diversity and Distributions* 20: 1147–1159.
DOI: [10.1111/ddi.12209](https://doi.org/10.1111/ddi.12209)

### What ExDet measures

ExDet distinguishes two types of extrapolation:

| Type | Code | Meaning |
|---|---|---|
| **NT1** (univariate) | Negative value | At least one predictor is outside its calibration min–max range |
| **NT2** (combinatorial) | 0 to 1 | All predictors in range, but combination novel; value = Mahalanobis-based dissimilarity |
| **Interpolation** | > 1 | Pixel well within calibration cloud |

**NT1 extrapolation is the most dangerous** — the model is predicting beyond any
observed value for that variable. NT2 is subtler but still represents novel
environmental combinations that the model has not seen.

### R code (manual ExDet)

```r
calc_exdet <- function(train_mat, proj_mat) {
  # Standardize using calibration mean and sd
  mu  <- colMeans(train_mat, na.rm = TRUE)
  sig <- apply(train_mat, 2, sd, na.rm = TRUE)
  S   <- cov(train_mat, use = "complete.obs")
  S_inv <- solve(S)

  apply(proj_mat, 1, function(px) {
    if (any(is.na(px))) return(NA)
    px_s <- (px - mu) / sig
    tr_s <- sweep(train_mat, 2, mu, "-")
    tr_s <- sweep(tr_s, 2, sig, "/")
    # NT1: univariate extrapolation
    below <- any(px < apply(train_mat, 2, min, na.rm = TRUE))
    above <- any(px > apply(train_mat, 2, max, na.rm = TRUE))
    if (below || above) {
      # NT1 score: negative, proportional to extent of extrapolation
      return(-1 * max(abs(px_s) - apply(abs(tr_s), 2, max)))
    }
    # NT2: Mahalanobis-based combinatorial novelty
    mah_px  <- t(px - mu) %*% S_inv %*% (px - mu)
    mah_ref <- median(apply(train_mat, 1, function(r) t(r - mu) %*% S_inv %*% (r - mu)))
    return(as.numeric(mah_ref / mah_px))
  })
}
```

---

## 4. MESS — Multivariate Environmental Similarity Surfaces

**Package:** `dismo` (R)

**Reference:** Elith et al. 2010. The art of modelling range-shifting species.
*Methods in Ecology and Evolution* 1: 330–342.
DOI: [10.1111/j.2041-210X.2010.00036.x](https://doi.org/10.1111/j.2041-210X.2010.00036.x)

### What MESS measures

MESS computes a similarity score for each projection pixel relative to the
calibration reference set. Negative MESS values indicate novel environments.

```r
suppressPackageStartupMessages(library(dismo))
suppressPackageStartupMessages(library(terra))

# Reference points from calibration area
ref_pts <- as.data.frame(train_stack, na.rm = TRUE)

# MESS calculation
mess_rast <- mess(proj_stack, ref_pts, full = FALSE)
```

- **MESS > 0:** similar to calibration set
- **MESS = 0:** boundary of calibration range
- **MESS < 0:** novel environment; magnitude indicates degree of novelty

---

## 5. Comparative Summary

| Method | What it detects | Scale | Distinguishes NT1/NT2 | R package | Java needed |
|---|---|---|---|---|---|
| **MOP** | Overall proximity to calibration cloud | 0–1 (continuous) | No | `terra` (custom) | No |
| **ExDet** | Univariate (NT1) and combinatorial (NT2) extrapolation | Continuous (negative=NT1, 0–1=NT2) | Yes | Custom / `ntbox` | No |
| **MESS** | Multivariate similarity | Continuous (negative=novel) | No | `dismo` | No |

**Recommendation for publication:**
- **Minimum:** always compute MOP; mask MOP = 0 pixels in figures
- **Recommended:** compute MESS alongside MOP for independent confirmation
- **Full analysis:** use ExDet to distinguish NT1 from NT2 when many predictors exceed range

---

## 6. Practical Recommendations

1. **Always run MOP before interpreting future projections.** Do not publish
   suitability maps without showing MOP alongside them.
2. **Mask MOP = 0 pixels in publication figures.** Use `terra::mask()` with the
   MOP layer thresholded at 0.
3. **Report the % of projection area with MOP < 0.25** in the methods section.
4. If > 30% of the area has MOP < 0.25, add an explicit caveat in the abstract
   or results section.
5. For climate change projections, MOP to future periods tends to increase with
   more extreme SSPs and longer time horizons — always report SSP-specific MOP.

### Concern thresholds

| % area with MOP < 0.25 | Recommended action |
|---|---|
| < 10% | Note in methods, no figure modification needed |
| 10–30% | Report in results; add caption noting extrapolation zones |
| 30–50% | Mask those pixels in primary figure; show MOP map in supplement |
| > 50% | Strong caveat in abstract; consider restricting projection area |

---

## 7. Common Pitfalls

- **Ignoring MOP entirely:** projecting to future SSP5-8.5 without any novelty
  assessment is a major reviewer concern and methodological flaw.
- **Confusing MESS negative values with unsuitable habitat:** MESS < 0 means
  *novel environment*, not predicted *absence*. These are independent signals.
- **Using only one method:** MOP and MESS are complementary; using both strengthens
  the analysis.
- **Not separating NT1 from NT2 when temperatures exceed calibration range:** for
  climate change projections where temperature strictly exceeds historical range,
  NT1 extrapolation is certain — ExDet makes this explicit.
- **Masking too aggressively:** masking all MOP < 0.5 may remove large fractions
  of a species' current range. Use MOP = 0 as the primary mask.

---

## 8. References

| Citation | DOI |
|---|---|
| Owens et al. 2013. Ecol. Model. 263:10–18 | [10.1016/j.ecolmodel.2013.04.011](https://doi.org/10.1016/j.ecolmodel.2013.04.011) |
| Mesgaran et al. 2014. Div. Dist. 20:1147–1159 | [10.1111/ddi.12209](https://doi.org/10.1111/ddi.12209) |
| Elith et al. 2010. Meth. Ecol. Evol. 1:330–342 | [10.1111/j.2041-210X.2010.00036.x](https://doi.org/10.1111/j.2041-210X.2010.00036.x) |
| Peterson et al. 2011. Ecological Niches and Geographic Distributions. Princeton UP | ISBN 978-0691136882 |
