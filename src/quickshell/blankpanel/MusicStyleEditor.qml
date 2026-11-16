import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

// Edit panel's side card for one Music style (Classic, Split or Ambient), with what Control's Theme → Music had for
// it: the cover (not Ambient), the background (Split), the visualizer (not Ambient), the Dynamic EQ (shared with the
// Default interface, as it sets the sound itself), the page it opens on, and the audio processor's error if any.
// Everything is saved at once into the Anserin interface's own settings (PanelLayout.setMusic, panel.music).
Rectangle {
    id: card

    property string styleId: "original"    // original, m3, m5
    signal finished()

    function s(v) { return Scaler.s(v); }

    readonly property var music: PanelLayout.music
    readonly property string styleName: ({ original: "Classic", m3: "Split", m5: "Ambient" })[styleId] || "Classic"
    readonly property string cover: {
        const v = music[styleId + "Cover"];
        return ["original", "record", "image"].indexOf(v) >= 0 ? v : (styleId === "m3" ? "image" : "original");
    }

    implicitHeight: content.implicitHeight + s(36)
    radius: ThemeBackend.clampedBorderRadius
    color: Qt.darker(ThemeBackend.surface0, 1.22)

    ColumnLayout {
        id: content
        x: card.s(18); y: card.s(18)
        width: card.width - card.s(36)
        spacing: card.s(14)

        Text {
            text: "Music · " + card.styleName
            font.family: ThemeBackend.fontFamily
            font.pixelSize: card.s(16)
            font.bold: true
            color: ThemeBackend.text
        }

        EditorChoices {
            Layout.fillWidth: true
            visible: card.styleId !== "m5"
            name: "Cover"
            current: card.cover
            options: [{ id: "original", name: "Disc" }, { id: "record", name: "Vinyl" }, { id: "image", name: "Image" }]
            onChosen: (id) => PanelLayout.setMusic(card.styleId + "Cover", id)
        }
        EditorChoices {
            Layout.fillWidth: true
            visible: card.styleId === "m3"
            name: "Background"
            current: card.music.m3Background === "original" ? "original" : "m3"
            options: [{ id: "m3", name: "Panels" }, { id: "original", name: "Plain" }]
            onChosen: (id) => PanelLayout.setMusic("m3Background", id)
        }
        EditorChoices {
            Layout.fillWidth: true
            visible: card.styleId !== "m5"
            name: "Visualizer"
            current: card.music.cavaEnabled === true ? "on" : "off"
            options: [{ id: "off", name: "Off" }, { id: "on", name: "On" }]
            onChosen: (id) => PanelLayout.setMusic("cavaEnabled", id === "on")
        }
        EditorChoices {
            Layout.fillWidth: true
            name: "Dynamic EQ"
            enabledRow: AudioProcessor.ready
            current: AudioProcessor.dynamicEq ? "on" : "off"
            options: [{ id: "off", name: "Off" }, { id: "on", name: "On" }]
            onChosen: (id) => PanelLayout.setMusic("dynamicEq", id === "on")
        }
        EditorChoices {
            Layout.fillWidth: true
            name: "Opens on"
            current: PanelLayout.firstPage(card.styleId)
            options: [{ id: "lyrics", name: "Lyrics" }, { id: "eq", name: "Equalizer" }]
            onChosen: (id) => PanelLayout.setMusic(card.styleId + "FirstPage", id)
        }
        Text {
            Layout.fillWidth: true
            visible: AudioProcessor.error !== ""
            text: AudioProcessor.error
            wrapMode: Text.WordWrap
            font.family: ThemeBackend.fontFamily
            font.pixelSize: card.s(11)
            color: ThemeBackend.red
        }

        ClickButton {
            Layout.alignment: Qt.AlignRight
            implicitHeight: card.s(34)
            horizontalPadding: card.s(16)
            cornerRadius: ThemeBackend.borderRadius
            buttonText: I18n.t("widgets.redactor.done")
            textFontSize: card.s(12)
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.crust
            onClicked: card.finished()
        }
    }
}
