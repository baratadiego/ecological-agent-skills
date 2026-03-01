#!/usr/bin/env python3
"""
generate_file_manifest.py
Generate SHA256 checksums for all files in a directory and write a manifest.
Usage: python generate_file_manifest.py <directory> [output_file]
"""
import sys, hashlib
from pathlib import Path

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()

def main():
    target_dir  = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("outputs")
    output_file = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("logs/file_manifest.md")
    output_file.parent.mkdir(parents=True, exist_ok=True)

    files = sorted(f for f in target_dir.rglob("*") if f.is_file())
    lines = [
        "# File Manifest",
        f"Directory: `{target_dir}`",
        f"Files: {len(files)}",
        "",
        "| File | Size (KB) | SHA256 |",
        "|------|----------|--------|",
    ]
    for f in files:
        size_kb = round(f.stat().st_size / 1024, 2)
        checksum = sha256(f)
        rel = f.relative_to(target_dir)
        lines.append(f"| `{rel}` | {size_kb} | `{checksum[:16]}...` |")

    output_file.write_text("\n".join(lines))
    print(f"Manifest written: {output_file} ({len(files)} files)")

if __name__ == "__main__":
    main()
