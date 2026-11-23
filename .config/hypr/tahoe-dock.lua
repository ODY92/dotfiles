if hl.plugin.hyprglass then
    local glass = hl.plugin.hyprglass
    glass.layer("tahoe-dock", {
        preset = "glass",
        mask_mode = "alpha",
        mask_threshold = 0.0,
        mask_feather = 0.0,
        shape = { inset = { 100, 64, 12, 64 }, radius = 24 },
        live_resample = true,
    })
    glass.layer("tahoe-dock-menu", {
        preset = "glass",
        mask_mode = "contour",
        mask_threshold = 0.15,
        mask_feather = 0.03,
    })
end

hl.layer_rule({
    name = "tahoe-dock-glass",
    match = { namespace = "tahoe-dock" },
    blur = true,
    ignore_alpha = 0.1,
    no_anim = true,
})

hl.layer_rule({
    name = "tahoe-dock-menu-glass",
    match = { namespace = "tahoe-dock-menu" },
    blur = true,
    ignore_alpha = 0.1,
    no_anim = true,
})
