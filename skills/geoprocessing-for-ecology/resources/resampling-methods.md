# Resampling Methods Reference

## Method Descriptions

### Nearest Neighbour (`near`)
- Assigns the value of the nearest source pixel
- **Use for:** Categorical data (land cover, soil type, administrative zones)
- **Avoid for:** Continuous data (creates blocky artefacts)
- GDAL flag: `-r near`

### Bilinear (`bilinear`)
- Weighted average of the 4 nearest source pixels
- **Use for:** Continuous data (elevation, temperature, precipitation, NDVI)
- Avoids blocky artefacts; slightly smooths the data
- GDAL flag: `-r bilinear`

### Cubic (`cubic`)
- Weighted average of the 16 nearest source pixels (bicubic spline)
- **Use for:** High-quality DEM processing, fine-resolution resampling
- Smoother than bilinear; may introduce slight ringing at edges
- GDAL flag: `-r cubic`

### Average (`average`)
- Average of all source pixels overlapping the target pixel
- **Use for:** Downsampling (coarsening resolution); preserves mean values
- GDAL flag: `-r average`

### Mode (`mode`)
- Most frequent value among source pixels
- **Use for:** Downsampling categorical data (land cover aggregation)
- GDAL flag: `-r mode`

### Sum (`sum`)
- Sum of all source pixels overlapping the target pixel
- **Use for:** Count data aggregation (fire frequency, species count per cell)
- GDAL flag: `-r sum`

## Decision Guide

```
Is the data categorical?
  YES → Use: nearest (upsampling) | mode (downsampling)
  NO  → Is high spatial precision critical?
          YES → Use: cubic
          NO  → Are you downsampling (coarsening)?
                  YES → Use: average
                  NO  → Use: bilinear
```

## Common Mistakes

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| Bilinear on land cover | Creates fractional class values | Use nearest |
| Nearest on elevation | Blocky DEM, poor slope/aspect | Use bilinear or cubic |
| No resampling specified | GDAL defaults to nearest | Always specify `-r` |
| Mixing resolutions in stack | Spatial misalignment | Resample all to common grid first |
