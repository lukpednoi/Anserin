import QtQuick
import QtQuick.Layouts
import "../../../"
import "../../../reusables"
import ".."

// Theme → Pet (the Anserin interface only): which pet the shell shows (theme.pet, "cat" or "duck"), as two preview
// cards side by side; it is the picture of an empty notification box and of Reserved pages. With the Duck: Desktop
// pet (theme.petMode) lets it live on the desktop.
BoardPage {
    id: page
    readonly property string pet: Config.getSetting("theme.pet", "cat") === "duck" ? "duck" : "cat"
    readonly property string src: Caching.anserinDir ? ("file://" + Caching.anserinDir) : Qt.resolvedUrl("../../../..").toString().replace(/\/$/, "")
    readonly property var pets: [
        { key: "cat", name: "Cat", source: page.src + "/assets/pushy.gif" },
        { key: "duck", name: "Duck" }
    ]

    BoardCard {
        title: "Pet"; icon: "\u{F03E9}"; accent: page.accent
        PreviewStrip {
            // both pets side by side, whole and equal (not Music's sliding carousel)
            columns: 2
            columnSpacing: 12
            focusIndex: page.pet === "duck" ? 1 : 0
            onCardChosen: index => { if (page.pets[index].key !== page.pet) Config.setSetting("theme.pet", page.pets[index].key); }
            Repeater {
                model: page.pets
                Rectangle {
                    id: card
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: previewBox.height + 48
                    radius: ThemeBackend.clampedBorderRadius
                    color: cardMouse.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                    border.width: page.pet === modelData.key ? 2 : 1
                    border.color: page.pet === modelData.key ? ThemeBackend.mauve : ThemeBackend.surface1
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
                        height: width * 3 / 4
                        color: ThemeBackend.mantle
                        radius: ThemeBackend.clampedBorderRadius
                        clip: true
                        // the pet as the shell draws it; loaded only while the page is open
                        Loader {
                            anchors.fill: parent
                            anchors.margins: 12
                            active: page.visible
                            sourceComponent: card.modelData.key === "duck" ? duckPet : catPet
                        }
                        Component {
                            id: catPet
                            AnimatedImage { source: card.modelData.source; fillMode: Image.PreserveAspectFit; playing: page.visible; smooth: true }
                        }
                        // the duck in its colour, doing its things on the spot
                        Component {
                            id: duckPet
                            Item {
                                DuckActor {
                                    size: parent.height * 0.82
                                    inPlace: true
                                    random: true
                                    quackInRandom: false
                                    colour: PetState.colour
                                    labelFont: ThemeBackend.fontFamily
                                    px: parent.width / 2 - size * 0.08
                                    py: parent.height - 4
                                    floors: [{ x1: 0, x2: parent.width, y: parent.height - 4 }]
                                }
                            }
                        }
                    }
                    Text {
                        x: 12; y: previewBox.y + previewBox.height + 10
                        text: card.modelData.name
                        color: page.pet === card.modelData.key ? ThemeBackend.mauve : ThemeBackend.text
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
                            Config.setSetting("theme.pet", card.modelData.key);
                        }
                    }
                }
            }
        }
        BoardCell {
            kind: "toggle"; icon: "\u{F03E9}"; title: "Desktop pet"; hidden: page.pet !== "duck"
            value: Config.getSetting("theme.petMode", false) === true
            onPicked: (v) => PetState.setDesktop(v)
        }
    }
}
