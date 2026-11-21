import QtQuick
import "../../"
import QtQuick.Shapes
import "."

/**
 * Shared Hub source glyph: crisp vector Router SVG, phone hotspot, or Bluetooth icon.
 */
Item {
    id: glyph

    property string sourceKind: "router" // "router" | "phone" | "bt"
    property string btIconGlyph: "󰂯"
    property color accentColor: ThemeBackend.mauve
    property int glyphSize: 28
    readonly property real k: glyphSize / 28.0

    implicitWidth: glyphSize
    implicitHeight: glyphSize

    Shape {
        visible: glyph.sourceKind === "router"
        anchors.centerIn: parent
        width: glyph.glyphSize
        height: glyph.glyphSize
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: glyph.accentColor
            strokeWidth: Math.max(1.6, 2.1 * glyph.k)
            capStyle: ShapePath.RoundCap
            startX: 9 * glyph.k; startY: 14 * glyph.k
            PathLine { x: 9 * glyph.k; y: 5 * glyph.k }
            PathMove { x: 19 * glyph.k; y: 14 * glyph.k }
            PathLine { x: 19 * glyph.k; y: 5 * glyph.k }
        }
        ShapePath {
            fillColor: Qt.alpha(glyph.accentColor, 0.14)
            strokeColor: glyph.accentColor
            strokeWidth: Math.max(1.6, 2.1 * glyph.k)
            joinStyle: ShapePath.RoundJoin
            startX: 6.5 * glyph.k; startY: 14 * glyph.k
            PathLine { x: 21.5 * glyph.k; y: 14 * glyph.k }
            PathArc { x: 24.5 * glyph.k; y: 17 * glyph.k; radiusX: 3 * glyph.k; radiusY: 3 * glyph.k }
            PathLine { x: 24.5 * glyph.k; y: 20.5 * glyph.k }
            PathArc { x: 21.5 * glyph.k; y: 23.5 * glyph.k; radiusX: 3 * glyph.k; radiusY: 3 * glyph.k }
            PathLine { x: 6.5 * glyph.k; y: 23.5 * glyph.k }
            PathArc { x: 3.5 * glyph.k; y: 20.5 * glyph.k; radiusX: 3 * glyph.k; radiusY: 3 * glyph.k }
            PathLine { x: 3.5 * glyph.k; y: 17 * glyph.k }
            PathArc { x: 6.5 * glyph.k; y: 14 * glyph.k; radiusX: 3 * glyph.k; radiusY: 3 * glyph.k }
        }
        Rectangle {
            x: 15.5 * glyph.k; y: 17.5 * glyph.k
            width: 2.3 * glyph.k; height: width; radius: width / 2
            color: glyph.accentColor
        }
        Rectangle {
            x: 19.4 * glyph.k; y: 17.5 * glyph.k
            width: 2.3 * glyph.k; height: width; radius: width / 2
            color: glyph.accentColor
        }
    }

    Text {
        visible: glyph.sourceKind !== "router"
        anchors.centerIn: parent
        text: glyph.sourceKind === "phone" ? "󰄜" : glyph.btIconGlyph
        font.family: ThemeBackend.iconFont
        font.pixelSize: Math.round(glyph.glyphSize * 0.88)
        color: glyph.accentColor
    }
}
