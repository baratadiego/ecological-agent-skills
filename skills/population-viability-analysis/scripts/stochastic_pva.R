# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript stochastic_pva.R <vital_rates_csv> <output_dir>
#        [n_init] [t_max] [n_sim] [quasi_ext]
#
# Stochastic PVA via Monte Carlo simulation. Vital rates are drawn each year
# from Beta distributions (survival/stasis) or Lognormal distributions
# (fecundity), parameterised from observed inter-annual variation.
#
# Outputs:
#   stochastic_pva_results.csv    — P(quasi-extinction), MTE, lambda_s per threshold
#   extinction_curve.csv          — P(ext) vs time
#   trajectory_plot.png           — 200 stochastic trajectories + median
#   extinction_curve.png          — Cumulative extinction probability over time
#   iucn_criterion_e.csv          — IUCN Criterion E classification

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "population-viability-analysis"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

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

# ── Input precondition checks ─────────────────────────────────────────────────
if (!file.exists(vr_path)) {
  log_error("Input nao encontrado: %s\nCausa provavel: passo anterior nao concluiu.\nVerifique: outputs do skill anterior.\nSkill anterior: population-viability-analysis (matrix_pva)", vr_path)
  stop("Missing input: ", vr_path)
}

log_decision("t_max", t_max, "Time horizon in years for stochastic simulation")
log_decision("n_sim", n_sim, "Number of Monte Carlo simulation replicates")
log_decision("quasi_ext", quasi_ext, "Quasi-extinction threshold in individuals (IUCN Criterion E basis)")
log_decision("n_init", ifelse(is.na(n_init), "from_data", n_init), "Initial N; NA means read from vital_rates_csv last year or default 1000")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load vital rates ─────────────────────────────────────────────────────────
log_step(1, "Load vital rates CSV and detect matrix structure")
tryCatch({
  vr <- read.csv(vr_path)
  log_info("Loaded vital rates: %d rows, %d columns.", nrow(vr), ncol(vr))

  mat_cols <- grep("^a_[0-9]+_[0-9]+$", names(vr), value = TRUE)
  if (length(mat_cols) == 0) {
    log_error("Nenhuma coluna de elemento de matriz (a_i_j) encontrada no CSV.\nCausa provavel: formato errado do arquivo de taxas vitais.\nVerifique: nomes das colunas do CSV.\nSkill anterior: population-viability-analysis (matrix_pva)")
    stop("No matrix element columns (a_i_j) found in vital_rates_csv.")
  }

  if (nrow(vr) < 5) {
    log_warn("Serie temporal curta (%d anos). Estimativas de variancia podem ser imprecisas; n_sim alto recomendado.", nrow(vr))
  }

  indices <- regmatches(mat_cols, gregexpr("[0-9]+", mat_cols))
  k       <- max(sapply(indices, function(x) max(as.integer(x))))
  log_info("Matrix dimension detected: %d x %d", k, k)
  log_decision("k", k, "Matrix dimension inferred from max index in vital rate column names")
}, error = function(e) {
  log_error("Falha em load_vital_rates: %s\nCausa provavel: arquivo CSV malformado ou ausente.\nVerifique: caminho e formato do CSV de taxas vitais.\nSkill anterior: population-viability-analysis (matrix_pva)", conditionMessage(e))
  stop(e)
})

# Per-element mean and variance
log_step(2, "Compute per-element mean and variance for distribution parameterisation")
tryCatch({
  vr_stats <- lapply(mat_cols, function(col) {
    x    <- vr[[col]][!is.na(vr[[col]])]
    mu   <- mean(x)
    sig2 <- var(x)
    list(col = col, mu = mu, sig2 = sig2)
  })
  names(vr_stats) <- mat_cols
  log_info("Vital rate statistics computed for %d matrix elements.", length(vr_stats))
}, error = function(e) {
  log_error("Falha em compute_vr_stats: %s\nCausa provavel: colunas com todos os valores NA.\nVerifique: completude dos dados de taxas vitais.\nSkill anterior: population-viability-analysis (matrix_pva)", conditionMessage(e))
  stop(e)
})

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
log_step(3, "Compute mean matrix and stable stage distribution for initial vector")
tryCatch({
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
  log_decision("n0", n0, "Initial N; from CLI arg or last year in vital_rates_csv or default 1000")

  if (n0 <= quasi_ext) {
    log_warn("n0 (%d) <= quasi_ext (%g). A populacao comeca abaixo do limiar de quasi-extincao.", n0, quasi_ext)
  }
}, error = function(e) {
  log_error("Falha em compute_initial_vector: %s\nCausa provavel: matriz singular ou eigenvalores complexos na A_mean.\nVerifique: estrutura da matriz de transicao.\nSkill anterior: population-viability-analysis (matrix_pva)", conditionMessage(e))
  stop(e)
})

