import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"
import "../../../reusables"
import "../../../guide/display"
import ".."

// Display → Presets as a board: name and save the current setup (the Settings page's own PresetSaver), its
// messages, and the saved presets as the real preset cards (their previews, apply and delete stay as they are).
BoardPage {
    id: page
    extras: [ PresetSaver { id: saver },
        FilePicker {
        id: importPicker
        rootObj: page.rootObj
        titleText: "Import preset"
        nameFilters: ["*.json"]
        places: [
            { name: "Downloads", icon: "󰇚", path: "file://" + (Quickshell.env("XDG_DOWNLOAD_DIR") || (Quickshell.env("HOME") + "/Downloads")) },
            { name: "Home", icon: "󰋜", path: "file://" + Quickshell.env("HOME") }
        ]
        onFileSelected: function(filePath, fileName) { if (filePath) ConfigProfiles.importFile(filePath); }
    } ]

    BoardCard {
        title: "Save preset"; icon: "󰆓"; accent: page.accent
        BoardCell {
            kind: "custom"; wide: true; icon: "󰆓"; title: "Preset name"; customHeight: 34
            available: !saver.busy
            Row {
                width: parent.width; spacing: 8
                Rectangle {
                    width: parent.width - saveBtn.width - 8; height: 34; radius: Math.min(ThemeBackend.borderRadius, 10)
                    color: ThemeBackend.surface0; border.width: nameInput.activeFocus ? 2 : 0; border.color: page.accent
                    TextInput { id: nameInput; x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; clip: true
                                font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.text; selectionColor: Qt.alpha(page.accent, 0.4)
                                Keys.onReturnPressed: saver.savePreset(text); Keys.onEscapePressed: focus = false }
                    Text { visible: nameInput.text === "" && !nameInput.activeFocus; x: 12; anchors.verticalCenter: parent.verticalCenter
                           text: ConfigProfiles.nextName; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext1 }
                }
                Rectangle {
                    id: saveBtn
                    width: sl.implicitWidth + 28; height: 34; radius: 17
                    color: sMa.pressed ? Qt.darker(page.accent, 1.15) : page.accent
                    Text { id: sl; anchors.centerIn: parent; text: "Save preset"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.crust }
                    MouseArea { id: sMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); saver.savePreset(nameInput.text); } }
                }
            }
        }
        BoardCell {
            kind: "action"; icon: "󰋺"; title: "Import preset"; actionText: "Import"
            available: !saver.busy
            onActivated: importPicker.openWithOptionalPath("")
        }
        BoardCell {
            kind: "info"; icon: saver.captureError || ConfigProfiles.error ? "󰀪" : "󰋽"; title: "Status"
            readonly property string msg: saver.captureError || ConfigProfiles.error || (saver.busy ? "Working…" : ConfigProfiles.message)
            hidden: msg === ""
            info: msg
        }
    }

    BoardCard {
        title: "Presets"; icon: "󰆓"; accent: page.accent
        GridLayout {
            id: grid
            columns: 2
            columnSpacing: 12
            rowSpacing: 12
            Repeater {
                model: ConfigProfiles.styleProfiles
                PresetCard {
                    required property var modelData
                    profile: modelData.profile
                    profileIndex: modelData.index
                    rootObj: page.rootObj
                    enabled: !saver.busy
                    Layout.fillWidth: true
                    Layout.preferredWidth: (grid.width - grid.columnSpacing) / 2
                    Layout.maximumWidth: Layout.preferredWidth
                }
            }
        }
        BoardCell {
            kind: "info"; icon: "󰆓"; title: "Presets"; hidden: !ConfigProfiles.ready || ConfigProfiles.styleProfiles.length > 0
            info: "No presets yet. Save the current layout to get started."
        }
    }
}
