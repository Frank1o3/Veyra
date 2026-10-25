#!/usr/bin/env bash
set -uo pipefail

MARKER=/var/lib/veyra/firstboot-pending
USER_NAME="$(cat "$MARKER")"
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"
SUDOERS=/etc/sudoers.d/99-veyra-firstboot
PACKAGES=(wallust-git catppuccin-cursors-mocha jdk25-temurin)   # verify the Temurin name

cleanup_sudo() { rm -f "$SUDOERS"; }
trap cleanup_sudo EXIT

# Wait for network (up to ~3 min)
for _ in $(seq 1 36); do
    ping -c1 -W2 aur.archlinux.org >/dev/null 2>&1 && break
    sleep 5
done
ping -c1 -W2 aur.archlinux.org >/dev/null 2>&1 || { echo "No network; will retry next boot"; exit 1; }

# Temporary passwordless sudo so paru can call pacman unattended
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS"
chmod 440 "$SUDOERS"

run_user() { runuser -u "$USER_NAME" -- env HOME="$USER_HOME" "$@"; }

# wallust-git needs a Rust toolchain
run_user rustup default stable || exit 1

run_user paru -Syu --needed --noconfirm --skipreview "${PACKAGES[@]}" || exit 1

# Generate the first palette so colors.conf / colors.json / hypr colors exist
if [ -f "$USER_HOME/wallpapers/wallpaper.jpg" ]; then
    run_user wallust run "$USER_HOME/wallpapers/wallpaper.jpg" || true
fi

# Success: remove everything this service ever installed
cleanup_sudo
systemctl disable veyra-firstboot.service
rm -f /etc/systemd/system/veyra-firstboot.service \
      /usr/local/lib/veyra/firstboot-aur.sh \
      "$MARKER"
systemctl daemon-reload
exit 0