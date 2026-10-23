source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
function fish_greeting
    echo (set_color cyan)"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo (set_color white)" Welcome back, $USER! "
    echo (set_color yellow)" 💡 Update config: "(set_color brwhite)" curl -fsSL https://raw.githubusercontent.com/Frank1o3/dotfiles/main/update.sh | sh"
    echo (set_color cyan)"━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
end