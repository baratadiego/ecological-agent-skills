# Usage: Rscript baci_analysis.R <baci_data.csv> <output_dir> [response_col] [random_effects]
# BACI mixed-effects model for ecological impact assessment
# Usage: Rscript baci_analysis.R <data_csv> <response_var> <output_dir>
# Requires: glmmTMB, emmeans, ggplot2, dplyr

# ── Inline logger ─────────────────────────────────────────────────────────────
SKILL_NAME <- "ecological-impact-assessment"
.log_ts  <- function() format(Sys.time(), "[%Y-%m-%d %H:%M:%S]")
log_info <- function(...) message(.log_ts(), " [INFO]  ", sprintf(...))
log_warn <- function(...) message(.log_ts(), " [WARN]  ", sprintf(...))
log_error<- function(...) message(.log_ts(), " [ERROR] ", sprintf(...))
log_step <- function(n, d) log_info("-- STEP %d: %s", n, d)
log_decision <- function(v, val, why) log_info("DECISION | %s = %s | %s", v, val, why)
dir.create("logs", recursive=TRUE, showWarnings=FALSE)

suppressPackageStartupMessages({
  library(glmmTMB)
  library(emmeans)
  library(ggplot2)
  library(dplyr)
})

args         <- commandArgs(trailingOnly = TRUE)
data_file    <- ifelse(length(args) >= 1, args[1], "data/baci_data.csv")
response_var <- ifelse(length(args) >= 2, args[2], "abundance")
output_dir   <- ifelse(length(args) >= 3, args[3], "outputs/baci")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_info("Skill: %s | data_file=%s | response_var=%s | output_dir=%s",
         SKILL_NAME, data_file, response_var, output_dir)

# ── Input precondition check ──────────────────────────────────────────────────
if (!file.exists(data_file)) {
  log_error(
    "Input nao encontrado: %s\nCausa provavel: caminho errado ou arquivo nao gerado pelo passo anterior.\nVerifique: se o arquivo CSV existe e o nome esta correto.\nSkill anterior: ecological-sampling-design ou coleta de campo.",
    data_file
  )
  stop("Missing: ", data_file)
}

log_step(1, "Carregar e validar dados BACI")
dat <- tryCatch({
  read.csv(data_file)
}, error = function(e) {
  log_error(
    "Falha ao ler CSV: %s\nCausa provavel: arquivo corrompido ou encoding incorreto.\nVerifique: abra o arquivo em editor de texto e confira separadores.\nSkill anterior: ecological-sampling-design.",
    conditionMessage(e)
  )
  stop(e)
})

required_cols <- c("site", "period", "treatment", response_var)
missing_cols  <- setdiff(required_cols, names(dat))
if (length(missing_cols) > 0) {
  log_error(
    "Colunas obrigatorias ausentes: %s\nCausa provavel: CSV nao segue o esquema BACI esperado.\nVerifique: o arquivo deve ter colunas site, period, treatment e a variavel resposta.\nSkill anterior: ecological-sampling-design.",
    paste(missing_cols, collapse = ", ")
  )
  stop("Missing columns: ", paste(missing_cols, collapse = ", "))
}

n_na <- sum(is.na(dat[[response_var]]))
if (n_na > 0) {
  log_warn("Coluna '%s' contem %d valores NA — podem ser excluidos pela funcao de modelo.", response_var, n_na)
}

dat$period    <- factor(dat$period,    levels = c("before", "after"))
dat$treatment <- factor(dat$treatment, levels = c("control", "impact"))

n_sites  <- n_distinct(dat$site)
n_before <- sum(dat$period == "before")
n_after  <- sum(dat$period == "after")
log_info("Sites: %d | Before: %d | After: %d", n_sites, n_before, n_after)
log_decision("response_var", response_var, "variavel resposta fornecida pelo usuario ou padrao 'abundance'")
log_decision("family", "nbinom2", "distribuicao binomial negativa adequada para contagens de abundancia com superdispersao")

