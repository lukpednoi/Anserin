import QtQuick
import "../"
import "../reusables"

// A named row of choices for Edit panel's side cards (the Weather scene, the Music styles): the one in use fills
// with the theme's main colour; `enabledRow` dims the row and stops it.
Column {
    id: choices
    property string name: ""
    property var options: []              // [{ id, name }]
    property string current: ""
    property bool enabledRow: true
    signal chosen(string id)
    spacing: Scaler.s(6)
    opacity: enabledRow ? 1 : 0.4
    Text {
        text: choices.name
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Scaler.s(12)
        font.bold: true
        color: ThemeBackend.subtext0
    }
    Flow {
        width: choices.width
        spacing: Scaler.s(6)
        Repeater {
            model: choices.options
            ClickButton {
                required property var modelData
                readonly property bool picked: modelData.id === choices.current
                enabled: choices.enabledRow
                implicitHeight: Scaler.s(30)
                horizontalPadding: Scaler.s(12)
                cornerRadius: Scaler.s(15)
                buttonText: modelData.name
                textFontSize: Scaler.s(11.5)
                accentColor: picked ? ThemeBackend.mauve : ThemeBackend.surface0
                textColor: picked ? ThemeBackend.crust : ThemeBackend.text
                onClicked: choices.chosen(modelData.id)
            }
        }
    }
}
