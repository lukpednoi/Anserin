import QtQuick
import QtQuick.Window
import "../../../"
import "../../../guide/display"
import "../../../widgets"
import ".."

// Display → General as a board. It runs the Settings page's own logic (guide/display/DisplayLogic.qml): the
// monitors: for every monitor its power (with more than one), night light, schedule
// and warmth (BlueLight) and its UI scale (the compositor, a second after the last move), and the desktop
// widgets (WidgetsLogic: the redactor, each screen's presets as the real preview cards, its widgets).
BoardPage {
    id: page
    extras: [
        DisplayLogic { id: logic; rootObj: page.rootObj; tabIndex: page.tabIndex; shown: page.visible },
        WidgetsLogic { id: wlogic; rootObj: page.rootObj; shown: page.visible; onPageHidden: savePopup.close() },
        SavePresetPopup { id: savePopup; rootObj: page.rootObj
                          onSaveRequested: function(presetName, monName, widgetsList) { wlogic.saveCustomPreset(presetName, monName, widgetsList); } }
    ]
    readonly property var ds: logic.displaySettings

    Repeater {
        model: logic.monitorsList
        BoardCard {
            id: mon
            required property var modelData
            readonly property string name: modelData.name
            readonly property var ms: page.ds && page.ds.monitors && page.ds.monitors[name] ? page.ds.monitors[name] : ({})
            readonly property bool powered: ms.powerEnabled !== undefined ? ms.powerEnabled : (modelData.active !== undefined ? modelData.active : true)
            readonly property bool filterOn: ms.enabled !== undefined ? ms.enabled : false
            readonly property bool filterAuto: ms.auto !== undefined ? ms.auto : false
            property real dragTemp: NaN
            readonly property var dims: modelData.dimensions ? modelData.dimensions.split("x") : ["1920", "1080"]
            readonly property var scales: logic.validScalesForResolution(parseInt(dims[0]) || 1920, parseInt(dims[1]) || 1080)
            property real shownScale: modelData.scale !== undefined ? modelData.scale : 1.0
            readonly property int scaleIndex: {
                const i = scales.indexOf(shownScale);
                if (i >= 0) return i;
                const n = scales.indexOf(logic.nearestValidScaleFromList(scales, shownScale));
                return n >= 0 ? n : 0;
            }
            onModelDataChanged: if (logic.pendingMonScaleName !== name) shownScale = modelData.scale !== undefined ? modelData.scale : 1.0
            function scaleText(s) { return s.toFixed(3).replace(/0+$/, '').replace(/\.$/, '.0') + "×"; }

            title: name + "  ·  " + modelData.dimensions + " • " + modelData.framerate + "Hz"; icon: "󰍹"; accent: page.accent
            BoardCell {
                kind: "toggle"; icon: "󰐥"; title: I18n.t("guide.display.enable.title", "Enable Monitor")
                hidden: logic.monitorsList.length <= 1
                value: mon.powered
                onPicked: (v) => { logic.updateMonitorSetting(mon.name, "powerEnabled", v); logic.applyMonitorPower(mon.name, v); }
            }
            BoardCell {
                kind: "toggle"; icon: "󰖔"; title: I18n.t("guide.display.bluelight.title")
                value: mon.filterOn
                onPicked: (v) => { BlueLight.setEnabled(mon.name, v); logic.refreshDisplaySettings(); }
            }
            BoardCell {
                kind: "toggle"; icon: "󰥔"; title: I18n.t("guide.display.schedule.title")
                hidden: !mon.filterOn
                value: mon.filterAuto
                onPicked: (v) => { BlueLight.setAuto(mon.name, v); logic.refreshDisplaySettings(); }
            }
            BoardCell {
                kind: "info"; icon: "󰖕"; title: I18n.t("guide.display.schedule.title")
                hidden: !mon.filterOn || !mon.filterAuto
                info: logic.scheduleDescription
            }
            BoardCell {
                kind: "slider"; icon: "󰔏"; title: I18n.t("guide.display.temperature.title")
                hidden: !mon.filterOn || mon.filterAuto
                from: 0; to: 100; step: 1
                value: isNaN(mon.dragTemp) ? (mon.ms.temperature !== undefined ? mon.ms.temperature : 50) : mon.dragTemp
                onMoving: (v) => { const r = Math.round(v); if (r !== mon.dragTemp) { mon.dragTemp = r; logic.updateMonitorSettingDebounced(mon.name, r); } }
                onReleased: { logic.flushMonitorSetting(mon.name); mon.dragTemp = NaN; }
            }
            BoardCell {
                kind: "slider"; icon: "󰍍"; title: I18n.t("guide.display.uiscale.title")
                from: 0; to: Math.max(0, mon.scales.length - 1); step: 1
                value: mon.scaleIndex
                valueText: (logic.scaleDebounceTimer.running && logic.pendingMonScaleName === mon.name ? "… " : "") + mon.scaleText(mon.shownScale)
                onMoving: (v) => {
                    const s = mon.scales[Math.round(v)] !== undefined ? mon.scales[Math.round(v)] : 1.0;
                    if (mon.shownScale !== s) { mon.shownScale = s; logic.scaleMoved(mon.name, s); }
                }
                onReleased: logic.scaleReleased()
            }
        }
    }

    // desktop widgets (guide/display/DisplayWidgetsTab.qml through WidgetsLogic): the redactor, each screen's
    // presets (the real preview cards) and its widgets
    BoardCard {
        title: I18n.t("guide.tabs.display_widgets", "Widgets"); icon: "󰋩"; accent: page.accent
        BoardCell {
            kind: "toggle"; icon: "󰘓"; title: I18n.t("guide.display.widgets.hide_bar.title", "Hide Bar in Redactor")
            value: wlogic.currentHideBarInRedactor
            onPicked: (v) => wlogic.updateWidgetsSetting("hideBarInRedactor", v)
        }
    }
    Repeater {
        model: wlogic.monitorsList
        BoardCard {
            id: wcard
            required property var modelData
            readonly property string monName: modelData.name
            readonly property var widgets: wlogic.monitorWidgetsMap && wlogic.monitorWidgetsMap[monName] ? wlogic.monitorWidgetsMap[monName] : []
            property bool showPresets: false
            title: monName + "  ·  " + widgets.length + " " + (widgets.length === 1 ? I18n.t("widgets.redactor.widget_singular", "widget") : I18n.t("widgets.redactor.widgets_plural", "widgets"))
            icon: "󰍹"; accent: page.accent
            BoardCell { kind: "action"; icon: "󰕰"; title: I18n.t("guide.display.widgets.open", "Open Redactor"); actionText: "Open"
                        onActivated: wlogic.openRedactor(wcard.monName) }
            BoardCell { kind: "action"; icon: "󰐕"; title: "Save as preset"; actionText: "Save"
                        onActivated: savePopup.openForMonitor(wcard.monName, wcard.widgets) }
            BoardCell { kind: "action"; icon: "󰄛"; title: I18n.t("guide.display.widgets.choose_preset", "Choose a preset")
                        actionText: wcard.showPresets ? I18n.t("guide.display.widgets.hide_presets", "Hide Presets") : "Show"
                        onActivated: wcard.showPresets = !wcard.showPresets }
            Item {
                property bool hidden: !presetLoader.active          // left out of the card's layout while closed
                visible: presetLoader.active
                implicitHeight: presetLoader.item ? presetLoader.item.implicitHeight : 0
                Loader {
                    id: presetLoader
                    width: parent.width
                    active: wcard.showPresets && page.visible
                    sourceComponent: WidgetPresetGrid { logic: wlogic; monName: wcard.monName; rootObj: page.rootObj }
                }
            }
            Repeater {
                model: wcard.widgets
                BoardCell {
                    id: wcell
                    required property var modelData
                    readonly property string wType: modelData.wType || modelData.type || "time"
                    readonly property var info: typeof WidgetRegistry !== "undefined" && WidgetRegistry.types && WidgetRegistry.types[wType] ? WidgetRegistry.types[wType] : null
                    kind: "custom"; wide: true; customHeight: 30
                    icon: info && info.icon ? info.icon : "󰕰"
                    title: info && info.name ? info.name : wType
                    Row {
                        width: parent.width; spacing: 8
                        Text { width: parent.width - del.width - 8; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                               text: (wcell.modelData.wVariant || "default") + " • " + Math.round(wcell.modelData.wWidth || 0) + "x" + Math.round(wcell.modelData.wHeight || 0)
                                     + " @ (" + Math.round(wcell.modelData.wX || 0) + ", " + Math.round(wcell.modelData.wY || 0) + ")"
                               font.family: ThemeBackend.fontFamily; font.pixelSize: 11; color: ThemeBackend.subtext0 }
                        Rectangle {
                            id: del
                            width: 30; height: 30; radius: 15
                            color: dMa.pressed ? Qt.darker(ThemeBackend.red, 1.2) : (dMa.containsMouse ? Qt.alpha(ThemeBackend.red, 0.3) : Qt.alpha(ThemeBackend.red, 0.14))
                            Behavior on color { ColorAnimation { duration: 140 } }
                            Text { anchors.centerIn: parent; text: "󰆴"; font.family: ThemeBackend.iconFont; font.pixelSize: 14; color: ThemeBackend.red }
                            MouseArea { id: dMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); wlogic.deleteWidget(wcard.monName, wcell.modelData.wId || wcell.modelData.id); } }
                        }
                    }
                }
            }
        }
    }
}
