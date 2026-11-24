import QtQuick
import "../"
import "../reusables"

// Edit panel's Smart bar for the Smart System Monitor style (panel.smartSystem.tone: "mirror" | "theme").
SmartBar {
    id: card
    signal finished()

    readonly property string tone: Config.getSetting("panel.smartSystem.tone", "mirror") === "theme" ? "theme" : "mirror"

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartLabel { strong: true; text: "Smart system"; rightPadding: card.s(4) }
        SmartDivider {}
        SmartLabel { text: "Tone" }
        SmartChoices {
            current: card.tone
            options: [{ id: "mirror", name: "Mirror" }, { id: "theme", name: "Theme" }]
            onChosen: (id) => Config.setSetting("panel.smartSystem.tone", id)
        }
        SmartDivider {}
        SmartPill { label: I18n.t("widgets.redactor.done"); onClicked: card.finished() }
    }
}
