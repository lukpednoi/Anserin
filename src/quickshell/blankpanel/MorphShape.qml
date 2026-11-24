import QtQuick
import "../"
import "../controlcenter/smart" as Smart

// A soft geometric shape in the top-right L-corner of BlankPanel that rotates gently while visible.
// change() morphs it into another shape with a 180-deg turn and spring pop; a shape repeats only after >= 3 others.
Item {
    id: root

    property bool active: false
    property color color: ThemeBackend.mauve
    property color color2: ThemeBackend.peach
    property bool gradientFill: true

    readonly property var shapes: [
        { kind: "cookie", n: 4, d: 0.12 },
        { kind: "cookie", n: 6, d: 0.10 },
        { kind: "cookie", n: 9, d: 0.08 },
        { kind: "cookie", n: 12, d: 0.07 },
        { kind: "cookie", n: 16, d: 0.10 },
        { kind: "cookie", n: 3, d: 0.20 },
        { kind: "clover", n: 3 },
        { kind: "clover", n: 4 },
        { kind: "star", n: 5 },
        { kind: "star", n: 8 },
        { kind: "squircle" },
        { kind: "pill" }
    ].map(shape => Object.assign({ scale: 1 / maxRadius(shape) }, shape))

    property var history: []
    property var current: null
    property var next: null
    property real blend: 1
    property real spin: 0

    Smart.SpringVal { id: popSc; target: 1.0; stiffness: 420; damping: 0.38; eps: 0.002 }

    function rawRadius(shape, angle) {
        const c = Math.cos(angle), s = Math.sin(angle);
        switch (shape.kind) {
        case "cookie": return 1 + shape.d * Math.cos(shape.n * angle);
        case "clover": return 0.55 + 0.45 * Math.pow(Math.abs(Math.cos(shape.n * angle / 2)), 0.7);
        case "star": return 0.62 + 0.38 * Math.pow((1 + Math.cos(shape.n * angle)) / 2, 2);
        case "squircle": return Math.pow(Math.pow(Math.abs(c), 4) + Math.pow(Math.abs(s), 4), -1 / 4);
        case "pill": return Math.pow(Math.pow(Math.abs(c), 4) + Math.pow(Math.abs(s / 0.62), 4), -1 / 4);
        }
        return 1;
    }

    function maxRadius(shape) {
        let max = 0;
        for (let i = 0; i < 360; i++) max = Math.max(max, rawRadius(shape, i / 360 * Math.PI * 2));
        return max;
    }

    function radiusAt(shape, angle) {
        return rawRadius(shape, angle) * shape.scale;
    }

    function pickShape() {
        const recent = history.slice(-3);
        const choices = [];
        for (let i = 0; i < shapes.length; i++) if (recent.indexOf(i) === -1) choices.push(i);
        const pick = choices[Math.floor(Math.random() * choices.length)];
        history = recent.concat([pick]);
        return shapes[pick];
    }

    function change() {
        current = blend >= 1 ? next : current;
        next = pickShape();
        morph.stop();
        spinMore.stop();
        spinMore.to = spin + 180;
        blend = 0;
        morph.restart();
        spinMore.restart();
        popSc.kick(1.35);
    }

    Component.onCompleted: {
        current = pickShape();
        next = current;
        canvas.requestPaint();
    }

    NumberAnimation { id: morph; target: root; property: "blend"; to: 1; duration: 400; easing.type: Easing.OutCubic }
    NumberAnimation { id: spinMore; target: root; property: "spin"; duration: 400; easing.type: Easing.OutCubic }

    onBlendChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onColor2Changed: canvas.requestPaint()

    Item {
        anchors.fill: parent
        scale: popSc.value
        rotation: root.spin

        Canvas {
            id: canvas
            anchors.fill: parent
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            NumberAnimation on rotation {
                from: 0; to: 360; duration: 8500
                loops: Animation.Infinite
                running: root.active && root.visible
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (!root.current || !root.next || width <= 2) return;
                const cx = width / 2, cy = height / 2, size = Math.min(width, height) / 2 - 1, steps = 160;
                ctx.beginPath();
                for (let i = 0; i <= steps; i++) {
                    const angle = i / steps * Math.PI * 2;
                    const r = size * (root.radiusAt(root.current, angle) * (1 - root.blend) + root.radiusAt(root.next, angle) * root.blend);
                    const x = cx + Math.cos(angle) * r, y = cy + Math.sin(angle) * r;
                    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
                }
                ctx.closePath();
                if (root.gradientFill) {
                    const g = ctx.createLinearGradient(0, 0, width, height);
                    g.addColorStop(0.0, root.color);
                    g.addColorStop(1.0, root.color2);
                    ctx.fillStyle = g;
                } else {
                    ctx.fillStyle = root.color;
                }
                ctx.fill();
            }
        }
    }
}
