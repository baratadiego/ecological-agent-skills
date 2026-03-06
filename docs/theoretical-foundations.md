# Theoretical Foundations

Reference document justifying the methodological decisions embedded in the ecological-agent-skills library. Intended as a citable companion for the Methods section of publications that use this skill set.

---

## 1. Spatial Cross-Validation over Random Cross-Validation

**Problem**: Spatial autocorrelation inflates model performance metrics when training and test sets share spatially proximate records. Standard random k-fold CV assumes independence between folds — an assumption violated by virtually all georeferenced ecological data.

**Solution**: Spatial block cross-validation partitions data into spatially disjoint folds whose block size equals or exceeds the species' spatial autocorrelation (SAC) range. This forces the model to predict into genuinely novel geographic space, producing honest estimates of transferability.

**Primary reference**: Roberts, D.R., Bahn, V., Ciuti, S., et al. (2017). Cross-validation strategies for data with temporal, spatial, hierarchical, or phylogenetic structure. *Ecography*, 40(8), 913–929. doi:10.1111/ecog.02881

**Supporting reference**: Valavi, R., Elith, J., Lahoz-Monfort, J.J. & Guillera-Arroita, G. (2019). blockCV: an R package for generating spatially or environmentally separated folds for k-fold cross-validation of species distribution models. *Methods in Ecology and Evolution*, 10, 225–232. doi:10.1111/2041-210X.13107

**When random CV is still acceptable**: When occurrence data are spatially uniform (e.g., systematic grid surveys) and SAC range is negligible relative to study area extent. In practice, this is rare for opportunistic occurrence data.

**Repository implementation**: `skills/predictive-modeling-best-practices/scripts/spatial_cv.py` and `spatial_cv.R`; block size is set to the SAC range estimated via variogram or Moran's I.

---

## 2. Ensemble of Models over Single Best Algorithm

**Problem**: Model uncertainty — the variation in predictions among algorithms fitted to the same data — is the largest source of uncertainty in range projections, often exceeding climate scenario uncertainty.

**Solution**: Combining predictions from multiple algorithms (e.g., MaxEnt, BRT, Random Forest, GLM) reduces variance and produces more robust suitability surfaces. The ensemble can be weighted by performance (TSS or AUC) or use equal weights.

**Primary reference**: Araújo, M.B. & New, M. (2007). Ensemble forecasting of species distributions. *Trends in Ecology & Evolution*, 22(1), 42–47. doi:10.1016/j.tree.2006.09.010

**Supporting reference**: Thuiller, W., Lafourcade, B., Engler, R. & Araújo, M.B. (2009). BIOMOD — a platform for ensemble forecasting of species distributions. *Ecography*, 32, 369–373. doi:10.1111/j.1600-0587.2008.05742.x

**Weighting guidance**: TSS-weighted ensemble outperforms equal-weight when model performance varies substantially (TSS range > 0.15 among algorithms). Equal-weight is safer when all models perform similarly and sample size is small (n < 50 presences).

**Repository implementation**: `skills/species-distribution-modeling/SKILL.md` Step 7; ensemble weights are computed from spatial CV metrics stored in validation outputs.

---

## 3. Partial ROC over Full AUC

**Problem**: AUC integrates model performance across the entire ROC curve, including specificity regions that are ecologically irrelevant (very high commission rates no ecologist would accept). A model that performs poorly in the decision-relevant region can still achieve a high AUC.

**Solution**: Partial ROC restricts evaluation to the portion of the ROC curve where omission rate is below a specified tolerance (e.g., E = 0.05 or 0.10), matching real-world acceptable error thresholds.

**Primary reference**: Peterson, A.T., Papeş, M. & Soberón, J. (2008). Rethinking receiver operating characteristic analysis applications in ecological niche modeling. *Ecological Modelling*, 213(1), 63–72. doi:10.1016/j.ecolmodel.2007.11.008

