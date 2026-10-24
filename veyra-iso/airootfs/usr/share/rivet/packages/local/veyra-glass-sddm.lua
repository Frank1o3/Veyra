package({
    name = "veyra-glass-sddm",
    version = "1.0.0",
    description = "Fluid Glass SDDM login theme with frosted blur and specular rims",
    license = "BSD-3-Clause",
    publisher = "Frank1o3",
    homepage = "https://github.com/Frank1o3/Veyra",

    install = function(ctx)
        local dest = ctx:destdir() .. ctx:prefix() .. "/share/sddm/themes/quickshell-glass"
        ctx:mkdir(dest)
    end,
})
