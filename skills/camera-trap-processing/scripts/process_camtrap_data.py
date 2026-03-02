"""Process camera trap detection records from CSV output of camtrapR.
Usage: python process_camtrap_data.py <record_table_csv> <output_dir> [species_name]

Reads a record_table.csv produced by camtrapR's recordTable() function.
Computes descriptive statistics per species and camera station.
Generates a detection timeline plot.
Does NOT require camtrapR — works with the CSV output only.

Arguments:
    record_table_csv : path to record_table.csv from camtrapR
    output_dir       : directory for output files
    species_name     : optional; filter to a single species
"""
import sys
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from pathlib import Path


def load_records(csv_path: str) -> pd.DataFrame:
    df = pd.read_csv(csv_path, parse_dates=["DateTimeOriginal"])
    required = {"Station", "Species", "DateTimeOriginal"}
    missing = required - set(df.columns)
    if missing:
        raise ValueError(f"Record table missing required columns: {missing}")
    return df


def species_summary(df: pd.DataFrame) -> pd.DataFrame:
    summary = (
        df.groupby("Species")
        .agg(
            n_events=("Species", "count"),
            n_stations=("Station", "nunique"),
            first_detection=("DateTimeOriginal", "min"),
            last_detection=("DateTimeOriginal", "max"),
        )
        .reset_index()
    )
    summary["rai_per_100_trapnights"] = np.nan  # requires cam_op; computed externally
    return summary


def station_summary(df: pd.DataFrame) -> pd.DataFrame:
    return (
        df.groupby("Station")
        .agg(
            n_events=("Species", "count"),
            n_species=("Species", "nunique"),
            first_detection=("DateTimeOriginal", "min"),
            last_detection=("DateTimeOriginal", "max"),
        )
        .reset_index()
    )


def plot_detection_timeline(df: pd.DataFrame, output_path: Path) -> None:
    """Timeline of detections per species over time."""
    species_list = df["Species"].unique()
    species_codes = {sp: i for i, sp in enumerate(sorted(species_list))}

    fig, ax = plt.subplots(figsize=(12, max(4, len(species_list) * 0.6)))
    for _, row in df.iterrows():
        y = species_codes[row["Species"]]
        ax.plot(row["DateTimeOriginal"], y, "|", color="steelblue",
                markersize=4, alpha=0.5)

    ax.set_yticks(list(species_codes.values()))
    ax.set_yticklabels([s.replace("_", " ") for s in species_codes.keys()],
                       fontsize=8)
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %Y"))
    fig.autofmt_xdate()
    ax.set_xlabel("Date")
    ax.set_title("Camera Trap Detection Timeline")
    ax.grid(axis="x", linestyle="--", alpha=0.4)
    plt.tight_layout()
    fig.savefig(output_path, dpi=120)
    plt.close(fig)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    record_csv = sys.argv[1]
    output_dir = Path(sys.argv[2])
    species_filter = sys.argv[3] if len(sys.argv) >= 4 else None

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading records from: {record_csv}")
    df = load_records(record_csv)
    print(f"  Total records: {len(df)}, Species: {df['Species'].nunique()}")

    if species_filter:
        df = df[df["Species"] == species_filter]
        print(f"  Filtered to '{species_filter}': {len(df)} records")

    sp_sum = species_summary(df)
    st_sum = station_summary(df)

    sp_sum.to_csv(output_dir / "species_summary.csv", index=False)
    st_sum.to_csv(output_dir / "station_summary.csv", index=False)

    low_events = sp_sum[sp_sum["n_events"] < 10]["Species"].tolist()
    if low_events:
        print(f"  WARNING: Species with < 10 events (RAI only): {low_events}")

    plot_detection_timeline(df, output_dir / "detection_timeline.png")

    print(f"Done. Outputs written to: {output_dir}")
    print(f"  species_summary.csv: {len(sp_sum)} species")
    print(f"  station_summary.csv: {len(st_sum)} stations")


if __name__ == "__main__":
    main()
