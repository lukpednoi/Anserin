import QtQuick
import QtQuick.Shapes
import "../../"
import "."

// System page, style "Activity rings": battery, CPU and memory as three nested rings with a legend, and small
// stat pills along the bottom, fed every second while shown. Opening: the rings sweep round from zero one after
// another, the legend counts up and the pills rise in; after that the rings and numbers glide to each sample.
// While charging, a light runs round the filled part of the battery ring and the bolt pulses.
Item {
    id: page
    required property SystemFeed feed

    property real intro: 0
    readonly property bool settled: intro >= 1
    onVisibleChanged: if (visible) introAnim.restart()
    Component.onCompleted: if (visible) introAnim.restart()
    NumberAnimation { id: introAnim; target: page; property: "intro"; from: 0; to: 1; duration: 1300 }
    function stage(i) { const t = Math.max(0, Math.min(1, (intro - i * 0.1) / 0.5)); return 1 - Math.pow(1 - t, 3); }

    readonly property bool chargingShown: feed.charging && page.visible
    readonly property var rings: [
        { name: "Battery", value: feed.batPct, unit: "%", detail: feed.batState + " · " + feed.batTime, color: ThemeBackend.mauve },
        { name: "CPU", value: feed.cpu, unit: "%", detail: "Processor load", color: ThemeBackend.peach },
        { name: "Memory", value: feed.ram, unit: "%", detail: feed.ramUsedGb.toFixed(1) + " / " + feed.ramTotalGb.toFixed(1) + " GB", color: ThemeBackend.green }
    ]

    Card {
        id: main
        width: parent.width
        height: parent.height - pills.height - 12
        opacity: page.stage(0)

        Item {
            id: ringStack
            x: 24; anchors.verticalCenter: parent.verticalCenter
            width: 290; height: 290
            Repeater {
                model: 3   // made once; values update in place
                Ring {
                    readonly property var modelData: page.rings[index]
                    required property int index
                    anchors.centerIn: parent
                    width: ringStack.width - index * 64; height: width
                    thickness: 24
                    smooth: page.settled
                    value: modelData.value / 100 * page.stage(index + 1)
                    color: modelData.color
                    track: Qt.alpha(modelData.color, 0.12)
                }
            }
            // the charging light, running round the filled part of the battery ring
            Shape {
                id: runner
                anchors.fill: parent
                visible: page.chargingShown
                preferredRendererType: Shape.CurveRenderer
                property real run: 0
                NumberAnimation on run { running: page.chargingShown; loops: Animation.Infinite; from: 0; to: 1; duration: 1800; easing.type: Easing.InOutSine }
                readonly property real filled: 360 * feed.batPct / 100
                ShapePath {
                    strokeColor: Qt.alpha("#ffffff", 0.45); strokeWidth: 24; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: ringStack.width / 2; centerY: ringStack.height / 2
                        radiusX: ringStack.width / 2 - 12; radiusY: radiusX
                        startAngle: -90 + runner.run * Math.max(0, runner.filled - 30)
                        sweepAngle: Math.min(30, runner.filled)
                    }
                }
            }
            Icon {
                anchors.centerIn: parent; text: feed.plugged ? "󱐋" : "󰁹"; font.pixelSize: 30; color: ThemeBackend.mauve
                SequentialAnimation on scale {
                    running: page.chargingShown; loops: Animation.Infinite
                    NumberAnimation { to: 1.25; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                }
            }
        }

        Column {
            anchors.left: ringStack.right; anchors.leftMargin: 28
            anchors.right: parent.right; anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 22
            Repeater {
                model: 3   // made once; values update in place
                Row {
                    id: entry
                    readonly property var modelData: page.rings[index]
                    required property int index
                    readonly property real st: page.stage(index + 1)
                    spacing: 12
                    opacity: st
                    transform: Translate { x: (1 - entry.st) * 16 }
                    Rectangle { width: 5; height: 52 * entry.st; radius: 3; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Label { text: modelData.name; font.pixelSize: 12; color: ThemeBackend.subtext0 }
                        Label { text: Math.round(modelData.value * entry.st) + modelData.unit; font.pixelSize: 26; font.bold: true }
                        Label { text: modelData.detail; font.pixelSize: 11; color: ThemeBackend.subtext1 }
                    }
                }
            }
        }
    }

    Row {
        id: pills
        anchors.bottom: parent.bottom
        width: parent.width
        height: 64
        spacing: 10
        Repeater {
            model: 4   // made once; values update in place
            Card {
                id: pill
                readonly property var modelData: [
                { icon: "󰔏", label: "Temp", value: Math.round(feed.temp) + "°C" },
                { icon: "󰋊", label: "Disk", value: feed.disk + "%" },
                { icon: "󰅐", label: "Uptime", value: feed.uptimeText },
                { icon: "󱐋", label: feed.charging ? "Charging" : "Draw", value: feed.watts > 0.05 ? feed.watts.toFixed(1) + " W" : "—" }
            ][index]
                required property int index
                readonly property real st: page.stage(index + 4)
                width: (pills.width - 30) / 4
                height: pills.height
                opacity: st
                transform: Translate { y: (1 - pill.st) * 16 }
                Row {
                    anchors.centerIn: parent; spacing: 10
                    Icon { text: modelData.icon; color: ThemeBackend.mauve; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        Label { text: modelData.value; font.pixelSize: 15; font.bold: true }
                        Label { text: modelData.label; font.pixelSize: 10; color: ThemeBackend.subtext1 }
                    }
                }
            }
        }
    }
}
