import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Infinite desktop controls: a section of the Terminal page (not a page of its own).
ColumnLayout {
    id: infRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 0
    Layout.fillWidth: true
    spacing: rootObj.s(6)

    SectionCard {
        rootObj: infRoot.rootObj
        icon: "󰍹"
        title: "Infinite Desktop"
        wrapText: true

        // live state as a pill: dot + ON/OFF, tinted with the accent when active
        Rectangle {
            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            implicitWidth: pillRow.implicitWidth + infRoot.rootObj.s(20)
            implicitHeight: infRoot.rootObj.s(26)
            radius: height / 2
            color: TerminalAppearance.infiniteActive ? Qt.alpha(ThemeBackend.mauve, 0.18) : ThemeBackend.surface0
            border.width: 1
            border.color: TerminalAppearance.infiniteActive ? Qt.alpha(ThemeBackend.mauve, 0.55) : Qt.alpha(ThemeBackend.surface2, 0.6)
            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: infRoot.rootObj.s(6)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: infRoot.rootObj.s(8); height: width; radius: width / 2
                    color: TerminalAppearance.infiniteActive ? ThemeBackend.mauve : ThemeBackend.overlay1
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: TerminalAppearance.infiniteActive ? "Active" : "Inactive"
                    color: TerminalAppearance.infiniteActive ? ThemeBackend.mauve : ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: infRoot.rootObj.s(11)
                    font.weight: Font.Bold
                }
            }
        }

        subSettings: [
            SettingsRow {
                rootObj: infRoot.rootObj
                icon: "󰌌"
                title: I18n.t("guide.terminal.infinite.toggle_shortcut")
                wrapText: true
                ShortcutRecorder {
                    id: toggleShortcutInput
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: infRoot.rootObj.s(190)
                    implicitHeight: infRoot.rootObj.s(32)
                    value: TerminalAppearance.infiniteSettings.toggleShortcut
                    hasError: TerminalAppearance.shortcutError !== ""
                    accentColor: ThemeBackend.mauve
                    fontPixelSize: infRoot.rootObj.s(11)
                }
                ClickButton {
                    buttonText: I18n.t("guide.terminal.infinite.save_shortcut")
                    buttonIcon: "󰆓"
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    textFontSize: infRoot.rootObj.s(11)
                    onClicked: TerminalAppearance.saveToggleShortcut(toggleShortcutInput.combo)
                }
            },
            SettingsRow {
                rootObj: infRoot.rootObj
                icon: "󰙖"
                title: "Window size"
                description: Math.round(TerminalAppearance.infiniteSettings.cellScale) + "% of one 2×2 cell; text keeps its size"
                wrapText: true
                Draggable {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: infRoot.rootObj.s(180)
                    implicitHeight: infRoot.rootObj.s(18)
                    from: 50
                    to: 150
                    stepSize: 10
                    defaultValue: 100
                    value: TerminalAppearance.infiniteSettings.cellScale
                    backgroundColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    handleColor: ThemeBackend.text
                    handleBorderColor: ThemeBackend.mantle
                    onMoved: function(value) { if (!isDragging) TerminalAppearance.setInfiniteOption("cellScale", Math.round(value / 10) * 10); }
                    onDragFinished: TerminalAppearance.setInfiniteOption("cellScale", Math.round(value / 10) * 10)
                }
            },
            // CLI toy: what a terminal drawn with the right button runs, one of the picked programs at random
            SettingsRow {
                rootObj: infRoot.rootObj
                icon: "󰆍"
                title: "CLI toy"
                wrapText: true
                Component.onCompleted: TerminalAppearance.refreshDragPrograms()
                Flow {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.maximumWidth: infRoot.rootObj.s(420)
                    spacing: infRoot.rootObj.s(6)
                    layoutDirection: Qt.RightToLeft
                    Repeater {
                        model: TerminalAppearance.availableDragPrograms
                        Rectangle {
                            id: toyChip
                            required property var modelData
                            readonly property bool picked: TerminalAppearance.cliToys.indexOf(modelData.id) >= 0
                            width: toyLabel.implicitWidth + infRoot.rootObj.s(24); height: infRoot.rootObj.s(30); radius: height / 2
                            color: picked ? ThemeBackend.mauve : (toyMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
                            Behavior on color { ColorAnimation { duration: 160 } }
                            Text { id: toyLabel; anchors.centerIn: parent; text: toyChip.modelData.name
                                   font.family: ThemeBackend.fontFamily; font.pixelSize: infRoot.rootObj.s(11); font.bold: toyChip.picked
                                   color: toyChip.picked ? ThemeBackend.crust : ThemeBackend.text }
                            MouseArea {
                                id: toyMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Sounds.playSfx("reusables/switch/sfx.wav");
                                    const id = toyChip.modelData.id, current = TerminalAppearance.cliToys;
                                    TerminalAppearance.setCliToys(toyChip.picked ? current.filter(t => t !== id) : current.concat([id]));
                                }
                            }
                        }
                    }
                }
            },
            SettingsRow {
                rootObj: infRoot.rootObj
                icon: "󰕰"
                title: I18n.t("guide.terminal.infinite.arrange")
                wrapText: true
                enabled: TerminalAppearance.infiniteActive
                opacity: enabled ? 1 : 0.5
                Behavior on opacity { NumberAnimation { duration: 200 } }
                ClickButton {
                    buttonText: I18n.t("guide.terminal.infinite.arrange")
                    buttonIcon: "󰕰"
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    textFontSize: infRoot.rootObj.s(11)
                    onClicked: TerminalAppearance.infiniteAction("arrange")
                }
            }
        ]
    }

    // inf desktop: Pan — Anserin's fixed way, or keys chosen here (the keys row opens only for Custom keys)
    SectionCard {
        rootObj: infRoot.rootObj
        icon: "󰆾"
        title: "Pan"
        wrapText: true
        subSettings: [
            SettingsRow {
                rootObj: infRoot.rootObj
                icon: "󰆾"
                title: "Mode"
                description: TerminalAppearance.infiniteSettings.panMode === "custom" ? "Hold the keys and move the mouse (1.6× the mouse)" : "Drag the empty desktop with the left button (1.6× the mouse)"
                wrapText: true
                Dropdown {
                    id: panModeSelector
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: infRoot.rootObj.s(180)
                    implicitHeight: infRoot.rootObj.s(32)
                    property var modes: ["anserin", "custom"]
                    options: ["Anserin", "Custom keys"]
                    currentIndex: Math.max(0, modes.indexOf(TerminalAppearance.infiniteSettings.panMode))
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: infRoot.rootObj.s(11)
                    onValueChanged: function(index) { TerminalAppearance.setInfiniteOption("panMode", modes[index]); }
                }
            },
            Loader {
                Layout.fillWidth: true
                active: TerminalAppearance.infiniteSettings.panMode === "custom"
                visible: active
                sourceComponent: SettingsRow {
                    rootObj: infRoot.rootObj
                    icon: "󰌌"
                    title: "Keys"
                    description: TerminalAppearance.keysError.panKeys || "Press the modifier keys, then Save"
                    wrapText: true
                    ShortcutRecorder {
                        id: panRec
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: infRoot.rootObj.s(190)
                        implicitHeight: infRoot.rootObj.s(32)
                        value: TerminalAppearance.infiniteSettings.panKeys
                        hasError: !!TerminalAppearance.keysError.panKeys
                        accentColor: ThemeBackend.mauve
                        fontPixelSize: infRoot.rootObj.s(11)
                    }
                    ClickButton {
                        buttonText: I18n.t("guide.terminal.infinite.save_shortcut")
                        buttonIcon: "󰆓"
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.crust
                        textFontSize: infRoot.rootObj.s(11)
                        onClicked: TerminalAppearance.saveInfiniteKeys("panKeys", panRec.combo)
                    }
                }
            }
        ]
    }

    // inf desktop: Go to window — Anserin's fixed way, or keys chosen here (the keys row opens only for Custom keys)
    SectionCard {
        rootObj: infRoot.rootObj
        icon: "󰁔"
        title: "Go to window"
        wrapText: true
        subSettings: [
            SettingsRow {
                rootObj: infRoot.rootObj
                icon: "󰁔"
                title: "Mode"
                description: TerminalAppearance.infiniteSettings.navigateMode === "custom" ? "Keys + arrows bring the next window to the middle" : "Win + arrows bring the next window to the middle"
                wrapText: true
                Dropdown {
                    id: navigateModeSelector
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: infRoot.rootObj.s(180)
                    implicitHeight: infRoot.rootObj.s(32)
                    property var modes: ["anserin", "custom"]
                    options: ["Anserin", "Custom keys"]
                    currentIndex: Math.max(0, modes.indexOf(TerminalAppearance.infiniteSettings.navigateMode))
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: infRoot.rootObj.s(11)
                    onValueChanged: function(index) { TerminalAppearance.setInfiniteOption("navigateMode", modes[index]); }
                }
            },
            Loader {
                Layout.fillWidth: true
                active: TerminalAppearance.infiniteSettings.navigateMode === "custom"
                visible: active
                sourceComponent: SettingsRow {
                    rootObj: infRoot.rootObj
                    icon: "󰌌"
                    title: "Keys"
                    description: TerminalAppearance.keysError.navigateKeys || "Press the modifier keys, then Save"
                    wrapText: true
                    ShortcutRecorder {
                        id: navigateRec
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: infRoot.rootObj.s(190)
                        implicitHeight: infRoot.rootObj.s(32)
                        value: TerminalAppearance.infiniteSettings.navigateKeys
                        hasError: !!TerminalAppearance.keysError.navigateKeys
                        accentColor: ThemeBackend.mauve
                        fontPixelSize: infRoot.rootObj.s(11)
                    }
                    ClickButton {
                        buttonText: I18n.t("guide.terminal.infinite.save_shortcut")
                        buttonIcon: "󰆓"
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.crust
                        textFontSize: infRoot.rootObj.s(11)
                        onClicked: TerminalAppearance.saveInfiniteKeys("navigateKeys", navigateRec.combo)
                    }
                }
            }
        ]
    }

    // inf desktop: Move window — Anserin's fixed way, or keys chosen here (the keys row opens only for Custom keys)
    SectionCard {
        rootObj: infRoot.rootObj
        icon: "󰁁"
        title: "Move window"
        wrapText: true
        subSettings: [
            SettingsRow {
                rootObj: infRoot.rootObj
                icon: "󰁁"
                title: "Mode"
                description: TerminalAppearance.infiniteSettings.moveMode === "custom" ? "Keys + arrows move the window 90 px; at an edge the canvas moves" : "Win + drag a window; pushing it into a screen edge moves the canvas"
                wrapText: true
                Dropdown {
                    id: moveModeSelector
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: infRoot.rootObj.s(180)
                    implicitHeight: infRoot.rootObj.s(32)
                    property var modes: ["anserin", "custom"]
                    options: ["Anserin", "Custom keys"]
                    currentIndex: Math.max(0, modes.indexOf(TerminalAppearance.infiniteSettings.moveMode))
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: infRoot.rootObj.s(11)
                    onValueChanged: function(index) { TerminalAppearance.setInfiniteOption("moveMode", modes[index]); }
                }
            },
            Loader {
                Layout.fillWidth: true
                active: TerminalAppearance.infiniteSettings.moveMode === "custom"
                visible: active
                sourceComponent: SettingsRow {
                    rootObj: infRoot.rootObj
                    icon: "󰌌"
                    title: "Keys"
                    description: TerminalAppearance.keysError.moveKeys || "Press the modifier keys, then Save"
                    wrapText: true
                    ShortcutRecorder {
                        id: moveRec
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: infRoot.rootObj.s(190)
                        implicitHeight: infRoot.rootObj.s(32)
                        value: TerminalAppearance.infiniteSettings.moveKeys
                        hasError: !!TerminalAppearance.keysError.moveKeys
                        accentColor: ThemeBackend.mauve
                        fontPixelSize: infRoot.rootObj.s(11)
                    }
                    ClickButton {
                        buttonText: I18n.t("guide.terminal.infinite.save_shortcut")
                        buttonIcon: "󰆓"
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.crust
                        textFontSize: infRoot.rootObj.s(11)
                        onClicked: TerminalAppearance.saveInfiniteKeys("moveKeys", moveRec.combo)
                    }
                }
            }
        ]
    }

    // inf desktop: Resize — Anserin's fixed way, or keys chosen here (the keys row opens only for Custom keys)
    SectionCard {
        rootObj: infRoot.rootObj
        icon: "󰩨"
        title: "Resize"
        wrapText: true
        subSettings: [
            SettingsRow {
                rootObj: infRoot.rootObj
                icon: "󰩨"
                title: "Mode"
                description: TerminalAppearance.infiniteSettings.resizeMode === "custom" ? "Keys + arrows: right/down grow, left/up shrink by 90 px" : "Drag a window edge with the left button"
                wrapText: true
                Dropdown {
                    id: resizeModeSelector
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: infRoot.rootObj.s(180)
                    implicitHeight: infRoot.rootObj.s(32)
                    property var modes: ["anserin", "custom"]
                    options: ["Anserin", "Custom keys"]
                    currentIndex: Math.max(0, modes.indexOf(TerminalAppearance.infiniteSettings.resizeMode))
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: infRoot.rootObj.s(11)
                    onValueChanged: function(index) { TerminalAppearance.setInfiniteOption("resizeMode", modes[index]); }
                }
            },
            Loader {
                Layout.fillWidth: true
                active: TerminalAppearance.infiniteSettings.resizeMode === "custom"
                visible: active
                sourceComponent: SettingsRow {
                    rootObj: infRoot.rootObj
                    icon: "󰌌"
                    title: "Keys"
                    description: TerminalAppearance.keysError.resizeKeys || "Press the modifier keys, then Save"
                    wrapText: true
                    ShortcutRecorder {
                        id: resizeRec
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: infRoot.rootObj.s(190)
                        implicitHeight: infRoot.rootObj.s(32)
                        value: TerminalAppearance.infiniteSettings.resizeKeys
                        hasError: !!TerminalAppearance.keysError.resizeKeys
                        accentColor: ThemeBackend.mauve
                        fontPixelSize: infRoot.rootObj.s(11)
                    }
                    ClickButton {
                        buttonText: I18n.t("guide.terminal.infinite.save_shortcut")
                        buttonIcon: "󰆓"
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.crust
                        textFontSize: infRoot.rootObj.s(11)
                        onClicked: TerminalAppearance.saveInfiniteKeys("resizeKeys", resizeRec.combo)
                    }
                }
            }
        ]
    }
}
