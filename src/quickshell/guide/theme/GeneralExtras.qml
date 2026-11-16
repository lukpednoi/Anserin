import "../../" as Real
import "../../reusables" as Controls
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var rootObj
    readonly property bool glass: Real.ThemeBackend.liquidGlass

    objectName: "theme-general-extras"
    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        width: parent.width
        spacing: root.rootObj.s(6)

        Controls.SettingsRow {
            objectName: "theme-mode-row"
            rootObj: root.rootObj
            title: "Color mode"
            description: Real.Matugen.matugenActive ? "Light or dark colours from the wallpaper" : "Set by the chosen colour theme · pick Matugen to switch"
            icon: "󰔎"

            Controls.Switch {
                objectName: "theme-mode-selector"
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: root.rootObj.s(250)
                implicitHeight: root.rootObj.s(32)
                options: ["Light", "Dark"]
                currentIndex: Real.Matugen.colorMode === "light" ? 0 : 1
                enabled: Real.Matugen.matugenActive && !Real.Matugen.isRunning
                opacity: Real.Matugen.matugenActive ? 1 : 0.5
                accentColor: Real.ThemeBackend.mauve
                baseColor: Real.ThemeBackend.surface0
                textColor: Real.ThemeBackend.subtext0
                activeTextColor: Real.ThemeBackend.crust
                cornerRadius: Real.ThemeBackend.borderRadius
                fontPixelSize: root.rootObj.s(11)
                onToggled: (index) => Real.Matugen.setColorMode(index === 0 ? "light" : "dark")
            }
        }

        Controls.SettingsRow {
            objectName: "theme-material-row"
            rootObj: root.rootObj
            title: "Theme style"
            icon: "󰏘"

            Controls.Switch {
                objectName: "theme-material-selector"
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                implicitWidth: root.rootObj.s(250)
                implicitHeight: root.rootObj.s(32)
                options: ["Default", "Liquid Glass"]
                currentIndex: root.glass ? 1 : 0
                accentColor: Real.ThemeBackend.mauve
                baseColor: Real.ThemeBackend.surface0
                textColor: Real.ThemeBackend.subtext0
                activeTextColor: Real.ThemeBackend.crust
                cornerRadius: Real.ThemeBackend.borderRadius
                fontPixelSize: root.rootObj.s(11)
                onToggled: (index) => {
                    Real.Config.setSetting("theme.material", index === 1 ? "liquid" : "default");
                }
            }

        }

        // apps that follow Anserin's colours (singletons/theme/AppTheming.qml); only installed ones are offered
        Controls.SettingsRow {
            objectName: "theme-apps-row"
            rootObj: root.rootObj
            title: "Apps"
            description: Real.AppTheming.error || (Real.AppTheming.busy ? "Applying theme…" : Real.AppTheming.enabledIds.length > 0 ? "Follow Anserin colors · reopen an app to refresh · turning one off restores its config" : "Pick apps to follow Anserin colors; their original settings are kept")
            icon: "󰀻"

            bottomContent: Flow {
                Layout.fillWidth: true
                spacing: root.rootObj.s(6)
                Repeater {
                    model: Real.AppTheming.installedApps
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool picked: Real.AppTheming.enabledIds.indexOf(modelData.id) >= 0
                        width: appChip.implicitWidth + root.rootObj.s(20)
                        height: root.rootObj.s(28)
                        radius: height / 2
                        color: picked ? Real.ThemeBackend.mauve : (chipMouse.containsMouse ? Real.ThemeBackend.surface1 : Real.ThemeBackend.surface0)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Text {
                            id: appChip
                            anchors.centerIn: parent
                            text: (modelData.icon ? modelData.icon + "  " : "") + modelData.name
                            color: parent.picked ? Real.ThemeBackend.crust : Real.ThemeBackend.text
                            font.family: Real.ThemeBackend.fontFamily
                            font.pixelSize: root.rootObj.s(11)
                        }
                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Real.Sounds.playSfx("reusables/switch/sfx.wav");
                                Real.AppTheming.setEnabled(modelData.id, !parent.picked);
                            }
                        }
                    }
                }
            }
        }
    }

}
