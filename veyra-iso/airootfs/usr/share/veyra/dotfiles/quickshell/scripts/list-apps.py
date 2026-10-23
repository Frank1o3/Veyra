#!/usr/bin/env python3
import json
from pathlib import Path

APP_DIRS = [
    "/usr/share/applications",
    str(Path.home() / ".local/share/applications"),
    "/var/lib/flatpak/exports/share/applications",
    str(Path.home() / ".local/share/flatpak/exports/share/applications"),
]

FIELD_CODES = ("%f", "%F", "%u", "%U", "%d", "%D", "%n", "%N", "%i", "%c", "%k", "%v", "%m")


def parse_desktop(path):
    name = exec_ = icon = None
    nodisplay = False
    terminal = False

    try:
        with open(path, "r", errors="ignore") as f:
            in_entry = False
            for line in f:
                line = line.strip()
                if line == "[Desktop Entry]":
                    in_entry = True
                    continue
                if line.startswith("[") and line != "[Desktop Entry]":
                    in_entry = False
                    continue
                if not in_entry:
                    continue

                if line.startswith("Name=") and name is None:
                    name = line.split("=", 1)[1]
                elif line.startswith("Exec=") and exec_ is None:
                    exec_ = line.split("=", 1)[1]
                elif line.startswith("Icon=") and icon is None:
                    icon = line.split("=", 1)[1]
                elif line.startswith("NoDisplay="):
                    nodisplay = line.split("=", 1)[1].strip().lower() == "true"
                elif line.startswith("Terminal="):
                    terminal = line.split("=", 1)[1].strip().lower() == "true"
    except Exception:
        return None

    if not name or not exec_ or nodisplay:
        return None

    for code in FIELD_CODES:
        exec_ = exec_.replace(code, "")
    exec_ = " ".join(exec_.split())

    if terminal:
        exec_ = f"kitty -e {exec_}"

    return {"name": name, "exec": exec_, "icon": icon or ""}


def main():
    seen = {}
    for d in APP_DIRS:
        p = Path(d)
        if not p.is_dir():
            continue
        for f in p.glob("*.desktop"):
            entry = parse_desktop(f)
            if entry:
                seen[entry["name"]] = entry

    apps = sorted(seen.values(), key=lambda a: a["name"].lower())
    print(json.dumps(apps))


if __name__ == "__main__":
    main()