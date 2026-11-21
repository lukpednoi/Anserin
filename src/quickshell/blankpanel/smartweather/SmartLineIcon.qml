import QtQuick
import QtQuick.Shapes

/**
 * Crisp ultra-thin Smart Mirror vector line icons (24x24 design grid).
 * Styled after MagicMirror2 hairline iconography with optional subtle motion.
 */
Item {
    id: root

    // clear, cloudy, overcast, mist, rain, snow, storm, wind, sunrise, sunset, humidity, droplet
    property string icon: "clear"
    property bool isNight: false
    property color color: "#ffffff"
    property real strokeWidth: 1.45
    property bool animated: false

    implicitWidth: 24
    implicitHeight: 24

    readonly property real sc: Math.min(width, height) / 24.0
    property real phase: 0

    NumberAnimation on phase {
        from: 0
        to: Math.PI * 2
        duration: 6000
        loops: Animation.Infinite
        running: root.animated && root.visible
    }

    Item {
        width: 24
        height: 24
        anchors.centerIn: parent
        scale: root.sc

        // ---- CLEAR DAY: thin sun + delicate breathing rays ----
        Shape {
            visible: root.icon === "clear" && !root.isNight
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 12 7.2 A 4.8 4.8 0 1 0 12 16.8 A 4.8 4.8 0 1 0 12 7.2 Z" }
            }
            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.85)
                strokeWidth: root.strokeWidth * 0.92
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: "M 12 2.2 L 12 4.3 M 12 19.7 L 12 21.8 M 2.2 12 L 4.3 12 M 19.7 12 L 21.8 12 "
                        + "M 5.1 5.1 L 6.6 6.6 M 17.4 17.4 L 18.9 18.9 M 18.9 5.1 L 17.4 6.6 M 6.6 17.4 L 5.1 18.9"
                }
            }
            transform: Rotation {
                origin.x: 12; origin.y: 12
                angle: root.animated ? Math.sin(root.phase) * 14 : 0
            }
        }

        // ---- CLEAR NIGHT: graceful thin crescent moon + tiny star ----
        Shape {
            visible: root.icon === "clear" && root.isNight
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 19.2 14.8 A 7.4 7.4 0 0 1 9.2 4.8 A 7.6 7.6 0 1 0 19.2 14.8 Z" }
            }
            ShapePath {
                strokeColor: Qt.alpha(root.color, root.animated ? (0.55 + 0.45 * Math.sin(root.phase * 2)) : 0.85)
                strokeWidth: root.strokeWidth * 0.8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 17.2 5.2 L 17.2 8.0 M 15.8 6.6 L 18.6 6.6" }
            }
        }

        // ---- CLOUDY (partly): sun/moon peek + thin cloud ----
        Shape {
            visible: root.icon === "cloudy"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.72)
                strokeWidth: root.strokeWidth * 0.9
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: root.isNight
                        ? "M 17.8 9.2 A 3.4 3.4 0 0 1 13.8 5.2 A 3.6 3.6 0 1 0 17.8 9.2"
                        : "M 12.6 9.8 A 3.4 3.4 0 1 1 18.2 12.2 M 15.6 3.5 L 15.6 5.0 M 20.6 8.5 L 22.0 8.5 M 19.2 4.9 L 20.2 3.9 M 11.8 4.9 L 10.8 3.9"
                }
            }
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 6.5 19.2 L 16.8 19.2 A 3.3 3.3 0 0 0 17.2 12.6 A 4.6 4.6 0 0 0 8.4 11.4 A 3.9 3.9 0 0 0 6.5 19.2 Z" }
            }
        }

        // ---- OVERCAST: layered minimal clouds ----
        Shape {
            visible: root.icon === "overcast"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.55)
                strokeWidth: root.strokeWidth * 0.85
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 10.2 9.4 A 3.8 3.8 0 0 1 17.4 10.2 A 2.7 2.7 0 0 1 18.8 15.0" }
            }
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 5.6 18.8 L 16.4 18.8 A 3.4 3.4 0 0 0 16.8 12.0 A 4.8 4.8 0 0 0 7.6 10.8 A 4.0 4.0 0 0 0 5.6 18.8 Z" }
            }
        }

        // ---- MIST: three delicate drifting fog lines ----
        Shape {
            visible: root.icon === "mist"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.9)
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 3.5 8.5 Q 8.0 6.8 12.0 8.5 T 20.5 8.5" }
            }
            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.72)
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 2.5 13.0 Q 7.5 11.3 12.0 13.0 T 21.5 13.0" }
            }
            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.52)
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 5.0 17.5 Q 9.0 16.0 13.0 17.5 T 19.5 17.5" }
            }
            transform: Translate { x: root.animated ? Math.sin(root.phase) * 1.1 : 0 }
        }

        // ---- RAIN: minimal cloud + crisp slanted rain streaks ----
        Shape {
            visible: root.icon === "rain"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 5.8 14.8 L 17.0 14.8 A 3.2 3.2 0 0 0 17.4 8.4 A 4.6 4.6 0 0 0 8.6 7.3 A 3.8 3.8 0 0 0 5.8 14.8 Z" }
            }
            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.82)
                strokeWidth: root.strokeWidth * 0.9
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 8.2 17.6 L 7.0 21.0 M 12.4 17.6 L 11.2 21.0 M 16.6 17.6 L 15.4 21.0" }
            }
        }

        // ---- SNOW: minimal cloud + delicate snow dots/crosses ----
        Shape {
            visible: root.icon === "snow"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 5.8 14.5 L 17.0 14.5 A 3.2 3.2 0 0 0 17.4 8.2 A 4.6 4.6 0 0 0 8.6 7.1 A 3.8 3.8 0 0 0 5.8 14.5 Z" }
            }
            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.88)
                strokeWidth: root.strokeWidth * 1.15
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M 8.0 18.2 L 8.0 18.3 M 12.0 20.2 L 12.0 20.3 M 16.0 18.2 L 16.0 18.3 M 10.0 21.2 L 10.0 21.3 M 14.0 17.4 L 14.0 17.5" }
            }
        }

        // ---- STORM: cloud + razor lightning bolt ----
        Shape {
            visible: root.icon === "storm"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 6.0 14.6 L 9.0 14.6 M 15.2 14.6 L 17.2 14.6 A 3.2 3.2 0 0 0 17.6 8.2 A 4.6 4.6 0 0 0 8.8 7.1 A 3.8 3.8 0 0 0 6.0 14.6" }
            }
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth * 0.98
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 13.0 12.2 L 10.4 16.8 L 13.4 16.8 L 11.2 21.6" }
            }
        }

        // ---- WIND ----
        Shape {
            visible: root.icon === "wind"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: "M 3.0 9.0 L 14.5 9.0 A 2.4 2.4 0 1 0 12.5 5.4 "
                        + "M 3.0 13.0 L 18.5 13.0 A 2.3 2.3 0 1 1 16.6 16.6 "
                        + "M 3.0 17.0 L 10.5 17.0 A 2.0 2.0 0 1 1 8.9 20.0"
                }
            }
        }

        // ---- SUNRISE ----
        Shape {
            visible: root.icon === "sunrise"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: "M 3.0 18.5 L 21.0 18.5 M 7.2 18.5 A 4.8 4.8 0 0 1 16.8 18.5 "
                        + "M 12.0 10.5 L 12.0 4.5 M 9.4 7.1 L 12.0 4.5 L 14.6 7.1 "
                        + "M 5.4 12.5 L 6.8 13.7 M 18.6 12.5 L 17.2 13.7"
                }
            }
        }

        // ---- SUNSET ----
        Shape {
            visible: root.icon === "sunset"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg {
                    path: "M 3.0 18.5 L 21.0 18.5 M 7.2 18.5 A 4.8 4.8 0 0 1 16.8 18.5 "
                        + "M 12.0 4.5 L 12.0 10.5 M 9.4 7.9 L 12.0 10.5 L 14.6 7.9 "
                        + "M 5.4 12.5 L 6.8 13.7 M 18.6 12.5 L 17.2 13.7"
                }
            }
        }

        // ---- HUMIDITY / DROPLET ----
        Shape {
            visible: root.icon === "humidity" || root.icon === "droplet"
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.strokeWidth
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: "M 12.0 3.6 C 12.0 3.6 6.2 10.4 6.2 14.4 A 5.8 5.8 0 0 0 17.8 14.4 C 17.8 10.4 12.0 3.6 12.0 3.6 Z" }
            }
        }
    }
}
