# GBIF Data Citation Guide

How to download, cite, and document GBIF occurrence data correctly for scientific publications.

---

## 1. Why Citation Method Matters

GBIF provides two download mechanisms with fundamentally different citability:

| Method | DOI generated | Citable for publication | Reproducible | Use case |
|---|---|---|---|---|
| `occ_search()` / `pygbif.occurrences.search()` | **No** | No — not recommended for peer review | No (results may change) | Exploration, pilot analysis, dashboards |
| `occ_download()` / `pygbif.occurrences.download()` | **Yes** | Yes — required for publication | Yes (snapshot frozen) | All published analyses |

**Rule:** If your analysis will appear in a publication or technical report, always
use the download API (`occ_download` / `occurrences.download`) to obtain a citable DOI.

---

## 2. How to Cite GBIF Data Correctly

### Standard GBIF citation format (APA-style)

```
GBIF.org (YEAR) GBIF Occurrence Download. https://doi.org/10.15468/dl.XXXXXXX
Accessed on YYYY-MM-DD.
```

**Example:**

```
GBIF.org (2024) GBIF Occurrence Download.
https://doi.org/10.15468/dl.abc123
Accessed on 2024-03-15.
```

### Fields required in every citation

| Field | Example | Notes |
|---|---|---|
| Portal name | `GBIF.org` | Always "GBIF.org", not the institution name |
| Year of download | `(2024)` | Year the download was created |
| Record type | `GBIF Occurrence Download` | Fixed string |
| DOI | `https://doi.org/10.15468/dl.XXXXXXX` | Full URL, not just the suffix |
| Access date | `Accessed on 2024-03-15` | ISO 8601 date format |

---

## 3. Retrieving the DOI from a Download in R

```r
suppressPackageStartupMessages(library(rgbif))

# Initiate download (runs asynchronously on GBIF servers)
download_key <- occ_download(
  pred("taxonKey", 2435098),           # GBIF taxon key for your species
  pred("hasCoordinate", TRUE),
  pred("occurrenceStatus", "PRESENT"),
  pred_in("basisOfRecord", c("HUMAN_OBSERVATION",
                              "MACHINE_OBSERVATION",
                              "PRESERVED_SPECIMEN")),
  pred_lt("coordinateUncertaintyInMeters", 10000),
  format = "SIMPLE_CSV"
)

# Wait for completion (polls every 10 seconds)
occ_download_wait(download_key)

# Retrieve metadata (includes DOI)
meta <- occ_download_meta(download_key)
doi  <- meta$doi   # e.g., "10.15468/dl.abc123"
cat("Download DOI:", doi, "\n")

# Save DOI to metadata file for citation
writeLines(
  c(
    paste("GBIF download key:", download_key),
    paste("DOI:", doi),
    paste("Citation: GBIF.org (", format(Sys.Date(), "%Y"), ") GBIF Occurrence Download.",
          paste0("https://doi.org/", doi),
          "Accessed on", format(Sys.Date(), "%Y-%m-%d")),
    paste("Download date:", Sys.Date()),
    paste("Species:", "Panthera onca")   # replace with your species
  ),
  "download_metadata.txt"
)

# Import the data
occ_data <- occ_download_get(download_key) |> occ_download_import()
```

---

## 4. Retrieving the DOI from a Download in Python

```python
import pygbif.occurrences as occ
import time
from pathlib import Path
from datetime import date

# Initiate download
download_key = occ.download(
    "taxonKey = 2435098",       # replace with actual taxon key
    "hasCoordinate = TRUE",
    "occurrenceStatus = PRESENT",
    "basisOfRecord in HUMAN_OBSERVATION,MACHINE_OBSERVATION,PRESERVED_SPECIMEN",
    "coordinateUncertaintyInMeters <= 10000"
)

# Poll until complete
while True:
    status = occ.download_meta(download_key[0])["status"]
    print(f"Status: {status}")
    if status == "SUCCEEDED":
        break
    elif status == "FAILED":
        raise RuntimeError("GBIF download failed")
    time.sleep(30)

# Get DOI from metadata
meta = occ.download_meta(download_key[0])
doi  = meta.get("doi", "")
print(f"Download DOI: {doi}")

# Save metadata
output_dir = Path("output/gbif")
output_dir.mkdir(parents=True, exist_ok=True)

with open(output_dir / "download_metadata.txt", "w") as f:
    f.write(f"GBIF download key: {download_key[0]}\n")
    f.write(f"DOI: {doi}\n")
    f.write(f"Citation: GBIF.org ({date.today().year}) GBIF Occurrence Download. "
            f"https://doi.org/{doi} Accessed on {date.today().isoformat()}\n")
    f.write(f"Download date: {date.today().isoformat()}\n")
```

---

## 5. Registering the DOI in data_provenance.md

Every project using GBIF data must have a `data_provenance.md` at the project root.
Add an entry like:

```markdown
## GBIF Occurrence Data

| Species | GBIF Taxon Key | Download Key | DOI | Download Date | Filters Applied |
|---|---|---|---|---|---|
| *Panthera onca* | 2435098 | 0001234-240101 | [10.15468/dl.abc123](https://doi.org/10.15468/dl.abc123) | 2024-03-15 | hasCoordinate, PRESENT, uncertainty < 10 km |
| *Chrysocyon brachyurus* | 2441050 | 0001235-240101 | [10.15468/dl.def456](https://doi.org/10.15468/dl.def456) | 2024-03-15 | hasCoordinate, PRESENT, uncertainty < 10 km |
```

---

## 6. occ_search vs occ_download — Decision Guide

| Situation | Use |
|---|---|
| Exploring data availability, checking record counts | `occ_search` (no DOI needed) |
| Pilot/exploratory analysis not for publication | `occ_search` acceptable |
| Analysis to be included in a paper, report, or thesis | **`occ_download` required** |
| Dataset with > 100,000 records | **`occ_download` required** (occ_search limited to 100k) |
| Reproducible analysis shared with collaborators | **`occ_download` required** |
| Training an SDM for conservation planning | **`occ_download` required** |

---

## 7. Common Pitfalls

- **Citing the GBIF portal URL instead of the DOI:** `https://www.gbif.org/occurrence/search?...` is
  not citable. Always use the download DOI.
- **Using `occ_search` for final analysis:** results from `occ_search` are not frozen;
  re-running the same query months later may return different records. Only `occ_download`
  creates a reproducible, citeable snapshot.
- **Forgetting to record the download date:** required even when DOI is present.
- **Not saving `download_metadata.txt`:** always save alongside the occurrence CSV.
- **Using taxon name instead of taxon key:** names can be ambiguous. Use the GBIF
  backbone taxon key (`occ_search(scientificName=...)$key`) for unambiguous queries.
- **Not filtering `coordinateUncertaintyInMeters`:** records with large uncertainty
  (> 10 km) should be excluded or handled explicitly.

---

## 8. References

| Resource | URL |
|---|---|
| GBIF citation guidelines | https://www.gbif.org/citation-guidelines |
| rgbif R package | https://docs.ropensci.org/rgbif/ |
| pygbif Python package | https://pygbif.readthedocs.io/ |
| GBIF DOI minting policy | https://www.gbif.org/faq?question=what-doi-does-gbif-assign-to-downloaded-data |
