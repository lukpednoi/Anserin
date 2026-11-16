import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

// The animated scene behind the Dashboard Weather box (sky, sun or moon, clouds, meadow, weather), drawn at its
// design size 565 x 262 (a host scales it). The sun crosses the sky 06:00-17:59 (highest at 12:00), the moon
// 18:00-05:59 (highest at 00:00) with the date's phase; the arc line can show their path. Everything moves from
// one clock (`time`), advanced only while the scene runs and shows; the wind's drift is added up frame by frame,
// so a change of wind never jumps the clouds, rain or grass. The weather is drawn from eased amounts (cloud cover,
// veil, rain, snow, mist, lightning...): they follow `condition` at once, or, after `animateNextChange()` (a day
// change), over about 2.5 s in stages: worse weather gathers its clouds first and then lets the rain or snow come,
// better weather stops the rain first and then breaks the clouds up; the moon's phase turns smoothly. It uses no
// shell singletons, so the stand-alone preview (preview/SceneDesign.qml) draws the same file.
Item {
    id: scene

    property real hour: 12               // 0 - 24
    property var date: new Date()        // for the moon's phase
    property string condition: "clear"   // clear, cloudy, overcast, mist, rain, snow, storm
    property real wind: 3                // m/s
    property real intensity: 1
    property string look: "flat"         // flat, pixel, soft
    property string moonTone: "yellow"   // yellow, white
    property bool showPath: false        // the arc line along the sun's or moon's path
    property string pathTone: "theme"    // theme (themeColor), daynight (orange-yellow by day, glowing white by night)
    property color themeColor: "#d3c972"
    property real cornerRadius: 16
    property bool running: true
    property real time: 0                // seconds of animation

    implicitWidth: 565
    implicitHeight: 262

    // the wind's drift and the grass's sway, added up frame by frame so a change of wind only changes their speed
    property real windShown: wind
    property real drift: 0                 // px the wind has carried things sideways
    property real cloudDrift: 0
    property real swayPhase: 0
    property real breezePhase: 0
    FrameAnimation {
        running: scene.running && scene.visible
        onTriggered: {
            const dt = frameTime;
            scene.time += dt;
            scene.drift += dt * scene.windShown * 12;
            scene.cloudDrift += dt * scene.windShown * 1.4;
            scene.swayPhase += dt * (1.3 + scene.windShown * 0.05);
            scene.breezePhase += dt / (3.6 - Math.min(1.6, scene.windShown * 0.08));
        }
    }

    // ---------- helpers ----------
    function rnd(i) { const x = Math.sin(i * 12.9898 + 78.233) * 43758.5453; return x - Math.floor(x); }
    function hex(s) { return [parseInt(s.substr(1, 2), 16) / 255, parseInt(s.substr(3, 2), 16) / 255, parseInt(s.substr(5, 2), 16) / 255]; }
    function lerp(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
    function rgb(c, a) { return Qt.rgba(c[0], c[1], c[2], a === undefined ? 1 : a); }
    function clamp01(v) { return Math.max(0, Math.min(1, v)); }

    // ---------- time of day ----------
    // daylight: 0 at night, 1 by day, easing over 05:00-07:00 and 17:00-19:00
    readonly property real light: {
        const h = hour;
        if (h < 5 || h >= 19) return 0;
        if (h < 7) return (h - 5) / 2;
        if (h < 17) return 1;
        return 1 - (h - 17) / 2;
    }
    readonly property real night: 1 - light

    // sky colours (top, middle, horizon) at key hours, blended between them
    readonly property var skyKeys: [
        { h: 0,    c: ["#070b1f", "#121a3a", "#1f2650"] },
        { h: 4.5,  c: ["#0a1029", "#18214a", "#2c3463"] },
        { h: 6,    c: ["#33427f", "#c97d8f", "#f5b98a"] },
        { h: 7.5,  c: ["#3f86d4", "#86bff0", "#d9eef8"] },
        { h: 12,   c: ["#2f7fd3", "#74b8ef", "#cfe8f8"] },
        { h: 16,   c: ["#3e86cf", "#8ec1ea", "#f2e1bd"] },
        { h: 18,   c: ["#363c7c", "#d0698a", "#f5a565"] },
        { h: 19.5, c: ["#18204d", "#45386f", "#86587a"] },
        { h: 21,   c: ["#070b1f", "#121a3a", "#1f2650"] },
        { h: 24,   c: ["#070b1f", "#121a3a", "#1f2650"] }
    ]
    // each weather's look: the sky's veil (how far it greys, towards what by day and night), the clouds (how many,
    // their size, height and tone, how solid), how much sun or moon shows, the stars, the night's fireflies, the
    // day's breeze, mist, rain (its share of the drops), snow (and snow lying on the grass), lightning; and how
    // heavy it is, which decides the order of a change
    readonly property var looks: ({
        clear:    { heavy: 0, veil: 0.0,  day: "#9aa4b2", night: "#1a1f2e", n: 3,  min: 0.14, max: 0.22, top: 0.06,  low: 0.38, tone: 0,    solid: 0.95, body: 1,    stars: 1,    glow: 0, flies: 1, breeze: 1, mist: 0, rain: 0,   snow: 0, storm: 0 },
        cloudy:   { heavy: 1, veil: 0.22, day: "#a9b3c1", night: "#1c2233", n: 8,  min: 0.2,  max: 0.32, top: 0.0,   low: 0.45, tone: 0.15, solid: 0.95, body: 1,    stars: 0.6,  glow: 0, flies: 1, breeze: 1, mist: 0, rain: 0,   snow: 0, storm: 0 },
        mist:     { heavy: 1, veil: 0.45, day: "#c9ced6", night: "#2a2f3c", n: 3,  min: 0.2,  max: 0.3,  top: 0.04,  low: 0.3,  tone: 0.2,  solid: 0.45, body: 0.55, stars: 0.35, glow: 0, flies: 1, breeze: 1, mist: 1, rain: 0,   snow: 0, storm: 0 },
        overcast: { heavy: 2, veil: 0.62, day: "#8f98a6", night: "#181c28", n: 16, min: 0.3,  max: 0.46, top: -0.15, low: 0.5,  tone: 0.45, solid: 0.9,  body: 0.3,  stars: 0.05, glow: 1, flies: 0, breeze: 1, mist: 0, rain: 0,   snow: 0, storm: 0 },
        snow:     { heavy: 3, veil: 0.5,  day: "#c3cad4", night: "#262c3a", n: 12, min: 0.3,  max: 0.44, top: -0.15, low: 0.45, tone: 0.3,  solid: 0.9,  body: 0.3,  stars: 0.05, glow: 1, flies: 0, breeze: 0, mist: 0, rain: 0,   snow: 1, storm: 0 },
        rain:     { heavy: 3, veil: 0.7,  day: "#6f7887", night: "#141824", n: 16, min: 0.32, max: 0.48, top: -0.18, low: 0.48, tone: 0.65, solid: 0.9,  body: 0.3,  stars: 0.05, glow: 1, flies: 0, breeze: 0, mist: 0, rain: 0.8, snow: 0, storm: 0 },
        storm:    { heavy: 4, veil: 0.82, day: "#4f5666", night: "#0f121b", n: 18, min: 0.34, max: 0.5,  top: -0.2,  low: 0.5,  tone: 0.85, solid: 0.9,  body: 0.3,  stars: 0.05, glow: 0.6, flies: 0, breeze: 0, mist: 0, rain: 1, snow: 0, storm: 1 }
    })
    readonly property var target: looks[condition] || looks.clear

    // the amounts the scene is drawn from, eased towards `target`
    property real veilA: 0
    property color veilDay: "#9aa4b2"
    property color veilNight: "#1a1f2e"
    property real cloudN: 3
    property real cloudMin: 0.14
    property real cloudMax: 0.22
    property real cloudTop: 0.06
    property real cloudLow: 0.38
    property real cloudTone: 0
    property real cloudSolid: 0.95
    property real bodyShow: 1
    property real starsAmt: 1
    property real glowAmt: 0
    property real fliesAmt: 1
    property real breezeAmt: 1
    property real mistAmt: 0
    property real rainAmt: 0
    property real snowAmt: 0
    property real frostAmt: 0
    property real stormAmt: 0
    property int heavyNow: 0

    // the next change of `condition`, wind or date eases in stages instead of at once (the host calls this just
    // before changing the day)
    property bool animateNext: false
    function animateNextChange() {
        animateNext = true;
        Qt.callLater(() => scene.animateNext = false);
    }

    function setAll() {
        change.stop();
        windEase.stop();
        windShown = wind;
        const t = target;
        goal = t;
        veilA = t.veil; veilDay = t.day; veilNight = t.night;
        cloudN = t.n; cloudMin = t.min; cloudMax = t.max; cloudTop = t.top; cloudLow = t.low; cloudTone = t.tone; cloudSolid = t.solid;
        bodyShow = t.body; starsAmt = t.stars; glowAmt = t.glow; fliesAmt = t.flies; breezeAmt = t.breeze; mistAmt = t.mist;
        rainAmt = t.rain; snowAmt = t.snow; frostAmt = t.snow; stormAmt = t.storm;
        heavyNow = t.heavy;
    }
    // worse weather: the sky first (0 - 1.5 s), then the rain or snow (1.0 - 2.5 s); better: the reverse.
    // The animations run to `goal`, set here before they start: a handler of `target` can run before bindings on
    // it have caught up, and an animation bound to `target` would then run to the previous day's values.
    property var goal: looks.clear
    property int skyDelay: 0
    property int fallDelay: 1000
    function ease() {
        const t = target;
        change.stop();
        const worse = t.heavy >= heavyNow;
        skyDelay = worse ? 0 : 800;
        fallDelay = worse ? 1000 : 0;
        heavyNow = t.heavy;
        goal = t;
        change.start();
    }
    onTargetChanged: if (animateNext) ease(); else setAll()
    Component.onCompleted: { setAll(); phaseShown = moonPhase; }

    ParallelAnimation {
        id: change
        SequentialAnimation {
            PauseAnimation { duration: scene.skyDelay }
            ParallelAnimation {
                NumberAnimation { target: scene; property: "veilA"; to: scene.goal.veil; duration: 1500; easing.type: Easing.InOutSine }
                ColorAnimation { target: scene; property: "veilDay"; to: scene.goal.day; duration: 1500 }
                ColorAnimation { target: scene; property: "veilNight"; to: scene.goal.night; duration: 1500 }
                NumberAnimation { target: scene; property: "cloudN"; to: scene.goal.n; duration: 1700; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "cloudMin"; to: scene.goal.min; duration: 1700; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "cloudMax"; to: scene.goal.max; duration: 1700; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "cloudTop"; to: scene.goal.top; duration: 1700; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "cloudLow"; to: scene.goal.low; duration: 1700; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "cloudTone"; to: scene.goal.tone; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "cloudSolid"; to: scene.goal.solid; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "bodyShow"; to: scene.goal.body; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "starsAmt"; to: scene.goal.stars; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "glowAmt"; to: scene.goal.glow; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "fliesAmt"; to: scene.goal.flies; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "breezeAmt"; to: scene.goal.breeze; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "mistAmt"; to: scene.goal.mist; duration: 1700; easing.type: Easing.InOutSine }
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: scene.fallDelay }
            ParallelAnimation {
                NumberAnimation { target: scene; property: "rainAmt"; to: scene.goal.rain; duration: 1500; easing.type: Easing.InQuad }
                NumberAnimation { target: scene; property: "snowAmt"; to: scene.goal.snow; duration: 1500; easing.type: Easing.InQuad }
                NumberAnimation { target: scene; property: "frostAmt"; to: scene.goal.snow; duration: 1500; easing.type: Easing.InOutSine }
                NumberAnimation { target: scene; property: "stormAmt"; to: scene.goal.storm; duration: 1500; easing.type: Easing.InOutSine }
            }
        }
    }
    onWindChanged: {
        windEase.stop();
        if (animateNext) { windEase.to = wind; windEase.start(); }
        else windShown = wind;
    }
    NumberAnimation { id: windEase; target: scene; property: "windShown"; duration: 2500; easing.type: Easing.InOutSine }

    function skyAt(k) {
        let i = 0;
        while (i < skyKeys.length - 2 && hour >= skyKeys[i + 1].h) i++;
        const a = skyKeys[i], b = skyKeys[i + 1];
        const t = clamp01((hour - a.h) / (b.h - a.h));
        const base = lerp(hex(a.c[k]), hex(b.c[k]), t);
        const grey = lerp([veilNight.r, veilNight.g, veilNight.b], [veilDay.r, veilDay.g, veilDay.b], light);
        return lerp(base, grey, veilA);
    }
    readonly property var skyTop: skyAt(0)
    readonly property var skyMid: skyAt(1)
    readonly property var skyLow: skyAt(2)

    // ---------- sun and moon: locked halves of the day ----------
    readonly property bool sunUp: hour >= 6 && hour < 18
    readonly property real arcT: sunUp ? (hour - 6) / 12 : ((hour + 6) % 24) / 12
    readonly property real horizonY: height * 0.58
    readonly property real zenithY: height * 0.13
    // the last (and first) ten minutes of each half: the body sinks behind the hills
    readonly property real sink: Math.max(0, 1 - Math.min(arcT, 1 - arcT) / (10 / 720)) * height * 0.2
    // along the same half ellipse as the arc line (centre mid-width on the horizon, 0.42 of the width across)
    readonly property real bodyX: width / 2 - width * 0.42 * Math.cos(Math.PI * arcT)
    readonly property real bodyY: horizonY - (horizonY - zenithY) * Math.sin(Math.PI * arcT) + sink

    // the moon's age in the synodic month (0 new, 0.5 full)
    readonly property real moonPhase: {
        const ref = Date.UTC(2000, 0, 6, 18, 14);
        const days = (date.getTime() - ref) / 86400000;
        const p = (days % 29.530588) / 29.530588;
        return p < 0 ? p + 1 : p;
    }
    // the phase drawn: follows the date's at once, or turns the short way round over 2.5 s after animateNextChange()
    property real phaseShown: 0
    readonly property real phaseDrawn: phaseShown - Math.floor(phaseShown)
    onMoonPhaseChanged: {
        phaseEase.stop();
        let d = moonPhase - phaseDrawn;
        if (d > 0.5) d -= 1;
        if (d < -0.5) d += 1;
        if (animateNext) { phaseEase.to = phaseShown + d; phaseEase.start(); }
        else phaseShown = moonPhase;
    }
    NumberAnimation { id: phaseEase; target: scene; property: "phaseShown"; duration: 2500; easing.type: Easing.InOutSine }
    readonly property real moonLit: (1 - Math.cos(2 * Math.PI * phaseDrawn)) / 2
    readonly property bool yellowMoon: moonTone === "yellow"
    readonly property string moonName: {
        const p = moonPhase;
        if (p < 0.03 || p >= 0.97) return "New moon";
        if (p < 0.22) return "Waxing crescent";
        if (p < 0.28) return "First quarter";
        if (p < 0.47) return "Waxing gibbous";
        if (p < 0.53) return "Full moon";
        if (p < 0.72) return "Waning gibbous";
        if (p < 0.78) return "Last quarter";
        return "Waning crescent";
    }

    // ---------- weather amounts ----------
    readonly property real windX: windShown * 12     // px/s sideways for rain, a little for snow

    // lightning: one strike per cycle, the cycle's start nudged by its own seed
    readonly property int strikeIndex: Math.floor(time / 4.8)
    readonly property real strikeT: time - strikeIndex * 4.8 - rnd(strikeIndex + 7) * 2.2
    readonly property real flash: {
        // only once the storm has fully gathered
        if (stormAmt < 0.85 || strikeT < 0 || strikeT > 0.42) return 0;
        const t = strikeT;
        if (t < 0.07) return 0.55;
        if (t < 0.13) return 0.08;
        if (t < 0.2) return 0.42;
        return 0.42 * (1 - (t - 0.2) / 0.22);
    }

    // ---------- the world ----------
    Item {
        id: world
        anchors.fill: parent

        // sky
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: scene.rgb(scene.skyTop) }
                GradientStop { position: 0.55; color: scene.rgb(scene.skyMid) }
                GradientStop { position: 0.8; color: scene.rgb(scene.skyLow) }
            }
        }

        // stars, twinkling, hidden by cloud
        Repeater {
            model: 46
            Rectangle {
                required property int index
                readonly property real tw: 0.55 + 0.45 * Math.sin(scene.time * (0.8 + scene.rnd(index + 3) * 1.6) + index)
                x: scene.rnd(index) * scene.width
                y: scene.rnd(index + 100) * scene.height * 0.62
                width: scene.rnd(index + 200) > 0.85 ? 2.5 : 1.5
                height: width
                radius: width / 2
                color: "#fffbe8"
                opacity: scene.night * tw * scene.starsAmt
            }
        }

        // the arc line along the sky path (the sink at the ends is left out)
        Shape {
            id: path
            visible: scene.showPath
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property color tone: scene.pathTone === "daynight" ? (scene.sunUp ? "#ffb54d" : "#f2f5ff") : scene.themeColor
            readonly property real rx: scene.width * 0.42
            readonly property real ry: scene.horizonY - scene.zenithY
            readonly property real cx: scene.width / 2
            readonly property real angle: Math.PI * (1 - scene.arcT)
            readonly property real px: cx + rx * Math.cos(angle)
            readonly property real py: scene.horizonY - ry * Math.sin(angle)
            readonly property string radii: rx + " " + ry
            // a soft glow under the night line
            ShapePath {
                strokeColor: Qt.alpha(path.tone, scene.pathTone === "daynight" && !scene.sunUp ? 0.22 : 0)
                strokeWidth: 10
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M " + (path.cx - path.rx) + " " + scene.horizonY + " A " + path.radii + " 0 0 1 " + path.px + " " + path.py }
            }
            ShapePath {
                strokeColor: Qt.alpha(path.tone, 0.3)
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M " + path.px + " " + path.py + " A " + path.radii + " 0 0 1 " + (path.cx + path.rx) + " " + scene.horizonY }
            }
            ShapePath {
                strokeColor: path.tone
                strokeWidth: 4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathSvg { path: "M " + (path.cx - path.rx) + " " + scene.horizonY + " A " + path.radii + " 0 0 1 " + path.px + " " + path.py }
            }
        }

        // the sun
        Item {
            visible: scene.sunUp
            x: scene.bodyX
            y: scene.bodyY
            opacity: scene.bodyShow
            readonly property real low: 1 - Math.sin(Math.PI * scene.arcT)     // 1 at the horizon
            readonly property color core: Qt.rgba(1, 0.86 - 0.26 * low, 0.45 - 0.2 * low, 1)
            Repeater {
                model: [{ r: 62, a: 0.08 }, { r: 42, a: 0.14 }, { r: 28, a: 0.28 }]
                Rectangle {
                    required property var modelData
                    width: modelData.r * 2; height: width; radius: width / 2
                    x: -width / 2; y: -height / 2
                    color: parent.core
                    opacity: modelData.a * (1 + 0.08 * Math.sin(scene.time * 1.4))
                }
            }
            Rectangle { width: 30; height: 30; radius: 15; x: -15; y: -15; color: parent.core }
        }

        // the moon, lit by its phase
        Item {
            id: moon
            visible: !scene.sunUp
            x: scene.bodyX
            y: scene.bodyY
            opacity: scene.bodyShow
            readonly property real r: 14
            readonly property real k: Math.cos(2 * Math.PI * scene.phaseDrawn)     // > 0: crescent
            readonly property bool waxing: scene.phaseDrawn < 0.5
            Rectangle { width: 64; height: 64; radius: 32; x: -32; y: -32; color: scene.yellowMoon ? "#ffe6a6" : "#e9ecff"; opacity: 0.05 + 0.08 * scene.moonLit }
            Rectangle { width: moon.r * 2; height: width; radius: moon.r; x: -moon.r; y: -moon.r; color: scene.yellowMoon ? "#d9c99a" : "#c8cde0"; opacity: 0.14 }
            Shape {
                x: -moon.r; y: -moon.r
                width: moon.r * 2; height: moon.r * 2
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillColor: scene.yellowMoon ? "#ffe39a" : "#f4f0dc"
                    PathSvg {
                        path: {
                            const r = moon.r, rx = Math.max(0.01, Math.abs(moon.k) * r);
                            if (scene.moonLit < 0.01) return "";
                            // the lit limb (right while waxing), then the terminator back up
                            const limb = moon.waxing ? 1 : 0;
                            const term = moon.waxing ? (moon.k > 0 ? 0 : 1) : (moon.k > 0 ? 1 : 0);
                            return "M " + r + " 0 A " + r + " " + r + " 0 0 " + limb + " " + r + " " + (2 * r)
                                 + " A " + rx + " " + r + " 0 0 " + term + " " + r + " 0 Z";
                        }
                    }
                }
            }
        }

        // clouds drifting with the wind: cumulus heaps of round puffs on a flat base, each its own shape,
        // lit from above and shaded underneath
        component Cloud: Item {
            id: cloud
            property color tint: "white"
            property int seed: 0
            readonly property color shade: Qt.darker(tint, 1.24)
            readonly property color lit: Qt.lighter(tint, 1.05)
            // the heap is cut flat along its base
            width: 350; height: 166
            clip: true
            // the scene's ids are out of reach in an inline component, so its own copy of the scene's noise
            function rnd(i) { const x = Math.sin(i * 12.9898 + 78.233) * 43758.5453; return x - Math.floor(x); }
            layer.enabled: opacity < 0.99
            readonly property var puffs: {
                const n = 5 + Math.floor(cloud.rnd(seed * 7 + 1) * 3);
                const out = [];
                for (let i = 0; i < n; i++) {
                    const u = i / (n - 1);
                    const bump = Math.sin(Math.PI * u);
                    const r = 32 + 46 * bump + cloud.rnd(seed * 13 + i) * 18;
                    const cx = 42 + u * 266 + (cloud.rnd(seed * 17 + i) - 0.5) * 24;
                    const cy = 150 - r * 0.72 - bump * 10 + (cloud.rnd(seed * 19 + i) - 0.5) * 10;
                    out.push({ x: cx - r, y: cy - r, d: 2 * r });
                }
                out.sort((p, q) => q.d - p.d);      // the big middle puffs behind, the small ones in front
                return out;
            }
            // a rounded base behind the puffs, so the cut base has no gaps
            Rectangle {
                x: 28; y: 108; width: 294; height: 76; radius: 38
                gradient: Gradient {
                    GradientStop { position: 0.0; color: cloud.tint }
                    GradientStop { position: 0.75; color: cloud.shade }
                }
            }
            Repeater {
                model: cloud.puffs
                Rectangle {
                    required property var modelData
                    x: modelData.x; y: modelData.y
                    width: modelData.d; height: modelData.d
                    radius: modelData.d / 2
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: cloud.lit }
                        GradientStop { position: 0.55; color: cloud.tint }
                        GradientStop { position: 1.0; color: cloud.shade }
                    }
                }
            }
        }
        Repeater {
            model: 18
            Cloud {
                required property int index
                seed: index
                // how far this cloud has formed: the eased count reaches past its slot
                readonly property real formed: scene.clamp01(scene.cloudN - index)
                visible: formed > 0.01
                readonly property real w: scene.width * (scene.cloudMin + (scene.cloudMax - scene.cloudMin) * scene.rnd(index + 11)) * (0.55 + 0.45 * formed)
                readonly property real speed: 5 + scene.rnd(index + 21) * 7
                readonly property real span: scene.width + w
                scale: w / 350
                transformOrigin: Item.TopLeft
                x: (((scene.rnd(index + 31) * span + scene.time * speed + scene.cloudDrift) % span) + span) % span - w
                y: scene.height * (scene.cloudTop + (scene.cloudLow - scene.cloudTop) * scene.rnd(index + 41)) + 18 * (1 - formed)
                opacity: scene.cloudSolid * formed
                tint: {
                    const day = scene.lerp(scene.hex("#f7f9fc"), scene.hex("#5d6576"), scene.cloudTone);
                    const dark = scene.lerp(scene.hex("#384263"), scene.hex("#1b2030"), scene.cloudTone);
                    // warm edges at dawn and dusk
                    const warm = Math.max(0, 1 - Math.abs(scene.hour - 6.5) / 1.5) + Math.max(0, 1 - Math.abs(scene.hour - 18) / 1.5);
                    const c = scene.lerp(scene.lerp(dark, day, scene.light), scene.hex("#f2b2a0"), 0.35 * warm * (1 - scene.cloudTone));
                    return scene.rgb(c);
                }
            }
        }

        // through heavy cloud only a soft patch of the sun's or moon's light shows
        Repeater {
            model: [{ r: 54, a: 0.07 }, { r: 36, a: 0.09 }, { r: 22, a: 0.12 }, { r: 12, a: 0.16 }]
            Rectangle {
                required property var modelData
                readonly property real r: modelData.r * (scene.sunUp ? 1 : 0.7)
                width: r * 2; height: width; radius: r
                x: scene.bodyX - r
                y: scene.bodyY - r
                color: scene.sunUp ? "#fff3d1" : (scene.yellowMoon ? "#fff0c4" : "#e6eaff")
                visible: scene.glowAmt > 0.01
                opacity: modelData.a * (scene.sunUp ? 1.4 : 0.8 * (0.3 + scene.moonLit)) * scene.glowAmt
            }
        }

        // the meadow: two hills and swaying grass
        readonly property real frost: 0.25 * scene.frostAmt
        readonly property var hillBack: scene.lerp(scene.lerp(scene.lerp(scene.hex("#1c2f2c"), scene.hex("#6fa65a"), scene.light), scene.hex("#7d8a80"), scene.veilA * 0.5), scene.hex("#dfe6ee"), frost)
        readonly property var hillFront: scene.lerp(scene.lerp(scene.lerp(scene.hex("#122321"), scene.hex("#4b8a43"), scene.light), scene.hex("#5d6a60"), scene.veilA * 0.5), scene.hex("#dfe6ee"), frost)
        Shape {
            width: 565; height: 262
            transform: Scale { xScale: scene.width / 565; yScale: scene.height / 262 }
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1; strokeColor: "transparent"
                fillColor: scene.rgb(world.hillBack)
                PathSvg { path: "M 0 186 C 90 158 180 168 262 182 C 344 196 430 160 565 174 L 565 262 L 0 262 Z" }
            }
            ShapePath {
                strokeWidth: -1; strokeColor: "transparent"
                fillColor: scene.rgb(world.hillFront)
                PathSvg { path: "M 0 214 C 110 198 200 222 300 213 C 400 204 480 222 565 208 L 565 262 L 0 262 Z" }
            }
        }
        // snow lying on the hills
        Repeater {
            model: 30
            Rectangle {
                required property int index
                visible: scene.frostAmt * 30 > index
                width: (8 + scene.rnd(index + 51) * 16) * scene.width / 565
                height: 3.5 + scene.rnd(index + 57) * 3
                radius: height / 2
                x: scene.rnd(index + 61) * scene.width - width / 2
                y: scene.height * (index % 3 === 0 ? 0.72 + scene.rnd(index + 71) * 0.06 : 0.84 + scene.rnd(index + 71) * 0.13)
                color: scene.light > 0.4 ? "#f4f7fb" : "#aab3c6"
                opacity: 0.7
            }
        }
        Repeater {
            model: 56
            Rectangle {
                required property int index
                readonly property real sway: Math.sin(scene.swayPhase + index * 0.7) * (3 + scene.windShown * 0.6) + scene.windShown * 0.8
                width: 2
                height: (7 + scene.rnd(index + 81) * 9) * scene.height / 262
                radius: 1
                x: scene.rnd(index + 91) * scene.width
                y: scene.height * (0.86 + scene.rnd(index + 95) * 0.12) - height
                transformOrigin: Item.Bottom
                rotation: sway
                color: scene.frostAmt > 0.5 && index % 3 === 0 ? "#e6ecf3" : scene.rgb(scene.lerp(world.hillFront, scene.hex("#a6d87c"), 0.35 * scene.light))
            }
        }

        // mist: soft bands low over the meadow
        Repeater {
            model: 5
            Rectangle {
                required property int index
                visible: scene.mistAmt > 0.01
                width: scene.width * 1.6
                height: scene.height * (0.16 + scene.rnd(index + 5) * 0.1)
                x: -scene.width * 0.3 + Math.sin(scene.time * 0.08 + index * 1.9) * scene.width * 0.2
                y: scene.height * (0.45 + index * 0.1)
                opacity: 0.55 * scene.mistAmt
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: scene.light > 0.4 ? Qt.rgba(0.94, 0.95, 0.97, 0.75) : Qt.rgba(0.6, 0.64, 0.72, 0.5) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        // a light breeze by day: thin streaks crossing the sky
        Repeater {
            model: Math.min(8, 3 + Math.floor(scene.wind / 5))
            Rectangle {
                required property int index
                visible: scene.light > 0.3 && scene.breezeAmt > 0.01
                readonly property real u: (scene.breezePhase + scene.rnd(index + 3) * 3) % 1
                width: 50 + scene.rnd(index + 13) * 40
                height: 1.5
                x: -width + u * (scene.width + width * 2)
                y: scene.height * (0.12 + scene.rnd(index + 23) * 0.55) + Math.sin(u * 6 + index) * 5
                opacity: Math.sin(Math.PI * u) * 0.5 * scene.light * scene.breezeAmt
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.6; color: "#ffffff" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        // fireflies at night
        Repeater {
            model: 14
            Item {
                required property int index
                visible: scene.night > 0.5 && scene.fliesAmt > 0.01
                readonly property real blink: Math.pow(0.5 + 0.5 * Math.sin(scene.time * (1.6 + scene.rnd(index + 7)) + index * 2.1), 2)
                x: scene.rnd(index + 17) * scene.width + Math.sin(scene.time * 0.5 + index) * 16
                y: scene.height * (0.55 + scene.rnd(index + 27) * 0.38) + Math.cos(scene.time * 0.7 + index * 1.7) * 9
                opacity: (scene.night - 0.5) * 2 * blink * scene.fliesAmt
                Rectangle { width: 12; height: 12; radius: 6; x: -6; y: -6; color: "#e9ff8a"; opacity: 0.22 }
                Rectangle { width: 3.5; height: 3.5; radius: 1.75; x: -1.75; y: -1.75; color: "#f4ffb8" }
            }
        }

        // rain, tilting right with the wind
        Repeater {
            model: 150
            Rectangle {
                required property int index
                visible: scene.rainAmt * 150 > index
                readonly property real vy: 420 + scene.rnd(index + 1) * 180
                readonly property real spanX: scene.width + 240
                width: 1.4
                height: 13
                radius: 0.7
                color: "#d6e4ff"
                opacity: 0.45 + scene.rnd(index + 2) * 0.25
                rotation: -Math.atan2(scene.windX, vy) * 180 / Math.PI
                x: (((scene.rnd(index + 3) * spanX + scene.drift) % spanX) + spanX) % spanX - 120
                y: ((scene.rnd(index + 4) * (scene.height + 30) + scene.time * vy) % (scene.height + 30)) - 30
            }
        }

        // snow, drifting as it falls
        Repeater {
            model: 80
            Rectangle {
                required property int index
                visible: scene.snowAmt * 80 > index
                readonly property real vy: 26 + scene.rnd(index + 1) * 30
                readonly property real spanX: scene.width + 80
                width: 2 + scene.rnd(index + 5) * 2.5
                height: width
                radius: width / 2
                color: "#ffffff"
                opacity: 0.9
                x: ((scene.rnd(index + 3) * spanX + scene.drift * 0.4 + Math.sin(scene.time * 1.2 + index) * 10) % spanX + spanX) % spanX - 40
                y: ((scene.rnd(index + 4) * (scene.height + 10) + scene.time * vy) % (scene.height + 10)) - 10
            }
        }

        // a storm's lightning: the bolt, then the flash over everything
        Shape {
            id: bolt
            visible: scene.flash > 0.05
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property var points: {
                const k = scene.strikeIndex;
                const pts = [];
                let x = scene.width * (0.2 + 0.6 * scene.rnd(k * 3 + 1));
                for (let i = 0; i <= 7; i++) {
                    pts.push(Qt.point(x, scene.height * 0.72 * i / 7));
                    x += (scene.rnd(k * 17 + i) - 0.5) * 36;
                }
                return pts;
            }
            ShapePath {
                strokeColor: Qt.rgba(0.85, 0.9, 1, 0.35)
                strokeWidth: 7
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: bolt.points }
            }
            ShapePath {
                strokeColor: "#ffffff"
                strokeWidth: 2.2
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathPolyline { path: bolt.points }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: "#eef2ff"
            opacity: scene.flash
        }
    }

    // the box's rounded corners
    Rectangle {
        id: corners
        anchors.fill: parent
        radius: scene.cornerRadius
        visible: false
        layer.enabled: true
    }

    // Pixel draws the finished scene at a quarter size and scales it up without smoothing
    Item {
        anchors.fill: parent
        opacity: scene.intensity
        layer.enabled: scene.look === "pixel"
        layer.smooth: false
        layer.textureSize: Qt.size(Math.round(width / 4), Math.round(height / 4))

        // the world drawn into a texture (hideSource keeps it rendering, so the clouds' own layers work)
        ShaderEffectSource {
            id: worldTex
            anchors.fill: parent
            sourceItem: world
            hideSource: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: worldTex
            autoPaddingEnabled: false
            maskEnabled: true
            maskSource: corners
            blurEnabled: scene.look === "soft"
            blur: 0.55
            blurMax: 18
            saturation: scene.look === "soft" ? 0.1 : 0
        }
    }
}
