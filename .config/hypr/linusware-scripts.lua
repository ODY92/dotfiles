-- DEL is handled on Sober's X11 window by the panel, without a desktop-wide bind.

hl.window_rule({
    name = "linusware-scripts-panel",
    match = { class = "^(linusware-scripts|Sober Scripts)$" },
    float = true,
    center = true,
    size = "1180 760",
    no_blur = true,
    opacity = "1.0 override 1.0 override 1.0 override",
    tag = "+hyprglass_disabled",
})

hl.window_rule({
    name = "sober-scripts-transparent-canvas",
    match = { class = "^(linusware_overlay)$" },
    no_blur = true, no_shadow = true,
    opacity = "1.0 override 1.0 override 1.0 override",
    tag = "+hyprglass_disabled",
})
