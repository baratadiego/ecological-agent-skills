# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript run_prioritization.R <pu_raster> <features_dir> <output_dir>
#        [targets] [locked_in_raster] [locked_out_raster] [blm] [budget]
#
# Runs systematic conservation prioritization using prioritizr (minimum-set
# or maximum-coverage ILP problem solved with HiGHS solver).
#
# Arguments:
#   pu_raster         — Planning unit cost raster (.tif); NA = excluded
#   features_dir      — Directory of feature rasters (.tif, one per species/habitat)
#   output_dir        — Directory for output files
#   targets           — Single value (applied to all features) or path to CSV
#                       with columns feature_name, target (default: 0.30)
#   locked_in_raster  — Binary raster, 1 = must select (default: none)
#   locked_out_raster — Binary raster, 1 = must exclude (default: none)
#   blm               — Boundary length modifier (default: 0)
#   budget            — For maximum coverage problem; if provided, switches
#                       objective to max-features (default: NA = min-set)
#
# Outputs:
#   solution.tif               — Binary raster: 1 = selected PU
#   feature_representation.csv — Amount of each feature in solution
#   cost_summary.csv           — Total cost and number of PUs selected
#   irreplaceability.tif       — Rarity-weighted importance of each PU
#   prioritization_map.png     — Visual output

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "spatial-prioritization"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages(library(prioritizr))
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(dplyr))
suppressPackageStartupMessages(library(ggplot2))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  cat("Usage: Rscript run_prioritization.R <pu_raster> <features_dir>",
      "<output_dir> [targets] [locked_in] [locked_out] [blm] [budget]\n")
  quit(status = 1)
}

pu_path       <- args[1]
features_dir  <- args[2]
output_dir    <- args[3]
targets_arg   <- if (length(args) >= 4 && args[4] != "NA") args[4] else "0.30"
locked_in_p   <- if (length(args) >= 5 && args[5] != "NA") args[5] else NULL
locked_out_p  <- if (length(args) >= 6 && args[6] != "NA") args[6] else NULL
blm           <- if (length(args) >= 7) as.numeric(args[7]) else 0
budget        <- if (length(args) >= 8 && args[8] != "NA") as.numeric(args[8]) else NA_real_

# ── Input precondition checks ─────────────────────────────────────────────────
if (!file.exists(pu_path)) {
  log_error("Input nao encontrado: %s\nCausa provavel: passo anterior nao concluiu.\nVerifique: outputs do skill anterior.\nSkill anterior: species-distribution-modeling", pu_path)
  stop("Missing input: ", pu_path)
}
if (!dir.exists(features_dir)) {
  log_error("Diretorio de features nao encontrado: %s\nCausa provavel: passo anterior nao concluiu ou caminho incorreto.\nVerifique: outputs do skill anterior.\nSkill anterior: species-distribution-modeling", features_dir)
  stop("Missing features directory: ", features_dir)
}

