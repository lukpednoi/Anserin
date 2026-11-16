import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// What the Notifications page does, without its look: the position (presets inside the screen's safe area, or
// a custom point, saved a moment after it settles), Do not disturb, the empty-centre graphic, the sound and its
// files (the bundled ones and the user's, installing one). Used by the Settings page (NotificationsTab.qml) and
// the Control Center's board. `selector` is that page's ScreenPositionSelector (it knows the safe area).
Item {
    id: logic
    property var selector: null
    signal customPosition()      // the saved position is not a preset (the page clears its preset list)
    signal soundInstalled()      // a sound file was installed (the page closes its picker)
    property alias debounceTimer: debounceTimer
    property alias reloadSoundsDebounceTimer: reloadSoundsDebounceTimer

    readonly property int presetTopV: logic.selector ? logic.selector.safeTopPercent : 5

    readonly property int presetBottomV: logic.selector ? logic.selector.safeBottomPercent : 95

    readonly property int presetLeftH: logic.selector ? logic.selector.safeLeftPercent : 5

    readonly property int presetRightH: logic.selector ? logic.selector.safeRightPercent : 95

    readonly property int presetCenterH: 50

    onPresetTopVChanged: {
        if (position !== "custom" && position.indexOf("top") !== -1) {
            verticalPosition = presetTopV;
            if (logic.selector) logic.selector.verticalPosition = presetTopV;
        }
    }

    onPresetBottomVChanged: {
        if (position !== "custom" && position.indexOf("bottom") !== -1) {
            verticalPosition = presetBottomV;
            if (logic.selector) logic.selector.verticalPosition = presetBottomV;
        }
    }

    onPresetLeftHChanged: {
        if (position !== "custom" && position.indexOf("left") !== -1) {
            horizontalPosition = presetLeftH;
            if (logic.selector) logic.selector.horizontalPosition = presetLeftH;
        }
    }

    onPresetRightHChanged: {
        if (position !== "custom" && position.indexOf("right") !== -1) {
            horizontalPosition = presetRightH;
            if (logic.selector) logic.selector.horizontalPosition = presetRightH;
        }
    }

    property var defaultNotificationSettings: ({
        "dnd": false,
        "position": "top right",
        "horizontalPosition": presetRightH,
        "verticalPosition": presetTopV,
        "sound": true,
        "soundFile": "",
        "showEmptyGraphic": true
    })

    property var notifSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["notifications"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("notifications", logic.defaultNotificationSettings);
        }
        return logic.defaultNotificationSettings;
    }

    property bool dnd: notifSettings && notifSettings.dnd !== undefined ? notifSettings.dnd : false

    property string position: notifSettings && notifSettings.position !== undefined ? notifSettings.position : "top right"

    property int horizontalPosition: {
        if (position !== "custom") {
            if (position.indexOf("left") !== -1) return presetLeftH;
            if (position.indexOf("center") !== -1) return presetCenterH;
            return presetRightH;
        }
        if (notifSettings && notifSettings.horizontalPosition !== undefined) return notifSettings.horizontalPosition;
        return presetRightH;
    }

    property int verticalPosition: {
        if (position !== "custom") {
            if (position.indexOf("bottom") !== -1) return presetBottomV;
            return presetTopV;
        }
        if (notifSettings && notifSettings.verticalPosition !== undefined) return notifSettings.verticalPosition;
        return presetTopV;
    }

    property bool soundEnabled: notifSettings && notifSettings.sound !== undefined ? notifSettings.sound : true

    property string selectedSound: notifSettings && notifSettings.soundFile !== undefined ? notifSettings.soundFile : ""

    property bool showEmptyGraphic: notifSettings && notifSettings.showEmptyGraphic !== undefined ? notifSettings.showEmptyGraphic : true

    function getPresetIndex(h, v) {
        if (Math.abs(v - presetTopV) <= 2 && Math.abs(h - presetRightH) <= 2) return 0;
        if (Math.abs(v - presetTopV) <= 2 && Math.abs(h - presetCenterH) <= 2) return 1;
        if (Math.abs(v - presetTopV) <= 2 && Math.abs(h - presetLeftH) <= 2) return 2;
        if (Math.abs(v - presetBottomV) <= 2 && Math.abs(h - presetRightH) <= 2) return 3;
        if (Math.abs(v - presetBottomV) <= 2 && Math.abs(h - presetCenterH) <= 2) return 4;
        if (Math.abs(v - presetBottomV) <= 2 && Math.abs(h - presetLeftH) <= 2) return 5;
        return -1;
    }

    function getPosStringFromIndex(index) {
        if (index === 0) return "top right";
        if (index === 1) return "top center";
        if (index === 2) return "top left";
        if (index === 3) return "bottom right";
        if (index === 4) return "bottom center";
        if (index === 5) return "bottom left";
        return "custom";
    }

    readonly property bool isCustomPos: {
        if (position === "custom") return true;
        let validPresets = ["top right", "top center", "top left", "bottom right", "bottom center", "bottom left"];
        return validPresets.indexOf(position) === -1;
    }

    onIsCustomPosChanged: if (isCustomPos) customPosition()

    property var soundList: []

    property var availableSounds: {
        let names = [];
        for (let i = 0; i < soundList.length; i++) {
            names.push(soundList[i].name);
        }
        return names;
    }

    function applyPosition(h, v, posStr) {
        // already there (the dropdown reports the index it was just given): writing again would loop its binding
        if (logic.position === posStr && logic.horizontalPosition === h && logic.verticalPosition === v) return;
        logic.horizontalPosition = h;
        logic.verticalPosition = v;
        logic.position = posStr;
        if (logic.selector) {
            logic.selector.horizontalPosition = h;
            logic.selector.verticalPosition = v;
        }
        debounceTimer.restart();
    }

    function setPosFromIndex(index) {
        if (index === 0) applyPosition(presetRightH, presetTopV, "top right");
        else if (index === 1) applyPosition(presetCenterH, presetTopV, "top center");
        else if (index === 2) applyPosition(presetLeftH, presetTopV, "top left");
        else if (index === 3) applyPosition(presetRightH, presetBottomV, "bottom right");
        else if (index === 4) applyPosition(presetCenterH, presetBottomV, "bottom center");
        else if (index === 5) applyPosition(presetLeftH, presetBottomV, "bottom left");
    }

    function updateNotifSetting(key, val) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("notifications", defaultNotificationSettings) || defaultNotificationSettings));
        current[key] = val;
        Config.setSetting("notifications", current);
        logic.notifSettings = current;
    }

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("notifications", logic.defaultNotificationSettings)
            : logic.defaultNotificationSettings;
        logic.dnd = s.dnd !== undefined ? s.dnd : false;
        logic.position = s.position !== undefined ? s.position : "top right";
        if (logic.position !== "custom") {
            logic.horizontalPosition = logic.position.indexOf("left") !== -1 ? presetLeftH : (logic.position.indexOf("center") !== -1 ? presetCenterH : presetRightH);
            logic.verticalPosition = logic.position.indexOf("bottom") !== -1 ? presetBottomV : presetTopV;
        } else {
            logic.horizontalPosition = s.horizontalPosition !== undefined ? s.horizontalPosition : presetRightH;
            logic.verticalPosition = s.verticalPosition !== undefined ? s.verticalPosition : presetTopV;
        }
        if (logic.selector) {
            logic.selector.horizontalPosition = logic.horizontalPosition;
            logic.selector.verticalPosition = logic.verticalPosition;
        }
        logic.soundEnabled = s.sound !== undefined ? s.sound : true;
        logic.selectedSound = s.soundFile !== undefined ? s.soundFile : "";
        logic.showEmptyGraphic = s.showEmptyGraphic !== undefined ? s.showEmptyGraphic : true;
        logic.notifSettings = s;
    }

    Timer {
        id: debounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            let current = JSON.parse(JSON.stringify(Config.getSetting("notifications", defaultNotificationSettings) || defaultNotificationSettings));
            current.horizontalPosition = logic.horizontalPosition;
            current.verticalPosition = logic.verticalPosition;
            current.position = logic.position;
            Config.setSetting("notifications", current);
            logic.notifSettings = current;
        }
    }

    function reloadSounds() {
        soundsLoader.running = false;
        soundsLoader.running = true;
    }

    Process {
        id: soundsLoader
        running: false
        command: {
            let assetsPath = Caching.anserinDir ? (Caching.anserinDir + "/assets/sounds/notifications") : (Caching.qsDir ? (Caching.qsDir + "/../assets/sounds/notifications") : "");
            let userPath = Caching.stateDir ? (Caching.stateDir + "/sounds/notifications") : (Caching.home + "/.local/state/anserin/sounds/notifications");
            let script =
                "mkdir -p \"" + userPath + "\"; " +
                "python3 -c '\n" +
                "import os, json, sys\n" +
                "assets = sys.argv[1]\n" +
                "user = sys.argv[2]\n" +
                "exts = (\".wav\", \".ogg\", \".mp3\", \".flac\", \".opus\", \".oga\", \".m4a\", \".aac\")\n" +
                "res = {}\n" +
                "for p in [assets, user]:\n" +
                "    if os.path.exists(p):\n" +
                "        for f in os.listdir(p):\n" +
                "            if f.lower().endswith(exts):\n" +
                "                name = os.path.splitext(f)[0]\n" +
                "                res[name] = os.path.join(p, f)\n" +
                "out = [{\"name\": k, \"path\": v} for k, v in sorted(res.items(), key=lambda x: x[0].lower())]\n" +
                "print(json.dumps(out))\n" +
                "' \"" + assetsPath + "\" \"" + userPath + "\"";
            return ["bash", "-c", script];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text.trim();
                    if (txt !== "") {
                        let list = JSON.parse(txt);
                        if (Array.isArray(list)) {
                            logic.soundList = list;
                            let found = false;
                            for (let i = 0; i < list.length; i++) {
                                if (list[i].path === logic.selectedSound || list[i].name === logic.selectedSound) {
                                    logic.selectedSound = list[i].path;
                                    logic.updateNotifSetting("soundFile", list[i].path);
                                    found = true;
                                    break;
                                }
                            }
                            if (!found) {
                                if (list.length > 0) {
                                    logic.selectedSound = list[0].path;
                                    logic.updateNotifSetting("soundFile", list[0].path);
                                } else {
                                    logic.selectedSound = "";
                                    logic.updateNotifSetting("soundFile", "");
                                }
                            }
                        }
                    } else {
                        logic.soundList = [];
                        logic.selectedSound = "";
                        logic.updateNotifSetting("soundFile", "");
                    }
                } catch (e) {}
            }
        }
    }

    function installSound(filePath, fileName) {
        if (!filePath || filePath.trim() === "" || !fileName || fileName.trim() === "") return;
        let userSoundsPath = Caching.stateDir ? (Caching.stateDir + "/sounds/notifications") : (Caching.home + "/.local/state/anserin/sounds/notifications");
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };

        let script =
            "D=\"" + escapeBash(userSoundsPath) + "\"; " +
            "B=\"" + escapeBash(fileName) + "\"; " +
            "S=\"" + escapeBash(filePath) + "\"; " +
            "mkdir -p \"$D\"; " +
            "if [ ! -f \"$D/$B\" ]; then cp \"$S\" \"$D/$B\"; fi; " +
            "NAME=$(basename \"$B\" | sed 's/\\.[^.]*$//'); " +
            "echo \"$NAME|$D/$B\";";

        soundInstallProcess.command = ["bash", "-c", script];
        soundInstallProcess.running = true;
    }

    Process {
        id: soundInstallProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out !== "") {
                    let idx = out.indexOf('|');
                    let sPath = idx !== -1 ? out.substring(idx + 1).trim() : "";
                    if (sPath !== "") {
                        logic.selectedSound = sPath;
                        logic.updateNotifSetting("soundFile", sPath);
                        logic.reloadSounds();
                        if (typeof Sounds !== "undefined" && typeof Sounds.play === "function") {
                            Sounds.play(sPath);
                        }
                    }
                }
                logic.soundInstalled();
            }
        }
    }

    Timer {
        id: reloadSoundsDebounceTimer
        interval: 220
        repeat: false
        onTriggered: reloadSounds()
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            logic.syncSettings();
        }
    }
}
