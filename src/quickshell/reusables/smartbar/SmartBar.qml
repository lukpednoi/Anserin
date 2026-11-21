import QtQuick
import "../../"

// The Smart bar: the floating test-and-settings bar first drawn for the Smart Weather style, in the theme's colours.
// A dark see-through rounded bar with a hairline rim; its rows (SmartPill, SmartSlider, SmartLabel, SmartDivider in
// a Row) stand centred one above the other. Edit panel's style editors and the duck editor use it.
Rectangle {
    id: bar
    default property alias rows: column.data
    property real maxWidth: Scaler.s(1400)

    function s(v) { return Scaler.s(v); }

    implicitWidth: Math.min(maxWidth, column.implicitWidth + s(28))
    implicitHeight: column.implicitHeight + s(24)
    radius: s(18)
    color: Qt.alpha(ThemeBackend.crust, 0.86)
    border.width: 1
    border.color: Qt.alpha(ThemeBackend.text, 0.16)

    // clicks on the bar stay in it
    MouseArea { anchors.fill: parent }

    Column {
        id: column
        anchors.centerIn: parent
        spacing: bar.s(7)
    }
}
