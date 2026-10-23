-- Safe wallust colors load
local ok, wallust = pcall(require, "colors")
local w_col = ok and wallust.general and wallust.general.col or {}

---- LOOK AND FEEL ----
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 15,
		border_size = 2,
		col = {
			active_border = w_col.active_border or { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
			inactive_border = w_col.inactive_border or "rgba(595959aa)",
		},
		resize_on_border = false,
		allow_tearing = true,
	},
	decoration = {
		rounding = 10,
		shadow = {
			enabled = true,
			range = 28,
			render_power = 4,
			color = "0xaa000000",
		},
		blur = {
			enabled = true,
			size = 12,
			passes = 3,
			new_optimizations = true,
			ignore_opacity = false
		},
	},
	animations = { enabled = true },
	cursor = { no_hardware_cursors = 2 },
})
