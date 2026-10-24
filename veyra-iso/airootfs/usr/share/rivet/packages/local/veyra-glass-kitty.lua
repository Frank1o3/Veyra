package({
    name = "veyra-glass-kitty",
    version = "1.0.0",
    description = "Fluid Glass Kitty terminal configuration with dual kawase background blur",
    license = "BSD-3-Clause",
    publisher = "Frank1o3",
    homepage = "https://github.com/Frank1o3/Veyra",

    install = function(ctx)
        local home = ctx:home()
        ctx:mkdir(home .. "/.config/kitty")
    end,
})
