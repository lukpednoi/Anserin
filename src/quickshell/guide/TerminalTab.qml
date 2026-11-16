import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"
import "../reusables/guide"
import "terminal"

Item {
    id: terminalTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 0
    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)
    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    Flickable {
        anchors.fill: parent
        anchors.margins: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            Text {
                Layout.fillWidth: true
                Layout.margins: rootObj.s(12)
                text: TerminalAppearance.error || TerminalAppearance.shortcutError
                visible: text !== ""
                color: ThemeBackend.red
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(11)
                wrapMode: Text.WordWrap
            }

            SectionCard {
                rootObj: terminalTabRoot.rootObj
                icon: "󰆍"
                title: "Desktop & Appearance"
                subSettings: [
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(6)
                        Repeater {
                            model: [
                                { key: "background", icon: "󰆍", values: ["default", "blur", "clear"] },
                                { key: "prompt", icon: "󰘳", values: ["default", "hex"] },
                                { key: "border", icon: "󰖯", values: ["white", "default", "theme", "none"] },
                                { key: "workspace", icon: "󰹑", values: ["vertical", "horizontal"] }
                            ]
                            delegate: ColumnLayout {
                                id: optionRow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: rootObj.s(6)

                                SettingsRow {
                                    rootObj: terminalTabRoot.rootObj
                                    icon: optionRow.modelData.icon
                                    settingId: "terminal_" + optionRow.modelData.key
                                    title: I18n.t("guide.terminal." + optionRow.modelData.key + ".title")
                                    description: I18n.t("guide.terminal." + optionRow.modelData.key + ".desc")

                                    Dropdown {
                                        id: selector
                                        objectName: "terminal-" + optionRow.modelData.key
                                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                        implicitWidth: rootObj.s(180)
                                        implicitHeight: rootObj.s(32)
                                        options: optionRow.modelData.values.map(function(value) {
                                            return I18n.t("guide.terminal.options." + value);
                                        })
                                        currentIndex: {
                                            let key = optionRow.modelData.key;
                                            let value = TerminalAppearance.settings[key] || TerminalAppearance.defaults[key];
                                            let index = optionRow.modelData.values.indexOf(value);
                                            return index >= 0 ? index : optionRow.modelData.values.indexOf(TerminalAppearance.defaults[key]);
                                        }
                                        accentColor: ThemeBackend.mauve
                                        baseColor: ThemeBackend.surface0
                                        hoverColor: ThemeBackend.surface1
                                        dropdownColor: ThemeBackend.surface0
                                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                                        textColor: ThemeBackend.text
                                        activeTextColor: ThemeBackend.crust
                                        fontPixelSize: rootObj.s(11)
                                        onValueChanged: function(index) {
                                            TerminalAppearance.setOption(optionRow.modelData.key, optionRow.modelData.values[index]);
                                        }
                                        Connections {
                                            target: terminalTabRoot
                                            function onVisibleChanged() {
                                                if (!terminalTabRoot.visible && selector.isOpen) selector.closePopup();
                                            }
                                        }
                                    }
                                }

                                Loader {
                                    Layout.fillWidth: true
                                    active: optionRow.modelData.key === "background" && TerminalAppearance.settings.background === "blur"
                                    visible: active
                                    sourceComponent: SettingsRow {
                                        rootObj: terminalTabRoot.rootObj
                                        icon: "󰂚"
                                        settingId: "terminal_blur_size"
                                        title: I18n.t("guide.terminal.blur_size.title")
                                        description: I18n.t("guide.terminal.blur_size.desc")

                                        Draggable {
                                            id: blurSlider
                                            objectName: "terminal-blur-size"
                                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                            implicitWidth: rootObj.s(180)
                                            implicitHeight: rootObj.s(18)
                                            from: 1
                                            to: 20
                                            stepSize: 1
                                            defaultValue: TerminalAppearance.defaults.blurSize
                                            value: TerminalAppearance.settings.blurSize || TerminalAppearance.defaults.blurSize
                                            backgroundColor: ThemeBackend.surface0
                                            accentColor: ThemeBackend.mauve
                                            handleColor: ThemeBackend.text
                                            handleBorderColor: ThemeBackend.mantle
                                            onMoved: function(value) {
                                                if (!isDragging) TerminalAppearance.setOption("blurSize", Math.round(value));
                                            }
                                            onDragFinished: TerminalAppearance.setOption("blurSize", Math.round(dragPreview))
                                        }
                                    }
                                }
                            }
                        }

                    }
                ]
            }

            SectionCard {
                rootObj: terminalTabRoot.rootObj
                icon: "󰖯"
                title: "Scrollable Tiling"
                subSettings: [
                    SettingsRow {
                        rootObj: terminalTabRoot.rootObj
                        icon: "󰆍"
                        settingId: "terminal_window_layout"
                        title: I18n.t("guide.terminal.scrollable.window_layout")
                        description: I18n.t("guide.terminal.scrollable.description")
                        wrapText: true
                        Dropdown {
                            id: tilingSelector
                            objectName: "terminal-window-layout"
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(180)
                            implicitHeight: rootObj.s(32)
                            property var modes: ["hyprland", "niri", "hybrid"]
                            options: ["Hyprland", "niri", I18n.t("guide.terminal.scrollable.hybrid")]
                            currentIndex: Math.max(0, modes.indexOf(TerminalAppearance.scrollableSettings.windowLayout))
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface0
                            hoverColor: ThemeBackend.surface1
                            dropdownColor: ThemeBackend.surface0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            textColor: ThemeBackend.text
                            activeTextColor: ThemeBackend.crust
                            fontPixelSize: rootObj.s(11)
                            onValueChanged: function(index) {
                                TerminalAppearance.setScrollableOption("windowLayout", modes[index]);
                            }
                            Connections {
                                target: terminalTabRoot
                                function onVisibleChanged() {
                                    if (!terminalTabRoot.visible && tilingSelector.isOpen) tilingSelector.closePopup();
                                }
                            }
                        }
                    },
                    SettingsRow {
                        rootObj: terminalTabRoot.rootObj
                        icon: "󰀻"
                        settingId: "terminal_scrollable_apps"
                        title: I18n.t("guide.terminal.scrollable.apps")
                        description: I18n.t("guide.terminal.scrollable.apps_description")
                        wrapText: true
                        Toggle {
                            objectName: "terminal-scrollable-apps"
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: TerminalAppearance.scrollableSettings.appsScrollable
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface2
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(value) { TerminalAppearance.setScrollableOption("appsScrollable", value); }
                        }
                    }
                ]
            }

            InfiniteDesktopSection { rootObj: terminalTabRoot.rootObj; tabIndex: terminalTabRoot.tabIndex }

            FastfetchSection { rootObj: terminalTabRoot.rootObj; tabIndex: terminalTabRoot.tabIndex }

        }
    }
}
