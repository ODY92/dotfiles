if hl.plugin.hypr3d then
    local hypr3d = hl.plugin.hypr3d

    hl.bind("SUPER + F11", hypr3d.open)
    hl.bind("SUPER + F12", hypr3d.close)

    hypr3d.on_state(function(open)
        hl.config({ input = { kb_layout = open and "us" or "fr" } })
    end)

    hypr3d.config({
        world = {
            grid = true,
        },
        player = {
            flying = true,
            collision = false,
            move_speed = 8.0,
            spawn = {0, 2, 0},
        },
        scene = {
            backrooms = {
                mesh = {
                    path = "~/hypr3d/backrooms.glb",
                    transform = {
                        position = {0, 0, 0},
                        scale = {1, 1, 1},
                    },
                    flat = true,
                },
                collision = false,
                static = true,
            },
        },
    })
end
