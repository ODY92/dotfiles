hl.on("hyprland.start", function()
    hl.exec_cmd("/home/ulysse/linux-voicemod/linux-voicemod/voicemod &")
end)

dofile(os.getenv("HOME") .. "/.config/hypr/tahoe-cursor.lua")
