-- Adapted from sarodscommits/hyprland-infinitie-desktop-v2 (MIT; see LICENSE).
-- Native Hyprland input and window events; no input-device reader or daemon.
return function(options)
    local Layout = dofile(assert(options.layout_file, "Missing layout module path"))
    local api = {enabled = false}
    -- How the canvas is moved: "anserin" ways are fixed, "custom" ones use keys chosen in Settings
    -- (defaults as in the original repo: hold SUPER + ALT and move the mouse, SUPER + SHIFT / SUPER + CTRL + arrows).
    local PAN_SPEED, STEP, MIN_SIZE, EDGE_MARGIN = 1.6, 90, 100, 10
    local pan_mode = options.pan_mode == "custom" and "custom" or "anserin"
    local move_mode = options.move_mode == "custom" and "custom" or "anserin"
    local resize_mode = options.resize_mode == "custom" and "custom" or "anserin"
    local cell_scale = math.max(50, math.min(150, tonumber(options.cell_scale) or 100)) / 100
    local MOD_KEYS = {SUPER = {"Super_L", "Super_R"}, CTRL = {"Control_L", "Control_R"}, ALT = {"Alt_L", "Alt_R"}, SHIFT = {"Shift_L", "Shift_R"}}
    local function mod_list(value, fallback)
        local list = {}
        for part in tostring(value or fallback):gmatch("[^+%s]+") do
            if MOD_KEYS[part] then table.insert(list, part) end
        end
        return #list > 0 and list or mod_list(fallback, "SUPER")
    end
    local function mods_text(list) return table.concat(list, " + ") end
    local function mods_down(list)
        for _, mod in ipairs(list) do
            if not (hl.is_key_down(MOD_KEYS[mod][1]) or hl.is_key_down(MOD_KEYS[mod][2])) then return false end
        end
        return true
    end
    local pan_keys = mod_list(options.pan_keys, "SUPER + ALT")
    local navigate_keys = options.navigate_mode == "custom" and mod_list(options.navigate_keys, "SUPER") or {"SUPER"}
    local move_keys = mod_list(options.move_keys, "SUPER + SHIFT")
    local resize_keys = mod_list(options.resize_keys, "SUPER + CTRL")
    local originals, groups = {}, {}
    local motion, tap, timer, dirty
    local session = os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or ""
    local legacy_zoom
    local loader, load_error = loadfile(options.state_file, "t", {})
    if loader then
        local ok, saved = pcall(loader)
        assert(ok and type(saved) == "table" and type(saved.windows) == "table", "Cannot read inf desktop recovery state")
        if saved.session == session then
            originals = saved.windows
            if saved.version == 2 or saved.version == 3 or saved.version == 4 then
                assert(type(saved.groups) == "table", "Invalid workspace state")
                groups = saved.groups
            else legacy_zoom = saved.base_zoom end
        end
        for id, record in pairs(originals) do
            assert((type(id) == "number" or type(id) == "string") and type(record) == "table" and type(record.floating) == "boolean", "Invalid recovery record")
            for _, key in ipairs({"x", "y", "w", "h", "workspace", "monitor"}) do
                assert(type(record[key]) == "number" and math.abs(record[key]) < math.huge, "Invalid recovery position")
            end
            for key, value in pairs(record) do
                assert(type(key) == "string" and (type(value) == "boolean" or (type(value) == "number" and math.abs(value) < math.huge)), "Invalid recovery value")
            end
            if record.group_workspace then
                for _, key in ipairs({"group_monitor", "cx", "cy", "cw", "ch"}) do assert(type(record[key]) == "number", "Invalid window group record") end
                assert(record.cw > 0 and record.ch > 0, "Invalid window size")
            end
        end
        for key, group in pairs(groups) do
            assert(type(key) == "string" and type(group) == "table", "Invalid workspace group")
            for _, field in ipairs({"monitor", "workspace", "x", "y"}) do
                assert(type(group[field]) == "number" and math.abs(group[field]) < math.huge, "Invalid canvas geometry")
            end
            Layout.validate(group.tree)
        end
    else
        local existing = io.open(options.state_file, "r")
        if existing then existing:close(); error("Cannot read recovery state: " .. tostring(load_error)) end
    end

    local function group_key(monitor, workspace) return monitor .. ":" .. workspace end
    local function current_group()
        local monitor = hl.get_active_monitor()
        if not monitor or not monitor.active_workspace or monitor.active_special_workspace then return nil end
        return groups[group_key(monitor.id, monitor.active_workspace.id)]
    end
    function api.is_active(monitor, workspace) return groups[group_key(monitor, workspace)] ~= nil end
    function api.has_native_groups()
        for _, group in pairs(groups) do if not group.scrolling then return true end end
        return false
    end
    local function write_value(file, value, seen)
        if type(value) == "table" then
            assert(not seen[value], "Cyclic recovery state")
            seen[value] = true
            assert(file:write("{"))
            for key, item in pairs(value) do
                assert(type(key) == "string" or type(key) == "number", "Invalid state key")
                local index = type(key) == "number" and tostring(key) or string.format("%q", key)
                assert(file:write("[" .. index .. "]=")); write_value(file, item, seen); assert(file:write(","))
            end
            assert(file:write("}")); seen[value] = nil
        else
            assert(type(value) == "boolean" or (type(value) == "number" and math.abs(value) < math.huge), "Invalid state value")
            assert(file:write(tostring(value)))
        end
    end
    local function save()
        local file = assert(io.open(options.state_file .. ".tmp", "w"))
        assert(file:write("return {version=4,session=" .. string.format("%q", session)
            .. ",active=" .. tostring(current_group() ~= nil) .. ",\n"))
        for _, entry in ipairs({{"windows", originals}, {"groups", groups}}) do
            assert(file:write(entry[1] .. "={\n"))
            for id, record in pairs(entry[2]) do
                local index = type(id) == "number" and tostring(id) or string.format("%q", id)
                assert(file:write("[" .. index .. "]="))
                write_value(file, record, {})
                assert(file:write(",\n"))
            end
            assert(file:write("},\n"))
        end
        assert(file:write("}\n")); assert(file:close())
        assert(os.rename(options.state_file .. ".tmp", options.state_file))
        dirty = false
    end
    local function eligible(window)
        return window and window.mapped and not window.hidden and not window.pinned
            and window.fullscreen == 0 and window.workspace and window.workspace.id > 0 and window.monitor
            and window.size.x > 0 and window.size.y > 0
    end
    local function windows(group, managed)
        local result = {}
        for _, window in ipairs(hl.get_windows()) do
            local record = originals[window.stable_id]
            if eligible(window) and window.monitor.id == group.monitor and window.workspace.id == group.workspace
                and (not managed or (record and record.group_monitor == group.monitor and record.group_workspace == group.workspace)) then
                table.insert(result, window)
            end
        end
        table.sort(result, function(a, b) return a.stable_id < b.stable_id end)
        return result
    end
    local function remember(window)
        if originals[window.stable_id] then return originals[window.stable_id] end
        local record = {x = window.at.x, y = window.at.y, w = window.size.x, h = window.size.y,
            floating = window.floating, workspace = window.workspace.id, monitor = window.monitor.id,
            dwindle = window.layout ~= nil and window.layout.name == "dwindle"}
        originals[window.stable_id] = record
        local ok, err = pcall(save)
        if not ok then originals[window.stable_id] = nil; error(err) end
        return record
    end
    local function geometry(window, x, y, w, h)
        local address = "address:" .. window.address
        if w and h then hl.dispatch(hl.dsp.window.resize({window = address, x = math.floor(w + .5), y = math.floor(h + .5), relative = false})) end
        hl.dispatch(hl.dsp.window.move({window = address, x = math.floor(x + .5), y = math.floor(y + .5), relative = false}))
    end
    local function render(group, skip)
        for _, window in ipairs(windows(group, true)) do
            if window.floating and window.stable_id ~= skip then
                local r = originals[window.stable_id]
                geometry(window, group.x + r.cx, group.y + r.cy)
            end
        end
    end
    local function sync_positions(group)
        local changed = false
        for _, window in ipairs(windows(group, true)) do
            local r = originals[window.stable_id]
            if window.floating and (math.abs(window.at.x - group.x - r.cx) > .75
                or math.abs(window.at.y - group.y - r.cy) > .75) then
                r.cx, r.cy = window.at.x - group.x, window.at.y - group.y
                changed, dirty = true, true
            end
            r.cw, r.ch = window.size.x, window.size.y
        end
        return changed
    end
    local function bounds(monitor, full_screen)
        local width, height = monitor.width / monitor.scale, monitor.height / monitor.scale
        if monitor.transform % 2 == 1 then width, height = height, width end
        local reserved = not full_screen and monitor.reserved or {}
        return {left = monitor.x + (reserved.left or 0), top = monitor.y + (reserved.top or 0),
            right = monitor.x + width - (reserved.right or 0), bottom = monitor.y + height - (reserved.bottom or 0)}
    end
    -- One cell of the monitor split 2x2 by Hyprland's own tiling (gaps and borders included), so every window on the
    -- canvas is the same rectangle as a quarter-screen tile.
    local function cell_size(monitor)
        local area = bounds(monitor)
        local function side(value, key) return type(value) == "table" and (value[key] or 0) or (tonumber(value) or 0) end
        local inner, outer = hl.get_config("general:gaps_in"), hl.get_config("general:gaps_out")
        local border = tonumber(hl.get_config("general:border_size")) or 0
        local w = (area.right - area.left - side(outer, "left") - side(outer, "right") - side(inner, "left") - side(inner, "right")) / 2 - 2 * border
        local h = (area.bottom - area.top - side(outer, "top") - side(outer, "bottom") - side(inner, "top") - side(inner, "bottom")) / 2 - 2 * border
        return math.max(1, math.floor(w * cell_scale + .5)), math.max(1, math.floor(h * cell_scale + .5))
    end
    local function attach(window, group)
        local record = remember(window)
        record.group_monitor, record.group_workspace = group.monitor, group.workspace
        -- Every window becomes one 2x2 cell, around its own centre (a box drawn with the right button sets its own).
        record.cw, record.ch = cell_size(window.monitor)
        record.cx = record.x + (record.w - record.cw) / 2 - group.x
        record.cy = record.y + (record.h - record.ch) / 2 - group.y
        save()
        if not window.floating then hl.dispatch(hl.dsp.window.float({window = "address:" .. window.address, action = "toggle"})) end
        -- Floating can choose a new size; put the original one back.
        geometry(window, group.x + record.cx, group.y + record.cy, record.cw, record.ch)
    end
    local function animate(group, targets)
        motion = {group = group, targets = targets, frame = 0}
        if timer then timer:set_timeout(16) end
    end
    local function arrange(group)
        motion = nil
        sync_positions(group)
        local targets = {}
        for _, window in ipairs(windows(group, true)) do
            local r = originals[window.stable_id]
            table.insert(targets, {id = window.stable_id, x = r.cx, y = r.cy,
                sx = r.cx, sy = r.cy, w = r.cw, h = r.ch})
        end
        local area = bounds(hl.get_active_monitor())
        area.left, area.right = area.left - group.x, area.right - group.x
        area.top, area.bottom = area.top - group.y, area.bottom - group.y
        Layout.scatter(targets, area)
        animate(group, targets)
    end
    local function restore(group)
        motion = nil
        local current, live = {}, {}
        local focus, cursor = hl.get_active_window(), hl.get_cursor_pos()
        local trees, exact = {}, true
        for _, window in ipairs(hl.get_windows()) do
            local r = originals[window.stable_id]
            if group and eligible(window) and not window.floating and not r
                and window.monitor.id == group.monitor and window.workspace.id == group.workspace then
                error("A new tiled app occupies the saved workspace; move it elsewhere before exact restoration")
            end
            if r and (not group or (r.group_monitor == group.monitor and r.group_workspace == group.workspace)) then
                if eligible(window) and window.monitor.id == r.monitor and window.workspace.id == r.workspace then
                    table.insert(current, window); live[window.stable_id] = window
                    if r.floating or r.new then exact = false end
                end
            end
        end
        for _, saved_group in pairs(groups) do
            if not group or saved_group == group then
                if saved_group.scrolling then exact = false end
                if not saved_group.tree and not saved_group.scrolling then
                    local records = {}
                    for id, r in pairs(originals) do
                        if r.group_monitor == saved_group.monitor and r.group_workspace == saved_group.workspace
                            and r.dwindle and not r.floating and not r.new then
                            table.insert(records, {id = id, x = r.x, y = r.y, w = r.w, h = r.h})
                        end
                    end
                    if #records > 0 then
                        saved_group.tree = Layout.capture(records, hl.get_config("general:border_size"), hl.get_config("general:gaps_in"))
                        save()
                    end
                end
                local tree = Layout.prune(saved_group.tree, live)
                if tree then table.insert(trees, tree) end
                if saved_group.tree and not Layout.complete(saved_group.tree, live) then exact = false end
            end
        end
        -- Rebuild the saved partition, including its ratios, rather than choosing nearby leaves.
        for _, window in ipairs(current) do
            if not window.floating and #trees > 0 then
                hl.dispatch(hl.dsp.window.float({window = "address:" .. window.address, action = "toggle"}))
            end
        end
        for _, tree in ipairs(trees) do Layout.replay(tree, live) end
        -- left to right, then top to bottom as they were tiled: layouts that keep an order (Scrollable) keep theirs
        table.sort(current, function(a, b)
            local ra, rb = originals[a.stable_id], originals[b.stable_id]
            if ra.x ~= rb.x then return ra.x < rb.x end
            if ra.y ~= rb.y then return ra.y < rb.y end
            return a.stable_id < b.stable_id
        end)
        -- Rebuild the old partition first, then let Dwindle make room for every additional window. Each window
        -- first gets its own size back, so a size changed on the canvas never leaks into the tiled layout.
        for _, window in ipairs(current) do
            if window.floating then
                local r = originals[window.stable_id]
                if r and not r.floating then geometry(window, r.x, r.y, r.w, r.h) end
                hl.dispatch(hl.dsp.window.float({window = "address:" .. window.address, action = "toggle"}))
            end
        end
        hl.dispatch(hl.dsp.cursor.move({x = cursor.x, y = cursor.y}))
        if eligible(focus) then hl.dispatch(hl.dsp.focus({window = "address:" .. focus.address})) end
        if exact then
            for _, window in ipairs(current) do
                local r = originals[window.stable_id]
                assert(window.at.x == r.x and window.at.y == r.y and window.size.x == r.w and window.size.y == r.h,
                    "Layout restoration differs from its snapshot; recovery state retained")
            end
        end
        for id, record in pairs(originals) do
            if not group or (record.group_monitor == group.monitor and record.group_workspace == group.workspace) then originals[id] = nil end
        end
    end
    -- Toggles the mode on one workspace of a monitor; turning it on needs at least one window there.
    local function toggle_workspace(monitor, workspace)
        local key = group_key(monitor.id, workspace.id)
        local group = groups[key]
        if group then
            restore(group); groups[key] = nil
            if _G.AnserinScrollable and AnserinScrollable.resume then AnserinScrollable.resume(workspace) end
        else
            group = {monitor = monitor.id, workspace = workspace.id, x = 0, y = 0}
            local current = windows(group)
            if #current == 0 then return end
            local scrolling = _G.AnserinScrollable and AnserinScrollable.manages(workspace)
            if scrolling then group.scrolling = true end
            local records = {}
            for _, window in ipairs(hl.get_windows()) do
                if eligible(window) and not window.floating and window.monitor.id == group.monitor and window.workspace.id == group.workspace then
                    assert(window.layout and (window.layout.name == "dwindle" or scrolling) and not window.group,
                        "Exact restore currently requires ungrouped Dwindle windows; mode was not enabled")
                    table.insert(records, {id = window.stable_id, x = window.at.x, y = window.at.y, w = window.size.x, h = window.size.y})
                end
            end
            if #records > 0 and not scrolling then
                group.tree = Layout.capture(records, hl.get_config("general:border_size"), hl.get_config("general:gaps_in"))
            end
            groups[key] = group
            if scrolling then AnserinScrollable.suspend(workspace) end
            save()
            for _, window in ipairs(current) do remember(window) end
            for _, window in ipairs(current) do attach(window, group) end
            arrange(group)
        end
        api.enabled = current_group() ~= nil
        save()
    end
    function api.toggle()
        local monitor = hl.get_active_monitor()
        if not monitor or not monitor.active_workspace or monitor.active_special_workspace or monitor.active_workspace.id < 1 then return end
        toggle_workspace(monitor, monitor.active_workspace)
    end
    -- For checks: the same toggle on a workspace that is not shown, leaving focus and the cursor where they are.
    function api.toggle_hidden(workspace_id)
        local workspace = hl.get_workspace(workspace_id)
        assert(workspace and workspace.monitor and workspace.id > 0, "No such workspace")
        local monitor = workspace.monitor
        assert(not (monitor.active_workspace and monitor.active_workspace.id == workspace.id), "Workspace is on screen")
        local focus = hl.get_active_window()
        toggle_workspace(monitor, workspace)
        if focus and eligible(focus) then hl.dispatch(hl.dsp.focus({window = "address:" .. focus.address})) end
    end
    function api.arrange() local group = current_group(); if group then arrange(group) end end
    function api.restore()
        restore(); groups = {}; originals = {}; api.enabled = false; save()
    end
    function api.pan(dx, dy, screen)
        assert(type(dx) == "number" and type(dy) == "number" and math.abs(dx) < math.huge and math.abs(dy) < math.huge, "Invalid pan delta")
        local group, monitor = current_group(), hl.get_active_monitor()
        if not group or (screen and monitor.name ~= screen) then return end
        motion = nil
        sync_positions(group)
        group.x, group.y = group.x + dx, group.y + dy
        render(group)
        dirty = true
        if timer then timer:set_timeout(16) end
    end
    -- Panning: dragging the empty desktop (Anserin; the shell says when the left button goes down and up and keeps the
    -- drag alive with pan_alive) or holding the pan keys (custom). The cursor stays where the pan began, brought back
    -- every frame, so the canvas moves PAN_SPEED times as far as the mouse, past the screen's edges.
    local grab
    -- While panning, the real cursor is hidden and the shell draws a still copy where the pan began
    -- (options.cursor_file holds "x y" during a pan and is empty otherwise).
    local function freeze_cursor(point)
        hl.config({cursor = {invisible = point ~= nil}})
        if not options.cursor_file then return end
        local file = io.open(options.cursor_file .. ".tmp", "w")
        if not file then return end
        file:write(point and string.format("%d %d\n", math.floor(point.x + .5), math.floor(point.y + .5)) or "\n")
        file:close()
        os.rename(options.cursor_file .. ".tmp", options.cursor_file)
    end
    local function start_grab(group, keys)
        local cursor = hl.get_cursor_pos()
        freeze_cursor(cursor)
        motion = nil
        sync_positions(group)
        grab = {group = group, x = cursor.x, y = cursor.y, alive = 0, keys = keys}
        -- a pan held with the toggle's keys is not a tap
        if keys and tap then tap.used = true end
        if timer then timer:set_timeout(16) end
    end
    function api.pan_begin(screen)
        local group, monitor = current_group(), hl.get_active_monitor()
        if pan_mode ~= "anserin" or not group or (screen and monitor.name ~= screen) or grab then return end
        start_grab(group, false)
    end
    function api.pan_alive() if grab then grab.alive = 0 end end
    function api.pan_end()
        if not grab then return end
        local g = grab
        grab = nil
        hl.dispatch(hl.dsp.cursor.move({x = g.x, y = g.y}))
        freeze_cursor(nil)
        save()
    end
    local function follow_grab()
        local g = grab
        if g.keys then
            if not mods_down(pan_keys) then api.pan_end(); return end
        else g.alive = g.alive + 1 end
        if g.alive > 90 or g.group ~= current_group() then api.pan_end(); return end
        local cursor = hl.get_cursor_pos()
        local dx, dy = cursor.x - g.x, cursor.y - g.y
        if dx == 0 and dy == 0 then return end
        g.group.x, g.group.y = g.group.x + dx * PAN_SPEED, g.group.y + dy * PAN_SPEED
        render(g.group)
        hl.dispatch(hl.dsp.cursor.move({x = g.x, y = g.y}))
        dirty = true
    end
    -- Dragging a window against a screen edge pushes the canvas (as the original repo): once the window is within
    -- EDGE_MARGIN of an edge, the mouse moving further that way slides the rest of the canvas instead, and the cursor
    -- is put back so the window stays at the edge. A drag is a Super hold in which the focused window moved, or a
    -- window that moved by itself within the last few frames (apps dragged by their own title bar).
    local dragging = {}
    local function edge_push(group, super)
        local window = hl.get_active_window()
        if not window or not eligible(window) or not window.floating or not originals[window.stable_id]
            or window.monitor.id ~= group.monitor or window.workspace.id ~= group.workspace then dragging = {}; return end
        local r = originals[window.stable_id]
        local moved = math.abs(window.at.x - group.x - r.cx) > .75 or math.abs(window.at.y - group.y - r.cy) > .75
        if dragging.id ~= window.stable_id then dragging = {id = window.stable_id, held = false, idle = 99} end
        if moved then dragging.idle = 0; if super then dragging.held = true end else dragging.idle = dragging.idle + 1 end
        if not super then dragging.held = false end
        local cursor = hl.get_cursor_pos()
        local last = dragging.cursor
        dragging.cursor = cursor
        if not (dragging.held or dragging.idle < 20) or not last then return end
        local area = bounds(window.monitor)
        local mx, my = cursor.x - last.x, cursor.y - last.y
        local px = ((mx < 0 and window.at.x <= area.left + EDGE_MARGIN)
            or (mx > 0 and window.at.x + window.size.x >= area.right - EDGE_MARGIN)) and mx or 0
        local py = ((my < 0 and window.at.y <= area.top + EDGE_MARGIN)
            or (my > 0 and window.at.y + window.size.y >= area.bottom - EDGE_MARGIN)) and my or 0
        if px == 0 and py == 0 then return end
        motion = nil
        local dx, dy = -px * PAN_SPEED, -py * PAN_SPEED
        group.x, group.y = group.x + dx, group.y + dy
        -- the dragged window keeps its place on screen, so its canvas position moves against the push
        r.cx, r.cy = r.cx - dx, r.cy - dy
        render(group, window.stable_id)
        dragging.cursor = {x = cursor.x - px, y = cursor.y - py}
        hl.dispatch(hl.dsp.cursor.move(dragging.cursor))
        dragging.idle = 0
        dirty = true
    end
    -- A box drawn with the right mouse button on the empty desktop opens a terminal of that size and place (global
    -- layout coordinates). The shell runs the command; the window is matched by its class when it opens.
    local SPAWN_CLASS = "anserin-infterm"
    local spawn
    function api.spawn_terminal(x, y, w, h, command)
        for _, v in ipairs({x, y, w, h}) do assert(type(v) == "number" and math.abs(v) < math.huge, "Invalid terminal box") end
        assert(type(command) == "string" and command ~= "", "Missing terminal command")
        if not current_group() or w < 120 or h < 80 then return end
        spawn = {x = x, y = y, w = w, h = h, frames = 0}
        hl.dispatch(hl.dsp.exec_cmd(command))
        if timer then timer:set_timeout(16) end
    end
    local function place_spawned(window, group)
        local r, box = originals[window.stable_id], spawn
        spawn = nil
        r.cx, r.cy, r.cw, r.ch = box.x - group.x, box.y - group.y, box.w, box.h
        save(); geometry(window, box.x, box.y, box.w, box.h)
    end
    local function center(window)
        local group = current_group()
        if not group or not eligible(window) or window.monitor.id ~= group.monitor or window.workspace.id ~= group.workspace
            or not originals[window.stable_id] or not window.floating then return end
        sync_positions(group)
        local area = bounds(window.monitor)
        local dx = (area.left + area.right - window.size.x) / 2 - window.at.x
        local dy = (area.top + area.bottom - window.size.y) / 2 - window.at.y
        local targets = {}
        for _, item in ipairs(windows(group, true)) do
            local r = originals[item.stable_id]
            table.insert(targets, {id = item.stable_id, sx = r.cx, sy = r.cy, x = r.cx + dx, y = r.cy + dy})
        end
        animate(group, targets)
    end
    -- Keyboard move (custom keys): STEP pixels a press; at a screen edge the window stops and the canvas moves the
    -- other way instead, as the original repo does.
    local DIRS = {left = {-1, 0}, right = {1, 0}, up = {0, -1}, down = {0, 1}}
    local function managed_active(group)
        local window = hl.get_active_window()
        if not group or not window or not eligible(window) or not window.floating or not originals[window.stable_id]
            or window.monitor.id ~= group.monitor or window.workspace.id ~= group.workspace then return nil end
        return window
    end
    function api.move_step(direction)
        local group = current_group()
        local window = managed_active(group)
        if not window or not DIRS[direction] then return end
        motion = nil
        sync_positions(group)
        local r, area = originals[window.stable_id], bounds(window.monitor)
        local dx, dy = DIRS[direction][1] * STEP, DIRS[direction][2] * STEP
        local x, y = group.x + r.cx + dx, group.y + r.cy + dy
        local cx = math.max(area.left, math.min(area.right - r.cw, x))
        local cy = math.max(area.top, math.min(area.bottom - r.ch, y))
        if cx ~= x then group.x = group.x - dx end
        if cy ~= y then group.y = group.y - dy end
        r.cx, r.cy = cx - group.x, cy - group.y
        render(group)
        save()
    end
    -- Keyboard resize (custom keys): right/down grow, left/up shrink (to MIN_SIZE); the top-left corner stays.
    function api.resize_step(direction)
        local group = current_group()
        local window = managed_active(group)
        if not window or not DIRS[direction] then return end
        motion = nil
        sync_positions(group)
        local r = originals[window.stable_id]
        local w = direction == "right" and r.cw + STEP or (direction == "left" and math.max(MIN_SIZE, r.cw - STEP) or r.cw)
        local h = direction == "down" and r.ch + STEP or (direction == "up" and math.max(MIN_SIZE, r.ch - STEP) or r.ch)
        r.cw, r.ch = w, h
        geometry(window, group.x + r.cx, group.y + r.cy, w, h)
        save()
    end
    function api.follow_focus(direction)
        local monitor = hl.get_active_monitor()
        if monitor and not current_group() and _G.AnserinScrollable and AnserinScrollable.manages(monitor.active_workspace) then
            AnserinScrollable.follow_focus(direction); return
        end
        hl.dispatch(hl.dsp.focus({direction = direction}))
        center(hl.get_active_window())
    end

    local function bind(key, callback, flags)
        flags = flags or {}; flags.description = "Mo inf desktop: " .. key
        hl.bind(key, callback, flags)
    end
    local function super_down() return hl.is_key_down("Super_L") or hl.is_key_down("Super_R") end
    local function alt_down() return hl.is_key_down("Alt_L") or hl.is_key_down("Alt_R") end
    local function ctrl_down() return hl.is_key_down("Control_L") or hl.is_key_down("Control_R") end
    local shortcut = options.toggle_shortcut or "SUPER + CTRL"
    local secondary_down = shortcut == "SUPER + ALT" and alt_down or ctrl_down
    if shortcut == "SUPER + ALT" or shortcut == "SUPER + CTRL" then
        local keys = shortcut == "SUPER + ALT" and {"Alt_L", "Alt_R", "Super_L", "Super_R"} or {"Control_L", "Control_R", "Super_L", "Super_R"}
        for _, key in ipairs(keys) do
            bind(key, function()
                if not tap and super_down() and secondary_down() then
                    tap = {cursor = hl.get_cursor_pos(), used = false}
                    if timer then timer:set_timeout(16) end
                end
            end, {ignore_mods = true, non_consuming = true})
        end
    else bind(shortcut, api.toggle) end
    for _, key in ipairs({"mouse_up", "mouse_down", "left", "right", "up", "down"}) do hl.unbind("SUPER + " .. key) end
    -- arrows with the chosen modifiers; a press during a Win + Ctrl / Win + Alt hold keeps that tap from toggling
    local function arrows(mods, callback, flags)
        for _, direction in ipairs({"left", "right", "up", "down"}) do
            local selected = direction
            hl.unbind(mods_text(mods) .. " + " .. selected)
            bind(mods_text(mods) .. " + " .. selected, function() if tap then tap.used = true end; callback(selected) end, flags)
        end
    end
    arrows(navigate_keys, api.follow_focus)
    if move_mode == "custom" then arrows(move_keys, api.move_step, {repeating = true}) end
    if resize_mode == "custom" then arrows(resize_keys, api.resize_step, {repeating = true}) end
    -- Anserin resize: drag a window's edge with the left button (Hyprland's resize_on_border), only while the
    -- workspace in view has the mode on; Hyprland's own value comes back otherwise.
    local initial_border = hl.get_config("general:resize_on_border")
    local border_resize_default = initial_border == true or initial_border == 1
    local border_resize_on
    local function border_resize(on)
        on = on and resize_mode == "anserin"
        if on == border_resize_on then return end
        border_resize_on = on
        hl.config({general = {resize_on_border = on or border_resize_default, extend_border_grab_area = 15}})
    end
    local function place_new(window, group)
        local record = originals[window.stable_id]
        local w, h, gap = record.cw, record.ch, 32
        -- on the workspace in view, a new window opens centred where the cursor points
        if group == current_group() then
            local cursor = hl.get_cursor_pos()
            record.cx, record.cy = cursor.x - w / 2 - group.x, cursor.y - h / 2 - group.y
            save(); geometry(window, cursor.x - w / 2, cursor.y - h / 2)
            return
        end
        -- on another workspace: the free spot nearest its canvas origin
        local cursor = {x = group.x + w / 2, y = group.y + h / 2}
        local others, candidates = {}, {{x = group.x, y = group.y}}
        for _, item in ipairs(windows(group, true)) do
            if item.stable_id ~= window.stable_id then
                table.insert(others, item)
                table.insert(candidates, {x = item.at.x + item.size.x + gap, y = item.at.y})
                table.insert(candidates, {x = item.at.x - w - gap, y = item.at.y})
                table.insert(candidates, {x = item.at.x, y = item.at.y + item.size.y + gap})
                table.insert(candidates, {x = item.at.x, y = item.at.y - h - gap})
            end
        end
        local area = nil
        local best, best_visible, best_distance
        for _, point in ipairs(candidates) do
            local free = true
            for _, item in ipairs(others) do
                if point.x < item.at.x + item.size.x + gap and point.x + w + gap > item.at.x
                    and point.y < item.at.y + item.size.y + gap and point.y + h + gap > item.at.y then free = false; break end
            end
            if free then
                local visible = area ~= nil and point.x >= area.left and point.y >= area.top and point.x + w <= area.right and point.y + h <= area.bottom
                local distance = (point.x + w / 2 - cursor.x)^2 + (point.y + h / 2 - cursor.y)^2
                if not best or (visible and not best_visible) or (visible == best_visible and distance < best_distance) then
                    best, best_visible, best_distance = point, visible, distance
                end
            end
        end
        -- no free spot next to the others (large windows): open past the right of every window instead of failing
        if not best then
            local right = cursor.x - w / 2
            for _, item in ipairs(others) do right = math.max(right, item.at.x + item.size.x + gap) end
            best = {x = right, y = cursor.y - h / 2}
        end
        local r = originals[window.stable_id]
        r.cx, r.cy = best.x - group.x, best.y - group.y
        save(); geometry(window, best.x, best.y)
    end
    -- A new window joins the canvas once it has a real size; it may open before Hyprland knows one.
    local arriving = {}
    local function adopt(window)
        local group = groups[group_key(window.monitor.id, window.workspace.id)]
        if not group then return end
        motion = nil
        sync_positions(group)
        local r = remember(window); r.new = true
        attach(window, group)
        if spawn and window.class == SPAWN_CLASS then place_spawned(window, group) else place_new(window, group) end
    end
    local function adopt_arrivals()
        for id, frames in pairs(arriving) do
            local window
            for _, item in ipairs(hl.get_windows()) do if item.stable_id == id then window = item; break end end
            if not window or frames > 120 then arriving[id] = nil
            elseif eligible(window) then arriving[id] = nil; adopt(window)
            else arriving[id] = frames + 1 end
        end
    end
    hl.on("window.open", function(window)
        if not window or not window.monitor or not window.workspace
            or not groups[group_key(window.monitor.id, window.workspace.id)] then return end
        if eligible(window) then adopt(window)
        else
            -- a paused tiling layout (Scrollable) never sizes it: floating gives it one, then it joins the canvas
            if not window.floating then hl.dispatch(hl.dsp.window.float({window = "address:" .. window.address, action = "toggle"})) end
            arriving[window.stable_id] = 0; if timer then timer:set_timeout(16) end
        end
    end)
    local pending = {}
    hl.on("window.close", function(window)
        if not window or not window.monitor or not window.workspace then return end
        local key = group_key(window.monitor.id, window.workspace.id)
        if groups[key] and originals[window.stable_id] then pending[key] = true; if timer then timer:set_timeout(16) end end
    end)

    -- The mode needs a window: a workspace whose last window closed leaves it by itself (nothing to restore).
    local function drop_empty_groups()
        local changed = false
        for key, group in pairs(groups) do
            if #windows(group) == 0 then
                groups[key] = nil
                for id, r in pairs(originals) do
                    if r.group_monitor == group.monitor and r.group_workspace == group.workspace then originals[id] = nil end
                end
                local workspace = hl.get_workspace(group.workspace)
                if workspace and _G.AnserinScrollable and AnserinScrollable.resume then AnserinScrollable.resume(workspace) end
                changed = true
            end
        end
        if changed then api.enabled = current_group() ~= nil; save() end
    end
    local function tick()
        local super = super_down()
        -- Repeat timers reset their deadline before calling back; re-arm every tick.
        local group = current_group()
        local active = group ~= nil
        local keyed_pan = pan_mode == "custom" and active
        timer:set_timeout((super or tap or motion or grab or spawn or next(arriving) or (dragging.idle or 99) < 20 or next(pending)) and 16
            or (keyed_pan and 33 or 100))
        border_resize(active)
        if keyed_pan and not grab and mods_down(pan_keys) then start_grab(group, true) end
        if api.enabled ~= active then api.enabled = active; save() end
        if spawn then spawn.frames = spawn.frames + 1; if spawn.frames > 600 then spawn = nil end end
        if next(arriving) then adopt_arrivals() end
        if grab then follow_grab(); group = current_group() end
        if group and not grab then edge_push(group, super) end
        if group and sync_positions(group) then motion = nil end
        for key in pairs(pending) do
            local live = {}
            for _, window in ipairs(hl.get_windows()) do if window.mapped then live[window.stable_id] = true end end
            for id in pairs(originals) do if not live[id] then originals[id] = nil end end
            save()
            pending[key] = nil
            drop_empty_groups()
        end
        if tap then
            local cursor = hl.get_cursor_pos()
            if math.abs(cursor.x - tap.cursor.x) > 4 or math.abs(cursor.y - tap.cursor.y) > 4 then tap.used = true end
            if not (super and secondary_down()) then
                local toggle = not tap.used
                tap = nil
                if toggle then api.toggle(); group = current_group() end
            end
        end
        if motion and motion.group ~= group then motion = nil; save() end
        if motion then
            local m = motion
            m.frame = m.frame + 1
            local p = 1 - (1 - m.frame / 12) ^ 3
            for _, target in ipairs(m.targets) do
                local r = originals[target.id]
                if r then r.cx, r.cy = target.sx + (target.x - target.sx) * p, target.sy + (target.y - target.sy) * p end
            end
            render(m.group)
            if m.frame == 12 then motion = nil; save() end
        end
        if dirty and not super and not grab then save() end
    end
    local function start_timer()
        if timer or not hl.get_active_monitor() then return end
        -- Restore legacy recovery records once before starting the rebuilt workspace mode.
        if not next(groups) and next(originals) then restore(); originals = {} end
        if type(legacy_zoom) == "number" and legacy_zoom >= 1 and legacy_zoom <= 10 then
            hl.config({cursor = {zoom_factor = legacy_zoom}}); legacy_zoom = nil
        end
        for _, group in pairs(groups) do
            sync_positions(group)
            for _, window in ipairs(windows(group, true)) do
                local r = originals[window.stable_id]
                r.cx, r.cy = window.at.x - group.x, window.at.y - group.y
                r.cw, r.ch = window.size.x, window.size.y
            end
            group.w, group.h, group.scale, group.columns = nil, nil, nil, nil
        end
        drop_empty_groups()
        api.enabled = current_group() ~= nil
        save()
        timer = hl.timer(tick, {timeout = 100, type = "repeat"})
    end
    hl.on("hyprland.start", start_timer)
    hl.on("config.reloaded", start_timer)
    _G.MoInfiniteDesktop = api
    return api
end
