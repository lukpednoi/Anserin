pragma Singleton
import QtQuick
import Quickshell
import "../"

// What the left edge panel's sidebar holds, shared by the panel, Edit panel and the Control Center's Panel page.
// settings.json:
//   panel.sidebar  the sidebar's cells, top to bottom: a module id, or "" for an empty cell (at most ten
//                  modules, as many as the sidebar has cells for; empty cells at the end are not saved). The sidebar is filled with as many empty cells
//                  of about 44 px as fit, all the same height, the last reaching the foot of the sidebar, in the
//                  panel and in Edit panel alike (cellLayout).
//   panel.star     the module that opens first every time the panel opens ("" = the page used last)
//   panel.styles   { system: "graphs" | "rings" | "bubble", user: "hero" | "slide", weather: "classic" | "dashboard" }
//   panel.music    the Anserin interface's own copy of Theme → Music (style "original" | "m3" | "m5", the covers,
//                  m3Background, cavaEnabled, and <style>FirstPage "lyrics" | "eq"), set in Edit panel → Style →
//                  Music. It starts as a copy of theme.music the first time the Anserin interface runs without one;
//                  Dynamic EQ stays theme.music.dynamicEq, as it sets the sound itself.
Singleton {
    id: root

    readonly property int slotCount: 10
    readonly property int maxCells: 16
    readonly property real emptyCell: 44

    // Every module the sidebar can hold. `face` is the bar module drawn in the sidebar; without one the
    // sidebar shows `icon`.
    readonly property var modules: ({
        music: { name: "Music", icon: "󰎈", face: "../bar/faces/media/SideMediaFace.qml",
                 styles: [{ id: "original", name: "Classic" }, { id: "m3", name: "Split" }, { id: "m5", name: "Ambient" }] },
        weather: { name: "Weather", icon: "\u{F0C2}", face: "../bar/faces/weather/SideWeatherFace.qml",
                   styles: [{ id: "classic", name: "Classic" }, { id: "dashboard", name: "Dashboard" }] },
        network: { name: "Network", icon: "󰤨", face: "../bar/faces/wifi/SideWifiFace.qml" },
        launcher: { name: "Launcher", icon: "󰵆", face: "../bar/faces/LauncherFace.qml", live: true },
        timer: { name: "Timer", icon: "󰔛", face: "SideTimerFace.qml" },
        system: { name: "System", icon: "󰍛", styles: [{ id: "graphs", name: "Graphs" }, { id: "rings", name: "Activity rings" }, { id: "bubble", name: "Bubble" }] },
        user: { name: "User", icon: "󰀄", styles: [{ id: "hero", name: "Hero" }, { id: "slide", name: "Slide" }] },
        wallpaper: { name: "Wallpaper", icon: "󰸉" },
        calculator: { name: "Calculator", icon: "󰃬" }
    })
    readonly property var defaultSlots: ["music", "weather", "network", "launcher", "timer", "system", "user"]

    // The sidebar as saved, cleaned up: unknown ids become empty cells, each module at most once, no empty cells
    // at the end.
    readonly property var cells: {
        const saved = Config.getSetting("panel.sidebar", null);
        return clean(Array.isArray(saved) ? saved : defaultSlots);
    }
    function clean(src) {
        const out = [];
        let count = 0;
        for (const raw of src) {
            if (out.length >= maxCells) break;
            const id = raw && modules[raw] && out.indexOf(raw) === -1 && count < slotCount ? raw : "";
            if (id) count++;
            out.push(id);
        }
        while (out.length && out[out.length - 1] === "") out.pop();
        return out;
    }
    // How many cells the sidebar shows and how tall each empty one is: as many empty cells of about `emptyCell`
    // as fit in `room` after the modules (heights: module id -> drawn height), all the same height so the last
    // one ends at the foot. One rule for the panel and Edit panel, so both line up.
    function cellLayout(room, gap, heights, emptyCell) {
        let mods = 0, used = 0;
        for (const id of cells) if (id !== "") { mods++; used += heights[id] || 44; }
        const interior = cells.length - mods;                      // empty cells between modules
        const spare = room - used - Math.max(0, mods - 1) * gap;   // room left for empty cells and their gaps
        let empty = Math.max(interior, Math.round((spare - (mods > 0 ? gap : 0) + gap) / (emptyCell + gap)));
        if (empty <= 0) return { count: cells.length, emptyH: emptyCell };
        const h = (spare - (mods > 0 ? gap * empty : gap * (empty - 1))) / empty;
        return { count: mods + empty, emptyH: Math.max(0, h) };
    }
    // The modules alone, top to bottom: the panel's pages.
    readonly property var order: cells.filter(id => id !== "")
    readonly property var stored: Object.keys(modules).filter(id => order.indexOf(id) === -1)

    readonly property string star: {
        const s = Config.getSetting("panel.star", "");
        return order.indexOf(s) !== -1 ? s : "";
    }

    function style(moduleId) {
        const m = modules[moduleId];
        if (!m || !m.styles) return "";
        const s = moduleId === "music" ? music.style : Config.getSetting("panel.styles." + moduleId, m.styles[0].id);
        return m.styles.some(x => x.id === s) ? s : m.styles[0].id;
    }

    function saveSlots(next) { Config.setSetting("panel.sidebar", next); }

    // Put a module into a cell. An empty cell takes it as it is; on a module it goes in above that one, the
    // modules below moving down into the next empty cell. A module moved within the sidebar leaves an empty cell
    // where it was. False when the sidebar is full.
    function placeAt(moduleId, cell) {
        if (!modules[moduleId] || cell < 0 || cell >= maxCells) return false;
        const next = cells.slice();
        const from = next.indexOf(moduleId);
        if (from === cell) return true;
        if (from !== -1) next[from] = "";
        else if (order.length >= slotCount) return false;
        while (next.length <= cell) next.push("");
        if (next[cell] === "") {
            next[cell] = moduleId;
        } else {
            // the nearest empty cell below closes up (or, with none below, the nearest above)
            next.splice(cell, 0, moduleId);
            let free = next.indexOf("", cell + 1);
            if (free === -1) free = next.lastIndexOf("", cell - 1);
            if (free === -1) return false;
            next.splice(free, 1);
        }
        const cleaned = clean(next);
        if (cleaned.filter(id => id !== "").length !== order.length + (from === -1 ? 1 : 0)) return false;
        saveSlots(cleaned);
        return true;
    }
    // Take a module out of the sidebar (its cell stays empty), unless it is the last one there.
    function remove(moduleId) {
        if (order.length <= 1 || order.indexOf(moduleId) === -1) return false;
        saveSlots(clean(cells.map(id => id === moduleId ? "" : id)));
        if (star === moduleId) Config.setSetting("panel.star", "");
        return true;
    }
    function toggleStar(moduleId) { Config.setSetting("panel.star", star === moduleId ? "" : moduleId); }
    function setStyle(moduleId, styleId) {
        if (moduleId === "music") setMusic("style", styleId);
        else Config.setSetting("panel.styles." + moduleId, styleId);
    }

    // ---------- Music (panel.music, see above) ----------
    readonly property var themeMusic: Config.getSetting("theme", {}).music || ({})
    // a saved copy counts once it has a style (an empty object is no copy)
    function hasStyle(m) { return !!m && typeof m === "object" && typeof m.style === "string"; }
    readonly property var ownMusic: { const m = Config.getSetting("panel.music", null); return hasStyle(m) ? m : null; }
    readonly property var music: Object.assign({}, ownMusic || themeMusic, { dynamicEq: themeMusic.dynamicEq === true })
    // read from Config itself, not from the bindings above: run while the settings load, those may still hold
    // the values from before
    function copyMusic() {
        const own = Config.getSetting("panel.music", null);
        const theme = Config.getSetting("theme", {}).music;
        if (hasStyle(own) || !hasStyle(theme)) return;
        const copy = Object.assign({}, theme, own || {});
        delete copy.dynamicEq;
        Config.setSetting("panel.music", copy);
    }
    function setMusic(key, value) {
        if (key === "dynamicEq") { Config.setSetting("theme.music.dynamicEq", value); return; }
        copyMusic();
        Config.setSetting("panel.music." + key, value);
    }
    // the page a style opens on: the lyrics unless the equalizer was chosen
    function firstPage(styleId) { return music[styleId + "FirstPage"] === "eq" ? "eq" : "lyrics"; }
    // after the settings have settled (writing them while they are being read loops their bindings)
    Connections {
        target: Config
        function onSettingsLoaded() { if (AnserinMode.active) Qt.callLater(root.copyMusic); }
    }
    Connections {
        target: AnserinMode
        function onActiveChanged() { if (AnserinMode.active) Qt.callLater(root.copyMusic); }
    }

    // ---------- Workspace only ----------
    // panel.workspaceOnly (default on): the left edge first shows only a small capsule of workspaces
    // (WorkspaceCapsule); clicking around its dots slides the panel out from it.
    readonly property bool workspaceOnly: Config.getSetting("panel.workspaceOnly", true) !== false
    property string capsuleScreen: ""      // the screen showing the capsule ("" = none)
    // the workspaces' place on the left edge, shared by the capsule and the panel: the dots (18 px pills) sit
    // 2 px inside the screen frame; the 40 px face is centred on them
    readonly property real workspaceX: ScreenEdges.thickness + 2 + 9 - 20
    property bool expandFromCapsule: false // the next panel opening takes over from the unfolded capsule
    signal expandRequested(string screenName)
    function showCapsule(screenName) { capsuleScreen = screenName || ""; }
    function hideCapsule() { capsuleScreen = ""; }
    // A click on the capsule: the panel opens, waits out Hyprland's layer fade-in all but invisible, takes the
    // workspaces and slides out under them; it sends the capsule away once the slide is done.
    function expand() {
        expandFromCapsule = true;
        expandRequested(capsuleScreen);
    }

    // The one set of workspaces, shared by the capsule and the panel: whichever is showing holds it (hostStrip),
    // so opening the panel moves the same workspaces in rather than showing a second set.
    property bool panelShown: false
    readonly property bool stripActive: capsuleScreen !== "" || panelShown
    property Item strip: null
    function hostStrip(slot) {
        if (!strip) strip = stripComponent.createObject(null);
        if (strip && strip.parent !== slot) strip.parent = slot;
        return strip;
    }
    function releaseStrip(slot) { if (strip && strip.parent === slot) strip.parent = null; }
    property Component stripComponent: Component {
        Item {
            id: stripItem
            width: Scaler.s(40)
            height: face.item ? face.item.implicitHeight : Scaler.s(120)
            QtObject {
                id: stripHost
                property bool moduleActive: root.stripActive
                property bool isCompact: false
                property bool isRightBar: false
                property var barWindow: ({ s: v => Scaler.s(v), visible: root.stripActive, isStartupReady: true, isDataReady: true, startupCascadeFinished: true,
                                           screen: Quickshell.screens.find(sc => sc.name === (root.capsuleScreen || root.editScreen)) || Quickshell.screens[0] })
            }
            Loader {
                id: face
                width: parent.width
                height: item ? item.implicitHeight : 0
                source: "../bar/faces/workspaces/SideWorkspacesFace.qml"
                onLoaded: item.module = stripHost
            }
        }
    }

    // ---------- Edit panel ----------
    property bool editing: false
    // the System page's Bubble style is full screen: the panel it came from stays open until it is back
    property bool bubbleFull: false
    property string editScreen: ""
    signal editFinished(string screenName)
    function startEdit(screenName) {
        editScreen = screenName || "";
        editing = true;
    }
    function endEdit() {
        if (!editing) return;
        editing = false;
        editFinished(editScreen);
    }
}
