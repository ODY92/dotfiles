hl.on("hyprland.start", function()
    hl.exec_cmd("/home/ulysse/.local/share/tuna-board/bin/tuna-board --background")
end)

dofile(os.getenv("HOME") .. "/.config/hypr/tahoe-cursor.lua")

-- LinusWare: panneau de scripts sur DEL dans Roblox
dofile(os.getenv("HOME") .. "/.config/hypr/linusware-scripts.lua")
