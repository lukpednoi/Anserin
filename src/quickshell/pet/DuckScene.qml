import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// A place for the duck, behind it in the editor: "river" (it floats; the water flows, reeds sway), "grass" (a
// meadow; the grass sways, clouds drift) or "falls" (a rock beside a waterfall; the water falls, mist rises).
// Drawn in a 560x440 space that covers the item (cropped at the edges, never stretched); it moves only while
// `running`. `floor` is where the duck stands (or the water's surface) and `spot` where it stands across, both in the
// drawing's space; pos(x, y) gives that point in the item. It is drawn through a layer with rounded corners
// (`radius`): plain clipping let the moving shapes (clouds, blades) show past the edges.
Item {
    id: scene
    property string kind: "grass"
    property real radius: 0
    property bool running: visible
    readonly property real floor: kind === "river" ? 300 : kind === "falls" ? 332 : 362
    readonly property real spot: kind === "river" ? 268 : kind === "falls" ? 236 : 276
    readonly property bool water: kind === "river"
    readonly property real k: Math.max(width / 560, height / 440)
    function pos(x, y) { return Qt.point(art.x + x * k, art.y + y * k); }

    // one clock for everything that moves (seconds)
    property real t: 0
    NumberAnimation on t { running: scene.running; from: 0; to: 3600; duration: 3600 * 1000; loops: Animation.Infinite }

    component Fill: ShapePath {
        property string d
        strokeWidth: -1
        strokeColor: "transparent"
        PathSvg { path: d }
    }
    component Lines: ShapePath {
        property string d
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathSvg { path: d }
    }

    // the rounded mask: a layer, left visible (a layer under visible:false draws nothing); the scene covers it
    Rectangle {
        id: corners
        anchors.fill: parent
        radius: scene.radius
        color: "black"
        layer.enabled: true
    }
    Item {
    id: content
    anchors.fill: parent
    layer.enabled: true
    layer.effect: MultiEffect { maskEnabled: true; maskSource: corners }
    Item {
        id: art
        width: 560
        height: 440
        scale: scene.k
        transformOrigin: Item.TopLeft
        x: (scene.width - 560 * scene.k) / 2
        y: (scene.height - 440 * scene.k) / 2

        // ---------- sky, shared ----------
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: scene.kind === "falls" ? "#a9cfdc" : "#a8d8ee" }
                GradientStop { position: 0.6; color: scene.kind === "falls" ? "#d7e9e6" : "#e4f3ea" }
            }
        }
        // two soft clouds drifting across
        Repeater {
            model: scene.kind === "falls" ? 0 : 2
            Shape {
                required property int index
                width: 120; height: 40
                x: ((index * 290 + scene.t * (9 + index * 4)) % 760) - 120
                y: 40 + index * 46
                opacity: 0.85
                preferredRendererType: Shape.CurveRenderer
                Fill { fillColor: "#ffffff"; d: "M 10 32 C 0 32 0 18 14 18 C 16 6 34 2 44 12 C 52 0 76 2 80 16 C 96 12 110 22 104 32 Z" }
            }
        }

        // ---------- grass ----------
        Item {
            anchors.fill: parent
            visible: scene.kind === "grass"
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                Fill { fillColor: "#a9cf93"; d: "M 0 250 C 90 200 190 214 280 238 C 370 262 470 206 560 228 L 560 440 L 0 440 Z" }
                Fill { fillColor: "#8dbd75"; d: "M 0 290 C 120 252 240 270 330 286 C 420 302 500 270 560 276 L 560 440 L 0 440 Z" }
                Fill {
                    d: "M 0 340 C 140 322 300 330 420 340 C 480 345 530 340 560 336 L 560 440 L 0 440 Z"
                    fillGradient: LinearGradient { x1: 0; y1: 330; x2: 0; y2: 440
                        GradientStop { position: 0; color: "#78ad5a" } GradientStop { position: 1; color: "#5a8c40" } }
                }
                // flowers
                Fill { fillColor: "#fff6d8"; d: "M 64 392 a 4 4 0 1 0 8 0 a 4 4 0 1 0 -8 0 Z M 430 406 a 4 4 0 1 0 8 0 a 4 4 0 1 0 -8 0 Z M 492 378 a 3 3 0 1 0 6 0 a 3 3 0 1 0 -6 0 Z" }
                Fill { fillColor: "#f2c14e"; d: "M 66.5 392 a 1.5 1.5 0 1 0 3 0 a 1.5 1.5 0 1 0 -3 0 Z M 432.5 406 a 1.5 1.5 0 1 0 3 0 a 1.5 1.5 0 1 0 -3 0 Z" }
            }
            // blades in front, swaying
            Repeater {
                model: 22
                Shape {
                    required property int index
                    readonly property real bx: 8 + index * 25.5 + (index % 3) * 4
                    readonly property real h: 30 + (index * 37 % 26)
                    x: bx; y: 440 - h
                    width: 14; height: h
                    preferredRendererType: Shape.CurveRenderer
                    transform: Rotation { origin.x: 7; origin.y: h; angle: 5 * Math.sin(scene.t * 1.4 + index * 0.7) }
                    Fill { fillColor: index % 2 ? "#4f8238" : "#5d9343"; d: "M 2 " + h + " C 4 " + h * 0.5 + " 6 " + h * 0.2 + " 9 0 C 9 " + h * 0.3 + " 11 " + h * 0.6 + " 12 " + h + " Z" }
                }
            }
        }

        // ---------- river ----------
        Item {
            anchors.fill: parent
            visible: scene.kind === "river"
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // the far bank and its trees
                Fill { fillColor: "#7fae74"; d: "M 0 230 C 60 196 120 210 170 200 C 230 186 290 210 350 196 C 420 180 490 204 560 194 L 560 290 L 0 290 Z" }
                Fill { fillColor: "#5d8f58"; d: "M 20 236 C 30 180 70 170 84 214 C 96 160 140 168 140 226 Z M 380 214 C 392 150 440 150 446 206 C 462 168 502 176 498 222 Z" }
                Fill { fillColor: "#9ac38a"; d: "M 0 278 C 140 268 420 268 560 276 L 560 292 L 0 292 Z" }
                // the water
                Fill {
                    d: "M 0 288 C 140 280 420 280 560 288 L 560 440 L 0 440 Z"
                    fillGradient: LinearGradient { x1: 0; y1: 284; x2: 0; y2: 440
                        GradientStop { position: 0; color: "#8fcbe2" } GradientStop { position: 1; color: "#3f8db3" } }
                }
            }
            // the current: light streaks drifting downstream
            Item {
                x: 0; y: 292; width: 560; height: 148
                clip: true
                Shape {
                    x: -((scene.t * 34) % 280)
                    width: 1120; height: 148
                    preferredRendererType: Shape.CurveRenderer
                    Lines { strokeColor: "#c8ecf8"; strokeWidth: 2
                        d: "M 20 18 L 80 18 M 160 40 L 250 40 M 60 70 L 120 70 M 210 100 L 300 100 M 30 128 L 110 128 "
                         + "M 300 18 L 360 18 M 440 40 L 530 40 M 340 70 L 400 70 M 490 100 L 580 100 M 310 128 L 390 128 "
                         + "M 580 18 L 640 18 M 720 40 L 810 40 M 620 70 L 680 70 M 770 100 L 860 100 M 590 128 L 670 128 "
                         + "M 860 18 L 920 18 M 1000 40 L 1090 40 M 900 70 L 960 70 M 1050 100 L 1120 100 M 870 128 L 950 128" }
                }
            }
            // reeds at both edges
            Repeater {
                model: 7
                Shape {
                    required property int index
                    readonly property bool atLeft: index < 4
                    x: atLeft ? 6 + index * 14 : 500 + (index - 4) * 16
                    y: 250; width: 12; height: 150
                    preferredRendererType: Shape.CurveRenderer
                    transform: Rotation { origin.x: 6; origin.y: 150; angle: 3 * Math.sin(scene.t * 1.1 + index) }
                    Fill { fillColor: "#5f8a4a"; d: "M 5 150 C 4 100 5 40 6 0 C 8 40 9 100 9 150 Z" }
                    Fill { fillColor: "#8a5a34"; d: "M 4 22 C 4 8 9 8 9 22 L 9 44 C 9 52 4 52 4 44 Z" }
                }
            }
        }

        // ---------- rocks by a waterfall ----------
        Item {
            anchors.fill: parent
            visible: scene.kind === "falls"
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                // the cliff
                Fill {
                    d: "M 0 0 L 300 0 C 296 90 306 200 300 330 L 0 330 Z M 440 0 L 560 0 L 560 330 L 432 330 C 438 220 434 110 440 0 Z"
                    fillGradient: LinearGradient { x1: 0; y1: 0; x2: 0; y2: 330
                        GradientStop { position: 0; color: "#7d8c86" } GradientStop { position: 1; color: "#5d6a66" } }
                }
                Fill { fillColor: "#6f9a5c"; d: "M 0 60 C 40 50 90 70 130 58 L 130 74 C 90 84 40 66 0 76 Z M 470 120 C 500 112 530 124 560 116 L 560 130 C 530 138 500 126 470 134 Z" }
                Lines { strokeColor: "#4f5a57"; strokeWidth: 2; d: "M 60 120 L 90 150 M 200 60 L 230 100 M 150 230 L 190 250 M 480 210 L 520 240 M 500 60 L 530 80" }
                // the falling water
                Fill {
                    d: "M 300 0 L 440 0 C 436 110 438 220 432 330 L 300 330 C 306 200 296 90 300 0 Z"
                    fillGradient: LinearGradient { x1: 300; y1: 0; x2: 440; y2: 0
                        GradientStop { position: 0; color: "#cfe9f2" } GradientStop { position: 0.5; color: "#f4fbfd" } GradientStop { position: 1; color: "#bfe1ee" } }
                }
                // the pool
                Fill {
                    d: "M 0 330 C 120 322 440 322 560 330 L 560 440 L 0 440 Z"
                    fillGradient: LinearGradient { x1: 0; y1: 326; x2: 0; y2: 440
                        GradientStop { position: 0; color: "#8ccbdd" } GradientStop { position: 1; color: "#447f9c" } }
                }
            }
            // streaks running down the fall
            Item {
                x: 300; y: 0; width: 140; height: 330
                clip: true
                Shape {
                    y: (scene.t * 160) % 110 - 110
                    width: 140; height: 440
                    preferredRendererType: Shape.CurveRenderer
                    Lines { strokeColor: "#a9d6e6"; strokeWidth: 3
                        d: "M 20 0 L 20 60 M 60 30 L 60 100 M 100 10 L 100 70 M 124 50 L 124 120 M 40 110 L 40 170 M 80 140 L 80 210 "
                         + "M 20 220 L 20 280 M 60 250 L 60 320 M 100 230 L 100 290 M 124 270 L 124 340 M 40 330 L 40 390 M 80 360 L 80 430" }
                }
            }
            // mist rising where it lands
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    readonly property real u: (scene.t * 0.35 + index / 6) % 1
                    width: 26 + index * 4; height: width; radius: width / 2
                    x: 300 + (index * 23) % 120 + 8 * Math.sin(scene.t + index)
                    y: 320 - u * 70
                    color: "#ffffff"
                    opacity: 0.35 * (1 - u)
                }
            }
            // the rock the duck stands on, mossy on top
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                Fill {
                    d: "M 90 440 C 96 380 120 340 170 330 C 220 322 280 326 316 338 C 346 350 352 400 350 440 Z"
                    fillGradient: LinearGradient { x1: 0; y1: 326; x2: 0; y2: 440
                        GradientStop { position: 0; color: "#9aa0a4" } GradientStop { position: 1; color: "#5a6064" } }
                }
                Fill { fillColor: "#7aa35f"; d: "M 140 338 C 170 326 240 324 300 334 C 280 340 220 338 170 344 C 158 346 146 344 140 338 Z" }
                Lines { strokeColor: "#6b7175"; strokeWidth: 2; d: "M 140 380 C 170 372 200 376 220 390 M 260 360 C 280 370 300 372 320 368" }
            }
        }
    }
}
}
