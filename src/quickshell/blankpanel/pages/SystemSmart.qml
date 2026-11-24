import QtQuick
import QtQuick.Layouts
import "../../"

// System Monitor Style: Smart (matches Smart Weather & Smart Music family).
// Drawn at 625 x 565 design coordinates and scaled smoothly to its host slot (SystemPage / PanelEditor).
// Pure lightweight QML + 1 tiny Canvas polyline repainted only on SystemFeed tick!
Item {
    id: wrap

    property var feed: null
    property bool preview: false
    property bool toneTheme: Config.getSetting("panel.smartSystem.tone", "mirror") === "theme"

    readonly property real sx: width > 0 ? width / 625.0 : 1.0
    readonly property real sy: height > 0 ? height / 565.0 : 1.0

    Rectangle {
        id: root
        width: 625
        height: 565
        transform: Scale { xScale: wrap.sx; yScale: wrap.sy }
        radius: Math.min(ThemeBackend.clampedBorderRadius, 22)
        color: "#06080c"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)
        clip: true

        readonly property string uiFont: ThemeBackend.fontFamily
        readonly property string iconFont: ThemeBackend.iconFont
        readonly property color cAccent: ThemeBackend.mauve
        readonly property color cGreen: ThemeBackend.green
        readonly property color ink: wrap.toneTheme ? Qt.tint("#ffffff", Qt.rgba(cAccent.r, cAccent.g, cAccent.b, 0.22)) : "#ffffff"
        readonly property color inkSoft: Qt.rgba(ink.r, ink.g, ink.b, 0.70)
        readonly property color inkMuted: Qt.rgba(ink.r, ink.g, ink.b, 0.42)
        readonly property color hairline: wrap.toneTheme ? Qt.rgba(cAccent.r, cAccent.g, cAccent.b, 0.26) : Qt.rgba(1, 1, 1, 0.15)
        readonly property color accent: wrap.toneTheme ? cAccent : "#ffffff"

        readonly property var f: wrap.feed
        readonly property int cpuPct: f ? Math.round(f.cpu) : 0
        readonly property int cpuTemp: f ? Math.round(f.temp) : 0
        readonly property int gpuPct: f ? f.gpuPct : 0
        readonly property int gpuTemp: f ? f.gpuTemp : 0
        readonly property int ramPct: f ? Math.round(f.ram) : 0
        readonly property int diskPct: f ? f.activeDiskPct : 0

        // Static soft ambient corner sheen (painted ONCE on size/tone change — zero frame cost!)
        Canvas {
            anchors.fill: parent
            readonly property var _k: [wrap.toneTheme, root.cAccent.toString(), root.radius, width, height]
            on_KChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d"); ctx.reset();
                const r = root.radius;
                ctx.beginPath();
                ctx.moveTo(r, 0); ctx.lineTo(width - r, 0); ctx.arcTo(width, 0, width, r, r);
                ctx.lineTo(width, height - r); ctx.arcTo(width, height, width - r, height, r);
                ctx.lineTo(r, height); ctx.arcTo(0, height, 0, height - r, r);
                ctx.lineTo(0, r); ctx.arcTo(0, 0, r, 0, r);
                ctx.closePath(); ctx.clip();

                const c = wrap.toneTheme ? root.cAccent : Qt.color("#6ea8ff");
                const g1 = ctx.createRadialGradient(width * 0.92, height * 0.12, 10, width * 0.92, height * 0.12, width * 0.55);
                g1.addColorStop(0.0, Qt.rgba(c.r, c.g, c.b, 0.16));
                g1.addColorStop(1.0, "transparent");
                ctx.fillStyle = g1; ctx.fillRect(0, 0, width, height);

                const g2 = ctx.createRadialGradient(width * 0.08, height * 0.90, 10, width * 0.08, height * 0.90, width * 0.48);
                g2.addColorStop(0.0, Qt.rgba(0.35, 0.78, 0.72, 0.10));
                g2.addColorStop(1.0, "transparent");
                ctx.fillStyle = g2; ctx.fillRect(0, 0, width, height);
            }
        }

        component SmartMetric: Item {
            id: sm
            property string label: "CPU"
            property string icon: "󰻠"
            property int pct: 0
            property string sub1: "—"
            property string sub2: "—"
            property bool clickable: false
            signal clicked()

            Column {
                anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                Row {
                    spacing: 6
                    Text { text: sm.icon; font.family: root.iconFont; font.pixelSize: 12; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: sm.label; font.family: root.uiFont; font.pixelSize: 10; font.letterSpacing: 1.4; font.weight: Font.Light; color: root.inkMuted }
                }
                Row {
                    spacing: 2
                    Text { text: sm.pct; font.family: root.uiFont; font.pixelSize: 34; font.weight: Font.ExtraLight; font.letterSpacing: -1.0; color: root.ink; lineHeight: 0.95 }
                    Text { text: "%"; anchors.bottom: parent.bottom; anchors.bottomMargin: 5; font.family: root.uiFont; font.pixelSize: 12; font.weight: Font.Light; color: root.inkMuted }
                }
                Item {
                    width: parent.width; height: 4
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1.2; color: Qt.rgba(1, 1, 1, 0.14) }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0.04, Math.min(1.0, sm.pct / 100.0)); height: 2.0; radius: 1; color: root.accent }
                }
                Text { width: parent.width; elide: Text.ElideRight; text: sm.sub1; font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Light; color: root.inkSoft }
                Text { width: parent.width; elide: Text.ElideRight; text: sm.sub2; font.family: root.uiFont; font.pixelSize: 9; font.weight: Font.Light; color: root.inkMuted }
            }
            MouseArea {
                anchors.fill: parent; enabled: !wrap.preview && sm.clickable; cursorShape: Qt.PointingHandCursor
                onClicked: sm.clicked()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // 1. 4-COLUMN SMART METRIC HERO (CPU | GPU | RAM | DISK)
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 120; Layout.maximumHeight: 120; Layout.fillHeight: false; spacing: 14

                SmartMetric {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                    label: "CPU"; icon: "󰻠"
                    pct: root.cpuPct
                    sub1: root.cpuTemp + " °C" + ((root.f && root.f.cpuGhz > 0) ? (" · " + root.f.cpuGhz.toFixed(1) + " GHz") : "")
                    sub2: root.f ? root.f.cpuSubShort : "—"
                }
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; Layout.topMargin: 10; Layout.bottomMargin: 10; color: Qt.rgba(1, 1, 1, 0.09) }
                SmartMetric {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                    label: "GPU " + (root.f ? ((root.f.gpuIdx + 1) + "/" + Math.max(1, root.f.gpuCount)) : "1/1"); icon: "󰢮"
                    pct: root.gpuPct
                    sub1: (root.gpuTemp > 0 ? (root.gpuTemp + " °C · ") : "") + "VRAM"
                    sub2: root.f ? root.f.vramText : "—"
                    clickable: root.f && root.f.gpuCount > 1
                    onClicked: { root.f.cycleGpu(); Sounds.playSfx("reusables/iconbutton/click.wav"); }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; Layout.topMargin: 10; Layout.bottomMargin: 10; color: Qt.rgba(1, 1, 1, 0.09) }
                SmartMetric {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                    label: "RAM"; icon: "󰍛"
                    pct: root.ramPct
                    sub1: root.f ? root.f.ramSub : "—"
                    sub2: root.f ? root.f.ramFreeText : "—"
                }
                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; Layout.topMargin: 10; Layout.bottomMargin: 10; color: Qt.rgba(1, 1, 1, 0.09) }
                SmartMetric {
                    Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.fillHeight: true
                    label: "DISK " + (root.f ? root.f.diskMount : "/"); icon: "󰋊"
                    pct: root.diskPct
                    sub1: root.f ? root.f.diskSub : "—"
                    sub2: ((root.f && root.f.diskTemp > 0) ? (root.f.diskTemp + " °C · ") : "") + (root.f ? ((root.f.diskIdx + 1) + "/" + Math.max(1, root.f.diskCount)) : "1/1")
                    clickable: root.f && root.f.diskCount > 1
                    onClicked: { root.f.cycleDisk(); Sounds.playSfx("reusables/iconbutton/click.wav"); }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.fillHeight: false
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: root.hairline } GradientStop { position: 0.92; color: "transparent" } }
            }

            // 2. MIDDLE TELEMETRY STRIP: NETWORK POLYLINE | POWER, BATTERY & PING
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 124; Layout.maximumHeight: 124; Layout.fillHeight: false; spacing: 18

                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 6
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Text { text: "NETWORK"; font.family: root.uiFont; font.pixelSize: 10; font.letterSpacing: 1.4; font.weight: Font.Light; color: root.inkMuted }
                        Text { text: "↓ " + (root.f ? root.f.netDownText : "0 B/s"); font.family: root.uiFont; font.pixelSize: 11; font.weight: Font.Normal; color: root.ink }
                        Text { text: "↑ " + (root.f ? root.f.netUpText : "0 B/s"); font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Light; color: root.inkSoft }
                        Item { Layout.fillWidth: true }
                        Text { text: "Peak " + (root.f ? root.f.netPeakText : "0B"); font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Light; color: root.inkMuted }
                    }
                    Canvas {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        readonly property var _k: [root.f ? root.f.detailTick : 0, root.accent.toString(), width, height]
                        on_KChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d"); ctx.reset();
                            if (width <= 8 || height <= 8) return;
                            const arr = (root.f && root.f.netHist && root.f.netHist.length) ? root.f.netHist : [0.05, 0.08, 0.06, 0.14, 0.10, 0.20, 0.14, 0.18];
                            const n = arr.length;
                            const step = width / Math.max(1, n - 1);
                            ctx.beginPath(); ctx.moveTo(0, height - 2); ctx.lineTo(width, height - 2);
                            ctx.lineWidth = 1; ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.10); ctx.stroke();

                            ctx.beginPath();
                            for (let i = 0; i < n; i++) {
                                const x = i * step;
                                const y = (height - 4) - arr[i] * (height - 10);
                                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                            }
                            ctx.lineTo(width, height - 2); ctx.lineTo(0, height - 2); ctx.closePath();
                            const g = ctx.createLinearGradient(0, 0, 0, height);
                            g.addColorStop(0.0, Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22));
                            g.addColorStop(1.0, "transparent");
                            ctx.fillStyle = g; ctx.fill();

                            ctx.beginPath();
                            for (let i = 0; i < n; i++) {
                                const x = i * step;
                                const y = (height - 4) - arr[i] * (height - 10);
                                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                            }
                            ctx.lineWidth = 1.6; ctx.strokeStyle = root.accent; ctx.stroke();
                        }
                    }
                }

                Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; Layout.topMargin: 4; Layout.bottomMargin: 4; color: Qt.rgba(1, 1, 1, 0.10) }

                Column {
                    Layout.preferredWidth: 180; Layout.alignment: Qt.AlignVCenter; spacing: 9
                    Item {
                        width: parent.width; height: 32
                        Row {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 9
                            Text { text: "󱐋"; font.family: root.iconFont; font.pixelSize: 15; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                spacing: 0
                                Text {
                                    text: ((root.f && root.f.powerWatts !== "—") ? (root.f.powerWatts + " W  ·  ") : "") + (root.f ? root.f.powerProfile : "Balanced")
                                    font.family: root.uiFont; font.pixelSize: 12; font.weight: Font.Light
                                    color: pwMa.containsMouse ? root.accent : root.ink
                                }
                                Text { text: root.f ? root.f.powerStatus : "AC power"; font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Light; color: root.inkMuted }
                            }
                        }
                        MouseArea {
                            id: pwMa; anchors.fill: parent; hoverEnabled: !wrap.preview
                            enabled: !wrap.preview && root.f && root.f.hasPowerProfiles
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: { root.f.cyclePower(); Sounds.playSfx("reusables/iconbutton/click.wav"); }
                        }
                    }
                    Row {
                        spacing: 9
                        Text { text: (root.f && root.f.charging) ? "󰂄" : "󰁹"; font.family: root.iconFont; font.pixelSize: 15; color: root.cGreen; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            spacing: 0
                            Text { text: (root.f ? root.f.batPct : 0) + "%  ·  Battery"; font.family: root.uiFont; font.pixelSize: 12; font.weight: Font.Light; color: root.ink }
                            Text { width: 150; elide: Text.ElideRight; text: (root.f && root.f.batTime) ? root.f.batTime : (root.f ? root.f.batState : "—"); font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Light; color: root.inkMuted }
                        }
                    }
                    Row {
                        spacing: 9
                        Text { text: "󰤨"; font.family: root.iconFont; font.pixelSize: 15; color: root.accent; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            spacing: 0
                            Text {
                                text: ((root.f && root.f.pingMs >= 0) ? (root.f.pingMs + " ms") : "—") + "  ·  Ping"
                                font.family: root.uiFont; font.pixelSize: 12; font.weight: Font.Light; color: root.ink
                            }
                            Text {
                                text: (root.f && root.f.pingMs >= 0) ? "1.1.1.1 · Stable" : "Offline"
                                font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Light; color: root.inkMuted
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.fillHeight: false
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: root.hairline } GradientStop { position: 0.92; color: "transparent" } }
            }

            // 3. BOTTOM SMART PROCESSES TABLE
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8

                RowLayout {
                    Layout.fillWidth: true; Layout.fillHeight: false
                    Text { text: "TOP PROCESSES"; font.family: root.uiFont; font.pixelSize: 10; font.letterSpacing: 1.5; font.weight: Font.Light; color: root.inkMuted }
                    Item { Layout.fillWidth: true }
                    Row {
                        spacing: 14
                        Repeater {
                            model: ["CPU", "Memory"]
                            Text {
                                required property var modelData; required property int index
                                readonly property bool cur: (root.f ? root.f.procSort : 1) === index
                                text: modelData; font.family: root.uiFont; font.pixelSize: 10; font.weight: cur ? Font.Normal : Font.Light
                                color: cur ? root.ink : root.inkMuted
                                Rectangle { visible: cur; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.bottom; anchors.topMargin: 3; width: parent.width; height: 1.2; color: root.accent }
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4; enabled: !wrap.preview; cursorShape: Qt.PointingHandCursor
                                    onClicked: { if (root.f) root.f.procSort = index; Sounds.playSfx("reusables/iconbutton/click.wav"); }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 3
                    Repeater {
                        model: root.f ? (root.f.procSort === 0 ? root.f.topCpuProcs : root.f.topMemProcs) : []
                        Item {
                            required property var modelData; required property int index
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Rectangle {
                                visible: index === 0
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                width: 1.8; height: parent.height * 0.62; radius: 1; color: root.accent
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 4; spacing: 10
                                Text { text: modelData.icon; font.family: root.iconFont; font.pixelSize: 12; color: index === 0 ? root.accent : root.inkMuted }
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: modelData.name; font.family: root.uiFont; font.pixelSize: 12; font.weight: index === 0 ? Font.Normal : Font.Light; color: index === 0 ? root.ink : root.inkSoft }
                                Text { text: modelData.threads + " thr"; font.family: root.uiFont; font.pixelSize: 10; font.weight: Font.Light; color: root.inkMuted; Layout.preferredWidth: 46; horizontalAlignment: Text.AlignRight }
                                Text { text: modelData.val; font.family: root.uiFont; font.pixelSize: 12; font.weight: index === 0 ? Font.Medium : Font.Light; color: index === 0 ? root.accent : root.ink; Layout.preferredWidth: 52; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }
                }
            }
        }
    }
}
