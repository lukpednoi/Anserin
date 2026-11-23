pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The Claude Panel's switch (Shell.qml makes the panel only while `shown`). Opened from the desktop's right-click
// menu or SUPER + C (`anserin ipc call claude toggle`): closed → opens with the launch streak from the bottom-left
// corner; open → folds into the corner dome (the session keeps running); folded → opens again. ✕ closes it for good.
Item {
    id: panel

    property bool shown: false
    property var screen: null
    property var overlay: null          // the ClaudeWelcomeOverlay while it exists (set by the overlay itself)
    // Claude's starburst, 24x24 (one colour), for menus and buttons
    readonly property string iconPath: "M 10.51 10.17 L 7.69 3.41 L 8.72 1.92 L 10.44 2.52 L 12.13 9.65 Z M 11.56 9.72 L 12.03 2.81 L 13.42 1.90 L 14.50 3.16 L 13.05 9.93 Z M 12.69 9.72 L 16.75 3.75 L 18.61 3.84 L 19.08 5.64 L 14.08 10.86 Z M 13.95 10.74 L 19.95 8.73 L 21.31 9.68 L 20.55 11.16 L 14.32 12.20 Z M 14.29 11.57 L 20.80 12.08 L 21.68 13.53 L 20.39 14.64 L 14.05 13.11 Z M 14.07 13.10 L 19.16 17.93 L 18.89 19.65 L 17.15 19.74 L 12.88 14.17 Z M 12.68 14.21 L 13.05 20.52 L 11.83 21.60 L 10.65 20.48 L 11.24 14.19 Z M 11.55 14.26 L 9.08 19.64 L 7.54 20.05 L 7.07 18.53 L 10.32 13.58 Z M 10.60 13.89 L 5.02 18.14 L 3.36 17.61 L 3.55 15.88 L 9.71 12.51 Z M 9.78 12.67 L 2.86 12.93 L 1.81 11.64 L 2.95 10.43 L 9.83 11.17 Z M 9.69 11.51 L 3.24 8.04 L 3.11 6.23 L 4.82 5.61 L 10.62 10.09 Z M 12 8.5 A 3.5 3.5 0 1 0 12 15.5 A 3.5 3.5 0 1 0 12 8.5 Z"

    function screenByName(name) {
        for (const s of Quickshell.screens) if (s.name === name) return s;
        return null;
    }
    function focusedScreen() {
        // Hyprland's focused monitor; the first screen when it cannot be told
        const mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        return screenByName(mon) || Quickshell.screens[0];
    }

    function open(targetScreen) {
        if (shown) {
            if (overlay && overlay.experience.folded) overlay.experience.startUnfold();
            return;
        }
        screen = targetScreen || focusedScreen();
        shown = true;
    }
    function toggle() {
        if (!shown) { open(null); return; }
        if (!overlay) return;
        const exp = overlay.experience;
        if (exp.folded) exp.startUnfold();
        else if (exp.loggedIn) exp.toggleFold();
    }
    function close() {
        if (shown && overlay) overlay.experience.close();
    }
    function closed() {
        shown = false;
        overlay = null;
    }

    IpcHandler {
        target: "claude"
        function toggle(): void { panel.toggle(); }
        function open(): void { panel.open(null); }
        function close(): void { panel.close(); }
    }
}
