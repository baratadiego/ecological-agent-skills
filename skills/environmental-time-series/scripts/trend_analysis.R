# Usage: Rscript trend_analysis.R <timeseries.csv> <output_dir> [frequency] [baseline_end]
# Mann-Kendall trend + Sen's slope + BFAST breakpoints
# Usage: Rscript trend_analysis.R <timeseries_csv> <output_dir> [frequency]
# Requires: trend, bfast, zoo, ggplot2

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
  library(trend)
  library(bfast)
  library(zoo)
  library(ggplot2)
})

args       <- commandArgs(trailingOnly = TRUE)
ts_file    <- ifelse(length(args) >= 1, args[1], "data/ndvi_series.csv")
output_dir <- ifelse(length(args) >= 2, args[2], "outputs/timeseries")
freq       <- ifelse(length(args) >= 3, as.integer(args[3]), 12L)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_info("Skill: %s | ts_file=%s | output_dir=%s | freq=%d",
         SKILL_NAME, ts_file, output_dir, freq)
log_decision("freq", as.character(freq),
             "frequencia da serie temporal (observacoes por ano); padrao 12 para dados mensais")

# ── Input precondition check ──────────────────────────────────────────────────
if (!file.exists(ts_file)) {
  log_error(
    "Input nao encontrado: %s\nCausa provavel: serie temporal nao gerada ou caminho incorreto.\nVerifique: execute primeiro o script de extracao/exportacao da serie temporal.\nSkill anterior: geoprocessing-for-ecology ou remote-sensing-analysis.",
    ts_file
  )
  stop("Missing: ", ts_file)
}

# ── Load ───────────────────────────────────────────────────────────────────────
log_step(1, "Carregar serie temporal e validar coluna 'value'")
dat <- tryCatch({
  read.csv(ts_file)
}, error = function(e) {
  log_error(
    "Falha ao ler CSV de serie temporal: %s\nCausa provavel: arquivo corrompido, encoding incorreto ou separador diferente de virgula.\nVerifique: abra o arquivo em editor de texto e confira o formato.\nSkill anterior: geoprocessing-for-ecology.",
    conditionMessage(e)
  )
  stop(e)
})

if (!"value" %in% names(dat)) {
  log_error(
    "Coluna 'value' nao encontrada no CSV (colunas presentes: %s).\nCausa provavel: CSV exportado com nome de coluna diferente.\nVerifique: renomeie a coluna de valores para 'value' ou ajuste o script.\nSkill anterior: geoprocessing-for-ecology.",
    paste(names(dat), collapse = ", ")
  )
  stop("Missing column: value")
}

n_na <- sum(is.na(dat$value))
if (n_na > 0) {
  log_warn("Coluna 'value' contem %d valores NA — Mann-Kendall pode ser afetado.", n_na)
}

log_info("Observacoes: %d | Frequencia: %d", nrow(dat), freq)

ts_obj <- ts(dat$value, frequency = freq)

# ── Mann-Kendall + Sen's slope ─────────────────────────────────────────────────
log_step(2, "Teste de Mann-Kendall e inclinacao de Sen")
mk  <- tryCatch({
  mk.test(dat$value)
}, error = function(e) {
  log_error(
    "Falha no teste de Mann-Kendall: %s\nCausa provavel: serie com todos os valores iguais ou NA excessivo.\nVerifique: variabilidade dos dados de entrada.\nSkill anterior: geoprocessing-for-ecology.",
    conditionMessage(e)
  )
  stop(e)
})

