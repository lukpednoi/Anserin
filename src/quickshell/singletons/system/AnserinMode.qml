pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Anserin is the only interface. `active` and `style` stay for the code that still reads them.
// Settings used to be kept separately for a "default" and an "anserin" interface: the active one in the normal keys,
// the other parked in display.styleSettings.<style>.<key> (desktop widget positions as widgetLayouts). Someone who was
// still on the Default interface is moved over once at start: Anserin's parked values come back into the normal keys
// and the Default ones are parked, as the old switch did, so nothing is lost.
Singleton {
    id: root

    readonly property var display: (Config.rawSettings && Config.rawSettings.display) || ({})
    readonly property string style: "anserin"
    readonly property bool active: true

    readonly property var separatedKeys: ["bar", "dock", "launcher", "notifications", "osd", "theme", "widgets"]
    // machine-wide, so never swapped: the SDDM style and the apps that follow Anserin colours
    readonly property var sharedThemeKeys: ["sddmStyle", "preparedApp", "apps"]
    readonly property var colorKeys: ["matugen", "activePreset", "colors", "mode", "schemeType"]
    // Default-only settings (Quick Actions): parked for Default, never kept for Anserin
    readonly property var defaultOnlyKeys: ["quickactions"]
    property string screenName: ""

    // the one-time move from the Default interface
    Connections {
        target: Config
        function onSettingsLoaded() { root.migrate(); }
    }
    Component.onCompleted: if (Config.dataReady) migrate()
    function migrate() {
        if (!Config.dataReady || display.settingsStyle === "anserin" || layoutReader.running) return;
        screenName = Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
        layoutReader.running = true;
    }

    function swapSettings(layouts) {
        const prev = "default", next = "anserin";
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
            const current = Config.getSetting(key, null);
            if (current !== null) stash.default = Object.assign(stash.default || {}, { [key]: current });
            updates[key] = undefined;
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
        command: ["python3", Caching.anserinDir + "/scripts/config-profile-widgets.py", "layouts", Caching.stateDir]
        stdout: StdioCollector { id: layoutOutput }
        stderr: StdioCollector { id: layoutReadErrors }
        onExited: code => {
            let layouts = null;
            try {
                if (code !== 0) throw new Error(layoutReadErrors.text.trim());
                layouts = JSON.parse(layoutOutput.text).widgets;
            } catch (failure) {
                console.warn("Moving to the Anserin interface kept the widget positions: " + failure);
            }
            root.swapSettings(layouts);
        }
    }

    Process {
        id: layoutWriter
        property var target: ({})
        stderr: StdioCollector { id: layoutWriteErrors }
        onExited: code => {
            if (code === 0) ConfigProfiles.refreshWidgets(target);
            else console.warn("Moving to the Anserin interface could not place the widgets: " + layoutWriteErrors.text.trim());
        }
    }
}
