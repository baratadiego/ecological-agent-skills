# run_ensemble_sdm.R
# Fit MaxEnt + BRT + RF ensemble SDM
# Usage: Rscript run_ensemble_sdm.R <params_yaml> <output_dir>
# Requires: terra, sf, maxnet, gbm, randomForest, dismo, blockCV, yaml

suppressPackageStartupMessages({
  library(terra); library(sf); library(maxnet)
  library(gbm); library(randomForest); library(yaml)
})

args       <- commandArgs(trailingOnly = TRUE)
params_f   <- ifelse(length(args) >= 1, args[1], "params.yaml")
output_dir <- ifelse(length(args) >= 2, args[2], "outputs/sdm")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

p <- yaml::read_yaml(params_f)
set.seed(p$random_seeds$global)

cat("=== SDM Ensemble Pipeline ===\n")
cat("Output:", output_dir, "\n")
cat("Algorithms:", paste(p$modeling$algorithms, collapse = ", "), "\n")
cat("CV method:", p$modeling$cv_method, "| Folds:", p$modeling$cv_folds, "\n")

# NOTE: This is a scaffold. Load your data and call your modeling functions below.
# Example structure:
#
# occ    <- read.csv("data/processed/occ_thinned.csv")
# bg     <- read.csv("data/processed/background.csv")
# stack  <- rast("data/predictors_stack.tif")
# predictors <- readLines("outputs/selected_predictors.txt")
#
# occ_env <- extract(stack[[predictors]], occ[, c("decimalLongitude","decimalLatitude")])
# bg_env  <- extract(stack[[predictors]], bg[, c("lon","lat")])
#
# train_df <- rbind(
#   cbind(pa = 1, occ_env),
#   cbind(pa = 0, bg_env)
# ) |> na.omit()
#
# # MaxEnt
# mx <- maxnet(p = train_df$pa, data = train_df[,-1],
#              regmult = p$hyperparameters$maxnet$regularization_multiplier[2])
#
# # Predict and ensemble — see biomod2 for full ensemble workflow
cat("Scaffold loaded. Fill in data loading and model calls for your study.\n")
