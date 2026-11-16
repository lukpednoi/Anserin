pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../"

// Which Settings "UI interface" is active (Display > General): "default" or "anserin".
// Features that belong only to the Anserin interface check `active`.
// Switching either way plays SwitchTransition; the style and the per-interface settings
// are swapped when the screen is fully covered.
Singleton {
    id: root

    readonly property var display: (Config.rawSettings && Config.rawSettings.display) || ({})
    readonly property string style: display.settingsStyle === "anserin" ? "anserin" : "default"
    readonly property bool active: style === "anserin"
    // when the corner revolver's Lock was fired (Date.now()): the Simple lock screen's Bullet animation sweeps in
    // diagonally after it, any other lock comes down from the top
    property real lockShotAt: 0

    // Settings kept separately for each interface. The active interface's values stay in their
    // normal keys, so existing readers need no change; the other interface's copy is parked in
    // display.styleSettings.<style>.<key>; desktop widget positions are parked there as widgetLayouts.
    // An interface with nothing parked yet keeps the current values, except for these Anserin defaults.
    readonly property var separatedKeys: ["bar", "dock", "launcher", "notifications", "osd", "theme", "widgets"]
    // Theme values that describe the whole system, so both interfaces always share them.
    // machine-wide, so the same in both interfaces: the SDDM style and the apps that follow Anserin colours
    readonly property var sharedThemeKeys: ["sddmStyle", "preparedApp", "apps"]
    readonly property var colorKeys: ["matugen", "activePreset", "colors", "mode", "schemeType"]
    // Settings only the Default interface has (the Anserin interface has no Quick Actions): they stay parked
    // for Default while Anserin is in use, and Anserin never keeps a copy of its own.
    readonly property var defaultOnlyKeys: ["quickactions"]

    property bool busy: false
    property string pendingStyle: ""
    property string screenName: ""
    property point origin: Qt.point(0, 0)
    signal playRequested()

    // Both directions play the animation; the circle always grows from the screen centre.
    function requestSwitch(next, screen, x, y) {
        if (busy || next === style) return;
        // The Settings window does not always report its screen; fall back to the focused one.
        const target = screen || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "")
            || (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
        if (!target) { applyStyle(next); return; }
        pendingStyle = next;
        screenName = target;
        origin = Qt.point(x, y);
        busy = true;
        safety.restart();
        playRequested();
    }

    function commit() {
        if (pendingStyle) applyStyle(pendingStyle);
        pendingStyle = "";
    }

    function finish() {
        safety.stop();
        commit();
        busy = false;
    }

    // Reads the widget positions first; the swap itself happens once they are known.
    function applyStyle(next) {
        if (next === style || layoutReader.running) return;
        layoutReader.next = next;
        layoutReader.running = true;
    }

    function swapSettings(next, layouts) {
        const prev = style;
        if (next === prev) return;
        const stash = JSON.parse(JSON.stringify(display.styleSettings || {}));
        const themeBefore = Config.getSetting("theme", {});
        stash[prev] = stash[prev] || {};
        const updates = { "display.settingsStyle": next };
        for (const key of separatedKeys) {
            const current = Config.getSetting(key, null);
            if (current !== null) stash[prev][key] = current;
            const saved = stash[next] ? stash[next][key] : undefined;
            if (saved !== undefined) updates[key] = saved;
        }
        for (const key of defaultOnlyKeys) {
            if (next === "anserin") {
                const current = Config.getSetting(key, null);
                if (current !== null) stash.default = Object.assign(stash.default || {}, { [key]: current });
                updates[key] = undefined;
            } else if (stash.default && stash.default[key] !== undefined) {
                updates[key] = stash.default[key];
            }
            if (stash.anserin) delete stash.anserin[key];
        }
        if (updates.theme) for (const key of sharedThemeKeys) {
            if (themeBefore[key] !== undefined) updates.theme[key] = themeBefore[key];
        }
        if (layouts !== null) stash[prev].widgetLayouts = layouts;
        updates["display.styleSettings"] = stash;
        Config.updateJsonBulk(updates);
        if (updates.theme) refreshColors(themeBefore, updates.theme);
        const saved = stash[next] ? stash[next].widgetLayouts : undefined;
        if (layouts !== null && saved !== undefined) applyLayouts(layouts, saved);
    }

    // Colours are written out for other apps by Matugen, which a settings change alone does not start.
    function refreshColors(before, after) {
        if (colorKeys.every(key => JSON.stringify(before[key]) === JSON.stringify(after[key]))) return;
        if (after.matugen === false && after.colors) {
            ThemeBackend.applyColorObject(after.colors);
            Matugen.generateFromStatic(after.colors, after.mode);
            return;
        }
        ThemeBackend.applyMatugenColors();
        const wallpaper = Wallpaper.getWallpaperPath(screenName);
        if (wallpaper) Matugen.generate(wallpaper, after.mode, after.schemeType);
        else ThemeBackend.reloadColors();
    }

    function applyLayouts(current, saved) {
        const target = JSON.parse(JSON.stringify(saved));
        for (const monitor of Object.keys(current)) {
            if (target[monitor] === undefined) target[monitor] = null;
        }
        layoutWriter.target = target;
        layoutWriter.command = ["python3", Caching.anserinDir + "/scripts/config-profile-widgets.py", "apply", Caching.stateDir, JSON.stringify(target)];
        layoutWriter.running = true;
    }

    Process {
        id: layoutReader
        property string next: ""
        command: ["python3", Caching.anserinDir + "/scripts/config-profile-widgets.py", "layouts", Caching.stateDir]
        stdout: StdioCollector { id: layoutOutput }
        stderr: StdioCollector { id: layoutReadErrors }
        onExited: code => {
            let layouts = null;
            try {
                if (code !== 0) throw new Error(layoutReadErrors.text.trim());
                layouts = JSON.parse(layoutOutput.text).widgets;
            } catch (failure) {
                console.warn("Interface switch kept the widget positions: " + failure);
            }
            root.swapSettings(next, layouts);
        }
    }

    Process {
        id: layoutWriter
        property var target: ({})
        stderr: StdioCollector { id: layoutWriteErrors }
        onExited: code => {
            if (code === 0) ConfigProfiles.refreshWidgets(target);
            else console.warn("Interface switch could not place the widgets: " + layoutWriteErrors.text.trim());
        }
    }

    // If no overlay answers (e.g. the screen name is unknown), still apply the choice.
    Timer { id: safety; interval: 6000; onTriggered: root.finish() }
}