log_decision("targets_arg", targets_arg, "Conservation targets: single proportion for all features or path to per-feature CSV")
log_decision("blm", blm, "Boundary length modifier: 0 = no compactness penalty; increase to promote spatially compact solutions")
log_decision("budget", ifelse(is.na(budget), "NA (min-set)", budget), "Budget for max-coverage objective; NA triggers minimum-set formulation")
log_decision("locked_in_p", ifelse(is.null(locked_in_p), "none", locked_in_p), "Locked-in raster: PUs that must always be selected (e.g., existing protected areas)")
log_decision("locked_out_p", ifelse(is.null(locked_out_p), "none", locked_out_p), "Locked-out raster: PUs that must never be selected (e.g., urban areas)")

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# ── Load planning units ───────────────────────────────────────────────────────
log_step(1, "Load planning unit raster")
tryCatch({
  pu <- rast(pu_path)
  log_info("Planning units: %d x %d cells, CRS: %s",
           nrow(pu), ncol(pu), crs(pu, describe = TRUE)$name)

  n_pu_total <- sum(!is.na(values(pu)))
  log_info("Valid planning units: %d", n_pu_total)

  if (n_pu_total < 10) {
    log_warn("Numero muito baixo de unidades de planejamento validas (%d). Verifique a mascara de NA no raster pu.", n_pu_total)
  }
}, error = function(e) {
  log_error("Falha em load_planning_units: %s\nCausa provavel: raster corrompido, caminho incorreto ou CRS ausente.\nVerifique: arquivo pu_raster e sua integridade.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Load features ─────────────────────────────────────────────────────────────
log_step(2, "Load feature rasters")
tryCatch({
  feat_files <- list.files(features_dir, pattern = "\\.tif$",
                            full.names = TRUE, ignore.case = TRUE)
  if (length(feat_files) == 0) {
    log_error("Nenhum arquivo .tif encontrado em: %s\nCausa provavel: features nao geradas ou caminho incorreto.\nVerifique: conteudo do diretorio features_dir.\nSkill anterior: species-distribution-modeling", features_dir)
    stop("No .tif feature files found in: ", features_dir)
  }
  log_info("Loading %d feature layers...", length(feat_files))

  features <- rast(feat_files)
  # Ensure same extent/resolution as planning units
  features <- resample(features, pu, method = "bilinear")
  names(features) <- tools::file_path_sans_ext(basename(feat_files))

  # Check for zero-sum features
  feat_sums <- global(features, "sum", na.rm = TRUE)[[1]]
  zero_feats <- names(features)[feat_sums == 0]
  if (length(zero_feats) > 0) {
    log_warn("%d features com soma zero excluidas (nenhuma ocorrencia na area de estudo): %s",
             length(zero_feats), paste(zero_feats, collapse = ", "))
    features <- features[[!names(features) %in% zero_feats]]
  }
  n_feats <- nlyr(features)
  log_info("Features loaded: %d (after removing zero-sum)", n_feats)

  if (n_feats == 0) {
    log_error("Nenhuma feature valida apos remocao de zero-sum.\nCausa provavel: features nao sobrepõem a area de planejamento.\nVerifique: extensao e CRS dos rasters de features vs pu_raster.\nSkill anterior: species-distribution-modeling")
    stop("No valid features remaining after zero-sum removal.")
  }
}, error = function(e) {
  log_error("Falha em load_features: %s\nCausa provavel: rasters corrompidos, incompativeis ou diretorio vazio.\nVerifique: arquivos .tif em features_dir e compatibilidade com pu_raster.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Set targets ────────────────────────────────────────────────────────────────
log_step(3, "Set conservation targets")
tryCatch({
  if (file.exists(targets_arg)) {
    target_df <- read.csv(targets_arg)
    targets_vec <- target_df$target[match(names(features), target_df$feature_name)]
    na_targets  <- is.na(targets_vec)
    targets_vec[na_targets] <- 0.30  # default for unmatched features
    if (any(na_targets)) {
      log_warn("Alvo nao encontrado para %d features; usando padrao 0.30: %s",
               sum(na_targets), paste(names(features)[na_targets], collapse = ", "))
    }
    log_decision("targets_vec", "from_csv", paste0("Per-feature targets loaded from ", targets_arg))
  } else {
    targets_vec <- rep(as.numeric(targets_arg), n_feats)
    log_decision("targets_vec", targets_arg, "Uniform proportion target applied to all features")
  }
  log_info("Targets: min=%.2f, mean=%.2f, max=%.2f",
           min(targets_vec), mean(targets_vec), max(targets_vec))

  if (any(targets_vec > 0.90)) {
    log_warn("%d features com alvo > 90%%. Alvos muito altos podem tornar o problema inviavel.", sum(targets_vec > 0.90))
  }
}, error = function(e) {
  log_error("Falha em set_targets: %s\nCausa provavel: CSV de alvos malformado ou proporcao invalida fora de [0,1].\nVerifique: formato do arquivo de alvos e nomes das features.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Build problem ─────────────────────────────────────────────────────────────
log_step(4, "Build prioritizr problem")
tryCatch({
  if (is.na(budget)) {
    # Minimum set problem
    p <- problem(pu, features) %>%
      add_min_set_objective() %>%
      add_relative_targets(targets_vec)
    log_info("Objective: minimum cost (min-set)")
    log_decision("objective", "min_set", "No budget specified; minimize cost while meeting all targets")
  } else {
    # Maximum coverage problem
    p <- problem(pu, features) %>%
      add_max_features_objective(budget = budget) %>%
      add_absolute_targets(1e-6)  # minimum feasibility constraint
    log_info("Objective: maximum coverage (budget = %g)", budget)
    log_decision("objective", "max_features", paste0("Budget ", budget, " specified; maximize feature coverage within budget"))
  }

  p <- p %>%
    add_binary_decisions()

  # Locked-in
  if (!is.null(locked_in_p)) {
    li <- rast(locked_in_p)
    li <- resample(li, pu, method = "near")
    p  <- p %>% add_locked_in_constraints(li)
    n_li <- sum(values(li) == 1, na.rm = TRUE)
    log_info("Locked-in: %d PUs", n_li)
    if (n_li == 0) {
      log_warn("Raster locked-in fornecido mas nenhuma PU com valor 1 encontrada.")
    }
  }

  # Locked-out
  if (!is.null(locked_out_p)) {
    lo <- rast(locked_out_p)
    lo <- resample(lo, pu, method = "near")
    p  <- p %>% add_locked_out_constraints(lo)
    n_lo <- sum(values(lo) == 1, na.rm = TRUE)
    log_info("Locked-out: %d PUs", n_lo)
    if (n_lo == 0) {
      log_warn("Raster locked-out fornecido mas nenhuma PU com valor 1 encontrada.")
    }
  }

  # Boundary penalty
  if (blm > 0) {
    p <- p %>% add_boundary_penalties(penalty = blm, data = NULL)
    log_info("Boundary length modifier applied: %g", blm)
  }

  # Solver (HiGHS preferred)
  p <- p %>%
    add_highs_solver(gap = 0.01, time_limit = 600, verbose = TRUE)

  log_info("Problem built successfully.")
}, error = function(e) {
  log_error("Falha em build_problem: %s\nCausa provavel: incompatibilidade entre rasters, alvos invalidos ou pacote prioritizr desatualizado.\nVerifique: versoes de prioritizr e terra, e compatibilidade espacial dos rasters.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Solve ─────────────────────────────────────────────────────────────────────
log_step(5, "Solve prioritization problem with HiGHS solver")
log_info("Solving...")
tryCatch({
  s <- tryCatch(
    solve(p),
    error = function(e) {
      log_warn("HiGHS falhou: %s. Tentando fallback para lpsymphony...", conditionMessage(e))
      p2 <- p %>% add_lpsymphony_solver(gap = 0.05, time_limit = 600)
      solve(p2)
    }
  )
  log_info("Solver completed successfully.")
}, error = function(e) {
  log_error("Falha em solve_problem: %s\nCausa provavel: problema inviavel (alvos inalcancaveis), solver nao instalado, ou timeout.\nVerifique: alvos vs disponibilidade de features, e instalacao do HiGHS/lpsymphony.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Write solution raster ─────────────────────────────────────────────────────
log_step(6, "Write solution raster and compute selection summary")
tryCatch({
  sol_path <- file.path(output_dir, "solution.tif")
  writeRaster(s, sol_path, overwrite = TRUE)
  n_selected <- sum(values(s) == 1, na.rm = TRUE)
  log_info("Solution: %d PUs selected (%.1f%% of valid PUs)",
           n_selected, n_selected / n_pu_total * 100)

  if (n_selected == 0) {
    log_warn("Nenhuma PU selecionada na solucao. Verifique viabilidade do problema e restricoes locked-out.")
  }
  if (n_selected / n_pu_total > 0.80) {
    log_warn("Mais de 80%% das PUs selecionadas (%.1f%%). Alvos podem ser muito altos ou area de estudo muito restrita.", n_selected / n_pu_total * 100)
  }
}, error = function(e) {
  log_error("Falha em write_solution: %s\nCausa provavel: permissoes de escrita ou solucao invalida.\nVerifique: output_dir e resultado do solver.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Feature representation ────────────────────────────────────────────────────
log_step(7, "Evaluate feature representation in solution")
tryCatch({
  rep_df <- eval_feature_representation_summary(p, s)
  rep_df$target <- targets_vec
  rep_df$target_met <- rep_df$relative_held >= targets_vec

  write.csv(rep_df, file.path(output_dir, "feature_representation.csv"),
            row.names = FALSE)
  n_targets_met <- sum(rep_df$target_met, na.rm = TRUE)
  log_info("Targets met: %d / %d features", n_targets_met, n_feats)

  if (n_targets_met < n_feats) {
    log_warn("%d features nao atingiram seus alvos de representacao. Verifique viabilidade e restricoes.", n_feats - n_targets_met)
  }
}, error = function(e) {
  log_error("Falha em feature_representation: %s\nCausa provavel: incompatibilidade entre problema e solucao, ou falha na avaliacao.\nVerifique: objetos p e s e versao do prioritizr.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Cost summary ──────────────────────────────────────────────────────────────
log_step(8, "Compute and write cost summary")
tryCatch({
  cost_df <- data.frame(
    metric = c("total_cost", "n_pu_selected", "n_pu_total",
               "pct_pu_selected", "n_targets_met", "n_features"),
    value  = c(eval_cost_summary(p, s)$cost,
               n_selected, n_pu_total,
               n_selected / n_pu_total * 100,
               n_targets_met, n_feats)
  )
  write.csv(cost_df, file.path(output_dir, "cost_summary.csv"), row.names = FALSE)
  log_info("Cost summary:\n%s", paste(capture.output(print(cost_df)), collapse = "\n"))
}, error = function(e) {
  log_error("Falha em cost_summary: %s\nCausa provavel: falha na avaliacao de custo ou permissoes de escrita.\nVerifique: objetos p e s e output_dir.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Irreplaceability ──────────────────────────────────────────────────────────
log_step(9, "Compute irreplaceability (rarity-weighted richness)")
tryCatch({
  irr <- eval_rare_richness_importance(p, s)
  writeRaster(irr, file.path(output_dir, "irreplaceability.tif"), overwrite = TRUE)
  log_info("Irreplaceability map written.")
}, error = function(e) {
  log_error("Falha em irreplaceability: %s\nCausa provavel: falha na avaliacao de raridade ou permissoes de escrita.\nVerifique: objetos p e s e output_dir.\nSkill anterior: species-distribution-modeling", conditionMessage(e))
  stop(e)
})

# ── Map visualisation ─────────────────────────────────────────────────────────
log_step(10, "Generate prioritization map visualisation")
tryCatch({
  s_agg  <- aggregate(s, fact = max(1, floor(nrow(s) / 300)))
  df_sol <- as.data.frame(s_agg, xy = TRUE)
  names(df_sol)[3] <- "selected"
  df_sol$selected <- factor(df_sol$selected, levels = c(0, 1),
                             labels = c("Not selected", "Selected"))

  p_map <- ggplot(df_sol, aes(x = x, y = y, fill = selected)) +
    geom_raster() +
    scale_fill_manual(values = c("Not selected" = "grey90", "Selected" = "#2166AC"),
                      na.value = "white") +
    coord_equal() +
    labs(x = "Easting", y = "Northing", fill = "",
         title = sprintf("Conservation solution — %d PUs selected, %d/%d targets met",
                         n_selected, n_targets_met, n_feats)) +
    theme_minimal(base_size = 10)

  ggsave(file.path(output_dir, "prioritization_map.png"), p_map,
         width = 9, height = 7, dpi = 150)
  log_info("Prioritization map saved.")
}, error = function(e) {
  log_warn("Nao foi possivel gerar o mapa de priorizacao: %s. Continuando sem o grafico.", conditionMessage(e))
})

log_info("Prioritization complete.")
