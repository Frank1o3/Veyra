"""Post-install extras: Rivet package manager and the self-deleting first-boot AUR service."""
from __future__ import annotations

import os
from pathlib import Path

from .config import AUR_PACKAGES, MOUNT
from .shell import chroot, put, run, target
from .ui import step

FIRSTBOOT_SCRIPT_PATH = "/usr/local/lib/veyra/firstboot-aur.sh"
FIRSTBOOT_MARKER = "/var/lib/veyra/firstboot-pending"

ONLINE_SCRIPT = """#!/bin/sh
for _ in $(seq 1 12); do
    curl -fsI --max-time 5 https://aur.archlinux.org >/dev/null 2>&1 && exit 0
    sleep 5
done
exit 1
"""

DISPATCHER = """#!/bin/sh
case "$2" in
    up|connectivity-change|dhcp4-change) ;;
    *) exit 0 ;;
esac
[ -e /var/lib/veyra/firstboot-pending ] || exit 0
systemctl start --no-block veyra-firstboot.service
"""

FIRSTBOOT_SCRIPT = r"""#!/usr/bin/env bash
set -uo pipefail

MARKER=/var/lib/veyra/firstboot-pending
USER_NAME="$(cat "$MARKER")"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
SUDOERS=/etc/sudoers.d/99-veyra-firstboot
PACKAGES=(@PACKAGES@)

cleanup_sudo() { rm -f "$SUDOERS"; }
trap cleanup_sudo EXIT

run_user() { runuser -u "$USER_NAME" -- env HOME="$USER_HOME" "$@"; }

# --- Config that setup.sh skips in --config-only mode (no network needed) ---
echo "Setting up default applications..."
run_user xdg-mime default thunar.desktop inode/directory application/x-directory || true
run_user xdg-mime default code.desktop text/plain text/x-shellscript text/x-python || true

echo "Configuring Git..."
run_user git config --global core.editor "code --wait" || true
run_user git config --global merge.tool vscode || true
run_user git config --global mergetool.vscode.cmd 'code --wait "$MERGED"' || true

# --- Network part ---
for _ in $(seq 1 36); do
    ping -c1 -W2 aur.archlinux.org >/dev/null 2>&1 && break
    sleep 5
done
ping -c1 -W2 aur.archlinux.org >/dev/null 2>&1 || { echo "No network; will retry next boot"; exit 1; }

echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS"
chmod 440 "$SUDOERS"

run_user rustup default stable || exit 1
run_user paru -Syu --needed --noconfirm --skipreview "${PACKAGES[@]}" || exit 1

if [ -f "$USER_HOME/wallpapers/wallpaper.jpg" ]; then
    run_user wallust run "$USER_HOME/wallpapers/wallpaper.jpg" || true
fi

cleanup_sudo
systemctl disable veyra-firstboot.service
rm -f /etc/systemd/system/veyra-firstboot.service "$0" "$MARKER" \
    /usr/local/lib/veyra/firstboot-online.sh \
    /etc/NetworkManager/dispatcher.d/90-veyra-firstboot
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
    put("/usr/local/lib/veyra/firstboot-online.sh", ONLINE_SCRIPT, 0o755)
    put("/etc/NetworkManager/dispatcher.d/90-veyra-firstboot", DISPATCHER, 0o755)
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