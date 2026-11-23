-- Dwindle's split tree is not exposed to Lua. Recover its visible partition before floating.
local layout = {}
function layout.scatter(targets, area, random)
    random = random or math.random
    local total, placed = 0, {}
    for _, target in ipairs(targets) do total = total + (target.w + 32) * (target.h + 32) end
    local span = math.sqrt(total * 2)
    local width, height = math.max(area.right - area.left, span), math.max(area.bottom - area.top, span)
    for _, target in ipairs(targets) do
        local found = false
        for attempt = 1, 256 do
            local spread = .65 + math.floor((attempt - 1) / 32) * .25
            local x = (area.left + area.right - target.w) / 2 + (random() - .5) * width * spread
            local y = (area.top + area.bottom - target.h) / 2 + (random() - .5) * height * spread
            local free = true
            for _, other in ipairs(placed) do
                if x < other.x + other.w + 32 and x + target.w + 32 > other.x
                    and y < other.y + other.h + 32 and y + target.h + 32 > other.y then free = false; break end
            end
            if free then target.x, target.y, found = x, y, true; break end
        end
        if not found then
            local right = area.right
            for _, other in ipairs(placed) do right = math.max(right, other.x + other.w) end
            target.x, target.y = right + 32, (area.top + area.bottom - target.h) / 2 + (random() - .5) * height
        end
        table.insert(placed, target)
    end
end
local function finite(value) return type(value) == "number" and math.abs(value) < math.huge end
function layout.validate(node, seen, ids)
    if node == nil then return end
    seen = seen or {}
    ids = ids or {}
    assert(type(node) == "table" and not seen[node], "Invalid saved layout tree")
    seen[node] = true
    if node.id then
        assert(((finite(node.id) and node.id > 0) or (type(node.id) == "string" and node.id ~= "")) and not ids[node.id], "Invalid saved layout window")
        ids[node.id] = true
    else
        assert((node.axis == 1 or node.axis == 2) and finite(node.ratio) and node.ratio >= .1 and node.ratio <= 1.9
            and node.first and node.second, "Invalid saved layout split")
        layout.validate(node.first, seen, ids); layout.validate(node.second, seen, ids)
    end
end
function layout.capture(records, border, gaps)
    if #records == 0 then return nil end
    local left, top, right, bottom = math.huge, math.huge, -math.huge, -math.huge
    for _, r in ipairs(records) do
        left, top = math.min(left, r.x), math.min(top, r.y)
        right, bottom = math.max(right, r.x + r.w), math.max(bottom, r.y + r.h)
    end
    local boxes = {}
    for _, r in ipairs(records) do
        table.insert(boxes, {id = r.id,
            x = r.x - border - (r.x > left and gaps.left or 0),
            y = r.y - border - (r.y > top and gaps.top or 0),
            right = r.x + r.w + border + (r.x + r.w < right and gaps.right or 0),
            bottom = r.y + r.h + border + (r.y + r.h < bottom and gaps.bottom or 0)})
    end
    local function partition(items, x, y, w, h)
        if #items == 1 then return {id = items[1].id} end
        local best
        for axis, key in ipairs({"x", "y"}) do
            local edge, origin, span = axis == 1 and "right" or "bottom", axis == 1 and x or y, axis == 1 and w or h
            table.sort(items, function(a, b) return a[key] == b[key] and a.id < b.id or a[key] < b[key] end)
            local finish = -math.huge
            for i = 1, #items - 1 do
                finish = math.max(finish, items[i][edge])
                local start = items[i + 1][key]
                if math.abs(start - finish) <= 1 then
                    local cut = (finish + start) / 2
                    local ratio = 2 * (cut - origin) / span
                    if ratio >= .1 and ratio <= 1.9 and (not best or math.abs(ratio - 1) < best.score) then
                        local a, b = {}, {}
                        for j, item in ipairs(items) do table.insert(j <= i and a or b, item) end
                        best = {axis = axis, ratio = ratio, cut = cut, first = a, second = b, score = math.abs(ratio - 1)}
                    end
                end
            end
        end
        assert(best, "Cannot snapshot this layout exactly; inf desktop was not enabled")
        local cut = best.cut
        if best.axis == 1 then
            return {axis = 1, ratio = best.ratio, first = partition(best.first, x, y, cut - x, h),
                second = partition(best.second, cut, y, x + w - cut, h)}
        end
        return {axis = 2, ratio = best.ratio, first = partition(best.first, x, y, w, cut - y),
            second = partition(best.second, x, cut, w, y + h - cut)}
    end
    return partition(boxes, left - border, top - border, right - left + 2 * border, bottom - top + 2 * border)
end
function layout.prune(node, live)
    if not node then return nil end
    if node.id then return live[node.id] and {id = node.id} or nil end
    local a, b = layout.prune(node.first, live), layout.prune(node.second, live)
    if not a then return b end
    if not b then return a end
    return {axis = node.axis, ratio = node.ratio, first = a, second = b}
end
function layout.complete(node, live)
    if not node then return true end
    if node.id then return live[node.id] ~= nil end
    return layout.complete(node.first, live) and layout.complete(node.second, live)
end
function layout.replay(tree, live)
    if not tree then return end
    local function first(node) return node.id or first(node.first) end
    local function tile(id)
        local window = live[id]
        if window.floating then hl.dispatch(hl.dsp.window.float({window = "address:" .. window.address, action = "toggle"})) end
    end
    local function split(node)
        if node.id then return end
        local a, b = live[first(node.first)], live[first(node.second)]
        hl.dispatch(hl.dsp.focus({window = "address:" .. a.address}))
        hl.dispatch(hl.dsp.cursor.move({x = a.at.x + a.size.x / 2, y = a.at.y + a.size.y / 2}))
        hl.dispatch(hl.dsp.layout("preselect " .. (node.axis == 1 and "right" or "down")))
        tile(b.stable_id)
        hl.dispatch(hl.dsp.focus({window = "address:" .. a.address}))
        hl.dispatch(hl.dsp.layout(string.format("splitratio %.17g exact", node.ratio)))
        split(node.first); split(node.second)
    end
    tile(first(tree)); split(tree)
    hl.dispatch(hl.dsp.layout("preselect none"))
end
return layout
