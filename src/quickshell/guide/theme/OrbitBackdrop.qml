import QtQuick
import "../../"

Rectangle {
    id: root
    objectName: "orbit-backdrop"
    property bool active: false
    property real unit: 1
    property real angle: 0
    readonly property color activeColor: Qt.lighter(ThemeBackend.sapphire, 1.15)
    color: ThemeBackend.base
    radius: ThemeBackend.borderRadius
    border.color: ThemeBackend.surface0
    border.width: 1
    clip: true

    NumberAnimation on angle {
        from: 0; to: Math.PI * 2; duration: 400000
        loops: Animation.Infinite
        running: root.active && root.visible
    }
    Rectangle {
        width: parent.width * .8; height: width; radius: width / 2
        x: (parent.width - width) / 2 + Math.cos(root.angle * 2) * 120 * root.unit
        y: (parent.height - height) / 2 + Math.sin(root.angle * 2) * 80 * root.unit
        color: root.activeColor
        opacity: .03
    }
    Rectangle {
        width: parent.width * .9; height: width; radius: width / 2
        x: (parent.width - width) / 2 - Math.sin(root.angle * 1.5) * 120 * root.unit
        y: (parent.height - height) / 2 - Math.cos(root.angle * 1.5) * 80 * root.unit
        color: Qt.darker(root.activeColor, 1.25)
        opacity: .02
    }
}
