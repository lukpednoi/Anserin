import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../../"
import "../../../guide/display"
import "../../../reusables"

// 3B. DISPLAY -> PRESETS (real PresetSaver, FilePicker, PresetCard grid)
Column {
    id: page
    property var app: null
    spacing: 11

    PresetSaver { id: saver }
    Item {
        width: 0; height: 0; visible: false
        FilePicker {
            id: importPicker
            rootObj: page.app ? page.app.shim : null
            onOpened: if (page.app) page.app.modalOpened()
            onClosed: if (page.app) page.app.modalClosed()
            titleText: "Import preset"
            nameFilters: ["*.json"]
            places: [
                { name: "Downloads", icon: "󰇚", path: "file://" + (Quickshell.env("XDG_DOWNLOAD_DIR") || (Quickshell.env("HOME") + "/Downloads")) },
                { name: "Home", icon: "󰋜", path: "file://" + Quickshell.env("HOME") }
            ]
            onFileSelected: function(filePath, fileName) { if (filePath) ConfigProfiles.importFile(filePath); }
        }
    }
    Component.onDestruction: importPicker.close()

    property string newPresetName: ""
    readonly property string nextPresetName: ConfigProfiles.nextName || ("config-" + (ConfigProfiles.styleProfiles.length + 1))
    readonly property string presetStatus: saver.captureError || ConfigProfiles.error || (saver.busy ? "Working…" : ConfigProfiles.message)

    component SCard: SmartCard {
        cornerRadius: page.app.cornerRadius; darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cCard; accent: page.app.cAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SAction: SmartActionTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SField: SmartFieldTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }

    SCard {
        title: "Save preset"; icon: "󰆓"
        SField {
            icon: "󰆓"; title: "Preset name"; text: page.newPresetName; placeholder: page.nextPresetName; actionText: "Save"
            onEdited: (v) => page.newPresetName = v
            onSubmitted: (v) => {
                if (!saver.busy) saver.savePreset((v || "").trim());
                page.newPresetName = "";
                page.app.sfx.playQuick();
            }
        }
        SAction { width: parent.width; icon: "󰋺"; title: "Import preset (.json)"; actionText: "Import"; onTriggered: { page.app.sfx.playClick(); importPicker.openWithOptionalPath(""); } }
        Text { visible: page.presetStatus !== ""; width: parent.width; leftPadding: 4; wrapMode: Text.WordWrap
               text: page.presetStatus; font.family: page.app.uiFont; font.pixelSize: 10; color: page.app.cSub }
    }

    SCard {
        title: "Presets"; icon: "󰆓"; statusText: ConfigProfiles.styleProfiles.length + " SAVED"
        GridLayout {
            id: presetGrid
            width: parent.width
            columns: 2; columnSpacing: 8; rowSpacing: 8
            Repeater {
                model: ConfigProfiles.styleProfiles
                PresetCard {
                    required property var modelData
                    profile: modelData.profile
                    profileIndex: modelData.index
                    rootObj: page.app.shim
                    enabled: !saver.busy
                    Layout.fillWidth: true
                    Layout.preferredWidth: (presetGrid.width - presetGrid.columnSpacing) / 2
                    Layout.maximumWidth: Layout.preferredWidth
                }
            }
        }
        Text {
            visible: ConfigProfiles.ready && ConfigProfiles.styleProfiles.length === 0
            width: parent.width; leftPadding: 4; wrapMode: Text.WordWrap
            text: "No presets yet. Save the current layout to get started."
            font.family: page.app.uiFont; font.pixelSize: 11; color: page.app.cSub
        }
    }
}
