pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    readonly property string soundsDir: Caching.qsDir + "/../assets/sounds/"

    property var activeHandles: ({})
    property int nextHandleId: 1

    property var _pendingQueue: []

    property var generalSettings: Config.getSetting("general", { "muteSfx": false, "sfxVolume": 100 })
    readonly property bool isMuted: generalSettings && generalSettings.muteSfx === true
    readonly property real sfxBoost: 1.35
    readonly property real masterVolume: {
        let v = (generalSettings && generalSettings.sfxVolume !== undefined) ? Number(generalSettings.sfxVolume) : 100;
        return Math.max(0.0, Math.min(1.0, v / 100.0));
    }

    // The native sound engine (native/core): sounds decoded once and mixed into one PipeWire stream, so a click
    // starts in a few milliseconds without starting a process. Built on first start; until it is ready, or when
    // it cannot be built, sounds play through pw-play as before.
    property var core: null
    // made once CoreTools has built Anserin core (by path: Quickshell would not find the plugin in the config folder)
    function makeCore() {
        if (root.core || !CoreTools.core) return;
        try {
            root.core = Qt.createQmlObject('import "file://' + CoreTools.moduleDir + '" as Core; Core.SfxEngine {}', root, "AnserinCore");
        } catch (e) {
            console.warn("Anserin core: " + e + " (sounds use pw-play)");
        }
    }
    Connections { target: CoreTools; function onCoreChanged() { root.makeCore(); } }
    Component.onCompleted: makeCore()
    Component.onDestruction: if (root.core) root.core.destroy()

    Connections {
        target: root.core
        // a sound started with playUntilStopped that ended by itself
        function onFinished(handle) {
            for (let id in root.activeHandles) {
                if (root.activeHandles[id] && root.activeHandles[id].coreHandle === handle) delete root.activeHandles[id];
            }
        }
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            root.generalSettings = Config.getSetting("general", { "muteSfx": false, "sfxVolume": 100 });
        }
    }

    function play(filePath, volume, duration, overrideSfxBlock) {
        if ((root.isMuted || root.masterVolume <= 0.0) && overrideSfxBlock !== true) return;
        if (!filePath || filePath.trim() === "") return;
        let vol = volume === undefined ? 1.0 : Math.max(0.0, Math.min(2.0, volume));
        let finalVol = Math.min(2.0, (overrideSfxBlock === true ? vol : (vol * root.masterVolume)) * root.sfxBoost);
        let dur = duration === undefined ? 0 : duration;
        root._pendingQueue.push({ filePath: filePath, volume: finalVol, duration: dur });
        Qt.callLater(root._drainQueue);
    }

    function playSfx(filename, volume, duration, overrideSfxBlock) {
        root.play(root.soundsDir + filename, volume, duration, overrideSfxBlock);
    }

    function _drainQueue() {
        let q = root._pendingQueue;
        root._pendingQueue = [];
        for (let i = 0; i < q.length; i++) {
            root._reallyPlay(q[i].filePath, q[i].volume, q[i].duration);
        }
    }

    function _reallyPlay(filePath, vol, dur) {
        let cleanPath = filePath.startsWith("file://") ? filePath.substring(7) : filePath;
        if (root.core && root.core.play(cleanPath, vol, dur, false) >= 0) return;
        let propsJson = "{\"application.id\":\"anserin-sfx\",\"application.name\":\"anserin-sfx\",\"media.role\":\"event\"}";
        try {
            if (dur > 0) {
                let escaped = cleanPath.replace(/'/g, "'\\''");
                Quickshell.execDetached(["sh", "-c",
                    "exec timeout " + dur + " pw-play -P '" + propsJson + "' --volume=" + vol + " '" + escaped + "' >/dev/null 2>&1"]);
            } else {
                Quickshell.execDetached(["pw-play", "-P", propsJson, "--volume=" + vol.toString(), cleanPath]);
            }
        } catch(e) {}
    }

    Component {
        id: stoppableProcess
        Process {
            property int handleId: -1
            stdinEnabled: false
        }
    }

    function playUntilStopped(filenameOrPath, volume, loop, overrideSfxBlock) {
        if ((root.isMuted || root.masterVolume <= 0.0) && overrideSfxBlock !== true) return -1;
        let vol = Math.max(0.0, Math.min(2.0, volume === undefined ? 1.0 : volume));
        let finalVol = Math.min(2.0, (overrideSfxBlock === true ? vol : (vol * root.masterVolume)) * root.sfxBoost);
        let doLoop = loop === true;
        let cleanPath = (filenameOrPath.startsWith("/") || filenameOrPath.startsWith("file://")) ?
            (filenameOrPath.startsWith("file://") ? filenameOrPath.substring(7) : filenameOrPath) :
            (root.soundsDir + filenameOrPath);
        let volFlag = "--volume=" + finalVol;

        let id = root.nextHandleId++;
        if (root.core) {
            const h = root.core.play(cleanPath, finalVol, 0, doLoop);
            if (h < 0) return -1;
            root.activeHandles[id] = { coreHandle: h };
            return id;
        }
        let sfxProps = "-P '{\"application.id\":\"anserin-sfx\",\"application.name\":\"anserin-sfx\",\"media.role\":\"event\"}' ";

        let script;
        if (doLoop) {
            script =
                "source '" + Caching.anserinDir + "/scripts/caching.sh'; PID_FILE=\"$QS_RUN_DIR/sound-$$.pid\"; trap 'mo_stop_tree \"$PID_FILE\"; exit' TERM; " +
                "while :; do pw-play " + sfxProps + volFlag + " '" + cleanPath + "' & CPID=$!; mo_pid_write \"$PID_FILE\" $CPID; wait $CPID; done";
        } else {
            script = "exec pw-play " + sfxProps + volFlag + " '" + cleanPath + "'";
        }

        let proc = stoppableProcess.createObject(root, {
            "command": ["bash", "-c", script],
            "handleId": id
        });
        proc.running = true;

        proc.exited.connect(function() {
            delete root.activeHandles[id];
            proc.destroy();
        });

        root.activeHandles[id] = proc;
        return id;
    }

    function stopSfx(handleId) {
        let entry = root.activeHandles[handleId];
        if (!entry) return;
        if (entry.coreHandle !== undefined) { if (root.core) root.core.stop(entry.coreHandle); }
        else entry.running = false;
        delete root.activeHandles[handleId];
    }

    function stopAllSfx() {
        for (let id in root.activeHandles) {
            const entry = root.activeHandles[id];
            if (entry.coreHandle !== undefined) { if (root.core) root.core.stop(entry.coreHandle); }
            else entry.running = false;
        }
        root.activeHandles = ({});
    }

    function trimMemory() {
        if (root.core && typeof root.core.trimMemory === "function") root.core.trimMemory();
    }
}
