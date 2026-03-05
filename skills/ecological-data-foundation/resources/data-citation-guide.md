# Data Citation Guide for Ecological Occurrence Data

Reference for citing biodiversity data sources correctly in publications, reports, and analytical workflows. Covers citation formats, data-use policies, and licence requirements for the six primary sources supported by this skill library.

---

## 1. GBIF — Global Biodiversity Information Facility

**Website**: https://www.gbif.org
**API**: https://api.gbif.org/v1/

### Citation formats

#### `occ_download` / `occ.download` (preferred for publications)
GBIF issues a citable DOI for every download submitted via `occ_download` (R) or `occ.download` (Python). The DOI resolves to a stable dataset snapshot.

```
GBIF.org (YEAR) GBIF Occurrence Download.
https://doi.org/10.15468/dl.XXXXXXX
Accessed on YYYY-MM-DD.
```

Example (R):
```r
meta <- occ_download_meta(dl_key)
doi  <- meta$doi
cat("Citation: GBIF.org (", format(Sys.Date(), "%Y"), ") GBIF Occurrence Download. ",
    "https://doi.org/", doi, " Accessed on ", Sys.Date(), ".\n", sep = "")
```

#### `occ_search` / `occ.search` (no DOI)
`occ_search` does not generate a persistent DOI and **should not be used in publications**. For exploratory analysis only. Record the query date and parameters manually.

```
GBIF.org (YEAR) Occurrence records for [species]. Query via GBIF API (occ_search).
Accessed on YYYY-MM-DD. [Not citable — re-run with occ_download for publication.]
```

