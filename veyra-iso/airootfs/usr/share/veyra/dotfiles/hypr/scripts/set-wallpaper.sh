#!/usr/bin/env sh

set -eu

WALLPAPER_DIR="$HOME/wallpapers"
SELECTED_PATH="${1:-}"

[ -z "$SELECTED_PATH" ] && {
    echo "Usage: set-wallpaper.sh <path>"
    exit 1
}

[ -f "$SELECTED_PATH" ] || {
    notify-send "Error" "Wallpaper not found: $SELECTED_PATH"
    exit 1
}

SELECTED_NAME=$(basename "$SELECTED_PATH")

# Keep a real copy as the persistent wallpaper
cp -f "$SELECTED_PATH" "$WALLPAPER_DIR/wallpaper.jpg"

if ! pgrep -x awww-daemon >/dev/null 2>&1; then
    awww-daemon & disown
    sleep 0.4
fi

awww img "$SELECTED_PATH" \
    --transition-type grow \
    --transition-pos "$(hyprctl cursorpos)" \
    --transition-duration 1.1 \
    --transition-fps 60 \
    --transition-bezier .43,1.19,1,.4

if command -v wallust >/dev/null 2>&1; then
    wallust run "$SELECTED_PATH"
else
    printf 'wallust is not installed; wallpaper changed without regenerating the color palette.\n' >&2
fi

notify-send "🎨 Applied" "$SELECTED_NAME"
