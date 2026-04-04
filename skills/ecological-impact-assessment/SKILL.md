---
name: ecological-impact-assessment
description: "Quantifies ecological impacts using BACI designs, landscape fragmentation metrics, and pressure indices. Use this skill when the user mentions BACI analysis, before-after-control-impact, impact assessment, disturbance effects, land use change impacts, fragmentation metrics, landscape metrics, pressure or threat indices, intervention effectiveness, management outcome evaluation, or control-impact comparisons."
skill_version: 1.0.0
---

# Skill: ecological-impact-assessment

**Domain:** BACI · Before/After · Fragmentation · Pressure · Impact synthesis  
**Phase:** 2 — Modeling  
**Used by:** assess-ecological-impact, build-fire-risk-map, analyze-environmental-change

---

## Purpose

Guides the agent through the design and analysis of ecological impact assessments: BACI frameworks, before/after comparisons, landscape fragmentation analysis, anthropogenic pressure quantification, and synthesis of impact magnitude.

---

## When to Invoke

- Quantifying the effect of a disturbance, land-use change, or management intervention
- Designing a BACI study or interpreting BACI data
- Computing landscape fragmentation or connectivity metrics
- Building a composite pressure or threat index

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Ecological indicator time series (control and impact sites) | CSV | Yes |
| Disturbance event date(s) | Text / date | Yes |
| Land cover maps (pre/post) | GeoTIFF | Conditional |
| Pressure / threat layers | GeoTIFF, SHP | Optional |

---

## Outputs

| Output | Description |
|--------|-------------|
| `baci_results.csv` | BACI interaction term with CI and p-value |
| `fragmentation_metrics.csv` | Patch area, perimeter, connectivity indices |
| `pressure_index.tif` | Composite pressure map |
| `impact_synthesis.md` | Narrative summary of impact magnitude |
| `impact_plots/` | Before/after and control/impact comparison plots |

---

## Steps

### 1. Define the Impact Hypothesis
- Identify the disturbance and its expected effect (direction, magnitude, timing)
- Define the ecological indicator(s) to measure
- Define control sites (unaffected by disturbance, similar baseline conditions)

### 2. BACI Design Assessment
- Verify: measurements Before AND After disturbance, at Control AND Impact sites
- Compute the BACI interaction: (After−Before)_Impact − (After−Before)_Control
- If multiple control or impact sites: use mixed model with site as random effect

### 2.5 Test Parallel Trends Assumption (mandatory before Step 3)
The BACI estimator is only valid if Control and Impact groups had parallel trajectories before the disturbance. This assumption is testable and must be reported.

**How to test:**
- Subset data to **pre-disturbance period only**
- Fit: `indicator ~ time * treatment + (1|site)` using only Before data
- If the `time:treatment` interaction is **NOT significant** (p > 0.05): parallel trends assumption is supported — proceed
- If the `time:treatment` interaction **IS significant** (p ≤ 0.05): baseline trends differed

**If assumption is violated:**
- Do NOT proceed with standard BACI as if causal
- Report the pre-disturbance divergence explicitly in the report
- Discuss whether the baseline difference confounds the impact estimate
- Consider DiD (difference-in-differences) with covariate adjustment, or report as "observed difference" rather than causal impact

**Document in `decision_log.md`:** the test result (F, df, p-value) and the action taken.

### 3. Statistical Analysis
- Linear model: `indicator ~ period * treatment + (1|site)`
- The interaction term (`period:treatment`) is the BACI effect
- Report coefficient, 95% CI, and p-value for the interaction
- Effect size: Cohen's d or partial η²

### 4. Landscape Fragmentation (if applicable)
- Compute patch-level metrics: area, perimeter/area ratio, shape index
- Compute landscape-level metrics: largest patch index, edge density, COHESION, MESH
- Compare pre/post land cover using transition matrix
- Report habitat loss and fragmentation separately

### 5. Pressure Index (if applicable)
- Identify pressure layers: road density, agricultural intensity, human footprint, fire frequency
- Normalise each layer (0–1)
- Compute weighted sum (document weights and rationale)
- Classify pressure zones (low / moderate / high / critical)

### 6. Synthesis
- Combine BACI results, fragmentation metrics, and pressure index
- Classify overall impact as: none / minor / moderate / major / critical
- Describe spatial distribution of impact
- Identify most impacted areas and most important drivers

---

## Key Decisions to Document

- Control site selection criteria
- BACI model specification (fixed vs. random effects)
- Fragmentation metrics chosen and software version
- Pressure layer sources and weighting scheme
- Impact classification thresholds

---

## Tools and Libraries

**R:** `lme4`, `emmeans`, `landscapemetrics`, `lsm`, `ggplot2`  
**Python:** `pylandstats`, `statsmodels`, `rasterio`  
**CLI:** FRAGSTATS (landscape metrics)

---

## Resources

- `resources/baci-design-guide.md` — BACI design requirements and common pitfalls
- `resources/fragmentation-metrics-reference.md` — FRAGSTATS metric definitions
- `resources/pressure-index-template.md` — standard pressure layer sources
- `examples/impact/` — worked BACI and fragmentation example

---

## Notes

- BACI requires pre-disturbance data; post-hoc designs without pre-disturbance are not BACI
- Multiple control sites are strongly preferred; single control site severely limits inference
- Landscape metrics are scale-dependent; always report the spatial resolution used
