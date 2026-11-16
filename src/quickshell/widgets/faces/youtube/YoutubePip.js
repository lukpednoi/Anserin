.pragma library

// Brave has one PiP window; only one widget may control it.
var owner = null;

function isYoutube(url) {
    return /^https:\/\/(www\.|m\.)?(youtube\.com|youtu\.be)\//i.test(String(url || ""));
}

function session(players) {
    for (const player of players) {
        const match = String(player.dbusName || "").match(/(?:^|\.)brave\.instance(\d+)$/);
        if (!match) continue;
        const metadata = player.metadata || {};
        if (isYoutube(metadata["xesam:url"])) return { pid: Number(match[1]) };
        // Brave omits the URL; Plasma's existing browser integration supplies it.
        if (!metadata["xesam:url"] && players.some(other =>
            /(?:^|\.)plasma-browser-integration$/.test(other.dbusName || "")
            && Number((other.metadata || {})["kde:pid"]) === Number(match[1])
            && isYoutube((other.metadata || {})["xesam:url"]))) {
            return { pid: Number(match[1]) };
        }
    }
    return null;
}

function findPip(clients, pid) {
    // shortcut: PiP titles cover English and Thai; extend when Brave's UI language changes.
    return clients.find(client => client.pid === pid && client.mapped && !client.hidden
        && /^brave(?:-browser)?(?:-(?:beta|nightly))?$/.test(client.class)
        && /^(picture.in.picture|การแสดงภาพซ้อนภาพ)$/i.test(client.title)
        && client.workspace && client.workspace.id > 0
        && /^[0-9a-f]+$/i.test(client.stableId)
        && /^0x[0-9a-f]+$/i.test(client.address)) || null;
}

function geometry(window) {
    return { x: Math.round(window.screen.x + window.wX), y: Math.round(window.screen.y + window.wY),
        w: Math.round(window.effectiveWidth), h: Math.round(window.effectiveHeight) };
}

function sameGeometry(a, b) {
    return a !== null && b !== null && a.x === b.x && a.y === b.y && a.w === b.w && a.h === b.h;
}

function containsPoint(rect, x, y) {
    return x >= rect.x && y >= rect.y && x < rect.x + rect.w && y < rect.y + rect.h;
}

function resizeEdges(rect, x, y, margin) {
    return {left: x < rect.x + margin, right: x >= rect.x + rect.w - margin,
        top: y < rect.y + margin, bottom: y >= rect.y + rect.h - margin};
}

function pointerGeometry(rect, edges, dx, dy) {
    const horizontal = edges.left || edges.right;
    const vertical = edges.top || edges.bottom;
    if (!horizontal && !vertical) return {x: rect.x + dx, y: rect.y + dy, w: rect.w, h: rect.h};
    const dw = edges.left ? -dx : dx;
    const dh = edges.top ? -dy : dy;
    // Project corner drags onto the video's aspect ratio; keep the opposite edge anchored.
    let scale;
    if (horizontal && vertical) scale = 1 + (dw * rect.w + dh * rect.h) / (rect.w * rect.w + rect.h * rect.h);
    else if (horizontal) scale = 1 + dw / rect.w;
    else scale = 1 + dh / rect.h;
    scale = Math.max(scale, 1 / rect.w, 1 / rect.h);
    const w = Math.round(rect.w * scale), h = Math.round(rect.h * scale);
    return {x: edges.left ? rect.x + rect.w - w : rect.x,
        y: edges.top ? rect.y + rect.h - h : rect.y, w: w, h: h};
}

function draggedGeometry(client, target, lastTarget) {
    const actual = {x: client.at[0], y: client.at[1], w: client.size[0], h: client.size[1]};
    return client.floating && sameGeometry(target, lastTarget) && !sameGeometry(target, actual) ? actual : null;
}

function command(client, target, restore, layoutFile) {
    if (!client || !/^[0-9a-f]+$/i.test(client.stableId)
        || !Number.isSafeInteger(client.pid) || client.pid <= 0
        || !client.workspace || !Number.isSafeInteger(client.workspace.id)
        || ![target.x, target.y, target.w, target.h].every(Number.isFinite)
        || target.w <= 0 || target.h <= 0) return "";
    const pinned = restore ? !!client.pinned : true;
    let actions = "";
    if (!restore || client.workspace.id > 0) {
        actions += "hl.dispatch(hl.dsp.window.float({window=w,action='enable'}));";
        if (restore) actions += "hl.dispatch(hl.dsp.window.pin({window=w,action='disable'}));"
            + "hl.dispatch(hl.dsp.window.move({window=w,workspace=" + client.workspace.id + ",follow=false}));";
        actions += "hl.dispatch(hl.dsp.window.resize({window=w,x=" + Math.round(target.w) + ",y=" + Math.round(target.h) + ",relative=false}));"
            + "hl.dispatch(hl.dsp.window.move({window=w,x=" + Math.round(target.x) + ",y=" + Math.round(target.y) + ",relative=false}));"
            + "hl.dispatch(hl.dsp.window.pin({window=w,action='" + (pinned ? "enable" : "disable") + "'}));";
        if (!restore) actions += "hl.dispatch(hl.dsp.window.alter_zorder({window=w,mode='top'}));";
    }
    if (restore && !client.floating) {
        if (!layoutFile || !Array.isArray(client.tiledPeers) || !client.tiledPeers.length) return "";
        const records = [];
        for (const peer of client.tiledPeers) {
            if (!/^[0-9a-f]+$/i.test(peer.stableId) || ![...peer.at, ...peer.size].every(Number.isFinite)) return "";
            records.push("{id=tonumber('" + peer.stableId + "',16),x=" + peer.at[0] + ",y=" + peer.at[1] + ",w=" + peer.size[0] + ",h=" + peer.size[1] + "}");
        }
        // Reuse the existing Dwindle recovery, including split order and ratios.
        actions += "local L=dofile(" + JSON.stringify(layoutFile) + ");"
            + "local tree=L.capture({" + records.join(",") + "},hl.get_config('general:border_size'),hl.get_config('general:gaps_in'));"
            + "local ids={};for _,r in ipairs({" + records.join(",") + "}) do ids[r.id]=true end;"
            + "local live={};for _,a in ipairs(hl.get_windows()) do "
            + "if a.workspace.id==w.workspace.id and a.monitor.id==w.monitor.id and a.mapped and not a.hidden then "
            + "assert(a.floating or ids[a.stable_id],'PiP layout changed; keeping current tiling');"
            + "if ids[a.stable_id] then live[a.stable_id]=a end end end;"
            + "local focus,cursor=hl.get_active_window(),hl.get_cursor_pos();"
            + "for _,a in pairs(live) do if not a.floating then hl.dispatch(hl.dsp.window.float({window=a,action='enable'})) end end;"
            + "L.replay(L.prune(tree,live),live);"
            + "hl.dispatch(hl.dsp.cursor.move({x=cursor.x,y=cursor.y}));"
            + "if focus and focus.mapped then hl.dispatch(hl.dsp.focus({window=focus})) end;";
    }
    // Match both identity and PID again when Hyprland executes the request.
    return "for _,w in ipairs(hl.get_windows()) do if w.stable_id==tonumber('" + client.stableId
        + "',16) and w.pid==" + client.pid + " then " + actions + "break end end";
}