### Data use policy
- Most records: **CC BY 4.0** or **CC0**
- Some datasets: **CC BY-NC 4.0** (check individual dataset licences at https://www.gbif.org/dataset)
- Always attribute the original data provider, not only GBIF
- Use the GBIF citation widget: https://www.gbif.org/citation-guidelines

---

## 2. iNaturalist

**Website**: https://www.inaturalist.org
**API**: https://api.inaturalist.org/v1/

### Citation format

iNaturalist does **not** issue download DOIs. Record the access date precisely.

```
iNaturalist contributors and the California Academy of Sciences (YEAR).
iNaturalist Research-grade Observations. iNaturalist.org.
Accessed on YYYY-MM-DD. https://www.inaturalist.org
```

Or, if re-exported through GBIF:
```
iNaturalist (YEAR) Occurrence records exported via GBIF.
https://doi.org/10.15468/ab3s5x
Accessed on YYYY-MM-DD.
```

### Quality grades
| Grade | Meaning | SDM recommendation |
|-------|---------|-------------------|
| **Research** | ID agreed by ≥2 users, has coordinates, is not captive | Use by default |
| **Needs ID** | Single ID or disagreement | Avoid for SDM |
| **Casual** | Missing fields, captive, or cultivated | Exclude |

### Data use policy
- Research-grade observations: **CC BY-NC** by default (individual users may choose CC0 or CC BY)
- Commercial use requires CC0 or CC BY records only
- Bulk data exports for research: permitted; cite as above

---

## 3. eBird (Cornell Lab of Ornithology)

**Website**: https://ebird.org
**Data portal**: https://ebird.org/data/download

### Citation format

eBird data requires a **signed Data Use Agreement**. Access is free but must be requested.

```
eBird Basic Dataset (EBD). Version: YEAR-MM.
Cornell Lab of Ornithology, Ithaca, New York.
https://ebird.org/data/download
Accessed on YYYY-MM-DD.
```

### Data use policy
- **Non-commercial research** only under the eBird Data Access Agreement
- Data may not be redistributed or used to create competing products
- Publications must acknowledge eBird and include the citation above
- Restricted species data (sensitive species, breeding season) may be withheld

### Filtering recommendations for SDM
| Filter | Recommended value | Rationale |
|--------|------------------|-----------|
| Protocol | Stationary, Traveling | Standardised effort |
| Approved | TRUE | Quality-reviewed by eBird |
| Complete checklist | TRUE | Absence implied for non-detected species |
| Effort distance | ≤5 km | Reduces localisation uncertainty |
| Duration | 5–300 min | Avoids very short/long checklists |

---

## 4. OBIS — Ocean Biodiversity Information System

**Website**: https://obis.org
**API**: https://api.obis.org/v3/

### Citation format

```
OBIS (YEAR). Ocean Biodiversity Information System.
Intergovernmental Oceanographic Commission of UNESCO.
www.obis.org. Accessed on YYYY-MM-DD.
```

For specific datasets within OBIS, also cite the original dataset DOI available in each record's `datasetName` and `resourceID` fields.

### Data use policy
- **CC0 1.0** (public domain dedication)
- Users encouraged (but not required) to share results with OBIS
- Do not use OBIS data to identify precise locations of sensitive species (use aggregated records)

### Quality flags to exclude
| Flag | Meaning |
|------|---------|
| `NO_COORD` | Missing coordinates |
| `ZERO_COORD` | Coordinates are 0,0 |
| `ON_LAND` | Marine record mapped to land |
| `DEPTH_EXCEEDS_BATH` | Depth exceeds bathymetry |
| `COORDINATE_MISMATCH` | Textual and coordinate locations conflict |

---

## 5. IUCN Red List

**Website**: https://www.iucnredlist.org
**API**: https://apiv3.iucnredlist.org
**API key**: Required — apply at https://apiv3.iucnredlist.org/

### Citation format

```
IUCN (YEAR). The IUCN Red List of Threatened Species. Version YEAR-N.
https://www.iucnredlist.org. Accessed on YYYY-MM-DD.
```

For species-specific assessments:
```
[Author(s)] (YEAR). [Species name]. The IUCN Red List of Threatened Species YEAR:
[Category]. https://dx.doi.org/10.2305/IUCN.UK.[version].RLTS.[TXID].en.
Accessed on YYYY-MM-DD.
```

### Data use policy
- **CC BY 4.0**
- Distribution maps and species data may not be used to create competing databases
- API key must not be shared; each user must register independently
- Sensitive species (CR, EN) distribution data may be partially obscured

### Red List categories
| Code | Category |
|------|---------|
| EX | Extinct |
| EW | Extinct in the Wild |
| CR | Critically Endangered |
| EN | Endangered |
| VU | Vulnerable |
| NT | Near Threatened |
| LC | Least Concern |
| DD | Data Deficient |
| NE | Not Evaluated |

---

## 6. WorldClim / CHELSA (Predictor Data)

### WorldClim v2.1

```
Fick, S.E. & Hijmans, R.J. (2017). WorldClim 2: new 1-km spatial resolution climate surfaces
for global land areas. International Journal of Climatology 37(12): 4302–4315.
https://doi.org/10.1002/joc.5086
```

**Licence**: CC BY 4.0

### CHELSA v2.1

```
Karger, D.N. et al. (2021). Global climate data at high spatial resolution (CHELSA v2.1).
Scientific Data 8: 282. https://doi.org/10.1038/s41597-021-01084-7
```

**Licence**: CC BY 4.0

---

## Combining Multiple Sources

When merging occurrence data from multiple sources, include the `source` and `datasetName` columns in your output so records can be traced back to their origin.

### Recommended merge workflow
```r
library(dplyr)
occ_all <- bind_rows(
  read_csv("output/gbif/occurrences_raw_GBIF_Panthera_onca_20260101.csv"),
  read_csv("output/inat/occurrences_raw_iNat_Panthera_onca_20260101.csv"),
  read_csv("output/obis/occurrences_raw_OBIS_Chelonia_mydas_20260101.csv")
) |>
  distinct(species, decimalLatitude, decimalLongitude, eventDate, .keep_all = TRUE)
```

### Master data citation block (for Methods section)
```
Occurrence data were downloaded from GBIF (GBIF.org YEAR, doi:...), iNaturalist
(iNaturalist contributors and CAS YEAR, accessed YYYY-MM-DD), and OBIS (OBIS YEAR,
accessed YYYY-MM-DD). Records were merged and spatially thinned to one record per
[resolution] grid cell. Final dataset: [n] records of [n_species] species, [year_range].
```

---

## Licence Compatibility Matrix

| Source | Licence | Commercial use | Redistribute | Attribution required |
|--------|---------|----------------|-------------|----------------------|
| GBIF (CC0) | CC0 | Yes | Yes | Strongly recommended |
| GBIF (CC BY) | CC BY 4.0 | Yes | Yes | Yes |
| GBIF (CC BY-NC) | CC BY-NC 4.0 | **No** | Yes | Yes |
| iNaturalist | CC BY-NC | **No** | Yes | Yes |
| eBird | Custom DUA | **No** | **No** | Yes |
| OBIS | CC0 | Yes | Yes | Recommended |
| IUCN | CC BY 4.0 | Yes | Yes* | Yes |
| WorldClim | CC BY 4.0 | Yes | Yes | Yes |
| CHELSA | CC BY 4.0 | Yes | Yes | Yes |

*IUCN: redistribution of the full database is not permitted; individual species data may be shared with attribution.

---

## Quick Reference: occ_search vs occ_download (GBIF)

| Aspect | `occ_search` | `occ_download` |
|--------|-------------|---------------|
| Speed | Immediate | Minutes to hours |
| Record limit | 100,000 | Unlimited |
| DOI generated | **No** | **Yes** |
| Reproducible | **No** | **Yes** |
| Recommended for | Exploration | Publication |
| Credentials needed | No | Yes (GBIF account) |

**Rule of thumb**: Use `occ_search` for initial exploration and data assessment. Switch to `occ_download` before any analysis intended for publication.