**Supporting reference**: Cobos, M.E., Peterson, A.T., Barve, N. & Osorio-Olvera, L. (2019). kuenm: an R package for detailed development of ecological niche models using Maxent. *PeerJ*, 7, e6281. doi:10.7717/peerj.6281

**How to calculate**: Implemented via `ntbox::pROC()`, `enmSdmX::evalSDM()`, or `ENMeval::calc.pROC()`. Ratio of partial AUC (model) to partial AUC (random) yields the AUC ratio; values > 1.0 indicate better-than-random prediction within the tolerance region.

**Repository implementation**: `skills/model-validation-and-uncertainty/SKILL.md` validation metrics section.

---

## 4. Calibration Area (M) Delimitation

**Problem**: Background points sampled outside the species' accessible area (M) produce an artificially broad environmental niche estimate. The model learns to distinguish presence environments from environments the species has never encountered, inflating apparent discrimination.

**Solution**: M should reflect the area historically accessible to the species via dispersal. Common M approximations: minimum convex polygon of occurrences buffered by estimated dispersal distance, biogeographic regions overlapping with occurrences, or distance-based buffers calibrated by home range.

**Primary reference**: Barve, N., Barve, V., Jiménez-Valverde, A., et al. (2011). The crucial role of the accessible area in ecological niche modeling and species distribution modeling. *Ecological Modelling*, 222(11), 1810–1819. doi:10.1016/j.ecolmodel.2011.02.011

**Supporting reference**: Soberón, J. & Peterson, A.T. (2005). Interpretation of models of fundamental ecological niches and species' distributional areas. *Biodiversity Informatics*, 2, 1–10. doi:10.17161/bi.v2i0.4

**Repository implementation**: `skills/species-distribution-modeling/SKILL.md` Step 2 (study area delimitation); `skills/geoprocessing-for-ecology/resources/` provides spatial operation guides for M construction.

---

## 5. Bray-Curtis Dissimilarity for Community Data

**Problem**: Euclidean distance is sensitive to "double zeros" — species absent from both sites contribute to perceived similarity, which is ecologically meaningless (shared absences ≠ ecological similarity).

**Solution**: Bray-Curtis dissimilarity ignores joint absences, weighting only shared and unshared presences/abundances. It is the default metric for NMDS ordination and PERMANOVA in community ecology.

**Primary reference**: Faith, D.P., Minchin, P.R. & Belbin, L. (1987). Compositional dissimilarity as a robust measure of ecological distance. *Vegetatio*, 69, 57–68. doi:10.1007/BF00045575

**Supporting reference**: Legendre, P. & Legendre, L. (2012). *Numerical Ecology*, 3rd edn. Elsevier. Chapter 7.

**When to use Jaccard**: Presence/absence data where abundance is unreliable or unavailable.
**When to use Aitchison**: Compositional data (proportions summing to 1) after CLR transformation, common in microbiome and eDNA metabarcoding studies.

**Repository implementation**: `skills/community-ecology-ordination/SKILL.md`; distance matrix computation in `scripts/ordination.R`.

---

## 6. Effective Mesh Size (MESH) for Fragmentation

**Problem**: Simple fragmentation metrics such as Number of Patches (NP) or Total Class Area (CA) do not capture connectivity and are scale-dependent. A landscape with many small patches can have the same NP as one with a few large patches plus many tiny fragments.

**Solution**: MESH (Effective Mesh Size) is the probability that two randomly placed points in the landscape fall within the same patch, expressed in area units. It is interpretable (expected patch size experienced by a randomly placed organism) and scale-invariant under the cross-boundary connectivity (CBC) approach.

**Primary reference**: Jaeger, J.A.G. (2000). Landscape division, splitting index, and effective mesh size: new measures of landscape fragmentation. *Landscape Ecology*, 15(2), 115–130. doi:10.1023/A:1008129329289

