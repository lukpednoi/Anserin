import QtQuick
import QtQuick.Shapes
import "../"

// The Classic Network style drawn still with made-up data, for its card in Edit panel → Style (and the Before/After
// pictures of the Gargantua warning). It follows NetworkPopup's look: the connected network in the core, its five
// details orbiting it on lines, the Wi-Fi/Bluetooth tabs and the power button. It fills the page's design size
// (565 × 525), reads only the theme, and runs nothing: no scans, no timers, no opening to wait for.
Item {
    id: root
    width: 565; height: 525

    readonly property color accent: Qt.lighter(ThemeBackend.sapphire, 1.15)   // NetworkPopup's sharedAccent
    readonly property color ink: ThemeBackend.crust
    readonly property real cx: width / 2
    readonly property real cy: (height - 51) / 2        // the orbit's middle, above the tabs
    readonly property real radX: 200
    readonly property real radY: 140
    // the same details, in the same order round the orbit, as a connected Wi-Fi shows
    readonly property var nodes: [
        { icon: "󰤨", text: "72%" },
        { icon: "󰦝", text: "WPA2" },
        { icon: "󰩟", text: "192.168.1.24", dim: true },
        { icon: "󰖧", text: "5180" },
        { icon: "󰍉", text: "Scan", dim: true }
    ]
    function nodeX(i) { return cx + Math.cos(i / nodes.length * Math.PI * 2) * radX; }
    function nodeY(i) { return cy + Math.sin(i / nodes.length * Math.PI * 2) * radY; }

    // two soft glows drifting behind
    Rectangle {
        width: parent.width * 0.8; height: width; radius: width / 2
        x: root.cx - width / 2 + 70; y: root.cy - height / 2 + 40
        color: root.accent; opacity: 0.03
    }
    Rectangle {
        width: parent.width * 0.9; height: width; radius: width / 2
        x: root.cx - width / 2 - 80; y: root.cy - height / 2 - 50
        color: Qt.darker(root.accent, 1.25); opacity: 0.02
    }

    // the three rings
    Repeater {
        model: 3
        Rectangle {
            required property int index
            width: 182 + index * 107; height: width; radius: width / 2
            x: root.cx - width / 2; y: root.cy - height / 2
            color: "transparent"
            border.color: root.accent; border.width: 1
            opacity: 0.08 - index * 0.02
        }
    }

    // the lines from the core to each detail (under both)
    Repeater {
        model: root.nodes.length
        Shape {
            required property int index
            readonly property real ex: root.nodeX(index)
            readonly property real ey: root.nodeY(index)
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Qt.lighter(root.accent, 1.35), 0.55)
                strokeWidth: 1.5
                fillColor: "transparent"
                startX: root.cx; startY: root.cy
                PathQuad {
                    x: ex; y: ey
                    controlX: (root.cx + ex) / 2 - (ey - root.cy) * 0.12
                    controlY: (root.cy + ey) / 2 + (ex - root.cx) * 0.12
                }
            }
        }
    }

    // the details
    Repeater {
        model: root.nodes
        Rectangle {
            required property var modelData
            required property int index
            width: 124; height: 42; radius: 14
            x: root.nodeX(index) - width / 2; y: root.nodeY(index) - height / 2
            color: Qt.tint(ThemeBackend.base, Qt.alpha(ThemeBackend.surface0, 0.6))
            Row {
                anchors.verticalCenter: parent.verticalCenter
                x: 12; spacing: 7
                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; font.family: ThemeBackend.iconFont; font.pixelSize: 14
                       color: modelData.dim ? root.accent : ThemeBackend.text }
                Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; font.bold: true
                       color: modelData.dim ? Qt.alpha(root.accent, 0.8) : ThemeBackend.text }
            }
        }
    }

    // the core: the connected network
    Rectangle {
        width: 174; height: width; radius: width / 2
        x: root.cx - width / 2; y: root.cy - height / 2
        color: root.accent; opacity: 0.15
    }
    Rectangle {
        width: 154; height: width; radius: width / 2
        x: root.cx - width / 2; y: root.cy - height / 2
        color: "transparent"; border.color: root.accent; border.width: 2; opacity: 0.3
    }
    Rectangle {
        width: 140; height: width; radius: width / 2
        x: root.cx - width / 2; y: root.cy - height / 2
        border.color: Qt.lighter(root.accent, 1.1); border.width: 2
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(root.accent, 1.15) }
            GradientStop { position: 1; color: root.accent }
        }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "󰤨"; font.family: ThemeBackend.iconFont; font.pixelSize: 30; color: root.ink }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Home_5G"; font.family: ThemeBackend.fontFamily; font.pixelSize: 14; font.bold: true; color: root.ink }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Connected"; font.family: ThemeBackend.fontFamily; font.pixelSize: 10; font.bold: true; color: Qt.alpha(root.ink, 0.8) }
        }
    }

    // the Wi-Fi / Bluetooth tabs
    Rectangle {
        width: 250; height: 34; radius: height / 2
        x: root.cx - width / 2; y: root.height - 21 - height
        color: ThemeBackend.surface0
        Rectangle { width: parent.width / 2; height: parent.height; radius: parent.radius; color: Qt.alpha(root.accent, 0.45) }
        Row {
            anchors.fill: parent
            Repeater {
                model: [{ icon: "󰤨", text: "Wi-Fi" }, { icon: "󰂯", text: "Bluetooth" }]
                Item {
                    required property var modelData
                    width: 125; height: 34
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.icon; font.family: ThemeBackend.iconFont; font.pixelSize: 12; color: ThemeBackend.text }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.text; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; color: ThemeBackend.text }
                    }
                }
            }
        }
    }

    // the power button (on)
    Rectangle {
        width: 36; height: width; radius: width / 2
        x: root.width - 21 - width; y: root.height - 21 - height
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Qt.lighter(root.accent, 1.15) }
            GradientStop { position: 1; color: root.accent }
        }
        Text { anchors.centerIn: parent; text: "󰐥"; font.family: ThemeBackend.iconFont; font.pixelSize: 16; color: root.ink }
    }
}
