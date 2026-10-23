-- =========================================================
-- AUTOSTART
-- =========================================================

return function(WALLPAPER_DIR)
	hl.on("hyprland.start", function()
		-- Update D-Bus / systemd activation environment
		-- so applications inherit the current session variables.
		hl.exec_cmd(
			"dbus-update-activation-environment --systemd --all"
		)

		-- GTK theme
		hl.exec_cmd(
			"gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark"
		)

		-- Icon theme
		hl.exec_cmd(
			"gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark"
		)

		-- Cursor theme
		hl.exec_cmd(
			"gsettings set org.gnome.desktop.interface cursor-theme catppuccin-mocha-dark-cursors"
		)

		-- Start wallpaper daemon
		hl.exec_cmd(
			"sh -c 'pgrep -x awww-daemon >/dev/null || awww-daemon >/dev/null 2>&1 &'"
		)

		-- Give the daemon a moment to initialize before setting the wallpaper
		hl.exec_cmd(
			"sleep 0.5 && awww img " .. WALLPAPER_DIR .. "/wallpaper.jpg"
		)

		-- QuickShell
		hl.exec_cmd(
			"sh -c 'pgrep -x quickshell >/dev/null || quickshell >/dev/null 2>&1 &'"
		)

		-- Idle management (lock / dpms off / suspend on timers)
		hl.exec_cmd(
			"sh -c 'pgrep -x hypridle >/dev/null || hypridle >/dev/null 2>&1 &'"
		)

		-- NetworkManager tray applet
		hl.exec_cmd(
			"sh -c 'pgrep -x nm-applet >/dev/null || nm-applet --indicator >/dev/null 2>&1 &'"
		)
	end)
end
