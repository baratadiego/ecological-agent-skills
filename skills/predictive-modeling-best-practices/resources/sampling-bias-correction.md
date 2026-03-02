# Sampling Bias Correction Guide

Detecting and correcting geographic sampling bias in occurrence records before SDM fitting.

---

## 1. Why Sampling Bias Distorts SDMs

Occurrence data from aggregated databases (GBIF, VertNet, iNaturalist) rarely represent
true species distributions. They reflect **where people search**, not where species occur.

### Sources of geographic bias

| Bias source | Mechanism | Effect on SDM |
|---|---|---|
| **Road/trail proximity** | Collectors follow accessible paths | Roadsides over-represented in environmental space |
| **Urban proximity** | Amateur naturalists concentrate near cities | Urban bioclimates over-represented |
| **Research institutions** | Field stations generate intense local records | Hyper-local clusters in training data |
| **National boundaries** | Data sharing policies differ by country | Abrupt density gradients at borders |
| **Language barriers** | Non-English-speaking regions under-sampled in GBIF | Geographic gaps unrelated to species ecology |

### Consequence for model fitting

When occurrence records are biased toward roadsides, MaxEnt or BRT will learn that
road-adjacent environments predict presence. Background points sampled randomly will
under-represent those environments. The model will incorrectly associate road proximity
with habitat suitability.

