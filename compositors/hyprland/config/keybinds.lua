local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

local function resize_window(x, y)
    return function()
        if _G.AnserinScrollable and AnserinScrollable.resize and AnserinScrollable.resize(x, y) then return end
        hl.dispatch(hl.dsp.window.resize({ x = x, y = y, relative = true }))
    end
end
hl.bind(mainMod .. " + SHIFT + Left", resize_window(-50, 0), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Right", resize_window(50, 0), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Up", resize_window(0, -50), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Down", resize_window(0, 50), { repeating = true })

hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.move({ direction = "d" }))

hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))

hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("anserin brightness lower"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("anserin brightness raise"), { locked = true })

hl.bind("Print", hl.dsp.exec_cmd("anserin screenshot"), { locked = true })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("anserin screenshot --edit"), { locked = true })
hl.bind("SUPER + Print", hl.dsp.exec_cmd("anserin screenshot --full"), { locked = true })
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("anserin screenshot --full --edit"), { locked = true })

hl.bind("XF86PowerOff", hl.dsp.exec_cmd("anserin lock"), { locked = true })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("anserin lock"), { repeating = true, locked = true })

hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("anserin volume mic-toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("anserin volume mute-toggle"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("anserin volume lower"), { repeating = true, locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("anserin volume raise"), { repeating = true, locked = true })

hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))

hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("anserin reload"))
hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("anserin msg toggle clipboard"))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("anserin msg toggle launcher"))
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("anserin msg toggle music"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("anserin msg toggle system"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("anserin msg toggle wallpaper"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("anserin msg toggle calendar"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("anserin msg toggle network"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("anserin msg toggle volume"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("anserin msg toggle guide"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("anserin msg toggle autohide"))

for i = 1, 10 do
  local ws = tostring(i)
  local key = tostring(i % 10)
  hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("anserin msg workspace " .. ws))
  hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("anserin msg workspace " .. ws .. " move"))
end
