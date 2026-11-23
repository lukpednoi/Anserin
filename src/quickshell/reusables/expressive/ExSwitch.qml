import QtQuick
import "../../"

// Expressive switch: the thumb is a small dot when off, grows when on and swells while pressed, sliding on a
// fast spatial spring; when on it turns into a cookie shape with the icon in it.
Item {
    id: root
    property bool checked: false
    property string iconOn: "\u{F012C}"     // check
    function s(v) { return Scaler.s(v); }
    implicitWidth: s(52); implicitHeight: s(32)
    ExSpring { id: pos; token: "spatialFast"; eps: 0.002; target: root.checked ? 1 : 0 }
    ExSpring { id: size; token: "spatialFast"; eps: 0.05; target: ma.pressed ? 28 : (root.checked ? 26 : 16) }
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? ThemeBackend.mauve : ThemeBackend.surface0
        border.width: root.s(2)
        border.color: root.checked ? ThemeBackend.mauve : ThemeBackend.overlay0
        Behavior on color { ColorAnimation { duration: ExMotion.fast } }
        Behavior on border.color { ColorAnimation { duration: ExMotion.fast } }
    }
    ExShape {
        id: thumb
        width: root.s(size.value); height: width
        x: root.s(16) + pos.value * root.s(20) - width / 2
        y: (root.height - height) / 2
        shape: root.checked ? "cookie" : "circle"
        lobes: 9
        spin: pos.value * 90
        color: root.checked ? ThemeBackend.crust : ThemeBackend.overlay1
        Text {
            anchors.centerIn: parent
            text: root.iconOn
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.s(14)
            color: ThemeBackend.mauve
            opacity: Math.max(0, Math.min(1, pos.value * 1.4 - 0.4))
        }
        Rectangle {          // press halo
            anchors.centerIn: parent
            width: root.s(40); height: width; radius: width / 2; z: -1
            color: root.checked ? ThemeBackend.mauve : ThemeBackend.text
            opacity: ma.pressed ? 0.14 : (ma.containsMouse ? 0.08 : 0)
            Behavior on opacity { NumberAnimation { duration: ExMotion.fast } }
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { Sounds.playSfx("reusables/switch/sfx.wav"); root.checked = !root.checked; }
    }
}
