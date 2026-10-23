-- ~/.config/hypr/modules/env.lua

-- Cursor
hl.env("XCURSOR_SIZE", "20")
hl.env("HYPRCURSOR_SIZE", "20")
hl.env("XCURSOR_THEME", "catppuccin-mocha-dark-cursors")
hl.env("HYPRCURSOR_THEME", "catppuccin-mocha-dark-cursors")

-- Toolkit Backend
hl.env("GTK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")

-- QT
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1.25")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- GTK
hl.env("GTK_ICON_THEME", "Papirus-Dark")
hl.env("GTK_CURSOR_THEME", "catppuccin-mocha-dark-cursors")
hl.env("GTK_APPLICATION_PREFER_DARK_THEME", "1")
hl.env("GDK_SCALE", "1")

-- Terminal
hl.env("TERMINAL", "kitty")