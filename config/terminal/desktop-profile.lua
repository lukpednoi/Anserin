dofile(os.getenv("HOME") .. "/.config/anserin/terminal/hyprland.lua")

-- SDDM's "Hyprland (Anserin)" session (the New theme's star chip) starts the shell at login.
-- Hyprland's own background stays black until the startup fade covers it, so it never flashes.
if os.getenv("ANSERIN_SESSION") == "1" then
    hl.config({ misc = { disable_hyprland_logo = true, background_color = 0xff000000 } })
    hl.on("hyprland.start", function()
        hl.exec_cmd('mkdir -p "$XDG_RUNTIME_DIR/anserin" && exec anserin login >>"$XDG_RUNTIME_DIR/anserin/fork.log" 2>&1')
    end)
end
