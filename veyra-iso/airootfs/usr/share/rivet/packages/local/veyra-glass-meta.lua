package({
    name = "veyra-glass-meta",
    version = "1.0.0",
    description = "Fluid Glass desktop environment meta-package for Veyra OS",
    license = "BSD-3-Clause",
    publisher = "Frank1o3",
    homepage = "https://github.com/Frank1o3/Veyra",

    dependencies = {
        "veyra-glass-hyprland >= 1.0.0",
        "veyra-glass-quickshell >= 1.0.0",
        "veyra-glass-sddm >= 1.0.0",
        "veyra-glass-gtk >= 1.0.0",
        "veyra-glass-kitty >= 1.0.0",
    },

    install = function(ctx)
        -- Virtual meta package
    end,
})
