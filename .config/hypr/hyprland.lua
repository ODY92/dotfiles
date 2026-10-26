local home   = os.getenv("HOME")
local hypr   = home .. "/.config/hypr"
package.path = package.path .. ";" .. home .. "/.config/caelestia/?.lua"

-- Create a file if it doesn't exist, optionally with initial content
local function maybe_create(file, content)
    local f = io.open(file)

    if f then
        f:close()
        return
    end

    f = io.open(file, "w")
    if f then
        if content then f:write(content) end
        f:close()
    end
end

-- Copy src to dst, but only if dst doesn't already exist
local function maybe_copy(src, dst)
    local out = io.open(dst)
    if out then
        out:close()
        return
    end

    local input = io.open(src, "r")
    if not input then return end

    out = io.open(dst, "w")
    if out then
        out:write(input:read("*a"))
        out:close()
    end
    input:close()
end

-- Maybe set current colours to defaults
maybe_copy(hypr .. "/scheme/default.lua", hypr .. "/scheme/current.lua")

-- User variables
maybe_create(home .. "/.config/caelestia/hypr-vars.lua", "return {}\n")
local overrides = require("hypr-vars")
if type(overrides) == "table" then
    local vars = require("variables")
    for k, v in pairs(overrides) do
        vars[k] = v
    end
end

-- Default monitor conf
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

hl.on("hyprland.start", function()
-- 	hl.exec_cmd("caelestia shell")
end)

-- Configs
require("hyprland.env")
require("hyprland.general")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.animations")
require("hyprland.decoration")
require("hyprland.group")
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.gestures")
require("hyprland.keybinds")

-- User configs
maybe_create(home .. "/.config/caelestia/hypr-user.lua")
require("hypr-user")

-- HYPRGLASS:

if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass
    hg.config({
        default_theme = "dark",        -- Thème par défaut ("light" ou "dark")
        default_preset = "glass",       -- Préréglage par défaut
        blur_strength = 2.0,            -- Rayon du flou (valeur * 12.0 px)
        blur_iterations = 3,            -- Passes de flou gaussien (1-5)
        refraction_strength = 0.2,      -- Intensité de réfraction des bords (0.0-1.0)
        fresnel_strength = 0.6,         -- Intensité de la lueur sur les angles (0.0-1.0)
        specular_strength = 0.8,        -- Luminosité des reflets spéculaires (0.0-1.0)
        glass_opacity = 0.25,            -- Opacité globale du verre (0.0-1.0)
        edge_thickness = 0.06           -- Largeur de la bordure / biseau (0.0 - 0.15)
    })
end


-- SENSIBILITEE SOURIS
hl.config({
    input = {
        sensitivity = -0.25,
        accel_profile = "flat",
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("sh -c 'hyprpm reload; sleep 3; hyprctl eval \"dofile(os.getenv(\\\"HOME\\\") .. \\\"/.config/hypr/hypr3d.lua\\\")\"'")
end)

-- HYPR3D:
dofile(os.getenv("HOME") .. "/.config/hypr/hypr3d.lua")

-- Added by hyprmoncfg: its generated monitor rules load last, so nothing before this can override the applied layout.
do local path = os.getenv("HOME") .. "/.config/hypr/hyprmoncfg-monitors.lua"; local file = io.open(path, "r"); if file then file:close(); dofile(path) end end


if hl.plugin.hyprglass then
    local hg = hl.plugin.hyprglass

    hg.config({
        layers = {
            enabled = true,
            live_resample = true,
            manage_blur = true,
        },
    })

    hg.layer("caelestia-drawers", { preset = "pomme", mask_threshold = 0.05 })
    hg.preset("spotlight-clear", {
        inherits = "pomme",
        glass_opacity = 0.55,
        tint_color = 0x00000000,
        blur_strength = 1.0,
        refraction_strength = 0.30,
        fresnel_strength = 0.65,
        specular_strength = 0.8,
        edge_thickness = 0.045,
    })
    hg.layer("spotlight26", { preset = "spotlight-clear", mask_mode = "contour", mask_threshold = 0.1, mask_feather = 0.03 })
end


hl.layer_rule({
    match = { namespace = "caelestia-drawers" },
    name = "caelestia-drawers-blur",
    blur = true,
    ignore_alpha = 0.1,
})

hl.layer_rule({
    match = { namespace = "spotlight26" },
    name = "spotlight26-glass",
    blur = true,
    ignore_alpha = 0.1,
    no_anim = true,
})
