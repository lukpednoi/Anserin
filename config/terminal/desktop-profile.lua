local home = os.getenv("HOME") or ""

-- Load a file Anserin writes (it may not exist yet, e.g. on the very first boot) without stopping the rest.
local function load_if_present(path)
    local f = io.open(path, "r")
    if not f then return end
    f:close()
    local ok, err = pcall(dofile, path)
    if not ok then print("Anserin: " .. path .. ": " .. tostring(err)) end
end

load_if_present(home .. "/.config/anserin/terminal/hyprland.lua")
-- Anserin's shortcuts, made from your own binds: only keys you do not use are taken (src/scripts/hypr-keybinds.py).
load_if_present(home .. "/.config/anserin/hyprland/keybinds.lua")

-- SDDM's "Hyprland (Anserin)" session (the New theme's star chip) starts the shell at login.
-- Hyprland's own background stays black until the startup fade covers it, so it never flashes.
if os.getenv("ANSERIN_SESSION") == "1" then
    hl.config({ misc = { disable_hyprland_logo = true, background_color = 0xff000000 } })
    hl.on("hyprland.start", function()
        hl.exec_cmd('mkdir -p "$XDG_RUNTIME_DIR/anserin" && exec anserin login >>"$XDG_RUNTIME_DIR/anserin/fork.log" 2>&1')
    end)
end

-- Clipboard history for Anserin's clipboard (cliphist), unless something already records it (the "^" makes pgrep
-- look only at real wl-paste processes, not at this shell line, which contains the same words).
hl.on("hyprland.start", function()
    hl.exec_cmd('pgrep -u "$USER" -f "^wl-paste --type text --watch cliphist" >/dev/null || exec wl-paste --type text --watch cliphist store')
    hl.exec_cmd('pgrep -u "$USER" -f "^wl-paste --type image --watch cliphist" >/dev/null || exec wl-paste --type image --watch cliphist store')
end)
