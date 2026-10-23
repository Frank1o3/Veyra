---- INPUT ----
---
hl.config({
	input = {
		-- Keyboard
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "compose:ralt",
		kb_rules = "",
		numlock_by_default = false,

		-- Touchdevice
		touchpad = { natural_scroll = true },

		-- Mouse
		follow_mouse = 1,
		sensitivity = 0,
		accel_profile = "flat",
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})
