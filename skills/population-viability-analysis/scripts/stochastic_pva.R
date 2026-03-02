# Usage: Rscript stochastic_pva.R <vital_rates_csv> <output_dir>
#        [n_init] [t_max] [n_sim] [quasi_ext]
#
# Stochastic PVA via Monte Carlo simulation. Vital rates are drawn each year
# from Beta distributions (survival/stasis) or Lognormal distributions
# (fecundity), parameterised from observed inter-annual variation.
#
# Outputs:
#   stochastic_pva_results.csv    — P(quasi-extinction), MTE, λ_s per threshold
#   extinction_curve.csv          — P(ext) vs time
#   trajectory_plot.png           — 200 stochastic trajectories + median
#   extinction_curve.png          — Cumulative extinction probability over time
#   iucn_criterion_e.csv          — IUCN Criterion E classification

suppressPackageStartupMessages(library(popbio))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
  cat("Usage: Rscript stochastic_pva.R <vital_rates_csv> <output_dir>",
      "[n_init] [t_max] [n_sim] [quasi_ext]\n")
  quit(status = 1)
}

vr_path    <- args[1]
output_dir <- args[2]
n_init     <- if (length(args) >= 3) as.integer(args[3]) else NA_integer_
t_max      <- if (length(args) >= 4) as.integer(args[4]) else 100L
n_sim      <- if (length(args) >= 5) as.integer(args[5]) else 1000L
quasi_ext  <- if (length(args) >= 6) as.numeric(args[6]) else 50

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load vital rates ─────────────────────────────────────────────────────────
vr <- read.csv(vr_path)
mat_cols <- grep("^a_[0-9]+_[0-9]+$", names(vr), value = TRUE)
if (length(mat_cols) == 0) {
  stop("No matrix element columns (a_i_j) found in vital_rates_csv.")
}

indices <- regmatches(mat_cols, gregexpr("[0-9]+", mat_cols))
k       <- max(sapply(indices, function(x) max(as.integer(x))))

# Per-element mean and variance
vr_stats <- lapply(mat_cols, function(col) {
  x    <- vr[[col]][!is.na(vr[[col]])]
  mu   <- mean(x)
  sig2 <- var(x)
  list(col = col, mu = mu, sig2 = sig2)
})
names(vr_stats) <- mat_cols

# ── Beta distribution parameterisation (for survival/stasis: bounded [0,1]) ──
beta_params <- function(mu, sig2) {
  if (is.na(sig2) || sig2 <= 0 || mu <= 0 || mu >= 1) return(NULL)
  # Cap variance to stay in valid Beta range
  max_sig2 <- mu * (1 - mu) - 1e-6
  sig2_use  <- min(sig2, max_sig2 * 0.95)
  denom <- mu * (1 - mu) / sig2_use - 1
  list(shape1 = mu * denom, shape2 = (1 - mu) * denom)
}

# Lognormal parameterisation (for fecundity: unbounded > 0)
lnorm_params <- function(mu, sig2) {
  if (is.na(sig2) || sig2 <= 0 || mu <= 0) return(NULL)
  sigma2_ln <- log(1 + sig2 / mu^2)
  mu_ln     <- log(mu) - sigma2_ln / 2
  list(meanlog = mu_ln, sdlog = sqrt(sigma2_ln))
}

# ── Draw a random matrix ──────────────────────────────────────────────────────
draw_matrix <- function() {
  A <- matrix(0, k, k)
  for (vs in vr_stats) {
    idx <- as.integer(regmatches(vs$col, gregexpr("[0-9]+", vs$col))[[1]])
    i   <- idx[1]; j <- idx[2]
    # Fecundity row (row 1): lognormal; survival/stasis: beta
    if (i == 1 && vs$mu > 0) {
      params <- lnorm_params(vs$mu, vs$sig2)
      val    <- if (!is.null(params)) max(0, rlnorm(1, params$meanlog, params$sdlog))
                else vs$mu
    } else {
      params <- beta_params(vs$mu, vs$sig2)
      val    <- if (!is.null(params)) rbeta(1, params$shape1, params$shape2)
                else min(max(vs$mu, 0), 1)
    }
    A[i, j] <- val
  }
  A
}

