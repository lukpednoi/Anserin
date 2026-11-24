import QtQuick
import "../"

// Unified Music Bar SDF shell: stadium pill + seamless drooping Cava wave + continuous 1px rim border.
// Rendered in a single GPU ShaderEffect with zero seam between corners and wave; FrameAnimation stops when idle.
Item {
    id: root

    property bool active: false
    property bool previewDemo: false
    property real pillHeight: Scaler.s(34)
    property color fillColor: "#090b10"
    property color borderColor: Qt.rgba(1, 1, 1, 0.14)
    property real borderWidth: 1.0
    property int count: 24
    property bool mirrored: true
    property real curve: 1.25
    property real threshold: 0.03
    property real gamma: 1.15
    property real rise: 0.45
    property real fall: 0.22

    readonly property int levelCount: Math.max(6, Math.min(32, count))
    readonly property real maxLength: Math.max(0, height - pillHeight - 3.0)

    readonly property var sourceMap: {
        const n = root.levelCount;
        const srcLen = Cava.barCount;
        const half = (n - 1) / 2;
        const map = [];
        for (let i = 0; i < n; i++) {
            const norm = root.mirrored ? (half > 0 ? Math.abs(i - half) / half : 0) : i / (n - 1);
            const pos = Math.pow(norm, root.curve) * (srcLen - 1);
            const idx0 = Math.floor(pos);
            map.push({ idx0: idx0, idx1: Math.min(srcLen - 1, idx0 + 1), frac: pos - idx0 });
        }
        return map;
    }

    // Strictly 0 at both outer pairs (i=0,1 and i=n-2,n-1) so wave meets the left/right pill arcs C1-tangentially!
    readonly property var waveEdge: {
        const n = root.levelCount;
        const edges = [];
        for (let i = 0; i < n; i++) {
            if (i <= 1 || i >= n - 2) {
                edges.push(0.0);
            } else {
                const u = (i - 1) / (n - 3);
                const s = Math.sin(u * Math.PI);
                edges.push(s * s);
            }
        }
        return edges;
    }

    function mapLevels(source) {
        const map = root.sourceMap;
        const out = new Array(map.length).fill(0.0);
        if (!source || source.length === 0) return out;
        for (let i = 0; i < map.length; i++) {
            const v0 = source[map[i].idx0] || 0.0;
            const v1 = source[map[i].idx1] || 0.0;
            const raw = v0 + (v1 - v0) * map[i].frac;
            const val = raw < root.threshold ? 0.0 : Math.pow((raw - root.threshold) / (1 - root.threshold), root.gamma);
            out[i] = Math.max(0.0, Math.min(1.0, val));
        }
        return out;
    }

    function demoLevels(n) {
        const out = [];
        const t = Date.now() / 650;
        for (let i = 0; i < n; i++) {
            const norm = i / (n - 1);
            const wave1 = Math.sin(norm * Math.PI * 2 + t) * 0.5 + 0.5;
            const wave2 = Math.cos(norm * Math.PI * 3 - t * 0.8) * 0.35 + 0.35;
            out.push(Math.max(0.0, Math.min(1.0, wave1 * 0.65 + wave2 * 0.35)));
        }
        return out;
    }

    function shapeWave(levels) {
        const edges = root.waveEdge;
        const n = levels.length;
        const out = [];
        for (let i = 0; i < n; i++) {
            const prev = i > 0 ? levels[i - 1] : levels[i];
            const next = i < n - 1 ? levels[i + 1] : levels[i];
            out.push((prev * 0.25 + levels[i] * 0.5 + next * 0.25) * edges[i]);
        }
        return out;
    }

    property int demoTick: 0
    Timer {
        interval: 33
        running: root.previewDemo && root.active && root.visible
        repeat: true
        onTriggered: root.demoTick++
    }

    property var targets: {
        const source = root.active ? Cava.barLevels : null;
        let out;
        if (root.previewDemo && root.active && (!source || source.every(v => v === 0))) {
            const dummy = root.demoTick;
            out = demoLevels(root.levelCount);
        } else {
            out = mapLevels(source);
        }
        return shapeWave(out);
    }

    property var currentLevels: []
    property bool settling: false
    onTargetsChanged: settling = true

    function packLevels(v, o) {
        const m = [];
        for (let k = 0; k < 16; k++) m.push(v[o + k] || 0.0);
        return Qt.matrix4x4(m);
    }

    function uploadLevels(v) {
        effect.levels0 = packLevels(v, 0);
        effect.levels1 = packLevels(v, 16);
    }

    Component.onCompleted: {
        uploadLevels(new Array(32).fill(0.0));
        settling = true;
    }

    FrameAnimation {
        running: root.settling && root.visible
        onTriggered: {
            const target = root.targets;
            const cur = root.currentLevels;
            const r = 1 - Math.pow(1 - root.rise, frameTime / 0.016);
            const f = 1 - Math.pow(1 - root.fall, frameTime / 0.016);
            const next = new Array(target.length);
            let moving = false;
            for (let i = 0; i < target.length; i++) {
                const t = target[i];
                let c = cur[i] || 0.0;
                if (Math.abs(t - c) > 0.001) {
                    c += (t - c) * (t > c ? r : f);
                    moving = true;
                } else {
                    c = t;
                }
                next[i] = c;
            }
            root.currentLevels = next;
            root.uploadLevels(next);
            if (!moving) root.settling = false;
        }
    }

    ShaderEffect {
        id: effect
        anchors.fill: parent
        blending: true
        property matrix4x4 levels0
        property matrix4x4 levels1
        property color fillColor: root.fillColor
        property color borderColor: root.borderColor
        property vector2d itemSize: Qt.vector2d(width, height)
        property real pillHeight: root.pillHeight
        property real count: root.levelCount
        property real maxLength: root.maxLength
        property real borderWidth: root.borderWidth
        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/audio/musicbar_shell.frag.qsb"
    }
}
