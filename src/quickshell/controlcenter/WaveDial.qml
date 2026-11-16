import QtQuick
import "../"
import "../reusables"

// Round level button for the Control Center: icon in the middle, a wavy half-circle line
// over the top that shows the level. Scroll over it (or drag the line) to change the level;
// click the icon for the button action. The wave only animates while hovered or just changed.
Rectangle {
    id: dial

    property string icon: ""
    property real value: 0               // 0..100
    property color accent: ThemeBackend.blue
    property color iconColor: ThemeBackend.text
    property bool muted: false
    property bool active: true           // false while the panel is hidden: stops all motion
    property real wheelStep: 5
    property string valueText: Math.round(value) + "%"
    property color baseColor: Qt.darker(ThemeBackend.surface0, 1.04)

    signal adjusted(real value)          // wheel or drag asks for a new level
    signal dragStarted()
    signal dragFinished()
    signal clicked()

    function s(v) { return Scaler.s(v); }

    radius: Math.min(ThemeBackend.borderRadius, s(20))
    color: dialGlass.active ? "transparent" : baseColor
    GlassFill { id: dialGlass; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
    clip: true

    readonly property real cx: width / 2
    readonly property real cy: height - s(40)
    readonly property real arcR: Math.min(s(68), width / 2 - s(20), cy - s(16))
    readonly property real discR: s(24)
    readonly property bool hovered: hoverArea.containsMouse || discMa.containsMouse
    readonly property real clamped: Math.max(0, Math.min(100, value))

    // smooth level + wave state
    property real shown: clamped
    Behavior on shown { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    // waves keep moving gently while the panel is open; livelier on hover / while changing
    property real boost: (hovered || recentChange.running || dragging) ? 1.0 : 0.45
    Behavior on boost { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    property real phase: 0
    property bool dragging: false
    NumberAnimation on phase {
        from: 0; to: Math.PI * 2; duration: 1700; loops: Animation.Infinite
        running: dial.active && dial.visible && dial.boost > 0.01
    }
    Timer { id: recentChange; interval: 900 }
    Timer { id: tickGate; interval: 70 }

    onShownChanged: arc.requestPaint()
    onPhaseChanged: arc.requestPaint()
    onAccentChanged: arc.requestPaint()
    onMutedChanged: arc.requestPaint()
    onWidthChanged: arc.requestPaint()
    onHeightChanged: arc.requestPaint()

    Canvas {
        id: arc
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var R = dial.arcR, cx = dial.cx, cy = dial.cy;
            var amp = dial.s(2.2) + dial.boost * dial.s(3.0);
            var waves = 7, N = 96;
            function pt(t) {
                var a = Math.PI + Math.PI * t;
                var r = R + amp * Math.sin(Math.PI * t) * Math.sin(t * waves * Math.PI * 2 + dial.phase);
                return [cx + Math.cos(a) * r, cy + Math.sin(a) * r];
            }
            function stroke(t0, t1, color, w) {
                if (t1 - t0 < 0.002) return;
                ctx.beginPath();
                for (var i = 0; i <= N; i++) {
                    var p = pt(t0 + (t1 - t0) * i / N);
                    if (i === 0) ctx.moveTo(p[0], p[1]); else ctx.lineTo(p[0], p[1]);
                }
                ctx.lineWidth = w; ctx.lineCap = "round"; ctx.lineJoin = "round";
                ctx.strokeStyle = color; ctx.stroke();
            }
            var v = dial.shown / 100;
            stroke(0, 1, Qt.alpha(ThemeBackend.surface2, 0.55), dial.s(4));
            var col = dial.muted ? ThemeBackend.overlay0 : dial.accent;
            stroke(0, v, col, dial.s(4.5));
            // knob at the end of the level
            var k = pt(v);
            ctx.beginPath(); ctx.arc(k[0], k[1], dial.s(5.5) + dial.boost * dial.s(1.5), 0, Math.PI * 2);
            ctx.fillStyle = dial.muted ? ThemeBackend.overlay1 : Qt.lighter(dial.accent, 1.25);
            ctx.fill();
        }
    }

    // icon button in the middle
    Rectangle {
        id: disc
        width: dial.discR * 2
        height: width
        radius: width / 2
        x: dial.cx - width / 2
        y: dial.cy - height / 2
        color: discMa.pressed ? ThemeBackend.surface2 : (discMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.surface1, 0.65))
        scale: discMa.pressed ? 0.94 : (discMa.containsMouse ? 1.04 : 1.0)
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
        Text {
            anchors.centerIn: parent
            text: dial.icon
            font.family: ThemeBackend.iconFont
            font.pixelSize: dial.s(20)
            color: dial.muted ? ThemeBackend.overlay0 : (dial.hovered ? Qt.lighter(dial.accent, 1.2) : dial.iconColor)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: dial.cy + dial.discR + dial.s(3)
        text: dial.muted ? "—" : dial.valueText
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Bold
        font.pixelSize: dial.s(12)
        color: dial.hovered ? ThemeBackend.text : ThemeBackend.subtext0
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    // wheel + hover over the whole card
    property real wheelAcc: 0
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onWheel: (wheel) => {
            dial.wheelAcc += wheel.angleDelta.y / 120 * dial.wheelStep;
            var d = Math.trunc(dial.wheelAcc);
            if (d !== 0) {
                dial.wheelAcc -= d;
                dial.adjusted(Math.max(0, Math.min(100, Math.round(dial.clamped + d))));
                if (!tickGate.running) { Sounds.playSfx("reusables/draggable/tick.wav", 0.6); tickGate.start(); }
                recentChange.restart();
            }
            wheel.accepted = true;
        }
    }

    // drag along the wavy line
    function levelAt(mx, my) {
        var a = Math.atan2(my - cy, mx - cx);     // -pi..pi, top half is -pi..0
        if (a > 0) a = (mx < cx) ? -Math.PI : 0;  // below the centre: clamp to the nearer end
        return Math.max(0, Math.min(100, Math.round((a + Math.PI) / Math.PI * 100)));
    }
    MouseArea {
        id: dragArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        preventStealing: true
        cursorShape: dial.dragging ? Qt.ClosedHandCursor : Qt.ArrowCursor
        onPressed: (mouse) => {
            var dx = mouse.x - dial.cx, dy = mouse.y - dial.cy;
            var dist = Math.sqrt(dx * dx + dy * dy);
            if (dy > dial.s(10) || Math.abs(dist - dial.arcR) > dial.s(18)) { mouse.accepted = false; return; }
            dial.dragging = true;
            dial.dragStarted();
            dial.adjusted(dial.levelAt(mouse.x, mouse.y));
        }
        onPositionChanged: (mouse) => { if (dial.dragging) dial.adjusted(dial.levelAt(mouse.x, mouse.y)); }
        onReleased: { if (dial.dragging) { dial.dragging = false; dial.dragFinished(); } }
        onCanceled: { if (dial.dragging) { dial.dragging = false; dial.dragFinished(); } }
    }
    MouseArea {
        id: discMa
        x: disc.x; y: disc.y; width: disc.width; height: disc.height
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { Sounds.playSfx("reusables/iconbutton/click.wav"); dial.clicked(); }
    }
}
