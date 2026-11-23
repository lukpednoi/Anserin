import QtQuick

// Smart Home Expressive Circular Arc Gauge (used in System Telemetry & Wellbeing!)
// Bouncy hover/tap scale, diagonal top-left -> bottom-right gradient arc, thin Smart Mirror numerals.
Item {
    id: g
    property real value: 0.42           // 0..1
    property string label: "CPU"
    property string valueText: "42%"
    property string icon: "󰍛"
    property bool selected: false
    property real cornerRadius: 16
    property bool darkMode: true
    property bool liquidGlass: false
    property color surface: "#171a20"
    property color surfaceHover: "#222630"
    property color accent: "#a5c8ff"
    property color accent2: "#dabde2"
    property color textColor: "#edf1f8"
    property color subColor: "#8d96a8"
    property string uiFont: "Noto Sans"
    property string iconFont: "Symbols Nerd Font Mono"

    signal clicked()

    implicitWidth: 140
    implicitHeight: 118
    height: implicitHeight

    SpringVal { id: valSp; target: Math.max(0, Math.min(1, g.value)); stiffness: 220; damping: 0.62; eps: 0.002 }
    SpringVal { id: scSp; target: ma.pressed ? 0.95 : (hov.hovered ? 1.025 : 1.0); stiffness: 520; damping: 0.45; eps: 0.001 }
    SpringVal { id: selSp; target: g.selected ? 1.0 : 0.0; stiffness: 280; damping: 0.66; eps: 0.005 }

    scale: scSp.value

    Rectangle {
        anchors.fill: parent
        radius: Math.max(12, Math.min(20, g.cornerRadius))
        color: g.liquidGlass
            ? Qt.rgba(hov.hovered ? g.surfaceHover.r : g.surface.r,
                      hov.hovered ? g.surfaceHover.g : g.surface.g,
                      hov.hovered ? g.surfaceHover.b : g.surface.b, g.darkMode ? 0.56 : 0.68)
            : (hov.hovered ? g.surfaceHover : g.surface)
        border.width: 1
        border.color: g.selected
            ? Qt.rgba(g.accent.r, g.accent.g, g.accent.b, 0.48)
            : (g.darkMode ? Qt.rgba(1, 1, 1, hov.hovered ? 0.14 : 0.07) : Qt.rgba(0, 0, 0, hov.hovered ? 0.12 : 0.06))
        clip: true
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        // Soft diagonal top-left -> bottom-right highlight when selected
        Canvas {
            anchors.fill: parent
            visible: selSp.value > 0.01
            opacity: Math.max(0, Math.min(1, selSp.value))
            readonly property var _k: [Math.round(width), Math.round(height), g.accent.toString(), g.accent2.toString(), g.darkMode]
            on_KChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const r = Math.max(12, Math.min(20, g.cornerRadius));
                const grad = ctx.createLinearGradient(0, 0, width, height);
                grad.addColorStop(0.0, Qt.rgba(g.accent.r, g.accent.g, g.accent.b, g.darkMode ? 0.22 : 0.18));
                grad.addColorStop(1.0, Qt.rgba(g.accent2.r, g.accent2.g, g.accent2.b, 0.05));
                ctx.fillStyle = grad;
                ctx.beginPath();
                ctx.roundedRect(0, 0, width, height, r, r);
                ctx.fill();
            }
        }
    }

    // Arc dial canvas (240° sweep)
    Canvas {
        id: arcCv
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 10
        width: 78; height: 74
        readonly property var _k: [Math.round(valSp.value * 400), g.accent.toString(), g.accent2.toString(), g.darkMode, width]
        on_KChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width * 0.5;
            const cy = height * 0.54;
            const r = 30;
            const startA = Math.PI * 0.78;
            const totalSweep = Math.PI * 1.44;
            const endA = startA + totalSweep;

            ctx.lineCap = "round";
            ctx.lineWidth = 4.6;

            // Track
            ctx.strokeStyle = g.darkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10);
            ctx.beginPath();
            ctx.arc(cx, cy, r, startA, endA);
            ctx.stroke();

            // Active value arc with diagonal gradient
            const v = Math.max(0.02, Math.min(1.0, valSp.value));
            const valEnd = startA + totalSweep * v;
            const grad = ctx.createLinearGradient(cx - r, cy - r, cx + r, cy + r);
            grad.addColorStop(0.0, g.accent);
            grad.addColorStop(1.0, g.accent2);

            ctx.strokeStyle = grad;
            ctx.lineWidth = 5.0;
            ctx.beginPath();
            ctx.arc(cx, cy, r, startA, valEnd);
            ctx.stroke();

            // Luminous tip dot
            const tx = cx + Math.cos(valEnd) * r;
            const ty = cy + Math.sin(valEnd) * r;
            ctx.fillStyle = g.darkMode ? "#ffffff" : g.accent;
            ctx.beginPath();
            ctx.arc(tx, ty, 3.0, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    // Center readout inside arc
    Column {
        anchors.centerIn: arcCv
        anchors.verticalCenterOffset: 2
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.valueText
            font.family: g.uiFont; font.pixelSize: 14; font.weight: Font.Light; font.letterSpacing: -0.2
            color: g.textColor
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: g.icon
            font.family: g.iconFont; font.pixelSize: 11
            color: g.accent
        }
    }

    // Bottom label
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 10
        text: g.label
        font.family: g.uiFont; font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: 1.0
        color: g.selected ? g.accent : g.subColor
        Behavior on color { ColorAnimation { duration: 160 } }
    }

    HoverHandler { id: hov }
    MouseArea {
        id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
        onClicked: { scSp.kick(0.75); g.clicked(); }
    }
}
