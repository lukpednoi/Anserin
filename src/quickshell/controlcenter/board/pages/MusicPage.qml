import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import "../../../media" as Media
import ".."

// Theme → Music as a board, doing what guide/theme/MusicTab.qml does: the player style (the real page's preview
// carousel, a little smaller),
// the cover of that style (not for M5), M3's background, Cava (not for M5) and Dynamic EQ (AudioProcessor).
BoardPage {
    id: page
    readonly property var music: Config.getSetting("theme", {}).music || ({})
    readonly property string style: ["original", "m3", "m5"].indexOf(music.style) >= 0 ? music.style : "original"
    readonly property var covers: ["original", "record", "image"]
    readonly property var styles: [{ key: "original", name: "Classic" }, { key: "m3", name: "Split" }, { key: "m5", name: "Ambient" }]
    readonly property string cover: {
        const v = music[style + "Cover"];
        return covers.indexOf(v) >= 0 ? v : (style === "m3" ? "image" : "original");
    }

    BoardCard {
        title: "Music"; icon: "󰎈"; accent: page.accent
        // the real Music page's carousel and cards (guide/theme/MusicTab.qml), a little smaller
        PreviewStrip {
            columns: 3
            columnSpacing: 12
            carousel: true
            cardWidth: 240
            edgeColor: Qt.darker(ThemeBackend.surface0, 1.04)
            focusIndex: ["original", "m3", "m5"].indexOf(page.style)
            onCardChosen: index => { if (page.styles[index].key !== page.style) Config.setSetting("theme.music.style", page.styles[index].key); }
            Repeater {
                model: page.styles
                Rectangle {
                    id: card
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: previewBox.height + 48
                    radius: ThemeBackend.clampedBorderRadius
                    color: cardMouse.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                    border.width: page.style === modelData.key ? 2 : 1
                    border.color: page.style === modelData.key ? ThemeBackend.mauve : ThemeBackend.surface1
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
                        x: 8; y: 8
                        width: parent.width - 16
                        height: width * 565 / 625
                        color: ThemeBackend.mantle
                        radius: ThemeBackend.clampedBorderRadius
                        clip: true
                        Loader {
                            anchors.centerIn: parent
                            width: previewBox.width; height: previewBox.height
                            active: page.visible
                            enabled: false
                            sourceComponent: Component {
                                Media.MusicStylePreview {
                                    appearance: card.modelData.key
                                    cover: page.music[card.modelData.key + "Cover"] || (card.modelData.key === "m3" ? "image" : "original")
                                }
                            }
                        }
                    }
                    Text {
                        x: 12; y: previewBox.y + previewBox.height + 10
                        text: card.modelData.name
                        color: page.style === card.modelData.key ? ThemeBackend.mauve : ThemeBackend.text
                        font { family: ThemeBackend.fontFamily; pixelSize: 12; bold: true }
                    }
                    MouseArea {
                        id: cardMouse
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
        BoardCell {
            kind: "seg"; icon: "󰀥"; title: "Cover"; hidden: page.style === "m5"
            options: ["Disc", "Vinyl", "Image"]; values: page.covers
            value: page.cover
            onPicked: (v) => Config.setSetting("theme.music." + page.style + "Cover", v)
        }
        BoardCell {
            kind: "seg"; icon: "󰸉"; title: "Background"; hidden: page.style !== "m3"
            options: ["Panels", "Plain"]; values: ["m3", "original"]
            value: page.music.m3Background === "original" ? "original" : "m3"
            onPicked: (v) => Config.setSetting("theme.music.m3Background", v)
        }
        BoardCell {
            kind: "toggle"; icon: "󰺢"; title: "Visualizer"; hidden: page.style === "m5"
            value: page.music.cavaEnabled === true
            onPicked: (v) => Config.setSetting("theme.music.cavaEnabled", v)
        }
        BoardCell {
            kind: "toggle"; icon: "󰺢"; title: "Dynamic EQ"
            value: AudioProcessor.dynamicEq
            available: AudioProcessor.ready
            onPicked: (v) => Config.setSetting("theme.music.dynamicEq", v)
        }
        BoardCell {
            kind: "info"; icon: "󰀪"; title: "Audio"; hidden: AudioProcessor.error === ""
            info: AudioProcessor.error
        }
    }
}
