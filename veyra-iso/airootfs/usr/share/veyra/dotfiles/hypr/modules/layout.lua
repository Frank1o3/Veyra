-- --- ~/.config/hypr/hyprland.lua

hl.config({
	general = {
		layout = "dwindle",
	},
	dwindle = {
		preserve_split = true,
	},
	xwayland = {
		force_zero_scaling = true,
	},
	master = {
		new_status = "master",
	},
	scrolling = {
		fullscreen_on_one_column = true,
	}
})
