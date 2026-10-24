package({
    name = "veyra-glass-quickshell",
    version = "1.0.0",
    description = "Fluid Glass desktop shell with pill bar, control center, and toasts",
    license = "BSD-3-Clause",
    publisher = "Frank1o3",
    homepage = "https://github.com/Frank1o3/Veyra",

    install = function(ctx)
        local home = ctx:home()
        ctx:mkdir(home .. "/.config/quickshell")
    end,
})
