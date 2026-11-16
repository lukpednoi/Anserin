import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

// The Ambient Music style's cover, song position and visualizer, at the page's design size (625 x 565): the cover
// fills a huge disc whose edge runs from the left side up into the top-right corner, the picture moved towards the
// middle of the part that shows. Inside the picture, along its edge, the song's position runs from left to right
// (white where played, grey still to come, short of both sides) and can be dragged; its knob shows only while the
// pointer is on the line. Outside the edge the visualizer's bars stand in a ring, following Cava's levels (bass at
// the left) weighted by the equalizer's curve, short and still when there is no sound.
Item {
    id: dial

    property url cover: ""
    property real position: 0              // seconds
    property real duration: 0
    property var levels: []                // Cava's bars, 0..1, bass first
    property var eqGains: []               // dB, bass to treble: the bars lean with the curve
    // device pixels per page unit (the host's stretch times the screen's scale): the cover and its mask are drawn
    // at that resolution, not at the page's design size, so the picture stays sharp once stretched
    property real renderScale: 1
    function gainAt(u) {                    // u: 0 at the right (treble) .. 1 at the left (bass); -1 .. 1
        const g = eqGains, n = g ? g.length : 0;
        if (n < 2) return 0;
        const x = (1 - u) * (n - 1), i = Math.min(n - 2, Math.floor(x));
        return ((g[i] || 0) + ((g[i + 1] || 0) - (g[i] || 0)) * (x - i)) / 12;
    }
    signal seeked(real position)

    // the disc, in page units: through (0, 290) and the top-right corner
    readonly property real cx: 50
    readonly property real cy: -420.7
    readonly property real r: 712.5
    readonly property real progressGap: -16             // the song's position, inside the picture along its edge
    readonly property real ringGap: 10                  // the visualizer, outside the edge
    readonly property real sideRoom: 30                 // the position stops this far (px) short of the left side,
    readonly property real endRoom: 72                  // and of its right end

    // where the edge leaves the page: angles (degrees, from the centre) at the right and left ends
    function angleOf(x, y) { return Math.atan2(y - cy, x - cx) * 180 / Math.PI; }
    readonly property real rightAngle: {
        const yRight = cy + Math.sqrt(r * r - (width - cx) * (width - cx));
        return yRight >= 0 ? angleOf(width, yRight) : angleOf(cx + Math.sqrt(r * r - cy * cy), 0);
    }
    readonly property real leftAngle: angleOf(0, cy + Math.sqrt(r * r - cx * cx))
    readonly property real step: 1.5                    // degrees between bars
    readonly property real firstAngle: rightAngle - 3
    readonly property int tickCount: Math.ceil((leftAngle + 3 - firstAngle) / step) + 1
    readonly property real lastAngle: firstAngle + (tickCount - 1) * step

    // the position's ends: from the left, short of both ends
    readonly property real playStart: leftAngle - sideRoom / (r + progressGap) * 180 / Math.PI
    readonly property real playSpan: playStart - (rightAngle + endRoom / (r + progressGap) * 180 / Math.PI)
    readonly property real played: duration > 0 ? Math.max(0, Math.min(1, position / duration)) : 0
    readonly property real playAngle: playStart - played * playSpan

    // the visible part of the disc: its bounding box and centre
    readonly property var region: {
        let sx = 0, sy = 0, n = 0, maxY = 0;
        for (let y = 5; y < height; y += 10)
            for (let x = 5; x < width; x += 10)
                if ((x - cx) * (x - cx) + (y - cy) * (y - cy) < r * r) { sx += x; sy += y; n++; maxY = Math.max(maxY, y); }
        return n > 0 ? { x: sx / n, y: sy / n, bottom: maxY + 5 } : { x: width / 2, y: height / 4, bottom: height / 2 };
    }

    // ---------- the cover, cut to the disc ----------
    Item {
        id: coverArt
        anchors.fill: parent
        Image {
            // as little zoom as fills the shown part, its centre moved halfway towards that part's middle
            readonly property real midX: (dial.width / 2 + dial.region.x) / 2
            readonly property real midY: (dial.region.bottom / 2 + dial.region.y) / 2
            readonly property real halfW: Math.max(midX, dial.width - midX)
            readonly property real halfH: Math.max(midY, dial.region.bottom - midY)
            x: midX - halfW
            y: midY - halfH
            width: halfW * 2
            height: halfH * 2
            source: dial.cover
            sourceSize.width: 1000
            mipmap: true
            smooth: true
            retainWhileLoading: true    // the old picture stays until the new one is ready: no blank frame
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }
    Item {
        id: discMask
        anchors.fill: parent
        Rectangle {
            x: dial.cx - dial.r; y: dial.cy - dial.r
            width: dial.r * 2; height: width
            radius: dial.r
        }
    }
    ShaderEffectSource {
        id: coverTex
        anchors.fill: parent
        sourceItem: coverArt
        hideSource: true
        visible: false
        smooth: true
        textureSize: Qt.size(Math.ceil(width * dial.renderScale), Math.ceil(height * dial.renderScale))
    }
    ShaderEffectSource {
        id: maskTex
        anchors.fill: parent
        sourceItem: discMask
        hideSource: true
        visible: false
        textureSize: coverTex.textureSize
    }
    MultiEffect {
        anchors.fill: parent
        source: coverTex
        maskEnabled: true
        maskSource: maskTex
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.004
    }
    // a soft light along the disc's edge
    Rectangle {
        x: dial.cx - dial.r - 1; y: dial.cy - dial.r - 1
        width: dial.r * 2 + 2; height: width
        radius: width / 2
        color: "transparent"
        border.width: 1.5
        border.color: Qt.rgba(1, 1, 1, 0.35)
    }

    // ---------- the song's position ----------
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // a soft shadow under the line, so it reads on a bright picture
        ShapePath {
            strokeColor: Qt.rgba(0, 0, 0, 0.22)
            strokeWidth: 5
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: dial.cx; centerY: dial.cy
                radiusX: dial.r + dial.progressGap; radiusY: radiusX
                startAngle: dial.playStart
                sweepAngle: -dial.playSpan
            }
        }
        ShapePath {
            strokeColor: Qt.rgba(1, 1, 1, 0.38)
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: dial.cx; centerY: dial.cy
                radiusX: dial.r + dial.progressGap; radiusY: radiusX
                startAngle: dial.playAngle
                sweepAngle: -(dial.playAngle - (dial.playStart - dial.playSpan))
            }
        }
        ShapePath {
            strokeColor: "white"
            strokeWidth: 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: dial.cx; centerY: dial.cy
                radiusX: dial.r + dial.progressGap; radiusY: radiusX
                startAngle: dial.playStart
                sweepAngle: -Math.max(0.01, dial.played * dial.playSpan)
            }
        }
    }
    // the knob shows only while the pointer is on the line or drags it
    Rectangle {
        readonly property real rad: dial.playAngle * Math.PI / 180
        readonly property bool shown: seek.dragging || seek.onLine
        width: seek.dragging ? 13 : 10
        height: width
        opacity: shown ? 1 : 0
        scale: shown ? 1 : 0.3
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
        radius: width / 2
        color: "white"
        x: dial.cx + (dial.r + dial.progressGap) * Math.cos(rad) - width / 2
        y: dial.cy + (dial.r + dial.progressGap) * Math.sin(rad) - height / 2
        Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
    }

    // ---------- the visualizer ----------
    Repeater {
        model: dial.tickCount
        Rectangle {
            required property int index
            readonly property real angle: dial.firstAngle + index * dial.step
            readonly property real rad: angle * Math.PI / 180
            // where the bar is along the ring: 0 at the right (treble) .. 1 at the left (bass)
            readonly property real u: Math.max(0, Math.min(1, (angle - dial.firstAngle) / (dial.lastAngle - dial.firstAngle)))
            readonly property real amp: {
                const l = dial.levels, n = l ? l.length : 0;
                if (n < 2) return 0;
                const x = (1 - u) * (n - 1), i = Math.min(n - 2, Math.floor(x));
                const level = (l[i] || 0) + ((l[i + 1] || 0) - (l[i] || 0)) * (x - i);
                return Math.max(0, Math.min(1, level * (1 + 0.6 * dial.gainAt(u))));
            }
            readonly property real fade: Math.max(0, Math.min(1, Math.min(angle - dial.firstAngle, dial.lastAngle - angle) / 6))
            width: 2.2
            // the sound's levels sit low; lift them so the ring moves visibly
            readonly property real lift: Math.min(1, Math.pow(amp, 0.75) * 1.25)
            height: 7 + lift * 28
            radius: width / 2
            color: "white"
            opacity: (0.55 + 0.4 * lift) * fade
            x: dial.cx + (dial.r + dial.ringGap) * Math.cos(rad) - width / 2
            y: dial.cy + (dial.r + dial.ringGap) * Math.sin(rad)
            transformOrigin: Item.Top
            rotation: angle - 90
        }
    }

    // drag along the position to wind the song; presses away from it pass through (`dragging` is set only for a
    // press on the line, as `pressed` turns true for a moment even for a press that is passed on)
    MouseArea {
        id: seek
        anchors.fill: parent
        cursorShape: dragging || onLine ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        property bool onLine: false
        property bool dragging: false
        function lineDistance(mx, my) { return Math.abs(Math.hypot(mx - dial.cx, my - dial.cy) - (dial.r + dial.progressGap)); }
        // on the line itself: close to it and between its two ends (not on the circle beyond them)
        function onTheLine(mx, my) {
            const a = dial.angleOf(mx, my);
            return lineDistance(mx, my) < 10 && a <= dial.playStart + 0.6 && a >= dial.playStart - dial.playSpan - 0.6;
        }
        function seekTo(mx, my) {
            const p = (dial.playStart - dial.angleOf(mx, my)) / dial.playSpan;
            dial.seeked(Math.max(0, Math.min(1, p)) * dial.duration);
        }
        onPositionChanged: (e) => {
            onLine = onTheLine(e.x, e.y);
            if (dragging) seekTo(e.x, e.y);
        }
        onExited: onLine = false
        onPressed: (e) => {
            if (!onTheLine(e.x, e.y) || dial.duration <= 0) { e.accepted = false; return; }
            dragging = true;
            seekTo(e.x, e.y);
        }
        onReleased: dragging = false
        onCanceled: dragging = false
    }
}
