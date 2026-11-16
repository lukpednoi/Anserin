import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

// The Dashboard's hourly strip: the first five days' hours in one row of pills on a gentle curve, today's
// hour raised; choosing another day slides the row to that day's hours. Used by the calendar Dashboard and
// (with oneDay: only the shown day's hours, flowing card by card on a day change) the left panel's Dashboard
// weather page.
Item {
    id: strip

    property var days: []                  // the forecast list (the first five days are used)
    property int day: 0                    // the day shown (0 = today)
    property int count: 8                  // pills in view
    property var now: DateTime.now
    property color accent: ThemeBackend.mauve
    property string fallbackIcon: ""       // for an hour without its own icon
    property bool oneDay: false            // only the shown day's hours instead of the five days in a row
    // the panel page's small cards: their size and a gentle sway (a phase in radians, as the Classic orbit's)
    property real cardScale: 1
    property bool swaying: false
    property real swayPhase: 0
    // a day change as on the Classic orbit, card by card: `flow` 0 -> 1 carries the shown cards one after another
    // along the curve and off its end (shrinking and fading), then the host swaps the day and runs -1 -> 0 to bring
    // the new day's cards in from the other end, each springing back to size. `flowDir` 1 moves them left (a later
    // day), -1 right.
    property real flow: 0
    property int flowDir: 1

    readonly property real pad: Scaler.s(4) * cardScale
    readonly property real gap: Scaler.s(6) * cardScale
    readonly property real pillStep: Scaler.s(46) * cardScale + gap

    implicitWidth: count * pillStep - gap + 2 * pad
    implicitHeight: Scaler.s(98) * cardScale
    // the five-day row scrolls, so it is cut at its ends; one day's cards fit and are left whole
    clip: !oneDay

    function parseClock(str) {
        if (!str) return null;
        let clockPart = String(str).trim().split(" ");
        clockPart = clockPart.length > 1 && clockPart[0].indexOf("-") !== -1 ? clockPart[1] : clockPart[0];
        let p = clockPart.split(":");
        let h = parseInt(p[0]);
        let m = parseInt(p[1] || "0");
        if (isNaN(h) || isNaN(m)) return null;
        return { h: h, m: m };
    }

    readonly property var stripDays: (strip.days || []).slice(0, 5)
    readonly property var slots: {
        if (strip.oneDay) return ((strip.stripDays[strip.day] || {}).hourly || []).slice(0, 8);
        let out = [];
        for (let i = 0; i < strip.stripDays.length; i++) {
            out = out.concat((strip.stripDays[i].hourly || []).slice(0, 8));
        }
        return out;
    }
    readonly property var dayStarts: {
        let starts = [];
        let n = 0;
        for (let i = 0; i < strip.stripDays.length; i++) {
            starts.push(n);
            n += Math.min(8, (strip.stripDays[i].hourly || []).length);
        }
        return starts;
    }
    readonly property int liveHourIndex: {
        if (strip.oneDay && strip.day !== 0) return -1;
        let day0 = strip.stripDays.length > 0 ? (strip.stripDays[0].hourly || []).slice(0, 8) : [];
        if (day0.length === 0) return -1;
        let ch = strip.now.getHours();
        let bestIdx = 0;
        let minDiff = 999;
        for (let i = 0; i < day0.length; i++) {
            let c = strip.parseClock(day0[i].time);
            let diff = Math.abs((c ? c.h : 0) - ch);
            if (diff < minDiff) {
                minDiff = diff;
                bestIdx = i;
            }
        }
        return bestIdx;
    }
    readonly property int start: {
        let t = strip.day;
        let base = strip.oneDay ? 0 : (strip.dayStarts[t] !== undefined ? strip.dayStarts[t] : 0);
        let s = t === 0 ? Math.max(0, strip.liveHourIndex - 1) : base;
        return Math.max(0, Math.min(s, strip.slots.length - strip.count));
    }

    property real pos: start
    Behavior on pos {
        NumberAnimation { duration: 650; easing.type: Easing.OutCubic }
    }
    readonly property real focusStrength: strip.oneDay ? (strip.day === 0 ? 1 : 0) : Math.max(0, Math.min(1, 1 - strip.pos / Math.max(1, strip.dayStarts[1] || 8)))
    readonly property real spin: Math.max(-28, Math.min(28, (strip.start - strip.pos) * 9))

    Row {
        id: hourRow
        y: Math.round((parent.height - height) / 2)
        x: strip.pad - strip.pos * strip.pillStep
        spacing: strip.gap

        Repeater {
            model: strip.slots

            delegate: Item {
                id: hourPill
                readonly property bool isHighlighted: index === strip.liveHourIndex

                property real hoverScale: hrMa.containsMouse && !isHighlighted ? 1.04 : 1.0
                Behavior on hoverScale { NumberAnimation { duration: 150 } }

                anchors.verticalCenter: parent.verticalCenter
                width: Scaler.s(46) * strip.cardScale
                height: Scaler.s(78) * strip.cardScale
                z: isHighlighted ? 1 : 0
                // this card's share of the flow: the card at the leading end goes first, the others follow
                readonly property real rank: strip.slots.length > 1 ? (strip.flowDir > 0 ? index : strip.slots.length - 1 - index) / (strip.slots.length - 1) : 0
                readonly property real flowP: Math.max(0, Math.min(1, Math.abs(strip.flow) * 1.7 - 0.7 * rank))
                readonly property bool leaving: strip.flow > 0
                // how far it is carried along the row: out it speeds up, in it slows down as it lands
                readonly property real flowX: (leaving ? -strip.flowDir : strip.flowDir) * strip.pillStep * 3 * flowP * flowP
                // shrinks as it leaves; grows in, overshooting a little as it lands
                readonly property real flowScale: leaving ? 1 - 0.5 * flowP
                                                          : 1 - 0.55 * flowP + (flowP < 0.3 ? 0.12 * Math.sin(Math.PI * flowP / 0.3) : 0)
                readonly property real arc: Math.max(-1.3, Math.min(1.3,
                    (x + flowX + width / 2 - (strip.pos * strip.pillStep + (strip.width / 2 - strip.pad))) / (strip.width / 2)))
                readonly property real emphasis: Math.max(0, 1 - Math.abs(index - strip.liveHourIndex) / 5)
                readonly property real sway: strip.swaying ? Math.sin(strip.swayPhase + index) : 0
                scale: (isHighlighted ? 1.08 + 0.12 * strip.focusStrength : 1.0 - (1.0 - (0.72 + 0.26 * emphasis)) * strip.focusStrength) * hoverScale * flowScale
                opacity: (isHighlighted ? 1.0 : 0.85 - (0.85 - (0.35 + 0.5 * emphasis)) * strip.focusStrength) * (1 - flowP)
                rotation: -arc * 9 + strip.spin + sway * 2.5
                transform: Translate {
                    x: hourPill.flowX
                    y: (0.5 - hourPill.arc * hourPill.arc) * Scaler.s(14) * strip.cardScale + hourPill.sway * Scaler.s(2)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(Scaler.s(16), ThemeBackend.borderRadius * 1.25) * strip.cardScale
                    color: hourGlass.active ? "transparent" : (hourPill.isHighlighted ? strip.accent : (hrMa.containsMouse ? Qt.lighter(ThemeBackend.surface0, 1.12) : ThemeBackend.surface0))
                    Behavior on color { ColorAnimation { duration: 150 } }

                    GlassFill {
                        id: hourGlass
                        anchors.fill: parent
                        radius: parent.radius
                        forceClear: true
                        tintColor: hourPill.isHighlighted ? strip.accent : ThemeBackend.surface0
                        tintAmount: hourPill.isHighlighted ? 0.4 : 0.2
                        tintStrength: 1.0
                        press: hrMa.pressed ? 0.8 : (hrMa.containsMouse ? 0.25 : 0)
                        Behavior on press { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Scaler.s(3) * strip.cardScale

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData ? modelData.time : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: Scaler.s(10.5) * strip.cardScale
                            color: (hourPill.isHighlighted && !hourGlass.active) ? ThemeBackend.base : (hrMa.containsMouse || hourPill.isHighlighted ? ThemeBackend.text : ThemeBackend.overlay1)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData ? (modelData.icon || strip.fallbackIcon) : ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: Scaler.s(16) * strip.cardScale
                            color: (hourPill.isHighlighted && !hourGlass.active) ? ThemeBackend.base : (modelData ? (modelData.hex || ThemeBackend.text) : ThemeBackend.text)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData ? (modelData.temp + "°") : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: Scaler.s(12) * strip.cardScale
                            color: (hourPill.isHighlighted && !hourGlass.active) ? ThemeBackend.base : ThemeBackend.text
                        }
                    }
                }

                MouseArea { id: hrMa; anchors.fill: parent; hoverEnabled: true }
            }
        }
    }
}
