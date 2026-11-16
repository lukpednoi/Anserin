import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import "../../"
import "../../reusables"
import "../theme" as ThemeUi
import "../../reusables/guide"

Item {
    id: lockscreenTab
    objectName: "theme-lockscreen-page"
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 1
    readonly property var animationStyles: ["default", "padlock", "portal", "portal-large"]
    readonly property string animationStyle: Config.getSetting("lockscreen.animation", "padlock")
    // Dashboard or Simple, each with its own animations and widgets (see LockscreenPage)
    readonly property bool simple: Config.getSetting("lockscreen.style", "dashboard") === "simple"
    readonly property string customBackground: Config.getSetting("lockscreen.backgroundMode", "follow") === "custom" ? Config.getSetting("lockscreen.customBackground", "") : ""
    readonly property string desktopBackground: {
        let path = Wallpaper.getWallpaperPath(Quickshell.cursorScreen ? Quickshell.cursorScreen.name : "");
        return !path || /\.(mp4|mkv|mov|webm)$/i.test(path) || path.indexOf("000_") !== -1
            ? Caching.getCacheDir("wallpaper") + "/current_wallpaper.png" : path;
    }
    readonly property string backgroundPath: customBackground || desktopBackground

    function selectBackground(filePath) {
        if (filePath !== "" && (!filePath.startsWith("/") || !/\.(png|jpg|jpeg|webp|svg|gif|bmp|avif|mp4|mkv|mov|webm)$/i.test(filePath))) return;
        Config.updateJsonBulk({
            "lockscreen.backgroundMode": filePath ? "custom" : "follow",
            "lockscreen.customBackground": filePath
        });
    }

    // Select Wallpaper itself, picking for the lock screen (the desktop and the theme stay as they are)
    function openBackgroundPicker() { Wallpaper.openForLock(); }

    function openWidgetEditor(context, monitorName) {
        Quickshell.execDetached(["quickshell", "-p", Caching.mainQml, "ipc", "call", "lock-redactor", "open", monitorName]);
        if (typeof rootObj.closePopup === "function") rootObj.closePopup();
    }

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex

    Flickable {
        anchors.fill: parent
        anchors.margins: lockscreenTab.rootObj.s(8)
        contentWidth: width
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: lockscreenTab.rootObj.s(12)

            SettingsRow {
                rootObj: lockscreenTab.rootObj
                settingId: "lockscreen_background"
                title: I18n.t("guide.display.lockscreen.background")
                searchKeywords: "lockscreen lock screen background wallpaper image video select"
                horizontalPadding: 0
                verticalPadding: 0
                customLeftContent: Component {
                    Item {
                        implicitHeight: lockscreenTab.rootObj.s(220)

                        Rectangle {
                            id: previewMask
                            anchors.fill: parent
                            radius: ThemeBackend.borderRadius
                            color: "black"
                            visible: false
                            layer.enabled: true
                        }

                        Item {
                            id: previewContent
                            anchors.fill: parent
                            Rectangle {
                                anchors.fill: parent
                                color: ThemeBackend.surface0
                            }
                            WallpaperMedia {
                                id: previewMedia
                                anchors.fill: parent
                                path: lockscreenTab.backgroundPath
                                active: lockscreenTab.visible && lockscreenTab.rootObj.visible
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: lockscreenTab.rootObj.s(64)
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "transparent" }
                                    GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.8) }
                                }
                            }
                        }

                        ShaderEffectSource {
                            id: previewTexture
                            anchors.fill: parent
                            sourceItem: previewContent
                            hideSource: true
                            visible: false
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: previewTexture
                            maskEnabled: true
                            maskSource: previewMask
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: previewMedia.failed
                            text: I18n.t("guide.display.lockscreen.background_error")
                            color: ThemeBackend.text
                            font.family: ThemeBackend.fontFamily
                        }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: lockscreenTab.rootObj.s(12)
                            spacing: lockscreenTab.rootObj.s(12)
                            ClickButton {
                                Layout.preferredHeight: lockscreenTab.rootObj.s(32)
                                cornerRadius: ThemeBackend.borderRadius
                                horizontalPadding: lockscreenTab.rootObj.s(14)
                                buttonIcon: "󰸉"
                                iconFontSize: lockscreenTab.rootObj.s(15)
                                buttonText: "Select"
                                textFontSize: lockscreenTab.rootObj.s(11)
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.base
                                onClicked: lockscreenTab.openBackgroundPicker()
                            }
                            ClickButton {
                                Layout.preferredHeight: lockscreenTab.rootObj.s(32)
                                cornerRadius: ThemeBackend.borderRadius
                                horizontalPadding: lockscreenTab.rootObj.s(14)
                                buttonIcon: "󰑓"
                                buttonText: I18n.t("guide.display.lockscreen.reset")
                                textFontSize: lockscreenTab.rootObj.s(11)
                                accentColor: ThemeBackend.surface1
                                textColor: ThemeBackend.text
                                onClicked: lockscreenTab.selectBackground("")
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: lockscreenTab.rootObj
                settingId: "lockscreen_animation"
                icon: "󰌾"
                title: I18n.t("guide.display.lockscreen.animation")
                description: I18n.t("guide.display.lockscreen.animation_desc")
                searchKeywords: "lockscreen lock screen dashboard animation default padlock portal"

                Dropdown {
                    visible: !lockscreenTab.simple
                    Layout.preferredWidth: lockscreenTab.rootObj.s(220)
                    options: [I18n.t("guide.display.lockscreen.default"), I18n.t("guide.display.lockscreen.padlock"), I18n.t("guide.display.lockscreen.portal"), I18n.t("guide.display.lockscreen.portal_large")]
                    currentIndex: lockscreenTab.animationStyles.includes(lockscreenTab.animationStyle) ? lockscreenTab.animationStyles.indexOf(lockscreenTab.animationStyle) : 1
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    onSelected: index => {
                        if (index >= 0 && index < lockscreenTab.animationStyles.length) Config.setSetting("lockscreen.animation", lockscreenTab.animationStyles[index]);
                    }
                }
                Dropdown {
                    visible: lockscreenTab.simple
                    Layout.preferredWidth: lockscreenTab.rootObj.s(220)
                    options: [I18n.t("guide.display.lockscreen.default")]
                    currentIndex: 0
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                }
            }

            SettingsRow {
                rootObj: lockscreenTab.rootObj
                settingId: "lockscreen_style"
                icon: "󰍹"
                title: "Style"
                description: "Dashboard: the card with widgets. Simple: the clock, the padlock, your name and the password. Each keeps its own animation and widgets."
                searchKeywords: "lockscreen lock screen style dashboard simple"

                Dropdown {
                    Layout.preferredWidth: lockscreenTab.rootObj.s(220)
                    options: ["Dashboard", "Simple"]
                    currentIndex: lockscreenTab.simple ? 1 : 0
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    onSelected: index => Config.setSetting("lockscreen.style", index === 1 ? "simple" : "dashboard")
                }
            }

            Repeater {
                model: Quickshell.screens
                delegate: SettingsRow {
                    id: widgetLayoutRow
                    required property var modelData
                    rootObj: lockscreenTab.rootObj
                    settingId: "lockscreen_widgets_" + modelData.name
                    icon: "󰋩"
                    title: I18n.t("guide.display.lockscreen.screen_widgets")
                        + (Quickshell.screens.length > 1 ? " · " + modelData.name : "")
                    description: I18n.t("guide.display.lockscreen.widgets_desc")
                    searchKeywords: "lockscreen lock screen dashboard widgets layout edit desktop decorate"

                    ClickButton {
                        Layout.preferredHeight: lockscreenTab.rootObj.s(32)
                        cornerRadius: ThemeBackend.borderRadius
                        horizontalPadding: lockscreenTab.rootObj.s(14)
                        buttonIcon: "󰏫"
                        buttonText: I18n.t("guide.display.lockscreen.edit_widgets")
                        textFontSize: lockscreenTab.rootObj.s(11)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.base
                        onClicked: lockscreenTab.openWidgetEditor("lockscreen", widgetLayoutRow.modelData.name)
                    }
                }
            }
            ThemeUi.SddmStyles { rootObj: lockscreenTab.rootObj }
        }
    }
}
