-- =========================================================
-- ~/.config/hypr/keybinds.lua
-- =========================================================

local HOME                 = os.getenv("HOME") or "/home/default"
local CONFIG_DIR           = HOME .. "/.config/hypr"

-- =========================================================
-- PROGRAMS
-- =========================================================

local terminal             = "kitty"
local ide                  = "code"
local browser              = "xdg-open https://google.com"
local fileManager          = "xdg-open " .. HOME

local mainMod              = "SUPER"

-- =========================================================
-- SCRIPTS
-- =========================================================

local script_power         = CONFIG_DIR .. "/scripts/power-menu.sh"
local script_games         = CONFIG_DIR .. "/scripts/wofi-games.sh"
local script_audio         = CONFIG_DIR .. "/scripts/toggle-audio.sh"
local script_emoticon      = CONFIG_DIR .. "/scripts/emoticon.py"

-- QuickShell
local script_launcher      = "qs ipc call launcher toggle"
local script_wallpaper     = "qs ipc call wallpaper toggle"
local script_notifications = "qs ipc call notifications toggle"
local script_powermenu     = "qs ipc call powermenu toggle"

-- =========================================================
-- APPLICATIONS
-- =========================================================

-- Launcher
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd(script_launcher))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(script_launcher))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd(script_launcher))

-- Terminal
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))

-- File manager
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))

-- IDE
hl.bind(mainMod .. " + I", hl.dsp.exec_cmd(ide))

-- Browser
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser))

-- Games
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd(script_games))

-- Emoji / emoticon picker
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd(script_emoticon))

-- =========================================================
-- WINDOW MANAGEMENT
-- =========================================================

-- Close window
hl.bind(
	mainMod .. " + SHIFT + Q",
	hl.dsp.window.close()
)

-- Fullscreen
hl.bind(
	mainMod .. " + F",
	hl.dsp.window.fullscreen({ mode = 0 })
)

-- Toggle floating
hl.bind(
	mainMod .. " + SHIFT + F",
	hl.dsp.window.float({ action = "toggle" })
)

-- Pseudo
hl.bind(
	mainMod .. " + P",
	hl.dsp.window.pseudo()
)

-- Toggle split
hl.bind(
	mainMod .. " + J",
	hl.dsp.layout("togglesplit")
)

-- =========================================================
-- FOCUS MOVEMENT
-- =========================================================

-- Arrow keys
local directions = {
	left = "left",
	right = "right",
	up = "up",
	down = "down",
}

for key, dir in pairs(directions) do
	hl.bind(
		mainMod .. " + " .. key,
		hl.dsp.focus({ direction = dir })
	)
end

-- Vim-style focus
-- NOTE: J is intentionally omitted because SUPER+J = togglesplit
hl.bind(
	mainMod .. " + H",
	hl.dsp.focus({ direction = "left" })
)

hl.bind(
	mainMod .. " + K",
	hl.dsp.focus({ direction = "up" })
)

hl.bind(
	mainMod .. " + L",
	hl.dsp.focus({ direction = "right" })
)

-- =========================================================
-- MOVE WINDOWS
-- =========================================================

hl.bind(
	mainMod .. " + SHIFT + H",
	hl.dsp.window.move({ direction = "left" })
)

hl.bind(
	mainMod .. " + SHIFT + L",
	hl.dsp.window.move({ direction = "right" })
)

hl.bind(
	mainMod .. " + SHIFT + K",
	hl.dsp.window.move({ direction = "up" })
)

hl.bind(
	mainMod .. " + SHIFT + J",
	hl.dsp.window.move({ direction = "down" })
)

-- =========================================================
-- DESKTOP / SESSION
-- =========================================================

-- Wallpaper
hl.bind(
	mainMod .. " + W",
	hl.dsp.exec_cmd(script_wallpaper)
)

-- Power menu
hl.bind(
	mainMod .. " + SHIFT + E",
	hl.dsp.exec_cmd(script_powermenu)
)

-- Reload Hyprland
hl.bind(
	mainMod .. " + SHIFT + R",
	hl.dsp.exec_cmd("hyprctl reload")
)

