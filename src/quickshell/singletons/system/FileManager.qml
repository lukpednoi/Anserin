pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// The file manager Anserin opens folders with (general.fileManager: "dolphin" or "ski"), chosen in Control →
// General and Settings → General. Only installed ones are offered. It changes what Anserin itself opens, not the
// desktop's default app for folders.
Item {
    id: root
    readonly property var choices: [
        { id: "dolphin", name: "Dolphin", bin: "dolphin" },
        { id: "ski", name: "Ski", bin: "ski" }
    ]
    property var installed: []
    readonly property var available: choices.filter(c => installed.indexOf(c.id) >= 0)
    readonly property string chosen: {
        const saved = Config.getSetting("general", {}).fileManager;
        if (installed.indexOf(saved) >= 0) return saved;
        return installed.length > 0 ? installed[0] : "";
    }

    function setChosen(id) {
        if (installed.indexOf(id) < 0) return;
        let general = Object.assign({}, Config.getSetting("general", {}));
        general.fileManager = id;
        Config.setSetting("general", general);
    }
    // open a folder (made first when create is true); without either file manager, the desktop's default
    function openFolder(path, create) {
        if (!path) return;
        const app = choices.find(c => c.id === root.chosen);
        Quickshell.execDetached(["bash", "-c", (create ? "mkdir -p \"$1\" && " : "") + "exec " + (app ? app.bin : "xdg-open") + " \"$1\"", "_", path]);
    }

    Process {
        running: true
        command: ["sh", "-c", "for b in dolphin ski; do command -v \"$b\" >/dev/null 2>&1 && echo \"$b\"; done"]
        stdout: StdioCollector { onStreamFinished: root.installed = text.split("\n").map(s => s.trim()).filter(s => s !== "") }
    }
}
