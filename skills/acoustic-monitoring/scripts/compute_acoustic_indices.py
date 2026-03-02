"""
Compute acoustic indices for passive acoustic monitoring using librosa and soundfile.

Usage:
    python compute_acoustic_indices.py <audio_dir> <output_dir>
        [--resolution_min 1] [--freq_min 0] [--freq_max 22050]

Implements:
    ACI  — Acoustic Complexity Index (Pieretti et al. 2011)
    BI   — Bioacoustic Index (Boelman et al. 2007), approximated
    NDSI — Normalized Difference Soundscape Index (Kasten et al. 2012)
    Ht   — Temporal entropy (Sueur et al. 2008)
    Hf   — Spectral entropy (Sueur et al. 2008)
    H    — Total entropy (Ht × Hf)

Outputs:
    acoustic_indices_timeseries.csv  — per-file indices with timestamps
    indices_summary.csv              — mean ± SD by hour of day
    soundscape_plot.png              — heatmap (date × hour, coloured by ACI)
"""

import sys
import os
import re
import csv
import math
import argparse
from pathlib import Path
from datetime import datetime

try:
    import numpy as np
    import librosa
    import soundfile as sf
except ImportError as e:
    print(f"[ERROR] Missing dependency: {e}")
    print("Install with: pip install librosa soundfile numpy")
    sys.exit(1)


def parse_args():
    parser = argparse.ArgumentParser(
        description="Compute acoustic indices for PAM recordings"
    )
    parser.add_argument("audio_dir",  help="Directory containing .wav/.flac files")
    parser.add_argument("output_dir", help="Directory for output files")
    parser.add_argument("--resolution_min", type=int, default=1,
                        help="Time aggregation resolution in minutes (default: 1)")
    parser.add_argument("--freq_min", type=float, default=0,
                        help="Minimum frequency in Hz (default: 0)")
    parser.add_argument("--freq_max", type=float, default=22050,
                        help="Maximum frequency in Hz (default: 22050)")
    # Fallback positional for simple invocation
    if len(sys.argv) >= 3 and not sys.argv[1].startswith("--"):
        return parser.parse_args()
    return parser.parse_args()


def parse_timestamp(fname: str):
    """Extract datetime from common logger filename patterns."""
    patterns = [r"(\d{8})[_$T](\d{6})"]
    for pat in patterns:
        m = re.search(pat, fname)
        if m:
            try:
                return datetime.strptime(m.group(1) + m.group(2), "%Y%m%d%H%M%S")
            except ValueError:
                pass
    return None


# ── Index computation functions ─────────────────────────────────────────────

def compute_aci(y: np.ndarray, sr: int, n_fft: int = 1024, hop: int = 512,
                freq_min: float = 0, freq_max: float = 22050) -> float:
    """Acoustic Complexity Index (Pieretti et al. 2011).

    ACI = sum(|D_k|) / sum(I_k)  per frequency bin, summed across bins.
    D_k = absolute difference between adjacent time frames in bin k.
    I_k = sum of intensities in bin k.
    """
    S = np.abs(librosa.stft(y, n_fft=n_fft, hop_length=hop))
    freqs = librosa.fft_frequencies(sr=sr, n_fft=n_fft)
    mask  = (freqs >= freq_min) & (freqs <= freq_max)
    S = S[mask, :]
    if S.shape[1] < 2:
        return float("nan")
    diffs  = np.abs(np.diff(S, axis=1))
    totals = np.sum(S[:, :-1], axis=1)
    totals[totals == 0] = np.finfo(float).eps
    aci = float(np.sum(np.sum(diffs, axis=1) / totals))
    return aci


def compute_bi(y: np.ndarray, sr: int, n_fft: int = 1024, hop: int = 512,
               bio_min: float = 2000, bio_max: float = 8000) -> float:
    """Bioacoustic Index — area under mean spectrum in biophony band (2–8 kHz).
    Approximation of Boelman et al. (2007).
    """
    S   = np.abs(librosa.stft(y, n_fft=n_fft, hop_length=hop))
    freqs = librosa.fft_frequencies(sr=sr, n_fft=n_fft)
    mask = (freqs >= bio_min) & (freqs <= min(bio_max, sr / 2))
    S_bio = S[mask, :]
    if S_bio.size == 0:
        return float("nan")
    mean_spec = np.mean(S_bio, axis=1)
    mean_db   = 20 * np.log10(mean_spec + np.finfo(float).eps)
    mean_db   = np.clip(mean_db - mean_db.min(), 0, None)
    bi = float(np.trapz(mean_db))
    return bi


