package({
    name = "veyra-glass-gtk",
    version = "1.0.0",
    description = "Fluid Glass GTK 3/4 and libadwaita styling overrides",
    license = "BSD-3-Clause",
    publisher = "Frank1o3",
    homepage = "https://github.com/Frank1o3/Veyra",

    install = function(ctx)
        local home = ctx:home()
        ctx:mkdir(home .. "/.config/gtk-4.0")
        ctx:mkdir(home .. "/.config/gtk-3.0")
    end,
})
