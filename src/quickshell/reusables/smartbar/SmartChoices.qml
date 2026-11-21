import QtQuick
import "../../"
import "../"

// A named group of pills on a Smart bar row (the Smart bar's form of Edit panel's EditorChoices): the one in use
// fills with the theme's main colour; `enabledRow` dims the group and stops it.
Row {
    id: choices
    property string name: ""
    property var options: []              // [{ id, name }]
    property string current: ""
    property bool enabledRow: true
    signal chosen(string id)

    spacing: Scaler.s(5)
    opacity: enabledRow ? 1 : 0.4

    SmartLabel {
        visible: choices.name !== ""
        text: choices.name
        rightPadding: Scaler.s(2)
    }
    Repeater {
        model: choices.options
        SmartPill {
            required property var modelData
            label: modelData.name
            active: modelData.id === choices.current
            enabled: choices.enabledRow
            onClicked: choices.chosen(modelData.id)
        }
    }
}
