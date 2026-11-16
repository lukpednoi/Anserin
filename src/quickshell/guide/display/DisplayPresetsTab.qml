import "../../"
import "../../reusables"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 1
    // saving lives in PresetSaver.qml (shared with the Control Center's board)
    PresetSaver { id: saver }
    readonly property alias busy: saver.busy
    readonly property alias captureError: saver.captureError
    function savePreset() { saver.savePreset(nameField.text); }
    FilePicker {
        id: importPicker
        rootObj: root.rootObj
        titleText: "Import preset"
        nameFilters: ["*.json"]
        places: [
            { name: "Downloads", icon: "󰇚", path: "file://" + (Quickshell.env("XDG_DOWNLOAD_DIR") || (Quickshell.env("HOME") + "/Downloads")) },
            { name: "Home", icon: "󰋜", path: "file://" + Quickshell.env("HOME") }
        ]
        onFileSelected: function(filePath, fileName) { if (filePath) ConfigProfiles.importFile(filePath); }
    }
    objectName: "display-presets-page"
    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex


    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.rootObj.s(12)
        spacing: root.rootObj.s(12)

        RowLayout {
            Layout.fillWidth: true

            Input {
                id: nameField

                objectName: "preset-name"
                Layout.fillWidth: true
                implicitHeight: root.rootObj.s(36)
                placeholderText: ConfigProfiles.nextName
                enabled: !root.busy
                textColor: ThemeBackend.text
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                cornerRadius: ThemeBackend.borderRadius
            }

            ClickButton {
                objectName: "save-preset"
                buttonText: "Save preset"
                enabled: !root.busy
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: root.savePreset()
            }

            // a preset file shared by someone (or exported from a preset card)
            ClickButton {
                objectName: "import-preset"
                buttonText: "Import"
                buttonIcon: "󰋺"
                enabled: !root.busy
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onClicked: importPicker.openWithOptionalPath("")
            }

        }

        Text {
            Layout.fillWidth: true
            text: root.captureError || ConfigProfiles.error || (root.busy ? "Working…" : ConfigProfiles.message)
            visible: text !== ""
            color: root.captureError || ConfigProfiles.error ? ThemeBackend.red : ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.rootObj.s(11)
            wrapMode: Text.Wrap
        }

        Flickable {
            id: presetViewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: grid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: grid

                width: parent.width
                columns: (root.rootObj.anserinInterface === true || width < root.rootObj.s(750)) ? 2 : 3
                columnSpacing: root.rootObj.s(12)
                rowSpacing: root.rootObj.s(12)

                Repeater {
                    model: ConfigProfiles.styleProfiles

                    PresetCard {
                        required property var modelData

                        profile: modelData.profile
                        profileIndex: modelData.index
                        rootObj: root.rootObj
                        enabled: !root.busy
                        Layout.fillWidth: true
                        Layout.preferredWidth: (grid.width - (grid.columns - 1) * grid.columnSpacing) / grid.columns
                        Layout.maximumWidth: Layout.preferredWidth
                    }

                }

            }

            Text {
                parent: presetViewport
                anchors.centerIn: parent
                width: parent.width - root.rootObj.s(24)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: ConfigProfiles.ready && ConfigProfiles.styleProfiles.length === 0
                text: "No presets yet. Save the current layout to get started."
                color: ThemeBackend.subtext0
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.rootObj.s(12)
            }

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

        }

    }

}
