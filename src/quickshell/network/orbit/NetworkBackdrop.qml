import QtQuick
import "../../"
import QtQuick.Shapes
import "."

/**
 * Clean 28-node constellation backdrop inspired by Screenshot_2569-11-18-005236.png:
 *   - 3 ultra-slow ambient bokeh orbs (54s / 69s / 84s)
 *   - Center Source Hub positioned strictly inside the innermost circular ring (r = 33px)
 *   - Electrical signal-scatter ripple radiates from center icon when each pulse cycle launches
 *   - True causal BFS chain-reaction light propagation:
 *       Hub -> Hop 1 -> Hop 2 -> Hop 3; no node lights up before a beam reaches it!
 *   - Clean 28-dot constellation ONLY (no Wi-Fi/BT icon dots or Wi-Fi tether curve)
 *   - Open/close reveal animation on initial entry, scan return, power toggle, and Wi-Fi <-> BT switch
 */
Item {
    id: root

    property color accentColor: ThemeBackend.mauve
    property bool active: true
    property bool powerOn: true
    property bool winVisible: true
    property bool showCenterHub: true
    property bool showMesh: true
    property bool hubClickable: false

    signal hubClicked()

    // Centered cleanly above bottom bar (0.50, 0.37)
    property real hubXRatio: 0.50
    property real hubYRatio: 0.37

    // Source kind: "router" | "phone" | "bt"
    property string sourceKind: "router"
    property string btIconGlyph: "󰂯"

    property real driftA: 0
    property real driftB: 0
    property real driftC: 0
    property real pulseTime: 0
    property real openReveal: showCenterHub ? 1.0 : 0.35

    readonly property bool animate: active && winVisible && visible
    readonly property bool lightActive: powerOn && showCenterHub
    readonly property real hubX: width * hubXRatio
    readonly property real hubY: height * hubYRatio

    clip: true

    Behavior on openReveal {
        enabled: root.winVisible
        NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.85 }
    }

    onShowCenterHubChanged: {
        openReveal = showCenterHub ? 1.0 : 0.82;
    }

    // Deep atmospheric base + vignette
    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.base

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.alpha(root.accentColor, root.powerOn ? 0.08 : 0.02) }
                GradientStop { position: 0.45; color: Qt.alpha(ThemeBackend.surface0, 0.32) }
                GradientStop { position: 1.0; color: Qt.alpha(ThemeBackend.crust, 0.94) }
            }
        }
    }

    // Center soft radial glow behind hub when powered on
    Rectangle {
        anchors.centerIn: centerHub
        width: 240
        height: 180
        radius: 120
        opacity: root.lightActive ? root.openReveal : 0.0
        Behavior on opacity { NumberAnimation { duration: 420 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(root.accentColor, 0.14) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // 3x slower lazy bokeh orbs
    NumberAnimation on driftA {
        running: root.animate
        from: 0; to: Math.PI * 2
        duration: 54000
        loops: Animation.Infinite
    }
    NumberAnimation on driftB {
        running: root.animate
        from: 0; to: Math.PI * 2
        duration: 69000
        loops: Animation.Infinite
    }
    NumberAnimation on driftC {
        running: root.animate
        from: 0; to: Math.PI * 2
        duration: 84000
        loops: Animation.Infinite
    }

    Rectangle {
        width: 230; height: 230; radius: 115
        x: root.width * 0.5 - width * 0.5 + Math.sin(root.driftA) * (root.width * 0.33)
        y: root.height * 0.25 - height * 0.5 + Math.cos(root.driftA * 2) * 14
        color: Qt.alpha(root.accentColor, root.powerOn ? 0.048 : 0.016)
        Behavior on color { ColorAnimation { duration: 450 } }
    }
    Rectangle {
        width: 185; height: 185; radius: 92.5
        x: root.width * 0.5 - width * 0.5 - Math.sin(root.driftB + 1.1) * (root.width * 0.35)
        y: root.height * 0.64 - height * 0.5 + Math.sin(root.driftB) * 16
        color: Qt.alpha(ThemeBackend.peach, root.powerOn ? 0.036 : 0.012)
        Behavior on color { ColorAnimation { duration: 450 } }
    }
    Rectangle {
        width: 148; height: 148; radius: 74
        x: root.width * 0.5 - width * 0.5 + Math.cos(root.driftC + 0.6) * (root.width * 0.28)
        y: root.height * 0.44 - height * 0.5 - Math.sin(root.driftC * 2) * 12
        color: Qt.alpha(ThemeBackend.green, root.powerOn ? 0.030 : 0.010)
        Behavior on color { ColorAnimation { duration: 450 } }
    }

    // Continuous radial chain-reaction cycle (5000ms for clear domino cascade + electrical fade)
    NumberAnimation on pulseTime {
        running: root.animate && root.powerOn && root.showMesh
        from: 0.0
        to: 1.0
        duration: 5000
        loops: Animation.Infinite
    }

    onPulseTimeChanged: if (meshCanvas.visible) meshCanvas.requestPaint()
    onOpenRevealChanged: if (meshCanvas.visible) meshCanvas.requestPaint()

    // 28-node causal chain-reaction constellation + signal scatter rings
    Canvas {
        id: meshCanvas
        anchors.fill: parent
        opacity: root.showMesh ? (root.powerOn ? (root.showCenterHub ? 1.0 : 0.24) : 0.0) : 0.0
        scale: root.showCenterHub ? (0.86 + 0.14 * root.openReveal) : 1.0
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()

        Connections {
            target: root
            function onAccentColorChanged() { meshCanvas.requestPaint(); }
            function onHubXRatioChanged() { meshCanvas.requestPaint(); }
            function onHubYRatioChanged() { meshCanvas.requestPaint(); }
            function onShowCenterHubChanged() { meshCanvas.requestPaint(); }
        }

        // 28 triangulated mesh vertices grouped cleanly by Hop level (0..6 = Hop 1, 7..17 = Hop 2, 18..27 = Hop 3)
        readonly property var meshNodes: [
            // Hop 1 (0..6)
            { dx: -76,  dy: -30,  r: 3.4, hop: 1 },
            { dx: -26,  dy: -68,  r: 3.8, hop: 1 },
            { dx:  62,  dy: -56,  r: 3.6, hop: 1 },
            { dx:  86,  dy:   8,  r: 4.0, hop: 1 },
            { dx:  52,  dy:  64,  r: 3.6, hop: 1 },
            { dx: -16,  dy:  70,  r: 3.8, hop: 1 },
            { dx: -84,  dy:  32,  r: 3.4, hop: 1 },

            // Hop 2 (7..17)
            { dx: -144, dy: -66,  r: 3.4, hop: 2 },
            { dx: -82,  dy: -104, r: 4.0, hop: 2 },
            { dx:  10,  dy: -116, r: 3.2, hop: 2 },
            { dx:  96,  dy: -94,  r: 3.8, hop: 2 },
            { dx:  142, dy: -20,  r: 3.8, hop: 2 },
            { dx:  168, dy:  34,  r: 3.4, hop: 2 },
            { dx:  108, dy:  86,  r: 3.8, hop: 2 },
            { dx:  22,  dy: 110,  r: 3.2, hop: 2 },
            { dx: -68,  dy: 108,  r: 3.8, hop: 2 },
            { dx: -142, dy:  68,  r: 4.0, hop: 2 },
            { dx: -182, dy: -10,  r: 3.4, hop: 2 },

            // Hop 3 (18..27)
            { dx: -222, dy: -46,  r: 2.6, hop: 3 },
            { dx: -168, dy: -112, r: 2.8, hop: 3 },
            { dx: -32,  dy: -138, r: 2.8, hop: 3 },
            { dx:  54,  dy: -136, r: 2.8, hop: 3 },
            { dx:  152, dy: -106, r: 2.8, hop: 3 },
            { dx:  228, dy: -26,  r: 2.8, hop: 3 },
            { dx:  214, dy:  56,  r: 2.6, hop: 3 },
            { dx:  146, dy:  86,  r: 3.4, hop: 3 },
            { dx: -24,  dy: 136,  r: 2.8, hop: 3 },
            { dx: -214, dy:  40,  r: 2.8, hop: 3 }
        ]

        // Outward Hop edges (strictly parent hop -> child hop for exact domino chain)
        readonly property var radialEdges: [
            // Hop 1 -> Hop 2
            [0,7],[0,8],[0,17],[1,8],[1,9],[2,9],[2,10],[2,11],
            [3,11],[3,12],[3,13],[4,13],[4,14],[5,14],[5,15],[6,15],[6,16],[6,17],
            // Hop 2 -> Hop 3
            [7,18],[7,19],[8,19],[8,20],[9,20],[9,21],[10,21],[10,22],
            [11,22],[11,23],[12,23],[12,24],[13,24],[13,25],[14,25],[14,26],
            [15,26],[16,26],[16,27],[17,27],[17,18]
        ]

        // Tangential structural edges (pulse only propagates laterally after earlier endpoint arrives)
        readonly property var crossEdges: [
            [0,1],[1,2],[2,3],[3,4],[4,5],[5,6],[6,0],
            [7,8],[8,9],[9,10],[10,11],[11,12],[12,13],[13,14],[14,15],[15,16],[16,17],[17,7],
            [18,19],[19,20],[20,21],[21,22],[22,23],[23,24],[24,25],[25,26],[26,27],[27,18]
        ]

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width <= 0 || height <= 0 || !root.powerOn) return;

            const hx = root.hubX;
            const hy = root.hubY;
            const c = root.accentColor;
            const phase = root.pulseTime;

            const pts = [];
            for (let i = 0; i < meshNodes.length; i++) {
                const n = meshNodes[i];
                const wave = Math.sin(phase * Math.PI * 2 + i * 0.9) * 2.0;
                pts.push({
                    x: hx + n.dx + wave * 0.65,
                    y: hy + n.dy - wave * 0.45,
                    r: n.r,
                    hop: n.hop
                });
            }

            // Concentric perspective ovals clearly framing the naked Center Hub icon inside the inner oval
            if (root.showCenterHub) {
                function strokeScaledOval(rx, ry, dashed, dashArr, lw, alpha) {
                    ctx.save();
                    ctx.translate(hx, hy);
                    ctx.scale(1.0, ry / rx);
                    ctx.beginPath();
                    ctx.arc(0, 0, rx, 0, Math.PI * 2);
                    ctx.restore();
                    ctx.lineWidth = lw;
                    if (dashed) ctx.setLineDash(dashArr);
                    else ctx.setLineDash([]);
                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, alpha);
                    ctx.stroke();
                    if (dashed) ctx.setLineDash([]);
                }

                // Innermost ellipse wide & tall enough (136×88px) so the 26px icon visibly sits spaciously inside
                strokeScaledOval(68, 44, false, [], 1.25, 0.34);
                strokeScaledOval(104, 66, true, [3, 5], 1.0, 0.18);
                strokeScaledOval(246, 156, true, [4, 7], 1.0, 0.09);

                // Signal-scatter wave expanding smoothly out from center icon (0.00 -> 0.24)
                if (phase >= 0.0 && phase <= 0.26) {
                    const scatT = Math.min(1.0, phase / 0.22);
                    const easeS = 1.0 - Math.pow(1.0 - scatT, 2.5);
                    if (phase <= 0.22) {
                        const rRipple1 = 12 + easeS * 52;
                        const a1 = Math.sin(scatT * Math.PI) * 0.56;
                        ctx.beginPath();
                        ctx.arc(hx, hy, rRipple1, 0, Math.PI * 2);
                        ctx.lineWidth = 1.7;
                        ctx.strokeStyle = Qt.rgba(1.0, 1.0, 0.94, a1);
                        ctx.stroke();
                    }
                    if (phase >= 0.04 && phase <= 0.26) {
                        const t2 = Math.min(1.0, (phase - 0.04) / 0.22);
                        const e2 = 1.0 - Math.pow(1.0 - t2, 2.2);
                        const rRipple2 = 14 + e2 * 64;
                        const a2 = Math.sin(t2 * Math.PI) * 0.34;
                        ctx.beginPath();
                        ctx.arc(hx, hy, rRipple2, 0, Math.PI * 2);
                        ctx.lineWidth = 1.3;
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, a2);
                        ctx.stroke();
                    }
                }
            }

            // Subtle faceted polygon glint
            if (root.showCenterHub) {
                const tris = [[2,10,11],[11,22,23],[6,16,15],[0,7,8],[13,24,25]];
                for (let t = 0; t < tris.length; t++) {
                    const p0 = pts[tris[t][0]];
                    const p1 = pts[tris[t][1]];
                    const p2 = pts[tris[t][2]];
                    ctx.beginPath();
                    ctx.moveTo(p0.x, p0.y);
                    ctx.lineTo(p1.x, p1.y);
                    ctx.lineTo(p2.x, p2.y);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.028);
                    ctx.fill();
                }
            }

            // --- Uniform-Speed Distance-Driven Chain Propagation (no forced simultaneous arrival, no round heads!) ---
            const waveSpeed = 480.0; // constant pixel velocity per full pulseTime cycle
            const hubFire = 0.05;
            const spokeOriginR = 18.0;

            const arrive = new Array(pts.length).fill(999.0);
            const spokes = [];
            for (let i = 0; i < 7; i++) {
                const p = pts[i];
                const rawD = Math.hypot(p.x - hx, p.y - hy);
                const len = Math.max(12.0, rawD - spokeOriginR);
                const dur = len / waveSpeed;
                arrive[i] = hubFire + dur;
                spokes.push({ dst: i, start: hubFire, dur: dur });
            }

            // Bellman-Ford / Dijkstra shortest-path distance arrival times across ALL real mesh edges
            const allEdges = [];
            for (let k = 0; k < radialEdges.length; k++) {
                const a = radialEdges[k][0];
                const b = radialEdges[k][1];
                const len = Math.max(8.0, Math.hypot(pts[b].x - pts[a].x, pts[b].y - pts[a].y));
                allEdges.push({ a: a, b: b, dur: len / waveSpeed, isCross: false });
            }
            for (let k = 0; k < crossEdges.length; k++) {
                const a = crossEdges[k][0];
                const b = crossEdges[k][1];
                const len = Math.max(8.0, Math.hypot(pts[b].x - pts[a].x, pts[b].y - pts[a].y));
                allEdges.push({ a: a, b: b, dur: len / waveSpeed, isCross: true });
            }

            for (let relax = 0; relax < 4; relax++) {
                for (let k = 0; k < allEdges.length; k++) {
                    const e = allEdges[k];
                    if (arrive[e.a] + e.dur < arrive[e.b]) arrive[e.b] = arrive[e.a] + e.dur;
                    if (arrive[e.b] + e.dur < arrive[e.a]) arrive[e.a] = arrive[e.b] + e.dur;
                }
            }

            // Draw clean tapering light beam (NO circular dot head!)
            function drawCausalBeam(x1, y1, x2, y2, start, dur, baseAlpha, beamStrength) {
                ctx.beginPath();
                ctx.moveTo(x1, y1);
                ctx.lineTo(x2, y2);
                ctx.lineWidth = 0.95;
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, baseAlpha);
                ctx.stroke();

                if (!root.showCenterHub || beamStrength <= 0.01) return;

                if (phase >= start && phase <= start + dur) {
                    const u = (phase - start) / dur;
                    const tailU = Math.max(0.0, u - 0.42);
                    const sx = x1 + (x2 - x1) * tailU;
                    const sy = y1 + (y2 - y1) * tailU;
                    const ex = x1 + (x2 - x1) * u;
                    const ey = y1 + (y2 - y1) * u;

                    const grad = ctx.createLinearGradient(sx, sy, ex, ey);
                    grad.addColorStop(0.0, Qt.rgba(c.r, c.g, c.b, 0.0));
                    grad.addColorStop(0.62, Qt.rgba(c.r, c.g, c.b, 0.76 * beamStrength));
                    grad.addColorStop(1.0, Qt.rgba(1.0, 1.0, 0.94, 0.95 * beamStrength));

                    ctx.beginPath();
                    ctx.moveTo(sx, sy);
                    ctx.lineTo(ex, ey);
                    ctx.lineWidth = 2.0 * beamStrength;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = grad;
                    ctx.stroke();
                }
            }

            // Draw Hub spokes (start cleanly from near center icon radius = 18 -> Hop 1)
            for (let k = 0; k < spokes.length; k++) {
                const sp = spokes[k];
                const p = pts[sp.dst];
                const ang = Math.atan2(p.y - hy, p.x - hx);
                const sx = hx + Math.cos(ang) * spokeOriginR;
                const sy = hy + Math.sin(ang) * spokeOriginR;
                drawCausalBeam(sx, sy, p.x, p.y, sp.start, sp.dur, 0.22, 1.0);
            }

            // Draw radial & cross edges strictly flowing outward from earlier-arrived endpoint to later endpoint at uniform speed
            for (let k = 0; k < allEdges.length; k++) {
                const ed = allEdges[k];
                const src = arrive[ed.a] <= arrive[ed.b] ? ed.a : ed.b;
                const dst = src === ed.a ? ed.b : ed.a;
                const pa = pts[src];
                const pb = pts[dst];
                const baseA = ed.isCross ? 0.12 : (pts[dst].hop === 3 ? 0.14 : 0.19);
                const str = ed.isCross ? 0.56 : 1.0;
                drawCausalBeam(pa.x, pa.y, pb.x, pb.y, arrive[src], ed.dur, baseA, str);
            }

            // Nodes ONLY illuminate starting at exact causal arrive[i]
            for (let i = 0; i < pts.length; i++) {
                const p = pts[i];
                let g = 0.0;
                if (root.showCenterHub && phase >= arrive[i]) {
                    const elapsed = phase - arrive[i];
                    if (elapsed <= 0.30) {
                        const rise = Math.min(1.0, elapsed / 0.035);
                        const fall = Math.pow(1.0 - Math.max(0.0, (elapsed - 0.035) / 0.265), 1.7);
                        g = rise * fall;
                    }
                }

                ctx.beginPath();
                ctx.arc(p.x, p.y, p.r * (2.2 + g * 2.0), 0, Math.PI * 2);
                ctx.fillStyle = Qt.rgba(c.r, c.g, c.b, 0.06 + g * 0.24);
                ctx.fill();

                ctx.beginPath();
                ctx.arc(p.x, p.y, p.r * (0.92 + g * 0.45), 0, Math.PI * 2);
                ctx.fillStyle = Qt.rgba(
                    c.r + (1.0 - c.r) * (0.14 + g * 0.68),
                    c.g + (1.0 - c.g) * (0.14 + g * 0.68),
                    c.b + (1.0 - c.b) * (0.14 + g * 0.68),
                    0.40 + g * 0.60
                );
                ctx.fill();
            }
        }
    }

    // Center Source Hub icon-only (no circle background, no border ring — spaciously inside inner ellipse!)
    Item {
        id: centerHub
        x: root.hubX - width / 2
        y: root.hubY - height / 2
        width: 34
        height: 34
        opacity: root.lightActive ? root.openReveal : 0.0
        scale: (root.lightActive ? (0.65 + 0.35 * root.openReveal) : 0.68) * (hubMa.pressed ? 0.92 : (root.hubClickable && hubMa.containsMouse ? 1.12 : 1.0))
        visible: opacity > 0.01

        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.InOutQuad } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        readonly property real emitBurst: root.pulseTime <= 0.16 ? Math.sin((root.pulseTime / 0.16) * Math.PI) : 0.0
        property real hoverRipple: 0.0

        NumberAnimation on hoverRipple {
            running: root.hubClickable && hubMa.containsMouse && root.animate && root.lightActive
            from: 0.0; to: 1.0
            duration: 1450
            loops: Animation.Infinite
            onRunningChanged: if (!running) centerHub.hoverRipple = 0.0
        }

        // Hover expanding signal ripples when Center Hub acts as Scan trigger
        Repeater {
            model: 2
            Rectangle {
                required property int index
                readonly property real p: (centerHub.hoverRipple + index * 0.5) % 1.0
                readonly property real easeP: 1.0 - Math.pow(1.0 - p, 2)
                anchors.centerIn: parent
                width: 44 + easeP * 32
                height: width
                radius: width / 2
                visible: root.hubClickable && hubMa.containsMouse
                color: "transparent"
                border.width: 1.4
                border.color: Qt.alpha(root.accentColor, (1.0 - easeP) * 0.68)
            }
        }

        // Soft hover halo behind icon when clickable
        Rectangle {
            anchors.centerIn: parent
            width: 50
            height: 50
            radius: 25
            visible: root.hubClickable
            opacity: hubMa.containsMouse ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            color: Qt.alpha(root.accentColor, 0.16)
            border.width: 1.2
            border.color: Qt.alpha(root.accentColor, 0.58)
        }

        HubSourceGlyph {
            anchors.centerIn: parent
            sourceKind: root.sourceKind
            btIconGlyph: root.btIconGlyph
            accentColor: root.accentColor
            glyphSize: 28
            scale: 1.0 + centerHub.emitBurst * 0.06
        }

        MouseArea {
            id: hubMa
            anchors.fill: parent
            anchors.margins: -14
            hoverEnabled: root.hubClickable
            enabled: root.hubClickable && root.lightActive
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.hubClicked()
        }
    }
}
