LOG_FILE = "/tmp/veyra-install.log"
MOUNT = "/mnt"
DOTFILES_URL = "https://github.com/Frank1o3/dotfiles.git"
BTRFS_OPTS = "noatime,compress=zstd:3,space_cache=v2"

BASE_PACKAGES = [
    "base", "linux-cachyos", "linux-firmware", "cachyos-keyring", "cachyos-mirrorlist",
    "btrfs-progs", "networkmanager", "sudo", "git", "nano", "fish", "cachyos-fish-config",
    "hyprland", "hyprlock", "hypridle", "hyprshutdown", "hyprpolkitagent", "quickshell",
    "kitty", "awww","ripgrep", "unzip","strace", "7zip" "unrar", "udisks2", "sddm",
    "pipewire", "pipewire-pulse", "wireplumber", "zip", "zstd", "xdg-utils",
    "xdg-desktop-portal-hyprland", "xdg-desktop-portal-gtk", "xdg-user-dirs",
    "gnome-keyring", "nm-connection-editor", "network-manager-applet", "man-db",
    "brightnessctl", "playerctl", "thunar", "gvfs", "tumbler", "file-roller","pavucontrol",
    "adw-gtk-theme", "papirus-icon-theme", "adwaita-cursors", "man-pages", "noto-fonts",
    "ttf-jetbrains-mono-nerd", "ttf-nerd-fonts-symbols", "ttf-nerd-fonts-symbols-common",
    "qt6ct", "qt6-5compat", "rsync", "cachyos-rate-mirrors", "wl-clipboard", "grim", "slurp",
    "limine", "limine-mkinitcpio-hook", "limine-snapper-sync", "snapper", "efibootmgr",
    "cava", "inter-font", "qt5-graphicaleffects", "qt5-quickcontrols2", "bluez", "bluez-utils",
    "llvm", "cmake", "clang", "ninja","base-devel", "rustup", "mason", "neovim", "tree-sitter-cli",
    "nodejs", "npm", "python", "gdb", "lldb", "mason", "clang-tools-extra", "uv", "ty", "ruff",
    "paru", "ccache", "valgrind", "curl", "jq", "openssh", "shellcheck", "shfmt", "sqlite",
]

# XKB layout name (what Hyprland/SDDM use) -> console keymap name (what vconsole uses).
# They are NOT the same namespace: e.g. XKB "latam" is console "la-latin1".
XKB_TO_CONSOLE = {
    "us": "us", "latam": "la-latin1", "es": "es", "gb": "uk", "de": "de-latin1",
    "fr": "fr", "it": "it", "pt": "pt-latin1", "br": "br-abnt2", "ru": "ru",
    "se": "sv-latin1", "no": "no-latin1", "dk": "dk-latin1", "fi": "fi",
    "pl": "pl2", "cz": "cz-lat2", "tr": "trq", "jp": "jp106", "ca": "cf",
}

V3_FLAGS = (
    "avx", "avx2", "bmi1", "bmi2", "f16c", "fma", "abm", "movbe", "xsave",
    "cx16", "lahf_lm", "popcnt", "pni", "ssse3", "sse4_1", "sse4_2",
)