**Key reference:** Phillips et al. 2009. Sample selection bias and presence-only distribution models.
*Ecological Applications* 19: 181–197. DOI: [10.1890/07-2153.1](https://doi.org/10.1890/07-2153.1)

---

## 2. Detecting Sampling Bias

### Spatial thinning (standard — already in `ecological-data-foundation`)

Remove records closer than a specified distance to reduce spatial clustering:

```r
suppressPackageStartupMessages(library(spThin))
thinned <- thin(loc.data = occ_df,
                lat.col = "decimalLatitude",
                long.col = "decimalLongitude",
                spec.col = "species",
                thin.par = 10,        # minimum distance in km
                reps = 10,
                locs.thinned.list.return = TRUE,
                write.files = FALSE)
```

### Kernel density bias map

Visualise sampling density to diagnose the pattern of bias:

```r
suppressPackageStartupMessages(library(MASS))
suppressPackageStartupMessages(library(terra))

# Estimate 2D kernel density of occurrences
kde <- kde2d(occ_df$decimalLongitude, occ_df$decimalLatitude,
             n = 200,
             lims = c(range(occ_df$decimalLongitude) + c(-2, 2),
                      range(occ_df$decimalLatitude)  + c(-2, 2)))

# Convert to SpatRaster
bias_rast <- rast(list(x = kde$x, y = kde$y, z = kde$z))
plot(bias_rast, main = "Sampling density kernel (darker = more sampled)")
```

### Environmental distribution comparison

Compare environmental space of occurrences vs. background to detect bias:

```r
# Extract env values at occurrence and background points
occ_env <- extract(env_stack, occ_pts)
bg_env  <- extract(env_stack, bg_pts)

# Kolmogorov-Smirnov test per variable
for (v in names(env_stack)) {
  ks_result <- ks.test(occ_env[[v]], bg_env[[v]])
  cat(v, ": D =", round(ks_result$statistic, 3),
      "p =", round(ks_result$p.value, 4), "\n")
}
# Significant D (p < 0.05) suggests occurrence records do NOT represent
# the available environmental space — evidence of sampling bias
```

---

## 3. Correction Methods

### Method 1 — Target-Group Background

**Concept:** Use occurrence records of all species from the same taxonomic group (e.g.,
all mammals, all birds) as the background. This approximates the sampling effort:
if a site was visited (evidenced by other species records), it should appear in the background.

**When to use:**
- When sampling effort tracks detectability (organised surveys, citizen science platforms)
- When a large pool of co-occurring taxonomic relatives exists in GBIF

**Limitations:**
- Assumes all species in the group have similar detectability
- Fails if the focal species was specifically targeted (e.g., camera trap targeted at jaguars)

```r
suppressPackageStartupMessages(library(rgbif))

# Download all mammal records in the study region as target-group background
tg_bg <- occ_search(
  orderKey = 732,           # Carnivora taxon key
  hasCoordinate = TRUE,
  occurrenceStatus = "PRESENT",
  country = "BR",
  limit = 50000
)$data

# Remove focal species from background
tg_bg <- tg_bg[tg_bg$species != "Panthera onca", ]

bg_pts <- tg_bg[, c("decimalLongitude", "decimalLatitude")]
bg_pts <- na.omit(bg_pts)
```

**Report in ODMAP field O4:** "Background sampled from target-group (Carnivora) GBIF records (n = X) to account for collector bias."

---

### Method 2 — Kernel Density Weighting

**Concept:** Weight background points inversely proportional to sampling density.
Areas that are densely sampled get low weight; areas rarely visited get high weight.

**Formula:**

```
weight(bg_i) = 1 / KDE(bg_i)
```

where KDE is the kernel density estimate of occurrence records at the background point location.

```r
suppressPackageStartupMessages(library(MASS))
suppressPackageStartupMessages(library(terra))

# Compute KDE of occurrence points
kde <- kde2d(occ_df$decimalLongitude, occ_df$decimalLatitude,
             n = 200,
             lims = c(range(occ_df$decimalLongitude) + c(-5, 5),
                      range(occ_df$decimalLatitude)  + c(-5, 5)))

# Interpolate KDE values at background point locations
bias_rast <- rast(list(x = kde$x, y = kde$y, z = kde$z))
bg_density <- extract(bias_rast, bg_pts)[[1]]

# Invert density to get weights (add small constant to avoid division by zero)
bg_weights <- 1 / (bg_density + 1e-6)
bg_weights  <- bg_weights / sum(bg_weights, na.rm = TRUE)

# Pass bg_weights to maxnet or ENMeval via:
# ENMevaluate(..., bg = bg_pts, bg.grp = NULL)
# maxnet::maxnet(p, data, bg.weights = bg_weights)
```

---

### Method 3 — Environmental Filtering (thin in environmental space)

**Concept:** Instead of geographic thinning (by distance), thin occurrence records in
environmental space to reduce over-representation of common bioclimates.

**When to use:**
- When geographic thinning removes records in distinct habitats that happen to be close
- When most records cluster in one bioclimatic region

```r
suppressPackageStartupMessages(library(terra))

# Extract env values at occurrences
occ_env <- extract(env_stack, occ_pts, ID = FALSE)

# Create a raster in environmental space (first two PCA axes)
pca_res <- prcomp(na.omit(occ_env), scale. = TRUE)
occ_pca <- predict(pca_res, occ_env)[, 1:2]

# Grid sampling in environmental space (keep 1 record per cell)
env_grid_size <- 0.5  # in PC1/PC2 units — adjust based on variance explained

occ_pca_df <- as.data.frame(occ_pca)
occ_pca_df$cell_id <- paste(
  floor(occ_pca_df$PC1 / env_grid_size),
  floor(occ_pca_df$PC2 / env_grid_size)
)

# Keep one record per environmental cell (random)
set.seed(42)
occ_thinned_idx <- occ_pca_df %>%
  dplyr::group_by(cell_id) %>%
  dplyr::slice_sample(n = 1) %>%
  dplyr::pull(.I)

occ_thinned <- occ_df[occ_thinned_idx, ]
message("Environmental thinning: ", nrow(occ_df), " → ", nrow(occ_thinned), " records")
```

---

### Method 4 — Checkerboard / Spatial Partitioning

See `resources/spatial-cv-guide.md` for detailed implementation. Spatial partitioning
(checkerboard or block CV) does not correct bias but ensures that validation data are
geographically independent from training data, making model evaluation more realistic
under spatially biased training.

---

## 4. Decision Table — Which Method to Use

| Type of bias | Data available | Recommended method |
|---|---|---|
| Road/city proximity, known from KDE | Target-group records in GBIF | Target-group background |
| General sampling density gradient | Any | Kernel density weighting |
| Bioclimatic clustering (few env types over-sampled) | Environmental predictors | Environmental filtering |
| All of the above | Any | Combine: KDE weighting + environmental filtering |
| Bias unknown but suspicious | Any | Spatial thinning (1 record per grid cell) as minimum |

---

## 5. Reporting in ODMAP (Field O4)

ODMAP field **O4 (Biases and sampling artefacts)** must state:
1. Which bias was detected and how (KDE, KS test, visual inspection)
2. Which correction method was applied
3. Key parameters (target group taxon, KDE bandwidth, grid cell size)

**Example ODMAP O4 text:**
> "Sampling bias was detected by comparing the environmental distribution of occurrence
> records vs. random background (KS test, p < 0.001 for bio1 and bio12). Bias was
> corrected using target-group background (all Mammalia records from GBIF within the
> study area, n = 12,450), excluding the focal species."

---

## 6. Common Pitfalls

- **Spatial thinning alone is not bias correction:** it reduces spatial clustering but
  does not address the underlying pattern of collector effort.
- **KDE bandwidth selection is subjective:** use cross-validated bandwidth (`MASS::bandwidth.nrd`
  or `ks::hpi`) rather than default.
- **Target-group background can introduce new bias:** if all Carnivora records are
  also biased toward roads, the background will still be biased. Always visualise.
- **Environmental filtering removes rare habitats:** if a unique habitat is represented
  by only a few records, environmental filtering will preferentially discard it. Check
  that important biomes are still represented after filtering.

---

## 7. References

| Citation | DOI |
|---|---|
| Phillips et al. 2009. Ecol. Apps. 19:181–197 | [10.1890/07-2153.1](https://doi.org/10.1890/07-2153.1) |
| Fourcade et al. 2014. PLoS ONE 9:e97122 | [10.1371/journal.pone.0097122](https://doi.org/10.1371/journal.pone.0097122) |
| Kramer-Schadt et al. 2013. Ecography 36:1044 | [10.1111/j.1600-0587.2013.00159.x](https://doi.org/10.1111/j.1600-0587.2013.00159.x) |
| Warton & Shepherd 2010. Ann. Appl. Stat. | [10.1214/10-AOAS331](https://doi.org/10.1214/10-AOAS331) |
