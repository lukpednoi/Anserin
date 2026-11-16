import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import "../"
import "../reusables"
import "../controlcenter/settings"
import "./shared"

Item {
    id: osdTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 1

    // sectionMode: shown as one section of a combined page (no own scrolling, height follows the content)
    property bool sectionMode: false
    anchors.fill: sectionMode ? undefined : parent
    implicitHeight: settingsCol.implicitHeight + rootObj.s(16)
    visible: sectionMode || (rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex)
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property bool selectorOpen: false

    readonly property var logicObject: logic
    // the page's logic lives in OsdLogic.qml (shared with the Control Center's board); the names below keep
    // the page reading it as before
    OsdLogic {
        id: logic
        selector: positionPicker.selector
        onCustomPosition: posDropdown.currentIndex = -1
    }
    property alias defaultOsdSettings: logic.defaultOsdSettings
    property alias osdSettings: logic.osdSettings
    property alias horizontalPosition: logic.horizontalPosition
    property alias verticalPosition: logic.verticalPosition
    property alias orientation: logic.orientation
    readonly property alias isVertical: logic.isVertical
    property alias showCapsLock: logic.showCapsLock
    property alias showNumLock: logic.showNumLock
    property alias showAirplane: logic.showAirplane
    property alias attachToBar: logic.attachToBar
    readonly property alias isCustomPos: logic.isCustomPos
    function applyPosition(h, v) { return logic.applyPosition(h, v); }
    function setPosFromIndex(index) { return logic.setPosFromIndex(index); }
    function syncSettings() { return logic.syncSettings(); }
    function updateOsdSetting(key, value) { return logic.updateOsdSetting(key, value); }










    onVisibleChanged: {
        if (visible) {
            syncSettings();
        } else {
            selectorOpen = false;
            if (posDropdown.isOpen) posDropdown.closePopup();
        }
    }

    Component.onCompleted: {
        syncSettings();
    }


    Flickable {
        interactive: !osdTabRoot.sectionMode
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            SettingsRow {
                id: posSettingsRow
                rootObj: osdTabRoot.rootObj
                icon: "󰍹"
                iconOffsetX: -2
                title: I18n.t("guide.osd.position.title", "Screen position")
                titleBold: true
                wrapText: true
                description: I18n.t("guide.osd.position.desc", "Select a preset position or drag on screen")
                innerSpacing: (osdTabRoot.selectorOpen || selectorWrapper.implicitHeight > 0) ? rootObj.s(12) : 0
                bottomSpacing: 0

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    horizontalPadding: rootObj.s(12)
                    buttonText: osdTabRoot.selectorOpen ? I18n.t("guide.osd.position.close_selector", "Close the selector") : I18n.t("guide.osd.position.select_on_screen", "Select on screen...")
                    buttonIcon: osdTabRoot.selectorOpen ? "󰅖" : "󰍹"
                    iconFontSize: rootObj.s(13)
                    textFontSize: rootObj.s(11)
                    accentColor: osdTabRoot.selectorOpen ? ThemeBackend.mauve : ThemeBackend.surface0
                    textColor: osdTabRoot.selectorOpen ? ThemeBackend.crust : ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    onClicked: {
                        osdTabRoot.selectorOpen = !osdTabRoot.selectorOpen;
                    }
                }

                Rectangle {
                    id: osdCustomBadge
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: rootObj.s(32)
                    implicitWidth: osdTabRoot.isCustomPos ? (customPosText.implicitWidth + rootObj.s(20)) : 0
                    radius: ThemeBackend.borderRadius
                    color: ThemeBackend.surface0
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                    clip: true
                    opacity: osdTabRoot.isCustomPos ? 1.0 : 0.0
                    visible: opacity > 0.001

                    Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    Text {
                        id: customPosText
                        anchors.centerIn: parent
                        text: I18n.t("guide.position.custom", "Custom") + " (" + osdTabRoot.horizontalPosition + "%, " + osdTabRoot.verticalPosition + "%)"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                        font.bold: true
                        color: "#ffffff"
                    }
                }

                Dropdown {
                    id: posDropdown
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: rootObj.s(180)
                    Layout.preferredHeight: rootObj.s(32)
                    options: [
                        I18n.t("guide.osd.position.bottom_center", "Bottom Center"),
                        I18n.t("guide.osd.position.bottom_left", "Bottom Left"),
                        I18n.t("guide.osd.position.bottom_right", "Bottom Right"),
                        I18n.t("guide.osd.position.top_center", "Top Center"),
                        I18n.t("guide.osd.position.top_left", "Top Left"),
                        I18n.t("guide.osd.position.top_right", "Top Right")
                    ]
                    currentIndex: {
                        if (osdTabRoot.isCustomPos) return -1;
                        let v = osdTabRoot.verticalPosition;
                        let h = osdTabRoot.horizontalPosition;
                        if (v === 90 && h === 50) return 0;
                        if (v === 90 && h === 10) return 1;
                        if (v === 90 && h === 90) return 2;
                        if (v === 10 && h === 50) return 3;
                        if (v === 10 && h === 10) return 4;
                        if (v === 10 && h === 90) return 5;
                        return -1;
                    }
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        osdTabRoot.setPosFromIndex(index);
                    }
                    onSelected: function(index, value) {
                        osdTabRoot.setPosFromIndex(index);
                    }
                }

                Binding {
                    target: posDropdown
                    property: "currentIndex"
                    value: {
                        if (osdTabRoot.isCustomPos) return -1;
                        let v = osdTabRoot.verticalPosition;
                        let h = osdTabRoot.horizontalPosition;
                        if (v === 90 && h === 50) return 0;
                        if (v === 90 && h === 10) return 1;
                        if (v === 90 && h === 90) return 2;
                        if (v === 10 && h === 50) return 3;
                        if (v === 10 && h === 10) return 4;
                        if (v === 10 && h === 90) return 5;
                        return -1;
                    }
                }

                bottomContent: [
                    Item {
                        id: selectorWrapper
                        Layout.fillWidth: true
                        property bool isOpen: osdTabRoot.selectorOpen
                        clip: true
                        visible: implicitHeight > 0
                        opacity: isOpen ? 1.0 : 0.0
                        implicitHeight: isOpen ? positionPicker.implicitHeight : 0

                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        OsdPositionPicker {
                            id: positionPicker
                            logic: osdTabRoot.logicObject
                            rootObj: osdTabRoot.rootObj
                            onPresetCleared: posDropdown.currentIndex = -1
                        }
                    }
                ]
            }

            // Anserin interface: the three "show on ..." options are press-to-toggle tiles, like the Overview buttons
            RowLayout {
                Layout.fillWidth: true
                visible: rootObj.anserinInterface === true
                spacing: rootObj.s(10)
                Repeater {
                    model: [
                        { icon: "󰘲", title: "Caps Lock", key: "showCapsLock" },
                        { icon: "󰎤", title: "Num Lock", key: "showNumLock" },
                        { icon: "󰀝", title: "Airplane Mode", key: "showAirplane" }
                    ]
                    CtlTile {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        unit: rootObj.s(1)
                        icon: modelData.icon
                        title: modelData.title
                        enabled: !osdTabRoot.isVertical
                        checked: modelData.key === "showCapsLock" ? osdTabRoot.showCapsLock : (modelData.key === "showNumLock" ? osdTabRoot.showNumLock : osdTabRoot.showAirplane)
                        onToggled: function(c) {
                            if (modelData.key === "showCapsLock") osdTabRoot.showCapsLock = c;
                            else if (modelData.key === "showNumLock") osdTabRoot.showNumLock = c;
                            else osdTabRoot.showAirplane = c;
                            osdTabRoot.updateOsdSetting(modelData.key, c);
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: rootObj.anserinInterface !== true
                spacing: rootObj.s(10)

                SettingsRow {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    rootObj: osdTabRoot.rootObj
                    icon: "󰘲"
                    title: I18n.t("guide.osd.capslock.title", "Show on Caps Lock")
                    titlePixelSize: 12
                    wrapText: true
                    baseColor: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)
                    titleColor: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                    opacity: osdTabRoot.isVertical ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    spacing: rootObj.s(10)

                    Text {
                        visible: osdTabRoot.isVertical
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        text: I18n.t("guide.common.unavailable", "Unavailable")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                        font.bold: true
                        color: ThemeBackend.subtext0
                    }

                    Toggle {
                        visible: !osdTabRoot.isVertical
                        enabled: !osdTabRoot.isVertical
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: osdTabRoot.showCapsLock
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            osdTabRoot.showCapsLock = c;
                            osdTabRoot.updateOsdSetting("showCapsLock", c);
                        }
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    rootObj: osdTabRoot.rootObj
                    icon: "󰎤"
                    title: I18n.t("guide.osd.numlock.title", "Show on Num Lock")
                    titlePixelSize: 12
                    wrapText: true
                    baseColor: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)
                    titleColor: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                    opacity: osdTabRoot.isVertical ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    spacing: rootObj.s(10)

                    Text {
                        visible: osdTabRoot.isVertical
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        text: I18n.t("guide.common.unavailable", "Unavailable")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                        font.bold: true
                        color: ThemeBackend.subtext0
                    }

                    Toggle {
                        visible: !osdTabRoot.isVertical
                        enabled: !osdTabRoot.isVertical
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: osdTabRoot.showNumLock
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            osdTabRoot.showNumLock = c;
                            osdTabRoot.updateOsdSetting("showNumLock", c);
                        }
                    }
                }

                SettingsRow {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    rootObj: osdTabRoot.rootObj
                    icon: "󰀝"
                    title: I18n.t("guide.osd.airplane.title", "Show on Airplane Mode")
                    titlePixelSize: 12
                    wrapText: true
                    baseColor: osdTabRoot.isVertical ? Qt.alpha(ThemeBackend.surface0, 0.18) : Qt.alpha(ThemeBackend.surface0, 0.4)
                    titleColor: osdTabRoot.isVertical ? ThemeBackend.subtext0 : ThemeBackend.text
                    opacity: osdTabRoot.isVertical ? 0.6 : 1.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }
                    spacing: rootObj.s(10)

                    Text {
                        visible: osdTabRoot.isVertical
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        text: I18n.t("guide.common.unavailable", "Unavailable")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(11)
                        font.bold: true
                        color: ThemeBackend.subtext0
                    }

                    Toggle {
                        visible: !osdTabRoot.isVertical
                        enabled: !osdTabRoot.isVertical
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        checked: osdTabRoot.showAirplane
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) {
                            osdTabRoot.showAirplane = c;
                            osdTabRoot.updateOsdSetting("showAirplane", c);
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: osdTabRoot.rootObj
                icon: "󱂬"
                title: I18n.t("guide.osd.attach_bar.title", "Attach to the bar in solid/fill style")
                description: I18n.t("guide.osd.attach_bar.desc", "Snap OSD popups to the status bar in solid or fill mode. When disabled, the OSD always stays in the configured position.")
                wrapText: true

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: osdTabRoot.attachToBar
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        osdTabRoot.attachToBar = c;
                        osdTabRoot.updateOsdSetting("attachToBar", c);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: rootObj.s(4)
                Layout.leftMargin: rootObj.s(4)
                Layout.rightMargin: rootObj.s(4)
                spacing: rootObj.s(12)

                Item { Layout.fillWidth: true }

                ClickButton {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitHeight: rootObj.s(36)
                    horizontalPadding: rootObj.s(16)
                    buttonText: I18n.t("guide.osd.test", "Test OSD")
                    buttonIcon: "󰕾"
                    iconFontSize: rootObj.s(16)
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    onClicked: {
                        if (typeof OsdController !== "undefined") {
                            OsdController.show("volume");
                        }
                    }
                }
            }
        }
    }
}
