import QtQuick
import QtQuick.Layouts
import ".."
import "../../../"

// 4B. THEME -> PET (real AnimatedImage Cat + real live DuckActor in PetState.colour + PetState.setDesktop)
Column {
    id: page
    property var app: null
    spacing: 11

    readonly property int petKind: Config.getSetting("theme.pet", "cat") === "duck" ? 1 : 0
    readonly property bool petEnabled: Config.getSetting("theme.petMode", false) === true

    component SCard: SmartCard {
        cornerRadius: page.app.cornerRadius; darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cCard; accent: page.app.cAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SToggle: SmartGeoToggleTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }

    SCard {
        title: "Pet"; icon: "\u{F03E9}"; statusText: page.petKind === 1 ? "DUCK" : "CAT"
        RowLayout {
            width: parent.width; spacing: 10
            Repeater {
                model: [{ key: 0, id: "cat", name: "Cat" }, { key: 1, id: "duck", name: "Duck" }]
                Rectangle {
                    id: pCard; required property var modelData
                    readonly property bool on: page.petKind === modelData.key
                    Layout.fillWidth: true; Layout.preferredWidth: 1; height: 176; radius: 16; color: page.app.cTile
                    border.width: on ? 1.8 : 1; border.color: on ? page.app.cAccent : (page.app.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08))
                    SpringVal { id: hopY; target: 0.0; stiffness: 320; damping: 0.36; eps: 0.2 }

                    Rectangle {
                        id: previewBox
                        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 8
                        height: 126; radius: 12; color: ThemeBackend.mantle; clip: true
                        transform: Translate { y: hopY.value }

                        Loader {
                            anchors.fill: parent; anchors.margins: 8
                            active: page.visible
                            sourceComponent: pCard.modelData.key === 1 ? duckPetComp : catPetComp
                        }
                        Component {
                            id: catPetComp
                            AnimatedImage {
                                source: page.app.repoUrl + "/src/assets/pushy.gif"
                                fillMode: Image.PreserveAspectFit
                                playing: page.visible
                                smooth: true
                            }
                        }
                        Component {
                            id: duckPetComp
                            Item {
                                DuckActor {
                                    size: parent.height * 0.84
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
                        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                        text: pCard.modelData.name
                        font.family: page.app.uiFont; font.pixelSize: 12; font.bold: pCard.on
                        color: pCard.on ? page.app.cAccent : page.app.cText
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pCard.modelData.id !== Config.getSetting("theme.pet", "cat"))
                                Config.setSetting("theme.pet", pCard.modelData.id);
                            hopY.kick(-220);
                            page.app.sfx.playQuick();
                        }
                    }
                }
            }
        }
        SToggle {
            visible: page.petKind === 1; width: parent.width
            icon: "\u{F03E9}"; title: "Desktop pet"; geoShape: "cookie6"
            checked: page.petEnabled
            onToggled: (v) => { PetState.setDesktop(v); page.app.sfx.playToggle(v); }
        }
    }
}