-- Lock session
hl.bind(
	mainMod .. " + SHIFT + L",
	hl.dsp.exec_cmd("loginctl lock-session")
)

-- Notifications
hl.bind(
	mainMod .. " + N",
	hl.dsp.exec_cmd(script_notifications)
)

-- =========================================================
-- WORKSPACES
-- =========================================================

for i = 1, 10 do
	local key = i % 10

	-- Switch workspace
	hl.bind(
		mainMod .. " + " .. key,
		hl.dsp.focus({ workspace = i })
	)

	-- Move active window
	hl.bind(
		mainMod .. " + SHIFT + " .. key,
		hl.dsp.window.move({ workspace = i })
	)
end

-- =========================================================
-- SPECIAL WORKSPACE
-- =========================================================

hl.bind(
	mainMod .. " + S",
	hl.dsp.workspace.toggle_special("magic")
)

hl.bind(
	mainMod .. " + SHIFT + S",
	hl.dsp.window.move({
		workspace = "special:magic"
	})
)

-- =========================================================
-- WORKSPACE SCROLLING
-- =========================================================

hl.bind(
	mainMod .. " + mouse_down",
	hl.dsp.focus({ workspace = "e+1" })
)

hl.bind(
	mainMod .. " + mouse_up",
	hl.dsp.focus({ workspace = "e-1" })
)

-- =========================================================
-- MOUSE WINDOW CONTROLS
-- =========================================================

hl.bind(
	mainMod .. " + mouse:272",
	hl.dsp.window.drag(),
	{ mouse = true }
)

hl.bind(
	mainMod .. " + mouse:273",
	hl.dsp.window.resize(),
	{ mouse = true }
)

-- =========================================================
-- AUDIO
-- =========================================================

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd(
		"wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
	),
	{ locked = true, repeating = true }
)

hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd(
		"wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
	),
	{ locked = true, repeating = true }
)

hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd(
		"wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
	),
	{ locked = true }
)

hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd(
		"wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
	),
	{ locked = true }
)

hl.bind(
	"SCROLL_LOCK",
	hl.dsp.exec_cmd(script_audio),
	{ locked = true }
)

-- =========================================================
-- BRIGHTNESS
-- =========================================================

hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd(
		"brightnessctl -e4 -n2 set 5%+"
	),
	{ locked = true, repeating = true }
)

hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd(
		"brightnessctl -e4 -n2 set 5%-"
	),
	{ locked = true, repeating = true }
)

-- =========================================================
-- MEDIA
-- =========================================================

hl.bind(
	"XF86AudioNext",
	hl.dsp.exec_cmd("playerctl next"),
	{ locked = true }
)

hl.bind(
	"XF86AudioPrev",
	hl.dsp.exec_cmd("playerctl previous"),
	{ locked = true }
)

hl.bind(
	"XF86AudioPlay",
	hl.dsp.exec_cmd("playerctl play-pause"),
	{ locked = true }
)

hl.bind(
	"XF86AudioPause",
	hl.dsp.exec_cmd("playerctl play-pause"),
	{ locked = true }
)

-- SUPER + navigation keys
hl.bind(
	mainMod .. " + HOME",
	hl.dsp.exec_cmd("playerctl previous"),
	{ locked = true }
)

hl.bind(
	mainMod .. " + END",
	hl.dsp.exec_cmd("playerctl next"),
	{ locked = true }
)

hl.bind(
	mainMod .. " + PRIOR",
	hl.dsp.exec_cmd("playerctl play-pause"),
	{ locked = true }
)

hl.bind(
	mainMod .. " + NEXT",
	hl.dsp.exec_cmd("playerctl stop"),
	{ locked = true }
)

-- =========================================================
-- SCREENSHOT
-- =========================================================

-- Select region
hl.bind(
	"Print",
	hl.dsp.exec_cmd("grimblast --notify copy area")
)

-- Active window
hl.bind(
	mainMod .. " + Print",
	hl.dsp.exec_cmd("grimblast --notify copy active")
)

-- =========================================================
-- END
-- =========================================================
