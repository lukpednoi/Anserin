import QtQuick
import "../"
import "../reusables"

Item {
    id: root
    readonly property Item glassBackdrop: edgeGlass
    property string edge: "top"
    property color color: "black"
    property real cornerRadius: 12
    readonly property bool vertical: edge === "left" || edge === "right"

    Item {
        id: oriented
        anchors.centerIn: parent
        width: root.vertical ? root.height : root.width
        height: root.vertical ? root.width : root.height
        rotation: root.edge === "left" ? 270 : (root.edge === "right" ? 90 : (root.edge === "bottom" ? 180 : 0))
        readonly property real radius: Math.max(0, Math.min(root.cornerRadius, height / 2, width / 2))

        Rectangle {
            id: edgeBody
            objectName: "edge-body"
            anchors.fill: parent
            color: edgeGlass.active ? "transparent" : root.color
            WallpaperBlur {
                id: edgeGlass
                anchors.fill: parent
                topLeftRadius: 0
                topRightRadius: 0
                bottomLeftRadius: oriented.radius
                bottomRightRadius: oriented.radius
            }
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: oriented.radius
            bottomRightRadius: oriented.radius
        }

        GlassFillets {
            card: edgeBody
            filletRadius: oriented.radius
            filletDir: Qt.vector2d(0, -1)
        }

        Repeater {
            model: 2
            ShaderEffect {
                visible: !edgeGlass.active
                objectName: index === 0 ? "edge-start-join" : "edge-end-join"
                x: index === 0 ? -width : oriented.width
                width: oriented.radius
                height: oriented.radius
                property vector2d itemSize: Qt.vector2d(width, height)
                property real cornerIndex: index === 0 ? 1 : 0
                property color color: root.color
                fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
            }
        }
    }
}
