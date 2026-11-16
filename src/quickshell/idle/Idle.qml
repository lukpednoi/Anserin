import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../"
import "../guide/shared"

Item {
    id: idleRoot

    // Settings, defaults, timeouts and the order check are shared with the Idle settings pages.
    IdleLogic { id: logic }
    readonly property bool isNiri: logic.isNiri
    readonly property var defaultIdleSettings: logic.defaultIdleSettings
    readonly property var idleSettings: logic.idleSettings
    readonly property bool idleEnabled: logic.idleEnabled
    property bool manualInhibit: Caffeine.enabled
    property bool isIdleSystemActive: idleEnabled && !manualInhibit
    property bool isDimmed: false
    property bool isLocked: false

    property bool isMediaPlaying: {
        try {
            return Mpris.players && Mpris.players.values ? Mpris.players.values.some(p => p.playbackState === MprisPlaybackState.Playing) : false;
        } catch (e) {
            return false;
        }
    }

    // Set while an app asks org.freedesktop.ScreenSaver not to lock (games, Steam, Wine)
    property bool isAppInhibited: false

    Process {
        id: screensaverProc
        running: Caching.qsDir !== ""
        command: ["python3", Caching.qsDir + "/idle/screensaver_inhibit.py"]
        stdout: SplitParser {
            onRead: data => idleRoot.isAppInhibited = data.trim() === "1"
        }
        onExited: (exitCode, exitStatus) => {
            idleRoot.isAppInhibited = false;
            // 0 means python-jeepney is missing, no point in retrying
            if (exitCode !== 0) screensaverRestartTimer.restart();
        }
    }

    Timer {
        id: screensaverRestartTimer
        interval: 10000
        onTriggered: screensaverProc.running = true
    }

    property var allActions: {
        let list = [];
        let acts = (idleSettings && idleSettings.actions) ? idleSettings.actions : defaultIdleSettings.actions;
        let keys = ["dim", "lock", "dpms", "suspend"];

        for (let i = 0; i < keys.length; i++) {
            let key = keys[i];
            let act = (acts && acts[key]) ? Object.assign({}, defaultIdleSettings.actions[key], acts[key]) : defaultIdleSettings.actions[key];
            list.push(act);
        }

        let customs = (idleSettings && idleSettings.customActions) ? idleSettings.customActions : [];
        for (let j = 0; j < customs.length; j++) {
            list.push(customs[j]);
        }
        return list;
    }

    function getActionTimeout(act) { return logic.getActionTimeout(act); }
    function isActionPipelineValid(actionObj) { return !!actionObj && logic.isActionPipelineValid(actionObj); }

    Timer {
        id: frameSettleTimer
        interval: 100
        repeat: false
        property var pendingCallback: null
        onTriggered: {
            if (pendingCallback) {
                pendingCallback();
                pendingCallback = null;
            }
        }
    }

    Timer {
        id: suspendTimer
        interval: 200
        repeat: false
        onTriggered: {
            Quickshell.execDetached(["systemctl", "suspend"]);
        }
    }

    function runCmd(cmd) {
        if (cmd && cmd.trim().length > 0) {
            Quickshell.execDetached(["sh", "-c", cmd]);
        }
    }

    function lockSession() {
        Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/lock.sh"]);
    }

    function performLock() {
        idleRoot.isLocked = true;
        idleRoot.lockSession();
    }

    function dpmsOff() {
        if (idleRoot.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]);
        } else {
            Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })' 2>/dev/null || hyprctl dispatch 'hl.dsp.dpms({ action = \"off\" })' 2>/dev/null || hyprctl dispatch dpms off"]);
        }
    }

    function dpmsOn() {
        if (idleRoot.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "power-on-monitors"]);
        } else {
            Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })' 2>/dev/null || hyprctl dispatch 'hl.dsp.dpms({ action = \"on\" })' 2>/dev/null || hyprctl dispatch dpms on"]);
        }
    }

    function teardownVisualStates() {
        if (idleRoot.isDimmed) {
            idleRoot.isDimmed = false;
        }
    }

    function triggerWarning(actionObj) {
        if (!actionObj || !idleRoot.isActionPipelineValid(actionObj)) return;
        idleRoot.runCmd(actionObj.warningCommand);
    }

    function triggerAction(actionObj) {
        if (!actionObj || !idleRoot.isActionPipelineValid(actionObj)) return;

        let id = (actionObj.id || "").toLowerCase();

        if (id === "dim") {
            if (!idleRoot.isLocked) {
                idleRoot.runCmd(actionObj.beforeCommand);
                idleRoot.isDimmed = true;
                idleRoot.runCmd(actionObj.command);
            }
            return;
        }

        idleRoot.teardownVisualStates();

        if (id === "lock") {
            idleRoot.runCmd(actionObj.beforeCommand);
            frameSettleTimer.pendingCallback = function() {
                idleRoot.performLock();
                idleRoot.runCmd(actionObj.command);
            };
            frameSettleTimer.restart();
            return;
        }

        if (id === "dpms") {
            idleRoot.runCmd(actionObj.beforeCommand);
            idleRoot.dpmsOff();
            idleRoot.runCmd(actionObj.command);
            return;
        }

        if (id === "suspend") {
            if (!idleRoot.isLocked) {
                idleRoot.performLock();
            }
            idleRoot.runCmd(actionObj.command);
            suspendTimer.restart();
            return;
        }

        idleRoot.runCmd(actionObj.beforeCommand);
        idleRoot.runCmd(actionObj.command);
    }

    function resumeAction(actionObj) {
        if (!actionObj) return;

        let id = (actionObj.id || "").toLowerCase();
        if (id === "dim") {
            idleRoot.isDimmed = false;
        } else if (id === "lock") {
            frameSettleTimer.stop();
            idleRoot.isLocked = false;
        } else if (id === "dpms") {
            if (actionObj.resumeCommand && actionObj.resumeCommand.trim().length > 0) idleRoot.runCmd(actionObj.resumeCommand);
            else idleRoot.dpmsOn();
            return;
        } else if (id === "suspend") {
            suspendTimer.stop();
            return;
        }

        idleRoot.runCmd(actionObj.resumeCommand);
    }

    function executeAction(name) {
        if (!name) return;
        let target = name.toString().trim().toLowerCase();
        let actionObj = idleRoot.allActions.find(a => (a.id && a.id.toLowerCase() === target) || (a.name && a.name.toLowerCase() === target));
        if (actionObj) {
            idleRoot.triggerAction(actionObj);
        }
    }

    IpcHandler {
        target: "idle"
        function trigger(name: string): void { idleRoot.executeAction(name); }
        function execute(name: string): void { idleRoot.executeAction(name); }
        function run(name: string): void { idleRoot.executeAction(name); }
    }

    Dim {
        active: idleRoot.isIdleSystemActive && idleRoot.isDimmed
    }

    Repeater {
        model: idleRoot.allActions
        delegate: Item {
            id: monitorDelegate
            required property var modelData

            property int actionTimeout: idleRoot.getActionTimeout(monitorDelegate.modelData)
            property int warnLead: Math.round(Number(monitorDelegate.modelData && monitorDelegate.modelData.warningTimeout ? monitorDelegate.modelData.warningTimeout : 0))
            property int warnTimeout: Math.max(1, actionTimeout - warnLead)
            property bool hasWarning: monitorDelegate.modelData && monitorDelegate.modelData.warningCommand && monitorDelegate.modelData.warningCommand.trim().length > 0 && warnLead > 0 && warnLead < actionTimeout
            property bool isActionEnabled: monitorDelegate.modelData && monitorDelegate.modelData.enabled !== undefined ? monitorDelegate.modelData.enabled : true
            property bool isValidInPipeline: idleRoot.isActionPipelineValid(monitorDelegate.modelData)
            property bool respectsInhibitors: monitorDelegate.modelData && monitorDelegate.modelData.respectInhibitors !== undefined ? monitorDelegate.modelData.respectInhibitors : true

            IdleMonitor {
                timeout: monitorDelegate.warnTimeout
                enabled: idleRoot.isIdleSystemActive &&
                         monitorDelegate.isValidInPipeline &&
                         monitorDelegate.isActionEnabled &&
                         monitorDelegate.hasWarning &&
                         (!monitorDelegate.modelData || !monitorDelegate.modelData.mprisInhibit || !idleRoot.isMediaPlaying) &&
                         (!monitorDelegate.respectsInhibitors || !idleRoot.isAppInhibited)
                respectInhibitors: monitorDelegate.respectsInhibitors

                onIsIdleChanged: {
                    if (isIdle) {
                        idleRoot.triggerWarning(monitorDelegate.modelData);
                    }
                }
            }

            IdleMonitor {
                timeout: monitorDelegate.actionTimeout
                enabled: idleRoot.isIdleSystemActive &&
                         monitorDelegate.isValidInPipeline &&
                         monitorDelegate.isActionEnabled &&
                         (!monitorDelegate.modelData || !monitorDelegate.modelData.mprisInhibit || !idleRoot.isMediaPlaying) &&
                         (!monitorDelegate.respectsInhibitors || !idleRoot.isAppInhibited)
                respectInhibitors: monitorDelegate.respectsInhibitors

                onIsIdleChanged: {
                    if (isIdle) {
                        idleRoot.triggerAction(monitorDelegate.modelData);
                    } else {
                        idleRoot.resumeAction(monitorDelegate.modelData);
                    }
                }
            }
        }
    }

    Loader {
        active: idleRoot.manualInhibit
        sourceComponent: PanelWindow {
            id: inhibitWindow
            color: "transparent"
            screen: (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null
            anchors.top: true
            anchors.left: true
            implicitWidth: 1
            implicitHeight: 1
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            IdleInhibitor {
                window: inhibitWindow
                enabled: true
            }
        }
    }
}
