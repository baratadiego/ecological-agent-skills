# Worked Example: Reef Fish Community — Indo-Pacific Coral Reefs

**Workflow:** analyze-community-structure
**System:** Reef fish assemblages, Indo-Pacific coral reefs (Great Barrier Reef to Coral Triangle)
**Sites:** 3,214 transects across 8 countries (Australia, Indonesia, Philippines, Papua New Guinea, Fiji, Solomon Islands, Malaysia, Timor-Leste)
**Survey:** Reef Life Survey — diver visual census, 50 m x 5 m belt transects, 2008--2023
**Matrix:** 3,214 transects x 987 species (abundance counts)

---

## Step 1 — Data Sources

| Item | Detail |
|------|--------|
| Database | Reef Life Survey (RLS), open-access |
| Citation | Edgar & Stuart-Smith 2014 (doi:10.1038/sdata.2014.7) |
| Raw scope | ~14,200 transects across 8 countries, all marine habitats |
| Geographic filter | Indo-Pacific coral reefs only (100--180 E, 0--30 S) |
| Temporal range | 2008--2023 |
| Post-filter | 3,847 transects, 1,126 species |
| Taxonomic scope | Actinopterygii (bony reef fishes) |

## Step 2 — QA and Filtering

| Filter | Criterion | Records removed | Remaining |
|--------|-----------|----------------|-----------|
| Survey method | Remove cryptic survey method (M2) | 214 transects | 3,633 |
| Depth | Remove transects > 30 m | 97 transects | 3,536 |
| Species poverty | Remove transects with < 5 species | 183 transects | 3,353 |
| Taxonomic standardization | Synonyms resolved via WoRMS | 139 names merged | 987 species |
| Outlier screening | Abundance values > 99.9th percentile winsorized | 41 records adjusted | 3,353 |
| Spatial thinning | Max 3 transects per site per year to reduce pseudoreplication | 139 transects | 3,214 |
| **Final matrix** | | | **3,214 transects x 987 species** |

Data transformation: square-root of abundance applied before ordination and dissimilarity calculations to down-weight numerically dominant schooling species.

---

## Alpha Diversity

### By Depth Zone

| Depth zone | n transects | Richness (S) | Shannon H' | Simpson 1-D |
|------------|------------|-------------|-----------|------------|
| Shallow (0--5 m) | 874 | 48.3 +/- 11.2 | 2.97 +/- 0.34 | 0.92 +/- 0.03 |
| Mid (5--15 m) | 1,487 | 61.7 +/- 13.8 | 3.28 +/- 0.29 | 0.95 +/- 0.02 |
| Deep (15--30 m) | 853 | 39.1 +/- 10.4 | 2.74 +/- 0.37 | 0.89 +/- 0.04 |

Kruskal-Wallis (richness ~ depth zone): H = 214.7, df = 2, p < 0.001
Post-hoc Dunn: all pairwise comparisons p_adj < 0.001
Mid-depth zone harbours peak richness, consistent with the mid-domain effect and maximum coral structural complexity at 5--15 m.

### By Latitude Band

| Latitude band | n transects | Richness (S) | Shannon H' | Simpson 1-D |
|---------------|------------|-------------|-----------|------------|
| 0--10 S (Coral Triangle core) | 1,241 | 68.4 +/- 14.1 | 3.42 +/- 0.27 | 0.96 +/- 0.01 |
| 10--20 S (central GBR, Melanesia) | 1,108 | 52.1 +/- 12.6 | 3.11 +/- 0.31 | 0.93 +/- 0.02 |
| 20--30 S (southern GBR, subtropical) | 865 | 34.7 +/- 9.8 | 2.68 +/- 0.35 | 0.88 +/- 0.03 |

Kruskal-Wallis (richness ~ latitude band): H = 387.2, df = 2, p < 0.001
Post-hoc Dunn: all pairwise comparisons p_adj < 0.001
Richness declines approximately 50% from the equatorial Coral Triangle to subtropical reefs, consistent with the marine latitudinal diversity gradient.

---

## Beta Diversity

### Bray-Curtis Dissimilarity

| Comparison | Mean dissimilarity +/- SD |
|-----------|--------------------------|
| Within shallow | 0.54 +/- 0.11 |
| Within mid | 0.48 +/- 0.09 |
| Within deep | 0.57 +/- 0.12 |
| Between shallow--mid | 0.63 +/- 0.10 |
| Between mid--deep | 0.66 +/- 0.11 |
| Between shallow--deep | 0.72 +/- 0.10 |
| Within 0--10 S | 0.46 +/- 0.10 |
| Within 10--20 S | 0.52 +/- 0.11 |
| Within 20--30 S | 0.58 +/- 0.13 |
| Between 0--10 S and 20--30 S | 0.78 +/- 0.08 |

