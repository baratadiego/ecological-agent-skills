# Installation Guide — ecological-agent-skills

## Choose your install profile

| Profile | Command | Time | Covers |
|---------|---------|------|--------|
| **pip-only** | `pip install -r requirements.txt` | ~2 min | All Python skills |
| **Python + conda** | `conda env create -f environment-python.yaml` | ~5 min | All Python skills (geospatial included) |
| **Full (Python + R)** | `conda env create -f environment.yaml` | ~15–25 min | All 17 skills including R-based analyses |

> **Which should I use?**
> - Start with **pip-only** if you just need SDM, GBIF download, geoprocessing, or acoustic analysis.
> - Use **Python + conda** if pip gives errors about GDAL/GEOS/PROJ (common on Windows/macOS).
> - Use **Full** only if you need R skills: biomod2, maxnet, vegan, occupancy models, spatial prioritization.

---

## Profile 1 — pip-only (~2 min)

```bash
pip install -r requirements.txt
```

**Requirements:** Python >= 3.11. System libraries GDAL, GEOS, and PROJ must be installed separately on Linux/macOS. On Windows, binary wheels from PyPI usually work without system libs.

Check system deps:
```bash
bash setup/check_system_deps.sh
```

---

## Profile 2 — Python + conda (~5 min)

```bash
conda env create -f environment-python.yaml
conda activate ecological-agent-skills-py
```

This installs all Python packages plus GDAL/GEOS/PROJ native libraries via conda-forge. No R is included.

---

## Profile 3 — Full Python + R (~15–25 min)

```bash
conda env create -f environment.yaml
conda activate ecological-agent-skills
```

Then install R packages that are not on conda-forge (see `renv.lock`):
```r
install.packages("renv")
renv::restore()
```

---

## R-only packages (installed via renv)

These packages are not available on conda-forge and are managed by `renv`:

- CoordinateCleaner, blockCV, maxnet, biomod2
- bfast, landscapemetrics, DHARMa, glmmTMB, betapart, SPEI
- camtrapR, overlap, circular, soundecology, tuneR
- popbio, prioritizr, highs
- rinat, auk, robis, rredlist

---

## GBIF credentials (optional but recommended)

Large downloads (> 100,000 records) require async GBIF download, which needs a free GBIF account.

See [docs/GBIF_SETUP.md](docs/GBIF_SETUP.md) for step-by-step instructions.

Without credentials, the script falls back to `occ.search` (no DOI, max ~100,000 records).

---

## Python version compatibility

| Python | Status |
|--------|--------|
| 3.11 | Recommended — all packages available |
| 3.12 | Supported — most packages available |
| 3.13 | Untested |
| 3.14 | Not recommended — `elapid` (MaxEnt) fails to build; `pygbif` has API bugs |

---

## Verify installation

```bash
python setup/check_packages.py
```

```r
source("setup/check_packages.R")
```
