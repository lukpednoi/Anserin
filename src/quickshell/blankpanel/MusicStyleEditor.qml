import QtQuick
import "../"
import "../reusables"

// Edit panel's Smart bar for one Music style (Classic, Split or Ambient), above the big preview, with what Control's
// Theme → Music had for it: the cover (not Ambient), the background (Split), the visualizer (not Ambient), the
// Dynamic EQ (shared with the Default interface, as it sets the sound itself), the page it opens on, and the audio
// processor's error if any. Everything is saved at once into the Anserin interface's own settings
// (PanelLayout.setMusic, panel.music).
SmartBar {
    id: card

    property string styleId: "original"    // original, m3, m5
    signal finished()

    Component.onCompleted: AudioProcessor.initialize()

    readonly property var music: PanelLayout.music
    readonly property string styleName: ({ original: "Classic", m3: "Split", m5: "Smart" })[styleId] || "Classic"
    readonly property string cover: {
        const v = music[styleId + "Cover"];
        return ["original", "record", "image"].indexOf(v) >= 0 ? v : (styleId === "m3" ? "image" : "original");
    }

    // the title and Done
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartLabel { strong: true; text: "Music · " + card.styleName; rightPadding: card.s(4) }
        SmartDivider {}
        SmartPill { label: I18n.t("widgets.redactor.done"); onClicked: card.finished() }
    }

    // Smart style tone (Mirror white vs Theme accent)
    Row {
        visible: card.styleId === "m5"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartChoices {
            name: "Tone"
            current: card.music.m5Tone === "theme" ? "theme" : "mirror"
            options: [{ id: "mirror", name: "Mirror" }, { id: "theme", name: "Theme" }]
            onChosen: (id) => PanelLayout.setMusic("m5Tone", id)
        }
    }

    // the look
    Row {
        visible: card.styleId !== "m5"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartChoices {
            name: "Cover"
            current: card.cover
            options: [{ id: "original", name: "Disc" }, { id: "record", name: "Vinyl" }, { id: "image", name: "Image" }]
            onChosen: (id) => PanelLayout.setMusic(card.styleId + "Cover", id)
        }
        SmartDivider { visible: card.styleId === "m3" }
        SmartChoices {
            visible: card.styleId === "m3"
            name: "Background"
            current: card.music.m3Background === "original" ? "original" : "m3"
            options: [{ id: "m3", name: "Panels" }, { id: "original", name: "Plain" }]
            onChosen: (id) => PanelLayout.setMusic("m3Background", id)
        }
        SmartDivider {}
        SmartChoices {
            name: "Visualizer"
            current: card.music.cavaEnabled === true ? "on" : "off"
            options: [{ id: "off", name: "Off" }, { id: "on", name: "On" }]
            onChosen: (id) => PanelLayout.setMusic("cavaEnabled", id === "on")
        }
    }

    // the sound and the first page
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartChoices {
            name: "Dynamic EQ"
            enabledRow: AudioProcessor.ready
            current: AudioProcessor.dynamicEq ? "on" : "off"
            options: [{ id: "off", name: "Off" }, { id: "on", name: "On" }]
            onChosen: (id) => PanelLayout.setMusic("dynamicEq", id === "on")
        }
        SmartDivider {}
        SmartChoices {
            name: "Opens on"
            current: PanelLayout.firstPage(card.styleId)
            options: [{ id: "lyrics", name: "Lyrics" }, { id: "eq", name: "Equalizer" }]
            onChosen: (id) => PanelLayout.setMusic(card.styleId + "FirstPage", id)
        }
    }

    Text {
        visible: AudioProcessor.error !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, card.s(520))
        text: AudioProcessor.error
        wrapMode: Text.WordWrap
        font.family: ThemeBackend.fontFamily
        font.pixelSize: card.s(10.5)
        color: ThemeBackend.red
    }
}
