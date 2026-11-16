import QtQuick
import Quickshell
import "../../"

// What the On-Screen Display page does, without its look: the OSD's position (presets or a custom point, saved a
// moment after it settles), its orientation, what it shows (Caps Lock, Num Lock, Airplane mode) and attaching to
// the bar. Used by the Settings page (OnScreenDisplayTab.qml) and the Control Center's board. `selector` is that
// page's ScreenPositionSelector.
Item {
    id: logic
    property var selector: null
    signal customPosition()      // the saved position is not a preset (the page clears its preset list)

    property alias debounceTimer: debounceTimer

    property var defaultOsdSettings: ({
        "horizontalPosition": 50,
        "verticalPosition": 90,
        "orientation": "horizontal",
        "showCapsLock": true,
        "showNumLock": true,
        "showAirplane": true,
        "attachToBar": true
    })

    property var osdSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["osd"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("osd", logic.defaultOsdSettings);
        }
        return logic.defaultOsdSettings;
    }

    property int horizontalPosition: osdSettings && osdSettings.horizontalPosition !== undefined ? osdSettings.horizontalPosition : 50

    property int verticalPosition: osdSettings && osdSettings.verticalPosition !== undefined ? osdSettings.verticalPosition : 90

    property string orientation: osdSettings && osdSettings.orientation !== undefined ? osdSettings.orientation : "horizontal"

    readonly property bool isVertical: orientation === "vertical"

    property bool showCapsLock: osdSettings && osdSettings.showCapsLock !== undefined ? osdSettings.showCapsLock : true

    property bool showNumLock: osdSettings && osdSettings.showNumLock !== undefined ? osdSettings.showNumLock : true

    property bool showAirplane: osdSettings && osdSettings.showAirplane !== undefined ? osdSettings.showAirplane : true

    property bool attachToBar: osdSettings && osdSettings.attachToBar !== undefined ? osdSettings.attachToBar : true

    readonly property bool isCustomPos: {
        let h = horizontalPosition;
        let v = verticalPosition;
        return !(
            (h === 50 && v === 90) ||
            (h === 10 && v === 90) ||
            (h === 90 && v === 90) ||
            (h === 50 && v === 10) ||
            (h === 10 && v === 10) ||
            (h === 90 && v === 10)
        );
    }

    onIsCustomPosChanged: if (isCustomPos) customPosition()

    function applyPosition(h, v) {
        logic.horizontalPosition = h;
        logic.verticalPosition = v;
        if (logic.selector) {
            logic.selector.horizontalPosition = h;
            logic.selector.verticalPosition = v;
        }
        debounceTimer.restart();
    }

    function setPosFromIndex(index) {
        if (index === 0) applyPosition(50, 90);
        else if (index === 1) applyPosition(10, 90);
        else if (index === 2) applyPosition(90, 90);
        else if (index === 3) applyPosition(50, 10);
        else if (index === 4) applyPosition(10, 10);
        else if (index === 5) applyPosition(90, 10);
    }

    function syncSettings() {
        let s = (typeof Config !== "undefined" && typeof Config.getSetting === "function")
            ? Config.getSetting("osd", logic.defaultOsdSettings)
            : logic.defaultOsdSettings;
        logic.osdSettings = s;
        logic.horizontalPosition = s.horizontalPosition !== undefined ? s.horizontalPosition : 50;
        logic.verticalPosition = s.verticalPosition !== undefined ? s.verticalPosition : 90;
        logic.orientation = s.orientation !== undefined ? s.orientation : "horizontal";
        if (logic.selector) {
            logic.selector.horizontalPosition = logic.horizontalPosition;
            logic.selector.verticalPosition = logic.verticalPosition;
        }
        logic.showCapsLock = s.showCapsLock !== undefined ? s.showCapsLock : true;
        logic.showNumLock = s.showNumLock !== undefined ? s.showNumLock : true;
        logic.showAirplane = s.showAirplane !== undefined ? s.showAirplane : true;
        logic.attachToBar = s.attachToBar !== undefined ? s.attachToBar : true;
    }

    function updateOsdSetting(key, value) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("osd", defaultOsdSettings) || defaultOsdSettings));
        current[key] = value;
        Config.setSetting("osd", current);
        logic.osdSettings = current;
    }

    Timer {
        id: debounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            let current = JSON.parse(JSON.stringify(Config.getSetting("osd", defaultOsdSettings) || defaultOsdSettings));
            current.horizontalPosition = logic.horizontalPosition;
            current.verticalPosition = logic.verticalPosition;
            Config.setSetting("osd", current);
            logic.osdSettings = current;
        }
    }

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            logic.syncSettings();
        }
    }
}
