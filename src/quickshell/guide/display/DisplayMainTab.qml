import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"
import "../../reusables/guide"

Item {
    id: displayTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 0

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    // the page's logic lives in DisplayLogic.qml (shared with the Control Center's board); the names below keep
    // the page reading it as before
    DisplayLogic {
        id: logic
        rootObj: displayTabRoot.rootObj
        tabIndex: displayTabRoot.tabIndex
        shown: displayTabRoot.visible
    }
    property alias displaySettings: logic.displaySettings
    property alias monitorsList: logic.monitorsList
    property alias pendingMonName: logic.pendingMonName
    property alias pendingMonScaleName: logic.pendingMonScaleName
    property alias pendingMonScaleVal: logic.pendingMonScaleVal
    readonly property alias scheduleDescription: logic.scheduleDescription
    function refreshDisplaySettings() { logic.refreshDisplaySettings(); }
    function validScalesForResolution(w, h) { return logic.validScalesForResolution(w, h); }
    function nearestValidScaleFromList(list, target) { return logic.nearestValidScaleFromList(list, target); }
    function updateMonitorSetting(monName, key, value) { logic.updateMonitorSetting(monName, key, value); }
    function applyMonitorPower(monName, enabled) { logic.applyMonitorPower(monName, enabled); }
    function applyMonitorScale(monName, scaleVal) { logic.applyMonitorScale(monName, scaleVal); }
    function updateMonitorSettingDebounced(monName, tempVal) { logic.updateMonitorSettingDebounced(monName, tempVal); }
    function flushMonitorSetting(monName) { logic.flushMonitorSetting(monName); }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: settingsCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: settingsCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(12)

            Repeater {
                model: displayTabRoot.monitorsList
                delegate: Rectangle {
                    id: monDelegate
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    clip: true
                    radius: ThemeBackend.borderRadius

                    property string monName: modelData.name
                    property var monSettings: (displayTabRoot.displaySettings && displayTabRoot.displaySettings.monitors && displayTabRoot.displaySettings.monitors[monName]) ? displayTabRoot.displaySettings.monitors[monName] : ({})

                    property bool monitorPowered: monSettings.powerEnabled !== undefined ? monSettings.powerEnabled : (modelData.active !== undefined ? modelData.active : true)
                    property bool filterEnabled: monSettings.enabled !== undefined ? monSettings.enabled : false
                    property bool filterAuto: monSettings.auto !== undefined ? monSettings.auto : false
                    property real currentTemp: monSettings.temperature !== undefined ? monSettings.temperature : 50
                    property real currentScale: modelData.scale !== undefined ? modelData.scale : 1.0

                    color: monitorPowered ? Qt.alpha(ThemeBackend.surface0, 0.4) : Qt.darker(Qt.alpha(ThemeBackend.surface0, 0.4), 1.1)
                    border.color: monitorPowered ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.darker(Qt.alpha(ThemeBackend.surface1, 0.4), 1.1)
                    border.width: 1

                    property real targetHeight: boxLayout.implicitHeight + rootObj.s(24)
                    property bool appeared: false

                    implicitHeight: appeared ? targetHeight : 0
                    opacity: appeared ? 1.0 : 0.0

                    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on border.color { ColorAnimation { duration: 250 } }

                    Component.onCompleted: {
                        appeared = true;
                    }

                    property var resDims: modelData.dimensions ? modelData.dimensions.split("x") : ["1920", "1080"]
                    property int monWidth: parseInt(resDims[0]) || 1920
                    property int monHeight: parseInt(resDims[1]) || 1080
                    property var validScales: displayTabRoot.validScalesForResolution(monWidth, monHeight)
                    readonly property int currentScaleIndex: {
                        let i = validScales.indexOf(currentScale);
                        if (i >= 0) return i;
                        let nearest = displayTabRoot.nearestValidScaleFromList(validScales, currentScale);
                        let ni = validScales.indexOf(nearest);
                        return ni >= 0 ? ni : 0;
                    }

                    onMonSettingsChanged: {
                        if (monSettings.powerEnabled !== undefined) {
                            monitorPowered = monSettings.powerEnabled;
                        }
                        filterEnabled = monSettings.enabled !== undefined ? monSettings.enabled : false;
                        filterAuto = monSettings.auto !== undefined ? monSettings.auto : false;
                        if (displayTabRoot.pendingMonName !== monName && !temperatureSlider.pressed) {
                            currentTemp = monSettings.temperature !== undefined ? monSettings.temperature : 50;
                        }
                    }

                    onModelDataChanged: {
                        if (monSettings.powerEnabled === undefined && modelData.active !== undefined) {
                            monitorPowered = modelData.active;
                        }
                        if (displayTabRoot.pendingMonScaleName !== monName) {
                            currentScale = modelData.scale !== undefined ? modelData.scale : 1.0;
                        }
                    }

                    ColumnLayout {
                        id: boxLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: rootObj.s(12)
                        spacing: rootObj.s(6)

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.bottomMargin: rootObj.s(6)
                            Layout.leftMargin: rootObj.s(4)
                            Layout.rightMargin: rootObj.s(4)
                            spacing: rootObj.s(8)

                            Text {
                                text: modelData.name
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(16)
                                font.bold: true
                                color: ThemeBackend.text
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: modelData.dimensions + " • " + modelData.framerate + "Hz"
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(12)
                                color: ThemeBackend.subtext0
                            }
                        }

                        SettingsRow {
                            visible: displayTabRoot.monitorsList.length > 1
                            rootObj: displayTabRoot.rootObj
                            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                            icon: "󰐥"
                            title: I18n.t("guide.display.enable.title", "Enable Monitor")
                            description: I18n.t("guide.display.enable.desc", "Turn display output on or off")

                            Toggle {
                                id: powerToggle
                                checked: monDelegate.monitorPowered
                                accentColor: ThemeBackend.mauve
                                baseColor: ThemeBackend.surface1
                                handleColor: ThemeBackend.crust
                                handleOffColor: ThemeBackend.text
                                onToggled: function(c) {
                                    monDelegate.monitorPowered = c;
                                    displayTabRoot.updateMonitorSetting(monDelegate.monName, "powerEnabled", c);
                                    displayTabRoot.applyMonitorPower(monDelegate.monName, c);
                                }

                                Binding {
                                    target: powerToggle
                                    property: "checked"
                                    value: monDelegate.monitorPowered
                                }
                            }
                        }

                        SettingsGroup {
                            rootObj: displayTabRoot.rootObj
                            icon: "󰖔"
                            title: I18n.t("guide.display.bluelight.title")
                            description: I18n.t("guide.display.bluelight.desc")
                            expanded: monDelegate.filterEnabled

                            Toggle {
                                id: filterToggle
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                checked: monDelegate.filterEnabled
                                accentColor: ThemeBackend.mauve
                                baseColor: ThemeBackend.surface1
                                handleColor: ThemeBackend.crust
                                handleOffColor: ThemeBackend.text
                                onToggled: function(c) {
                                    monDelegate.filterEnabled = c;
                                    BlueLight.setEnabled(monDelegate.monName, c);
                                    displayTabRoot.refreshDisplaySettings();
                                }

                                Binding {
                                    target: filterToggle
                                    property: "checked"
                                    value: monDelegate.filterEnabled
                                }
                            }

                            subSettings: [
                                SettingsRow {
                                    rootObj: displayTabRoot.rootObj
                                    baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                                    icon: "󰥔"
                                    title: I18n.t("guide.display.schedule.title")
                                    description: I18n.t("guide.display.schedule.desc") + " " + displayTabRoot.scheduleDescription

                                    Toggle {
                                        id: autoToggle
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                        checked: monDelegate.filterAuto
                                        accentColor: ThemeBackend.mauve
                                        baseColor: ThemeBackend.surface1
                                        handleColor: ThemeBackend.crust
                                        handleOffColor: ThemeBackend.text
                                        onToggled: function(c) {
                                            monDelegate.filterAuto = c;
                                            BlueLight.setAuto(monDelegate.monName, c);
                                            displayTabRoot.refreshDisplaySettings();
                                        }

                                        Binding {
                                            target: autoToggle
                                            property: "checked"
                                            value: monDelegate.filterAuto
                                        }
                                    }
                                },

                                Item {
                                    id: tempSectionWrapper
                                    Layout.fillWidth: true
                                    property bool isOpen: !monDelegate.filterAuto
                                    clip: true
                                    visible: implicitHeight > 0
                                    opacity: isOpen ? 1.0 : 0.0
                                    implicitHeight: isOpen ? tempInnerBox.implicitHeight : 0

                                    Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                    Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                                    SettingsRow {
                                        id: tempInnerBox
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        rootObj: displayTabRoot.rootObj
                                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                                        icon: "󰔏"
                                        title: I18n.t("guide.display.temperature.title")
                                        description: I18n.t("guide.display.temperature.desc")

                                        Draggable {
                                            id: temperatureSlider
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                            Layout.rightMargin: rootObj.s(8)
                                            implicitWidth: rootObj.s(220)
                                            implicitHeight: rootObj.s(18)
                                            from: 0
                                            to: 100
                                            stepSize: 1
                                            defaultValue: 50
                                            showValueBubble: true
                                            valueFormatter: function(v) { return Math.round(v).toString() }
                                            value: monDelegate.currentTemp
                                            backgroundColor: ThemeBackend.surface0
                                            accentColor: ThemeBackend.mauve
                                            handleColor: ThemeBackend.text
                                            handleBorderColor: ThemeBackend.mantle
                                            onMoved: function(val) {
                                                let rounded = Math.round(val);
                                                if (monDelegate.currentTemp !== rounded) {
                                                    monDelegate.currentTemp = rounded;
                                                    displayTabRoot.updateMonitorSettingDebounced(monDelegate.monName, rounded);
                                                }
                                            }
                                            onDragFinished: {
                                                displayTabRoot.flushMonitorSetting(monDelegate.monName);
                                            }
                                        }
                                    }
                                }
                            ]
                        }

                        SettingsRow {
                            rootObj: displayTabRoot.rootObj
                            baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                            icon: "󰍍"
                            title: I18n.t("guide.display.uiscale.title")
                            description: I18n.t("guide.display.uiscale.desc")
                            controlSpacing: rootObj.s(4)

                            LoaderIcon {
                                id: scaleLoader
                                Layout.preferredWidth: rootObj.s(32)
                                Layout.preferredHeight: rootObj.s(32)
                                Layout.alignment: Qt.AlignVCenter
                                running: logic.scaleDebounceTimer.running && displayTabRoot.pendingMonScaleName === monDelegate.monName
                                accentColor: ThemeBackend.mauve
                            }

                            Draggable {
                                id: uiScaleSlider
                                implicitWidth: rootObj.s(220)
                                implicitHeight: rootObj.s(18)
                                from: 0
                                to: Math.max(0, monDelegate.validScales.length - 1)
                                stepSize: 1
                                defaultValue: monDelegate.validScales.indexOf(1.0) >= 0 ? monDelegate.validScales.indexOf(1.0) : 0
                                showValueBubble: true
                                showTooltip: true
                                alwaysShowHandle: false
                                valueFormatter: function(idx) {
                                    let i = Math.round(idx);
                                    let s = monDelegate.validScales[i] !== undefined ? monDelegate.validScales[i] : 1.0;
                                    return s.toFixed(3).replace(/0+$/,'').replace(/\.$/,'.0');
                                }
                                value: monDelegate.currentScaleIndex
                                backgroundColor: ThemeBackend.surface0
                                accentColor: ThemeBackend.mauve
                                handleColor: ThemeBackend.text
                                handleBorderColor: ThemeBackend.mantle
                                onMoved: function(idx) {
                                    let i = Math.round(idx);
                                    let s = monDelegate.validScales[i] !== undefined ? monDelegate.validScales[i] : 1.0;
                                    if (monDelegate.currentScale !== s) {
                                        monDelegate.currentScale = s;
                                        displayTabRoot.pendingMonScaleName = monDelegate.monName;
                                        displayTabRoot.pendingMonScaleVal = s;
                                        logic.scaleDebounceTimer.restart();
                                    }
                                }
                                onDragFinished: {
                                    logic.scaleDebounceTimer.stop();
                                    if (displayTabRoot.pendingMonScaleName !== "") {
                                        displayTabRoot.applyMonitorScale(displayTabRoot.pendingMonScaleName, displayTabRoot.pendingMonScaleVal);
                                        displayTabRoot.updateMonitorSetting(displayTabRoot.pendingMonScaleName, "scale", displayTabRoot.pendingMonScaleVal);
                                        displayTabRoot.pendingMonScaleName = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.leftMargin: rootObj.s(8)
                Layout.topMargin: rootObj.s(8)
                text: I18n.t("guide.tabs.display_widgets", "Widgets")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(16)
                font.bold: true
                color: ThemeBackend.text
            }
            DisplayWidgetsTab {
                rootObj: displayTabRoot.rootObj
                tabIndex: displayTabRoot.tabIndex
                subTabIndex: displayTabRoot.subTabIndex
                embedded: true
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
            }
        }
    }
}
