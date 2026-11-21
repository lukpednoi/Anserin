import QtQuick
import QtQuick.Shapes
import "../../"
import "../"

// The Modern frame: a band `inset` wide around the screen with rounded inner corners, glass over the wallpaper
// when Liquid Glass is on, else the theme's base colour. Drawn by ScreenBorder on its own layer, and on top of
// full-screen overlays (the widget Redactor) so the frame stays still like the screen's own edge.
Item {
    id: root

    property real inset: ScreenEdges.thickness
    readonly property real rounding: Math.max(0, Math.min(ScreenEdges.rounding, (width - inset * 2) / 2, (height - inset * 2) / 2))

    WallpaperBlur {
        id: glass
        anchors.fill: parent
        radius: root.rounding
        inverted: true
        boxRect: Qt.rect(root.inset, root.inset, width - root.inset * 2, height - root.inset * 2)
        bezelSize: root.inset
    }

    Shape {
        anchors.fill: parent
        visible: !glass.active
        ShapePath {
            fillColor: ThemeBackend.base
            strokeWidth: -1
            fillRule: ShapePath.OddEvenFill
            startX: 0; startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }
            PathMove { x: root.inset + root.rounding; y: root.inset }
            PathLine { x: root.width - root.inset - root.rounding; y: root.inset }
            PathArc { x: root.width - root.inset; y: root.inset + root.rounding; radiusX: root.rounding; radiusY: root.rounding }
            PathLine { x: root.width - root.inset; y: root.height - root.inset - root.rounding }
            PathArc { x: root.width - root.inset - root.rounding; y: root.height - root.inset; radiusX: root.rounding; radiusY: root.rounding }
            PathLine { x: root.inset + root.rounding; y: root.height - root.inset }
            PathArc { x: root.inset; y: root.height - root.inset - root.rounding; radiusX: root.rounding; radiusY: root.rounding }
            PathLine { x: root.inset; y: root.inset + root.rounding }
            PathArc { x: root.inset + root.rounding; y: root.inset; radiusX: root.rounding; radiusY: root.rounding }
        }
    }
}
