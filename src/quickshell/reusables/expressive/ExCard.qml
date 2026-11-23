import QtQuick
import "../../"

// A surface that rises a little under the pointer and dips when pressed (spatial springs on scale), with an
// optional morphing icon badge. Content goes inside (default property).
Item {
    id: root
    default property alias content: inner.data
    property bool clickable: true
    property color color: ThemeBackend.surface0
    property real radius: Scaler.s(24)
    readonly property alias hovered: ma.containsMouse
    readonly property alias pressed: ma.pressed
    signal clicked()
    ExSpring { id: sc; token: "spatialFast"; eps: 0.0005; target: !root.clickable ? 1 : (ma.pressed ? 0.965 : (ma.containsMouse ? 1.015 : 1)) }
    scale: sc.value
    Rectangle { id: bg; anchors.fill: parent; radius: root.radius; color: root.color }
    ExStateLayer { anchors.fill: parent; radius: root.radius; color: ThemeBackend.text; hovered: root.clickable && ma.containsMouse; pressed: root.clickable && ma.pressed }
    Item { id: inner; anchors.fill: parent }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: root.clickable
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: -1
        onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); root.clicked(); }
    }
}
