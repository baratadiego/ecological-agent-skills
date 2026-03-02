---
resource_id: sensitivity-elasticity-reference
skill_id: population-viability-analysis
---

# Sensitivity and Elasticity Analysis Reference

## Definitions

| Term | Symbol | Formula | Units |
|------|--------|---------|-------|
| Sensitivity | S_ij | ∂λ/∂a_ij | λ per matrix element unit |
| Elasticity | E_ij | (a_ij/λ) × ∂λ/∂a_ij | dimensionless proportion |
| Lower-level sensitivity | ∂λ/∂θ | chain rule via vital rates | λ per vital rate unit |
| LTRE contribution | c_ij | (ā_ij_treated - ā_ij_control) × s_ij | Change in λ per treatment |

---

## Life Table Response Experiment (LTRE)

LTRE partitions the observed difference in λ between two treatments (or populations) into contributions from each matrix element:

```r
suppressPackageStartupMessages(library(popbio))

# Two population matrices
A_control <- matrix(c(0, 0, 1.2, 0.25, 0.55, 0, 0, 0.60, 0.85),
                    nrow = 3, byrow = TRUE)
A_treat   <- matrix(c(0, 0, 0.9, 0.20, 0.50, 0, 0, 0.55, 0.80),
                    nrow = 3, byrow = TRUE)

lambda_c <- lambda(A_control)
lambda_t <- lambda(A_treat)
cat(sprintf("λ control = %.4f, λ treatment = %.4f, Δλ = %.4f\n",
            lambda_c, lambda_t, lambda_t - lambda_c))

# Midpoint matrix and its sensitivity
A_mid <- (A_control + A_treat) / 2
S_mid <- sensitivity(A_mid)

# LTRE contributions
LTRE_contrib <- (A_treat - A_control) * S_mid
cat("LTRE contributions:\n"); print(round(LTRE_contrib, 4))
cat(sprintf("Sum of contributions: %.4f (should ≈ Δλ = %.4f)\n",
            sum(LTRE_contrib), lambda_t - lambda_c))
```

---

## Prospective vs Retrospective Analysis

| Analysis type | Question answered | Method |
|---------------|------------------|--------|
| Prospective (sensitivity/elasticity) | Which vital rates, if changed, would most change λ? | Eigenvalue derivatives |
| Retrospective (LTRE) | Which vital rates actually caused observed λ differences? | Observed differences × sensitivities |

**Key distinction:** A vital rate may have high elasticity (prospective) but contribute little to observed population differences (retrospective) if it varies little among populations or years.

---

## Stochastic Sensitivity (Stochastic Elasticity)

