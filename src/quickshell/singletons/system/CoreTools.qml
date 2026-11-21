pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Anserin core (src/quickshell/native/core): built by scripts/build-core.py when the shell starts, only when its
// source or Qt changed, into .lab-data/core-build (outside the config folder, where Quickshell finds a C++
// plugin). It gives the sound engine (module/, used by Sounds) and anserin-core (bin/: system usage,
// monitors, lock keys, backlight, Night light). Until it is ready, or when it cannot be built, every user keeps
// its own older way (pw-play, the shell scripts).
Item {
    id: root
    property bool ready: false
    property bool core: false
    readonly property bool gamma: core
    readonly property string buildDir: Caching.anserinDir + "/../.lab-data/core-build"
    readonly property string coreBin: buildDir + "/bin/anserin-core"
    readonly property string moduleDir: buildDir + "/module"

    Process {
        running: Caching.anserinDir !== ""
        command: ["python3", Caching.anserinDir + "/scripts/build-core.py"]
        stderr: StdioCollector { id: buildErrors }
        onExited: code => {
            root.core = code === 0;
            root.ready = true;
            if (code !== 0) console.warn("Anserin core: " + buildErrors.text.trim() + " (using the older ways)");
        }
    }
}
