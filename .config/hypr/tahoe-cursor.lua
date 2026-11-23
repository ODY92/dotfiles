-- Keep the compositor and application cursors on the same Apple Cursor theme.
hl.env("HYPRCURSOR_THEME", "macOS")
hl.env("HYPRCURSOR_SIZE", "42")
hl.config({ cursor = { enable_hyprcursor = true, sync_gsettings_theme = true } })

local function configure_pointer()
    if not hl.plugin.dynamic_cursors then
        return
    end
    hl.config({
        plugin = {
            dynamic_cursors = {
                enabled = true,
                mode = "tilt",
                threshold = 0.15,
                tilt = {
                    full = 10,
                    limit = 2200,
                    window = 60,
                    activation = "negative_quadratic",
                },
                immersive = {
                    click_enabled = true,
                    click_scale = 0.90,
                    blur_enabled = true,
                    blur_strength = 0.45,
                    blur_shutter = 0.008,
                    blur_limit = 14.0,
                },
                -- Movement is tracked through onCursorMoved for plugin compatibility.
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
                hyprcursor = { enabled = true, resolution = 96, nearest = 0 },
            },
        },
    })
end

configure_pointer()

-- The loader checks the Hyprland ABI before loading the locally built plugin.
hl.on("hyprland.start", function()
    hl.exec_cmd(os.getenv("HOME") .. "/.local/share/macos-cursor/load-plugin")
end)
