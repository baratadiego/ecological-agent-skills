# camtrapR Workflow Guide

## Required Directory Structure

camtrapR requires images organised in a strict hierarchy:

```
image_dir/
├── Station_A/
│   ├── Panthera_pardus/
│   │   ├── Station_A__Panthera_pardus__2023-06-01__02-15-33(1).JPG
│   │   └── Station_A__Panthera_pardus__2023-06-01__02-16-01(2).JPG
│   └── Loxodonta_africana/
│       └── Station_A__Loxodonta_africana__2023-06-03__18-40-12(1).JPG
└── Station_B/
    └── ...
```

**Rules:**
- Station directory names become station IDs — use consistent naming
- Species directory names become species labels — use binomial Latin names with underscores
- Image filenames are not parsed by camtrapR (EXIF timestamps are used)

---

## Creating the Camera Metadata Table

```r
suppressPackageStartupMessages(library(camtrapR))

# Minimum required columns
camera_metadata <- data.frame(
  Station      = c("Station_A", "Station_B", "Station_C"),
  utm_x        = c(310500, 312000, 308700),  # or latitude/longitude
  utm_y        = c(9045200, 9043100, 9047800),
  Setup_date   = c("2023-05-01", "2023-05-01", "2023-05-03"),
  Retrieval_date = c("2023-07-31", "2023-07-31", "2023-07-31"),
  Problem1_from = NA,  # date camera was inactive (malfunction)
  Problem1_to   = NA
)
```

---

## Building the Record Table

```r
# Extract EXIF timestamps and build record table
record_table <- recordTable(
  inDir               = "image_dir/",
  IDfrom              = "directory",     # species ID from directory name
  minDeltaTime        = 30,             # independence threshold in minutes
  deltaTimeComparedTo = "lastIndependentRecord",
  timeZone            = "Africa/Nairobi",
  video               = list(
    file_formats = "mp4",
    dateTimeTag  = "QuickTime:CreateDate"
  )
)

write.csv(record_table, "outputs/record_table.csv", row.names = FALSE)
```

---

## Camera Operation Matrix

```r
# Create daily operation matrix (required for effort calculation)
cam_op <- cameraOperation(
  CTtable      = camera_metadata,
  stationCol   = "Station",
  setupCol     = "Setup_date",
  retrievalCol = "Retrieval_date",
  hasProblems  = TRUE,        # set TRUE if any cameras had problems
  dateFormat   = "yyyy-mm-dd"
)

# Compute trap-nights per station
trap_effort <- apply(cam_op, 1, sum, na.rm = TRUE)
```

---

## Generating Detection History for Unmarked

```r
# Occasion length: 7 days (weekly detection history)
det_hist <- detectionHistory(
  recordTable  = record_table,
  camOp        = cam_op,
  stationCol   = "Station",
  speciesCol   = "Species",
  recordDateTimeCol = "DateTimeOriginal",
  species      = "Panthera_pardus",
  occasionLength = 7,
  day1         = "station",
  output       = "binary"  # or "count" for N-mixture models
)

# det_hist$detection_history is the matrix for unmarked::occu()
```

---

## Key Functions Reference

| Function | Purpose | Key arguments |
|---|---|---|
| `recordTable()` | Build detection record from images | `inDir`, `IDfrom`, `minDeltaTime` |
| `cameraOperation()` | Build daily operation matrix | `CTtable`, `setupCol`, `retrievalCol` |
| `detectionHistory()` | Convert records to site × occasion matrix | `species`, `occasionLength`, `output` |
| `activityHistogram()` | Plot raw activity histogram | `recordTable`, `species` |
| `activityDensity()` | Kernel density of activity times | `recordTable`, `species` |
| `activityOverlap()` | Diel overlap between two species/groups | `recordTable`, `speciesA`, `speciesB` |
| `spatialDetectionHistory()` | Spatial capture-recapture input | Requires individual ID column |

---

## Pitfalls

- **EXIF must be present:** camtrapR reads timestamps from image EXIF. If images were transferred in a way that strips EXIF (e.g., some MMS or cloud transfers), timestamps will be wrong. Always use original files.
- **Time zone matters:** Incorrect timezone shifts all timestamps. Double-check against known sunrise/sunset events in the record table.
- **Camera malfunctions inflate trap-nights if not recorded:** Use `Problem1_from` / `Problem1_to` columns in the metadata table for any known periods of inactivity.

---

## References

- Niedballa, J. et al. (2016). camtrapR: an R package for efficient camera trap data management. *Methods in Ecology and Evolution*, 7(12), 1457–1462. DOI: 10.1111/2041-210X.12600
