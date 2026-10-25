"""Post-install extras: Rivet package manager and the self-deleting first-boot AUR service."""
from __future__ import annotations

import os
from pathlib import Path

from config import AUR_PACKAGES, MOUNT
from shell import chroot, put, run, target
from ui import step

FIRSTBOOT_SCRIPT_PATH = "/usr/local/lib/veyra/firstboot-aur.sh"
FIRSTBOOT_MARKER = "/var/lib/veyra/firstboot-pending"

# paru refuses to run as root and calls `sudo pacman`, so the script drops to
# the user and grants a temporary NOPASSWD rule that is always removed.
# Deletes itself only after success; on failure it retries next boot.
FIRSTBOOT_SCRIPT = r"""#!/usr/bin/env bash
set -uo pipefail

MARKER=/var/lib/veyra/firstboot-pending
USER_NAME="$(cat "$MARKER")"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
SUDOERS=/etc/sudoers.d/99-veyra-firstboot
PACKAGES=(@PACKAGES@)

cleanup_sudo() { rm -f "$SUDOERS"; }
trap cleanup_sudo EXIT

for _ in $(seq 1 36); do
    ping -c1 -W2 aur.archlinux.org >/dev/null 2>&1 && break
    sleep 5
done
ping -c1 -W2 aur.archlinux.org >/dev/null 2>&1 || { echo "No network; will retry next boot"; exit 1; }

echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS"
chmod 440 "$SUDOERS"

run_user() { runuser -u "$USER_NAME" -- env HOME="$USER_HOME" "$@"; }

# wallust-git builds with cargo; rustup has no toolchain until one is chosen.
run_user rustup default stable || exit 1
run_user paru -Syu --needed --noconfirm --skipreview "${PACKAGES[@]}" || exit 1

if [ -f "$USER_HOME/wallpapers/wallpaper.jpg" ]; then
    run_user wallust run "$USER_HOME/wallpapers/wallpaper.jpg" || true
fi

cleanup_sudo
systemctl disable veyra-firstboot.service
rm -f /etc/systemd/system/veyra-firstboot.service "$0" "$MARKER"
systemctl daemon-reload
exit 0
"""

FIRSTBOOT_UNIT = """[Unit]
Description=Veyra first-boot AUR package install
ConditionPathExists=/var/lib/veyra/firstboot-pending
Wants=network-online.target
After=network-online.target NetworkManager-wait-online.service

[Service]
Type=oneshot
ExecStart=/usr/local/lib/veyra/firstboot-aur.sh
TimeoutStartSec=infinity

[Install]
WantedBy=multi-user.target
"""


def install_firstboot(cfg: dict) -> None:
    step("First-boot AUR service")
    script = FIRSTBOOT_SCRIPT.replace("@PACKAGES@", " ".join(AUR_PACKAGES))
    put(FIRSTBOOT_SCRIPT_PATH, script, 0o755)
    put("/etc/systemd/system/veyra-firstboot.service", FIRSTBOOT_UNIT)
    put(FIRSTBOOT_MARKER, cfg["username"] + "\n")
    chroot("systemctl", "enable", "veyra-firstboot.service")


def install_rivet(cfg: dict) -> None:
    if not os.access("/usr/local/bin/rivet", os.X_OK):
        return
    step("Rivet package manager")
    run(["install", "-Dm755", "/usr/local/bin/rivet", f"{MOUNT}/usr/local/bin/rivet"])
    if Path("/usr/share/rivet").is_dir():
        target("/usr/share/rivet").mkdir(parents=True, exist_ok=True)
        run(["cp", "-a", "/usr/share/rivet/.", f"{MOUNT}/usr/share/rivet/"])
    chroot("rivet", "init", "--system", check=False)
    chroot("sudo", "-u", cfg["username"], "rivet", "init", check=False)