# Worked Example: Bird Community Structure Across Land Uses

**Workflow:** analyze-community-structure  
**System:** Birds, Atlantic Forest  
**Sites:** 90 sites across 3 land use types (30 each)  
**Species matrix:** 90 sites × 127 species (point counts, 5 min, 25m radius)

---

## Alpha Diversity

| Land use | S (richness) | H' (Shannon) | 1−D (Simpson) |
|----------|-------------|-------------|--------------|
| Old-growth forest | 42.3 ± 4.1 | 3.41 ± 0.18 | 0.96 ± 0.01 |
| Secondary forest | 28.7 ± 5.2 | 2.89 ± 0.24 | 0.92 ± 0.02 |
| Pasture | 14.2 ± 3.8 | 2.01 ± 0.31 | 0.81 ± 0.04 |

Kruskal-Wallis (richness): H = 47.3, p < 0.001  
Post-hoc Dunn: all pairs significantly different (p_adj < 0.01)

## NMDS

- Stress = 0.13 (acceptable)
- 20 random starts; converged solution confirmed

## PERMANOVA

```
adonis2(bray_dist ~ land_use, permutations = 999)

         Df  SumOfSqs    R2      F    Pr(>F)
land_use  2   4.218   0.421  29.1   0.001 ***
Residual 87   6.299   0.579
Total    89  10.517   1.000
```

## PERMDISP (Homogeneity of Dispersions)

```
F = 3.42, p = 0.038 (significant)
```

**Note:** Significant dispersion differences detected. PERMANOVA result reflects both centroid differences AND variation in dispersion. Old-growth forest sites are more homogeneous (lower dispersion) than pasture sites. Both centroid and dispersion effects are ecologically meaningful.

## Top SIMPER Species (Old-growth vs Pasture)

| Species | Contribution (%) | Mean abund OG | Mean abund Pasture |
|---------|----------------|--------------|-------------------|
| Thamnophilus caerulescens | 4.2 | 3.1 | 0.1 |
| Dysithamnus mentalis | 3.8 | 2.8 | 0.0 |
| Myrmotherula axillaris | 3.5 | 2.6 | 0.0 |
| Volatinia jacarina | 3.1 | 0.2 | 4.7 |
| Sporophila caerulescens | 2.9 | 0.1 | 3.8 |

## Beta Diversity Partitioning

| Component | Total beta |
|-----------|-----------|
| Bray-Curtis total | 0.623 |
| Turnover | 0.481 (77.2%) |
| Nestedness | 0.142 (22.8%) |

**Interpretation:** Community differences are dominated by species turnover (replacement), not nestedness. This suggests true compositional differentiation between habitats rather than simple species loss.
