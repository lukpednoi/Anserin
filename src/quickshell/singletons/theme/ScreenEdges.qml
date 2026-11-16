pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../"

QtObject {
    // The Anserin interface always uses the Modern frame at 10 px; the saved Classic/Modern and
    // thickness values are kept untouched for the default interface.
    readonly property bool modern: AnserinMode.active || Config.getSetting("theme.windowBorder", "classic") === "modern"
    readonly property int thickness: {
        if (AnserinMode.active) return 10;
        const value = Config.getSetting("theme.windowBorderThickness", 10);
        return typeof value === "number" && isFinite(value) ? Math.round(Math.max(2, Math.min(32, value))) : 10;
    }
    readonly property real rounding: ThemeBackend.clampedBorderRadius
    property var docks: ({})

    function registerDock(name, window) {
        docks = Object.assign({}, docks, { [name]: window });
    }

    function unregisterDock(name, window) {
        if (docks[name] !== window) return;
        let next = Object.assign({}, docks);
        delete next[name];
        docks = next;
    }

    function fullscreen(screen) {
        if (!screen) return false;
        for (const workspace of Hyprland.workspaces.values) {
            if (!workspace.active || !workspace.monitor || workspace.monitor.name !== screen.name) continue;
            for (const window of workspace.toplevels.values) {
                if (window.wayland && window.wayland.fullscreen) return true;
            }
        }
        const active = ToplevelManager.activeToplevel;
        return !!active && active.fullscreen && active.screens.indexOf(screen) !== -1;
    }

    function inset(screen) {
        return modern && screen && !Config.sessionLocked && !fullscreen(screen) ? thickness : 0;
    }

    function reserved(screen, edge) {
        let size = inset(screen);
        if (!size) return 0;
        const bar = LauncherController.bars[screen.name];
        if (bar && bar.visible && bar.barPosition === edge && !bar.autohide) size += bar.barHeight;
        const dock = docks[screen.name];
        if (dock && dock.dockPosition === edge && dock.isEffectivelyExclusive) size += dock.dockReservedSpace;
        return size;
    }
}
