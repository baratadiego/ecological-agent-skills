# ecological-agent-skills / Copyright (C) 2026 Francisco Diego Barros Barata
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage: Rscript recovery_trajectory.R <timeseries.csv> <disturbance_date> <output_dir>
# Estimate post-disturbance vegetation recovery trajectory
# Usage: Rscript recovery_trajectory.R <timeseries_csv> <disturbance_date> <output_dir>
# Requires: dplyr, ggplot2, zoo, broom, lubridate

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "environmental-time-series"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(zoo)
  library(broom)
})

args             <- commandArgs(trailingOnly = TRUE)
ts_file          <- ifelse(length(args) >= 1, args[1], "tests/data/ndvi_monthly_series.csv")
disturbance_date <- ifelse(length(args) >= 2, args[2], "2010-01-01")
output_dir       <- ifelse(length(args) >= 3, args[3], "outputs/recovery")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_info("Skill: %s | ts_file=%s | disturbance_date=%s | output_dir=%s",
         SKILL_NAME, ts_file, disturbance_date, output_dir)

# ── Input precondition check ──────────────────────────────────────────────────
if (!file.exists(ts_file)) {
  log_error(
    "Input nao encontrado: %s\nCausa provavel: serie temporal nao gerada pelo passo anterior ou caminho incorreto.\nVerifique: execute primeiro o script de extracao de NDVI ou forneca o CSV correto.\nSkill anterior: geoprocessing-for-ecology ou remote-sensing-analysis.",
    ts_file
  )
  stop("Missing: ", ts_file)
}

# ── 1. Load and parse ──────────────────────────────────────────────────────────
log_step(1, "Carregar e parsear serie temporal")
dat <- tryCatch({
  read.csv(ts_file)
}, error = function(e) {
  log_error(
    "Falha ao ler CSV de serie temporal: %s\nCausa provavel: arquivo corrompido, encoding incorreto ou separador diferente de virgula.\nVerifique: abra o arquivo em editor de texto e confira o formato.\nSkill anterior: geoprocessing-for-ecology.",
    conditionMessage(e)
  )
  stop(e)
})

val_col  <- if ("value" %in% names(dat)) "value" else names(dat)[ncol(dat)]
date_col <- if ("date"  %in% names(dat)) "date"  else names(dat)[1]

log_decision("val_col",  val_col,  "coluna 'value' usada se presente, caso contrario ultima coluna numerica")
log_decision("date_col", date_col, "coluna 'date' usada se presente, caso contrario primeira coluna")

dat[[date_col]] <- tryCatch({
  as.Date(dat[[date_col]])
}, error = function(e) {
  log_error(
    "Falha ao converter coluna '%s' para Date: %s\nCausa provavel: formato de data nao reconhecido (esperado YYYY-MM-DD).\nVerifique: todos os valores da coluna de data devem seguir o formato ISO 8601.\nSkill anterior: geoprocessing-for-ecology.",
    date_col, conditionMessage(e)
  )
  stop(e)
})

dist_date <- tryCatch({
  as.Date(disturbance_date)
}, error = function(e) {
  log_error(
    "Falha ao parsear disturbance_date='%s': %s\nCausa provavel: formato invalido; use YYYY-MM-DD.\nVerifique: o segundo argumento do script.\nSkill anterior: nenhuma.",
    disturbance_date, conditionMessage(e)
  )
  stop(e)
})

n_na_val <- sum(is.na(dat[[val_col]]))
if (n_na_val > 0) {
  log_warn("Coluna '%s' contem %d valores NA — podem afetar calculo de baseline e minimo.", val_col, n_na_val)
}

log_info("Comprimento da serie: %d | Data de disturbio: %s", nrow(dat), format(dist_date))

# ── 2. Define periods ──────────────────────────────────────────────────────────
log_step(2, "Separar periodos pre e pos-disturbio")
pre  <- dat[dat[[date_col]] <  dist_date, ]
post <- dat[dat[[date_col]] >= dist_date, ]
log_info("Obs pre-disturbio: %d | Pos: %d", nrow(pre), nrow(post))
log_decision("period_split", format(dist_date),
             "divisao estrita: pre < disturbance_date, pos >= disturbance_date")

if (nrow(pre) < 12) {
  log_error(
    "Observacoes pre-disturbio insuficientes: %d (minimo 12 necessario).\nCausa provavel: a data de disturbio e muito proxima ao inicio da serie.\nVerifique: a data de disturbio e os dados disponiveis antes dela.\nSkill anterior: geoprocessing-for-ecology.",
    nrow(pre)
  )
  stop("Need at least 12 pre-disturbance observations for baseline.")
}

if (nrow(post) < 5) {
  log_warn("Apenas %d observacoes pos-disturbio — ajuste de curva pode ser instavel.", nrow(post))
}

