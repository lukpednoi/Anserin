import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

// The position picker of the Notifications page: a small screen to drag the popup on (with grid, reset and the bar
// shown) and its coordinates. Shared by the Settings page and the Control Center's board. `logic` is a
// NotificationsLogic; `selector` is the ScreenPositionSelector inside (the logic reads the screen's safe area from it).
Rectangle {
    id: picker
    required property var logic
    required property var rootObj
    property bool gridEnabled: false
    property bool showBarBox: true
    readonly property alias selector: screenSelector
    signal presetCleared()
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: implicitHeight
    implicitHeight: selectorInnerCol.implicitHeight + picker.rootObj.s(24)
    radius: ThemeBackend.borderRadius
    color: Qt.alpha(ThemeBackend.surface1, 0.35)
    border.width: 0

    ColumnLayout {
        id: selectorInnerCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: picker.rootObj.s(12)
        spacing: picker.rootObj.s(10)

        RowLayout {
            Layout.fillWidth: true
            spacing: picker.rootObj.s(6)

            ClickButton {
                enabled: false
                Layout.preferredWidth: picker.rootObj.s(140)
                implicitHeight: picker.rootObj.s(26)
                cornerRadius: picker.rootObj.s(6)
                horizontalPadding: picker.rootObj.s(6)
                textFontSize: picker.rootObj.s(11)
                accentColor: ThemeBackend.surface1
                textColor: "#ffffff"
                buttonText: "X: " + picker.logic.horizontalPosition + "%  Y: " + picker.logic.verticalPosition + "%"
            }

            IconButton {
                size: picker.rootObj.s(26)
                cornerRadius: picker.rootObj.s(6)
                buttonIcon: "󰕰"
                iconFontSize: picker.rootObj.s(13)
                accentColor: picker.gridEnabled ? ThemeBackend.mauve : ThemeBackend.surface1
                textColor: picker.gridEnabled ? ThemeBackend.crust : ThemeBackend.text
                onClicked: {
                    picker.gridEnabled = !picker.gridEnabled;
                }
            }

            IconButton {
                size: picker.rootObj.s(26)
                cornerRadius: picker.rootObj.s(6)
                buttonIcon: "󰑐"
                iconFontSize: picker.rootObj.s(13)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onClicked: {
                    picker.logic.applyPosition(picker.logic.presetRightH, picker.logic.presetTopV, "top right");
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: picker.rootObj.s(8)
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                Text {
                    text: I18n.t("guide.common.show_bar", "Show bar")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: picker.rootObj.s(11)
                    color: ThemeBackend.subtext0
                }

                Toggle {
                    checked: picker.showBarBox
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        picker.showBarBox = c;
                    }
                }
            }
        }

        ScreenPositionSelector {
            id: screenSelector
            Layout.fillWidth: true
            horizontalPosition: picker.logic.horizontalPosition
            verticalPosition: picker.logic.verticalPosition
            gridEnabled: picker.gridEnabled
            showBar: picker.showBarBox
            marginV: picker.rootObj.s(12)
            marginH: picker.rootObj.s(16)
            dragWidth: picker.rootObj.s(170)
            dragHeight: picker.rootObj.s(48)

            onPositionChanged: (hPos, vPos) => {
                let h = Math.round(hPos);
                let v = Math.round(vPos);
                picker.logic.horizontalPosition = h;
                picker.logic.verticalPosition = v;
                let idx = picker.logic.getPresetIndex(h, v);
                picker.logic.position = idx !== -1 ? picker.logic.getPosStringFromIndex(idx) : "custom";
                picker.logic.debounceTimer.restart();
            }

            onDragFinished: {
                picker.logic.debounceTimer.stop();
                let idx = picker.logic.getPresetIndex(picker.logic.horizontalPosition, picker.logic.verticalPosition);
                let posStr = idx !== -1 ? picker.logic.getPosStringFromIndex(idx) : "custom";
                picker.logic.position = posStr;
                let current = JSON.parse(JSON.stringify(Config.getSetting("notifications", picker.logic.defaultNotificationSettings) || picker.logic.defaultNotificationSettings));
                current.horizontalPosition = picker.logic.horizontalPosition;
                current.verticalPosition = picker.logic.verticalPosition;
                current.position = posStr;
                Config.setSetting("notifications", current);
                picker.logic.notifSettings = current;
            }

            Rectangle {
                anchors.fill: parent
                radius: picker.rootObj.s(8)
                color: ThemeBackend.base
                border.width: 1
                border.color: ThemeBackend.surface0
                clip: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: picker.rootObj.s(6)
                    spacing: picker.rootObj.s(8)

                    Rectangle {
                        Layout.preferredWidth: parent.height
                        Layout.preferredHeight: parent.height
                        Layout.alignment: Qt.AlignVCenter
                        radius: picker.rootObj.s(6)
                        color: ThemeBackend.surface1

                        Text {
                            anchors.centerIn: parent
                            text: "󰂚"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: picker.rootObj.s(16)
                            color: ThemeBackend.mauve
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: picker.rootObj.s(4)

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.maximumWidth: picker.rootObj.s(80)
                            height: picker.rootObj.s(6)
                            radius: picker.rootObj.s(3)
                            color: ThemeBackend.text
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.maximumWidth: picker.rootObj.s(110)
                            height: picker.rootObj.s(5)
                            radius: picker.rootObj.s(2.5)
                            color: ThemeBackend.subtext0
                        }
                    }
                }
            }
        }
    }
}
