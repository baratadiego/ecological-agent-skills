# Activity Patterns Reference

## Diel Activity and the Overlap Index Δ

Diel activity is the distribution of an animal's activity across the 24-hour cycle. It is typically estimated from camera trap timestamps as circular data (time in radians).

**Conversion:** `time_rad <- hour(datetime) * (2 * pi / 24)`

---

## Overlap Index Δ (Delta)

The overlap index Δ measures the proportion of shared activity time between two activity distributions. Range: 0 (no overlap) to 1 (complete overlap).

| Estimator | Formula | When to use |
|---|---|---|
| Dhat1 | Area under min(f1, f2) | Small samples (n < 50), conservative |
| Dhat4 | Weighted mean of Dhat1 and Dhat5 | **Recommended default** for n > 50 |
| Dhat5 | Area method with bandwidth adjustment | Large samples (n > 100) |

**Rule:** Use **Dhat4** as the default unless n < 50 per group, in which case use Dhat1.

```r
suppressPackageStartupMessages(library(overlap))

# Convert timestamps to radians
records_sp <- records[records$Species == "Panthera_pardus", ]
time_rad <- (hour(records_sp$DateTimeOriginal) +
             minute(records_sp$DateTimeOriginal) / 60) * (2 * pi / 24)

# Bootstrap CI for Dhat4
bootstrap_result <- bootEst(
  A     = time_rad_groupA,
  B     = time_rad_groupB,
  nb    = 1000,
  type  = "Dhat4"
)
cat("Dhat4:", bootstrap_result["Dhat4"],
    "95% CI:", bootstrap_result["lower0.025"], "-", bootstrap_result["upper0.975"])
```

---

## Interpretation Table

| Δ value | Interpretation |
|---|---|
| 0.00–0.25 | Minimal temporal overlap — strong temporal partitioning |
| 0.26–0.50 | Low overlap — partial temporal separation |
| 0.51–0.75 | Moderate overlap — temporal niche sharing |
| 0.76–1.00 | High overlap — largely similar activity timing |

---

## Circular Statistics

For mean activity time and activity concentration:

```r
suppressPackageStartupMessages(library(circular))

time_circ <- circular(time_rad, units = "radians", template = "clock24")

# Mean activity time
mean_time <- mean.circular(time_circ)
cat("Mean activity hour:", mean_time * 24 / (2 * pi))

# Rayleigh test: H0 = uniform distribution (no preferred activity time)
rayleigh_test <- rayleigh.test(time_circ)
cat("Rayleigh p-value:", rayleigh_test$p.value)

# Concentration parameter κ (Watson's)
kappa_est <- mle.vonmises(time_circ)$kappa
# κ = 0: uniform; κ > 2: concentrated; κ > 5: strongly nocturnal/diurnal
```

---

## Seasonal Stratification

Tropical regions: define seasons by rainfall (≥ 100 mm/month = wet season).
Temperate regions: calendar seasons (DJF, MAM, JJA, SON).

```r
records$season <- ifelse(month(records$DateTimeOriginal) %in% c(11,12,1,2,3),
                         "dry", "wet")

# Compute separate Δ for dry and wet seasons
for (s in c("dry", "wet")) {
  subset_data <- records[records$season == s & records$Species == "target_sp", ]
  time_subset <- (hour(subset_data$DateTimeOriginal) +
                  minute(subset_data$DateTimeOriginal)/60) * (2*pi/24)
  cat("Season:", s, " n =", length(time_subset), "\n")
}
```

---

## Minimum Sample Sizes for Reliable Δ Estimation

| n per group | Reliability of Dhat4 |
|---|---|
| < 10 | Do not report Δ; report RAI and activity histogram only |
| 10–50 | Use Dhat1; bootstrap CI will be wide |
| 50–100 | Dhat4 acceptable; moderate CI width |
| > 100 | Dhat4 reliable; narrow CI |

---

## References

- Ridout, M.S. & Linkie, M. (2009). Estimating overlap of daily activity patterns from camera trap data. *Journal of Agricultural, Biological, and Environmental Statistics*, 14(3), 322–337. DOI: 10.1198/jabes.2009.08038
- Meredith, M. & Ridout, M. (2021). overlap: Estimates of coefficient of overlapping for animal activity patterns. R package. https://CRAN.R-project.org/package=overlap