# ── Monte Carlo simulation ────────────────────────────────────────────────────
log_step(4, "Monte Carlo stochastic simulation")
log_info("Running %d stochastic simulations (t_max = %d, Ne = %g, N0 = %d)...",
         n_sim, t_max, quasi_ext, n0)

tryCatch({
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
  log_info("Simulations complete. Extinctions observed: %d / %d (%.1f%%)",
           sum(!is.na(ext_times)), n_sim, 100 * mean(!is.na(ext_times)))
}, error = function(e) {
  log_error("Falha em monte_carlo_simulation: %s\nCausa provavel: erro na amostragem de parametros ou overflow numerico.\nVerifique: parametros de distribuicao (mu, sig2) para cada elemento de matriz.\nSkill anterior: population-viability-analysis (matrix_pva)", conditionMessage(e))
  stop(e)
})

# ── Extinction probability over time ──────────────────────────────────────────
log_step(5, "Compute extinction probability curve over time")
tryCatch({
  ext_curve <- numeric(t_max)
  for (t in seq_len(t_max)) {
    ext_curve[t] <- mean(!is.na(ext_times) & ext_times <= t, na.rm = TRUE)
  }

  ext_df <- data.frame(time = seq_len(t_max), p_extinction = ext_curve)
  write.csv(ext_df, file.path(output_dir, "extinction_curve.csv"), row.names = FALSE)
  log_info("Extinction curve written. P(ext at t=%d) = %.4f", t_max, ext_curve[t_max])
}, error = function(e) {
  log_error("Falha em extinction_curve: %s\nCausa provavel: vetor ext_times malformado ou diretorio de saida inacessivel.\nVerifique: output_dir e resultados da simulacao.\nSkill anterior: population-viability-analysis (matrix_pva)", conditionMessage(e))
  stop(e)
})

# ── IUCN thresholds ───────────────────────────────────────────────────────────
log_step(6, "Classify IUCN Criterion E category")
tryCatch({
  # IUCN Criterion E time horizons (generation time = t_max / 5 as approximation)
  gen_time <- t_max / 5  # placeholder; adjust if generation time known
  log_decision("gen_time", gen_time, "Approximated as t_max/5; replace with known generation time if available")

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

  log_info("P(quasi-extinction <= %g at t = %d yr) = %.3f", quasi_ext, t_max, ext_curve[t_max])
  log_info("IUCN Criterion E category: %s", risk_cat)

  if (risk_cat %in% c("CR", "EN")) {
    log_warn("Categoria IUCN %s detectada. Considerar medidas urgentes de conservacao.", risk_cat)
  }
}, error = function(e) {
  log_error("Falha em iucn_classification: %s\nCausa provavel: curva de extincao vazia ou horizontes temporais invalidos.\nVerifique: resultados da simulacao e parametro t_max.\nSkill anterior: population-viability-analysis (matrix_pva)", conditionMessage(e))
  stop(e)
})

