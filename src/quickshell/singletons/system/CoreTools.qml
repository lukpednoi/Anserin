pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The helper programs from Serpantinum that Anserin uses when they are installed: serpantinum-core (system usage,
// brightness, monitors, wallpaper index, network) and serpantinum-gamma (Night light). Each user keeps its own
// fallback (the shell scripts and tools it used before), so a missing helper only means the older path.
Item {
    id: root
    property bool ready: false
    property bool core: false
    property bool gamma: false
    readonly property string coreBin: "serpantinum-core"
    readonly property string gammaBin: "serpantinum-gamma"

    Process {
        running: true
        command: ["sh", "-c", "command -v serpantinum-core >/dev/null 2>&1 && echo core; command -v serpantinum-gamma >/dev/null 2>&1 && echo gamma; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = text.split("\n").map(s => s.trim());
                root.core = found.indexOf("core") >= 0;
                root.gamma = found.indexOf("gamma") >= 0;
                root.ready = true;
            }
        }
    }
}
