# Test Suite — ecological-agent-skills

Automated tests for all 12 skills using **pytest** (Python) and **testthat** (R).

---

## Structure

```
tests/
├── data/                         ← synthetic test datasets (see data/README.md)
├── python/
│   ├── conftest.py               ← shared fixtures
│   ├── pytest.ini                ← pytest configuration
│   ├── run_all_tests.sh          ← run full suite
│   ├── test_data_integrity.py    ← validates all test datasets first
│   ├── test_ecological_data_foundation.py
│   ├── test_model_validation.py
│   ├── test_environmental_time_series.py
│   ├── test_community_ecology.py
│   ├── test_predictive_modeling.py
│   ├── test_ecosystem_services.py
│   └── test_occupancy.py
└── r/
    ├── run_all_tests.R           ← run full suite
    ├── test-ecological-data-foundation.R
    ├── test-biostatistics-workbench.R
    ├── test-community-ecology.R
    ├── test-occupancy.R
    └── test-baci-impact.R
```

---

## Running Tests

### Python (pytest)

```bash
# From project root — run all tests
bash tests/python/run_all_tests.sh

# Run a single file
pytest tests/python/test_data_integrity.py -v

# Skip slow/integration tests
pytest tests/python/ -m "not slow and not integration" -v

# Run with coverage (if pytest-cov installed)
pytest tests/python/ --cov=skills --cov-report=term-missing
```

### R (testthat)

```r
# From RStudio or R console — run from project root
Rscript tests/r/run_all_tests.R

# Run a single file
testthat::test_file("tests/r/test-community-ecology.R")

# Run with devtools (if using package structure)
devtools::test()
```

---

## Test Categories

### Unit tests
Each function is tested in isolation with known inputs and expected outputs.
Example: `test_shannon_zero_for_monoculture`, `test_tss_range`.

### Integration tests (marked `slow`)
Run the full script as a subprocess and verify output files.
Example: `test_script_produces_outputs`, `test_recovery_script_produces_files`.

### Data integrity tests
`test_data_integrity.py` runs before everything else and verifies:
- All 11 test CSV files exist and are non-empty
- Known signals are present (breakpoint in NDVI, BACI effect, model AUC)
- Data types and ranges are valid

---

## Adding Tests

1. Write new test functions in the appropriate file (same skill = same file)
2. Use the fixtures from `conftest.py` for shared data
3. Mark slow tests with `@pytest.mark.slow`
4. Update this README if you add a new test file

---

## Dependencies

| Package | Required for |
|---------|-------------|
| `pytest` | All Python tests |
| `numpy`, `pandas`, `scipy` | All Python tests |
| `scikit-learn` | `test_model_validation.py`, `test_predictive_modeling.py` |
| `scikit-bio` | `test_community_ecology.py` (optional — skipped if missing) |
| `testthat` | All R tests |
| `vegan` | `test-community-ecology.R` (optional — skipped if missing) |
| `unmarked` | `test-occupancy.R` (optional — skipped if missing) |
| `glmmTMB` | `test-baci-impact.R` (optional — skipped if missing) |
