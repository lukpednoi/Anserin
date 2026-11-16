import QtQuick
import QtQuick.Shapes
import "../"

Item {
    id: root
    readonly property real unit: width / 224

    Rectangle {
        x: root.width * .87 - width / 2
        y: root.height * .1 - height / 2
        width: 22 * root.unit; height: width; radius: width / 2
        color: ThemeBackend.surface1
        border.color: ThemeBackend.overlay1
        border.width: root.unit
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer
        ShapePath {
            strokeColor: ThemeBackend.text
            strokeWidth: 5 * root.unit
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: root.width * .87; startY: root.height * .1
            PathLine { x: root.width * .87; y: root.height * .27 }
            PathLine { x: root.width * .73; y: root.height * .53 }
            PathLine { x: root.width * .65; y: root.height * .58 }
        }
    }
    Rectangle {
        x: root.width * .65 - width / 2
        y: root.height * .58 - height / 2
        width: 10 * root.unit; height: 23 * root.unit
        radius: 2 * root.unit
        rotation: 38
        color: ThemeBackend.text
    }
}
