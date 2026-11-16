import QtQuick
import QtQuick.Shapes
import "../"

// The duck on a pond (the pet's picture for Reserved pages): it floats, dips its head under with its tail up and
// feet paddling, then rights itself with a splash. In the duck's colour (PetState). Runs only while visible.
// Everything follows t (seconds, looping every `loop`). Drawing space 400x300, scaled to fit.
Item {
    id: root
    property bool playing: visible
    property string colour: PetState.colour
    readonly property real waterY: 246
    readonly property real loop: 6.23
    property real t: 0

    // the timeline (seconds): float 0-2, tip 2-2.65, paddle 2.65-4.03, back up 4.03-4.63, settle 4.63-5.01,
    // splash and ripple from 4.63, float again to the end
    function cubic(u) { return u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; }
    function outBack(u) { const c = 1.70158; return 1 + (c + 1) * Math.pow(u - 1, 3) + c * Math.pow(u - 1, 2); }
    function seg(a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))); }
    readonly property real bob: 1 - Math.cos(2 * Math.PI * t / (loop / 3))
    readonly property real paddle: t >= 2.65 && t < 4.03 ? Math.sin(2 * Math.PI * (t - 2.65) / 0.46) : 0
    readonly property real angle: t < 2 ? 0
        : t < 2.65 ? 98 * cubic(seg(2, 2.65))
        : t < 4.03 ? 98 + 4 * paddle
        : t < 4.63 ? 98 - 103 * cubic(seg(4.03, 4.63))
        : t < 5.01 ? -5 + 5 * outBack(seg(4.63, 5.01))
        : 0
    readonly property real feet: 22 * paddle
    readonly property real drops: t < 4.63 ? 0 : t < 4.75 ? seg(4.63, 4.75) : 1 - Math.pow(seg(4.75, 5.4), 2)
    readonly property real ripple: t >= 4.63 && t < 5.73 ? 1 - Math.pow(1 - seg(4.63, 5.73), 3) : 0

    NumberAnimation on t {
        running: root.playing
        loops: Animation.Infinite
        from: 0; to: root.loop; duration: root.loop * 1000
    }

    Item {
        width: 400
        height: 300
        scale: Math.min(root.width / 400, root.height / 300)
        transformOrigin: Item.TopLeft
        x: (root.width - 400 * scale) / 2
        y: (root.height - 300 * scale) / 2

        // everything sits 22 left, so the pond, wider to the right (past the head when it dips), stays centred
        Item {
        anchors.fill: parent
        transform: Translate { x: -22 }

        // the pond, seen a little from above
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1; strokeColor: "transparent"
                fillGradient: RadialGradient { centerX: 212; centerY: 240; centerRadius: 185; focalX: 212; focalY: 240; focalRadius: 0
                    GradientStop { position: 0; color: "#b9e2f5" } GradientStop { position: 0.6; color: "#8cc6e6" } GradientStop { position: 1; color: "#5e9fca" } }
                PathSvg { path: "M 30 252 C 30 224 108 212 212 212 C 316 212 394 224 394 252 C 394 278 316 292 212 292 C 108 292 30 278 30 252 Z" }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: "#80ffffff"; strokeWidth: 1.4; capStyle: ShapePath.RoundCap
                PathSvg { path: "M 58 238 C 90 224 150 218 200 218 M 270 222 C 316 226 356 232 374 240 M 90 272 Q 130 282 176 284" }
            }
        }
        // the ring round the duck, and the one that spreads after the splash
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeColor: "#b3ffffff"; strokeWidth: 1.6
                PathSvg { path: "M 98 248 C 98 238 144 232 200 232 C 256 232 302 238 302 248 C 302 258 256 264 200 264 C 144 264 98 258 98 248 Z" }
            }
        }
        Shape {
            anchors.fill: parent
            visible: root.ripple > 0
            opacity: 1 - root.ripple
            transform: Scale { origin.x: 200; origin.y: 248; xScale: 1 + 0.3 * root.ripple; yScale: 1 + 0.3 * root.ripple }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeColor: "#ccffffff"; strokeWidth: 1.6
                PathSvg { path: "M 98 248 C 98 238 144 232 200 232 C 256 232 302 238 302 248 C 302 258 256 264 200 264 C 144 264 98 258 98 248 Z" }
            }
        }

        // the duck, hidden below the surface; it tips round the middle of its body
        Item {
            width: 400
            height: root.waterY
            clip: true
            DuckRig {
                width: 400
                height: 300
                colour: root.colour
                shadowVisible: false
                legsVisible: root.angle > 30
                legSwing: root.feet
                transform: [
                    Translate { y: 20 + root.bob - 12 * Math.max(0, Math.min(root.angle, 100)) / 100 },
                    Rotation { origin.x: 206; origin.y: 238; angle: root.angle }
                ]
            }
        }

        // splash drops
        Shape {
            anchors.fill: parent
            visible: root.drops > 0
            opacity: root.drops
            y: -10 * root.drops
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "#d8f0fb"; strokeColor: "#8cc6e6"; strokeWidth: 1
                PathSvg { path: "M 72 234 a 3 4 0 1 0 6 0 a 3 4 0 1 0 -6 0 Z M 328 228 a 3 4 0 1 0 6 0 a 3 4 0 1 0 -6 0 Z M 58 214 a 2.2 3 0 1 0 4.4 0 a 2.2 3 0 1 0 -4.4 0 Z M 344 208 a 2.2 3 0 1 0 4.4 0 a 2.2 3 0 1 0 -4.4 0 Z" }
            }
        }
        }
    }
}
