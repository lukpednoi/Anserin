import QtQuick
import "../../"
import "."

// System page, style "Graphs": a wide battery strip on top and four live graph cards below, fed every second
// while shown. Opening: the cards rise in one after another, the battery fills and the numbers count up from
// zero, and the graphs draw in from the left; after that the graphs keep sliding, the numbers glide, and behind
// each card's graph solid water filled to its level keeps rolling, in the Quick Actions System monitor's colours
// (its words turn dark where the water covers them), only while shown.
// While charging, a light sweeps through the battery and the bolt pulses.
Item {
    id: page
    required property SystemFeed feed

    property real intro: 0
    readonly property bool settled: intro >= 1
    onVisibleChanged: if (visible) introAnim.restart()
    Component.onCompleted: if (visible) introAnim.restart()
    NumberAnimation { id: introAnim; target: page; property: "intro"; from: 0; to: 1; duration: 1100 }
    // 0..1 for the i-th thing to appear, eased
    function stage(i) { const t = Math.max(0, Math.min(1, (intro - i * 0.1) / 0.5)); return 1 - Math.pow(1 - t, 3); }

    readonly property bool chargingShown: feed.charging && page.visible

    Card {
        id: batCard
        width: parent.width
        height: 140
        opacity: page.stage(0)
        transform: Translate { y: (1 - page.stage(0)) * 18 }

        // a drawn battery that fills with the charge
        Item {
            id: glyph
            x: 24; anchors.verticalCenter: parent.verticalCenter
            width: 132; height: 64
            Rectangle {
                id: shell
                width: parent.width - 8; height: parent.height
                radius: 16; color: "transparent"
                border.width: 3; border.color: Qt.alpha(ThemeBackend.text, 0.35)
                Rectangle {
                    id: level
                    x: 6; y: 6; height: parent.height - 12; radius: 10
                    width: Math.max(radius * 2, (parent.width - 12) * feed.batPct / 100 * page.stage(1))
                    color: feed.batPct <= 20 && !feed.plugged ? ThemeBackend.red : ThemeBackend.mauve
                    clip: true
                    Behavior on width { enabled: page.settled; NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }
                    // the charging light
                    Rectangle {
                        id: sheen
                        visible: page.chargingShown
                        width: 46; height: parent.height
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Qt.alpha("#ffffff", 0) }
                            GradientStop { position: 0.5; color: Qt.alpha("#ffffff", 0.38) }
                            GradientStop { position: 1; color: Qt.alpha("#ffffff", 0) }
                        }
                        NumberAnimation on x { running: page.chargingShown; loops: Animation.Infinite; from: -46; to: level.width; duration: 1600; easing.type: Easing.InOutSine }
                    }
                }
                Icon {
                    anchors.centerIn: parent; visible: feed.plugged; text: "󱐋"; font.pixelSize: 26; color: ThemeBackend.crust
                    SequentialAnimation on scale {
                        running: page.chargingShown; loops: Animation.Infinite
                        NumberAnimation { to: 1.18; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
            }
            Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 22; radius: 3; color: Qt.alpha(ThemeBackend.text, 0.35) }
        }
        Column {
            anchors.left: glyph.right; anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Label { text: Math.round(feed.batPct * page.stage(1)) + "%"; font.pixelSize: 40; font.bold: true }
            Label { text: feed.batState + " · " + feed.batTime; font.pixelSize: 12; color: ThemeBackend.subtext0 }
        }
        Column {
            anchors.right: parent.right; anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            opacity: page.stage(2)
            Column {
                anchors.right: parent.right
                Label { anchors.right: parent.right; text: feed.watts > 0.05 ? feed.watts.toFixed(1) + " W" : "—"; font.pixelSize: 20; font.bold: true }
                Label { anchors.right: parent.right; text: feed.charging ? "charging rate" : "power draw"; font.pixelSize: 11; color: ThemeBackend.subtext1 }
            }
            Column {
                anchors.right: parent.right
                Label { anchors.right: parent.right; text: feed.uptimeText; font.pixelSize: 20; font.bold: true }
                Label { anchors.right: parent.right; text: "uptime"; font.pixelSize: 11; color: ThemeBackend.subtext1 }
            }
        }
    }

    Grid {
        y: batCard.height + 12
        width: parent.width
        height: parent.height - y
        columns: 2
        spacing: 12
        Repeater {
            // The Quick Actions System monitor's colours: solid water in shades of the accent. Four cards made once;
            // their values update in place (a model built from the live values would remake them every frame).
            model: 4
            Card {
                id: card
                required property int index
                readonly property var modelData: [
                { icon: "󰻠", name: "CPU", value: feed.cpu, unit: "%", detail: "last 40 s", hist: feed.cpuHist, fill: Qt.lighter(ThemeBackend.mauve, 1.35) },
                { icon: "󰍛", name: "Memory", value: feed.ram, unit: "%", detail: feed.ramUsedGb.toFixed(1) + " of " + feed.ramTotalGb.toFixed(1) + " GB", hist: feed.ramHist, fill: Qt.lighter(ThemeBackend.mauve, 1.15) },
                { icon: "󰔏", name: "Temperature", value: feed.temp, unit: "°C", detail: "CPU package", hist: feed.tempHist, fill: ThemeBackend.mauve },
                { icon: "󰋊", name: "Disk", value: feed.disk, unit: "%", detail: Math.round(feed.diskUsedGb) + " of " + Math.round(feed.diskTotalGb) + " GB used", hist: null, fill: Qt.darker(ThemeBackend.mauve, 1.15) }
                ][index]
                readonly property real st: page.stage(index + 1)
                readonly property real level: Math.max(0.04, Math.min(1, modelData.value / 100)) * st
                readonly property real waveAmp: level < 0.99 ? 3 + 4 * Math.sin(level * Math.PI) : 0
                width: (parent.width - 12) / 2
                height: (parent.height - 12) / 2
                clip: true
                opacity: st
                transform: Translate { y: (1 - card.st) * 18 }

                // the card's words, drawn twice: normally, and in the dark ink where the water covers them
                Component {
                    id: words
                    Item {
                        property bool inked: false
                        width: card.width; height: card.height
                        Row {
                            x: 16; y: 14; spacing: 8
                            Icon { text: card.modelData.icon; color: parent.parent.inked ? ThemeBackend.crust : card.modelData.fill; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: card.modelData.name; font.bold: true; color: parent.parent.inked ? ThemeBackend.crust : ThemeBackend.text; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Label { anchors.right: parent.right; anchors.rightMargin: 16; y: 10; text: Math.round(card.modelData.value * card.st) + card.modelData.unit
                                font.pixelSize: 22; font.bold: true; color: parent.inked ? ThemeBackend.crust : ThemeBackend.text }
                        Label { x: 16; y: 38; text: card.modelData.detail; font.pixelSize: 11
                                color: parent.inked ? Qt.alpha(ThemeBackend.crust, 0.75) : ThemeBackend.subtext1 }
                    }
                }

                // water up to the card's level, rolling waves across it
                LevelWave {
                    anchors.fill: parent
                    radius: ThemeBackend.clampedBorderRadius
                    fillLevel: card.level
                    waveAmp: card.waveAmp
                    running: page.visible
                    period: 3200 + card.index * 400
                    color1: Qt.lighter(card.modelData.fill, 1.18)
                    color2: card.modelData.fill
                    backColor: Qt.alpha(Qt.darker(card.modelData.fill, 1.25), 0.55)
                }
                Loader { sourceComponent: words }
                Item {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.min(parent.height, Math.max(0, parent.height * card.level))
                    clip: true
                    Loader { y: parent.height - card.height; sourceComponent: words; onLoaded: item.inked = true }
                }

                // the graph draws in from the left, over the water
                Item {
                    visible: modelData.hist !== null
                    anchors.left: parent.left; anchors.bottom: parent.bottom
                    width: parent.width * page.stage(index + 3)
                    height: parent.height - 64
                    clip: true
                    Spark {
                        width: card.width; height: parent.height
                        data: modelData.hist || []
                        capacity: page.feed.capacity
                        interval: page.feed.interval
                        maxValue: 100
                        color: ThemeBackend.text
                    }
                }
            }
        }
    }
}
