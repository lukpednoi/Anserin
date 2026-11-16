pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property int barCount: 64
    readonly property var emptyLevels: {
        let arr = [];
        for (let i = 0; i < barCount; i++) arr.push(0.0);
        return Object.freeze(arr);
    }
    property var barLevels: emptyLevels
    property int activeConsumers: 0
    property bool isPlaying: MprisController.isPlaying || Audio.hasActiveStream
    property bool isDecaying: false
    property bool hasActiveAudio: false
    property bool isRestarting: false
    property int consecutiveCrashes: 0
    property bool processEnabled: activeConsumers > 0 && (isPlaying || isDecaying) && !isRestarting

    function registerConsumer() {
        activeConsumers++;
    }

    function unregisterConsumer() {
        activeConsumers = Math.max(0, activeConsumers - 1);
    }

    function resetBars() {
        root.barLevels = root.emptyLevels;
    }

    function restartCava() {
        if (!processEnabled || consecutiveCrashes >= 5) return;
        consecutiveCrashes++;
        isRestarting = true;
        restartTimer.restart();
    }

    onActiveConsumersChanged: {
        if (activeConsumers === 0) {
            root.isDecaying = false;
            decayTimer.stop();
        }
    }

    onIsPlayingChanged: {
        if (isPlaying) {
            root.isDecaying = false;
            decayTimer.stop();
        } else if (activeConsumers > 0) {
            root.isDecaying = true;
            decayTimer.restart();
        } else {
            root.isDecaying = false;
            decayTimer.stop();
            resetBars();
        }
    }

    onProcessEnabledChanged: {
        if (!processEnabled) {
            root.hasActiveAudio = false;
            root.consecutiveCrashes = 0;
            dataWatchdog.stop();
            resetBars();
        }
    }

    Timer {
        id: decayTimer
        interval: 1200
        repeat: false
        onTriggered: root.isDecaying = false
    }

    Timer {
        id: restartTimer
        interval: 500
        repeat: false
        onTriggered: root.isRestarting = false
    }

    // The bars come from Anserin's own audio processor (native/audio, `anserin-audio visualizer`) when it is built,
    // otherwise from cava. The processor prints nothing while the bars stay the same, so silence is not a stall.
    readonly property string processorBin: Caching.qsDir + "/native/audio/anserin-audio"
    property bool useProcessor: false
    Process {
        id: processorCheck
        running: true
        command: ["test", "-x", root.processorBin]
        onExited: code => root.useProcessor = code === 0
    }

    Timer {
        id: dataWatchdog
        interval: 2500
        running: cavaProcess.running && root.isPlaying && !root.useProcessor
        repeat: false
        onTriggered: root.restartCava()
    }

    Process {
        id: cavaProcess
        running: root.processEnabled
        onExited: root.restartCava()
        command: root.useProcessor
            ? [root.processorBin, "visualizer", "--bars", String(root.barCount), "--framerate", "60", "--sensitivity", "150"]
            : [
            "bash", "-c",
            "exec cava -p <(printf '[general]\\nbars = %d\\nframerate = 60\\nsensitivity = 150\\n[output]\\nmethod = raw\\nraw_target = /dev/stdout\\ndata_format = ascii\\nascii_max_range = 1000\\nbar_delimiter = 59\\n' " + root.barCount + ")"
        ]
        stdout: SplitParser {
            onRead: data => {
                if (!root.processEnabled) return;
                let str = data.trim();
                if (str.length === 0) return;
                root.consecutiveCrashes = 0;
                dataWatchdog.restart();

                // the processor: one JSON array of bar heights from 0 to 1 per frame
                if (str.charAt(0) === "[") {
                    let bars;
                    try { bars = JSON.parse(str); } catch (e) { return; }
                    if (!bars.some(v => v > 0.001)) {
                        if (root.hasActiveAudio) { root.hasActiveAudio = false; root.resetBars(); }
                        return;
                    }
                    root.hasActiveAudio = true;
                    let levels = new Array(root.barCount);
                    for (let i = 0; i < root.barCount; i++) levels[i] = i < bars.length ? Math.max(0.0, Math.min(1.0, Number(bars[i]) || 0)) : 0;
                    root.barLevels = levels;
                    return;
                }

                let hasAudio = /[1-9]/.test(str);
                if (!hasAudio) {
                    if (root.hasActiveAudio) {
                        root.hasActiveAudio = false;
                        root.resetBars();
                    }
                    return;
                }

                root.hasActiveAudio = true;

                let parts = str.split(";");
                let count = Math.min(parts.length, root.barCount);
                let newLevels = new Array(root.barCount);
                for (let i = 0; i < root.barCount; i++) {
                    let val = i < count ? (parseInt(parts[i]) || 0) : 0;
                    newLevels[i] = Math.max(0.0, Math.min(1.0, val / 1000.0));
                }
                root.barLevels = newLevels;
            }
        }
    }
}