# ── 3. Baseline statistics ─────────────────────────────────────────────────────
log_step(3, "Calcular estatisticas de baseline pre-disturbio (ultimos 24 meses)")
recent_pre    <- tail(pre, 24)
baseline_mean <- mean(recent_pre[[val_col]], na.rm = TRUE)
baseline_sd   <- sd(recent_pre[[val_col]],   na.rm = TRUE)
log_info("Baseline pre-disturbio: %.4f +/- %.4f (n=%d obs)", baseline_mean, baseline_sd, nrow(recent_pre))
log_decision("baseline_window", "24 observacoes mais recentes antes do disturbio",
             "janela de 2 anos captura condicoes imediatamente anteriores ao impacto")

if (nrow(recent_pre) < 24) {
  log_warn("Janela de baseline reduzida para %d obs (esperado 24) — serie pre-disturbio curta.", nrow(recent_pre))
}

# ── 4. Minimum post-disturbance value ─────────────────────────────────────────
log_step(4, "Identificar minimo pos-disturbio com suavizacao (janela 3)")
post_smooth <- tryCatch({
  rollapply(post[[val_col]], width = 3, FUN = mean, align = "center", fill = NA)
}, error = function(e) {
  log_error(
    "Falha na suavizacao rolante: %s\nCausa provavel: serie pos-disturbio muito curta para janela de 3 observacoes.\nVerifique: numero de observacoes pos-disturbio.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

min_val  <- min(post_smooth, na.rm = TRUE)
min_idx  <- which.min(post_smooth)
min_date <- post[[date_col]][min_idx]
log_info("Minimo pos-disturbio: %.4f em %s", min_val, format(min_date))
log_decision("smoothing_width", "3",
             "suavizacao com janela de 3 reduz ruido de sensor sem mascarar dinamica de recuperacao")

if (baseline_mean <= min_val) {
  log_warn("Minimo pos-disturbio (%.4f) nao e menor que a media baseline (%.4f) — possivel ausencia de disturbio detectavel.", min_val, baseline_mean)
}

# ── 5. Recovery Indicator (RI) ─────────────────────────────────────────────────
log_step(5, "Calcular Recovery Indicator (RI) e salvar serie")
# RI_t = (value_t - min_val) / (baseline_mean - min_val)
post$RI <- (post[[val_col]] - min_val) / (baseline_mean - min_val + 1e-10)

tryCatch({
  write.csv(post[, c(date_col, val_col, "RI")],
            file.path(output_dir, "recovery_indicator.csv"), row.names = FALSE)
  log_info("recovery_indicator.csv salvo em: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha ao salvar recovery_indicator.csv: %s\nCausa provavel: permissao negada ou disco cheio.\nVerifique: permissoes do diretorio de saida.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

log_decision("RI_formula", "RI = (value - min) / (baseline_mean - min + 1e-10)",
             "normalizacao 0->1 onde 0=minimo pos-disturbio e 1=baseline pre-disturbio; epsilon evita divisao por zero")

# ── 6. Fit recovery curves ─────────────────────────────────────────────────────
log_step(6, "Ajustar curvas de recuperacao (linear e exponencial)")
# t = months since minimum
post$t_months <- as.numeric(difftime(post[[date_col]], min_date, units = "days")) / 30.44
post_fit      <- post[post$t_months >= 0, ]

results_list <- list()

m_lin <- tryCatch({
  lm(RI ~ t_months, data = post_fit)
}, error = function(e) {
  log_error(
    "Falha ao ajustar modelo linear de recuperacao: %s\nCausa provavel: dados pos-disturbio insuficientes ou sem variacao em t_months.\nVerifique: numero de observacoes pos-disturbio apos o minimo.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

results_list$linear <- broom::glance(m_lin) |>
  mutate(model = "linear", formula = "RI ~ t")
log_info("Modelo linear ajustado: R2=%.4f", summary(m_lin)$r.squared)

# Exponential (log-linear)
post_fit_pos <- post_fit[post_fit$RI > 0.01, ]  # avoid log(0)
if (nrow(post_fit_pos) > 5) {
  tryCatch({
    m_exp <- lm(log(RI) ~ t_months, data = post_fit_pos)
    results_list$exponential <- broom::glance(m_exp) |>
      mutate(model = "exponential", formula = "log(RI) ~ t")
    log_info("Modelo exponencial ajustado: R2=%.4f", summary(m_exp)$r.squared)
  }, error = function(e) {
    log_warn("Falha ao ajustar modelo exponencial: %s — continuando apenas com modelo linear.", conditionMessage(e))
  })
} else {
  log_warn("Apenas %d obs com RI > 0.01 — modelo exponencial nao ajustado (minimo 5 necessario).", nrow(post_fit_pos))
}

# ── 7. Estimate time to 80% and 100% recovery ─────────────────────────────────
log_step(7, "Estimar tempo para 80%% e 100%% de recuperacao (modelo linear)")
slope     <- coef(m_lin)[["t_months"]]
intercept <- coef(m_lin)[["(Intercept)"]]
# RI = intercept + slope * t → t = (RI_target - intercept) / slope
t_80  <- if (slope > 0) round((0.80 - intercept) / slope, 1) else NA
t_100 <- if (slope > 0) round((1.00 - intercept) / slope, 1) else NA

log_info("Tempo estimado para 80%% de recuperacao: %s meses", ifelse(is.na(t_80), "NA (inclinacao negativa)", t_80))
log_info("Tempo estimado para 100%% de recuperacao: %s meses", ifelse(is.na(t_100), "NA (inclinacao negativa)", t_100))
log_decision("recovery_model", "linear",
             "modelo linear usado para projecao de tempo de recuperacao por simplicidade e interpretabilidade")

if (slope <= 0) {
  log_warn("Inclinacao linear negativa (%.6f) — sem recuperacao detectada no periodo pos-disturbio.", slope)
}

recovery_metrics <- data.frame(
  baseline_mean        = round(baseline_mean, 4),
  baseline_sd          = round(baseline_sd,   4),
  disturbance_date     = format(dist_date),
  post_minimum_value   = round(min_val, 4),
  post_minimum_date    = format(min_date),
  magnitude_of_decline = round((baseline_mean - min_val) / baseline_mean * 100, 2),
  RI_current           = round(tail(post$RI, 1), 4),
  slope_linear         = round(slope, 6),
  r2_linear            = round(summary(m_lin)$r.squared, 4),
  t_to_80pct_months    = t_80,
  t_to_100pct_months   = t_100
)

tryCatch({
  write.csv(recovery_metrics, file.path(output_dir, "recovery_metrics.csv"), row.names = FALSE)
  log_info("recovery_metrics.csv salvo em: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha ao salvar recovery_metrics.csv: %s\nCausa provavel: permissao negada ou disco cheio.\nVerifique: permissoes do diretorio de saida.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

# ── 8. Plot recovery trajectory ────────────────────────────────────────────────
log_step(8, "Gerar grafico de trajetoria de recuperacao")
tryCatch({
  pred_df <- data.frame(t_months = seq(0, max(post_fit$t_months, na.rm=TRUE), by=1))
  pred_df$RI_pred <- intercept + slope * pred_df$t_months

  p <- ggplot() +
    geom_hline(yintercept = 1.0, linetype = "dashed", colour = "forestgreen", alpha = 0.7) +
    geom_hline(yintercept = 0.8, linetype = "dashed", colour = "orange",      alpha = 0.7) +
    geom_line(data = post_fit, aes(x = t_months, y = RI), colour = "grey50", linewidth = 0.8) +
    geom_point(data = post_fit, aes(x = t_months, y = RI), size = 1.5, alpha = 0.7) +
    geom_line(data = pred_df, aes(x = t_months, y = RI_pred),
              colour = "#2166ac", linewidth = 1.1, linetype = "solid") +
    annotate("text", x = max(post_fit$t_months)*0.05, y = 1.02, label = "100% recovery",
             colour = "forestgreen", size = 3, hjust = 0) +
    annotate("text", x = max(post_fit$t_months)*0.05, y = 0.82, label = "80% recovery",
             colour = "orange", size = 3, hjust = 0) +
    labs(x = "Months since post-disturbance minimum",
         y = "Recovery Indicator (RI)",
         title = "Post-Disturbance Recovery Trajectory",
         subtitle = paste0("Disturbance: ", format(dist_date),
                           " | Linear model R\u00b2 = ", round(summary(m_lin)$r.squared, 3))) +
    theme_bw()

  ggsave(file.path(output_dir, "recovery_trajectory.png"), p, width = 8, height = 5, dpi = 150)
  log_info("recovery_trajectory.png salvo em: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha ao gerar grafico de trajetoria de recuperacao: %s\nCausa provavel: dados insuficientes para projecao ou diretorio sem permissao de escrita.\nVerifique: se post_fit contem observacoes validas.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

# ── 9. Full time series context plot ───────────────────────────────────────────
log_step(9, "Gerar grafico de contexto da serie temporal completa")
tryCatch({
  p2 <- ggplot(dat, aes(x = .data[[date_col]], y = .data[[val_col]])) +
    geom_line(colour = "grey60", linewidth = 0.6) +
    geom_vline(xintercept = as.numeric(dist_date), linetype = "dashed",
               colour = "red", linewidth = 0.8) +
    geom_hline(yintercept = baseline_mean, linetype = "dotted",
               colour = "forestgreen", linewidth = 0.8) +
    annotate("text", x = dist_date, y = max(dat[[val_col]], na.rm=TRUE),
             label = " Disturbance", hjust = 0, colour = "red", size = 3.2) +
    annotate("text", x = min(dat[[date_col]]), y = baseline_mean + 0.005,
             label = "Pre-disturbance baseline", hjust = 0, colour = "forestgreen", size = 3) +
    labs(x = NULL, y = val_col, title = "Full NDVI Time Series with Disturbance Event") +
    theme_bw()
  ggsave(file.path(output_dir, "timeseries_context.png"), p2, width = 10, height = 4, dpi = 150)
  log_info("timeseries_context.png salvo em: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha ao gerar grafico de contexto da serie temporal: %s\nCausa provavel: colunas de data ou valor invalidas ou diretorio sem permissao de escrita.\nVerifique: integridade do CSV de entrada.\nSkill anterior: geoprocessing-for-ecology.",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Analise de recuperacao concluida. Saidas em: %s", output_dir)
log_info("Metricas-chave:")
print(t(recovery_metrics))
