import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"
import "../../media" as Media

Item {
    id: root
    objectName: "music-appearance-page"
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 1
    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1 : 0
    property real slideY: visible ? 0 : rootObj.s(10)
    transform: Translate { y: slideY }
    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    readonly property var musicSettings: Config.getSetting("theme", {}).music || ({})
    readonly property string selectedStyle: ["original", "m3", "m5"].indexOf(musicSettings.style) >= 0 ? musicSettings.style : "original"
    readonly property var styles: [{key:"original", name:"Classic"}, {key:"m3", name:"Split"}, {key:"m5", name:"Ambient"}]
    readonly property var covers: ["original", "record", "image"]
    readonly property string selectedCover: {
        let value = musicSettings[selectedStyle+"Cover"];
        return covers.indexOf(value) >= 0 ? value : (selectedStyle === "m3" ? "image" : "original");
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: rootObj.s(8)
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: content
            width: parent.width
            spacing: rootObj.s(16)
            Text {
                text: "Music"
                color: ThemeBackend.text
                font { family: ThemeBackend.fontFamily; pixelSize: rootObj.s(16); bold: true }
            }
            PreviewStrip {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: rootObj.s(12)
                carousel: rootObj.carouselPreviews === true
                focusIndex: ["original", "m3", "m5"].indexOf(root.selectedStyle)
                onCardChosen: index => {
                    if (root.styles[index].key !== root.selectedStyle) Config.setSetting("theme.music.style", root.styles[index].key);
                }
                Repeater {
                    model: root.styles
                    Rectangle {
                        id: card
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: previewBox.height + rootObj.s(48)
                        radius: ThemeBackend.clampedBorderRadius
                        color: cardMouse.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                        border.width: root.selectedStyle === modelData.key ? rootObj.s(2) : 1
                        border.color: root.selectedStyle === modelData.key ? ThemeBackend.mauve : ThemeBackend.surface1
                        property real popScale: 1
                        scale: popScale
                        Behavior on color { ColorAnimation { duration: 180 } }
                        SequentialAnimation {
                            id: pop
                            NumberAnimation { target: card; property: "popScale"; to: .97; duration: 100; easing.type: Easing.OutQuad }
                            NumberAnimation { target: card; property: "popScale"; to: 1; duration: 250; easing.type: Easing.OutBack }
                        }
                        Rectangle {
                            id: previewBox
                            x: rootObj.s(8); y: rootObj.s(8)
                            width: parent.width-rootObj.s(16)
                            height: width*565/625
                            color: ThemeBackend.mantle
                            radius: ThemeBackend.clampedBorderRadius
                            clip: true
                            Loader {
                                objectName: "music-style-preview-"+card.modelData.key
                                anchors.centerIn: parent
                                width: previewBox.width; height: previewBox.height
                                active: root.visible
                                enabled: false
                                sourceComponent: Component {
                                    Media.MusicStylePreview {
                                        appearance: card.modelData.key
                                        cover: root.musicSettings[card.modelData.key+"Cover"] || (card.modelData.key === "m3" ? "image" : "original")
                                    }
                                }
                            }
                        }
                        Text {
                            x: rootObj.s(12); y: previewBox.y+previewBox.height+rootObj.s(10)
                            text: card.modelData.name
                            color: root.selectedStyle === card.modelData.key ? ThemeBackend.mauve : ThemeBackend.text
                            font { family: ThemeBackend.fontFamily; pixelSize: rootObj.s(12); bold: true }
                        }
                        MouseArea {
                            id: cardMouse
                            objectName: "music-style-"+card.modelData.key
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pop.restart();
                                Sounds.playSfx("reusables/clickbutton/click.wav");
                                Config.setSetting("theme.music.style", card.modelData.key);
                            }
                        }
                    }
                }
            }
            SettingsRow {
                rootObj: root.rootObj
                title: "Cover"
                icon: "󰀥"
                visible: root.selectedStyle !== "m5"
                Switch {
                    id: coverStyleSwitch
                    objectName: "music-cover-style"
                    implicitWidth: rootObj.s(360)
                    implicitHeight: rootObj.s(32)
                    options: ["Disc", "Vinyl", "Image"]
                    currentIndex: Math.max(0, root.covers.indexOf(root.selectedCover))
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    textColor: ThemeBackend.subtext0
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onToggled: index => Config.setSetting("theme.music."+root.selectedStyle+"Cover", root.covers[index])
                    Connections {
                        target: root
                        function onSelectedCoverChanged() { coverStyleSwitch.currentIndex = Math.max(0, root.covers.indexOf(root.selectedCover)); }
                    }
                }
            }
            SettingsRow {
                rootObj: root.rootObj
                title: "Background"
                icon: "󰸉"
                visible: root.selectedStyle === "m3"
                Switch {
                    id: backgroundStyleSwitch
                    objectName: "music-m3-background"
                    implicitWidth: rootObj.s(240)
                    implicitHeight: rootObj.s(32)
                    options: ["Panels", "Plain"]
                    currentIndex: root.musicSettings.m3Background === "original" ? 1 : 0
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    textColor: ThemeBackend.subtext0
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onToggled: index => Config.setSetting("theme.music.m3Background", index === 1 ? "original" : "m3")
                    Connections {
                        target: root
                        function onMusicSettingsChanged() { backgroundStyleSwitch.currentIndex = root.musicSettings.m3Background === "original" ? 1 : 0; }
                    }
                }
            }
            SettingsRow {
                rootObj: root.rootObj
                title: "Visualizer"
                icon: "󰺢"
                visible: root.selectedStyle !== "m5"
                Toggle {
                    id: cavaToggle
                    objectName: "music-cover-cava-toggle"
                    checked: root.musicSettings.cavaEnabled === true
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.subtext0
                    onToggled: checked => Config.setSetting("theme.music.cavaEnabled", checked)
                    Connections {
                        target: root
                        function onMusicSettingsChanged() { cavaToggle.checked = root.musicSettings.cavaEnabled === true; }
                    }
                }
            }
            SettingsRow {
                rootObj: root.rootObj
                title: "Dynamic EQ"
                icon: "󰺢"
                Toggle {
                    id: dynamicToggle
                    objectName: "music-dynamic-eq"
                    checked: AudioProcessor.dynamicEq
                    enabled: AudioProcessor.ready
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.subtext0
                    onToggled: checked => Config.setSetting("theme.music.dynamicEq", checked)
                    Connections {
                        target: AudioProcessor
                        function onDynamicEqChanged() { dynamicToggle.checked = AudioProcessor.dynamicEq; }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: AudioProcessor.error !== ""
                text: AudioProcessor.error
                wrapMode: Text.WordWrap
                color: ThemeBackend.red
                font { family: ThemeBackend.fontFamily; pixelSize: rootObj.s(11) }
            }
        }
        ScrollBar.vertical: ScrollBar {}
    }
}
