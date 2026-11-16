pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"

Item {
    id: root
    property bool initialized: false
    property bool ready: false
    property string error: ""
    property bool engineStarted: false
    readonly property bool dynamicEq: Config.getSetting("theme", {}).music?.dynamicEq === true

    function initialize() {
        if (initialized) return;
        initialized = true;
        build.running = true;
    }
    function synchronize() {
        if (!ready || control.running) return;
        control.requestedDynamic = dynamicEq;
        control.command = ["bash", Caching.qsDir + "/media/equalizer.sh", "init", dynamicEq ? "true" : "false"];
        control.running = true;
    }
    onDynamicEqChanged: synchronize()
    Process {
        id: build
        command: ["make", "-C", Caching.qsDir + "/native/audio", "OUT=anserin-audio"]
        stderr: StdioCollector { id: buildError }
        onExited: code => {
            root.error = code === 0 ? "" : buildError.text.trim();
            // a daemon left running by an earlier shell session keeps the audio lock: reuse it, only start one if none answers
            if (code === 0) probe.running = true;
            else console.warn("Audio processor build: " + root.error);
        }
    }
    Process {
        id: probe
        command: [Caching.qsDir + "/native/audio/anserin-audio", "ctl", "ping"]
        onExited: code => {
            root.ready = code === 0;
            if (root.ready) { root.error = ""; root.synchronize(); }
            else if (!root.engineStarted) { root.engineStarted = true; engine.running = true; }
            else root.error = "Audio processor is unavailable";
        }
    }
    Process {
        id: engine
        command: [Caching.qsDir + "/native/audio/anserin-audio", "daemon"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "Anserin audio ready") {
                    root.ready = true;
                    root.synchronize();
                }
            }
        }
        stderr: SplitParser { onRead: data => { if (data.trim()) console.warn("Audio processor: " + data); } }
        onExited: code => {
            root.ready = false;
            // "already running" (1): another daemon owns the lock, so check whether it answers
            if (code !== 0) probe.running = true;
        }
    }
    Process {
        id: control
        property bool requestedDynamic: false
        stderr: StdioCollector { id: controlError }
        onExited: code => {
            root.error = code === 0 ? "" : controlError.text.trim();
            if (requestedDynamic !== root.dynamicEq) root.synchronize();
        }
    }
}
