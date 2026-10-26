hl.env("HYPRCURSOR_THEME", "MacTahoe-Tailless")
hl.env("HYPRCURSOR_SIZE", "64")
hl.config({ cursor = { enable_hyprcursor = true, sync_gsettings_theme = true } })

local function configure_pointer()
    if not hl.plugin.dynamic_cursors then
        return
    end
    hl.config({
        plugin = {
            dynamic_cursors = {
                enabled = true,
                mode = "none",
                ignore_warps = false,
                shake = {
                    enabled = true,
                    effects = false,
                    threshold = 6.0,
                    base = 2.5,
                    speed = 0.0,
                    limit = 2.5,
                    timeout = 500,
                },
                hyprcursor = { enabled = true, resolution = 160, nearest = 0 },
            },
        },
    })
end

configure_pointer()
