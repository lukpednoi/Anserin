import QtQuick
import QtQuick.Layouts
import ".."
import "../../../"
import "../../../guide/display"

// 3A. DISPLAY -> GENERAL (clean monitor controls, Color Temp in tens 0..100, real WidgetPresetGrid)
Column {
    id: page
    property var app: null
    spacing: 11

    DisplayLogic { id: dlogic; rootObj: page.app ? page.app.shim : null; tabIndex: page.app ? page.app.catIdx : 2; shown: page.visible }
    WidgetsLogic { id: wlogic; rootObj: page.app ? page.app.shim : null; shown: page.visible; onPageHidden: savePopup.close() }
    Item {
        width: 0; height: 0; visible: false
        SavePresetPopup {
            id: savePopup
            rootObj: page.app ? page.app.shim : null
            onOpened: if (page.app) page.app.modalOpened()
            onClosed: if (page.app) page.app.modalClosed()
            onSaveRequested: function(presetName, monName, widgetsList) { wlogic.saveCustomPreset(presetName, monName, widgetsList); }
        }
    }
    Component.onDestruction: savePopup.close()

    readonly property var monitors: dlogic.monitorsList
    function monSettings(name) { const d = dlogic.displaySettings; return d && d.monitors && d.monitors[name] ? d.monitors[name] : ({}); }
    function monPowered(m) { const ms = monSettings(m.name); return ms.powerEnabled !== undefined ? ms.powerEnabled : (m.active !== undefined ? m.active : true); }
    function setMonPower(name, v) { dlogic.updateMonitorSetting(name, "powerEnabled", v); dlogic.applyMonitorPower(name, v); }
    function nightOn(name) { const ms = monSettings(name); return ms.enabled !== undefined ? ms.enabled : false; }
    function nightAutoOf(name) { const ms = monSettings(name); return ms.auto !== undefined ? ms.auto : false; }
    function setNight(name, v) { BlueLight.setEnabled(name, v); dlogic.refreshDisplaySettings(); }
    function setNightAuto(name, v) { BlueLight.setAuto(name, v); dlogic.refreshDisplaySettings(); }

    property var tempDrag: ({})
    function monTemp(name) { if (tempDrag[name] !== undefined) return tempDrag[name]; const ms = monSettings(name); return ms.temperature !== undefined ? ms.temperature : 50; }
    function moveTemp(name, frac) {
        const r = Math.round(frac * 10) * 10;
        if (r === tempDrag[name]) return;
        const t = Object.assign({}, tempDrag); t[name] = r; tempDrag = t;
        dlogic.updateMonitorSettingDebounced(name, r);
    }
    function releaseTemp(name) {
        dlogic.flushMonitorSetting(name);
        const t = Object.assign({}, tempDrag); delete t[name]; tempDrag = t;
    }

    property var scaleShown: ({})
    function monScales(m) {
        const dims = m.dimensions ? m.dimensions.split("x") : ["1920", "1080"];
        return dlogic.validScalesForResolution(parseInt(dims[0]) || 1920, parseInt(dims[1]) || 1080);
    }
    function monScale(m) { return scaleShown[m.name] !== undefined ? scaleShown[m.name] : (m.scale !== undefined ? m.scale : 1.0); }
    function monScaleFrac(m) {
        const sc = monScales(m); if (sc.length < 2) return 0;
        let i = sc.indexOf(monScale(m)); if (i < 0) i = Math.max(0, sc.indexOf(dlogic.nearestValidScaleFromList(sc, monScale(m))));
        return i / (sc.length - 1);
    }
    function moveScale(m, frac) {
        const sc = monScales(m); if (sc.length === 0) return;
        const v = sc[Math.round(frac * (sc.length - 1))];
        if (v === monScale(m)) return;
        const t = Object.assign({}, scaleShown); t[m.name] = v; scaleShown = t;
        dlogic.scaleMoved(m.name, v);
    }
    function scaleText(m) { return monScale(m).toFixed(3).replace(/0+$/, '').replace(/\.$/, '.0') + "×"; }
    onMonitorsChanged: scaleShown = ({})

    function widgetsOf(name) { return wlogic.monitorWidgetsMap && wlogic.monitorWidgetsMap[name] ? wlogic.monitorWidgetsMap[name] : []; }
    property var showWidgetPresetsFor: ({})
    function toggleWidgetPresets(name) { const t = Object.assign({}, showWidgetPresetsFor); t[name] = !t[name]; showWidgetPresetsFor = t; }

    component SCard: SmartCard {
        cornerRadius: page.app.cornerRadius; darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cCard; accent: page.app.cAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SToggle: SmartGeoToggleTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SSlider: SmartSliderTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; accent: page.app.cAccent; accent2: page.app.cAccent2
        textColor: page.app.cText; subColor: page.app.cSub; uiFont: page.app.uiFont; iconFont: page.app.iconFont
        active: visible; onStepped: page.app.sfx.playTick(); onLockedFull: page.app.sfx.playLock()
    }
    component SAction: SmartActionTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component TileGrid: GridLayout { width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8 }

    Repeater {
        model: page.monitors
        SCard {
            id: monCard
            required property var modelData
            readonly property string mon: modelData.name
            readonly property bool nightOn: page.nightOn(mon)
            readonly property bool nightAuto: page.nightAutoOf(mon)
            width: parent.width
            title: mon; icon: "󰍹"; statusText: (modelData.dimensions || "").replace("x", "×") + " • " + Math.round(modelData.framerate || 60) + "Hz"
            TileGrid {
                SToggle { visible: page.monitors.length > 1; Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰐥"; title: "Enable Monitor"; geoShape: "squircle"; checked: page.monPowered(monCard.modelData); onToggled: (v) => { page.setMonPower(monCard.mon, v); page.app.sfx.playToggle(v); } }
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰖔"; title: "Night Light"; geoShape: "cookie9"; checked: monCard.nightOn; onToggled: (v) => { page.setNight(monCard.mon, v); page.app.sfx.playToggle(v); } }
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰥔"; title: "Auto Schedule"; geoShape: "clover3"; available: monCard.nightOn; checked: monCard.nightAuto; onToggled: (v) => { page.setNightAuto(monCard.mon, v); page.app.sfx.playToggle(v); } }
            }
            Text {
                visible: monCard.nightOn && monCard.nightAuto && (dlogic.scheduleDescription || "") !== ""
                width: parent.width; leftPadding: 4; wrapMode: Text.WordWrap
                text: dlogic.scheduleDescription || ""; font.family: page.app.uiFont; font.pixelSize: 10; color: page.app.cSub
            }
            SSlider {
                visible: monCard.nightOn && !monCard.nightAuto
                icon: "󰔏"; title: "Color Temperature"
                value: page.monTemp(monCard.mon) / 100
                valueText: String(page.monTemp(monCard.mon))
                onMoved: (v) => page.moveTemp(monCard.mon, v)
                onReleased: page.releaseTemp(monCard.mon)
            }
            SSlider {
                icon: "󰍍"; title: "UI Scale"; value: page.monScaleFrac(monCard.modelData)
                step: 1 / Math.max(1, page.monScales(monCard.modelData).length - 1)
                valueText: page.scaleText(monCard.modelData)
                onMoved: (v) => page.moveScale(monCard.modelData, v)
                onReleased: dlogic.scaleReleased()
            }
        }
    }

    Repeater {
        model: page.monitors
        SCard {
            id: wCard
            required property var modelData
            readonly property string mon: modelData.name
            readonly property int count: page.widgetsOf(mon).length
            readonly property bool presetsOpen: page.showWidgetPresetsFor[mon] === true
            width: parent.width
            title: "Widgets · " + mon; icon: "󰋩"; statusText: count + (count === 1 ? " WIDGET" : " WIDGETS")
            TileGrid {
                SAction { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰐕"; title: "Save as preset"; actionText: "Save"; onTriggered: { page.app.sfx.playQuick(); savePopup.openForMonitor(wCard.mon, page.widgetsOf(wCard.mon)); } }
                SAction { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰄛"; title: "Choose a preset"; actionText: wCard.presetsOpen ? "Hide" : "Show"; onTriggered: { page.toggleWidgetPresets(wCard.mon); page.app.sfx.playClick(); } }
            }
            Loader {
                width: parent.width
                active: wCard.presetsOpen && page.visible
                visible: active
                height: item ? item.implicitHeight : 0
                sourceComponent: WidgetPresetGrid { logic: wlogic; monName: wCard.mon; rootObj: page.app.shim }
            }
        }
    }
}
