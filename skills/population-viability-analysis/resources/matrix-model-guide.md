---
resource_id: matrix-model-guide
skill_id: population-viability-analysis
---

# Population Matrix Model Guide

## Leslie vs Lefkovitch Matrix

| Feature | Leslie matrix | Lefkovitch matrix |
|---------|--------------|------------------|
| Stage definition | Age classes (1, 2, 3, … years) | Life-history stages (juvenile, subadult, adult) |
| Transition type | Survival only along super-diagonal | Survival + stasis (diagonal) |
| Data requirement | Age-specific survival and fecundity | Stage-specific survival, growth, stasis, fecundity |
| Best for | Species with fixed maturation age | Species with variable development time |
| Examples | Annual birds with known maximum age | Sea turtles, forest trees, long-lived mammals |

---

## Matrix Structure

### Leslie matrix (3 age classes)

```
A = | F1   F2   F3  |   ← fecundity row (top)
    | P1   0    0   |   ← survival to next age
    | 0    P2   P3  |   ← P3 = adult survival (loop)
```

Where:
- Fᵢ = age-specific fecundity (offspring produced per individual in age class i)
- Pᵢ = probability of surviving from age class i to i+1

### Lefkovitch matrix (juvenile–subadult–adult)

```
A = | 0    0    F   |   ← adults produce offspring
    | Gj   Sj   0   |   ← Gj = juvenile growth rate, Sj = juvenile stasis
    | 0    Gsa  Sa  |   ← Sa = adult survival (stasis), Gsa = subadult growth
```

---

## Computing λ and Sensitivity/Elasticity in R

```r
suppressPackageStartupMessages(library(popbio))

# Example: 3-stage Lefkovitch matrix for a long-lived reptile
A <- matrix(c(
  0,    0,    0.8,   # fecundity (adults only)
  0.3,  0.6,  0,     # juvenile → subadult growth (0.3) + juvenile stasis (0.6)? No.
  0,    0.7,  0.9    # subadult growth + adult survival
), nrow = 3, ncol = 3, byrow = TRUE)

# Dominant eigenvalue (population growth rate)
lambda_val <- lambda(A)
cat(sprintf("Lambda (λ) = %.4f\n", lambda_val))
# λ > 1: growing; λ = 1: stable; λ < 1: declining

# Stable stage distribution
w <- stable.stage(A)
cat("Stable stage distribution:", round(w, 3), "\n")

# Reproductive value
v <- reproductive.value(A)
cat("Reproductive value:", round(v, 3), "\n")

# Sensitivity matrix (∂λ/∂aᵢⱼ)
S <- sensitivity(A)
cat("Sensitivity matrix:\n"); print(round(S, 4))

# Elasticity matrix (proportional sensitivity)
E <- elasticity(A)
cat("Elasticity matrix:\n"); print(round(E, 4))

# Sum of elasticities = 1 (verify)
cat(sprintf("Sum of elasticities = %.4f (should be 1.0)\n", sum(E)))
```

---

## Interpreting Sensitivity and Elasticity

| Metric | Formula | Interpretation | Management use |
|--------|---------|----------------|---------------|
| Sensitivity | ∂λ/∂aᵢⱼ | Absolute change in λ per unit change in aᵢⱼ | Identifies demographically critical transitions |
| Elasticity | (aᵢⱼ/λ) × ∂λ/∂aᵢⱼ | Proportional change in λ per proportional change in aᵢⱼ | Comparable across transitions; sums to 1 |

**Key elasticity patterns by life history:**

| Life history guild | Highest elasticity usually on |
|-------------------|------------------------------|
| Short-lived, high fecundity | Fecundity (F) and juvenile survival |
| Long-lived, low fecundity | Adult survival (Sa) — protect adults |
| Intermediate (most mammals) | Subadult/juvenile survival and adult survival roughly equal |

**Rule:** If adult survival elasticity > 0.5 → any intervention reducing adult mortality has higher λ return than fecundity enhancement.

---

## Uncertainty in Vital Rates: Sensitivity Range vs Point Estimate

When fewer than 3 years of data are available:

```r
# Range of λ across vital rate uncertainty
F_range  <- c(0.6, 1.2)   # fecundity range
Sa_range <- c(0.75, 0.90)  # adult survival range

lambda_range <- expand.grid(F = F_range, Sa = Sa_range) %>%
  dplyr::rowwise() %>%
  dplyr::mutate(
    A_mat = list(matrix(c(0, 0, F, 0.3, 0.6, 0, 0, 0.7, Sa),
                        nrow = 3, byrow = TRUE)),
    lambda = lambda(A_mat)
  )
cat("Lambda range:", range(lambda_range$lambda), "\n")
```

**Report:** λ = [min, max] (vital rate uncertainty), not a single point estimate.

---

## Pitfalls

- **Stage matrix built from different populations:** Vital rates from captive populations overestimate survival. Always use wild rates or correct for captivity effects.
- **Non-ergodic matrix:** If the matrix has disconnected life-history blocks (e.g., no pathway from stage 1 to stage 3), λ will be undefined or biologically meaningless. Check connectivity of stages.
- **Fertility confusion:** Fecundity in the first row should be the number of stage-1 individuals produced per individual per time step — not clutch size or litter size directly. Account for sex ratio and offspring survival to first census.
- **Time step mismatch:** If survival rates are annual but fecundity is seasonal, standardise all vital rates to the same time step before building the matrix.
- **λ ≈ 1 with wide CI:** A point estimate of λ = 1.01 with uncertainty range [0.92, 1.10] should NOT be reported as "stable population." Report the full range.

---

## References

- Caswell, H. (2001). *Matrix Population Models: Construction, Analysis, and Interpretation* (2nd ed.). Sinauer Associates.
- Morris, W.F. & Doak, D.F. (2002). *Quantitative Conservation Biology*. Sinauer Associates. ISBN: 978-0878935468
- Crouse, D.T., Crowder, L.B. & Caswell, H. (1987). A stage-based population model for loggerhead sea turtles. *Ecology*, 68(5), 1412–1423. DOI: 10.2307/1939225