# ── Initial population vector ─────────────────────────────────────────────────
A_mean <- matrix(0, k, k)
for (vs in vr_stats) {
  idx <- as.integer(regmatches(vs$col, gregexpr("[0-9]+", vs$col))[[1]])
  A_mean[idx[1], idx[2]] <- vs$mu
}
SS <- stable.stage(A_mean)

n0 <- if (!is.na(n_init)) n_init else {
  if ("population_N" %in% names(vr)) as.integer(tail(vr$population_N, 1))
  else 1000L
}

# ── Monte Carlo simulation ────────────────────────────────────────────────────
cat(sprintf("Running %d stochastic simulations (t_max = %d, Ne = %g, N₀ = %d)...\n",
            n_sim, t_max, quasi_ext, n0))

all_N     <- matrix(NA_real_, n_sim, t_max + 1)
ext_times <- rep(NA_integer_, n_sim)

for (s in seq_len(n_sim)) {
  n_vec      <- round(n0 * SS)
  N_total    <- numeric(t_max + 1)
  N_total[1] <- sum(n_vec)
  extinct    <- FALSE

  for (t in seq_len(t_max)) {
    if (!extinct) {
      A_t   <- draw_matrix()
      n_vec <- A_t %*% n_vec
      N_t   <- sum(n_vec)
      N_total[t + 1] <- N_t

      if (N_t <= quasi_ext) {
        extinct            <- TRUE
        ext_times[s]       <- t
        N_total[(t + 1):length(N_total)] <- 0
      }
    }
  }
  all_N[s, ] <- N_total
}

cat("Simulations complete.\n")

# ── Extinction probability over time ──────────────────────────────────────────
ext_curve <- numeric(t_max)
for (t in seq_len(t_max)) {
  ext_curve[t] <- mean(!is.na(ext_times) & ext_times <= t, na.rm = TRUE)
}

ext_df <- data.frame(time = seq_len(t_max), p_extinction = ext_curve)
write.csv(ext_df, file.path(output_dir, "extinction_curve.csv"), row.names = FALSE)

# ── IUCN thresholds ───────────────────────────────────────────────────────────
# IUCN Criterion E time horizons (generation time = t_max / 5 as approximation)
gen_time <- t_max / 5  # placeholder; adjust if generation time known

iucn_df <- data.frame(
  category    = c("CR", "EN", "VU"),
  threshold   = c(0.50, 0.20, 0.10),
  time_horizon = c(min(100, max(10, 3 * gen_time)),
                   min(100, max(20, 5 * gen_time)),
                   100)
)
iucn_df$p_extinction <- sapply(round(iucn_df$time_horizon), function(T) {
  t_use <- min(T, t_max)
  ext_curve[t_use]
})
iucn_df$qualifies <- iucn_df$p_extinction >= iucn_df$threshold
write.csv(iucn_df, file.path(output_dir, "iucn_criterion_e.csv"), row.names = FALSE)

# Overall risk category
risk_cat <- if (iucn_df$qualifies[iucn_df$category == "CR"]) "CR" else
            if (iucn_df$qualifies[iucn_df$category == "EN"]) "EN" else
            if (iucn_df$qualifies[iucn_df$category == "VU"]) "VU" else "LC/NT"

cat(sprintf("\nP(quasi-extinction ≤ %g at t = %d yr) = %.3f\n",
            quasi_ext, t_max, ext_curve[t_max]))
cat(sprintf("IUCN Criterion E category: %s\n", risk_cat))

