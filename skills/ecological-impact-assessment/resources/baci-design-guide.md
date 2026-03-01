# BACI Design Requirements and Common Pitfalls

## Core Requirements

BACI (Before-After-Control-Impact) is the gold standard for ecological impact assessment.

### Minimum design:
- **Before:** ≥ 1 sampling period before the disturbance
- **After:** ≥ 1 sampling period after the disturbance
- **Control:** ≥ 1 site not affected by the disturbance, similar to impact site
- **Impact:** ≥ 1 site affected by the disturbance

### Recommended design (for inference):
- Multiple control sites (≥ 3 preferred)
- Multiple impact sites (≥ 3 preferred)
- ≥ 3 time points before and after
- Sites monitored for the same duration before and after

## Statistical Model

```
indicator ~ period * treatment + (1 | site)
```

- `period`: factor with levels `before` / `after`
- `treatment`: factor with levels `control` / `impact`
- `period:treatment`: **the BACI interaction — the effect of interest**
- `(1 | site)`: random intercept for repeated measures at sites

The BACI effect = difference in before-after change between impact and control sites.

## Assumptions

1. **Parallel trends:** Control and impact sites had similar trajectories *before* the disturbance. **Test this** by checking the significance of `time × treatment` interaction in the pre-disturbance period only.
2. **No spillover:** The disturbance does not affect control sites (e.g., no upstream pollution affecting downstream controls).
3. **Independence among sites** (partially relaxed by random effects).

## Common Pitfalls

| Pitfall | Consequence | Fix |
|---------|------------|-----|
| Only one control site | Cannot distinguish site effect from treatment effect | Use ≥ 3 control sites |
| No pre-disturbance data | Cannot implement BACI; only Before-After | Document limitation explicitly |
| Control site affected by disturbance | BACI estimate biased toward zero | Verify spatial separation |
| Very short pre-disturbance baseline | Parallel trend assumption unverifiable | Report as limitation |
| Pseudoreplication (subsamples as sites) | Inflated degrees of freedom, false significance | Use random effects or aggregate |
| No random effects for repeated sites | Underestimated standard errors | Always include `(1|site)` |

## Effect Size Reporting

For the BACI interaction (β_BACI):

- **Linear scale (Gaussian):** Report β, 95% CI, and Cohen's d
- **Log scale (Poisson/lognormal):** Back-transform: exp(β) = multiplicative factor
- **Example:** β_BACI = -0.48 on log scale → impact sites had exp(−0.48) = 0.62× the abundance of control sites after disturbance, i.e. a 38% reduction
