import QtQuick
import "../../"

// Slider drawn as a wavy line (same language as the level dials). The wave only moves while
// the pointer is on it or the value is being changed.
Item {
    id: w
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property color accent: ThemeBackend.mauve
    property bool active: true
    signal moved(real value)
    signal released()
    implicitHeight: 28
    implicitWidth: 200

    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0
    property real shown: frac
    Behavior on shown { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    property bool dragging: false
    property real boost: (hover.containsMouse || dragging) ? 1 : 0.45   // keeps moving gently while the panel is open
    Behavior on boost { NumberAnimation { duration: 260 } }
    property real phase: 0
    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 1500; loops: Animation.Infinite; running: w.active && w.visible && w.boost > 0.01 }
    onShownChanged: cv.requestPaint()
    onPhaseChanged: cv.requestPaint()
    onAccentChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var cy = height / 2, pad = 8, L = width - pad * 2;
            var amp = 1.6 + w.boost * 2.8;
            function y(x) { return cy + amp * Math.sin(x / 9 + w.phase); }
            function line(x0, x1, color, lw) {
                if (x1 - x0 < 0.5) return;
                ctx.beginPath();
                for (var x = x0; x <= x1; x += 2) { if (x === x0) ctx.moveTo(pad + x, y(x)); else ctx.lineTo(pad + x, y(x)); }
                ctx.lineTo(pad + x1, y(x1));
                ctx.lineWidth = lw; ctx.lineCap = "round"; ctx.lineJoin = "round"; ctx.strokeStyle = color; ctx.stroke();
            }
            line(0, L, Qt.alpha(ThemeBackend.surface2, 0.6), 3.5);
            var fx = L * w.shown;
            line(0, fx, w.accent, 4);
            ctx.beginPath(); ctx.arc(pad + fx, y(fx), 6 + w.boost * 1.5, 0, Math.PI * 2);
            ctx.fillStyle = Qt.lighter(w.accent, 1.3); ctx.fill();
        }
    }
    function setFromX(mx) {
        var pad = 8, f = Math.max(0, Math.min(1, (mx - pad) / (width - pad * 2)));
        var raw = from + f * (to - from);
        var v = Math.round(raw / step) * step;
        v = Math.max(from, Math.min(to, v));
        if (v !== value) { if (!tickGate.running) { Sounds.playSfx("reusables/draggable/tick.wav", 0.6); tickGate.start(); } moved(v); }
    }
    Timer { id: tickGate; interval: 70 }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (m) => { w.dragging = true; w.setFromX(m.x); }
        onPositionChanged: (m) => { if (w.dragging) w.setFromX(m.x); }
        onReleased: { w.dragging = false; w.released(); }
        onCanceled: { w.dragging = false; w.released(); }
        onWheel: (e) => { var d = e.angleDelta.y > 0 ? 1 : -1; var v = Math.max(w.from, Math.min(w.to, w.value + d * Math.max(w.step, (w.to - w.from) / 50))); if (v !== w.value) { w.moved(v); w.released(); } }
    }
}
