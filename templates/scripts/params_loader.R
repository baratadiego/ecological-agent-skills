# params_loader.R
# Load project parameters from params.yaml into R environment
# Source this at the top of every analysis script:
#   source("scripts/params_loader.R")
# Requires: yaml

if (!requireNamespace("yaml", quietly = TRUE)) install.packages("yaml")
library(yaml)

PARAMS_FILE <- "params.yaml"
if (!file.exists(PARAMS_FILE)) stop("params.yaml not found in working directory: ", getwd())

p <- yaml::read_yaml(PARAMS_FILE)
cat("params.yaml loaded. Project:", p$project$name, "| Version:", p$project$version, "\n")

# Set random seeds
set.seed(p$random_seeds$global)
cat("Global random seed set to:", p$random_seeds$global, "\n")

# Convenience aliases
PROJECT_CRS  <- p$spatial$project_crs
ANALYSIS_CRS <- p$spatial$analysis_crs
OUTPUT_RES   <- p$spatial$raster_resolution_m
CV_FOLDS     <- p$modeling$cv_folds
N_BACKGROUND <- p$modeling$background_n
VIF_THRESH   <- p$modeling$collinearity_vif_threshold

cat("CRS:", PROJECT_CRS, "| CV folds:", CV_FOLDS, "| Background n:", N_BACKGROUND, "\n")
