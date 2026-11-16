import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Where screenshots are saved (the "screenshotDir" setting read by src/scripts/screenshot.sh; empty means
// Pictures/Screenshots). Lists the usual picture folders that exist, plus the chosen one. Used by the Settings
// page (guide/general/GeneralTab.qml) and the Control Center's board (GeneralPage.qml).
Item {
    id: logic
    readonly property string defaultDir: (Quickshell.env("XDG_PICTURES_DIR") || (Quickshell.env("HOME") + "/Pictures")) + "/Screenshots"
    readonly property string currentDir: Config.getSetting("screenshotDir", "") || defaultDir
    property var found: []
    readonly property var dirs: found.indexOf(currentDir) >= 0 ? found : [currentDir].concat(found)

    function setDir(value) {
        if (!Config.dataReady || !value) return;
        Config.setSetting("screenshotDir", value === defaultDir ? "" : value);
    }
    function openDir() {
        FileManager.openFolder(currentDir, true);
    }
    function scan() { scanner.running = false; scanner.running = true; }

    Process {
        id: scanner
        command: ["bash", "-c", "p=\"${XDG_PICTURES_DIR:-$HOME/Pictures}\"; for d in \"$p/Screenshots\" \"$p\" \"$HOME/Screenshots\" \"${XDG_DESKTOP_DIR:-$HOME/Desktop}\" \"${XDG_DOCUMENTS_DIR:-$HOME/Documents}\" \"${XDG_DOWNLOAD_DIR:-$HOME/Downloads}\"; do [ -d \"$d\" ] && printf '%s\\n' \"$d\"; done"]
        stdout: StdioCollector {
            onStreamFinished: logic.found = text.split("\n").map(s => s.trim()).filter(s => s !== "")
        }
    }
    Component.onCompleted: scan()
}
