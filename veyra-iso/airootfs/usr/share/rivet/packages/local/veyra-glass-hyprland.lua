package({
    name = "veyra-glass-hyprland",
    version = "1.0.0",
    description = "Fluid Glass compositor configuration and GLSL shaders for Hyprland",
    license = "BSD-3-Clause",
    publisher = "Frank1o3",
    homepage = "https://github.com/Frank1o3/Veyra",

    install = function(ctx)
        local home = ctx:home()
        ctx:mkdir(home .. "/.config/hypr/shaders")
    end,
})