def compute_ndsi(y: np.ndarray, sr: int, n_fft: int = 1024, hop: int = 512,
                 anthro_min: float = 200, anthro_max: float = 2000,
                 bio_min: float = 2000, bio_max: float = 8000) -> float:
    """Normalized Difference Soundscape Index (Kasten et al. 2012).
    NDSI = (biophony - anthrophony) / (biophony + anthrophony)
    """
    S     = np.abs(librosa.stft(y, n_fft=n_fft, hop_length=hop)) ** 2
    freqs = librosa.fft_frequencies(sr=sr, n_fft=n_fft)
    anthro_mask = (freqs >= anthro_min) & (freqs < anthro_max)
    bio_mask    = (freqs >= bio_min)    & (freqs <= min(bio_max, sr / 2))
    anthro = float(np.sum(S[anthro_mask, :]))
    bio    = float(np.sum(S[bio_mask, :]))
    total  = anthro + bio
    if total == 0:
        return float("nan")
    return (bio - anthro) / total


def compute_entropy(y: np.ndarray, sr: int, n_fft: int = 1024,
                    hop: int = 512) -> tuple[float, float, float]:
    """Temporal entropy (Ht), spectral entropy (Hf), total entropy H = Ht × Hf.
    After Sueur et al. (2008).
    """
    # Temporal entropy
    env = np.abs(y)
    env_sum = env.sum()
    if env_sum == 0:
        return float("nan"), float("nan"), float("nan")
    env_norm = env / env_sum
    env_norm[env_norm == 0] = np.finfo(float).eps
    Ht = float(-np.sum(env_norm * np.log(env_norm)) / math.log(len(env_norm)))

    # Spectral entropy
    S   = np.abs(librosa.stft(y, n_fft=n_fft, hop_length=hop))
    mean_spec = np.mean(S, axis=1)
    sp_sum = mean_spec.sum()
    if sp_sum == 0:
        return Ht, float("nan"), float("nan")
    sp_norm = mean_spec / sp_sum
    sp_norm[sp_norm == 0] = np.finfo(float).eps
    Hf = float(-np.sum(sp_norm * np.log(sp_norm)) / math.log(len(sp_norm)))

    H = Ht * Hf
    return Ht, Hf, H


def process_file(fpath: Path, freq_min: float, freq_max: float) -> dict | None:
    """Load audio and compute all indices. Returns dict or None on error."""
    try:
        y, sr = librosa.load(str(fpath), sr=None, mono=True)
    except Exception as e:
        print(f"  [WARN] Cannot load {fpath.name}: {e}")
        return None

    freq_max_use = min(freq_max, sr / 2)
    n_fft = 1024
    hop   = 512

    aci  = compute_aci(y, sr, n_fft, hop, freq_min, freq_max_use)
    bi   = compute_bi(y, sr, n_fft, hop,
                      bio_min=max(freq_min, 2000),
                      bio_max=min(freq_max_use, 8000))
    ndsi = compute_ndsi(y, sr, n_fft, hop,
                        anthro_min=max(freq_min, 200),
                        anthro_max=2000,
                        bio_min=2000,
                        bio_max=min(freq_max_use, 8000))
    Ht, Hf, H = compute_entropy(y, sr, n_fft, hop)

    ts = parse_timestamp(fpath.name)
    return {
        "file":        fpath.name,
        "datetime":    ts.strftime("%Y-%m-%d %H:%M:%S") if ts else "",
        "date":        ts.strftime("%Y-%m-%d") if ts else "",
        "hour":        ts.hour if ts else -1,
        "ACI":         round(aci,  2),
        "BI":          round(bi,   2),
        "NDSI":        round(ndsi, 4),
        "Ht":          round(Ht,   4),
        "Hf":          round(Hf,   4),
        "H":           round(H,    4),
    }


