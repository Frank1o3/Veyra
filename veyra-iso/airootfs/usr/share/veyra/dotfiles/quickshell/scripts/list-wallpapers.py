#!/usr/bin/env python3
import json
from pathlib import Path

WALLPAPER_DIR = Path.home() / "wallpapers"
EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def main():
    entries = []
    if WALLPAPER_DIR.is_dir():
        for f in sorted(WALLPAPER_DIR.iterdir()):
            if f.is_file() and f.suffix.lower() in EXTS and f.name != "wallpaper.jpg":
                entries.append({"name": f.stem, "path": str(f)})
    print(json.dumps(entries))


if __name__ == "__main__":
    main()