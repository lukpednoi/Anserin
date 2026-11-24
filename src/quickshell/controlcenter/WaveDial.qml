import QtQuick
import "../"
import "../reusables"
import "./smart" as Smart

// Expressive Smart Home Wave Dial (Control Center Overview — Style A):
// - Half-circle wavy arc + center morphing geometric icon button + bottom percentage only (no text labels).
// - Lower values = higher wave frequency & denser crests (strictly capped amplitude).
// - At 100% (full) = razor-smooth circular arc (A = 0) with glow + lockedFull signal.
// - Drag anywhere on card (outside center badge) or wheel to adjust 0..100; click center badge to mute / toggle.
// - Zero-idle: wave animation runs only while active && visible && !isFull && !muted.
Item {
    id: dial

    property string icon: "󰕾"
    property string mutedIcon: "󰖁"
    property string geoShape: "clover4"
    property real value: 0                // 0..100
    property bool muted: false
    property bool active: true
    property real wheelStep: 5
    property color accent: ThemeBackend.mauve
    property color accent2: ThemeBackend.peach
    property color baseColor: ThemeBackend.surface0

    signal adjusted(real value)
    signal dragStarted()
    signal dragFinished()
    signal clicked()
    signal stepped()
    signal lockedFull()

    function s(v) { return Scaler.s(v); }

    readonly property bool darkMode: (0.2126 * ThemeBackend.base.r + 0.7152 * ThemeBackend.base.g + 0.0722 * ThemeBackend.base.b) < 0.5
    readonly property color inkAccent: {
        const lum = 0.2126 * accent.r + 0.7152 * accent.g + 0.0722 * accent.b;
        return lum > 0.52 ? "#0b0e14" : "#ffffff";
    }
    readonly property real cornerRadius: Math.min(ThemeBackend.borderRadius, s(18))
    readonly property real clamped: Math.max(0, Math.min(100, value))
    readonly property real frac: clamped / 100.0
    readonly property bool isActiveState: !muted && frac > 0.005
    readonly property bool isFull: !muted && frac >= 0.995

    property bool dragging: false
    property real lastDragX: 0
    property real wheelAcc: 0
    property int _lastBucket: Math.round(clamped / 5)
    property bool _wasFull: isFull

    Smart.SpringVal { id: shownSp; target: dial.frac; stiffness: 360; damping: 0.62; eps: 0.001 }
    Smart.SpringVal { id: swaySp;  target: 0.0;       stiffness: 240; damping: 0.34; eps: 0.004 }
    Smart.SpringVal { id: cardSc;  target: dial.dragging ? 0.985 : (hovH.hovered ? 1.015 : 1.0); stiffness: 460; damping: 0.50; eps: 0.001 }
    Smart.SpringVal { id: floodSp; target: dial.isActiveState ? (0.35 + 0.65 * dial.frac) : 0.0; stiffness: 260; damping: 0.64; eps: 0.002 }
    Smart.SpringVal { id: badgeSc; target: discMa.pressed ? 0.86 : (discMa.containsMouse ? 1.08 : 1.0); stiffness: 520; damping: 0.42; eps: 0.001 }

    // Continuous gentle wave phase while panel Overview is open & not locked straight at 100%
    property real wavePhase: 0.0
    NumberAnimation on wavePhase {
        from: 0; to: Math.PI * 2; duration: 2100; loops: Animation.Infinite
        running: dial.active && dial.visible && !dial.isFull && !dial.muted
    }

    onFracChanged: {
        const b = Math.round(clamped / 5);
        if (b !== _lastBucket) {
            _lastBucket = b;
            if (dragging) stepped();
        }
        if (isFull && !_wasFull) {
            _wasFull = true;
            badgeSc.kick(1.25);
            if (active && visible) lockedFull();
        } else if (!isFull) {
            _wasFull = false;
        }
    }

    scale: cardSc.value

    // Card surface (Liquid Glass aware) + diagonal top-left -> bottom-right gradient flood
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: dial.cornerRadius
        color: dialGlass.active ? "transparent" : dial.baseColor
        border.width: dial.isFull ? 1.4 : 1
        border.color: dial.isFull
            ? Qt.rgba(dial.accent.r, dial.accent.g, dial.accent.b, 0.58)
            : (dial.isActiveState
                ? Qt.rgba(dial.accent.r, dial.accent.g, dial.accent.b, 0.24)
                : (dial.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.07)))
        clip: true

        GlassFill {
            id: dialGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.surface0
            tintAmount: ThemeBackend.glassTint
            sharp: true
            frost: ThemeBackend.glassFrost
            rim: 0.9
            z: -1
        }

        Canvas {
            anchors.fill: parent
            readonly property var _k: [floodSp.value, dial.accent.toString(), dial.accent2.toString(), dial.cornerRadius, width, height]
            on_KChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const f = Math.max(0, Math.min(1, floodSp.value));
                if (f <= 0.005 || width <= 4 || height <= 4) return;
                const r = dial.cornerRadius;
                const g = ctx.createLinearGradient(0, 0, width * (0.4 + 0.7 * f), height * (0.4 + 0.7 * f));
                g.addColorStop(0.0, Qt.rgba(dial.accent.r, dial.accent.g, dial.accent.b, 0.26 * f));
                g.addColorStop(0.55, Qt.rgba(dial.accent2.r, dial.accent2.g, dial.accent2.b, 0.12 * f));
                g.addColorStop(1.0, "transparent");
                ctx.fillStyle = g;
                ctx.beginPath();
                ctx.roundedRect(0, 0, width, height, r, r);
                ctx.fill();
            }
        }
    }

    readonly property real cx: width * 0.5
    readonly property real cy: height * 0.61
    readonly property real arcR: Math.max(s(24), Math.min(width * 0.37, height * 0.43))

    // Wavy half-circle arc Canvas
    Canvas {
        id: arcCanvas
        anchors.fill: parent
        readonly property var _k: [
            shownSp.value, swaySp.value, dial.wavePhase, dial.muted, dial.isFull,
            dial.accent.toString(), dial.accent2.toString(), dial.darkMode, width, height
        ]
        on_KChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (width <= 8 || height <= 8) return;
            const cx = dial.cx, cy = dial.cy, R = dial.arcR;
            const v = Math.max(0, Math.min(1, shownSp.value));
            const sway = swaySp.value;

            // Background arc track
            ctx.beginPath();
            ctx.arc(cx, cy, R, Math.PI, Math.PI * 2, false);
            ctx.lineWidth = dial.s(4.5);
            ctx.lineCap = "round";
            ctx.strokeStyle = dial.darkMode ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(0, 0, 0, 0.11);
            ctx.stroke();

            if (v <= 0.004) return;

            // At 100% (v >= 0.995): amplitude = 0 -> smooth circular arc; lower values = denser crests, capped amplitude
            const smoothToStraight = Math.min(1, Math.max(0, (1.0 - v) / 0.08));
            const amp = dial.muted ? 0.0 : (dial.s(3.1) * smoothToStraight);
            const waves = 4.2 + (1.0 - v) * 8.5;
            const steps = 84;

            function pt(t) {
                const a = Math.PI + Math.PI * t + sway * 0.05 * Math.sin(Math.PI * t);
                const env = Math.sin(Math.PI * Math.min(1, t / Math.max(0.05, v)));
                const r = R + amp * env * Math.sin(t * waves * Math.PI * 2 + dial.wavePhase);
                return [cx + Math.cos(a) * r, cy + Math.sin(a) * r];
            }

            const grad = ctx.createLinearGradient(cx - R, cy - R, cx + R, cy);
            if (dial.muted) {
                grad.addColorStop(0.0, ThemeBackend.subtext0);
                grad.addColorStop(1.0, ThemeBackend.subtext0);
            } else {
                grad.addColorStop(0.0, dial.accent);
                grad.addColorStop(1.0, dial.accent2);
            }

            if (dial.isFull) {
                ctx.beginPath();
                ctx.arc(cx, cy, R, Math.PI, Math.PI * 2, false);
                ctx.lineWidth = dial.s(9.0);
                ctx.lineCap = "round";
                ctx.strokeStyle = Qt.rgba(dial.accent.r, dial.accent.g, dial.accent.b, 0.25);
                ctx.stroke();
            }

            ctx.beginPath();
            for (let i = 0; i <= steps; i++) {
                const t = v * (i / steps);
                const p = pt(t);
                if (i === 0) ctx.moveTo(p[0], p[1]);
                else ctx.lineTo(p[0], p[1]);
            }
            ctx.lineWidth = dial.s(4.8);
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.strokeStyle = grad;
            ctx.stroke();

            // Glowing tip knob
            const tip = pt(v);
            ctx.beginPath();
            ctx.arc(tip[0], tip[1], dial.s(dial.dragging ? 6.2 : 5.0), 0, Math.PI * 2);
            ctx.fillStyle = dial.muted ? ThemeBackend.subtext0 : "#ffffff";
            ctx.fill();
            ctx.lineWidth = dial.s(2);
            ctx.strokeStyle = dial.muted ? dial.baseColor : dial.accent;
            ctx.stroke();
        }
    }

    // Center morphing geometric icon badge (muted/0% = circle, active = geoShape + gradient)
    Item {
        id: centerBadge
        width: dial.s(44); height: dial.s(44)
        x: dial.cx - width * 0.5
        y: dial.cy - height * 0.5 - dial.s(2)
        scale: badgeSc.value
        rotation: swaySp.value * 8
        z: 5

        Smart.SpringVal { id: geoMorphSp; target: dial.isActiveState ? 1.0 : 0.0; stiffness: 420; damping: 0.44; eps: 0.002 }
        Smart.SmartGeoShape {
            anchors.fill: parent
            fromShape: "circle"
            toShape: dial.geoShape
            morph: geoMorphSp.value
            fill: dial.isActiveState ? dial.accent : (dial.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08))
            fill2: dial.isActiveState ? dial.accent2 : "transparent"
        }

        Text {
            anchors.centerIn: parent
            text: (dial.muted || dial.clamped <= 0) ? dial.mutedIcon : dial.icon
            font.family: ThemeBackend.iconFont
            font.pixelSize: dial.s(18)
            color: dial.isActiveState ? dial.inkAccent : ThemeBackend.subtext0
        }

        MouseArea {
            id: discMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                badgeSc.kick(1.3);
                dial.clicked();
            }
        }
    }

    // Bottom clean percentage readout only
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: dial.s(10)
        text: dial.muted ? "0%" : (Math.round(dial.clamped) + "%")
        font.family: ThemeBackend.fontFamily
        font.pixelSize: dial.s(11)
        font.bold: true
        color: dial.isActiveState ? dial.accent : ThemeBackend.subtext0
    }

    HoverHandler { id: hovH }

    // Drag along the card (outside center badge) to adjust level
    MouseArea {
        anchors.fill: parent
        z: 2
        preventStealing: true
        cursorShape: dial.dragging ? Qt.ClosedHandCursor : Qt.SizeVerCursor
        function updateFromPos(mx, my) {
            const dx = mx - dial.cx;
            const dy = my - dial.cy;
            let ang = Math.atan2(dy, dx);
            if (ang > 0) ang = (dx < 0) ? -Math.PI : 0;
            const t = Math.max(0, Math.min(1, (ang + Math.PI) / Math.PI));
            const pct = Math.round(t * 100);
            const vel = (mx - dial.lastDragX) * 0.08;
            swaySp.kick(Math.max(-12, Math.min(12, vel)));
            dial.lastDragX = mx;
            dial.adjusted(pct);
        }
        onPressed: (e) => {
            dial.dragging = true;
            dial.lastDragX = e.x;
            dial.dragStarted();
            updateFromPos(e.x, e.y);
        }
        onPositionChanged: (e) => { if (pressed) updateFromPos(e.x, e.y); }
        onReleased: { if (dial.dragging) { dial.dragging = false; swaySp.target = 0.0; dial.dragFinished(); } }
        onCanceled: { if (dial.dragging) { dial.dragging = false; swaySp.target = 0.0; dial.dragFinished(); } }
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            dial.wheelAcc += e.angleDelta.y / 120 * dial.wheelStep;
            const d = Math.trunc(dial.wheelAcc);
            if (d !== 0) {
                dial.wheelAcc -= d;
                swaySp.kick(d > 0 ? 4.5 : -4.5);
                dial.adjusted(Math.max(0, Math.min(100, Math.round(dial.clamped + d))));
                dial.stepped();
            }
            e.accepted = true;
        }
    }
}
