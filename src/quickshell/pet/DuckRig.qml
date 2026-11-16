import QtQuick
import QtQuick.Shapes
import "DuckColours.js" as DuckColours

// The white Call duck, three-quarter view, as a rig: the locked design split into parts that move. Written by
// src/assets/pet/rig2qml.py from src/assets/pet/duck-rig-34.svg; edit the drawing there, not here. At rest it draws the locked design.
// Pose properties (an action animates them):
//   whole duck: rock (deg, over its feet), bob (px up), shakeX (px sideways), stretchY (squash < 0 < stretch),
//               breath (0..1)
//   head:       headAngle (deg, + dips it forward), headX / headY (px), headFlip (looks back), eyesClosed (shut at 0.5+),
//               jawOpen (deg, opens the bill)
//   wings:      wingsOpen (spread instead of folded), flap (deg, + raises them)
//   tail / legs: tailWag (deg), legSwing / farLegSwing (deg), legsVisible, shadowVisible
//   colour:     one of DuckColours.list's ids ("white", the locked design, by default)
// The drawing is 400x300 and scales to fit the item.
Item {
    id: duck
    property real rock: 0
    property real bob: 0
    property real shakeX: 0
    property real stretchY: 0
    property real breath: 0
    property real headAngle: 0
    property real headX: 0
    property real headY: 0
    property bool headFlip: false
    property real eyesClosed: 0
    property real jawOpen: 0
    property bool wingsOpen: false
    property real flap: 0
    property real tailWag: 0
    property real legSwing: 0
    property real farLegSwing: -legSwing
    property bool legsVisible: true
    property bool shadowVisible: true
    property string colour: "white"
    readonly property var pal: DuckColours.palette(colour)
    implicitWidth: 400
    implicitHeight: 300

    Item {
        width: 400
        height: 300
        scale: Math.min(duck.width / 400, duck.height / 300)
        transformOrigin: Item.TopLeft
        x: (duck.width - 400 * scale) / 2
        y: (duck.height - 300 * scale) / 2

            Item {  // shadow
                anchors.fill: parent
                visible: duck.shadowVisible
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: "#38000000"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 88.00 276.00 C 88.00 269.37 135.46 264.00 194.00 264.00 C 252.54 264.00 300.00 269.37 300.00 276.00 C 300.00 282.63 252.54 288.00 194.00 288.00 C 135.46 288.00 88.00 282.63 88.00 276.00 Z" }
}
                }
            }

        Item {
            anchors.fill: parent
            transform: [
                Scale { origin.x: 194; origin.y: 272; xScale: 1 - 0.45 * duck.stretchY; yScale: 1 + duck.stretchY },
                Rotation { origin.x: 194; origin.y: 272; angle: duck.rock },
                Translate { x: duck.shakeX; y: -duck.bob }
            ]

            Item {  // farWingOpen
                anchors.fill: parent
                visible: duck.wingsOpen
                transform: [
                    Scale { origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath },
                    Rotation { origin.x: 216; origin.y: 142; angle: -0.8 * duck.flap }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 197.8 92.3 C 178.9 84.7 158.0 79.6 147.7 81.7 C 146.6 83.4 154.4 90.7 169.7 96.3 C 181.9 100.3 191.7 102.9 194.2 103.7 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 197.3 90.0 C 177.6 77.9 155.4 68.0 143.8 67.6 C 142.3 69.1 149.9 78.3 165.9 87.5 C 178.7 94.2 189.2 99.1 191.7 100.5 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 196.7 87.8 C 177.8 71.2 155.9 56.2 143.9 53.3 C 142.1 54.5 148.8 65.4 164.3 78.3 C 176.7 88.0 186.9 95.2 189.4 97.2 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 196.0 85.8 C 179.8 65.6 160.4 46.6 148.8 41.3 C 146.9 42.2 151.7 54.4 165.1 70.1 C 175.9 82.1 185.0 91.3 187.2 93.7 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 195.2 83.8 C 183.1 61.7 167.7 40.2 157.3 33.3 C 155.3 33.9 157.8 46.4 167.9 63.8 C 176.3 77.1 183.4 87.5 185.1 90.1 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 194.2 82.0 C 186.9 60.0 176.2 38.2 167.6 30.4 C 165.5 30.6 165.4 42.5 171.8 59.9 C 177.2 73.3 182.1 83.8 183.2 86.5 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 193.0 80.3 C 190.2 60.0 184.1 39.4 177.2 31.5 C 175.1 31.4 172.7 41.8 175.5 57.9 C 178.2 70.4 180.9 80.2 181.4 82.7 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 199.1 95.2 C 182.5 91.1 164.5 90.6 156.1 95.7 C 155.3 98.1 162.5 104.6 175.9 107.2 C 186.4 108.7 195.0 109.2 197.1 109.5 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 203.4 102.5 C 188.4 96.7 171.7 94.3 163.1 98.5 C 162.1 100.7 168.0 108.0 180.1 112.0 C 189.8 114.6 197.7 116.0 199.6 116.5 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 207.6 110.0 C 194.4 102.8 179.1 98.8 170.5 102.0 C 169.3 104.1 173.8 111.9 184.6 117.1 C 193.3 120.6 200.5 122.7 202.2 123.4 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 211.9 117.6 C 200.5 109.3 186.7 104.0 178.2 106.3 C 176.7 108.3 179.9 116.3 189.3 122.4 C 196.9 126.6 203.3 129.3 204.9 130.2 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 216.1 125.2 C 206.6 116.2 194.5 109.9 186.1 111.5 C 184.4 113.3 186.1 121.3 194.1 128.0 C 200.6 132.7 206.3 136.0 207.6 136.9 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 220.2 133.0 C 212.7 123.6 202.1 116.5 194.0 117.4 C 192.1 119.0 192.5 126.9 199.0 133.9 C 204.4 139.0 209.2 142.5 210.3 143.5 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 36.0; x2: 0.0; y2: 146.0; GradientStop { position: 0.0; color: duck.pal.farWing[0] } GradientStop { position: 1.0; color: duck.pal.farWing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_b8bdc5 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_b8bdc5, 1))
strokeWidth: 1.1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 220.0 148.0 C 209.0 148.3 185.2 103.2 186.4 80.0 C 201.0 86.2 219.5 86.8 226.5 106.0 C 243.3 131.9 228.8 144.8 220.0 148.0 Z" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_c3c8cf === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c3c8cf, 0.8))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 207.6 103.7 q 5 4 10 0 M 212.0 112.9 q 5 4 10 0 M 216.4 122.1 q 5 4 10 0 M 220.8 131.3 q 5 4 10 0" }
}
                }
            }
            Item {  // farLeg
                anchors.fill: parent
                visible: duck.legsVisible
                transform: [
                    Rotation { origin.x: 214; origin.y: 246; angle: duck.farLegSwing }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: "transparent"
strokeColor: "#d27420"
strokeWidth: 6
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 214 246 C 215 252 216 258 216 264" }
}
ShapePath {
fillColor: "#d27420"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 214 262 C 222 262 232 266 238 271 C 230 275 222 274 216 272 C 210 274 204 272 200 268 C 204 264 209 262 214 262 Z" }
}
                }
            }
            Item {  // tail
                anchors.fill: parent
                transform: [
                    Scale { origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath },
                    Rotation { origin.x: 124; origin.y: 160; angle: duck.tailWag }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: RadialGradient { centerX: 236.0; centerY: 150.0; centerRadius: 178.0; focalX: 236.0; focalY: 150.0; focalRadius: 0; GradientStop { position: 0.0; color: duck.pal.tail[0] } GradientStop { position: 0.5; color: duck.pal.tail[1] } GradientStop { position: 0.82; color: duck.pal.tail[2] } GradientStop { position: 1.0; color: duck.pal.tail[3] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_c3c7ce === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c3c7ce, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 130.0 157.6 C 127.0 145.9 120.6 135.5 113.5 131.9 C 111.0 132.6 108.7 140.3 111.4 148.9 C 114.2 155.9 117.4 161.0 118.0 162.4 Z" }
}
ShapePath {
fillGradient: RadialGradient { centerX: 236.0; centerY: 150.0; centerRadius: 178.0; focalX: 236.0; focalY: 150.0; focalRadius: 0; GradientStop { position: 0.0; color: duck.pal.tail[0] } GradientStop { position: 0.5; color: duck.pal.tail[1] } GradientStop { position: 0.82; color: duck.pal.tail[2] } GradientStop { position: 1.0; color: duck.pal.tail[3] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_c3c7ce === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c3c7ce, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 129.8 156.1 C 123.1 143.2 113.2 132.5 104.6 129.7 C 102.0 131.0 101.9 140.2 107.2 149.6 C 112.2 157.1 117.2 162.4 118.2 163.9 Z" }
}
ShapePath {
fillGradient: RadialGradient { centerX: 236.0; centerY: 150.0; centerRadius: 178.0; focalX: 236.0; focalY: 150.0; focalRadius: 0; GradientStop { position: 0.0; color: duck.pal.tail[0] } GradientStop { position: 0.5; color: duck.pal.tail[1] } GradientStop { position: 0.82; color: duck.pal.tail[2] } GradientStop { position: 1.0; color: duck.pal.tail[3] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_c3c7ce === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c3c7ce, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 128.9 155.0 C 118.5 142.6 105.5 133.1 95.8 131.6 C 93.6 133.3 95.9 143.0 104.0 151.9 C 111.2 158.9 117.7 163.6 119.1 165.0 Z" }
}
ShapePath {
fillGradient: RadialGradient { centerX: 236.0; centerY: 150.0; centerRadius: 178.0; focalX: 236.0; focalY: 150.0; focalRadius: 0; GradientStop { position: 0.0; color: duck.pal.tail[0] } GradientStop { position: 0.5; color: duck.pal.tail[1] } GradientStop { position: 0.82; color: duck.pal.tail[2] } GradientStop { position: 1.0; color: duck.pal.tail[3] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_c3c7ce === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c3c7ce, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 127.7 154.1 C 115.7 144.6 101.6 138.4 92.2 139.2 C 90.4 141.3 94.4 150.1 103.6 156.8 C 111.6 161.9 118.7 164.9 120.3 165.9 Z" }
}
ShapePath {
fillGradient: RadialGradient { centerX: 236.0; centerY: 150.0; centerRadius: 178.0; focalX: 236.0; focalY: 150.0; focalRadius: 0; GradientStop { position: 0.0; color: duck.pal.tail[0] } GradientStop { position: 0.5; color: duck.pal.tail[1] } GradientStop { position: 0.82; color: duck.pal.tail[2] } GradientStop { position: 1.0; color: duck.pal.tail[3] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_c3c7ce === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c3c7ce, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 126.2 153.9 C 114.7 148.0 102.0 145.6 94.2 148.3 C 93.0 150.7 97.6 157.6 106.4 161.6 C 113.9 164.3 120.3 165.6 121.8 166.1 Z" }
}
ShapePath {
fillGradient: RadialGradient { centerX: 236.0; centerY: 150.0; centerRadius: 178.0; focalX: 236.0; focalY: 150.0; focalRadius: 0; GradientStop { position: 0.0; color: duck.pal.tail[0] } GradientStop { position: 0.5; color: duck.pal.tail[1] } GradientStop { position: 0.82; color: duck.pal.tail[2] } GradientStop { position: 1.0; color: duck.pal.tail[3] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_c3c7ce === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c3c7ce, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 125.0 154.1 C 115.0 150.9 104.5 151.0 98.5 154.8 C 97.8 157.1 102.4 162.5 110.0 164.6 C 116.4 165.7 121.7 165.7 123.0 165.9 Z" }
}
                }
            }
            Item {  // body
                anchors.fill: parent
                transform: [
                    Scale { origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: RadialGradient { centerX: 236.0; centerY: 150.0; centerRadius: 178.0; focalX: 236.0; focalY: 150.0; focalRadius: 0; GradientStop { position: 0.0; color: duck.pal.body[0] } GradientStop { position: 0.5; color: duck.pal.body[1] } GradientStop { position: 0.82; color: duck.pal.body[2] } GradientStop { position: 1.0; color: duck.pal.body[3] } }
fillColor: "transparent"
strokeColor: (duck.pal.outline === "transparent" ? "transparent" : Qt.alpha(duck.pal.outline, 0.7))
strokeWidth: 1.1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 112 162 C 124 144 152 132 186 132 C 204 132 214 134 222 138 C 246 142 280 144 300 152 C 314 174 310 214 282 238 C 254 260 190 264 152 250 C 124 240 108 218 108 196 C 108 184 108 172 112 162 Z" }
}
                }
                Item {  // rearShadeShade
                    anchors.fill: parent
                    opacity: duck.pal.shade
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: LinearGradient { x1: 108.0; y1: 0.0; x2: 156.0; y2: 0.0; GradientStop { position: 0.0; color: "#99b3b9c3" } GradientStop { position: 1.0; color: "#00b3b9c3" } }
fillColor: "transparent"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 112 162 C 124 150 148 140 172 136 C 158 170 158 214 172 258 C 164 256 158 253 152 250 C 124 240 108 218 108 196 C 108 184 108 172 112 162 Z" }
}
                    }
                }
                Item {  // bellyShade
                    anchors.fill: parent
                    opacity: duck.pal.shade
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 206.0; x2: 0.0; y2: 260.0; GradientStop { position: 0.0; color: "#00b9bfc9" } GradientStop { position: 1.0; color: "#d9b9bfc9" } }
fillColor: "transparent"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 124 232 C 156 250 222 256 276 230 C 266 246 250 254 234 258 C 200 264 166 260 152 250 C 140 244 130 238 124 232 Z" }
}
                    }
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: (duck.pal.back === "transparent" ? "transparent" : Qt.alpha(duck.pal.back, 1))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 112 162 C 124 144 152 132 186 132 C 204 132 214 134 222 138 C 218 152 202 160 180 160 C 150 160 126 168 112 176 Z" }
}
                }
            }
            Shape {  // neck join
                id: neckJoin
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                transform: [ Scale { origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath } ]
                // only as the head moves off its place, so at rest the duck is exactly the locked design
                // (not for the small nods of walking: its shape is worked out again on every frame it shows)
                opacity: Math.max(0, Math.min(1, (Math.hypot(duck.headX, duck.headY) + Math.abs(duck.headAngle) * 0.4 - 4) / 6))
                visible: opacity > 0
                // the head's transform applied to a point of the drawing
                function hp(x, y) {
                    if (duck.headFlip) x = 516 - x;
                    const a = duck.headAngle * Math.PI / 180, dx = x - 258, dy = y - 160;
                    return (258 + dx * Math.cos(a) - dy * Math.sin(a) + duck.headX) + " " + (160 + dx * Math.sin(a) + dy * Math.cos(a) + duck.headY);
                }
                // back of the neck: from the back line, curving up into the nape; front: from under the chin down onto the breast
                readonly property string back: "M 212 135 C 222 137 " + hp(219, 138) + " " + hp(221, 126)
                readonly property string front: "M " + hp(300, 150) + " C " + hp(304, 176) + " 318 184 306 198"
                ShapePath {
                    strokeWidth: -1; strokeColor: "transparent"
                    fillGradient: RadialGradient { centerX: 236; centerY: 150; centerRadius: 178; focalX: 236; focalY: 150; focalRadius: 0
                        GradientStop { position: 0; color: duck.pal.head[0] } GradientStop { position: 0.5; color: duck.pal.head[1] } GradientStop { position: 0.82; color: duck.pal.head[2] } GradientStop { position: 1; color: duck.pal.head[3] } }
                    PathSvg { path: neckJoin.back + " L " + neckJoin.hp(262, 150) + " L " + neckJoin.hp(300, 150)
                                     + " C " + neckJoin.hp(304, 176) + " 318 184 306 198 Q 262 200 212 135 Z" }
                }
                ShapePath {
                    fillColor: "transparent"; strokeColor: Qt.alpha(duck.pal.outline, 0.7); strokeWidth: 1.1; capStyle: ShapePath.RoundCap
                    PathSvg { path: neckJoin.back + " " + neckJoin.front }
                }
            }
            Item {  // head
                anchors.fill: parent
                transform: [
                    Scale { origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath },
                    Scale { origin.x: 258; origin.y: 160; xScale: duck.headFlip ? -1 : 1 },
                    Rotation { origin.x: 258; origin.y: 160; angle: duck.headAngle },
                    Translate { x: duck.headX; y: duck.headY }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: RadialGradient { centerX: 236.0; centerY: 150.0; centerRadius: 178.0; focalX: 236.0; focalY: 150.0; focalRadius: 0; GradientStop { position: 0.0; color: duck.pal.head[0] } GradientStop { position: 0.5; color: duck.pal.head[1] } GradientStop { position: 0.82; color: duck.pal.head[2] } GradientStop { position: 1.0; color: duck.pal.head[3] } }
fillColor: "transparent"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 222 138 C 218 124 218 110 222 98 C 228 68 250 48 276 48 C 302 48 324 66 326 94 C 327 108 322 118 314 126 C 306 134 300 142 300 152 C 302 162 300 172 296 178 C 276 186 242 184 226 172 C 222 162 222 150 222 138 Z" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.outline === "transparent" ? "transparent" : Qt.alpha(duck.pal.outline, 0.7))
strokeWidth: 1.1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 222 138 C 218 124 218 110 222 98 C 228 68 250 48 276 48 C 302 48 324 66 326 94 C 327 108 322 118 314 126 C 306 134 300 142 300 152" }
}
ShapePath {
fillColor: (duck.pal.cap === "transparent" ? "transparent" : Qt.alpha(duck.pal.cap, 1))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 221 104 C 224 72 248 50 276 50 C 300 50 317 62 323 80 C 300 76 272 78 248 90 C 236 96 228 101 221 104 Z" }
}
                }
                Item {  // headSheen
                    anchors.fill: parent
                    opacity: duck.pal.sheen
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: RadialGradient { centerX: 262.0; centerY: 80.0; centerRadius: 46.0; focalX: 262.0; focalY: 80.0; focalRadius: 0; GradientStop { position: 0.0; color: "#ffffff" } GradientStop { position: 0.7; color: "#80ffffff" } GradientStop { position: 1.0; color: "#00ffffff" } }
fillColor: "transparent"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 232 92 C 236 66 254 56 274 58 C 296 60 312 76 310 98 C 300 114 276 118 258 114 C 240 110 230 104 232 92 Z" }
}
                    }
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: (duck.pal.chin === "transparent" ? "transparent" : Qt.alpha(duck.pal.chin, 0.5))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 312 122 C 304 132 298 140 298 150 C 292 144 286 140 278 138 C 290 136 302 130 312 122 Z" }
}
                }
                Item {  // farEye
                    anchors.fill: parent
                    visible: duck.eyesClosed < 0.5
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: (duck.pal.eyeRing === "transparent" ? "transparent" : Qt.alpha(duck.pal.eyeRing, 1))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 309.20 88.00 C 309.20 84.35 310.90 81.40 313.00 81.40 C 315.10 81.40 316.80 84.35 316.80 88.00 C 316.80 91.65 315.10 94.60 313.00 94.60 C 310.90 94.60 309.20 91.65 309.20 88.00 Z" }
}
ShapePath {
fillColor: "#10141c"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 310.70 88.00 C 310.70 85.02 311.91 82.60 313.40 82.60 C 314.89 82.60 316.10 85.02 316.10 88.00 C 316.10 90.98 314.89 93.40 313.40 93.40 C 311.91 93.40 310.70 90.98 310.70 88.00 Z" }
}
ShapePath {
fillColor: "#ccffffff"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 313.10 85.60 C 313.10 84.88 313.50 84.30 314.00 84.30 C 314.50 84.30 314.90 84.88 314.90 85.60 C 314.90 86.32 314.50 86.90 314.00 86.90 C 313.50 86.90 313.10 86.32 313.10 85.60 Z" }
}
                    }
                }
                Item {  // mouth
                    anchors.fill: parent
                    visible: duck.jawOpen > 0.5
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: "#b8575a"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 291 117 C 302 126 318 133 331 136 C 322 146 304 142 292 128 Z" }
}
ShapePath {
fillColor: "transparent"
strokeColor: "#e08a8c"
strokeWidth: 2
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 298 124 C 308 130 318 134 326 136" }
}
                    }
                }
                Item {  // jaw
                    anchors.fill: parent
                    transform: [
                        Rotation { origin.x: 292; origin.y: 122; angle: duck.jawOpen }
                    ]
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: (duck.pal.jaw === "transparent" ? "transparent" : Qt.alpha(duck.pal.jaw, 1))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 292 120 C 302 130 318 138 330 138 C 326 144 306 144 294 132 Z" }
}
                    }
                }
                Item {  // bill
                    anchors.fill: parent
                    transform: [
                        Rotation { origin.x: 290; origin.y: 112; angle: -0.3 * duck.jawOpen }
                    ]
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 100.0; x2: 0.0; y2: 134.0; GradientStop { position: 0.0; color: duck.pal.bill[0] } GradientStop { position: 1.0; color: duck.pal.bill[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.billEdge === "transparent" ? "transparent" : Qt.alpha(duck.pal.billEdge, 1))
strokeWidth: 0.9
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 290 108 C 298 100 312 98 320 104 C 328 110 338 116 340 124 C 342 132 334 138 324 137 C 310 136 296 128 290 118 Z" }
}
ShapePath {
fillColor: "transparent"
strokeColor: "#ccffd58c"
strokeWidth: 1.4
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 304 106 C 316 110 328 116 336 124" }
}
ShapePath {
fillColor: "transparent"
strokeColor: "#a85a1c"
strokeWidth: 1.1
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 290 118 C 300 128 314 135 326 137" }
}
ShapePath {
fillColor: "#a6591d"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 305.58 112.60 C 305.96 111.93 307.36 112.01 308.70 112.79 C 310.04 113.56 310.81 114.73 310.42 115.40 C 310.04 116.07 308.64 115.99 307.30 115.21 C 305.96 114.44 305.19 113.27 305.58 112.60 Z" }
}
ShapePath {
fillColor: "#b2a6591d"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 318.09 108.90 C 318.40 108.37 319.50 108.44 320.55 109.05 C 321.60 109.65 322.21 110.57 321.91 111.10 C 321.60 111.63 320.50 111.56 319.45 110.95 C 318.40 110.35 317.79 109.43 318.09 108.90 Z" }
}
ShapePath {
fillColor: "#e6f6cf91"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 333 126 C 339 126 342 131 338 135 C 335 134 333 130 333 126 Z" }
}
                    }
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.billBase === "transparent" ? "transparent" : Qt.alpha(duck.pal.billBase, 1))
strokeWidth: 1.4
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 290 106 C 287 112 287 116 291 121" }
}
                }
                Item {  // nearEye
                    anchors.fill: parent
                    visible: duck.eyesClosed < 0.5
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: (duck.pal.eyeRing === "transparent" ? "transparent" : Qt.alpha(duck.pal.eyeRing, 1))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 260.20 90.00 C 260.20 85.03 263.69 81.00 268.00 81.00 C 272.31 81.00 275.80 85.03 275.80 90.00 C 275.80 94.97 272.31 99.00 268.00 99.00 C 263.69 99.00 260.20 94.97 260.20 90.00 Z" }
}
ShapePath {
fillGradient: RadialGradient { centerX: 268.0; centerY: 90.0; centerRadius: 8.0; focalX: 268.0; focalY: 90.0; focalRadius: 0; GradientStop { position: 0.0; color: "#34405a" } GradientStop { position: 0.6; color: "#151a24" } GradientStop { position: 1.0; color: "#07090d" } }
fillColor: "transparent"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 262.20 90.00 C 262.20 85.91 264.98 82.60 268.40 82.60 C 271.82 82.60 274.60 85.91 274.60 90.00 C 274.60 94.09 271.82 97.40 268.40 97.40 C 264.98 97.40 262.20 94.09 262.20 90.00 Z" }
}
ShapePath {
fillColor: "#ffffff"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 268.90 86.80 C 268.90 85.53 269.84 84.50 271.00 84.50 C 272.16 84.50 273.10 85.53 273.10 86.80 C 273.10 88.07 272.16 89.10 271.00 89.10 C 269.84 89.10 268.90 88.07 268.90 86.80 Z" }
}
ShapePath {
fillColor: "#99ffffff"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 265.10 93.40 C 265.10 92.90 265.50 92.50 266.00 92.50 C 266.50 92.50 266.90 92.90 266.90 93.40 C 266.90 93.90 266.50 94.30 266.00 94.30 C 265.50 94.30 265.10 93.90 265.10 93.40 Z" }
}
                    }
                }
                Item {  // lids
                    anchors.fill: parent
                    visible: duck.eyesClosed >= 0.5
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: "transparent"
strokeColor: "#3b4150"
strokeWidth: 1.7
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 260.5 90.5 Q 268 96.5 275.5 90.5 M 310.4 89 Q 313 92.6 315.6 89" }
}
                    }
                }
            }
            Item {  // breast
                anchors.fill: parent
                transform: [
                    Scale { origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: (duck.pal.breast === "transparent" ? "transparent" : Qt.alpha(duck.pal.breast, 1))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 224 160 C 250 170 282 170 301 160 C 312 178 312 202 302 218 C 280 228 248 224 231 208 C 222 194 221 176 224 160 Z" }
}
ShapePath {
fillColor: (duck.pal.bib === "transparent" ? "transparent" : Qt.alpha(duck.pal.bib, 1))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 266 132 C 284 140 298 146 302 156 C 309 172 307 192 297 204 C 284 198 274 186 270 170 C 266 158 263 144 266 132 Z" }
}
ShapePath {
fillColor: (duck.pal.ring === "transparent" ? "transparent" : Qt.alpha(duck.pal.ring, 1))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 223 149 C 248 160 278 162 300 155 L 301 162 C 278 170 246 168 223 157 Z" }
}
                }
                Item {  // breastSheen
                    anchors.fill: parent
                    opacity: duck.pal.sheen
                    Shape {
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: RadialGradient { centerX: 272.0; centerY: 192.0; centerRadius: 52.0; focalX: 272.0; focalY: 192.0; focalRadius: 0; GradientStop { position: 0.0; color: "#f2ffffff" } GradientStop { position: 1.0; color: "#00ffffff" } }
fillColor: "transparent"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 226 176 C 236 150 284 150 300 170 C 310 196 298 222 276 234 C 252 244 228 230 222 210 C 220 198 222 186 226 176 Z" }
}
                    }
                }
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_c9cdd4 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c9cdd4, 0.7))
strokeWidth: 1.4
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 236 146 C 250 154 270 158 296 152" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_cfd3d9 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_cfd3d9, 0.75))
strokeWidth: 1
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 276 172 q 6 4 12 0 M 286 188 q 6 4 12 0 M 270 192 q 6 4 12 0 M 284 206 q 6 4 12 0 M 266 210 q 6 4 12 0 M 276 224 q 6 4 12 0" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_cfd3d9 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_cfd3d9, 0.75))
strokeWidth: 1
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 250 214 q 6 4 12 0 M 240 228 q 6 4 12 0 M 222 238 q 6 4 12 0 M 202 242 q 6 4 12 0" }
}
                }
            }
            Item {  // wingFolded
                anchors.fill: parent
                visible: !duck.wingsOpen
                transform: [
                    Scale { origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: (duck.pal.farEdge === "transparent" ? "transparent" : Qt.alpha(duck.pal.farEdge, 0.9))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 160 138 C 184 130 208 130 220 138 C 204 138 182 140 166 144 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 108.0; y1: 0.0; x2: 196.0; y2: 0.0; GradientStop { position: 0.0; color: duck.pal.primaries[0] } GradientStop { position: 1.0; color: duck.pal.primaries[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 196 172 C 166 166 136 160 108 152 C 120 170 146 188 196 190 Z" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 0.9
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 192 180 C 166 176 138 170 114 160 M 188 186 C 164 182 142 176 120 166" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 150.0; x2: 0.0; y2: 202.0; GradientStop { position: 0.0; color: duck.pal.wing[0] } GradientStop { position: 1.0; color: duck.pal.wing[1] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_c3c8cf === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c3c8cf, 1))
strokeWidth: 1.1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 236 166 C 220 152 182 150 156 160 C 144 165 136 170 126 172 C 142 188 166 200 192 202 C 218 202 234 190 236 166 Z" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_c6cad1 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c6cad1, 1))
strokeWidth: 1.1
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 230 172 C 214 164 190 164 168 170" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_c6cad1 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c6cad1, 1))
strokeWidth: 1.1
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 224 184 C 206 178 182 178 158 182" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_c6cad1 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c6cad1, 1))
strokeWidth: 1.1
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 212 194 C 196 191 174 189 154 186" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_c6cad1 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_c6cad1, 0.8))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 218 160 q 6 5 12 1 M 206 157 q 6 5 12 1 M 194 156 q 6 5 12 1 M 182 156 q 6 5 12 1" }
}
ShapePath {
fillColor: (duck.pal.speculum === "transparent" ? "transparent" : Qt.alpha(duck.pal.speculum, 1))
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 216 189 C 198 188 174 186 152 182 L 149 189 C 172 194 196 196 215 196 Z" }
}
                }
            }
            Item {  // wingOpen
                anchors.fill: parent
                visible: duck.wingsOpen
                transform: [
                    Scale { origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath },
                    Rotation { origin.x: 234; origin.y: 164; angle: -duck.flap }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 206.2 103.3 C 183.9 94.3 159.3 88.4 147.2 90.8 C 145.8 92.9 155.0 101.5 173.1 108.1 C 187.4 112.7 199.0 115.7 201.8 116.7 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 205.6 100.6 C 182.3 86.3 156.2 74.7 142.6 74.2 C 140.8 76.0 149.8 86.8 168.6 97.6 C 183.7 105.6 196.0 111.3 199.0 112.9 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 204.9 98.0 C 182.6 78.5 156.9 60.9 142.7 57.4 C 140.6 58.8 148.4 71.7 166.7 86.8 C 181.2 98.2 193.3 106.8 196.2 109.0 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 204.0 95.6 C 184.9 71.9 162.1 49.5 148.5 43.3 C 146.2 44.4 151.9 58.7 167.7 77.2 C 180.4 91.3 191.1 102.1 193.6 105.0 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 203.1 93.3 C 188.8 67.3 170.7 42.0 158.5 33.9 C 156.1 34.6 159.0 49.3 171.0 69.8 C 180.8 85.4 189.2 97.6 191.2 100.8 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 201.9 91.2 C 193.3 65.3 180.7 39.6 170.6 30.5 C 168.1 30.8 168.0 44.7 175.5 65.2 C 181.9 80.9 187.6 93.3 188.9 96.4 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 200.5 89.1 C 197.2 65.3 190.0 41.1 181.9 31.7 C 179.4 31.6 176.6 43.9 179.9 62.8 C 183.0 77.5 186.2 89.1 186.8 92.0 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 208.0 106.8 C 188.5 102.0 167.3 101.5 157.4 107.4 C 156.5 110.2 165.0 118.0 180.8 121.0 C 193.1 122.8 203.2 123.3 205.6 123.7 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 213.7 115.8 C 196.1 109.0 176.4 106.1 166.3 111.0 C 165.1 113.7 172.1 122.2 186.4 126.9 C 197.7 130.0 207.0 131.6 209.3 132.2 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 219.4 124.9 C 203.8 116.4 185.8 111.7 175.7 115.5 C 174.2 118.0 179.6 127.1 192.3 133.2 C 202.5 137.3 211.0 139.8 213.0 140.6 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 225.0 134.1 C 211.6 124.3 195.4 118.1 185.4 120.9 C 183.7 123.2 187.3 132.6 198.4 139.7 C 207.4 144.7 215.0 147.9 216.8 148.9 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 230.6 143.4 C 219.5 132.8 205.1 125.3 195.3 127.2 C 193.3 129.3 195.4 138.8 204.7 146.6 C 212.4 152.2 219.0 156.0 220.6 157.1 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 236.0 152.8 C 227.2 141.7 214.8 133.5 205.2 134.5 C 203.0 136.4 203.5 145.6 211.1 153.9 C 217.5 159.9 223.2 164.0 224.5 165.2 Z" }
}
ShapePath {
fillGradient: LinearGradient { x1: 0.0; y1: 44.0; x2: 0.0; y2: 170.0; GradientStop { position: 0.0; color: duck.pal.wingOpen[0] } GradientStop { position: 0.45; color: duck.pal.wingOpen[1] } GradientStop { position: 1.0; color: duck.pal.wingOpen[2] } }
fillColor: "transparent"
strokeColor: (duck.pal.l_bfc4cc === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_bfc4cc, 1))
strokeWidth: 1.1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 236.0 170.0 C 225.2 170.7 193.4 115.7 192.7 88.8 C 208.1 96.4 226.9 97.7 237.2 121.1 C 258.7 152.8 244.6 166.3 236.0 170.0 Z" }
}
ShapePath {
fillColor: "transparent"
strokeColor: (duck.pal.l_cdd1d7 === "transparent" ? "transparent" : Qt.alpha(duck.pal.l_cdd1d7, 0.8))
strokeWidth: 1
capStyle: ShapePath.FlatCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 217.1 117.4 q 5 4 10 0 M 223.1 128.6 q 5 4 10 0 M 229.1 139.8 q 5 4 10 0 M 235.1 151.0 q 5 4 10 0" }
}
                }
            }
            Item {  // nearLeg
                anchors.fill: parent
                visible: duck.legsVisible
                transform: [
                    Rotation { origin.x: 180; origin.y: 248; angle: duck.legSwing }
                ]
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
ShapePath {
fillColor: "transparent"
strokeColor: "#e07b22"
strokeWidth: 7
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 180 250 C 180 256 179 262 178 268" }
}
ShapePath {
fillColor: "#f08f2c"
strokeWidth: -1
strokeColor: "transparent"
PathSvg { path: "M 176 266 C 186 266 198 270 206 276 C 198 281 188 280 180 279 C 172 280 162 278 156 274 C 160 269 168 266 176 266 Z" }
}
ShapePath {
fillColor: "transparent"
strokeColor: "#ccc96a1e"
strokeWidth: 1
capStyle: ShapePath.RoundCap
joinStyle: ShapePath.RoundJoin
PathSvg { path: "M 178 268 L 204 276 M 178 268 L 182 279 M 178 268 L 158 274" }
}
                }
            }
        }
    }
}
