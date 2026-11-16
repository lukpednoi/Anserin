import QtQuick
import "../../"
import "../"
import "../../reusables"

// Press-to-toggle tile in the same language as the Overview's Wi-Fi / Bluetooth buttons:
// icon + name, filled with the accent while on, and a water-wave wipe to the right when it flips.
Rectangle {
    id: t
    property bool checked: false
    property string icon: ""
    property string title: ""
    property color accent: ThemeBackend.mauve
    property real unit: 1             // UI scale of the hosting page
    signal toggled(bool value)

    implicitHeight: 54 * unit
    radius: Math.min(ThemeBackend.borderRadius, 14 * unit)
    property color idleColor: ma.containsMouse ? ThemeBackend.surface1 : Qt.darker(ThemeBackend.surface0, 1.04)
    Behavior on idleColor { ColorAnimation { duration: 150 } }
    color: checked ? accent : (tileGlass.active ? "transparent" : idleColor)
    GlassFill { id: tileGlass; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
    scale: ma.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
    opacity: enabled ? 1 : 0.5

    property real sweep: 1
    property color sweptFrom: "transparent"
    onCheckedChanged: {
        if (!visible) return;
        sweptFrom = checked ? idleColor : accent;
        sweepAnim.restart();
    }
    NumberAnimation { id: sweepAnim; target: t; property: "sweep"; from: 0; to: 1; duration: 560; easing.type: Easing.InOutCubic }
    WaveFill { radius: t.radius; oldColor: t.sweptFrom; sweep: t.sweep }

    Row {
        anchors.centerIn: parent
        spacing: 9 * t.unit
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: t.icon
            font.family: ThemeBackend.iconFont; font.pixelSize: 18 * t.unit
            color: t.checked ? ThemeBackend.crust : (ma.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, t.width - 58 * t.unit)
            elide: Text.ElideRight
            text: t.title
            font.family: ThemeBackend.fontFamily; font.pixelSize: 12 * t.unit; font.weight: Font.Bold
            color: t.checked ? ThemeBackend.crust : ThemeBackend.text
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { Sounds.playSfx("reusables/toggle/sfx.wav"); t.toggled(!t.checked); }
    }
}
