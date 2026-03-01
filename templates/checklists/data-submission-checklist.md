# Data Submission Checklist (for Zenodo / OSF / figshare)

## Before Uploading

- [ ] All raw data files in standard open formats (CSV, GeoTIFF, GPKG — not proprietary)
- [ ] All files named meaningfully (no "data_final_v2_USE_THIS.csv")
- [ ] README.md describes every file: what it contains, what each column means, units
- [ ] Taxonomy validated against a standard backbone (version stated)
- [ ] Darwin Core fields used for biodiversity occurrence data
- [ ] Sensitive species data: coordinate uncertainty added or location generalised per GBIF policy
- [ ] Coordinate reference system stated for all spatial files
- [ ] File checksums computed (MD5 or SHA256) and listed in README

## Metadata

- [ ] Title: descriptive, includes taxon, region, and type of data
- [ ] Authors and ORCIDs: complete and correct
- [ ] DOI of associated publication (if available): linked
- [ ] License: explicitly stated (CC BY 4.0 recommended for open science)
- [ ] Keywords: 5–10 relevant terms
- [ ] Temporal coverage: start date – end date
- [ ] Spatial coverage: bounding box coordinates

## For Occurrence Data Specifically

- [ ] All Darwin Core terms documented
- [ ] basisOfRecord populated
- [ ] coordinateUncertaintyInMeters populated where known
- [ ] geodeticDatum = "WGS84" confirmed
- [ ] License per record populated if records from multiple sources

## After Uploading

- [ ] DOI resolved and landing page accessible
- [ ] All files download correctly
- [ ] README renders correctly on the platform
- [ ] DOI included in manuscript data availability statement
- [ ] Zenodo/OSF record linked in the code repository README
