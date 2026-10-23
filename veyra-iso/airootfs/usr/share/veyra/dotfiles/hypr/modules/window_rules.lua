-- =========================================================
-- ~/.config/hypr/window_rules.lua
-- =========================================================

-- Desired game height.
-- Width is automatically calculated for 16:9.
local game_res = 576

-- =========================================================
-- HELPERS
-- =========================================================

local function calc_landscape(height)
	local width = math.ceil(height * (16 / 9))
	return { width, height }
end

local game_size = calc_landscape(game_res)

-- =========================================================
-- SHARED GAME PROFILE
-- =========================================================

local game_profile = {
	-- Floating game window
	float = true,

	-- Do not restore a previous size
	persistent_size = false,

	-- Computed 16:9 resolution
	size = game_size,

	-- Performance / latency
	no_anim = true,
	no_blur = true,
	no_dim = true,
	no_vrr = true,
	immediate = true,

	-- Keep the system awake during gameplay
	idle_inhibit = "always",

	-- Always place games on workspace 1
	workspace = "1",

	-- Clean game presentation
	border_size = 0,
	rounding = 0,
}

-- =========================================================
-- XWAYLAND
-- =========================================================

hl.window_rule({
	name = "fix-xwayland-drags",

	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

-- =========================================================
-- PICTURE IN PICTURE
-- =========================================================

hl.window_rule({
	name = "picture-in-picture",

	match = {
		title = "^Picture in Picture$",
		initial_title = "^Picture in Picture$",
	},

	float = true,
	persistent_size = true,
	size = calc_landscape(270),
	center = true,
})

-- =========================================================
-- GENERAL
-- =========================================================

hl.window_rule({
	name = "suppress-maximize-events",

	match = {
		class = ".*",
	},

	suppress_event = "maximize",
})

-- =========================================================
-- MENUS
-- =========================================================

hl.window_rule({
	name = "pick-wallpaper",

	match = {
		class = "^wallpaper-picker$",
		initial_title = "^kitty$",
	},

	fullscreen = false,
	tag = "+menu",
})

hl.window_rule({
	name = "kaomoji-picker",

	match = {
		initial_class = "^Tk$",
	},

	fullscreen = false,
	center = true,
})

-- =========================================================
-- GAMES
-- =========================================================

-- Blood Strike
hl.window_rule({
	name = "bloodstrike",

	match = {
		initial_class = "^(steam_app_3199170|bloodstrike%.exe)$",
	},

	fullscreen = false,

	-- Apply the shared game profile
	float = game_profile.float,
	persistent_size = game_profile.persistent_size,
	size = game_profile.size,

	no_anim = game_profile.no_anim,
	no_blur = game_profile.no_blur,
	no_dim = game_profile.no_dim,
	no_vrr = game_profile.no_vrr,
	immediate = game_profile.immediate,

	idle_inhibit = game_profile.idle_inhibit,
	workspace = game_profile.workspace,

	border_size = game_profile.border_size,
	rounding = game_profile.rounding,

	tag = "+game",
})

-- Sober
hl.window_rule({
	name = "sober",

	match = {
		class = "^org%.vinegarhq%.Sober$",
	},

	fullscreen = false,

	-- Apply the shared game profile
	float = game_profile.float,
	persistent_size = game_profile.persistent_size,
	size = game_profile.size,

	no_anim = game_profile.no_anim,
	no_blur = game_profile.no_blur,
	no_dim = game_profile.no_dim,
	no_vrr = game_profile.no_vrr,
	immediate = game_profile.immediate,

	idle_inhibit = game_profile.idle_inhibit,
	workspace = game_profile.workspace,

	border_size = game_profile.border_size,
	rounding = game_profile.rounding,

	tag = "+game",
})

-- Minecraft
hl.window_rule({
	name = "minecraft",

	match = {
		initial_class = "^Minecraft.*$",
	},

	fullscreen = false,

	-- Apply the shared game profile
	float = game_profile.float,
	persistent_size = game_profile.persistent_size,
	size = game_profile.size,

	no_anim = game_profile.no_anim,
	no_blur = game_profile.no_blur,
	no_dim = game_profile.no_dim,
	no_vrr = game_profile.no_vrr,
	immediate = game_profile.immediate,

	idle_inhibit = game_profile.idle_inhibit,
	workspace = game_profile.workspace,

	border_size = game_profile.border_size,
	rounding = game_profile.rounding,

	tag = "+game",
})

-- =========================================================
-- GAME TAG PROFILE
-- =========================================================

-- Keep this for properties that should apply dynamically
-- to anything carrying the game tag.
hl.window_rule({
	name = "game-profile",

	match = {
		tag = "game",
	},

	-- Dynamic effects only.
	-- Static effects such as float/size are applied directly
	-- by each game's rule above.
	no_anim = true,
	no_blur = true,
	no_dim = true,
	no_vrr = true,
	immediate = true,
	idle_inhibit = "always",
	border_size = 0,
	rounding = 0,
})

-- =========================================================
-- MENUS
-- =========================================================

hl.window_rule({
	name = "menu",

	match = {
		tag = "menu",
	},

	float = true,
	persistent_size = true,
	size = calc_landscape(720),
	center = true,

	no_blur = false,
	no_dim = false,
	idle_inhibit = "always",
})

hl.window_rule({
	name = "menu-small",

	match = {
		tag = "menu-small",
	},

	float = true,
	persistent_size = true,
	size = { 220, 300 },
	center = true,

	no_blur = false,
	no_dim = false,
	idle_inhibit = "always",
})
