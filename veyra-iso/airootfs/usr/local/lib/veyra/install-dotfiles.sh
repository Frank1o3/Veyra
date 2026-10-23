#!/usr/bin/env bash
set -Eeuo pipefail

USERNAME=${1:?usage: install-dotfiles.sh USERNAME}
USER_HOME=$(getent passwd "$USERNAME" | cut -d: -f6)
[[ -n "$USER_HOME" && -d "$USER_HOME" ]] || {
    printf 'Cannot find home directory for %s\n' "$USERNAME" >&2
    exit 1
}

DOTFILES=/usr/share/veyra/dotfiles
[[ -d "$DOTFILES" ]] || {
    printf 'Bundled dotfiles are missing from %s\n' "$DOTFILES" >&2
    exit 1
}

printf 'Installing Veyra desktop configuration for %s...\n' "$USERNAME"
install -d -o "$USERNAME" -g "$USERNAME" "$USER_HOME/.config" "$USER_HOME/wallpapers"
for config in hypr quickshell kitty fish wallust; do
    install -d -o "$USERNAME" -g "$USERNAME" "$USER_HOME/.config/$config"
    cp -a "$DOTFILES/$config/." "$USER_HOME/.config/$config/"
done
cp -a "$DOTFILES/wallpapers/." "$USER_HOME/wallpapers/"
if [[ ! -e "$USER_HOME/wallpapers/wallpaper.jpg" ]]; then
    install -m644 "$DOTFILES/wallpapers/night-sky.jpg" "$USER_HOME/wallpapers/wallpaper.jpg"
fi
chmod +x "$USER_HOME/.config/hypr/scripts/"*.sh \
    "$USER_HOME/.config/hypr/scripts/emoticon.py" \
    "$USER_HOME/.config/quickshell/scripts/"*.sh
chown -R "$USERNAME:$USERNAME" "$USER_HOME/.config" "$USER_HOME/wallpapers"

printf 'Installing the Quickshell SDDM theme...\n'
install -d /usr/share/sddm/themes/quickshell-glass/backgrounds /etc/sddm.conf.d
cp -a "$DOTFILES/sddm/theme/." /usr/share/sddm/themes/quickshell-glass/
install -m644 "$USER_HOME/wallpapers/wallpaper.jpg" \
    /usr/share/sddm/themes/quickshell-glass/backgrounds/default.jpg
cat > /etc/sddm.conf.d/theme.conf <<'EOF'
[Theme]
Current=quickshell-glass
EOF

install -Dm755 "$DOTFILES/sddm/sddm-theme-sync.py" \
    /usr/local/bin/sddm-theme-sync.py
sed "s|{USERNAME}|$USERNAME|g" "$DOTFILES/sddm/sddm-theme-sync.service" \
    > /etc/systemd/system/sddm-theme-sync.service
sed "s|{HOME}|$USER_HOME|g" "$DOTFILES/sddm/sddm-theme-sync.path" \
    > /etc/systemd/system/sddm-theme-sync.path
systemctl enable sddm sddm-theme-sync.path
systemctl set-default graphical.target

printf 'Desktop configuration installed.\n'