**Repository implementation**: `skills/ecological-impact-assessment/scripts/fragmentation_analysis.R` and `.py`.

---

## 7. IIC/PC over MESH for Functional Connectivity

**Problem**: MESH is a structural metric — it measures fragmentation geometry but does not model species-specific dispersal capacity or movement between patches.

**Solution**: Integral Index of Connectivity (IIC) and Probability of Connectivity (PC) model the landscape as a graph where patches are nodes and links are weighted by inter-patch dispersal probability. PC additionally accounts for stepping-stone connectivity (indirect paths through intermediate patches).

**Primary reference**: Saura, S. & Pascual-Hortal, L. (2007). A new habitat availability index to integrate connectivity in landscape conservation planning: comparison with existing indices and application to a case study. *Landscape and Urban Planning*, 83(2–3), 91–103. doi:10.1016/j.landurbplan.2007.03.005

**Supporting reference**: Saura, S. & Torné, J. (2009). Conefor Sensinode 2.2: a software package for quantifying the importance of habitat patches for landscape connectivity. *Environmental Modelling & Software*, 24(1), 135–139. doi:10.1016/j.envsoft.2008.05.005

**Repository implementation**: `skills/landscape-connectivity/SKILL.md`; `scripts/connectivity_analysis.R` computes IIC, PC, and dPC for patch prioritization.

---

## 8. 10% Omission Rate (OR10) as MaxEnt Threshold

**Problem**: The minimum training presence threshold (OR0, 0% omission) assumes zero error in occurrence coordinates — unrealistic for museum and citizen-science data with typical georeferencing errors of 1–10 km.

**Solution**: OR10 (10th percentile training presence) tolerates 10% omission, accommodating coordinate imprecision and environmental marginality. It produces more ecologically realistic range maps than minimum training presence.

**Primary reference**: Phillips, S.J., Anderson, R.P. & Schapire, R.E. (2006). Maximum entropy modeling of species geographic distributions. *Ecological Modelling*, 190(3–4), 231–259. doi:10.1016/j.ecolmodel.2005.03.026

**Supporting reference**: Warren, D.L. & Seifert, S.N. (2011). Ecological niche modeling in Maxent: the importance of model complexity and the performance of model selection criteria. *Ecological Applications*, 21(2), 335–342. doi:10.1890/10-1171.1

**Repository implementation**: `skills/species-distribution-modeling/SKILL.md` threshold selection step; model outputs include OR10 and MTP thresholds for comparison.

---

## 9. Regularization Multiplier Calibration in MaxEnt

**Problem**: MaxEnt's default regularization multiplier (RM = 1.0) often produces overfitted models, especially for species with few occurrence records (n < 50). Overfitting manifests as artificially narrow predicted ranges that fail to transfer to novel environments.

**Solution**: Calibrate RM across a range (e.g., 0.5–4.0 in steps of 0.5) and select the value that minimizes AICc or optimizes the trade-off between omission rate and model complexity. This process is automated by ENMeval and kuenm.

**Primary reference**: Warren, D.L. & Seifert, S.N. (2011). Ecological niche modeling in Maxent: the importance of model complexity and the performance of model selection criteria. *Ecological Applications*, 21(2), 335–342. doi:10.1890/10-1171.1

**Supporting reference**: Muscarella, R., Galante, P.J., Soley-Guardia, M., et al. (2014). ENMeval: an R package for conducting spatially independent evaluations and estimating optimal model complexity for Maxent ecological niche models. *Methods in Ecology and Evolution*, 5, 1198–1205. doi:10.1111/2041-210X.12261

**Repository implementation**: `skills/species-distribution-modeling/resources/maxent-calibration-guide.md`; calibration script in `scripts/`.

---

## 10. Random Effects for Site in BACI Designs

**Problem**: In Before-After-Control-Impact (BACI) designs, repeated measurements at the same site are not independent. Ignoring this intra-site correlation (pseudoreplication) inflates Type I error rates and produces unreliable p-values for the BA×CI interaction.

