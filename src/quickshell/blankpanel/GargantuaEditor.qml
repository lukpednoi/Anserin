import QtQuick
import "../"
import "../reusables"

// Edit panel's Smart bar for the Gargantua Network style, above the big preview: the black hole's colour (Copper or
// Champagne), its tilt (flat, or tipped 6.6°) and its drawing (Unified, or the older Classic one). Each is saved at
// once (panel.gargantua.colour, .tilt, .unified).
SmartBar {
    id: card
    signal finished()

    readonly property var look: Config.getSetting("panel.gargantua", {}) || {}
    function save(key, value) { Config.setSetting("panel.gargantua." + key, value); }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartLabel { strong: true; text: "Gargantua"; rightPadding: card.s(4) }
        SmartDivider {}
        SmartChoices {
            name: "Colour"
            current: card.look.colour === "champagne" ? "champagne" : "copper"
            options: [{ id: "copper", name: "Copper" }, { id: "champagne", name: "Champagne" }]
            onChosen: (id) => card.save("colour", id)
        }
        SmartDivider {}
        SmartChoices {
            name: "Tilt"
            current: card.look.tilt === true ? "on" : "off"
            options: [{ id: "off", name: "0°" }, { id: "on", name: "6.6°" }]
            onChosen: (id) => card.save("tilt", id === "on")
        }
        SmartDivider {}
        SmartChoices {
            name: "Black hole"
            current: card.look.unified === false ? "classic" : "unified"
            options: [{ id: "unified", name: "Unified" }, { id: "classic", name: "Classic" }]
            onChosen: (id) => card.save("unified", id === "unified")
        }
        SmartDivider {}
        SmartPill { label: I18n.t("widgets.redactor.done"); onClicked: card.finished() }
    }
}