### Turnover vs Nestedness Decomposition (betapart)

| Component | Sorensen-based | % of total |
|-----------|---------------|-----------|
| Total beta (beta.sor) | 0.71 | 100% |
| Turnover (beta.sim) | 0.51 | 71.8% |
| Nestedness-resultant (beta.sne) | 0.20 | 28.2% |

Turnover dominates total beta diversity (~72%), indicating that compositional change across depth zones and latitude bands reflects species replacement rather than progressive impoverishment of a nested subset.

---

## NMDS

- Distance: Bray-Curtis on square-root transformed abundances
- Dimensions: 2
- Random starts: 50
- **Stress = 0.14** (acceptable; < 0.20 threshold)
- Convergence reached after 50 iterations in best solution

Ordination reveals clear separation along NMDS1 by latitude band (Coral Triangle vs subtropical) and along NMDS2 by depth zone. Shallow and deep assemblages occupy distinct ordination space with mid-depth transects intermediate. Coral Triangle transects cluster tightly relative to the more dispersed subtropical group.

Environmental fitting (envfit, 999 permutations):

| Variable | r2 | p |
|---------|-----|------|
| Latitude | 0.68 | 0.001 |
| Depth (m) | 0.54 | 0.001 |
| Sea surface temperature | 0.51 | 0.001 |
| Live coral cover (%) | 0.47 | 0.001 |
| Structural complexity (rugosity) | 0.39 | 0.001 |
| Distance to shelf edge (km) | 0.22 | 0.003 |

---

## PERMANOVA

```
adonis2(bray_dist ~ depth_zone * region, data = env, permutations = 999)

                    Df  SumOfSqs     R2       F     Pr(>F)
depth_zone           2    48.71   0.182   112.4    0.001 ***
region               7    82.94   0.310    54.7    0.001 ***
depth_zone:region   14    16.05   0.060     5.3    0.001 ***
Residual          3190   119.82   0.448
Total             3213   267.52   1.000
```

Region explains the largest fraction of community variance (R2 = 0.31), followed by depth zone (R2 = 0.18). The significant interaction (R2 = 0.06) indicates that depth zonation patterns differ among regions -- for example, shallow assemblages in the Coral Triangle are compositionally distinct from shallow assemblages on the southern Great Barrier Reef.

---

## PERMDISP (Homogeneity of Multivariate Dispersions)

### By Depth Zone

```
betadisper(bray_dist, group = depth_zone)
F = 14.87, df1 = 2, df2 = 3211, p = 0.001
```

| Depth zone | Mean distance to centroid |
|------------|-------------------------|
| Shallow (0--5 m) | 0.442 +/- 0.061 |
| Mid (5--15 m) | 0.401 +/- 0.054 |
| Deep (15--30 m) | 0.459 +/- 0.068 |

### By Region

```
betadisper(bray_dist, group = region)
F = 9.31, df1 = 7, df2 = 3206, p = 0.001
```

**Note:** Significant heterogeneity of dispersions detected for both factors. Deep and shallow transects show greater multivariate dispersion than mid-depth transects, and subtropical regions are more dispersed than Coral Triangle sites. The PERMANOVA result therefore reflects a combination of centroid shifts and dispersion differences. Both effects are ecologically interpretable: greater dispersion in deep and subtropical assemblages reflects higher environmental heterogeneity in those settings.

---

## SIMPER — Top Contributors to Between-Depth-Zone Differences

### Shallow vs Deep

| Species | Contribution (%) | Mean abund shallow | Mean abund deep | Functional group |
|---------|------------------|--------------------|-----------------|-----------------|
| *Pomacentrus moluccensis* | 3.7 | 12.4 | 1.2 | Planktivore, coral-associated |
| *Chromis viridis* | 3.4 | 18.7 | 2.1 | Schooling planktivore |
| *Pseudanthias squamipinnis* | 2.9 | 0.8 | 9.6 | Schooling planktivore, deep reef |
| *Acanthurus lineatus* | 2.6 | 7.3 | 0.4 | Territorial herbivore, reef crest |
| *Cephalopholis miniata* | 2.3 | 0.3 | 3.8 | Mesopredator, deep reef |

