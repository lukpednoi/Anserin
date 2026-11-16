import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import "../../"
import "../../reusables"
import "../../reusables/guide"

ColumnLayout {
    id: configTab
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 0
    Layout.fillWidth: true
    spacing: rootObj.s(6)

    property var asciiNames: []
    property var picNames: []
    readonly property var settings: TerminalAppearance.fastfetchSettings

    function refreshFiles() {
        let names = [];
        for (let i = 0; i < asciiFiles.count; i++) names.push(asciiFiles.get(i, "fileName"));
        asciiNames = names;
        names = [];
        for (let i = 0; i < picFiles.count; i++) names.push(picFiles.get(i, "fileName"));
        picNames = names;
    }

    FolderListModel {
        id: asciiFiles
        folder: "file://" + TerminalAppearance.fastfetchDir + "/ascii"
        nameFilters: ["*.txt"]
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onCountChanged: Qt.callLater(configTab.refreshFiles)
        onDataChanged: Qt.callLater(configTab.refreshFiles)
        onStatusChanged: Qt.callLater(configTab.refreshFiles)
    }

    FolderListModel {
        id: picFiles
        folder: "file://" + TerminalAppearance.fastfetchDir + "/pngs"
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.avif"]
        caseSensitive: false
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
        onCountChanged: Qt.callLater(configTab.refreshFiles)
        onDataChanged: Qt.callLater(configTab.refreshFiles)
        onStatusChanged: Qt.callLater(configTab.refreshFiles)
    }

    Text {
        Layout.fillWidth: true
        text: TerminalAppearance.fastfetchError
        visible: text !== ""
        color: ThemeBackend.red
        font.family: ThemeBackend.fontFamily
        font.pixelSize: rootObj.s(11)
        wrapMode: Text.WordWrap
    }

    SectionCard {
        rootObj: configTab.rootObj
        icon: "󰒓"
        title: "Fastfetch"
        wrapText: true
        subSettings: [
            ColumnLayout {
                Layout.fillWidth: true
                spacing: configTab.rootObj.s(6)

            SettingsRow {
                rootObj: configTab.rootObj
                settingId: "terminal_fastfetch_auto"
                icon: "󰆍"
                title: "Auto Fastfetch"
                Toggle {
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface2
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    checked: configTab.settings.auto
                    onToggled: function(checked) { TerminalAppearance.setFastfetchOption("auto", checked); }
                }
            }

            SettingsRow {
                rootObj: configTab.rootObj
                settingId: "terminal_fastfetch_hide_logo"
                icon: "󰈉"
                title: "Hide ASCII / Pic"
                Toggle {
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface2
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    checked: configTab.settings.hideLogo
                    onToggled: function(checked) { TerminalAppearance.setFastfetchOption("hideLogo", checked); }
                }
            }

            SettingsRow {
                rootObj: configTab.rootObj
                settingId: "terminal_fastfetch_mode"
                icon: "󰆍"
                title: I18n.t("guide.terminal.fastfetch.mode", "Fastfetch logo")
                Dropdown {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(180)
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: rootObj.s(11)
                    options: ["Default", "ASCII", "Pic"]
                    enabled: !configTab.settings.random
                    currentIndex: ["default", "ascii", "pic"].indexOf(configTab.settings.mode)
                    onValueChanged: function(index) { TerminalAppearance.setFastfetchOption("mode", ["default", "ascii", "pic"][index]); }
                }
            }

            SettingsRow {
                rootObj: configTab.rootObj
                settingId: "terminal_fastfetch_random"
                icon: "󰒟"
                title: "Random"
                Toggle {
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface2
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    checked: configTab.settings.random
                    onToggled: function(checked) { TerminalAppearance.setFastfetchOption("random", checked); }
                }
            }

            SettingsRow {
                rootObj: configTab.rootObj
                visible: configTab.settings.random
                settingId: "terminal_fastfetch_random_source"
                icon: "󰒟"
                title: I18n.t("guide.terminal.fastfetch.random_source", "Random source")
                Dropdown {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(180)
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    fontPixelSize: rootObj.s(11)
                    options: ["ASCII", "Pic", "Both"]
                    currentIndex: ["ascii", "pic", "both"].indexOf(configTab.settings.randomMode)
                    onValueChanged: function(index) { TerminalAppearance.setFastfetchOption("randomMode", ["ascii", "pic", "both"][index]); }
                }
            }

            Repeater {
                model: ["ascii", "pic"]
                delegate: SettingsRow {
                    id: fileRow
                    required property string modelData
                    readonly property var names: modelData === "ascii" ? configTab.asciiNames : configTab.picNames
                    rootObj: configTab.rootObj
                    visible: configTab.settings.random
                        ? (configTab.settings.randomMode === "both" || configTab.settings.randomMode === modelData)
                        : configTab.settings.mode === modelData
                    settingId: "terminal_fastfetch_" + modelData
                    icon: modelData === "ascii" ? "󰆍" : "󰋩"
                    title: modelData === "ascii" ? "ASCII" : "Pic"

                    Dropdown {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: rootObj.s(200)
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        hoverColor: ThemeBackend.surface1
                        dropdownColor: ThemeBackend.surface0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        textColor: ThemeBackend.text
                        activeTextColor: ThemeBackend.crust
                        fontPixelSize: rootObj.s(11)
                        options: fileRow.names
                        enabled: !configTab.settings.random && fileRow.names.length > 0
                        placeholderText: I18n.t("guide.terminal.fastfetch.empty", "No files")
                        currentIndex: fileRow.names.length ? Math.max(0, fileRow.names.indexOf(configTab.settings[fileRow.modelData])) : -1
                        onValueChanged: function(index) { TerminalAppearance.setFastfetchOption(fileRow.modelData, fileRow.names[index]); }
                    }

                    ClickButton {
                        buttonText: fileRow.modelData === "ascii" ? "Add ASCII" : "Add Pic"
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        textFontSize: rootObj.s(11)
                        onClicked: FileManager.openFolder(TerminalAppearance.fastfetchDir + (fileRow.modelData === "ascii" ? "/ascii" : "/pngs"), false)
                    }
                }
            }
            }
        ]
    }
}
