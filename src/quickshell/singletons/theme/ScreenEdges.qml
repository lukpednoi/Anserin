pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../"

QtObject {
    // Anserin always uses the Modern frame at 10 px
    readonly property bool modern: true
    readonly property int thickness: 10
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
        // Not tied to fullscreen: fullscreen windows ignore reserved space, and changing it mid workspace-slide
        // re-lays-out windows (black-line glitch on NVIDIA)
        let size = (modern && screen && !Config.sessionLocked) ? thickness : 0;
        if (!size) return 0;
        const bar = LauncherController.bars[screen.name];
        if (bar && bar.visible && bar.barPosition === edge && !bar.autohide) size += bar.barHeight;
        const dock = docks[screen.name];
        if (dock && dock.dockPosition === edge && dock.isEffectivelyExclusive) size += dock.dockReservedSpace;
        return size;
    }
}