def write_summary(rows: list[dict], output_dir: Path) -> None:
    """Write per-hour summary (mean ± SD) for each index."""
    from collections import defaultdict
    hour_data = defaultdict(lambda: {k: [] for k in ("ACI", "BI", "NDSI", "H")})
    for r in rows:
        if r["hour"] >= 0:
            for idx in ("ACI", "BI", "NDSI", "H"):
                v = r[idx]
                if not math.isnan(v):
                    hour_data[r["hour"]][idx].append(v)

    path = output_dir / "indices_summary.csv"
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["hour", "ACI_mean", "ACI_sd", "BI_mean", "BI_sd",
                         "NDSI_mean", "NDSI_sd", "H_mean", "H_sd", "n"])
        for h in sorted(hour_data.keys()):
            row = [h]
            for idx in ("ACI", "BI", "NDSI", "H"):
                vals = hour_data[h][idx]
                if vals:
                    row += [round(sum(vals) / len(vals), 3),
                            round(math.sqrt(sum((v - sum(vals)/len(vals))**2
                                               for v in vals) / max(len(vals)-1, 1)), 3)]
                else:
                    row += ["", ""]
            row.append(sum(len(hour_data[h][k]) for k in ("ACI",)) // 1)  # n per hour
            writer.writerow(row)
    print(f"Summary written: {path}")


def write_heatmap(rows: list[dict], output_dir: Path) -> None:
    """Produce a simple heatmap PNG of ACI by date × hour."""
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("  [SKIP] matplotlib not available; skipping heatmap.")
        return

    dated = [r for r in rows if r["date"] and r["hour"] >= 0]
    if not dated:
        return

    dates = sorted(set(r["date"] for r in dated))
    hours = list(range(24))

    from collections import defaultdict
    grid = defaultdict(lambda: defaultdict(list))
    for r in dated:
        if not math.isnan(r["ACI"]):
            grid[r["date"]][r["hour"]].append(r["ACI"])

    matrix = np.full((len(dates), 24), np.nan)
    for i, d in enumerate(dates):
        for h in hours:
            vals = grid[d][h]
            if vals:
                matrix[i, h] = sum(vals) / len(vals)

    fig, ax = plt.subplots(figsize=(12, max(3, len(dates) * 0.35 + 2)))
    im = ax.imshow(matrix, aspect="auto", cmap="magma",
                   interpolation="nearest",
                   extent=[-0.5, 23.5, len(dates) - 0.5, -0.5])
    ax.set_xlabel("Hour of day")
    ax.set_yticks(range(len(dates)))
    ax.set_yticklabels(dates, fontsize=7)
    ax.set_title("Acoustic Complexity Index (ACI) — date × hour heatmap")
    plt.colorbar(im, ax=ax, label="ACI")
    plt.tight_layout()
    path = output_dir / "soundscape_plot.png"
    fig.savefig(path, dpi=150)
    plt.close(fig)
    print(f"Heatmap saved: {path}")


def main():
    args = parse_args()
    audio_dir  = Path(args.audio_dir)
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    if not audio_dir.is_dir():
        print(f"[ERROR] Not a directory: {audio_dir}")
        sys.exit(1)

    files = sorted(
        p for ext in ("*.wav", "*.WAV", "*.flac", "*.FLAC")
        for p in audio_dir.rglob(ext)
    )
    if not files:
        print(f"[ERROR] No audio files found in {audio_dir}")
        sys.exit(1)

    print(f"Found {len(files)} audio files.")
    rows = []
    for i, fpath in enumerate(files, 1):
        print(f"  [{i}/{len(files)}] {fpath.name}")
        result = process_file(fpath, args.freq_min, args.freq_max)
        if result:
            rows.append(result)

    if not rows:
        print("[ERROR] No files processed successfully.")
        sys.exit(1)

    # Write timeseries
    ts_path = output_dir / "acoustic_indices_timeseries.csv"
    fieldnames = ["file", "datetime", "date", "hour",
                  "ACI", "BI", "NDSI", "Ht", "Hf", "H"]
    with open(ts_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"\nTimeseries written: {ts_path} ({len(rows)} rows)")

    write_summary(rows, output_dir)
    write_heatmap(rows, output_dir)

    print("\nAcoustic index computation complete.")


if __name__ == "__main__":
    main()
