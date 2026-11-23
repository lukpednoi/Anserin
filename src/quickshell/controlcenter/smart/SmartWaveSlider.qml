import QtQuick

// Smart Home Expressive Spring-Coil Slider:
// 1) Velocity-based left/right handle tilt + elastic sway & bounce-back on release/wheel stop.
// 2) Compression-coil frequency:
//    - At 100% (v >= 0.99): COMPLETELY STRAIGHT taut line (A = 0.0, ตรงแด่ว!) with subtle luminous glow & lock chime!
//    - Lower values (toward 0.0): wave becomes tighter/more frequent with MORE waves packed in,
//      while keeping the wave HEIGHT (amplitude) strictly capped (never taller!).
// 3) WheelHandler { target: null } so wheel doesn't fight page scroll + silky SFX tick & 100% lock chime.
Item {
    id: ws
    property real value: 0.65            // 0..1
    property real step: 0.04
    property color accent: "#a5c8ff"
    property color accent2: "#dabde2"
    property color trackColor: Qt.rgba(1, 1, 1, 0.14)
    property color handleColor: "#ffffff"
    property real thickness: 3.3
    property real maxAmplitude: 3.6      // STRICT constant cap — never grows taller when frequency rises!
    property bool active: true
    signal moved(real v)
    signal stepped()
    signal lockedFull()
    signal released()                    // a drag let go, or a wheel turn that has stopped: time to save

    implicitWidth: 280
    implicitHeight: 38

    property real phase: 0.0
    readonly property bool dragging: ma.pressed
    readonly property bool isFull: shownSp.value >= 0.988
    property real _lastV: value
    property bool _wasFull: value >= 0.99
    property int _lastTickIdx: Math.round(value * 24)

    SpringVal { id: shownSp; target: ws.value; stiffness: ws.dragging ? 660 : 280; damping: ws.dragging ? 0.80 : 0.50; eps: 0.0005 }
    SpringVal { id: handleHSp; target: ws.dragging ? 26 : (ma.containsMouse ? 22 : (ws.isFull ? 20 : 18)); stiffness: 480; damping: 0.42; eps: 0.05 }
    // Under-damped tilt & bow springs -> lean left/right on drag/scroll and bounce back!
    SpringVal { id: tiltSp; target: 0.0; stiffness: 230; damping: 0.21; eps: 0.06 }
    SpringVal { id: bowSp; target: 0.0; stiffness: 290; damping: 0.24; eps: 0.04 }
    SpringVal { id: fullGlowSp; target: ws.isFull ? 1.0 : 0.0; stiffness: 320; damping: 0.65; eps: 0.005 }

    function _impulse(nextV, isWheel) {
        const dv = nextV - ws._lastV;
        ws._lastV = nextV;
        if (Math.abs(dv) > 0.0004) {
            tiltSp.kick(Math.max(-560, Math.min(560, dv * (isWheel ? 5200 : 3600))));
            bowSp.kick(Math.max(-135, Math.min(135, dv * 880)));
        }
        const nowFull = nextV >= 0.99;
        if (nowFull && !ws._wasFull) {
            handleHSp.kick(75);
            ws.lockedFull();
        }
        ws._wasFull = nowFull;

        const ti = Math.round(nextV * 24);
        if (ti !== ws._lastTickIdx) {
            ws._lastTickIdx = ti;
            if (!nowFull) ws.stepped();
        }
    }

    // Gentle living wave drift only while visible, active, and NOT locked straight at 100%
    NumberAnimation on phase {
        from: 0; to: Math.PI * 2.0
        duration: 1500
        loops: Animation.Infinite
        running: ws.active && ws.visible && shownSp.value > 0.015 && shownSp.value < 0.99
    }

    Canvas {
        id: cv
        anchors.fill: parent
        readonly property var _k: [
            Math.round(shownSp.value * 1000),
            Math.round(phase * 100),
            Math.round(handleHSp.value * 20),
            Math.round(tiltSp.value * 30),
            Math.round(bowSp.value * 30),
            Math.round(fullGlowSp.value * 100),
            ws.accent.toString(), ws.accent2.toString(), ws.trackColor.toString(), ws.handleColor.toString(),
            width, height
        ]
        on_KChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 16 || height <= 6) return;

            const cy = height * 0.5;
            const pad = 11;
            const x0 = pad;
            const x1 = width - pad;
            const span = Math.max(1, x1 - x0);
            const v = Math.max(0.0, Math.min(1.0, shownSp.value));
            const ax = x0 + span * v;
            const gap = 8.5;

            const tiltDeg = Math.max(-32, Math.min(32, tiltSp.value));
            // Suppress residual bow when locked at 100% so full line is razor-straight!
            const bowY = Math.max(-5.5, Math.min(5.5, bowSp.value)) * (1.0 - fullGlowSp.value * 0.88);

            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            // 1) Inactive right hairline track
            if (ax + gap < x1) {
                ctx.lineWidth = Math.max(2.0, ws.thickness * 0.62);
                ctx.strokeStyle = ws.trackColor;
                ctx.beginPath();
                ctx.moveTo(ax + gap, cy - bowY * 0.20);
                ctx.quadraticCurveTo((ax + gap + x1) * 0.5, cy, x1, cy);
                ctx.stroke();
            }

            // 2) Active left track
            const endX = ax - gap;
            const activeLen = endX - x0;
            if (activeLen > 1.5) {
                const grad = ctx.createLinearGradient(x0, cy - ws.maxAmplitude, endX, cy + ws.maxAmplitude);
                grad.addColorStop(0.0, ws.accent);
                grad.addColorStop(1.0, ws.accent2);

                // Smoothly relaxes from constant maxAmplitude (for v <= 0.78) to EXACT 0.0 at v >= 0.99 (100% straight!)
                const stretchT = Math.max(0.0, Math.min(1.0, (v - 0.78) / 0.21));
                const smoothStretch = stretchT * stretchT * (3.0 - 2.0 * stretchT);
                const A = ws.maxAmplitude * (1.0 - smoothStretch);

                // Subtle taut-line halo glow when locked completely straight at 100%!
                if (fullGlowSp.value > 0.05) {
                    ctx.save();
                    ctx.strokeStyle = Qt.rgba(ws.accent.r, ws.accent.g, ws.accent.b, 0.22 * fullGlowSp.value);
                    ctx.lineWidth = ws.thickness + 4.5;
                    ctx.beginPath();
                    ctx.moveTo(x0, cy);
                    ctx.lineTo(endX, cy);
                    ctx.stroke();
                    ctx.restore();
                }

                ctx.strokeStyle = grad;
                ctx.lineWidth = ws.thickness;

                if (A <= 0.04 && Math.abs(bowY) <= 0.05) {
                    // 100% FULL -> Razor-straight line (ตรงแด่ว!)
                    ctx.beginPath();
                    ctx.moveTo(x0, cy);
                    ctx.lineTo(endX, cy);
                    ctx.stroke();
                } else {
                    // Spring-coil frequency: tighter & more waves as v decreases, strictly capped height!
                    const wavelength = 5.8 + Math.pow(v, 2.65) * 260.0;
                    const dx = Math.max(0.65, Math.min(1.8, wavelength / 16.0));
                    const edgeRamp = Math.min(10.0, activeLen * 0.22);

                    ctx.beginPath();
                    let first = true;
                    for (let x = x0; x <= endX; x += dx) {
                        const u = (x - x0) / activeLen;
                        const edgeFade = Math.min(1.0, (x - x0) / Math.max(1.0, edgeRamp), (endX - x) / Math.max(1.0, edgeRamp));
                        const bowPart = Math.sin(u * Math.PI) * bowY * 0.50;
                        const wave = Math.sin(2.0 * Math.PI * (x - x0) / wavelength - ws.phase * (1.0 - smoothStretch * 0.6));
                        const yy = cy + bowPart + A * Math.max(0.0, edgeFade) * wave;
                        if (first) { ctx.moveTo(x, yy); first = false; }
                        else ctx.lineTo(x, yy);
                    }
                    ctx.lineTo(endX, cy + bowY * 0.18);
                    ctx.stroke();
                }
            }

            // End-cap dot when not full
            if (v < 0.96) {
                ctx.fillStyle = Qt.rgba(ws.accent.r, ws.accent.g, ws.accent.b, 0.55);
                ctx.beginPath();
                ctx.arc(x1, cy, 2.1, 0, Math.PI * 2);
                ctx.fill();
            }

            // 3) Tilting & bouncing vertical pill handle
            const hw = ws.dragging ? 5.4 : 4.4;
            const hh = Math.max(14, handleHSp.value);
            ctx.save();
            ctx.translate(ax, cy);
            ctx.rotate(tiltDeg * Math.PI / 180.0);

            if (ma.containsMouse || ws.dragging || Math.abs(tiltDeg) > 1.0 || fullGlowSp.value > 0.2) {
                ctx.fillStyle = Qt.rgba(ws.accent.r, ws.accent.g, ws.accent.b, 0.24);
                ctx.beginPath();
                ctx.roundedRect(-hw * 0.5 - 3.5, -hh * 0.5 - 3.5, hw + 7, hh + 7, (hw + 7) * 0.5, (hw + 7) * 0.5);
                ctx.fill();
            }

            const hGrad = ctx.createLinearGradient(0, -hh * 0.5, 0, hh * 0.5);
            hGrad.addColorStop(0.0, ws.handleColor);
            hGrad.addColorStop(1.0, ws.accent);
            ctx.fillStyle = hGrad;
            ctx.beginPath();
            ctx.roundedRect(-hw * 0.5, -hh * 0.5, hw, hh, hw * 0.5, hw * 0.5);
            ctx.fill();
            ctx.restore();
        }
    }

    function setFromX(mx) {
        const pad = 11;
        let v = Math.max(0.0, Math.min(1.0, (mx - pad) / Math.max(1.0, width - pad * 2)));
        // Soft magnetic snap at the very end so hitting 100% straight feels crisp
        if (v > 0.985) v = 1.0;
        ws._impulse(v, false);
        ws.moved(v);
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: (e) => { handleHSp.kick(48); ws.setFromX(e.x); }
        onPositionChanged: (e) => { if (pressed) ws.setFromX(e.x); }
        onReleased: {
            ws.released();
            handleHSp.kick(-52);
            if (Math.abs(tiltSp.velocity) < 35) tiltSp.kick(tiltSp.value >= 0 ? -180 : 180);
        }
    }

    Timer { id: wheelDone; interval: 350; onTriggered: ws.released() }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            // Let normal wheel events scroll the page without snagging on sliders; Shift+Wheel fine-tunes the slider.
            if (!(e.modifiers & Qt.ShiftModifier)) {
                e.accepted = false;
                return;
            }
            const dir = e.angleDelta.y > 0 ? 1 : -1;
            let next = Math.max(0.0, Math.min(1.0, ws.value + dir * ws.step));
            if (next > 0.985) next = 1.0;
            ws._impulse(next, true);
            handleHSp.kick(68);
            ws.moved(next);
            wheelDone.restart();
            e.accepted = true;
        }
    }
}
