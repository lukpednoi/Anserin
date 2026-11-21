pragma Singleton
import QtQuick
import Quickshell
import "../../"

// What the Radar and Gargantua styles add to the theme: their card corner and the signal colour (strong green,
// fair yellow, weak red).
Singleton {
    readonly property int cardRadius: Math.min(ThemeBackend.clampedBorderRadius, 20)
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    readonly property color fairSignalColor: lum(ThemeBackend.yellow) < 0.36 ? ThemeBackend.peach : ThemeBackend.yellow
    function signalColor(sig) {
        if (sig >= 75) return ThemeBackend.green;
        if (sig >= 45) return fairSignalColor;
        return ThemeBackend.red;
    }
}
