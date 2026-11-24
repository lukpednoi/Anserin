import QtQuick
import "../../"

// Expressive circular progress: the done part is a wavy ring that keeps rolling, the rest a thin track, with a
// label in the middle. For gauges (CPU, battery, volume) and countdowns.
Item {
    id: root
    property real value: 0.6                // 0..1
    property string label: ""
    property string sublabel: ""
    property color color: ThemeBackend.mauve
    function s(v) { return Scaler.s(v); }
    implicitWidth: s(96); implicitHeight: s(96)
    ExSpring { id: shown; token: "spatialDefault"; eps: 0.0005; target: Math.max(0, Math.min(1, root.value)) }
    property real phase: 0
    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 2400; loops: Animation.Infinite; running: root.visible }
    Canvas {
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        property var key: [shown.value, root.phase, width, root.color, ThemeBackend.surface1]
        onKeyChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2, R = Math.min(width, height) / 2 - root.s(7);
            const lw = root.s(5), gap = 0.22, waves = 11, A = root.s(2.4);
            const start = -Math.PI / 2, sweep = shown.value * Math.PI * 2;
            ctx.lineCap = "round";
            ctx.lineWidth = lw;
            if (shown.value < 0.97) {
                ctx.strokeStyle = ThemeBackend.surface1;
                ctx.beginPath();
                ctx.arc(cx, cy, R, start + sweep + gap, start + Math.PI * 2 - gap);
                ctx.stroke();
            }
            if (sweep > 0.02) {
                ctx.strokeStyle = root.color;
                ctx.beginPath();
                const steps = Math.max(8, Math.round(sweep * 40));
                for (let i = 0; i <= steps; i++) {
                    const a = start + sweep * i / steps;
                    const r = R + A * Math.sin(waves * a - root.phase);
                    const x = cx + r * Math.cos(a), y = cy + r * Math.sin(a);
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }
    }
    Column {
        anchors.centerIn: parent
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(18); font.weight: Font.Bold
            color: ThemeBackend.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.sublabel !== ""
            text: root.sublabel
            font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(10)
            color: ThemeBackend.subtext0
        }
    }
}
