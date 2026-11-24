import QtQuick
import QtQuick.Layouts
import "../../"

// System Monitor Style: Minimal (Hardware Bento RAM-Saver Grid).
// Drawn at 625 x 565 design coordinates and scaled smoothly to its host slot (SystemPage / PanelEditor).
// Zero ShaderEffects, zero continuous 60fps loops — Canvas gauges/sparklines repaint ONLY when SystemFeed ticks!
Item {
    id: wrap

    property var feed: null
    property bool preview: false

    readonly property real sx: width > 0 ? width / 625.0 : 1.0
    readonly property real sy: height > 0 ? height / 565.0 : 1.0

    Rectangle {
        id: root
        width: 625
        height: 565
        transform: Scale { xScale: wrap.sx; yScale: wrap.sy }
        radius: Math.min(ThemeBackend.clampedBorderRadius, 22)
        color: "#0e1118"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.10)
        clip: true

        readonly property string uiFont: ThemeBackend.fontFamily
        readonly property string iconFont: ThemeBackend.iconFont
        readonly property color cAccent: ThemeBackend.mauve
        readonly property color cAccent2: ThemeBackend.blue
        readonly property color cGreen: ThemeBackend.green
        readonly property color cAmber: ThemeBackend.yellow
        readonly property color cardBg: "#151923"
        readonly property color cardBorder: Qt.rgba(1, 1, 1, 0.065)
        readonly property color ink: "#f2f5fb"
        readonly property color inkSoft: Qt.rgba(0.95, 0.96, 0.99, 0.68)
        readonly property color inkMuted: Qt.rgba(0.95, 0.96, 0.99, 0.42)
        readonly property color trackBg: Qt.rgba(1, 1, 1, 0.09)

        readonly property var f: wrap.feed
        readonly property int cpuPct: f ? Math.round(f.cpu) : 0
        readonly property int cpuTemp: f ? Math.round(f.temp) : 0
        readonly property int gpuPct: f ? f.gpuPct : 0
        readonly property int gpuTemp: f ? f.gpuTemp : 0
        readonly property int ramPct: f ? Math.round(f.ram) : 0
        readonly property int diskPct: f ? f.activeDiskPct : 0

        component BlobPctBadge: Item {
            id: bdg
            property int pct: 0
            property int lobes: 5
            property color fillCol: "#252b3b"
            property color textCol: "#f2f5fb"
            width: 66; height: 66

            Canvas {
                anchors.fill: parent
                readonly property var _k: [bdg.lobes, bdg.fillCol.toString(), width, height]
                on_KChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset();
                    const cx = width * 0.5, cy = height * 0.5;
                    const R = Math.min(width, height) * 0.43;
                    const amp = bdg.lobes <= 5 ? 0.10 : 0.065;
                    ctx.beginPath();
                    const steps = 72;
                    for (let i = 0; i <= steps; i++) {
                        const a = (i / steps) * Math.PI * 2;
                        const r = R * (1.0 + amp * Math.cos(bdg.lobes * a - 0.35));
                        const x = cx + Math.cos(a) * r;
                        const y = cy + Math.sin(a) * r;
                        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                    }
                    ctx.closePath();
                    ctx.fillStyle = bdg.fillCol;
                    ctx.fill();
                    ctx.lineWidth = 1;
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.09);
                    ctx.stroke();
                }
            }
            Text {
                anchors.centerIn: parent
                text: bdg.pct + " %"
                font.family: root.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold
                color: bdg.textCol
            }
        }

        component ArcGauge: Item {
            id: ag
            property real frac: 0.0
            property color arcColor: root.cAccent
            property string centerText: "0 %"
            width: 76; height: 76

            Canvas {
                anchors.fill: parent
                readonly property var _k: [Math.round(ag.frac * 100), ag.arcColor.toString(), width, height]
                on_KChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset();
                    const cx = width * 0.5, cy = height * 0.5;
                    const R = Math.min(width, height) * 0.41;
                    const startA = Math.PI * 0.75;
                    const sweep = Math.PI * 1.50;
                    ctx.lineCap = "round";
                    ctx.lineWidth = 7.5;
                    ctx.beginPath();
                    ctx.arc(cx, cy, R, startA, startA + sweep, false);
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.11);
                    ctx.stroke();
                    const fv = Math.max(0.02, Math.min(1.0, ag.frac));
                    ctx.beginPath();
                    ctx.arc(cx, cy, R, startA, startA + sweep * fv, false);
                    ctx.strokeStyle = ag.arcColor;
                    ctx.stroke();
                }
            }
            Text {
                anchors.centerIn: parent
                text: ag.centerText
                font.family: root.uiFont; font.pixelSize: 14; font.weight: Font.DemiBold
                color: root.ink
            }
        }

        component MiniIconRing: Item {
            id: mir
            property real frac: 0.0
            property color ringColor: root.cAccent
            property string glyph: "󰻠"
            property color glyphColor: ThemeBackend.red
            width: 32; height: 32
            Canvas {
                anchors.fill: parent
                readonly property var _k: [Math.round(mir.frac * 100), mir.ringColor.toString()]
                on_KChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d"); ctx.reset();
                    const cx = width * 0.5, cy = height * 0.5, R = 13.5;
                    ctx.lineWidth = 2.6; ctx.lineCap = "round";
                    ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2);
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.11); ctx.stroke();
                    ctx.beginPath(); ctx.arc(cx, cy, R, -Math.PI * 0.5, -Math.PI * 0.5 + Math.PI * 2 * Math.max(0.05, mir.frac));
                    ctx.strokeStyle = mir.ringColor; ctx.stroke();
                }
            }
            Text { anchors.centerIn: parent; text: mir.glyph; font.family: root.iconFont; font.pixelSize: 13; color: mir.glyphColor }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 11

            // ==================== ROW 1: CPU & GPU ====================
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 142; Layout.maximumHeight: 142; Layout.fillHeight: false; spacing: 10

                // CPU CARD
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                    radius: 18; color: root.cardBg; border.width: 1; border.color: root.cardBorder

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 7

                            Row {
                                spacing: 9
                                MiniIconRing {
                                    frac: root.cpuPct / 100.0
                                    ringColor: root.cAccent; glyph: "󰻠"; glyphColor: ThemeBackend.red
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Text { text: "CPU"; font.family: root.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.ink }
                                    Text {
                                        text: root.f ? root.f.cpuSub : "—"
                                        font.family: root.uiFont; font.pixelSize: 10; color: root.inkMuted
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: "󰔏"; font.family: root.iconFont; font.pixelSize: 11; color: root.inkMuted }
                                Text { text: root.cpuTemp + " °C"; font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Medium; color: root.ink }
                                Rectangle {
                                    Layout.fillWidth: true; height: 5; radius: 2.5; color: root.trackBg
                                    Rectangle {
                                        width: parent.width * Math.max(0.06, Math.min(1.0, root.cpuTemp / 95.0))
                                        height: parent.height; radius: 2.5; color: root.ink
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                                Row {
                                    spacing: 2; Layout.alignment: Qt.AlignBottom
                                    Text { text: "P"; font.family: root.uiFont; font.pixelSize: 8; color: root.inkMuted; anchors.verticalCenter: parent.verticalCenter; rightPadding: 2 }
                                    Repeater {
                                        model: (root.f && root.f.pCores && root.f.pCores.length) ? root.f.pCores : [10, 14, 12, 16]
                                        Item {
                                            required property real modelData
                                            width: 5; height: 24
                                            Rectangle { anchors.fill: parent; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.08) }
                                            Rectangle {
                                                anchors.bottom: parent.bottom; width: parent.width
                                                height: Math.max(3, parent.height * (modelData / 100.0))
                                                radius: 1.5; color: root.cAccent
                                            }
                                        }
                                    }
                                }
                                Row {
                                    visible: root.f && root.f.eCores && root.f.eCores.length > 0
                                    spacing: 2; Layout.alignment: Qt.AlignBottom
                                    Text { text: "E"; font.family: root.uiFont; font.pixelSize: 8; color: root.inkMuted; anchors.verticalCenter: parent.verticalCenter; rightPadding: 2 }
                                    Repeater {
                                        model: (root.f && root.f.eCores) ? root.f.eCores : []
                                        Item {
                                            required property real modelData
                                            width: 4; height: 24
                                            Rectangle { anchors.fill: parent; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.08) }
                                            Rectangle {
                                                anchors.bottom: parent.bottom; width: parent.width
                                                height: Math.max(3, parent.height * (modelData / 100.0))
                                                radius: 1.5; color: root.inkSoft
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        BlobPctBadge {
                            Layout.alignment: Qt.AlignVCenter
                            pct: root.cpuPct
                            lobes: 5
                            fillCol: "#252b3b"
                        }
                    }
                }

                // GPU CARD
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                    radius: 18; color: root.cardBg; border.width: 1; border.color: root.cardBorder

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 8

                        ColumnLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

                            Row {
                                spacing: 9
                                MiniIconRing {
                                    frac: root.gpuPct / 100.0
                                    ringColor: root.cAccent2; glyph: "󰢮"; glyphColor: root.cGreen
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter; spacing: 1
                                    Row {
                                        spacing: 6
                                        Text { text: "GPU"; font.family: root.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: root.ink }
                                        Rectangle {
                                            height: 15; width: gIdxT.implicitWidth + 10; radius: 7.5; anchors.verticalCenter: parent.verticalCenter
                                            color: Qt.rgba(1, 1, 1, 0.10)
                                            Text {
                                                id: gIdxT; anchors.centerIn: parent
                                                text: root.f ? ((root.f.gpuIdx + 1) + "/" + Math.max(1, root.f.gpuCount)) : "1/1"
                                                font.family: root.uiFont; font.pixelSize: 8; color: root.inkSoft
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                enabled: !wrap.preview && root.f && root.f.gpuCount > 1
                                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                onClicked: { root.f.cycleGpu(); Sounds.playSfx("reusables/iconbutton/click.wav"); }
                                            }
                                        }
                                    }
                                    Text {
                                        width: 146; elide: Text.ElideRight
                                        text: root.f ? root.f.gpuName : "GPU"
                                        font.family: root.uiFont; font.pixelSize: 10; color: root.inkMuted
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: "󰔏"; font.family: root.iconFont; font.pixelSize: 11; color: root.inkMuted }
                                Text { text: root.gpuTemp > 0 ? (root.gpuTemp + " °C") : "—"; font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Medium; color: root.ink }
                                Rectangle {
                                    Layout.fillWidth: true; height: 5; radius: 2.5; color: root.trackBg
                                    Rectangle {
                                        width: parent.width * Math.max(0.06, Math.min(1.0, root.gpuTemp / 95.0))
                                        height: parent.height; radius: 2.5; color: root.ink
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true; spacing: 6
                                Text { text: "󰍛"; font.family: root.iconFont; font.pixelSize: 11; color: root.inkMuted }
                                Text { text: root.f ? root.f.vramText : "—"; font.family: root.uiFont; font.pixelSize: 10; color: root.inkSoft }
                                Rectangle {
                                    Layout.fillWidth: true; height: 5; radius: 2.5; color: root.trackBg
                                    Rectangle {
                                        width: parent.width * Math.max(0.06, Math.min(1.0, root.f ? root.f.vramFrac : 0.1))
                                        height: parent.height; radius: 2.5; color: root.cAccent2
                                    }
                                }
                            }
                        }

                        BlobPctBadge {
                            Layout.alignment: Qt.AlignVCenter
                            pct: root.gpuPct
                            lobes: 10
                            fillCol: "#272c3d"
                        }
                    }
                }
            }

            // ==================== ROW 2: RAM RING | DISK RING | NET GRAPH ====================
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 136; Layout.maximumHeight: 136; Layout.fillHeight: false; spacing: 10

                // RAM RING CARD
                Rectangle {
                    Layout.preferredWidth: 138; Layout.fillHeight: true
                    radius: 18; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        ArcGauge {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 72; height: 72
                            frac: root.ramPct / 100.0
                            arcColor: root.cAccent
                            centerText: root.ramPct + " %"
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "RAM"; font.family: root.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold; color: root.ink }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.f ? root.f.ramSub : "—"; font.family: root.uiFont; font.pixelSize: 10; color: root.inkMuted }
                    }
                }

                // DISK RING CARD
                Rectangle {
                    Layout.preferredWidth: 138; Layout.fillHeight: true
                    radius: 18; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                    Column {
                        anchors.centerIn: parent; spacing: 3
                        ArcGauge {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 72; height: 72
                            frac: root.diskPct / 100.0
                            arcColor: root.cAccent2
                            centerText: root.diskPct + " %"
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; spacing: 4
                            Text { text: root.f ? root.f.diskMount : "/"; font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.DemiBold; color: root.ink }
                            Rectangle {
                                height: 14; width: dIdxT.implicitWidth + 8; radius: 7; anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(1, 1, 1, 0.10)
                                Text {
                                    id: dIdxT; anchors.centerIn: parent
                                    text: root.f ? ((root.f.diskIdx + 1) + "/" + Math.max(1, root.f.diskCount)) : "1/1"
                                    font.family: root.uiFont; font.pixelSize: 8; color: root.inkSoft
                                }
                            }
                            Text {
                                visible: root.f && root.f.diskTemp > 0
                                text: (root.f ? root.f.diskTemp : 0) + "°"
                                font.family: root.uiFont; font.pixelSize: 10; color: root.inkSoft
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.f ? root.f.diskSub : "—"; font.family: root.uiFont; font.pixelSize: 10; color: root.inkMuted }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !wrap.preview && root.f && root.f.diskCount > 1
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: { root.f.cycleDisk(); Sounds.playSfx("reusables/iconbutton/click.wav"); }
                    }
                }

                // NET LIVE SPARKLINE CARD
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 18; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 8
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: "󰛳"; font.family: root.iconFont; font.pixelSize: 13; color: root.cAccent }
                            Text { text: "Net"; font.family: root.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: root.ink }
                            Text { text: "↓ " + (root.f ? root.f.netDownText : "0 B/s"); font.family: root.uiFont; font.pixelSize: 10; color: root.inkSoft }
                            Text { text: "↑ " + (root.f ? root.f.netUpText : "0 B/s"); font.family: root.uiFont; font.pixelSize: 10; color: root.inkMuted }
                            Item { Layout.fillWidth: true }
                            Text { text: root.f ? root.f.netPeakText : "0B"; font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.DemiBold; color: root.cAccent }
                        }

                        Canvas {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            readonly property var _k: [root.f ? root.f.detailTick : 0, root.cAccent.toString(), width, height]
                            on_KChanged: requestPaint()
                            onPaint: {
                                const ctx = getContext("2d"); ctx.reset();
                                if (width <= 8 || height <= 8) return;
                                const arr = (root.f && root.f.netHist && root.f.netHist.length) ? root.f.netHist : [0.05, 0.08, 0.05, 0.12, 0.08, 0.15, 0.10, 0.18, 0.12, 0.22, 0.16, 0.20];
                                const n = arr.length;
                                ctx.beginPath(); ctx.moveTo(0, height - 2); ctx.lineTo(width, height - 2);
                                ctx.lineWidth = 1; ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.10); ctx.stroke();

                                const step = width / Math.max(1, n);
                                const bw = Math.max(3, step * 0.52);
                                for (let i = 0; i < n; i++) {
                                    const h = Math.max(3, arr[i] * (height - 8));
                                    const x = i * step + (step - bw) * 0.5;
                                    const g = ctx.createLinearGradient(0, height - 2 - h, 0, height - 2);
                                    g.addColorStop(0.0, Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.75));
                                    g.addColorStop(1.0, Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.12));
                                    ctx.fillStyle = g;
                                    ctx.fillRect(x, height - 2 - h, bw, h);
                                    ctx.fillStyle = root.cAccent;
                                    ctx.fillRect(x, height - 2 - h, bw, 2);
                                }
                            }
                        }
                    }
                }
            }

            // ==================== ROW 3: POWER/BATTERY/PING (LEFT) + PROCESSES (RIGHT) ====================
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10

                ColumnLayout {
                    Layout.fillWidth: false
                    Layout.preferredWidth: 246
                    Layout.maximumWidth: 246
                    Layout.minimumWidth: 246
                    Layout.fillHeight: true
                    spacing: 10

                    // POWER CARD
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 104; Layout.fillHeight: false
                        radius: 18; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                        Column {
                            anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 13; spacing: 5
                            RowLayout {
                                width: parent.width; spacing: 6
                                Text { text: "󱐋"; font.family: root.iconFont; font.pixelSize: 13; color: root.cAmber }
                                Text { text: "Power"; font.family: root.uiFont; font.pixelSize: 12; font.weight: Font.Medium; color: root.inkSoft }
                                Rectangle {
                                    Layout.preferredHeight: 20; Layout.preferredWidth: profR.implicitWidth + 14; radius: 10
                                    color: profMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.09)
                                    Row {
                                        id: profR; anchors.centerIn: parent; spacing: 4
                                        Text { text: root.f ? root.f.powerProfile : "Balanced"; font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Medium; color: root.ink }
                                        Text { visible: root.f && root.f.hasPowerProfiles; text: "󰅀"; font.family: root.iconFont; font.pixelSize: 10; color: root.inkSoft }
                                    }
                                    MouseArea {
                                        id: profMa; anchors.fill: parent; hoverEnabled: true
                                        enabled: !wrap.preview && root.f && root.f.hasPowerProfiles
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: { root.f.cyclePower(); Sounds.playSfx("reusables/iconbutton/click.wav"); }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                            }
                            Text {
                                text: (root.f && root.f.powerWatts !== "—") ? (root.f.powerWatts + " W") : "—"
                                font.family: root.uiFont; font.pixelSize: 23; font.weight: Font.Bold; color: root.ink
                            }
                            Text { width: parent.width; elide: Text.ElideRight; text: root.f ? root.f.powerStatus : "AC power"; font.family: root.uiFont; font.pixelSize: 10; color: root.inkMuted }
                        }
                    }

                    // BATTERY + PING
                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                            radius: 18; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                            Column {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 12; spacing: 5
                                Row {
                                    spacing: 5
                                    Text { text: (root.f && root.f.charging) ? "󰂄" : "󰁹"; font.family: root.iconFont; font.pixelSize: 12; color: root.cGreen; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Battery"; font.family: root.uiFont; font.pixelSize: 11; font.weight: Font.Medium; color: root.inkSoft }
                                }
                                Text { text: (root.f ? root.f.batPct : 0) + " %"; font.family: root.uiFont; font.pixelSize: 21; font.weight: Font.Bold; color: root.ink }
                                Text { width: parent.width; elide: Text.ElideRight; text: (root.f && root.f.batTime) ? root.f.batTime : (root.f ? root.f.batState : "—"); font.family: root.uiFont; font.pixelSize: 10; color: root.inkMuted }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                            radius: 18; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                            Column {
                                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 12; spacing: 5
                                Row {
                                    spacing: 5
                                    Text { text: "󰤨"; font.family: root.iconFont; font.pixelSize: 12; color: root.cAccent; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Ping"; font.family: root.uiFont; font.pixelSize: 11; font.weight: Font.Medium; color: root.inkSoft }
                                }
                                Text {
                                    text: (root.f && root.f.pingMs >= 0) ? (root.f.pingMs + " ms") : "—"
                                    font.family: root.uiFont; font.pixelSize: 21; font.weight: Font.Bold; color: root.ink
                                }
                                Text { text: (root.f && root.f.pingMs >= 0) ? "1.1.1.1" : "Offline"; font.family: root.uiFont; font.pixelSize: 10; color: root.inkMuted }
                            }
                        }
                    }
                }

                // RIGHT: PROCESSES CARD
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    radius: 18; color: root.cardBg; border.width: 1; border.color: root.cardBorder
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 13; spacing: 8

                        RowLayout {
                            Layout.fillWidth: true; Layout.fillHeight: false
                            Text { text: "PROCESSES"; font.family: root.uiFont; font.pixelSize: 10; font.letterSpacing: 1.0; font.weight: Font.DemiBold; color: root.inkMuted }
                            Item { Layout.fillWidth: true }
                            Rectangle {
                                Layout.preferredHeight: 24; Layout.preferredWidth: pSwR.implicitWidth + 10; radius: 12
                                color: Qt.rgba(1, 1, 1, 0.05); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12)
                                Row {
                                    id: pSwR; anchors.centerIn: parent; spacing: 2
                                    Repeater {
                                        model: ["CPU", "Memory"]
                                        Rectangle {
                                            required property var modelData; required property int index
                                            readonly property bool cur: (root.f ? root.f.procSort : 1) === index
                                            height: 18; width: psT.implicitWidth + 12; radius: 9; anchors.verticalCenter: parent.verticalCenter
                                            color: cur ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                                            Text { id: psT; anchors.centerIn: parent; text: modelData; font.family: root.uiFont; font.pixelSize: 10; font.weight: cur ? Font.DemiBold : Font.Normal; color: cur ? root.ink : root.inkMuted }
                                            MouseArea {
                                                anchors.fill: parent; enabled: !wrap.preview; cursorShape: Qt.PointingHandCursor
                                                onClicked: { if (root.f) root.f.procSort = index; Sounds.playSfx("reusables/iconbutton/click.wav"); }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 4
                            Repeater {
                                model: root.f ? (root.f.procSort === 0 ? root.f.topCpuProcs : root.f.topMemProcs) : []
                                Rectangle {
                                    required property var modelData; required property int index
                                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 9
                                    color: pRowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.055) : "transparent"
                                    RowLayout {
                                        anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 8
                                        Text { text: modelData.icon; font.family: root.iconFont; font.pixelSize: 12; color: root.inkMuted }
                                        Text { Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.name; font.family: root.uiFont; font.pixelSize: 11; font.weight: Font.Normal; color: root.ink }
                                        Text { text: modelData.threads; font.family: root.uiFont; font.pixelSize: 10; color: root.inkMuted; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 26 }
                                        Text { text: modelData.val; font.family: root.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold; color: index === 0 ? root.cAccent : root.ink; horizontalAlignment: Text.AlignRight; Layout.preferredWidth: 46 }
                                    }
                                    MouseArea { id: pRowMa; anchors.fill: parent; hoverEnabled: !wrap.preview }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
