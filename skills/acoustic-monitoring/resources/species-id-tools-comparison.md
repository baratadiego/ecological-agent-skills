# Species Identification Tools Comparison

## Tool Comparison Table

| Tool | Taxa covered | Cost | API / CLI | Recommended confidence | Geographic limitation |
|---|---|---|---|---|---|
| BirdNET | Birds (10,000+ species) | Free (open source) | CLI + Python API | ≥ 0.7 | Best in North America and Europe |
| RavenPro | Any (manual + CNN) | Paid ($400–$800) | None (GUI) | User-defined | None |
| Kaleidoscope Pro | Bats, birds | Paid ($350+) | None (GUI) | ≥ 90% | None |
| ARBIMON | Tropical birds, frogs | Free (cloud) | Web API | ≥ 0.8 | Tropics focus |
| Rainforest Connection | Chainsaws, birds | Proprietary | API (partners) | N/A | Tropical forests |

---

## BirdNET in Detail

### Installation
```bash
# Install from GitHub
pip install birdnet
# Or use the BirdNET-Analyzer standalone
git clone https://github.com/kahst/BirdNET-Analyzer
pip install -r requirements.txt
```

### Command-line usage
```bash
python analyze.py \
  --i /path/to/audio/ \
  --o /path/to/output/ \
  --min_conf 0.7 \
  --lat -3.5 \
  --lon -60.2 \
  --week 24 \
  --slist /path/to/species_list.txt
```

### Parameters
| Parameter | Description | Default |
|---|---|---|
| `--min_conf` | Confidence threshold | 0.1 (must increase) |
| `--lat` / `--lon` | Location for species filtering | None |
| `--week` | Week of year (1–48) for seasonal filtering | None |
| `--slist` | Restrict to species in this list | None |
| `--rtype` | Output format: table, audacity, r, csv | table |

### Interpreting Scores
- < 0.5: Very likely false positive — do not use without validation
- 0.5–0.7: Possible detection — flag for review
- 0.7–0.9: Probable detection — use with caution in analyses
- > 0.9: High confidence — generally reliable for common species

---

## Validation Protocol

To calculate regional precision and recall for BirdNET:

1. **Create validation set:** Randomly select 100–200 detections per confidence band (< 0.5, 0.5–0.7, 0.7–0.9, > 0.9).
2. **Manual verification:** Review spectrograms in Raven or Audacity; mark each as TP or FP.
3. **Calculate precision per band:**

```r
validation <- data.frame(
  confidence_band = c("<0.5", "0.5-0.7", "0.7-0.9", ">0.9"),
  n_reviewed      = c(100, 100, 100, 100),
  n_correct       = c(12, 45, 78, 94)
)
validation$precision <- validation$n_correct / validation$n_reviewed
```

4. **Apply precision as weight** in species accumulation analyses.

---

## When Manual Validation Is Mandatory

Always validate manually before using BirdNET results for:
- Species of conservation concern (IUCN threatened categories)
- First records in a region
- Rare or vagrant species
- Any species with < 20 training recordings in BirdNET training set

---

## References

- Kahl, S. et al. (2021). BirdNET: A deep learning solution for avian diversity monitoring. *Ecological Informatics*, 61, 101236. DOI: 10.1016/j.ecoinf.2021.101236
- Abrahams, C. (2021). Practical bioacoustics: Passive acoustic monitoring. *British Wildlife* 32(4), 241–249.
