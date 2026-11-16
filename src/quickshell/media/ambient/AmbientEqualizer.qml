import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../../"

// The Ambient Music style's equalizer, in the lyrics' place: the ten bands (31 Hz to 16 kHz, -12 to +12 dB) as a
// soft curve with a knob on each band to drag up or down (sent when let go), and the eight presets under it as a
// lyric line, the one in use large and bright (a click picks one, with the lyrics' pop). A preset or an applied
// change plays the Music window's own EQ lightning over the curve (its shader, its sweep and the knobs' glow as it
// passes, from MusicPopup's lightning values). Dimmed and still while the Dynamic EQ is on.
Item {
    id: eq

    property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string preset: "Flat"
    property var presets: ["Flat", "Bass", "Treble", "Vocal", "Pop", "Rock", "Jazz", "Classic"]
    property real plotHeight: 84
    signal bandSet(int band, int db)           // band 1..10, on letting go of its knob
    signal presetPicked(string name)

    readonly property var labels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    // MusicPopup's EQ lightning: the sweep across the bands (0..10), its fade (1 = gone) and colour
    property real lightningProgress: 0
    property real lightningFade: 1
    property color accentColor: ThemeBackend.mauve
    property bool running: false

    // ---------- the curve and its knobs ----------
    Item {
        id: plot
        width: parent.width
        height: eq.plotHeight
        readonly property real bandW: width / 10
        function px(i) { return bandW * (i + 0.5); }
        function py(db) { return height / 2 - db / 12 * (height / 2 - 8); }
        function dbAt(y) { return Math.max(-12, Math.min(12, (height / 2 - y) / (height / 2 - 8) * 12)); }
        property int revision: 0
        // the knobs' (eased) values, read when the curve redraws
        function dbOf(i) { void revision; const k = knobs.itemAt(i); return k ? k.shown : 0; }

        // 0 dB
        Rectangle { y: plot.height / 2; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.18) }

        Shape {
            id: curve
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // a smooth line through the knobs (Catmull-Rom as cubic Béziers), and the area under it
            readonly property string line: {
                const p = [];
                for (let i = 0; i < 10; i++) p.push({ x: plot.px(i), y: plot.py(plot.dbOf(i)) });
                let d = "M 0 " + p[0].y + " L " + p[0].x + " " + p[0].y;
                for (let i = 0; i < 9; i++) {
                    const p0 = p[Math.max(0, i - 1)], p1 = p[i], p2 = p[i + 1], p3 = p[Math.min(9, i + 2)];
                    d += " C " + (p1.x + (p2.x - p0.x) / 6) + " " + (p1.y + (p2.y - p0.y) / 6) + " "
                               + (p2.x - (p3.x - p1.x) / 6) + " " + (p2.y - (p3.y - p1.y) / 6) + " " + p2.x + " " + p2.y;
                }
                return d + " L " + plot.width + " " + p[9].y;
            }
            ShapePath {
                strokeWidth: -1
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0; y1: 0; x2: 0; y2: plot.height
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.22) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                }
                PathSvg { path: curve.line + " L " + plot.width + " " + plot.height + " L 0 " + plot.height + " Z" }
            }
            ShapePath {
                strokeWidth: 2.2
                strokeColor: Qt.rgba(1, 1, 1, 0.9)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: curve.line }
            }
        }

        Repeater {
            id: knobs
            model: 10
            Item {
                id: knob
                required property int index
                readonly property real gain: Number(eq.gains[index]) || 0
                property real dragDb: 0
                // follows the pointer while dragged, eases to the band's value otherwise
                property real shown: gain
                Binding on shown { when: drag.pressed; value: knob.dragDb }
                Behavior on shown { enabled: !drag.pressed; NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                onShownChanged: plot.revision++
                x: plot.px(index) - width / 2
                y: plot.py(shown) - height / 2
                width: 26; height: 26
                // the lightning reaching this band: a glow, and a ring that opens and fades
                readonly property real dist: eq.lightningProgress - knob.index
                readonly property real hitPulse: dist >= 0 && dist < 1 ? Math.sin(dist * Math.PI) : 0
                property real ringPulse: 0
                property bool fired: false
                onDistChanged: {
                    if (dist <= 0.05) fired = false;
                    else if (dist > 0.4 && !fired) { fired = true; ringAnim.restart(); }
                }
                SequentialAnimation {
                    id: ringAnim
                    NumberAnimation { target: knob; property: "ringPulse"; from: 0; to: 1; duration: 160; easing.type: Easing.OutCubic }
                    NumberAnimation { target: knob; property: "ringPulse"; to: 0; duration: 600; easing.type: Easing.InOutSine }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 10 + 31 * knob.hitPulse
                    height: width
                    radius: width / 2
                    color: eq.accentColor
                    opacity: knob.hitPulse * (1 - eq.lightningFade)
                    visible: opacity > 0.01
                    layer.enabled: visible
                    layer.effect: MultiEffect { blurEnabled: true; blurMax: 32; blur: 1.0 }
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 18 + knob.ringPulse * 26
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: eq.accentColor
                    border.width: 2 + knob.ringPulse * 3
                    opacity: knob.ringPulse * 0.8 * (1 - eq.lightningFade)
                    visible: opacity > 0.01
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: drag.pressed ? 14 : (drag.containsMouse ? 12 : 10)
                    height: width
                    radius: width / 2
                    color: "white"
                    // grows as the lightning reaches its band, as on the other styles' handles
                    scale: 1 + knob.hitPulse * 0.4 * (1 - eq.lightningFade)
                    Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                }
                MouseArea {
                    id: drag
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeVerCursor
                    onPressed: knob.dragDb = knob.gain
                    onPositionChanged: (e) => { if (pressed) knob.dragDb = Math.round(plot.dbAt(knob.y + e.y)); }
                    onReleased: if (Math.round(knob.dragDb) !== Math.round(knob.gain)) eq.bandSet(knob.index + 1, Math.round(knob.dragDb))
                }
            }
        }
        // the Music window's EQ lightning (assets/shaders/vfx/eq_lightning.frag), over the same ten bands
        ShaderEffect {
            anchors.fill: parent
            opacity: 1 - eq.lightningFade
            visible: opacity > 0.001
            property real animTime: 0
            NumberAnimation on animTime { running: eq.running && eq.visible; loops: Animation.Infinite; from: 0; to: 1000; duration: 1000000 }
            property vector2d itemSize: Qt.vector2d(width, height)
            property real time: animTime
            property real progress: eq.lightningProgress
            property real fade: eq.lightningFade
            property real scale: 1.0
            property color accentColor: eq.accentColor
            property vector4d bands0: Qt.vector4d(Number(eq.gains[0]) || 0, Number(eq.gains[1]) || 0, Number(eq.gains[2]) || 0, Number(eq.gains[3]) || 0)
            property vector4d bands1: Qt.vector4d(Number(eq.gains[4]) || 0, Number(eq.gains[5]) || 0, Number(eq.gains[6]) || 0, Number(eq.gains[7]) || 0)
            // the bands' last two, then the curve's top and bottom room (as plot.py: 8 each)
            property vector4d bands2: Qt.vector4d(Number(eq.gains[8]) || 0, Number(eq.gains[9]) || 0, 8, 8)
            fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/vfx/eq_lightning.frag.qsb"
        }

        Repeater {
            model: eq.labels
            Text {
                required property string modelData
                required property int index
                x: plot.px(index) - width / 2
                y: plot.height + 8
                text: modelData
                font.family: ThemeBackend.fontFamily
                font.pixelSize: 9
                font.weight: Font.Bold
                color: "white"
                opacity: 0.55
            }
        }
    }

    // ---------- the presets, as a lyric line ----------
    Flow {
        y: plot.height + 36
        width: parent.width
        Repeater {
            model: eq.presets
            Item {
                id: preset
                required property string modelData
                readonly property bool picked: eq.preset === modelData
                property real grow: picked ? 1 : 0.52
                Behavior on grow { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                width: (presetText.implicitWidth + 10) * grow
                height: 30 * 1.18
                Text {
                    id: presetText
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    transformOrigin: Item.BottomLeft
                    scale: preset.grow
                    text: I18n.t("music.presets." + preset.modelData.toLowerCase())
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 30
                    font.weight: Font.Black
                    color: "white"
                    opacity: preset.picked ? 1 : (presetMa.containsMouse ? 0.7 : 0.42)
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
                MouseArea {
                    id: presetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); eq.presetPicked(preset.modelData); }
                }
            }
        }
    }
}