# MTE
valid_ext <- ext_times[!is.na(ext_times)]
mte_mean  <- if (length(valid_ext) > 0) mean(valid_ext) else Inf
mte_ci    <- if (length(valid_ext) >= 10)
               quantile(valid_ext, c(0.025, 0.975)) else c(NA, NA)

# Stochastic growth rate (log λ_s)
log_Ns <- log(all_N[, ncol(all_N)])
log_Ns <- log_Ns[is.finite(log_Ns) & log_Ns > 0]
lambda_s <- if (length(log_Ns) > 0) exp(mean(log_Ns - log(n0)) / t_max) else NA

# Results summary
results_df <- data.frame(
  metric = c("n_simulations", "n_init", "quasi_ext_threshold", "t_max",
             "p_extinction", "mte_mean_yr", "mte_CI_2.5", "mte_CI_97.5",
             "lambda_s", "iucn_category"),
  value  = c(n_sim, n0, quasi_ext, t_max,
             round(ext_curve[t_max], 4),
             round(mte_mean, 1), round(mte_ci[1], 1), round(mte_ci[2], 1),
             round(lambda_s, 4), risk_cat)
)
write.csv(results_df, file.path(output_dir, "stochastic_pva_results.csv"),
          row.names = FALSE)
cat("Results written.\n")
print(results_df)

# ── Trajectory plot ───────────────────────────────────────────────────────────
# Sample 200 trajectories for plot
plot_idx <- sample(seq_len(n_sim), min(200, n_sim))
traj_df  <- data.frame(
  time = rep(0:t_max, length(plot_idx)),
  N    = as.vector(t(all_N[plot_idx, ])),
  sim  = rep(plot_idx, each = t_max + 1)
)

med_N <- apply(all_N, 2, median, na.rm = TRUE)
med_df <- data.frame(time = 0:t_max, N = med_N)

p_traj <- ggplot() +
  geom_line(data = traj_df,
            aes(x = time, y = N, group = sim),
            alpha = 0.08, colour = "#2166AC", linewidth = 0.4) +
  geom_line(data = med_df, aes(x = time, y = N),
            colour = "darkblue", linewidth = 1.5) +
  geom_hline(yintercept = quasi_ext, linetype = "dashed", colour = "red") +
  scale_y_continuous(labels = scales::comma, limits = c(0, NA)) +
  labs(x = "Time (years)", y = "Population size (N)",
       title = sprintf("Stochastic PVA (%d simulations, N₀ = %d, Ne = %g)",
                       n_sim, n0, quasi_ext),
       subtitle = sprintf("P(extinction at t=%d) = %.3f | Category: %s",
                          t_max, ext_curve[t_max], risk_cat)) +
  theme_minimal(base_size = 11)

ggsave(file.path(output_dir, "trajectory_plot.png"), p_traj,
       width = 9, height = 5, dpi = 150)

# ── Extinction curve plot ─────────────────────────────────────────────────────
p_ext <- ggplot(ext_df, aes(x = time, y = p_extinction)) +
  geom_line(linewidth = 1.2, colour = "#D73027") +
  geom_hline(yintercept = c(0.10, 0.20, 0.50),
             linetype = "dashed", colour = c("goldenrod", "orange", "red")) +
  annotate("text", x = t_max * 0.02, y = c(0.52, 0.22, 0.12),
           label = c("CR ≥ 50%", "EN ≥ 20%", "VU ≥ 10%"),
           colour = c("red", "orange", "goldenrod"), hjust = 0, size = 3) +
  labs(x = "Time (years)", y = "Cumulative P(quasi-extinction)",
       title = sprintf("Extinction probability curve (Ne threshold = %g)", quasi_ext)) +
  coord_cartesian(ylim = c(0, 1)) +
  theme_minimal(base_size = 11)

ggsave(file.path(output_dir, "extinction_curve.png"), p_ext,
       width = 8, height = 5, dpi = 150)

cat("\nStochastic PVA complete.\n")
