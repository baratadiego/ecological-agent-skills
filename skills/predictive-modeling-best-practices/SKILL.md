---
skill_version: 1.0.0
---

# Skill: predictive-modeling-best-practices

**Domain:** CV · Tuning · Leakage · Collinearity · Overfitting  
**Phase:** 1 — Foundation  
**Used by:** run-sdm-study, build-fire-risk-map

---

## Purpose

Ensures that any predictive model in the project is built with sound ML practices: proper data splitting, cross-validation strategy, hyperparameter tuning, collinearity reduction, leakage prevention, and overfitting diagnosis.

---

## When to Invoke

- Before fitting any algorithmic model (MaxEnt, BRT, Random Forest, ANN, GLM for prediction)
- When designing the validation strategy for a modeling study
- When the user asks about feature selection, predictor reduction, or model tuning

---

## Inputs

| Input | Format | Required |
|-------|--------|----------|
| Feature matrix (predictors) | CSV, data frame | Yes |
| Target variable | Vector (binary, continuous, multiclass) | Yes |
| Spatial coordinates (if applicable) | lat/lon columns | Recommended |
| Candidate model list | Text description | Optional |

---

## Outputs

| Output | Description |
|--------|-------------|
| `cv_strategy.md` | Chosen CV method with rationale |
| `collinearity_report.csv` | VIF and pairwise correlation for all predictors |
| `selected_predictors.txt` | Final predictor set after reduction |
| `tuning_results.csv` | Hyperparameter grid search results |
| `leakage_audit.md` | Confirmation of no data leakage |
| `modeling_plan.md` | Complete modeling plan document |

---

## Steps

### 1. Define the Modeling Objective
- Regression, binary classification, or multiclass?
- Interpolation within the study area or extrapolation to new areas/times?
- Primary metric: AUC, TSS, RMSE, R², F1?

### 2. Data Splitting Strategy

**For non-spatial data:**
- Random split: 70% train / 15% validation / 15% test (or use k-fold CV)

**For spatial data (required for SDMs and most ecological models):**
- Spatial block cross-validation (checkerboard or custom blocks)
- Block size should exceed the spatial autocorrelation range
- Never use random splits for spatially autocorrelated data

**For temporal data:**
- Forward-chaining (walk-forward) CV; never shuffle temporal order

### 3. Collinearity Assessment
- Compute Pearson/Spearman correlation matrix for all predictors
- Flag pairs with |r| > 0.7
- Compute VIF; flag predictors with VIF > 5
- Reduce collinear predictors using:
  - Ecological/domain knowledge priority
  - PCA (when interpretability is not critical)
  - VIF-stepwise removal

### 4. Leakage Audit
- Confirm that target variable information does not appear in any predictor
- Confirm that future information is not used for past predictions
- Confirm that validation/test data were not used during feature engineering or scaling

### 5. Hyperparameter Tuning
- Define tuning grid for each candidate algorithm
- Use the training set + CV folds only; never touch the test set
- Report best hyperparameters and CV performance curve
- Flag overfitting: large gap between train and CV performance

### 6. Feature Importance Pre-selection (optional)
- Run a preliminary model to rank feature importance
- Remove predictors with near-zero importance AND high collinearity burden
- Re-run CV with reduced predictor set; confirm no performance loss

### 7. Finalize and Document Modeling Plan
- Chosen algorithm(s)
- CV strategy
- Final predictor set
- Tuned hyperparameters
- Primary evaluation metric

---

## Key Decisions to Document

- CV strategy and block size (for spatial CV)
- Collinearity threshold used
- Predictor selection method
- Tuning method (grid search, random search, Bayesian)
- Train/validation/test split sizes

---

## Tools and Libraries

**R:** `caret`, `tidymodels`, `blockCV`, `ENMeval`, `corrplot`, `usdm`  
**Python:** `scikit-learn`, `optuna`, `shap`, `scipy.spatial`

---

## Resources

- `resources/spatial-cv-guide.md` — spatial block CV configuration guide
- `resources/collinearity-decision-tree.md` — when and how to remove predictors
- `examples/` — worked tuning examples for BRT and Random Forest

---

## Notes

- Spatial CV is mandatory for SDMs and any model with spatially autocorrelated responses
- Report both training and CV/test performance; never report training performance alone
- Regularisation (LASSO, ridge) is preferred over manual stepwise selection
