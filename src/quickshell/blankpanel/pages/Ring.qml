import QtQuick
import QtQuick.Shapes
import "../../"

// A round level ring with a soft track.
Shape {
    id: ring
    property real value: 0          // 0..1
    property real thickness: 12
    property color color: ThemeBackend.mauve
    property color track: Qt.alpha(ThemeBackend.text, 0.07)
    property bool smooth: true      // off while a page drives the value itself (its opening)
    property real shown: value
    Behavior on shown { enabled: ring.smooth; NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
    readonly property real rad: Math.min(width, height) / 2 - thickness / 2
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: ring.track; strokeWidth: ring.thickness; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.rad; radiusY: ring.rad; startAngle: 0; sweepAngle: 360 }
    }
    ShapePath {
        strokeColor: ring.color; strokeWidth: ring.thickness; fillColor: "transparent"; capStyle: ShapePath.RoundCap
        PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: ring.rad; radiusY: ring.rad; startAngle: -90
                       sweepAngle: 360 * Math.max(0.002, Math.min(1, ring.shown)) }
    }
}
