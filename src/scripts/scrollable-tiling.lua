return function(options)
    local Model = dofile(options.model_file)
    local Layout = dofile(options.layout_file)
    local name = "lua:anserin-scroll"
    local api = {enabled = false, manages = function() return false end}
    local session = os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or ""
    local saved = {session = session, mode = options.mode, apps = options.apps, enabled = true, workspaces = {}}
    local placements, suspended, boxes, closing = {}, {}, {}, {}
    local target_orders = {}
    local drag, timer
    local update_resize_binding
    local seeding = true
    local wants = options.mode ~= "hyprland" or options.apps

    local function encode(value)
        if type(value) == "table" then
            local parts = {"{"}
            for key, item in pairs(value) do
                assert(type(key) == "string" or type(key) == "number", "Invalid scroll state key")
                table.insert(parts, "[" .. encode(key) .. "]=" .. encode(item) .. ",")
            end
            table.insert(parts, "}"); return table.concat(parts)
        end
        if type(value) == "string" then return string.format("%q", value) end
        assert(type(value) == "boolean" or (type(value) == "number" and math.abs(value) < math.huge), "Invalid scroll state value")
        return tostring(value)
    end
    local last_saved
    local function save()
        local content = "return " .. encode(saved) .. "\n"
        if content == last_saved then return end
        local file = assert(io.open(options.state_file .. ".tmp", "w"))
        assert(file:write(content)); assert(file:close())
        assert(os.rename(options.state_file .. ".tmp", options.state_file))
        last_saved = content
    end
    local loader, err = loadfile(options.state_file, "t", {})
    if loader then
        local ok, old = pcall(loader)
        assert(ok and type(old) == "table" and type(old.workspaces) == "table", "Cannot read Scrollable Tiling state")
        if old.session == session and old.enabled and old.mode == options.mode and old.apps == options.apps then
            for key, state in pairs(old.workspaces) do
                assert(type(key) == "number" and type(state) == "table" and type(state.pages) == "table", "Invalid scroll workspace")
                for _, page in ipairs(state.pages) do
                    assert(type(page) == "table" and (page.native == nil or type(page.native) == "boolean"), "Invalid scroll page")
                    page.native = page.native == true
                    Layout.validate(page.tree)
                end
                assert(state.focus == nil or type(state.focus) == "number", "Invalid scroll focus")
            end
            saved = old
        end
    else
        local file = io.open(options.state_file, "r")
        if file then file:close(); error("Cannot read Scrollable Tiling state: " .. tostring(err)) end
    end
    _G.AnserinScrollable = api
    if not wants then
        if loader then saved.enabled = false; save() end
        return api
    end
    for _, window in ipairs(hl.get_windows()) do
        if window.mapped then placements[window.stable_id] = {existing = true} end
    end

    local function eligible(window)
        return window and window.mapped and not window.hidden and not window.pinned and not window.floating
            and window.workspace and window.workspace.id > 0 and window.monitor and not closing[window.stable_id]
    end
    local function is_suspended(workspace)
        return suspended[workspace.id] or (_G.MoInfiniteDesktop and MoInfiniteDesktop.is_active(workspace.monitor.id, workspace.id))
    end
    local function hovered(exclude)
        local cursor = hl.get_cursor_pos()
        if not cursor then return nil end
        for _, window in ipairs(hl.get_windows()) do
            if eligible(window) and window.stable_id ~= exclude and window.workspace.visible
                and cursor.x >= window.at.x and cursor.x < window.at.x + window.size.x
                and cursor.y >= window.at.y and cursor.y < window.at.y + window.size.y then return window end
        end
    end
    local function refresh()
        local workspace = hl.get_active_workspace()
        if api.enabled and workspace and workspace.tiled_layout == name and not is_suspended(workspace) then
            hl.dispatch(hl.dsp.layout("anserin-refresh"))
        end
    end
    local function recalculate(ctx)
        local first = ctx.targets[1] and ctx.targets[1].window
        if not first or not first.workspace then return end
        local workspace = first.workspace
        if is_suspended(workspace) then return end
        for id, window in pairs(closing) do if not window.mapped then closing[id] = nil end end
        local state = saved.workspaces[workspace.id] or {pages = {}}
        saved.workspaces[workspace.id] = state
        local target_order = {}
        for _, target in ipairs(ctx.targets) do
            if target.window then table.insert(target_order, target.window.stable_id) end
        end
        Model.reorder(state, target_orders[workspace.id], target_order)
        target_orders[workspace.id] = target_order
        local live, order = {}, {}
        for _, window in ipairs(hl.get_windows()) do
            if eligible(window) and window.workspace.id == workspace.id then
                live[window.stable_id] = window; table.insert(order, window.stable_id)
            end
        end
        table.sort(order)
        for _, id in ipairs(order) do
            if not Model.page(state, id) and not placements[id] and not seeding then
                local hit = hovered(id)
                placements[id] = {anchor = hit and hit.stable_id}
            end
        end
        Model.sync(state, live, order, options.mode, options.apps, placements, seeding, ctx.area)
        for _, id in ipairs(order) do placements[id] = nil end
        local active = hl.get_active_window()
        if active and live[active.stable_id] then state.focus = active.stable_id end
        local selected = Model.page(state, state.focus) or 1
        local monitor = workspace.monitor
        local span = options.vertical and monitor.height / monitor.scale or monitor.width / monitor.scale
        if monitor.transform % 2 == 1 then span = options.vertical and monitor.width / monitor.scale or monitor.height / monitor.scale end
        local positions = {}
        for i, page in ipairs(state.pages) do
            local area = {x = ctx.area.x, y = ctx.area.y, w = ctx.area.w, h = ctx.area.h}
            if options.vertical then area.y = area.y + (i - selected) * span
            else area.x = area.x + (i - selected) * span end
            Model.boxes(page.tree, area, positions)
        end
        boxes[workspace.id] = positions
        if not drag then save() end
        for _, target in ipairs(ctx.targets) do
            local window = target.window
            local position = window and positions[window.stable_id]
            if not window or not closing[window.stable_id] then target:place(position and position.box or ctx.area) end
        end
    end
    hl.layout.register("anserin-scroll", {recalculate = recalculate, layout_msg = function(_, message)
        local window = hl.get_active_window()
        local positions = window and window.workspace and boxes[window.workspace.id]
        local position = positions and positions[window.stable_id]
        local split = position and position.path[#position.path]
        if message == "togglesplit" and split then
            split.node.axis = split.node.axis == 1 and 2 or 1
            save()
        end
        return true
    end})

    hl.workspace_rule({workspace = "s[true]", layout = hl.get_config("general:layout")})

    local function activate()
        if _G.MoInfiniteDesktop and MoInfiniteDesktop.has_native_groups() then return end
        api.enabled = true
        hl.config({general = {layout = name}})
        if update_resize_binding then update_resize_binding() end
    end
    function api.manages(workspace)
        return api.enabled and workspace and workspace.tiled_layout == name
    end
    function api.suspend(workspace)
        suspended[workspace.id] = true; save()
        if update_resize_binding then update_resize_binding() end
    end
    function api.resume(workspace)
        suspended[workspace.id] = nil
        activate(); refresh()
    end
    local function focus_window(id)
        for _, window in ipairs(hl.get_windows()) do
            if eligible(window) and window.stable_id == id then
                local cursor = hl.get_cursor_pos()
                hl.dispatch(hl.dsp.focus({window = "address:" .. window.address}))
                if cursor then hl.dispatch(hl.dsp.cursor.move({x = cursor.x, y = cursor.y})) end
                return
            end
        end
    end
    function api.step(direction, screen)
        local monitor = hl.get_monitor(screen)
        local workspace = monitor and monitor.active_workspace
        if not api.manages(workspace) or monitor.active_special_workspace or is_suspended(workspace) then return end
        local state = saved.workspaces[workspace.id]
        if not state or #state.pages < 2 then return end
        local current = Model.page(state, state.focus) or 1
        local index = math.max(1, math.min(#state.pages, current + (direction > 0 and 1 or -1)))
        if index == current then return end
        focus_window(Model.first(state.pages[index].tree))
    end
    function api.follow_focus(direction)
        local window = hl.get_active_window()
        local workspace = window and window.workspace
        local state = workspace and saved.workspaces[workspace.id]
        local positions = workspace and boxes[workspace.id]
        local position = positions and positions[window.stable_id]
        if not eligible(window) or not state or not position or is_suspended(workspace) then
            hl.dispatch(hl.dsp.focus({direction = direction})); return
        end
        local _, page = Model.page(state, window.stable_id)
        local horizontal = direction == "left" or direction == "right"
        local sign = (direction == "left" or direction == "up") and -1 or 1
        local current = position.box
        local best, score
        for id, item in pairs(positions) do
            if id ~= window.stable_id and Model.contains(page.tree, id) then
                local dx = item.box.x + item.box.w / 2 - current.x - current.w / 2
                local dy = item.box.y + item.box.h / 2 - current.y - current.h / 2
                local forward = (horizontal and dx or dy) * sign
                local distance = forward + math.abs(horizontal and dy or dx) * 2
                if forward > 1 and (not score or distance < score or (distance == score and id < best)) then
                    best, score = id, distance
                end
            end
        end
        if best then focus_window(best)
        elseif horizontal ~= options.vertical then api.step(sign, workspace.monitor.name)
        else hl.dispatch(hl.dsp.focus({direction = direction})) end
    end
    function api.resize(dx, dy)
        local window = hl.get_active_window()
        local workspace = window and window.workspace
        local positions = workspace and boxes[workspace.id]
        local position = positions and positions[window.stable_id]
        if not eligible(window) or not api.manages(workspace) or not position or is_suspended(workspace) then return false end
        assert(type(dx) == "number" and type(dy) == "number" and math.abs(dx) < math.huge and math.abs(dy) < math.huge, "Invalid resize delta")
        local axes = {}
        for i = #position.path, 1, -1 do
            local item = position.path[i]
            if not axes[item.node.axis] then
                axes[item.node.axis] = true
                local extent = item.node.axis == 1 and item.area.w or item.area.h
                local delta = item.node.axis == 1 and dx or dy
                item.node.ratio = math.max(.1, math.min(1.9, item.node.ratio + 2 * delta / extent * (item.first and 1 or -1)))
            end
        end
        refresh(); return true
    end
    hl.on("window.open_early", function(window)
        if window then local hit = hovered(window.stable_id); placements[window.stable_id] = {anchor = hit and hit.stable_id} end
    end)
    hl.on("window.close", function(window)
        if not window or not window.stable_id then return end
        closing[window.stable_id], placements[window.stable_id] = window, nil
        local workspace = window.workspace
        local state = workspace and saved.workspaces[workspace.id]
        if not state or is_suspended(workspace) then return end
        local page_index, closing_page = Model.page(state, window.stable_id)
        local focused = hl.get_active_window()
        local live = {}
        for _, item in ipairs(hl.get_windows()) do
            if eligible(item) and item.workspace.id == workspace.id then live[item.stable_id] = item end
        end
        for i = #state.pages, 1, -1 do
            local page = state.pages[i]
            page.tree = Model.prune(page.tree, live)
            if not page.tree then table.remove(state.pages, i) end
        end
        if #state.pages == 0 then
            saved.workspaces[workspace.id], boxes[workspace.id], target_orders[workspace.id] = nil, nil, nil
        end
        if closing_page and focused and focused.stable_id == window.stable_id and window.fullscreen == 0 then
            local page = closing_page.tree and closing_page or state.pages[math.min(page_index, #state.pages)]
            if page then focus_window(Model.first(page.tree)) end
        end
        save()
    end)
    hl.on("window.active", refresh)
    hl.on("workspace.active", refresh)
    hl.on("workspace.removed", function(workspace)
        if workspace and workspace.id then
            saved.workspaces[workspace.id], boxes[workspace.id], target_orders[workspace.id] = nil, nil, nil
            save()
        end
    end)
    hl.on("config.reloaded", function() seeding = false; refresh() end)
    hl.on("hyprland.start", function() seeding = false end)

    local function stop_drag()
        drag = nil
        if timer then timer:set_enabled(false) end
        save()
    end
    local function resize_tick()
        if not drag or not (hl.is_key_down("Super_L") or hl.is_key_down("Super_R")) then stop_drag(); return end
        local cursor = hl.get_cursor_pos()
        local dx, dy = cursor.x - drag.cursor.x, cursor.y - drag.cursor.y
        for _, item in ipairs(drag.path) do
            local extent = item.node.axis == 1 and item.area.w or item.area.h
            local delta = item.node.axis == 1 and dx or dy
            item.node.ratio = math.max(.1, math.min(1.9, item.ratio + 2 * delta / extent * item.sign))
        end
        refresh()
    end
    local function resize_split()
        local window = hovered()
        local positions = window and boxes[window.workspace.id]
        local position = positions and positions[window.stable_id]
        if not window or not api.manages(window.workspace) or is_suspended(window.workspace) or not position then
            local native_resize = hl.dsp.window.resize()
            native_resize(); return
        end
        local path, axes = {}, {}
        for i = #position.path, 1, -1 do
            local item = position.path[i]
            if not axes[item.node.axis] then
                axes[item.node.axis] = true
                table.insert(path, {node = item.node, area = item.area, ratio = item.node.ratio, sign = item.first and 1 or -1})
            end
        end
        if #path == 0 then return end
        drag = {cursor = hl.get_cursor_pos(), path = path}
        if not timer then timer = hl.timer(resize_tick, {timeout = 16, type = "repeat"})
        else timer:set_enabled(true) end
    end
    local custom_resize
    update_resize_binding = function()
        local workspace, window = hl.get_active_workspace(), hl.get_active_window()
        local custom = api.manages(workspace) and not is_suspended(workspace) and not (window and window.floating)
        if custom_resize == custom then return end
        custom_resize = custom
        hl.unbind("SUPER + mouse:273")
        if custom then
            hl.bind("SUPER + mouse:273", resize_split, {description = "Anserin Scrollable Tiling: resize"})
        else
            stop_drag()
            hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), {mouse = true})
        end
    end
    hl.on("window.active", update_resize_binding)
    hl.on("workspace.active", update_resize_binding)
    hl.on("monitor.focused", update_resize_binding)
    hl.bind("mouse:273", stop_drag, {release = true, ignore_mods = true, non_consuming = true})
    activate()
    return api
end
