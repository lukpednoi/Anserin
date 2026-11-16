pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property string anserinDir: {
        if (typeof Caching !== "undefined" && Caching.anserinDir) {
            return Caching.anserinDir;
        }
        return "";
    }

    readonly property string helperScript: root.anserinDir + "/scripts/first_launch.sh"

    property bool isFirstLaunch: false
    property bool executed: false

    signal firstLaunchStarted()
    signal startAnimations()
    signal firstLaunchFinished()

    Timer {
        id: startupDelayTimer
        interval: 350
        repeat: false
        onTriggered: {
            initProcess.running = true;
        }
    }

    // The first launch sets a wallpaper (when one is found) and then opens the Settings window.
    Timer {
        id: launchStageTimer
        interval: 850
        repeat: false
        onTriggered: {
            root.firstLaunchStarted();
            root.startAnimations();
            Quickshell.execDetached(["bash", root.helperScript, "--open-guide"]);
            root.firstLaunchFinished();
        }
    }
    IpcHandler {
        target: "firstlaunch"

        function trigger(): bool {
            root.runSetup("");
            return true;
        }

        function reset(): bool {
            Quickshell.execDetached(["bash", root.helperScript, "--reset"]);
            root.executed = false;
            root.isFirstLaunch = false;
            return true;
        }
    }

    function checkFirstLaunch() {
        if (executed) return;
        executed = true;
        startupDelayTimer.start();
    }

    function runSetup(customWp) {
        root.isFirstLaunch = true;

        let wp = (customWp || "").trim();
        if (wp.startsWith("file://")) {
            wp = wp.substring(7).trim();
        }

        if (wp.length > 0) {
            try {
                if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                    Matugen.generate(wp, "", "");
                }
            } catch (e) {}

            Wallpaper.setWallpaper("all", wp, "fade");
            launchStageTimer.interval = 900;
        } else {
            launchStageTimer.interval = 100;
        }

        launchStageTimer.start();
    }

    Process {
        id: initProcess
        running: false
        command: ["bash", root.helperScript, "--check"]
        stdout: StdioCollector {
            id: initOut
            onStreamFinished: {
                let lines = initOut.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line.startsWith("FIRST|")) {
                        let parts = line.split("|");
                        let wp = parts.length > 1 ? parts[1] : "";
                        root.runSetup(wp);
                        break;
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        root.checkFirstLaunch();
    }
}
