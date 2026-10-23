-- =========================
-- Curves
-- =========================

-- Fast acceleration, smooth landing
hl.curve("snappy", {
type = "bezier",
points = { {0.22, 0.0}, {0.08, 1.0} }
})

-- Quick start with a slightly dramatic finish
hl.curve("dramatic", {
type = "bezier",
points = { {0.16, 1.0}, {0.08, 1.0} }
})

-- Smooth and natural
hl.curve("smooth", {
type = "bezier",
points = { {0.22, 0.1}, {0.22, 1.0} }
})

-- True linear
hl.curve("linear", {
type = "bezier",
points = { {0, 0}, {1, 1} }
})

-- Soft, premium spring
hl.curve("floaty", {
type = "spring",
mass = 1,
stiffness = 55,
dampening = 20
})

-- Controlled bounce
hl.curve("bouncy", {
type = "spring",
mass = 1,
stiffness = 155,
dampening = 11
})

-- Very fast and controlled
hl.curve("snap", {
type = "spring",
mass = 1,
stiffness = 240,
dampening = 25
})

-- =========================
-- Animations
-- =========================

-- Border
hl.animation({
leaf = "border",
enabled = true,
speed = 5,
bezier = "snappy"
})

-- =========================
-- Windows
-- =========================

-- Main window movement
hl.animation({
leaf = "windows",
enabled = true,
speed = 6,
spring = "snap"
})

-- Window opening
hl.animation({
leaf = "windowsIn",
enabled = true,
speed = 9,
spring = "bouncy",
style = "popin 85%"
})

-- Window closing
hl.animation({
leaf = "windowsOut",
enabled = true,
speed = 6,
bezier = "snappy",
style = "popin 85%"
})

-- =========================
-- Fade
-- =========================

-- Gentle fade-in
hl.animation({
leaf = "fadeIn",
enabled = true,
speed = 2.2,
bezier = "smooth"
})

-- Slightly faster fade-out
hl.animation({
leaf = "fadeOut",
enabled = true,
speed = 2,
bezier = "smooth"
})

-- General fade
hl.animation({
leaf = "fade",
enabled = true,
speed = 4,
bezier = "linear"
})

-- =========================
-- Layers
-- =========================

-- Layer movement
hl.animation({
leaf = "layers",
enabled = true,
speed = 6,
spring = "floaty"
})

-- Layer opening
hl.animation({
leaf = "layersIn",
enabled = true,
speed = 6,
spring = "floaty",
style = "fade"
})

-- Layer closing
hl.animation({
leaf = "layersOut",
enabled = true,
speed = 4,
bezier = "snappy",
style = "fade"
})

-- Layer fade-in
hl.animation({
leaf = "fadeLayersIn",
enabled = true,
speed = 2.4,
bezier = "smooth"
})

-- Layer fade-out
hl.animation({
leaf = "fadeLayersOut",
enabled = true,
speed = 2.2,
bezier = "smooth"
})

-- =========================
-- Workspaces
-- =========================

-- Fast, cinematic workspace switching
hl.animation({
leaf = "workspaces",
enabled = true,
speed = 8,
bezier = "dramatic",
style = "fade"
})

hl.animation({
leaf = "workspacesIn",
enabled = true,
speed = 8,
bezier = "dramatic",
style = "fade"
})

hl.animation({
leaf = "workspacesOut",
enabled = true,
speed = 8,
bezier = "dramatic",
style = "fade"
})

-- =========================
-- Zoom
-- =========================

-- Fast but smooth zoom
hl.animation({
leaf = "zoomFactor",
enabled = true,
speed = 11,
spring = "snap"
})