When vital rates vary stochastically, use stochastic sensitivity (Tuljapurkar's approach):

```r
# Stochastic elasticity via simulation
compute_stoch_elasticity <- function(A_list, n_sim = 10000, delta = 0.001) {
  # A_list: list of annual matrices (environmental variation)
  # Returns element-wise stochastic elasticity

  log_lambda_s <- function(A_lst) {
    N <- 100
    n <- rep(1, nrow(A_lst[[1]]))
    for (t in seq_len(N)) {
      A_t <- A_lst[[sample(length(A_lst), 1)]]
      n   <- A_t %*% n
    }
    for (t in seq_len(n_sim)) {
      A_t <- A_lst[[sample(length(A_lst), 1)]]
      n   <- A_t %*% n
    }
    log(sum(n)) / n_sim
  }

  lls_base <- log_lambda_s(A_list)
  nr <- nrow(A_list[[1]])
  E_stoch <- matrix(0, nr, nr)

  for (i in seq_len(nr)) {
    for (j in seq_len(nr)) {
      A_perturbed <- lapply(A_list, function(A) {
        A_p <- A
        A_p[i, j] <- A_p[i, j] + delta
        A_p
      })
      lls_pert <- log_lambda_s(A_perturbed)
      E_stoch[i, j] <- (lls_pert - lls_base) / delta *
                        mean(sapply(A_list, function(A) A[i, j]))
    }
  }
  E_stoch
}
```

---

## Common Elasticity Patterns by Taxon

| Taxon group | Typical dominant elasticity | Implication |
|-------------|---------------------------|-------------|
| Annual plants | Seed survival, germination, seedling survival | Protect seedling stage |
| Long-lived trees | Adult survival (Sa >> 0.95) | Any adult mortality has high λ cost |
| Large mammals (elephant, rhino) | Adult female survival (e > 0.6) | Protect adult females absolutely |
| Sea turtles | Juvenile/subadult survival | Bycatch reduction critical |
| Songbirds | Adult survival + fecundity | Both vital rates important |
| Amphibians | Egg/larval survival | Breeding habitat quality critical |

---

## Management Implications of Elasticity

```r
E <- elasticity(A)

# Which life stage should managers prioritise?
stage_names <- c("Juvenile", "Subadult", "Adult")

# Column sums of E = elasticity of λ to survival/growth from each stage
col_sums <- colSums(E)
names(col_sums) <- stage_names
cat("Elasticity to transitions FROM each stage:\n")
print(round(col_sums, 4))

# Row sums = elasticity of λ to transitions INTO each stage
row_sums <- rowSums(E)
names(row_sums) <- stage_names
cat("Elasticity to transitions INTO each stage:\n")
print(round(row_sums, 4))

# Fecundity vs survival tradeoff
fec_el  <- sum(E[1, ])   # fecundity row
surv_el <- sum(E[-1, ])  # survival rows
cat(sprintf("Fecundity elasticity total: %.3f\n", fec_el))
cat(sprintf("Survival elasticity total: %.3f\n", surv_el))
```

---

## Uncertainty Propagation in Sensitivity Analysis

```r
# Bootstrap confidence intervals on elasticities
# Assumes you have multiple annual matrices
bootstrap_elasticity <- function(A_list, n_boot = 1000) {
  boot_E <- replicate(n_boot, {
    A_boot <- Reduce("+", sample(A_list, length(A_list), replace = TRUE)) /
              length(A_list)
    elasticity(A_boot)
  }, simplify = FALSE)
  # 95% CI for each element
  E_lower <- apply(simplify2array(boot_E), c(1, 2), quantile, 0.025)
  E_upper <- apply(simplify2array(boot_E), c(1, 2), quantile, 0.975)
  list(lower = E_lower, upper = E_upper)
}
```

---

## Pitfalls

- **Reporting sensitivities for fecundity and survival on same scale:** Fecundity is unbounded (can be 0, 1, 10, 100 offspring) while survival is bounded [0, 1]. Sensitivities are not directly comparable; always interpret elasticities (proportional) for cross-element comparison.
- **Interpreting elasticity as management priority without feasibility:** High elasticity on adult survival does not mean managers CAN improve adult survival. Always overlay feasibility (budget, methods, political will).
- **LTRE with non-additive contributions:** When A_control and A_treat differ by large amounts, the linear midpoint approximation breaks down. Use fixed LTRE or random LTRE designs for large differences.
- **Elasticity changes with environmental context:** Elasticities are properties of the matrix, which changes with environment. Report elasticities for the average matrix AND across observed range of environmental variation.

---

## References

- de Kroon, H., van Groenendael, J. & Ehrlén, J. (2000). Elasticities: a review of methods and model limitations. *Ecology*, 81(3), 607–618. DOI: 10.1890/0012-9658(2000)081[0607:EAROMA]2.0.CO;2
- Caswell, H. (2000). Prospective and retrospective perturbation analyses. *Ecology*, 81(3), 619–627. DOI: 10.1890/0012-9658(2000)081[0619:PARPA]2.0.CO;2
- Tuljapurkar, S., Horvitz, C.C. & Pascarella, J.B. (2003). The many growth rates and elasticities of populations in random environments. *American Naturalist*, 162(4), 489–502. DOI: 10.1086/378648
