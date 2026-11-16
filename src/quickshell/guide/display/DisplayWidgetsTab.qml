import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"
import "../../reusables/guide"
import "../../widgets"

Item {
    id: displayWidgetsRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 1
    property bool embedded: false

    implicitHeight: widgetsCol.implicitHeight + rootObj.s(24)
    anchors.fill: embedded ? undefined : parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    // the page's logic lives in WidgetsLogic.qml (shared with the Control Center's board); the names below keep
    // the page reading it as before
    WidgetsLogic {
        id: logic
        rootObj: displayWidgetsRoot.rootObj
        shown: displayWidgetsRoot.visible
        onPageHidden: savePresetPopup.close()
    }
    property alias currentHideBarInRedactor: logic.currentHideBarInRedactor
    property alias monitorWidgetsMap: logic.monitorWidgetsMap
    property alias monitorsList: logic.monitorsList
    property alias systemPresets: logic.systemPresets
    property alias userPresets: logic.userPresets
    function applyWidgetPreset(monName, presetData) { return logic.applyWidgetPreset(monName, presetData); }
    function deleteCustomPreset(presetName) { return logic.deleteCustomPreset(presetName); }
    function deleteWidget(monName, widgetId) { return logic.deleteWidget(monName, widgetId); }
    function getFaceUrl(type, variant) { return logic.getFaceUrl(type, variant); }
    function getScreen(monName) { return logic.getScreen(monName); }
    function getScreenDimensions(monName) { return logic.getScreenDimensions(monName); }
    function getWallpaperSource(monName) { return logic.getWallpaperSource(monName); }
    function openRedactor(mon) { return logic.openRedactor(mon); }
    function resolveDimension(val, screenDim, defVal) { return logic.resolveDimension(val, screenDim, defVal); }
    function resolvePosition(cfg, sw, sh, w, h) { return logic.resolvePosition(cfg, sw, sh, w, h); }
    function saveCustomPreset(presetName, monName, widgetsList) { return logic.saveCustomPreset(presetName, monName, widgetsList); }
    function updateWidgetsSetting(key, value) { return logic.updateWidgetsSetting(key, value); }

    SavePresetPopup {
        id: savePresetPopup
        rootObj: displayWidgetsRoot.rootObj
        onSaveRequested: function(presetName, monName, widgetsList) {
            displayWidgetsRoot.saveCustomPreset(presetName, monName, widgetsList);
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: widgetsCol.implicitHeight + rootObj.s(16)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: !displayWidgetsRoot.embedded

        ScrollBar.vertical: ScrollBar {
            active: parent.moving || parent.movingVertically
            width: rootObj.s(4)
            policy: displayWidgetsRoot.embedded ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: rootObj.s(4)
                radius: rootObj.s(2)
                color: ThemeBackend.surface2
            }
        }

        ColumnLayout {
            id: widgetsCol
            width: parent.width - (parent.contentHeight > parent.height ? rootObj.s(6) : 0)
            spacing: rootObj.s(6)

            SettingsRow {
                rootObj: displayWidgetsRoot.rootObj
                settingId: "widgets_hide_bar"
                icon: "󰘓"
                title: I18n.t("guide.display.widgets.hide_bar.title", "Hide Bar in Redactor")
                description: I18n.t("guide.display.widgets.hide_bar.desc", "Automatically hide the bar when editing widgets in redactor mode")
                searchKeywords: "widgets redactor hide bar panel"

                Toggle {
                    id: hideBarToggle
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: displayWidgetsRoot.currentHideBarInRedactor
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(val) {
                        displayWidgetsRoot.currentHideBarInRedactor = val;
                        displayWidgetsRoot.updateWidgetsSetting("hideBarInRedactor", val);
                    }
                }
            }

            Repeater {
                model: displayWidgetsRoot.monitorsList
                delegate: Rectangle {
                    id: monWidgetCard
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    clip: true
                    radius: ThemeBackend.borderRadius
                    color: Qt.alpha(ThemeBackend.surface0, 0.4)
                    border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
                    border.width: 1

                    property string monName: modelData.name
                    property var widgetsList: (displayWidgetsRoot.monitorWidgetsMap && displayWidgetsRoot.monitorWidgetsMap[monName]) ? displayWidgetsRoot.monitorWidgetsMap[monName] : []
                    property bool showPresets: false

                    implicitHeight: cardLayout.implicitHeight + rootObj.s(12)
                    Behavior on implicitHeight { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }

                    ColumnLayout {
                        id: cardLayout
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0

                        SettingsRow {
                            id: monHeaderRow
                            rootObj: displayWidgetsRoot.rootObj
                            settingId: "widgets_screen_" + monWidgetCard.monName.toLowerCase().replace(/[^a-z0-9_]/g, "_")
                            icon: "󰍹"
                            title: monWidgetCard.monName
                            description: I18n.t("guide.display.widgets.screen_desc", "Configure and edit desktop widgets")
                            searchKeywords: "widgets redactor edit layout preset presets monitor screen " + monWidgetCard.monName.toLowerCase()
                            baseColor: "transparent"
                            hoverColor: "transparent"
                            borderWidth: 0
                            color: highlightFlash > 0.001 ? Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, highlightFlash * 0.18) : "transparent"

                            titleBadge: Component {
                                Text {
                                    text: "(" + monWidgetCard.widgetsList.length + " " + (monWidgetCard.widgetsList.length === 1 ? I18n.t("widgets.redactor.widget_singular", "widget") : I18n.t("widgets.redactor.widgets_plural", "widgets")) + ")"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(11)
                                    color: ThemeBackend.subtext0
                                }
                            }

                            IconButton {
                                size: rootObj.s(32)
                                Layout.preferredWidth: rootObj.s(32)
                                Layout.preferredHeight: rootObj.s(32)
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                cornerRadius: ThemeBackend.borderRadius
                                buttonIcon: "󰐕"
                                iconFontSize: rootObj.s(16)
                                accentColor: ThemeBackend.surface0
                                textColor: ThemeBackend.text
                                onClicked: {
                                    savePresetPopup.openForMonitor(monWidgetCard.monName, monWidgetCard.widgetsList);
                                }
                            }

                            ClickButton {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                maxWidth: rootObj.s(200)
                                implicitHeight: rootObj.s(32)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonText: monWidgetCard.showPresets ? I18n.t("guide.display.widgets.hide_presets", "Hide Presets") : I18n.t("guide.display.widgets.choose_preset", "Choose a preset")
                                buttonIcon: "󰄛"
                                iconFontSize: rootObj.s(14)
                                textFontSize: rootObj.s(12)
                                accentColor: monWidgetCard.showPresets ? ThemeBackend.surface2 : ThemeBackend.surface0
                                textColor: ThemeBackend.text
                                onClicked: {
                                    if (typeof Sounds !== "undefined") {
                                        Sounds.playSfx("reusables/clickbutton/click.wav");
                                    }
                                    monWidgetCard.showPresets = !monWidgetCard.showPresets;
                                }
                            }

                            ClickButton {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                maxWidth: rootObj.s(140)
                                implicitHeight: rootObj.s(32)
                                cornerRadius: ThemeBackend.borderRadius
                                buttonText: I18n.t("guide.display.widgets.open", "Open Redactor")
                                buttonIcon: "󰕰"
                                iconFontSize: rootObj.s(14)
                                textFontSize: rootObj.s(12)
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.crust
                                onClicked: {
                                    displayWidgetsRoot.openRedactor(monWidgetCard.monName);
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: Qt.alpha(ThemeBackend.surface1, 0.3)
                        }

                        Loader {
                            id: presetsSectionLoader
                            Layout.fillWidth: true
                            Layout.leftMargin: rootObj.s(12)
                            Layout.rightMargin: rootObj.s(12)
                            Layout.topMargin: rootObj.s(12)
                            active: monWidgetCard.showPresets && displayWidgetsRoot.visible
                            visible: active

                            sourceComponent: Component {
                                WidgetPresetGrid { logic: displayWidgetsRoot; monName: monWidgetCard.monName; rootObj: displayWidgetsRoot.rootObj }
                            }
                        }

                        Grid {
                            id: widgetsGrid
                            Layout.fillWidth: true
                            Layout.leftMargin: rootObj.s(12)
                            Layout.rightMargin: rootObj.s(12)
                            Layout.topMargin: rootObj.s(12)
                            Layout.bottomMargin: rootObj.s(12)
                            columns: 3
                            rowSpacing: rootObj.s(8)
                            columnSpacing: rootObj.s(8)
                            visible: monWidgetCard.widgetsList.length > 0

                            readonly property real colWidth: Math.max(0, ((cardLayout.width - rootObj.s(24)) - columnSpacing * 2) / 3)

                            Repeater {
                                model: monWidgetCard.widgetsList
                                delegate: Rectangle {
                                    id: widgetItemCard
                                    required property var modelData
                                    required property int index

                                    width: widgetsGrid.colWidth
                                    height: rootObj.s(48)
                                    radius: ThemeBackend.borderRadius
                                    color: Qt.alpha(ThemeBackend.surface1, 0.3)
                                    border.color: Qt.alpha(ThemeBackend.surface2, 0.35)
                                    border.width: 1

                                    property string wType: modelData.wType || modelData.type || "time"
                                    property var typeInfo: (typeof WidgetRegistry !== "undefined" && WidgetRegistry.types && WidgetRegistry.types[wType]) ? WidgetRegistry.types[wType] : null

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: rootObj.s(8)
                                        anchors.rightMargin: rootObj.s(8)
                                        spacing: rootObj.s(8)

                                        IconButton {
                                            size: rootObj.s(32)
                                            iconOffsetX: (widgetItemCard.typeInfo && widgetItemCard.typeInfo.iconOffsetX !== undefined) ? rootObj.s(widgetItemCard.typeInfo.iconOffsetX) : 0
                                            cornerRadius: ThemeBackend.borderRadius
                                            buttonIcon: (widgetItemCard.typeInfo && widgetItemCard.typeInfo.icon) ? widgetItemCard.typeInfo.icon : "󰕰"
                                            iconFontSize: rootObj.s(16)
                                            accentColor: ThemeBackend.surface1
                                            textColor: ThemeBackend.mauve
                                            Layout.alignment: Qt.AlignVCenter
                                            enabled: false
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: rootObj.s(1)

                                            Text {
                                                text: widgetItemCard.typeInfo && widgetItemCard.typeInfo.name ? widgetItemCard.typeInfo.name : widgetItemCard.wType
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: rootObj.s(12)
                                                font.bold: true
                                                color: ThemeBackend.text
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: (widgetItemCard.modelData.wVariant || "default") + " • " + Math.round(widgetItemCard.modelData.wWidth || 0) + "x" + Math.round(widgetItemCard.modelData.wHeight || 0) + " @ (" + Math.round(widgetItemCard.modelData.wX || 0) + ", " + Math.round(widgetItemCard.modelData.wY || 0) + ")"
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: rootObj.s(10)
                                                color: ThemeBackend.subtext0
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        DeleteButton {
                                            size: rootObj.s(28)
                                            cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(8))
                                            iconFontSize: rootObj.s(14)
                                            Layout.alignment: Qt.AlignVCenter
                                            onClicked: {
                                                let wId = widgetItemCard.modelData.wId || widgetItemCard.modelData.id;
                                                displayWidgetsRoot.deleteWidget(monWidgetCard.monName, wId);
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: rootObj.s(40)
                            Layout.leftMargin: rootObj.s(12)
                            Layout.rightMargin: rootObj.s(12)
                            Layout.topMargin: rootObj.s(12)
                            Layout.bottomMargin: rootObj.s(12)
                            visible: !monWidgetCard.showPresets && monWidgetCard.widgetsList.length === 0

                            Text {
                                anchors.centerIn: parent
                                text: I18n.t("widgets.redactor.no_widgets_active", "No widgets configured for this screen")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(12)
                                color: ThemeBackend.subtext0
                            }
                        }
                    }
                }
            }
        }
    }
}