if (n_sites < 3) {
  log_warn("Apenas %d site(s) detectado(s) — efeitos aleatorios podem nao ser estimaveis.", n_sites)
}

# ── Fit BACI model ────────────────────────────────────────────────────────────
log_step(2, "Ajustar modelo misto BACI (glmmTMB, nbinom2)")
formula_str <- paste(response_var, "~ period * treatment + (1|site)")
log_info("Formula: %s", formula_str)

m <- tryCatch({
  glmmTMB(as.formula(formula_str), data = dat, family = nbinom2())
}, error = function(e) {
  log_error(
    "Falha ao ajustar modelo glmmTMB: %s\nCausa provavel: dados insuficientes, colunas mal codificadas ou singularidade no modelo.\nVerifique: numero de niveis por site/periodo e presenca de zeros excessivos.\nSkill anterior: ecological-sampling-design.",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Modelo ajustado com sucesso.")
print(summary(m))

# ── Extract BACI interaction ───────────────────────────────────────────────────
log_step(3, "Extrair interacao BACI e calcular efeito na escala original")
coef_table <- tryCatch({
  as.data.frame(coef(summary(m))$cond)
}, error = function(e) {
  log_error(
    "Falha ao extrair coeficientes do modelo: %s\nCausa provavel: modelo nao convergiu ou estrutura inesperada.\nVerifique: inspecione summary(m) manualmente.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

baci_row <- grep("period.*treatment|treatment.*period", rownames(coef_table))

if (length(baci_row) > 0) {
  baci_est <- coef_table[baci_row, ]
  log_info("=== Interacao BACI ===")
  print(baci_est)
  effect_multiplicative <- round(exp(baci_est[, "Estimate"]), 3)
  log_info("Efeito na escala original (multiplicativo): %s", paste(effect_multiplicative, collapse = ", "))
  tryCatch({
    write.csv(baci_est, file.path(output_dir, "baci_results.csv"))
    log_info("baci_results.csv salvo em: %s", output_dir)
  }, error = function(e) {
    log_error(
      "Falha ao salvar baci_results.csv: %s\nCausa provavel: permissao negada ou disco cheio.\nVerifique: permissoes do diretorio de saida.\nSkill anterior: nenhuma.",
      conditionMessage(e)
    )
    stop(e)
  })
} else {
  log_warn("Termo de interacao BACI (period:treatment) nao encontrado na tabela de coeficientes.")
}

# ── Before/After plot ──────────────────────────────────────────────────────────
log_step(4, "Gerar grafico BACI (controle vs impacto, antes vs depois)")
tryCatch({
  p_baci <- dat |>
    group_by(period, treatment) |>
    summarise(mean_y = mean(.data[[response_var]], na.rm = TRUE),
              se_y   = sd(.data[[response_var]], na.rm = TRUE) / sqrt(n()),
              .groups = "drop") |>
    ggplot(aes(x = period, y = mean_y, colour = treatment, group = treatment)) +
    geom_line(linewidth = 1) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = mean_y - se_y, ymax = mean_y + se_y), width = 0.1) +
    scale_colour_manual(values = c(control = "#2166ac", impact = "#d6604d")) +
    labs(y = response_var, title = "BACI: Control vs Impact") +
    theme_bw()
  ggsave(file.path(output_dir, "baci_plot.png"), p_baci, width = 6, height = 5, dpi = 150)
  log_info("baci_plot.png salvo em: %s", output_dir)
}, error = function(e) {
  log_error(
    "Falha ao gerar ou salvar grafico BACI: %s\nCausa provavel: dados insuficientes para sumarizacao ou diretorio sem permissao de escrita.\nVerifique: presenca de pelo menos um registro por combinacao period/treatment.\nSkill anterior: nenhuma.",
    conditionMessage(e)
  )
  stop(e)
})

log_info("Analise BACI concluida. Saidas em: %s", output_dir)
