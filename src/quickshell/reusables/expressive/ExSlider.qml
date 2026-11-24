import QtQuick
import "../../"

// Expressive slider: the filled part is a moving wave (flat while dragging, so the value is easy to read), a
// tall pill handle that narrows while held, and a plain track. The wave only animates while it is visible.
Item {
    id: root
    property real value: 0.5                // 0..1
    property string icon: ""
    property bool wavy: true
    readonly property bool dragging: ma.pressed
    signal moved(real value)
    function s(v) { return Scaler.s(v); }
    implicitWidth: s(240); implicitHeight: s(44)

    ExSpring { id: shown; token: "spatialDefault"; eps: 0.0005; target: root.value }
    ExSpring { id: amp; token: "effectsDefault"; eps: 0.01; target: (root.wavy && !ma.pressed && root.value > 0.02) ? 1 : 0 }
    ExSpring { id: handleW; token: "spatialFast"; eps: 0.05; target: ma.pressed ? 2 : 4 }
    property real phase: 0
    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 1200; loops: Animation.Infinite; running: root.visible && amp.value > 0.01 }

    readonly property real thick: s(6)
    readonly property real gap: s(6)
    readonly property real hx: shown.value * width

    Canvas {
        id: wave
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        property var key: [root.hx, amp.value, root.phase, width, ThemeBackend.mauve, ThemeBackend.surface1]
        onKeyChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineCap = "round";
            ctx.lineWidth = root.thick;
            const y = height / 2, A = root.s(3.2) * amp.value, L = root.s(34);
            const x0 = root.icon !== "" ? root.s(30) : root.thick / 2;   // leave room for the icon
            const end = Math.max(x0, root.hx - root.gap);
            ctx.strokeStyle = ThemeBackend.mauve;
            ctx.beginPath();
            for (let x = x0; x <= end; x += 1.5) {
                const yy = y + A * Math.sin(2 * Math.PI * x / L - root.phase);
                if (x === x0) ctx.moveTo(x, yy); else ctx.lineTo(x, yy);
            }
            ctx.stroke();
            const start = root.hx + root.gap;
            if (start < width - root.thick / 2) {
                ctx.strokeStyle = ThemeBackend.surface1;
                ctx.beginPath(); ctx.moveTo(start, y); ctx.lineTo(width - root.thick / 2, y); ctx.stroke();
            }
        }
    }
    Rectangle {                  // handle
        width: root.s(handleW.value); height: root.s(30)
        radius: width / 2
        x: root.hx - width / 2; y: (root.height - height) / 2
        color: ThemeBackend.mauve
    }
    Text {                        // icon at the start, on the wave or on the track
        visible: root.icon !== ""
        text: root.icon
        x: root.s(14) - width / 2
        anchors.verticalCenter: parent.verticalCenter
        font.family: ThemeBackend.iconFont; font.pixelSize: root.s(15)
        color: root.hx > root.s(30) ? ThemeBackend.mauve : ThemeBackend.subtext0
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function set(mx) { root.value = Math.max(0, Math.min(1, mx / width)); root.moved(root.value); }
        onPressed: m => { Sounds.playSfx("reusables/draggable/tick.wav", 0.6); set(m.x); }
        onPositionChanged: m => set(m.x)
        onWheel: w => { root.value = Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))); root.moved(root.value); }
    }
}
