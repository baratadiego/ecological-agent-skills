# Known Issues

Problems encountered with packages or configurations that may affect users of this repository. Entries are maintained as issues are discovered and resolved.

---

## Issue: blockCV fails with geographic CRS on large extents

- **Skill affected:** predictive-modeling-best-practices
- **Package/version:** blockCV >= 3.0.0 with sf >= 1.0.0
- **Symptom:** `spatialBlock()` throws error "st_buffer does not work correctly for longitude/latitude data" when input occurrences use EPSG:4326 (WGS84 geographic) and study area spans > 50 degrees longitude.
- **Cause:** sf >= 1.0 uses S2 spherical geometry by default. `st_buffer()` on geographic coordinates creates invalid geometries at large spatial extents.
- **Solution:** Either (a) project to an appropriate equal-area CRS before calling `spatialBlock()`, or (b) temporarily disable S2 with `sf::sf_use_s2(FALSE)` before the blockCV call and re-enable after.
- **Reported:** 2026-01-15
- **Status:** Open — documented in `skills/predictive-modeling-best-practices/resources/sampling-bias-correction.md`

---

## Issue: ENMeval 2.x incompatible with terra < 1.6

- **Skill affected:** species-distribution-modeling
- **Package/version:** ENMeval >= 2.0.0 requires terra >= 1.6.0
- **Symptom:** `ENMevaluate()` fails with "Error in .check_ext_xy" or "formal argument 'ext' matched by multiple actual arguments" when terra is version 1.5.x or older.
- **Cause:** ENMeval 2.x uses terra's updated extent API (`ext()` class changed in terra 1.6). Older terra versions have a different method signature.
- **Solution:** Upgrade terra to >= 1.7.0: `install.packages("terra")`. If using renv, run `renv::update("terra")`.
- **Reported:** 2026-02-10
- **Status:** Open — `renv.lock` pins terra >= 1.7.0, but users with local renv caches may have older versions.

---

## Issue: camtrapR fails with spaces in file paths on Windows

- **Skill affected:** camera-trap-processing
- **Package/version:** camtrapR >= 2.2.0 on Windows
- **Symptom:** `recordTable()` returns "Error in file(file, 'rt'): cannot open connection" when the image directory path contains spaces (e.g., `C:\Users\My Name\camera_data\`).
- **Cause:** camtrapR internally uses `system()` calls that do not properly quote file paths with spaces on Windows.
- **Solution:** Move camera trap image directories to a path without spaces (e.g., `C:\camtrap_data\`), or create a symbolic link: `mklink /D C:\camtrap C:\Users\My Name\camera_data`.
- **Reported:** 2026-02-22
- **Status:** Open — documented in `skills/camera-trap-processing/SKILL.md` Notes section.
