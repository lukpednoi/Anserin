import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import "../"
import "../reusables"
import "../notifications"
import "../widgets"
import "redactor"
import "redactor/elements"

Scope {
    id: root
    property alias uiState: lockUI
    property alias authContext: pam
    property alias suspendProcessHandle: suspendProcess
    property alias reloadProcessHandle: reloadProcess
    property alias poweroffProcessHandle: poweroffProcess
    property alias sessionLock: rootLock

    property string freezeTimestamp: ""
    property bool isUnlocking: false
    property int resumeRevision: 0
    property bool startupFade: false
    readonly property string customBackground: Config.getSetting("lockscreen.backgroundMode", "follow") === "custom" ? Config.getSetting("lockscreen.customBackground", "") : ""

    property bool isNiri: false
    property bool isSway: false
    property string kbLayout: "US"
    property int connectedScreenCount: 1

    readonly property bool isDesktop: UPower.displayDevice.ready ? !UPower.displayDevice.isLaptopBattery : SystemInfo.isDesktop
    readonly property int batCap: UPower.displayDevice.ready ? Math.round(UPower.displayDevice.percentage * 100) : 0
    readonly property string batPercent: batCap + "%"
    readonly property string batStatus: UPower.displayDevice.ready ? (UPower.displayDevice.state === UPowerDeviceState.FullyCharged ? "Full" : (UPower.displayDevice.state === UPowerDeviceState.Charging ? "Charging" : "Unknown")) : "Unknown"
    readonly property bool isCharging: UPower.displayDevice.ready && (UPower.displayDevice.state === UPowerDeviceState.Charging || UPowerDeviceState.FullyCharged)
    readonly property string batIcon: isCharging ? "󰂄" : (batCap > 20 ? "󰁹" : "󰂃")

    readonly property color batDynamicColor: {
        if (batCap <= 15 && !isCharging) return ThemeBackend.red;
        if (batCap <= 25 && !isCharging) return ThemeBackend.peach;
        if (isCharging) return ThemeBackend.green;
        return ThemeBackend.text;
    }

    function updateDeInfo() {
        let de = SystemInfo.desktopEnv ? SystemInfo.desktopEnv.toLowerCase() : "";
        root.isNiri = de.indexOf("niri") !== -1;
        root.isSway = de.indexOf("sway") !== -1;
    }

    function updateScreenCount() {
        root.connectedScreenCount = Quickshell.screens ? Quickshell.screens.length : 1;
    }

    Component.onCompleted: {
        SystemInfo.fetch();
        root.updateDeInfo();
        root.updateScreenCount();
        Quickshell.execDetached(["rm", "-f", Caching.getRunDir("lock") + "/locked"]);
    }

    Component.onDestruction: {
        Quickshell.execDetached(["rm", "-f", Caching.getRunDir("lock") + "/locked"]);
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.updateScreenCount();
        }
    }

    function switchKbLayout() {
        root.updateDeInfo();
        if (root.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
        } else if (root.isSway) {
            Quickshell.execDetached(["swaymsg", "input", "type:keyboard", "xkb_switch_layout", "next"]);
        } else {
            Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"]);
        }
    }

    Timer {
        id: kbPollerRestartTimer
        interval: 400
        repeat: false
        onTriggered: {
            kbWaiter.running = false;
            kbPoller.running = false;
            if (rootLock.locked) kbPoller.running = true;
        }
    }

    Process {
        id: kbPoller
        running: rootLock.locked
        command: [
            "bash",
            "-c",
            root.isNiri
                ? "layout=$(niri msg -j keyboard-layouts 2>/dev/null | jq -r '.names[.current_idx] // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                : (root.isSway
                    ? "layout=$(swaymsg -t get_inputs 2>/dev/null | jq -r '[.[] | select(.type == \"keyboard\" and .xkb_active_layout_name != null)] | .[0].xkb_active_layout_name // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'"
                    : "layout=$(LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '(.keyboards[] | select(.main == true) | .active_keymap) // .keyboards[0].active_keymap // empty' | head -n1); [[ -z \"$layout\" || \"$layout\" == \"null\" ]] && layout=\"US\"; echo \"${layout:0:2}\" | tr '[:lower:]' '[:upper:]'")
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "" && root.kbLayout !== txt) root.kbLayout = txt;
                kbWaiter.running = false;
                if (rootLock.locked) kbWaiter.running = true;
            }
        }
    }

    Process {
        id: kbWaiter
        command: [
            "bash",
            Caching.qsDir + "/watchers/kb_wait.sh",
            root.isNiri ? "niri" : (root.isSway ? "sway" : "hyprland")
        ]
        onExited: {
            kbPoller.running = false;
            if (rootLock.locked) kbPoller.running = true;
        }
    }

    Process {
        id: grimLockSnapProcess
        property string timeStamp: ""
        property var screenNames: []

        command: {
            let ts = timeStamp;
            let dir = Caching.getRunDir("screenshot");
            let cmd = "dir=\"" + dir + "\"; mkdir -p \"$dir\"; ";
            let mons = screenNames;
            if (mons && mons.length > 0) {
                for (let i = 0; i < mons.length; i++) {
                    let m = mons[i];
                    cmd += "grim -o \"" + m + "\" -l 0 \"$dir/lock_freeze_" + m + "_" + ts + ".png\" & ";
                }
                cmd += "wait; ";
                let firstMon = mons[0];
                cmd += "ln -sf \"$dir/lock_freeze_" + firstMon + "_" + ts + ".png\" \"$dir/lock_freeze_default_" + ts + ".png\" 2>/dev/null || cp -f \"$dir/lock_freeze_" + firstMon + "_" + ts + ".png\" \"$dir/lock_freeze_default_" + ts + ".png\" 2>/dev/null || true;";
            } else {
                cmd += "grim -l 0 \"$dir/lock_freeze_default_" + ts + ".png\" || exit 1;";
            }
            return ["bash", "-c", cmd];
        }

        onExited: (exitCode) => {
            grimTimeoutTimer.stop();
            if (exitCode === 0) {
                root.freezeTimestamp = timeStamp;
            } else {
                root.freezeTimestamp = "";
            }
            root.doLock();
        }
    }

    Timer {
        id: grimTimeoutTimer
        interval: 500
        repeat: false
        onTriggered: {
            grimLockSnapProcess.running = false;
            root.doLock();
        }
    }

    function lock() {
        if (rootLock.locked) return;
        let ts = Date.now().toString();
        let mons = [];
        if (Quickshell.screens) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                if (Quickshell.screens[i] && Quickshell.screens[i].name) {
                    mons.push(Quickshell.screens[i].name);
                }
            }
        }
        grimLockSnapProcess.screenNames = mons;
        grimLockSnapProcess.timeStamp = ts;
        grimLockSnapProcess.running = false;
        grimLockSnapProcess.running = true;
        grimTimeoutTimer.restart();
    }

    function doLock() {
        Config.sessionLocked = true;
        grimTimeoutTimer.stop();
        SystemInfo.fetch();
        root.updateDeInfo();
        root.updateScreenCount();
        root.isUnlocking = false;
        lockUI.failed = false;
        lockUI.authenticating = false;
        lockUI.statusText = I18n.t("lock.status.locked");
        rootLock.locked = true;
        pamActionTimer.start();
        kbPollerRestartTimer.restart();
    }

    function finishUnlock() {
        if (root.isUnlocking) return;
        root.isUnlocking = true;
    }

    function completeUnlock() {
        if (!rootLock.locked || !root.isUnlocking) return;
        rootLock.locked = false;
        root.isUnlocking = false;
        kbWaiter.running = false;
        kbPoller.running = false;
        Quickshell.execDetached(["rm", "-f", Caching.getRunDir("lock") + "/locked"]);
        if (root.freezeTimestamp !== "") {
            Quickshell.execDetached(["bash", "-c", "rm -f " + Caching.getRunDir("screenshot") + "/lock_freeze_*_" + root.freezeTimestamp + ".png"]);
            root.freezeTimestamp = "";
        }
        Config.sessionLocked = false;
        Qt.callLater(function() {
            gc();
            if (typeof Sounds !== "undefined") Sounds.trimMemory();
        });
    }

    IpcHandler {
        target: "lock"
        function activate(): void {
            root.lock();
        }
        function startup(): void {
            if (rootLock.locked) return;
            root.startupFade = true;
            root.freezeTimestamp = "";
            root.doLock();
        }
        function startupReady(): bool { return rootLock.secure && !root.startupFade; }
    }


    QtObject {
        id: lockUI
        property bool failed: false
        property bool authenticating: false
        property string statusText: I18n.t("lock.status.locked")
    }

    Timer {
        id: pamActionTimer
        interval: 350
        onTriggered: {
            if (rootLock.locked) {
                pam.start();
            }
        }
    }

    PamContext {
        id: pam

        onCompleted: (result) => {
            lockUI.authenticating = false;
            if (result === PamResult.Success) {
                root.finishUnlock();
            } else {
                lockUI.failed = true;
                lockUI.statusText = I18n.t("lock.status.access_denied");
                pamActionTimer.start();
            }
        }
    }

    Process {
        id: suspendProcess
        command: ["bash", Caching.anserinDir + "/scripts/system/suspend.sh"]
        onExited: {
            SystemInfo.fetch();
            root.updateDeInfo();
            pamActionTimer.restart();
            kbPollerRestartTimer.restart();
            root.resumeRevision++;
            if (rootLock.locked) {
                pam.start();
            }
        }
    }

    Process {
        id: poweroffProcess
        command: ["bash", Caching.anserinDir + "/scripts/system/poweroff.sh"]
    }

    Process {
        id: reloadProcess
        command: ["bash", Caching.anserinDir + "/scripts/system/reboot.sh"]
    }

    readonly property bool isLocked: rootLock.locked
    readonly property Component sceneComponent: Component {
        LockScreen {
            surface: parent ? parent.sceneHost : null
            lockController: root
            rootLock: root.sessionLock
            pam: root.authContext
            lockUI: root.uiState
            suspendProcess: root.suspendProcessHandle
            reloadProcess: root.reloadProcessHandle
            poweroffProcess: root.poweroffProcessHandle
        }
    }

    WlSessionLock {
        id: rootLock
        locked: false
        onSecureChanged: if (secure) root.startupFade = false
        onLockedChanged: {
            let lockFile = Caching.getRunDir("lock") + "/locked";
            if (locked) {
                Quickshell.execDetached(["touch", lockFile]);
            } else {
                Quickshell.execDetached(["rm", "-f", lockFile]);
            }
        }

        surface: Component {
            WlSessionLockSurface {
                id: surface

                Loader {
                    anchors.fill: parent
                    focus: true
                    property var sceneHost: surface
                    property bool decorationMode: false
                    property string decorationStage: "lockscreen"
                    sourceComponent: root.sceneComponent
                }
            }
        }
    }
}