Shallow assemblages are characterised by coral-associated damselfishes and herbivores adapted to high-energy, light-saturated reef crests. Deep assemblages shift toward planktivorous anthiines and mesopredators associated with walls and overhangs.

### Coral Triangle vs Subtropical (20--30 S)

| Species | Contribution (%) | Mean abund Coral Triangle | Mean abund subtropical | Functional group |
|---------|------------------|--------------------------|----------------------|-----------------|
| *Chromis ternatensis* | 2.8 | 8.9 | 0.1 | Schooling planktivore |
| *Halichoeres melanurus* | 2.5 | 5.4 | 0.3 | Invertivore wrasse |
| *Chaetodon trifascialis* | 2.2 | 3.7 | 0.0 | Obligate corallivore |
| *Abudefduf vaigiensis* | 1.9 | 1.2 | 6.1 | Generalist omnivore |
| *Notolabrus gymnogenis* | 1.7 | 0.0 | 4.3 | Temperate-affinity wrasse |

---

## Ecological Interpretation

1. **Latitudinal diversity gradient.** Richness declines approximately 50% from equatorial Coral Triangle reefs to subtropical reefs at 20--30 S. This gradient is consistent with the marine species-area relationship, higher sea surface temperatures supporting greater metabolic scope, and the Coral Triangle functioning as both an evolutionary centre of origin and an overlap zone for Indian and Pacific Ocean faunas.

2. **Depth zonation driven by environmental filtering.** The three depth zones harbour distinct assemblages structured by light attenuation, wave energy, and coral morphological transitions. Branching *Acropora*-dominated shallows support a different functional guild than plating and massive coral communities at depth. The significant depth x region interaction indicates these vertical zonation patterns are not uniform across the Indo-Pacific.

3. **Turnover dominates beta diversity.** The high turnover component (~72%) indicates that communities at different depths and latitudes are not nested subsets of one another but rather comprise distinct species pools shaped by environmental filtering. This contrasts with a simple impoverishment model and implies that conservation of Indo-Pacific reef fish diversity requires protecting reefs across the full depth and latitudinal gradient.

4. **Dispersion patterns are ecologically informative.** Greater multivariate dispersion in deep and subtropical assemblages reflects higher among-site environmental heterogeneity (variable reef geomorphology at depth; mixing of tropical and temperate faunas at subtropical margins). Conservation planning should account for this higher beta diversity in marginal reef environments.

5. **Functional turnover.** SIMPER results show that depth-zone differences are driven by shifts in functional groups (coral-associated planktivores replaced by deep-reef mesopredators), not simply by abundance fluctuations within the same guild. This reinforces the hypothesis that environmental filtering acts on functional traits.

---

## Data Sources and References

| Reference | DOI |
|-----------|-----|
| Edgar, G.J. & Stuart-Smith, R.D. (2014). Systematic global assessment of reef fish communities by the Reef Life Survey program. *Scientific Data*, 1, 140007. | doi:10.1038/sdata.2014.7 |
| Bellwood, D.R., Hughes, T.P., Connolly, S.R. & Tanner, J. (2005). Environmental and geometric constraints on Indo-Pacific coral reef biodiversity. *Ecology Letters*, 8, 643--651. | doi:10.1111/j.1461-0248.2005.00820.x |
| Baselga, A. (2010). Partitioning the turnover and nestedness components of beta diversity. *Global Ecology and Biogeography*, 19, 134--143. | doi:10.1111/j.1466-8238.2009.00490.x |
| Roberts, C.M. et al. (2002). Marine biodiversity hotspots and conservation priorities for tropical reefs. *Science*, 295, 1280--1284. | doi:10.1126/science.1067728 |
| Anderson, M.J. (2001). A new method for non-parametric multivariate analysis of variance. *Austral Ecology*, 26, 32--46. | doi:10.1111/j.1442-9993.2001.01070.pp.x |
| Clarke, K.R. (1993). Non-parametric multivariate analyses of changes in community structure. *Australian Journal of Ecology*, 18, 117--143. | doi:10.1111/j.1442-9993.1993.tb00438.x |

### R Packages Used

| Package | Purpose |
|---------|---------|
| `vegan` | NMDS, PERMANOVA (adonis2), SIMPER, envfit, betadisper |
| `betapart` | Turnover--nestedness decomposition |
| `worrms` | Taxonomic standardization via WoRMS API |
| `dplyr`, `tidyr` | Data wrangling and filtering |
| `ggplot2` | Ordination and diversity visualizations |
