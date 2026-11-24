dofile(os.getenv("HOME") .. "/.config/anserin/terminal/hyprland.lua")

-- SDDM's "Hyprland (Anserin)" session (the New theme's star chip) starts the shell at login.
-- Hyprland's own background stays black until the startup fade covers it, so it never flashes.
if os.getenv("ANSERIN_SESSION") == "1" then
    hl.config({ misc = { disable_hyprland_logo = true, background_color = 0xff000000 } })
    hl.on("hyprland.start", function()
        hl.exec_cmd('mkdir -p "$XDG_RUNTIME_DIR/anserin" && exec anserin login >>"$XDG_RUNTIME_DIR/anserin/fork.log" 2>&1')
    end)
end

-- Claude Panel: SUPER + C opens it, folds it into its corner dome (the session keeps running) and opens it again.
hl.bind("SUPER + C", hl.dsp.exec_cmd("anserin ipc call claude toggle"), { description = "Anserin: Claude Panel" })

-- Closing a window (SUPER + X) while the pointer is over the Claude Panel closes only the panel: it floats over the
-- windows, so it is closed like a program of its own. The panel writes where it is ("x y w h", layout pixels).
local function pointer_over_claude_panel()
    local run = (os.getenv("XDG_RUNTIME_DIR") or "") .. "/anserin"
    -- a panel-rect left behind by a shell that crashed must not stop SUPER + X from closing windows
    local pf = io.open(run .. "/quickshell.pid", "r")
    local pid = pf and pf:read("n")
    if pf then pf:close() end
    local alive = pid and io.open("/proc/" .. math.tointeger(pid) .. "/cmdline", "r")
    if not alive then return false end
    alive:close()
    local f = io.open(run .. "/claude/panel-rect", "r")
    if not f then return false end
    local x, y, w, h = f:read("n", "n", "n", "n")
    f:close()
    local c = hl.get_cursor_pos()
    return x ~= nil and h ~= nil and c ~= nil and c.x >= x and c.x < x + w and c.y >= y and c.y < y + h
end
hl.unbind("SUPER + X")
hl.bind("SUPER + X", function()
    if pointer_over_claude_panel() then
        hl.dispatch(hl.dsp.exec_cmd("anserin ipc call claude close"))
    else
        hl.dispatch(hl.dsp.window.close())
    end
end, { description = "Close the window (or the Claude Panel under the pointer)" })