# ── Results summary ────────────────────────────────────────────────────────────
log_step(7, "Compute MTE, stochastic lambda_s, and write results summary")
tryCatch({
  # MTE
  valid_ext <- ext_times[!is.na(ext_times)]
  mte_mean  <- if (length(valid_ext) > 0) mean(valid_ext) else Inf
  mte_ci    <- if (length(valid_ext) >= 10)
                 quantile(valid_ext, c(0.025, 0.975)) else c(NA, NA)

  if (length(valid_ext) < 10) {
    log_warn("Menos de 10 extincoes observadas (%d). Intervalo de confianca do MTE nao calculado.", length(valid_ext))
  }

  # Stochastic growth rate (log lambda_s) — SURVIVOR-CONDITIONED
  log_Ns <- log(all_N[, ncol(all_N)])
  n_surviving <- sum(is.finite(log_Ns) & log_Ns > 0)
  n_total_sims <- nrow(all_N)
  log_Ns <- log_Ns[is.finite(log_Ns) & log_Ns > 0]
  lambda_s <- if (length(log_Ns) > 0) exp(mean(log_Ns - log(n0)) / t_max) else NA
  if (n_surviving < n_total_sims) {
    log_warn("lambda_s is conditioned on %d/%d surviving simulations (%.1f%% extinct). Estimate is biased upward.",
             n_surviving, n_total_sims, (1 - n_surviving / n_total_sims) * 100)
  }
  log_decision("lambda_s", ifelse(is.na(lambda_s), "NA", round(lambda_s, 4)),
               sprintf("Stochastic growth rate from %d/%d surviving simulations (survivor-conditioned)", n_surviving, n_total_sims))

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
  log_info("Results written.")
  log_info("Summary:\n%s", paste(capture.output(print(results_df)), collapse = "\n"))
}, error = function(e) {
  log_error("Falha em results_summary: %s\nCausa provavel: erro no calculo do MTE ou lambda_s.\nVerifique: resultados da simulacao all_N e ext_times.\nSkill anterior: population-viability-analysis (matrix_pva)", conditionMessage(e))
  stop(e)
})

# ── Trajectory plot ───────────────────────────────────────────────────────────
log_step(8, "Generate stochastic trajectory plot")
tryCatch({
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
         title = sprintf("Stochastic PVA (%d simulations, N0 = %d, Ne = %g)",
                         n_sim, n0, quasi_ext),
         subtitle = sprintf("P(extinction at t=%d) = %.3f | Category: %s",
                            t_max, ext_curve[t_max], risk_cat)) +
    theme_minimal(base_size = 11)

  ggsave(file.path(output_dir, "trajectory_plot.png"), p_traj,
         width = 9, height = 5, dpi = 150)
  log_info("Trajectory plot saved.")
}, error = function(e) {
  log_error("Falha em trajectory_plot: %s\nCausa provavel: erro no ggplot2 ou dados de trajetoria invalidos.\nVerifique: instalacao do ggplot2 e matriz all_N.\nSkill anterior: population-viability-analysis (matrix_pva)", conditionMessage(e))
  stop(e)
})

# ── Extinction curve plot ─────────────────────────────────────────────────────
log_step(9, "Generate extinction probability curve plot")
tryCatch({
  p_ext <- ggplot(ext_df, aes(x = time, y = p_extinction)) +
    geom_line(linewidth = 1.2, colour = "#D73027") +
    geom_hline(yintercept = c(0.10, 0.20, 0.50),
               linetype = "dashed", colour = c("goldenrod", "orange", "red")) +
    annotate("text", x = t_max * 0.02, y = c(0.52, 0.22, 0.12),
             label = c("CR >= 50%", "EN >= 20%", "VU >= 10%"),
             colour = c("red", "orange", "goldenrod"), hjust = 0, size = 3) +
    labs(x = "Time (years)", y = "Cumulative P(quasi-extinction)",
         title = sprintf("Extinction probability curve (Ne threshold = %g)", quasi_ext)) +
    coord_cartesian(ylim = c(0, 1)) +
    theme_minimal(base_size = 11)

  ggsave(file.path(output_dir, "extinction_curve.png"), p_ext,
         width = 8, height = 5, dpi = 150)
  log_info("Extinction curve plot saved.")
}, error = function(e) {
  log_error("Falha em extinction_curve_plot: %s\nCausa provavel: erro no ggplot2 ou dados da curva de extincao invalidos.\nVerifique: instalacao do ggplot2 e ext_df.\nSkill anterior: population-viability-analysis (matrix_pva)", conditionMessage(e))
  stop(e)
})

log_info("Stochastic PVA complete.")
