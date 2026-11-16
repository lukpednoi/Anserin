import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Item {
    id: notificationsTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 0

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
    // the page's logic lives in NotificationsLogic.qml (shared with the Control Center's board); the names
    // below keep the page reading it as before
    NotificationsLogic {
        id: logic
        selector: positionPicker.selector
        onCustomPosition: posDropdown.currentIndex = -1
        onSoundInstalled: soundPickerPopup.close()
    }
    readonly property alias presetTopV: logic.presetTopV
    readonly property alias presetRightH: logic.presetRightH
    property alias defaultNotificationSettings: logic.defaultNotificationSettings
    property alias notifSettings: logic.notifSettings
    property alias dnd: logic.dnd
    property alias position: logic.position
    property alias horizontalPosition: logic.horizontalPosition
    property alias verticalPosition: logic.verticalPosition
    property alias soundEnabled: logic.soundEnabled
    property alias selectedSound: logic.selectedSound
    property alias showEmptyGraphic: logic.showEmptyGraphic
    readonly property alias isCustomPos: logic.isCustomPos
    property alias soundList: logic.soundList
    property alias availableSounds: logic.availableSounds
    function getPresetIndex(h, v) { return logic.getPresetIndex(h, v); }
    function getPosStringFromIndex(index) { return logic.getPosStringFromIndex(index); }
    function applyPosition(h, v, posStr) { return logic.applyPosition(h, v, posStr); }
    function setPosFromIndex(index) { return logic.setPosFromIndex(index); }
    function updateNotifSetting(key, val) { return logic.updateNotifSetting(key, val); }
    function syncSettings() { return logic.syncSettings(); }
    function installSound(filePath, fileName) { return logic.installSound(filePath, fileName); }



















    SoundPicker {
        id: soundPickerPopup
        rootObj: notificationsTabRoot.rootObj
        onSoundSelected: function(filePath, fileName) {
            if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") {
                notificationsTabRoot.installSound(filePath, fileName);
            }
        }
    }


    Component.onCompleted: {
        syncSettings();
        if (visible) {
            logic.reloadSoundsDebounceTimer.restart();
        }
    }

    onVisibleChanged: {
        if (visible) {
            syncSettings();
            logic.reloadSoundsDebounceTimer.restart();
        } else {
            logic.reloadSoundsDebounceTimer.stop();
            selectorOpen = false;
            soundPickerPopup.close();
            if (posDropdown.isOpen) posDropdown.closePopup();
            if (soundDropdown.isOpen) soundDropdown.closePopup();
        }
    }


    Flickable {
        interactive: !notificationsTabRoot.sectionMode
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            SettingsRow {
                id: posSettingsRow
                rootObj: notificationsTabRoot.rootObj
                icon: "󰍹"
                iconOffsetX: -2
                title: I18n.t("guide.notifications.position.title", "Screen position")
                titleBold: true
                description: I18n.t("guide.notifications.position.desc", "Select a preset position or drag on screen")
                innerSpacing: (notificationsTabRoot.selectorOpen || selectorWrapper.implicitHeight > 0) ? rootObj.s(12) : 0
                bottomSpacing: 0

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    horizontalPadding: rootObj.s(12)
                    buttonText: notificationsTabRoot.selectorOpen ? I18n.t("guide.notifications.position.close_selector", "Close the selector") : I18n.t("guide.notifications.position.select_on_screen", "Select on screen...")
                    buttonIcon: notificationsTabRoot.selectorOpen ? "󰅖" : "󰍹"
                    iconFontSize: rootObj.s(13)
                    textFontSize: rootObj.s(11)
                    accentColor: notificationsTabRoot.selectorOpen ? ThemeBackend.mauve : ThemeBackend.surface0
                    textColor: notificationsTabRoot.selectorOpen ? ThemeBackend.crust : ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    onClicked: {
                        notificationsTabRoot.selectorOpen = !notificationsTabRoot.selectorOpen;
                    }
                }

                Rectangle {
                    id: notifCustomPosBox
                    Layout.alignment: Qt.AlignVCenter
                    implicitHeight: rootObj.s(32)
                    implicitWidth: notificationsTabRoot.isCustomPos ? (notifCustomPosText.implicitWidth + rootObj.s(20)) : 0
                    radius: ThemeBackend.borderRadius
                    color: ThemeBackend.surface0
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                    clip: true
                    opacity: notificationsTabRoot.isCustomPos ? 1.0 : 0.0
                    visible: opacity > 0.001

                    Behavior on implicitWidth { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                    Text {
                        id: notifCustomPosText
                        anchors.centerIn: parent
                        text: I18n.t("guide.position.custom", "Custom") + " (" + notificationsTabRoot.horizontalPosition + "%, " + notificationsTabRoot.verticalPosition + "%)"
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
                        I18n.t("guide.notifications.position.top_right", "Top Right"),
                        I18n.t("guide.notifications.position.top_center", "Top Center"),
                        I18n.t("guide.notifications.position.top_left", "Top Left"),
                        I18n.t("guide.notifications.position.bottom_right", "Bottom Right"),
                        I18n.t("guide.notifications.position.bottom_center", "Bottom Center"),
                        I18n.t("guide.notifications.position.bottom_left", "Bottom Left")
                    ]
                    currentIndex: {
                        if (notificationsTabRoot.isCustomPos) return -1;
                        if (notificationsTabRoot.position === "top right") return 0;
                        if (notificationsTabRoot.position === "top center") return 1;
                        if (notificationsTabRoot.position === "top left") return 2;
                        if (notificationsTabRoot.position === "bottom right") return 3;
                        if (notificationsTabRoot.position === "bottom center") return 4;
                        if (notificationsTabRoot.position === "bottom left") return 5;
                        return notificationsTabRoot.getPresetIndex(notificationsTabRoot.horizontalPosition, notificationsTabRoot.verticalPosition);
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
                        notificationsTabRoot.setPosFromIndex(index);
                    }
                    onSelected: function(index, value) {
                        notificationsTabRoot.setPosFromIndex(index);
                    }
                }

                Binding {
                    target: posDropdown
                    property: "currentIndex"
                    value: {
                        if (notificationsTabRoot.isCustomPos) return -1;
                        if (notificationsTabRoot.position === "top right") return 0;
                        if (notificationsTabRoot.position === "top center") return 1;
                        if (notificationsTabRoot.position === "top left") return 2;
                        if (notificationsTabRoot.position === "bottom right") return 3;
                        if (notificationsTabRoot.position === "bottom center") return 4;
                        if (notificationsTabRoot.position === "bottom left") return 5;
                        return notificationsTabRoot.getPresetIndex(notificationsTabRoot.horizontalPosition, notificationsTabRoot.verticalPosition);
                    }
                }

                bottomContent: [
                    Item {
                        id: selectorWrapper
                        Layout.fillWidth: true
                        property bool isOpen: notificationsTabRoot.selectorOpen
                        clip: true
                        visible: implicitHeight > 0
                        opacity: isOpen ? 1.0 : 0.0
                        implicitHeight: isOpen ? positionPicker.implicitHeight : 0

                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                        NotificationPositionPicker {
                            id: positionPicker
                            logic: notificationsTabRoot.logicObject
                            rootObj: notificationsTabRoot.rootObj
                            onPresetCleared: posDropdown.currentIndex = -1
                        }
                    }
                ]
            }

            SettingsRow {
                rootObj: notificationsTabRoot.rootObj
                icon: "󰂛"
                title: I18n.t("guide.notifications.dnd.title")
                description: I18n.t("guide.notifications.dnd.desc")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: notificationsTabRoot.dnd
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        notificationsTabRoot.dnd = c;
                        notificationsTabRoot.updateNotifSetting("dnd", c);
                    }
                }
            }

            SettingsRow {
                rootObj: notificationsTabRoot.rootObj
                icon: "󰋑"
                title: I18n.t("guide.notifications.empty_graphic.title")
                description: I18n.t("guide.notifications.empty_graphic.desc")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: notificationsTabRoot.showEmptyGraphic
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        notificationsTabRoot.showEmptyGraphic = c;
                        notificationsTabRoot.updateNotifSetting("showEmptyGraphic", c);
                    }
                }
            }

            SettingsRow {
                rootObj: notificationsTabRoot.rootObj
                icon: "󰂚"
                title: I18n.t("guide.notifications.sound.title")
                description: I18n.t("guide.notifications.sound.desc")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: notificationsTabRoot.soundEnabled
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        notificationsTabRoot.soundEnabled = c;
                        notificationsTabRoot.updateNotifSetting("sound", c);
                    }
                }
            }

            SettingsRow {
                rootObj: notificationsTabRoot.rootObj
                visible: notificationsTabRoot.soundEnabled
                icon: "󰎆"
                title: I18n.t("guide.notifications.sound_file.title")
                description: I18n.t("guide.notifications.sound_file.desc")

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: rootObj.s(6)
                    buttonIcon: "󰉋"
                    iconOffsetX: -2
                    iconFontSize: rootObj.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    onClicked: {
                        let userSoundsPath = Caching.stateDir ? (Caching.stateDir + "/sounds/notifications") : (Caching.home + "/.local/state/anserin/sounds/notifications");
                        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                        FileManager.openFolder(userSoundsPath, true);
                    }
                }

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: rootObj.s(6)
                    buttonIcon: "󰐕"
                    iconFontSize: rootObj.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    onClicked: soundPickerPopup.openPicker()
                }

                Dropdown {
                    id: soundDropdown
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: rootObj.s(180)
                    Layout.preferredHeight: rootObj.s(32)
                    options: notificationsTabRoot.availableSounds
                    currentIndex: {
                        for (let i = 0; i < notificationsTabRoot.soundList.length; i++) {
                            if (notificationsTabRoot.soundList[i].path === notificationsTabRoot.selectedSound) {
                                return i;
                            }
                        }
                        return 0;
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
                    onSelected: function(index, value) {
                        if (index >= 0 && index < notificationsTabRoot.soundList.length) {
                            let targetPath = notificationsTabRoot.soundList[index].path;
                            notificationsTabRoot.selectedSound = targetPath;
                            notificationsTabRoot.updateNotifSetting("soundFile", targetPath);
                            if (typeof Sounds !== "undefined" && typeof Sounds.play === "function") {
                                Sounds.play(targetPath);
                            }
                        }
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
                    buttonText: I18n.t("guide.notifications.test", "Test notification")
                    buttonIcon: "󰂚"
                    iconFontSize: rootObj.s(16)
                    textFontSize: rootObj.s(12)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    onClicked: {
                        Quickshell.execDetached([
                            "notify-send",
                            "-u",
                            "critical",
                            I18n.t("guide.notifications.test", "Test notification"),
                            I18n.t("guide.notifications.test_desc", "This is a test notification")
                        ]);
                    }
                }
            }
        }
    }
}
