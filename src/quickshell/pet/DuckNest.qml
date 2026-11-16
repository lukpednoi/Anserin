import QtQuick
import QtQuick.Shapes
import "../"

// The duck asleep in a straw nest (the pet's picture for an empty notification box): breathing slowly, a soft
// "Quack" drifting up clear of its head. In the duck's colour (PetState). Runs only while visible.
// Everything follows t (seconds, looping every `loop`). Drawing space 400x300, scaled to fit.
Item {
    id: root
    property bool playing: visible
    property string colour: PetState.colour
    property string labelFont: ThemeBackend.fontFamily
    readonly property real loop: 3
    property real t: 0

    readonly property real breath: 0.5 - 0.5 * Math.cos(2 * Math.PI * t / loop)
    readonly property real quack: (t % loop) / loop        // 0..1, the word rising and fading

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

        // the nest's back rim and its hollow
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1; strokeColor: "transparent"
                fillGradient: LinearGradient { x1: 0; y1: 214; x2: 0; y2: 262
                    GradientStop { position: 0; color: "#b4874f" } GradientStop { position: 1; color: "#7a532c" } }
                PathSvg { path: "M 62 246 C 62 222 120 210 196 210 C 272 210 330 222 330 246 C 330 262 272 268 196 268 C 120 268 62 262 62 246 Z" }
            }
            ShapePath {
                strokeWidth: -1; strokeColor: "transparent"
                fillColor: "#5e3f22"
                PathSvg { path: "M 84 244 C 90 228 140 220 196 220 C 252 220 302 228 308 244 C 290 254 252 258 196 258 C 140 258 102 254 84 244 Z" }
            }
        }

        // the duck sits down into it: no legs, no shadow, eyes shut
        DuckRig {
            width: 400
            height: 300
            y: 22
            colour: root.colour
            legsVisible: false
            shadowVisible: false
            eyesClosed: 1
            breath: root.breath
        }

        // the nest's front, in front of the duck's belly
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1; strokeColor: "transparent"
                fillGradient: LinearGradient { x1: 0; y1: 244; x2: 0; y2: 296
                    GradientStop { position: 0; color: "#d4a86c" } GradientStop { position: 0.55; color: "#b58450" } GradientStop { position: 1; color: "#7c5530" } }
                PathSvg { path: "M 60 246 C 92 268 300 268 332 246 C 336 276 292 296 196 296 C 100 296 56 276 60 246 Z" }
            }
            // straw, a few loose twigs
            ShapePath {
                fillColor: "transparent"; strokeColor: "#8a5f33"; strokeWidth: 1.6; capStyle: ShapePath.RoundCap
                PathSvg { path: "M 74 258 Q 110 270 150 268 M 160 276 Q 200 282 244 274 M 250 266 Q 286 262 318 252 M 92 276 Q 120 286 156 286 M 232 286 Q 262 284 300 272 M 120 262 Q 150 272 186 272" }
            }
            ShapePath {
                fillColor: "transparent"; strokeColor: "#e6c48e"; strokeWidth: 1.2; capStyle: ShapePath.RoundCap
                PathSvg { path: "M 86 252 Q 118 262 152 262 M 206 270 Q 236 270 262 264 M 140 282 Q 170 288 204 286 M 268 280 Q 292 276 314 264 M 60 246 L 48 240 M 332 246 L 346 238" }
            }
        }

        // "Quack", soft grey, up and to the right of the head (never over it), rising and fading
        Text {
            x: 286
            y: 14 - 12 * root.quack
            rotation: -8
            text: "Quack"
            color: "#c3c8d0"
            opacity: Math.min(1, root.quack / 0.2, (1 - root.quack) / 0.35) * 0.9
            font { family: root.labelFont; pixelSize: 32; bold: true; italic: true }
        }
    }
}
