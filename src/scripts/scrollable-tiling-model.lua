local M = {}

function M.first(tree)
    return tree.id or M.first(tree.first)
end

function M.contains(tree, id)
    return tree and id ~= nil and (tree.id == id or (not tree.id and (M.contains(tree.first, id) or M.contains(tree.second, id))))
end

function M.prune(tree, live)
    if not tree then return nil end
    if tree.id then return live[tree.id] and tree or nil end
    tree.first, tree.second = M.prune(tree.first, live), M.prune(tree.second, live)
    if not tree.first then return tree.second end
    if not tree.second then return tree.first end
    return tree
end

function M.insert(tree, anchor, id, horizontal)
    if not tree then return {id = id} end
    if tree.id then
        return {axis = horizontal and 1 or 2, ratio = 1, first = tree, second = {id = id}}
    end
    if M.contains(tree.first, anchor) then tree.first = M.insert(tree.first, anchor, id, horizontal)
    else tree.second = M.insert(tree.second, anchor, id, horizontal) end
    return tree
end

function M.page(state, id)
    for i, page in ipairs(state.pages) do
        if M.contains(page.tree, id) then return i, page end
    end
end

function M.reorder(state, before, after)
    if not before or #before ~= #after then return end
    local present, replacements = {}, {}
    for _, id in ipairs(before) do present[id] = true end
    for i, id in ipairs(after) do
        if not present[id] then return end
        replacements[before[i]] = id
    end
    local function replace(tree)
        if tree.id then tree.id = replacements[tree.id] or tree.id
        else replace(tree.first); replace(tree.second) end
    end
    for _, page in ipairs(state.pages) do replace(page.tree) end
end

function M.sync(state, live, order, mode, apps, placements, seeding, area)
    for i = #state.pages, 1, -1 do
        local page = state.pages[i]
        page.tree = M.prune(page.tree, live)
        if not page.tree then table.remove(state.pages, i) end
    end
    for _, id in ipairs(order) do
        if not M.page(state, id) then
            local window, placement = live[id], placements[id] or {}
            local existing = seeding or placement.existing == true
            local terminal = window.class == "kitty"
            local scrolling = terminal and mode ~= "hyprland" or not terminal and apps
            local anchor = placement.anchor
            local index, page
            if terminal and mode == "hybrid" and anchor and live[anchor] and live[anchor].class == "kitty" then
                index, page = M.page(state, anchor)
            elseif not scrolling or (existing and terminal and mode == "hybrid") then
                if not existing then index, page = M.page(state, anchor or state.focus) end
                if not page then
                    for i, item in ipairs(state.pages) do
                        if item.native then index, page = i, item; break end
                    end
                end
            end
            if page then
                local positions = area and M.boxes(page.tree, area)
                if not M.contains(page.tree, anchor) then
                    anchor = M.first(page.tree)
                    if existing and positions then
                        local largest = -1
                        for candidate, item in pairs(positions) do
                            local size = item.box.w * item.box.h
                            if size > largest or (size == largest and candidate < anchor) then anchor, largest = candidate, size end
                        end
                    end
                end
                local source = live[anchor]
                local box = positions and positions[anchor].box
                local width, height = source.size.x, source.size.y
                if box then width, height = box.w, box.h end
                page.tree = M.insert(page.tree, anchor, id, width >= height)
            else
                page = {tree = {id = id}, native = not scrolling or (existing and terminal and mode == "hybrid")}
                -- Every new page follows the current page along the positive axis.
                local current = state.focus and M.page(state, state.focus)
                table.insert(state.pages, current and current + 1 or #state.pages + 1, page)
            end
        end
    end
    if not M.page(state, state.focus) then state.focus = state.pages[1] and M.first(state.pages[1].tree) end
end

function M.boxes(tree, area, result, path)
    result, path = result or {}, path or {}
    if tree.id then
        result[tree.id] = {box = area, path = path}
        return result
    end
    local a = {x = area.x, y = area.y, w = area.w, h = area.h}
    local b = {x = area.x, y = area.y, w = area.w, h = area.h}
    if tree.axis == 1 then
        a.w = area.w * tree.ratio / 2; b.x, b.w = area.x + a.w, area.w - a.w
    else
        a.h = area.h * tree.ratio / 2; b.y, b.h = area.y + a.h, area.h - a.h
    end
    local function descend(child, box, first)
        local next_path = {}
        for i, item in ipairs(path) do next_path[i] = item end
        table.insert(next_path, {node = tree, area = area, first = first})
        M.boxes(child, box, result, next_path)
    end
    descend(tree.first, a, true); descend(tree.second, b, false)
    return result
end

return M
