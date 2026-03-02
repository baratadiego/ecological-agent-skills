# Acoustic Indices Reference

## Index Overview Table

| Index | Full name | What it measures | Scale | R package | Sensitive to noise? |
|---|---|---|---|---|---|
| ACI | Acoustic Complexity Index | Temporal variation in spectral energy | 0–∞ (relative) | soundecology | Medium |
| BI | Bioacoustic Index | Intensity in biological frequency band (2–8 kHz) | 0–∞ (dB·Hz) | soundecology | Low |
| NDSI | Normalized Difference Soundscape Index | Ratio biophony/geophony | −1 to +1 | soundecology | High |
| H | Acoustic Entropy | Spectral and temporal entropy | 0–1 | soundecology | Medium |
| ADI | Acoustic Diversity Index | Shannon diversity of frequency bins | 0–∞ | soundecology | Medium |
| AEI | Acoustic Evenness Index | Gini coefficient of frequency bins | 0–1 | soundecology | Medium |

---

## Index Formulas and Interpretation

### ACI (Acoustic Complexity Index)
Calculates the sum of absolute differences in spectral amplitudes across time steps within each frequency bin. High ACI = high temporal variation = complex biological signal.

**Caution:** Heavy rain and wind also produce high ACI. Correlate with NDSI to separate biological from abiotic signals.

### NDSI (Normalized Difference Soundscape Index)
NDSI = (biophony − geophony) / (biophony + geophony)
- Biophony band: 2–8 kHz (default)
- Geophony band: 0.2–1 kHz (default)
- NDSI > 0 → biophony dominant; NDSI < 0 → geophony/anthrophony dominant

### H (Acoustic Entropy)
H = Ht × Hf where Ht = temporal entropy, Hf = spectral entropy.
Range 0–1; values close to 1 indicate highly variable, complex soundscape.

---

## Recommended Index Combinations

| Research question | Primary index | Supporting index |
|---|---|---|
| Overall acoustic biodiversity | H or ADI | ACI |
| Urbanisation gradient | NDSI | BI |
| Diel soundscape pattern | ACI heatmap | NDSI by hour |
| Disturbance recovery | ACI trend | H trend |
| Biophony vs. anthrophony | NDSI | BI |

---

## Computing Indices in R

```r
suppressPackageStartupMessages(library(soundecology))
suppressPackageStartupMessages(library(tuneR))

wav_file <- readWave("recording.wav")

# ACI (min_freq and max_freq in Hz)
aci <- acoustic_complexity(wav_file, min_freq = 200, max_freq = 10000, j = 5)
cat("ACI:", aci$AciTotAll_left)

# NDSI
ndsi_result <- ndsi(wav_file, fft_w = 1024, anthro_min = 1000, anthro_max = 2000,
                    bio_min = 2000, bio_max = 8000)
cat("NDSI:", ndsi_result$ndsi_left)

# Full suite
multi <- multiple_sounds(
  directory   = "audio_dir/",
  resultfile  = "outputs/acoustic_indices.csv",
  soundindex  = "soundecology",
  min_freq    = 200,
  max_freq    = 10000,
  max_duration = 60
)
```

---

## Sensitivity to Anthropogenic Noise by Index

| Noise source | ACI | NDSI | H | ADI |
|---|---|---|---|---|
| Road traffic (low-freq) | Low | High | Medium | Low |
| Aircraft | Medium | High | Medium | Medium |
| Wind | High | Medium | Low | Low |
| Rain | High | Low | Low | Low |
| Human voices | Medium | High | Medium | Medium |

---

## References

- Villanueva-Rivera, L.J. et al. (2011). A primer of acoustic analysis for landscape ecologists. *Landscape Ecology*, 26(9), 1233–1246. DOI: 10.1007/s10980-011-9636-9
- Pijanowski, B.C. et al. (2011). Soundscape ecology: the science of sound in the landscape. *BioScience*, 61(3), 203–216. DOI: 10.1525/bio.2011.61.3.6
- Pieretti, N. et al. (2011). A new methodology to infer the singing activity of an avian community: the Acoustic Complexity Index (ACI). *Ecological Indicators*, 11(3), 868–873. DOI: 10.1016/j.ecolind.2010.11.005
