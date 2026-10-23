#!/usr/bin/env python3
"""
Syncs the current wallust-generated wallpaper/colors into the SDDM theme.
Runs as root, triggered by a systemd path unit watching the live wallpaper.

Usage: sddm-theme-sync.py <username>
"""
import json
import pwd
import shutil
import sys
from pathlib import Path


def main():
    if len(sys.argv) < 2:
        print("Usage: sddm-theme-sync.py <username>")
        sys.exit(1)

    username = sys.argv[1]
    try:
        user_home = Path(pwd.getpwnam(username).pw_dir)
    except KeyError:
        print(f"Unknown user: {username}")
        sys.exit(1)

    colors_json = user_home / ".config/quickshell/colors.json"
    wallpaper = user_home / "wallpapers/wallpaper.jpg"

    theme_dir = Path("/usr/share/sddm/themes/quickshell-glass")
    bg_dest = theme_dir / "backgrounds/current.jpg"
    conf_dest = theme_dir / "theme.conf.user"

    if not colors_json.exists() or not wallpaper.exists():
        print("colors.json or wallpaper not found, skipping")
        return

    data = json.loads(colors_json.read_text())

    bg_dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(wallpaper, bg_dest)
    bg_dest.chmod(0o644)

    colors = data.get("colors", [])
    accent = colors[4] if len(colors) > 4 else data.get("foreground", "#cdd6f4")
    border = colors[5] if len(colors) > 5 else data.get("background", "#1e1e2e")

    conf = f"""[General]
background=backgrounds/current.jpg
colorBackground={data.get("background", "#1e1e2e")}
colorForeground={data.get("foreground", "#cdd6f4")}
colorAccent={accent}
colorBorder={border}
"""
    conf_dest.write_text(conf)
    conf_dest.chmod(0o644)
    print("SDDM theme synced")


if __name__ == "__main__":
    main()