**Solution**: Fit a mixed-effects model with `(1|site)` random intercept to absorb between-site variation. The fixed-effect BA×CI interaction then tests the true impact effect with correct degrees of freedom.

**Primary reference**: Underwood, A.J. (1994). On beyond BACI: sampling designs that might reliably detect environmental disturbances. *Ecological Applications*, 4(1), 3–15. doi:10.2307/1942110

**Supporting reference**: Schwarz, C.J. (2015). Analysis of BACI experiments. In *Course Notes for Beginning and Intermediate Statistics*. Available: http://www.stat.sfu.ca/~cschwarz/CourseNotes

**Repository implementation**: `skills/ecological-impact-assessment/scripts/baci_analysis.R`; model specification uses `lmer(response ~ period * treatment + (1|site))`.

---

## Recommended Citation

When using ecological-agent-skills in a publication, cite as:

```
[Your Name] (2026). ecological-agent-skills: A modular skill library for
quantitative ecology with AI agent integration. Version [X.Y.Z].
https://github.com/[user]/ecological-agent-skills
```

In the Methods section, reference specific methodological justifications:

> "Spatial cross-validation block size was set to exceed the species' SAC range following Roberts et al. (2017); model ensemble was TSS-weighted following Araújo & New (2007). Full methodological justifications are documented in the theoretical-foundations companion document (https://github.com/[user]/ecological-agent-skills/blob/main/docs/theoretical-foundations.md)."

---

## References (consolidated)

- Araújo, M.B. & New, M. (2007). *Trends in Ecology & Evolution*, 22, 42–47. doi:10.1016/j.tree.2006.09.010
- Barve, N. et al. (2011). *Ecological Modelling*, 222, 1810–1819. doi:10.1016/j.ecolmodel.2011.02.011
- Cobos, M.E. et al. (2019). *PeerJ*, 7, e6281. doi:10.7717/peerj.6281
- Faith, D.P. et al. (1987). *Vegetatio*, 69, 57–68. doi:10.1007/BF00045575
- Jaeger, J.A.G. (2000). *Landscape Ecology*, 15, 115–130. doi:10.1023/A:1008129329289
- Legendre, P. & Legendre, L. (2012). *Numerical Ecology*, 3rd edn. Elsevier.
- Muscarella, R. et al. (2014). *Methods in Ecology and Evolution*, 5, 1198–1205. doi:10.1111/2041-210X.12261
- Peterson, A.T. et al. (2008). *Ecological Modelling*, 213, 63–72. doi:10.1016/j.ecolmodel.2007.11.008
- Phillips, S.J. et al. (2006). *Ecological Modelling*, 190, 231–259. doi:10.1016/j.ecolmodel.2005.03.026
- Roberts, D.R. et al. (2017). *Ecography*, 40, 913–929. doi:10.1111/ecog.02881
- Saura, S. & Pascual-Hortal, L. (2007). *Landscape and Urban Planning*, 83, 91–103. doi:10.1016/j.landurbplan.2007.03.005
- Saura, S. & Torné, J. (2009). *Environmental Modelling & Software*, 24, 135–139. doi:10.1016/j.envsoft.2008.05.005
- Soberón, J. & Peterson, A.T. (2005). *Biodiversity Informatics*, 2, 1–10. doi:10.17161/bi.v2i0.4
- Thuiller, W. et al. (2009). *Ecography*, 32, 369–373. doi:10.1111/j.1600-0587.2008.05742.x
- Underwood, A.J. (1994). *Ecological Applications*, 4, 3–15. doi:10.2307/1942110
- Valavi, R. et al. (2019). *Methods in Ecology and Evolution*, 10, 225–232. doi:10.1111/2041-210X.13107
- Warren, D.L. & Seifert, S.N. (2011). *Ecological Applications*, 21, 335–342. doi:10.1890/10-1171.1
