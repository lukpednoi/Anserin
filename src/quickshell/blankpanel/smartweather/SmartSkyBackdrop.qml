import QtQuick
import QtQuick.Shapes

/**
 * Full-page Atmospheric Blur + Smart Mirror Horizon sky engine.
 * Preserves Dashboard WeatherScene's 24-hour sun/moon cycle, synodic moon phase,
 * wind-driven drift, and staged weather transitions — reimagined across the entire
 * page with a GPU atmospheric blur shader and a luminous horizon plane where the
 * sun and moon visibly rise and set.
 */
Item {
    id: scene

    property real hour: 12                 // 0.0 - 24.0
    property var date: new Date()          // for synodic moon phase
    property string condition: "clear"     // clear, cloudy, overcast, mist, rain, snow, storm
    property real wind: 3.4                // m/s
    property real horizonFrac: 0.56        // normalized horizon Y
    property real cornerRadius: 20         // px rounded clip in shader
    property bool showArc: true            // delicate celestial arc hairline
    property color arcAccent: "#ffffff"
    property bool useAccentArc: false
    property bool running: true
    property real time: 0

    // Wind drift & continuous clock (runs ONLY while visible & running)
    property real windShown: wind
    property real drift: 0
    property real cloudDrift: 0
    property real breezePhase: 0

    FrameAnimation {
        running: scene.running && scene.visible
        onTriggered: {
            const dt = Math.min(frameTime, 0.05);
            scene.time += dt;
            scene.drift += dt * scene.windShown * 14;
            scene.cloudDrift += dt * (0.35 + scene.windShown * 0.16);
            scene.breezePhase += dt / (3.8 - Math.min(1.6, scene.windShown * 0.07));
        }
    }

    // ---------- math helpers ----------
    function rnd(i) { const x = Math.sin(i * 12.9898 + 78.233) * 43758.5453; return x - Math.floor(x); }
    function hex(s) { return [parseInt(s.substr(1, 2), 16) / 255, parseInt(s.substr(3, 2), 16) / 255, parseInt(s.substr(5, 2), 16) / 255]; }
    function lerp3(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
    function rgb(c, a) { return Qt.rgba(c[0], c[1], c[2], a === undefined ? 1 : a); }
    function clamp01(v) { return Math.max(0, Math.min(1, v)); }

    // ---------- Dashboard 24-hour daylight & rich atmospheric sky keys ----------
    // Smooth daylight factor: 0 at night, 1 by day, easing over 05:00-07:15 and 16:45-19:15
    readonly property real light: {
        const h = ((hour % 24) + 24) % 24;
        if (h < 5.0 || h >= 19.25) return 0;
        if (h < 7.25) return (h - 5.0) / 2.25;
        if (h < 16.75) return 1;
        return 1 - (h - 16.75) / 2.5;
    }
    readonly property real night: 1 - light

    // Refined Smart-Mirror atmospheric sky palette (top, mid, horizon, smoked-mirror ground)
    readonly property var skyKeys: [
        { h: 0.0,  c: ["#050814", "#0b1228", "#162040", "#05070e"] },
        { h: 4.5,  c: ["#070c1d", "#111938", "#232a4f", "#060811"] },
        { h: 5.5,  c: ["#141c3d", "#45375e", "#9e5c64", "#0a0a14"] },
        { h: 6.2,  c: ["#223568", "#9c6076", "#eba46e", "#100d15"] },
        { h: 7.5,  c: ["#285b9c", "#5491c9", "#b7d5e8", "#0c1420"] },
        { h: 12.0, c: ["#1f5da8", "#488fd0", "#a6d0eb", "#0b1420"] },
        { h: 15.8, c: ["#265c9d", "#5e92c4", "#d9c6a6", "#0d131c"] },
        { h: 17.5, c: ["#222c5c", "#a14e6c", "#ec8d52", "#120c14"] },
        { h: 18.4, c: ["#161b42", "#5d3560", "#b85c68", "#0b0912"] },
        { h: 19.6, c: ["#0b1028", "#1d1f44", "#3c3156", "#070810"] },
        { h: 21.0, c: ["#050814", "#0b1228", "#162040", "#05070e"] },
        { h: 24.0, c: ["#050814", "#0b1228", "#162040", "#05070e"] }
    ]

    // Weather presets matching Dashboard WeatherScene's exact 7 conditions & staged heaviness
    readonly property var looks: ({
        clear:    { heavy: 0, veil: 0.00, day: "#8e99a8", night: "#131724", cloud: 0.14, tone: 0.05, body: 1.00, stars: 1.00, breeze: 1.0, mist: 0.0, rain: 0.0, snow: 0.0, storm: 0.0 },
        cloudy:   { heavy: 1, veil: 0.22, day: "#96a2b2", night: "#161b2a", cloud: 0.48, tone: 0.22, body: 0.88, stars: 0.55, breeze: 1.0, mist: 0.0, rain: 0.0, snow: 0.0, storm: 0.0 },
        mist:     { heavy: 1, veil: 0.44, day: "#aeb7c4", night: "#1f2533", cloud: 0.36, tone: 0.25, body: 0.52, stars: 0.30, breeze: 0.5, mist: 1.0, rain: 0.0, snow: 0.0, storm: 0.0 },
        overcast: { heavy: 2, veil: 0.62, day: "#7b8594", night: "#131722", cloud: 0.82, tone: 0.52, body: 0.28, stars: 0.06, breeze: 0.8, mist: 0.2, rain: 0.0, snow: 0.0, storm: 0.0 },
        snow:     { heavy: 3, veil: 0.52, day: "#a8b2c0", night: "#1c2230", cloud: 0.72, tone: 0.32, body: 0.30, stars: 0.08, breeze: 0.0, mist: 0.25, rain: 0.0, snow: 1.0, storm: 0.0 },
        rain:     { heavy: 3, veil: 0.70, day: "#5b6575", night: "#0e121c", cloud: 0.88, tone: 0.72, body: 0.24, stars: 0.04, breeze: 0.0, mist: 0.18, rain: 0.82, snow: 0.0, storm: 0.0 },
        storm:    { heavy: 4, veil: 0.84, day: "#3d4454", night: "#090c14", cloud: 0.96, tone: 0.92, body: 0.18, stars: 0.02, breeze: 0.0, mist: 0.15, rain: 1.0, snow: 0.0, storm: 1.0 }
    })
    readonly property var target: looks[condition] || looks.clear

    // Eased weather amounts
    property real veilA: 0
    property color veilDay: "#8e99a8"
    property color veilNight: "#131724"
    property real cloudAmt: 0.14
    property real cloudToneAmt: 0.05
    property real bodyShow: 1
    property real starsAmt: 1
    property real breezeAmt: 1
    property real mistAmt: 0
    property real rainAmt: 0
    property real snowAmt: 0
    property real stormAmt: 0
    property int heavyNow: 0

    property bool animateNext: false
    function animateNextChange() {
        animateNext = true;
        Qt.callLater(() => scene.animateNext = false);
    }

    function setAll() {
        changeAnim.stop();
        windEase.stop();
        windShown = wind;
        const t = target;
        goal = t;
        veilA = t.veil; veilDay = t.day; veilNight = t.night;
        cloudAmt = t.cloud; cloudToneAmt = t.tone; bodyShow = t.body;
        starsAmt = t.stars; breezeAmt = t.breeze; mistAmt = t.mist;
        rainAmt = t.rain; snowAmt = t.snow; stormAmt = t.storm;
        heavyNow = t.heavy;
    }

    property var goal: looks.clear
    property int skyDelay: 0
    property int fallDelay: 850
    function ease() {
        const t = target;
        changeAnim.stop();
        const worse = t.heavy >= heavyNow;
        skyDelay = worse ? 0 : 700;
        fallDelay = worse ? 850 : 0;
        heavyNow = t.heavy;
        goal = t;
        changeAnim.start();
    }
    onTargetChanged: if (animateNext) ease(); else setAll()
    Component.onCompleted: { setAll(); phaseShown = moonPhase; }

    ParallelAnimation {
        id: changeAnim
        SequentialAnimation {
            PauseAnimation { duration: scene.skyDelay }
            ParallelAnimation {
                NumberAnimation { target: scene; property: "veilA"; to: scene.goal.veil; duration: 1400; easing.type: Easing.InOutSine }
                ColorAnimation { target: scene; property: "veilDay"; to: scene.goal.day; duration: 1400 }
                ColorAnimation { target: scene; property: "veilNight"; to: scene.goal.night; duration: 1400 }
                NumberAnimation { target: scene; property: "cloudAmt"; to: scene.goal.cloud; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "cloudToneAmt"; to: scene.goal.tone; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "bodyShow"; to: scene.goal.body; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "starsAmt"; to: scene.goal.stars; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "breezeAmt"; to: scene.goal.breeze; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "mistAmt"; to: scene.goal.mist; duration: 1500; easing.type: Easing.InOutSine }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: scene.fallDelay }
            ParallelAnimation {
                NumberAnimation { target: scene; property: "rainAmt"; to: scene.goal.rain; duration: 1300; easing.type: Easing.InQuad }
                NumberAnimation { target: scene; property: "snowAmt"; to: scene.goal.snow; duration: 1300; easing.type: Easing.InQuad }
                NumberAnimation { target: scene; property: "stormAmt"; to: scene.goal.storm; duration: 1300; easing.type: Easing.InOutSine }
            }
        }
    }

    onWindChanged: {
        windEase.stop();
        if (animateNext) { windEase.to = wind; windEase.start(); }
        else windShown = wind;
    }
    NumberAnimation { id: windEase; target: scene; property: "windShown"; duration: 1800; easing.type: Easing.InOutSine }

    function skyAt(k) {
        const h = ((hour % 24) + 24) % 24;
        let i = 0;
        while (i < skyKeys.length - 2 && h >= skyKeys[i + 1].h) i++;
        const a = skyKeys[i], b = skyKeys[i + 1];
        const t = clamp01((h - a.h) / Math.max(0.001, b.h - a.h));
        const base = lerp3(hex(a.c[k]), hex(b.c[k]), t);
        if (k === 3) return base; // ground smoked glass stays sleek
        const grey = lerp3([veilNight.r, veilNight.g, veilNight.b], [veilDay.r, veilDay.g, veilDay.b], light);
        return lerp3(base, grey, veilA);
    }

    readonly property color skyTopCol: rgb(skyAt(0))
    readonly property color skyMidCol: rgb(skyAt(1))
    readonly property color skyLowCol: rgb(skyAt(2))
    readonly property color groundCol: rgb(skyAt(3))

    // ---------- Sun & Moon Horizon Arc ----------
    // Sun: 06:00-18:00 (zenith 12:00), Moon: 18:00-06:00 (zenith 00:00)
    readonly property real normHour: ((hour % 24) + 24) % 24
    readonly property bool sunUp: normHour >= 6 && normHour < 18
    readonly property real arcT: sunUp ? (normHour - 6) / 12 : ((normHour + 6) % 24) / 12

    readonly property real horizonY: height * horizonFrac
    readonly property real zenithY: height * 0.21
    readonly property real arcRx: width * 0.40
    readonly property real arcRy: Math.max(24, horizonY - zenithY)

    // Smooth emergence right out of the horizon line:
    // At arcT = 0.0 (06:00 / 18:00), the center sits right on horizonY (half-disc peeking above horizon!)
    // Slightly sinks just under horizon in the first/last 12 minutes so rise/set feels cinematic
    readonly property real edgeDip: {
        const edge = Math.min(arcT, 1 - arcT);
        const span = 12 / 720; // 12 minutes
        return edge < span ? (1 - edge / span) * 14 : 0;
    }
    readonly property real bodyX: width * 0.5 - arcRx * Math.cos(Math.PI * arcT)
    readonly property real bodyY: horizonY - arcRy * Math.sin(Math.PI * arcT) + edgeDip
    readonly property real lowFactor: 1 - Math.sin(Math.PI * arcT) // 1 near horizon, 0 at noon/midnight

    // Body tint: deep warm coral-gold on the horizon -> bright crisp ivory-sun at noon; silver-ice for moon
    readonly property color sunColor: Qt.rgba(
        1.0,
        0.92 - 0.34 * Math.pow(lowFactor, 1.3),
        0.72 - 0.44 * Math.pow(lowFactor, 1.1),
        1.0
    )
    readonly property color moonColor: "#e6eeff"
    readonly property color activeBodyColor: sunUp ? sunColor : moonColor

    // ---------- Synodic Moon Phase ----------
    readonly property real moonPhase: {
        const ref = Date.UTC(2000, 0, 6, 18, 14);
        const ms = date && typeof date.getTime === "function" ? date.getTime() : Date.now();
        const days = (ms - ref) / 86400000;
        const p = (days % 29.530588) / 29.530588;
        return p < 0 ? p + 1 : p;
    }
    property real phaseShown: 0.25
    readonly property real phaseDrawn: phaseShown - Math.floor(phaseShown)
    onMoonPhaseChanged: {
        phaseEase.stop();
        let d = moonPhase - phaseDrawn;
        if (d > 0.5) d -= 1;
        if (d < -0.5) d += 1;
        if (animateNext) { phaseEase.to = phaseShown + d; phaseEase.start(); }
        else phaseShown = moonPhase;
    }
    NumberAnimation { id: phaseEase; target: scene; property: "phaseShown"; duration: 1800; easing.type: Easing.InOutSine }

    readonly property real moonLit: (1 - Math.cos(2 * Math.PI * phaseDrawn)) / 2
    readonly property string moonName: {
        const p = moonPhase;
        if (p < 0.03 || p >= 0.97) return "New Moon";
        if (p < 0.22) return "Waxing Crescent";
        if (p < 0.28) return "First Quarter";
        if (p < 0.47) return "Waxing Gibbous";
        if (p < 0.53) return "Full Moon";
        if (p < 0.72) return "Waning Gibbous";
        if (p < 0.78) return "Last Quarter";
        return "Waning Crescent";
    }

    // ---------- Storm Lightning ----------
    readonly property real windX: windShown * 14
    readonly property int strikeIndex: Math.floor(time / 4.6)
    readonly property real strikeT: time - strikeIndex * 4.6 - rnd(strikeIndex + 7) * 2.1
    readonly property real flash: {
        if (stormAmt < 0.78 || strikeT < 0 || strikeT > 0.40) return 0;
        const t = strikeT;
        if (t < 0.06) return 0.58;
        if (t < 0.12) return 0.08;
        if (t < 0.19) return 0.42;
        return 0.42 * (1 - (t - 0.19) / 0.21);
    }

    // =========================================================================
    // LAYER 1: Full-page GPU Atmospheric Blur + Horizon Reflection Shader
    // =========================================================================
    ShaderEffect {
        id: skyShader
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/smart_sky_blur.frag.qsb")

        property vector2d res: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        property real time: scene.time
        property real cloudDrift: scene.cloudDrift
        property color skyTop: scene.skyTopCol
        property color skyMid: scene.skyMidCol
        property color skyLow: scene.skyLowCol
        property color groundCol: scene.groundCol
        property color bodyCol: Qt.rgba(scene.activeBodyColor.r, scene.activeBodyColor.g, scene.activeBodyColor.b, scene.bodyShow)
        property vector2d bodyPos: Qt.vector2d(
            scene.bodyX / Math.max(1, scene.width),
            scene.bodyY / Math.max(1, scene.height)
        )
        property real horizonY: scene.horizonFrac
        property real daylight: scene.light
        property real sunUp: scene.sunUp ? 1.0 : 0.0
        property real cloudCover: scene.cloudAmt
        property real cloudTone: scene.cloudToneAmt
        property real mistAmt: scene.mistAmt
        property real flashAmt: scene.flash
        property real cornerRadius: scene.cornerRadius
    }

    // =========================================================================
    // LAYER 2: Horizon-Clipped Sky Elements (Stars, Arc, Rising Sun / Moon)
    // Clipped cleanly at y = horizonY so the sun/moon truly emerge from the horizon!
    // =========================================================================
    Item {
        id: aboveHorizon
        x: 0
        y: 0
        width: scene.width
        height: Math.max(1, Math.round(scene.horizonY))
        clip: true

        // Twinkling minimal stars at night (fade out toward horizon & behind clouds)
        Repeater {
            model: 44
            Rectangle {
                required property int index
                readonly property real yNorm: 0.04 + scene.rnd(index + 100) * 0.78
                readonly property real tw: 0.45 + 0.55 * Math.sin(scene.time * (0.7 + scene.rnd(index + 3) * 1.5) + index * 1.3)
                visible: scene.night > 0.08 && scene.starsAmt > 0.03
                x: scene.rnd(index) * aboveHorizon.width
                y: yNorm * aboveHorizon.height
                width: scene.rnd(index + 200) > 0.84 ? 2.2 : 1.3
                height: width
                radius: width / 2
                color: scene.rnd(index + 300) > 0.7 ? "#dbe8ff" : "#fffcf2"
                opacity: scene.night * tw * scene.starsAmt * (1.0 - yNorm * 0.65)
            }
        }

        // Delicate Smart Mirror Celestial Arc Hairline
        Shape {
            id: celestialArc
            visible: scene.showArc
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            readonly property real cx: scene.width * 0.5
            readonly property real rx: scene.arcRx
            readonly property real ry: scene.arcRy
            readonly property real hY: aboveHorizon.height
            readonly property real px: cx - rx * Math.cos(Math.PI * scene.arcT)
            readonly property real py: hY - ry * Math.sin(Math.PI * scene.arcT)
            readonly property string radii: rx.toFixed(1) + " " + ry.toFixed(1)
            readonly property color lineCol: scene.useAccentArc
                ? scene.arcAccent
                : (scene.sunUp ? "#ffe2b0" : "#dbe6ff")

            // Remaining future path (ultra-faint dashed hairline)
            ShapePath {
                strokeColor: Qt.alpha("#ffffff", 0.14)
                strokeWidth: 1.0
                strokeStyle: ShapePath.DashLine
                dashPattern: [3, 6]
                fillColor: "transparent"
                PathSvg {
                    path: "M " + (celestialArc.cx - celestialArc.rx).toFixed(1) + " " + celestialArc.hY.toFixed(1)
                        + " A " + celestialArc.radii + " 0 0 1 "
                        + (celestialArc.cx + celestialArc.rx).toFixed(1) + " " + celestialArc.hY.toFixed(1)
                }
            }

            // Soft outer aura along elapsed path
            ShapePath {
                strokeColor: Qt.alpha(celestialArc.lineCol, 0.16 * scene.bodyShow)
                strokeWidth: 5.0
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: scene.arcT > 0.004
                        ? ("M " + (celestialArc.cx - celestialArc.rx).toFixed(1) + " " + celestialArc.hY.toFixed(1)
                           + " A " + celestialArc.radii + " 0 0 1 "
                           + celestialArc.px.toFixed(1) + " " + celestialArc.py.toFixed(1))
                        : ""
                }
            }

            // Crisp hairline along elapsed path
            ShapePath {
                strokeColor: Qt.alpha(celestialArc.lineCol, 0.52 * scene.bodyShow)
                strokeWidth: 1.25
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg {
                    path: scene.arcT > 0.004
                        ? ("M " + (celestialArc.cx - celestialArc.rx).toFixed(1) + " " + celestialArc.hY.toFixed(1)
                           + " A " + celestialArc.radii + " 0 0 1 "
                           + celestialArc.px.toFixed(1) + " " + celestialArc.py.toFixed(1))
                        : ""
                }
            }
        }

        // ---- THE SUN (rises directly out of the horizon line! Silky GPU bloom comes from skyShader) ----
        Item {
            id: sunItem
            visible: scene.sunUp
            x: scene.bodyX
            y: scene.bodyY
            opacity: scene.bodyShow
            readonly property real baseR: Math.max(13, Math.min(24, scene.height * 0.026))

            // Sun photosphere disc
            Rectangle {
                width: sunItem.baseR * 2
                height: width
                radius: sunItem.baseR
                x: -sunItem.baseR
                y: -sunItem.baseR
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#fffef8" }
                    GradientStop { position: 0.62; color: scene.sunColor }
                    GradientStop { position: 1.0; color: Qt.darker(scene.sunColor, 1.06) }
                }
            }
        }

        // ---- THE MOON (with real synodic phase, rises cleanly from horizon) ----
        Item {
            id: moonItem
            visible: !scene.sunUp
            x: scene.bodyX
            y: scene.bodyY
            opacity: scene.bodyShow
            readonly property real r: Math.max(12, Math.min(21, scene.height * 0.023))
            readonly property real k: Math.cos(2 * Math.PI * scene.phaseDrawn)
            readonly property bool waxing: scene.phaseDrawn < 0.5

            // Earthshine dark limb ring
            Rectangle {
                width: moonItem.r * 2; height: width; radius: moonItem.r
                x: -moonItem.r; y: -moonItem.r
                color: Qt.rgba(0.84, 0.89, 1.0, 0.10)
                border.width: 0.8
                border.color: Qt.rgba(0.88, 0.93, 1.0, 0.24)
            }
            // Lit synodic phase shape
            Shape {
                x: -moonItem.r; y: -moonItem.r
                width: moonItem.r * 2; height: moonItem.r * 2
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: "#f2f6ff"
                    PathSvg {
                        path: {
                            const r = moonItem.r;
                            const rx = Math.max(0.01, Math.abs(moonItem.k) * r);
                            if (scene.moonLit < 0.015) return "";
                            const limb = moonItem.waxing ? 1 : 0;
                            const term = moonItem.waxing ? (moonItem.k > 0 ? 0 : 1) : (moonItem.k > 0 ? 1 : 0);
                            return "M " + r + " 0 A " + r + " " + r + " 0 0 " + limb + " " + r + " " + (2 * r)
                                 + " A " + rx + " " + r + " 0 0 " + term + " " + r + " 0 Z";
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // LAYER 3: Full-Page Subtle Weather Particles (Breeze, Rain, Snow, Lightning)
    // =========================================================================
    Item {
        id: weatherFx
        anchors.fill: parent
        clip: true

        // Delicate daytime breeze streaks
        Repeater {
            model: 6
            Rectangle {
                required property int index
                visible: scene.light > 0.25 && scene.breezeAmt > 0.02 && index < Math.min(6, 2 + Math.floor(scene.windShown / 4))
                readonly property real u: (scene.breezePhase + scene.rnd(index + 3) * 3) % 1
                width: 65 + scene.rnd(index + 13) * 65
                height: 1.0
                x: -width + u * (scene.width + width * 2)
                y: scene.horizonY * (0.18 + scene.rnd(index + 23) * 0.72) + Math.sin(u * 5 + index) * 4
                opacity: Math.sin(Math.PI * u) * 0.28 * scene.light * scene.breezeAmt
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.55; color: "#ffffff" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        // Ultra-fine Smart Mirror rain streaks (angled by wind, strongest in sky above horizon)
        Repeater {
            model: 95
            Rectangle {
                required property int index
                visible: scene.rainAmt * 95 > index
                readonly property real vy: 460 + scene.rnd(index + 1) * 210
                readonly property real spanX: scene.width + 260
                readonly property real yPos: ((scene.rnd(index + 4) * (scene.height + 36) + scene.time * vy) % (scene.height + 36)) - 36
                readonly property real lowerFade: yPos > scene.horizonY ? 0.35 : 1.0
                width: 1.1
                height: 14 + scene.rnd(index + 8) * 10
                radius: 0.55
                color: "#dce8ff"
                opacity: (0.18 + scene.rnd(index + 2) * 0.26) * scene.rainAmt * lowerFade
                rotation: -Math.atan2(scene.windX, vy) * 180 / Math.PI
                x: (((scene.rnd(index + 3) * spanX + scene.drift) % spanX) + spanX) % spanX - 130
                y: yPos
            }
        }

        // Delicate drifting snowflakes
        Repeater {
            model: 64
            Rectangle {
                required property int index
                visible: scene.snowAmt * 64 > index
                readonly property real vy: 28 + scene.rnd(index + 1) * 34
                readonly property real spanX: scene.width + 90
                width: 1.8 + scene.rnd(index + 5) * 2.4
                height: width
                radius: width / 2
                color: "#ffffff"
                opacity: (0.45 + scene.rnd(index + 9) * 0.42) * scene.snowAmt
                x: (((scene.rnd(index + 3) * spanX + scene.drift * 0.36 + Math.sin(scene.time * 1.1 + index) * 14) % spanX) + spanX) % spanX - 45
                y: ((scene.rnd(index + 4) * (scene.height + 14) + scene.time * vy) % (scene.height + 14)) - 14
            }
        }

        // Minimal high-altitude lightning bolt (above horizon)
        Shape {
            id: boltShape
            visible: scene.flash > 0.06
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property var pts: {
                const k = scene.strikeIndex;
                const out = [];
                let x = scene.width * (0.22 + 0.56 * scene.rnd(k * 3 + 1));
                for (let i = 0; i <= 7; i++) {
                    out.push(Qt.point(x, scene.horizonY * i / 7));
                    x += (scene.rnd(k * 17 + i) - 0.5) * 42;
                }
                return out;
            }
            ShapePath {
                strokeColor: Qt.rgba(0.84, 0.91, 1.0, 0.32 * scene.flash)
                strokeWidth: 7
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: boltShape.pts }
            }
            ShapePath {
                strokeColor: Qt.rgba(1, 1, 1, Math.min(1, scene.flash * 1.6))
                strokeWidth: 1.8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: boltShape.pts }
            }
        }
    }
}