sen <- tryCatch({
  sens.slope(dat$value)
}, error = function(e) {
  log_error(
    "Falha ao calcular inclinacao de Sen: %s\nCausa provavel: serie insuficiente ou sem variacao.\nVerifique: numero de observacoes validas.\nSkill anterior: geoprocessing-for-ecology.",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Mann-Kendall: tau=%.4f | p=%.4f", mk$statistic, mk$p.value)
log_info("Inclinacao de Sen: %.6f (unidades/observacao)", sen$estimates)

if (mk$p.value < 0.05) {
  trend_dir <- ifelse(mk$statistic > 0, "crescente", "decrescente")
  log_info("Tendencia significativa detectada (p<0.05): %s", trend_dir)
} else {
  log_info("Nenhuma tendencia significativa detectada (p=%.4f >= 0.05).", mk$p.value)
}

mk_results <- data.frame(
  tau = mk$statistic, p_value = mk$p.value,
  sens_slope = as.numeric(sen$estimates),
  trend_direction = ifelse(mk$p.value < 0.05,
                           ifelse(mk$statistic > 0, "increasing", "decreasing"),
                           "no significant trend")
)

tryCatch({
  write.csv(mk_results, file.path(output_dir, "trend_results.csv"), row.names = FALSE)
  log_info("trend_results.csv salvo em: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha ao salvar trend_results.csv: %s\nCausa provavel: permissao negada ou disco cheio.\nVerifique: permissoes do diretorio de saida.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

# ── BFAST breakpoints ──────────────────────────────────────────────────────────
log_step(3, "Detectar quebras estruturais com BFAST")
min_length_bfast <- 3 * freq
if (length(ts_obj) >= min_length_bfast) {
  log_info("Serie suficiente para BFAST (%d obs >= %d minimo). Executando...", length(ts_obj), min_length_bfast)
  log_decision("bfast_h", "0.15",
               "h=0.15 requer pelo menos 15%% da serie entre quebras; equilibrio entre sensibilidade e estabilidade")
  log_decision("bfast_season", "harmonic",
               "modelo harmonico para sazonalidade adequado para series de vegetacao com ciclo anual")
  tryCatch({
    bf <- bfast(ts_obj, h = 0.15, season = "harmonic", max.iter = 20)
    bp <- bf$output[[1]]$bp.Vt$breakpoints
    if (length(bp) == 0 || all(is.na(bp))) {
      log_info("BFAST: nenhuma quebra estrutural detectada.")
    } else {
      log_info("BFAST: quebras detectadas nas observacoes: %s", paste(bp, collapse = ", "))
    }
    write.csv(data.frame(breakpoint_obs = bp),
              file.path(output_dir, "breakpoints.csv"), row.names = FALSE)
    log_info("breakpoints.csv salvo em: %s", output_dir)
    png(file.path(output_dir, "bfast_plot.png"), width = 1200, height = 600, res = 150)
    plot(bf)
    dev.off()
    log_info("bfast_plot.png salvo em: %s", output_dir)
  }, error = function(e) {
    log_warn("BFAST falhou: %s — continuando sem deteccao de quebras.", conditionMessage(e))
  })
} else {
  log_warn("Serie muito curta para BFAST: %d obs < %d minimo (3 ciclos completos de frequencia %d).",
           length(ts_obj), min_length_bfast, freq)
}

# ── Anomalies ──────────────────────────────────────────────────────────────────
log_step(4, "Calcular anomalias em relacao ao baseline")
baseline_n    <- min(freq * 10, length(dat$value) %/% 2)
baseline_mean <- mean(dat$value[1:baseline_n], na.rm = TRUE)
baseline_sd   <- sd(dat$value[1:baseline_n],   na.rm = TRUE)

log_decision("baseline_n", as.character(baseline_n),
             "minimo entre 10 anos de dados e metade da serie; evita que o baseline abranja o periodo de mudanca")
log_info("Baseline: %.4f +/- %.4f (primeiras %d observacoes)", baseline_mean, baseline_sd, baseline_n)

if (baseline_sd == 0) {
  log_warn("Desvio padrao do baseline e zero — todas as anomalias serao infinitas ou NaN.")
}

dat$anomaly_z <- (dat$value - baseline_mean) / baseline_sd

n_extreme <- sum(abs(dat$anomaly_z) > 3, na.rm = TRUE)
if (n_extreme > 0) {
  log_warn("%d observacao(oes) com anomalia |Z| > 3 detectada(s) — possiveis outliers ou eventos extremos.", n_extreme)
}

tryCatch({
  write.csv(dat[, c(names(dat)[1], "value", "anomaly_z")],
            file.path(output_dir, "anomaly_series.csv"), row.names = FALSE)
  log_info("anomaly_series.csv salvo em: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha ao salvar anomaly_series.csv: %s\nCausa provavel: permissao negada ou disco cheio.\nVerifique: permissoes do diretorio de saida.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Anomalias calculadas em relacao as primeiras %d observacoes.", baseline_n)
log_info("Analise de tendencia concluida. Saidas em: %s", output_dir)
