import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

// The position picker of the On-Screen Display page: a small screen to drag the OSD on (with grid, reset and the bar
// shown) and its coordinates. Shared by the Settings page and the Control Center's board. `logic` is a
// OsdLogic; `selector` is the ScreenPositionSelector inside (the logic reads the screen's safe area from it).
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
                    picker.logic.applyPosition(50, 90);
                }
            }

            Switch {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: picker.rootObj.s(160)
                implicitHeight: picker.rootObj.s(26)
                cornerRadius: picker.rootObj.s(6)
                fontPixelSize: picker.rootObj.s(11)
                options: [I18n.t("guide.osd.orientation.horizontal", "Horizontal"), I18n.t("guide.osd.orientation.vertical", "Vertical")]
                currentIndex: picker.logic.orientation === "vertical" ? 1 : 0
                accentColor: ThemeBackend.mauve
                baseColor: Qt.alpha(ThemeBackend.surface0, 0.4)
                textColor: ThemeBackend.text
                activeTextColor: ThemeBackend.crust
                onValueChanged: function(index, value) {
                    let orient = index === 1 ? "vertical" : "horizontal";
                    picker.logic.orientation = orient;
                    picker.logic.updateOsdSetting("orientation", orient);
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
            dragWidth: picker.logic.isVertical ? picker.rootObj.s(43) : picker.rootObj.s(173)
            dragHeight: picker.logic.isVertical ? picker.rootObj.s(173) : picker.rootObj.s(43)

            onPositionChanged: (hPos, vPos) => {
                picker.logic.horizontalPosition = hPos;
                picker.logic.verticalPosition = vPos;
                picker.presetCleared();
                picker.logic.debounceTimer.restart();
            }

            onDragFinished: {
                picker.logic.debounceTimer.stop();
                picker.presetCleared();
                let current = JSON.parse(JSON.stringify(Config.getSetting("osd", picker.logic.defaultOsdSettings) || picker.logic.defaultOsdSettings));
                current.horizontalPosition = picker.logic.horizontalPosition;
                current.verticalPosition = picker.logic.verticalPosition;
                Config.setSetting("osd", current);
                picker.logic.osdSettings = current;
            }

            Rectangle {
                anchors.fill: parent
                radius: picker.rootObj.s(11)
                color: ThemeBackend.base
                border.width: 1
                border.color: ThemeBackend.surface0
                clip: true

                RowLayout {
                    visible: !picker.logic.isVertical
                    anchors.fill: parent
                    anchors.leftMargin: picker.rootObj.s(7)
                    anchors.rightMargin: picker.rootObj.s(12)
                    spacing: picker.rootObj.s(9)

                    Rectangle {
                        Layout.preferredWidth: parent.height - picker.rootObj.s(10)
                        Layout.preferredHeight: parent.height - picker.rootObj.s(10)
                        Layout.alignment: Qt.AlignVCenter
                        radius: picker.rootObj.s(7)
                        color: ThemeBackend.surface1

                        Text {
                            anchors.centerIn: parent
                            text: "󰕾"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: picker.rootObj.s(18)
                            color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            id: trackBar
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: picker.rootObj.s(9)
                            radius: height / 2
                            color: ThemeBackend.surface1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: parent.width * 0.65
                                radius: parent.radius
                                color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                            }

                            Rectangle {
                                x: (parent.width * 0.65) - (width / 2)
                                anchors.verticalCenter: parent.verticalCenter
                                width: picker.rootObj.s(16)
                                height: picker.rootObj.s(16)
                                radius: width / 2
                                color: Qt.lighter(ThemeBackend.sapphire, 1.3)
                                border.width: 1
                                border.color: Qt.rgba(0, 0, 0, 0.25)
                            }
                        }
                    }
                }

                ColumnLayout {
                    visible: picker.logic.isVertical
                    anchors.fill: parent
                    anchors.topMargin: picker.rootObj.s(7)
                    anchors.bottomMargin: picker.rootObj.s(12)
                    spacing: picker.rootObj.s(9)

                    Rectangle {
                        Layout.preferredWidth: parent.width - picker.rootObj.s(10)
                        Layout.preferredHeight: parent.width - picker.rootObj.s(10)
                        Layout.alignment: Qt.AlignHCenter
                        radius: picker.rootObj.s(7)
                        color: ThemeBackend.surface1

                        Text {
                            anchors.centerIn: parent
                            text: "󰕾"
                            font.family: "Iosevka Nerd Font"
                            font.pixelSize: picker.rootObj.s(18)
                            color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: picker.rootObj.s(9)
                            radius: width / 2
                            color: ThemeBackend.surface1

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: parent.height * 0.65
                                radius: parent.radius
                                color: Qt.lighter(ThemeBackend.sapphire, 1.5)
                            }

                            Rectangle {
                                y: parent.height - (parent.height * 0.65) - (height / 2)
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: picker.rootObj.s(16)
                                height: picker.rootObj.s(16)
                                radius: width / 2
                                color: Qt.lighter(ThemeBackend.sapphire, 1.3)
                                border.width: 1
                                border.color: Qt.rgba(0, 0, 0, 0.25)
                            }
                        }
                    }
                }
            }
        }
    }
}
