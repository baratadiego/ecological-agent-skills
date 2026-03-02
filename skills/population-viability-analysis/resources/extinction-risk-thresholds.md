---
resource_id: extinction-risk-thresholds
skill_id: population-viability-analysis
---

# Extinction Risk Thresholds and IUCN Criterion E

## IUCN Red List Criterion E — Quantitative Analysis

Criterion E uses a PVA to assess extinction risk. All thresholds refer to the probability of extinction within a specified time horizon.

| IUCN Category | Extinction probability | Time horizon |
|---------------|----------------------|--------------|
| Critically Endangered (CR) | ≥ 50% | 10 years or 3 generations (whichever longer, max 100 years) |
| Endangered (EN) | ≥ 20% | 20 years or 5 generations (whichever longer, max 100 years) |
| Vulnerable (VU) | ≥ 10% | 100 years |

**Quasi-extinction threshold (Ne):** IUCN recommends Ne = 1 (true extinction). Many studies use Ne = 2 or Ne = 50 to capture functional extinction (loss of genetic diversity/reproductive capacity). **Document and justify your chosen Ne.**

---

## Minimum Viable Population (MVP) and 50/500 Rule

| Rule | Value | Purpose |
|------|-------|---------|
| Ne = 50 (short-term) | Effective population ≥ 50 | Avoid inbreeding depression over ~5 generations |
| Ne = 500 (long-term) | Effective population ≥ 500 | Maintain adaptive potential indefinitely |
| Ne/N ratio typical range | 0.1–0.5 | Convert effective to census size |

**Example:** If Ne/N = 0.2, then MVP (census) = 500 / 0.2 = 2,500 individuals.

**Caution:** The 50/500 rule is a heuristic. Modern genetic analyses suggest Ne > 1,000 for long-term viability of many taxa.

---

## Mean Time to Extinction (MTE) Interpretation

| MTE (years) | Conservation interpretation |
|-------------|---------------------------|
| < 20 | Immediate crisis; emergency management required |
| 20–100 | High risk; major population augmentation needed |
| 100–500 | Elevated risk; monitor and manage habitat |
| 500–1,000 | Moderate risk; status-quo management may suffice |
| > 1,000 | Low risk under current conditions |

**Note:** MTE is highly sensitive to initial population size and stochastic variation. Report confidence interval (2.5th–97.5th percentile across simulations), not just the mean.

---

## Stochastic vs Deterministic Threshold Comparison

| Condition | Recommendation |
|-----------|---------------|
| CV of vital rates < 0.10 | Deterministic model sufficient for λ estimation |
| CV of vital rates 0.10–0.30 | Stochastic PVA recommended |
| CV of vital rates > 0.30 | Stochastic PVA mandatory; deterministic results misleading |
| Catastrophic events possible | Include catastrophe module regardless of CV |

**CV calculation:**

```r
# Coefficient of variation for adult survival (example)
Sa_estimates <- c(0.82, 0.79, 0.88, 0.76, 0.85)  # across years
CV_Sa <- sd(Sa_estimates) / mean(Sa_estimates)
cat(sprintf("CV(Sa) = %.3f\n", CV_Sa))
```

---

## Demographic vs Environmental Stochasticity

| Type | Source | Effect on extinction risk | At large N |
|------|--------|--------------------------|-----------|
| Demographic stochasticity | Random individual fates (who dies, who reproduces) | Dominant at small N | Negligible |
| Environmental stochasticity | Year-to-year variation in vital rates | Scales with N | Remains important |
| Catastrophes | Rare events (disease, drought, fire) | Can override all other factors | Matters even at large N |

**Incorporating environmental stochasticity:**

```r
# Draw vital rates from Beta distribution each year
# Beta parameterization: mean = a/(a+b), variance ≈ mean*(1-mean)/(a+b+1)

beta_params <- function(mu, sigma2) {
  # sigma2: inter-annual variance
  a <- mu * ((mu * (1 - mu) / sigma2) - 1)
  b <- (1 - mu) * ((mu * (1 - mu) / sigma2) - 1)
  list(shape1 = a, shape2 = b)
}

# Example: adult survival mean = 0.82, variance = 0.01
bp <- beta_params(0.82, 0.01)
Sa_draw <- rbeta(1, bp$shape1, bp$shape2)
```

---

## Reporting Requirements for Criterion E Assessment

A PVA submitted for IUCN Criterion E must document:

1. **Model type:** deterministic/stochastic; software and version
2. **Vital rates:** source, sample size, years of data, CV
3. **Initial population size:** census N and Ne; Ne/N ratio assumed
4. **Quasi-extinction threshold (Ne):** value and justification
5. **Time horizon:** years; generation time used
6. **Uncertainty analysis:** sensitivity of P(ext) to ±20% vital rate changes
7. **Assumptions:** density dependence (yes/no), carrying capacity K
8. **Result:** P(extinction) ± bootstrapped 95% CI

---

## Pitfalls

- **Ignoring density dependence:** Populations near carrying capacity have density-dependent vital rate reductions that stabilise λ. Omitting this overestimates extinction risk.
- **Using mean vital rates for stochastic PVA:** Average rates remove the variance that drives extinction in stochastic models. Always use year-specific rates or CV estimates.
- **Confusing P(quasi-extinction) with P(true extinction):** If Ne = 50, you are estimating probability of declining below 50, not reaching 0.
- **Short time series inflating CV:** With only 2–3 years of vital rate data, sampling variance is large. Use informative Bayesian priors from related species.
- **Catastrophe specification without data:** Arbitrary catastrophe rates can dominate PVA results. Document the source of catastrophe frequency and severity parameters.

---

## References

- IUCN Standards and Petitions Committee (2022). *Guidelines for Using the IUCN Red List Categories and Criteria* (version 15.1). IUCN, Gland, Switzerland.
- Shaffer, M.L. (1981). Minimum population sizes for species conservation. *BioScience*, 31(2), 131–134. DOI: 10.2307/1308256
- Brook, B.W., Traill, L.W. & Bradshaw, C.J.A. (2006). Minimum viable population sizes and global extinction risk are unrelated. *Ecology Letters*, 9(4), 375–382. DOI: 10.1111/j.1461-0248.2006.00883.x
- Lande, R. (1993). Risks of population extinction from demographic and environmental stochasticity and random catastrophes. *American Naturalist*, 142(6), 911–927. DOI: 10.1086/285580
