import QtQuick
import QtQuick.Effects
import "../../"

// The Ambient Music style's lyrics: the line being sung is large, each word growing bright and bold as it is sung
// while the words still to come stay small and faint (a line without word timing lights up whole). A line is
// broken into rows for its words at full size from the start, so a word growing never moves a word to the next row
// nor the lines below. The next line pops up below, faint and soft, once the line's last word is sung, showing only
// its first row until it is sung; a finished line rises away. With no lyrics, `message` stands in the line's place.
// The Music widget's Ambient lyrics style uses it too, with its own size, colour and alignment (left, center, right).
Item {
    id: lyrics

    property var lines: []                 // [{ t, words: [{ w, t }] }]
    property real time: 0
    property string message: ""
    readonly property real smallScale: 0.62
    property real bigSize: 34
    property color color: "white"
    property string alignment: "left"
    readonly property real rowHeight: bigSize * 1.18
    readonly property real wordGap: bigSize * 0.265

    readonly property int current: {
        let c = -1;
        for (let i = 0; i < lines.length; i++) { if (lines[i].t <= time) c = i; else break; }
        return c;
    }
    property real curHeight: rowHeight
    // the next line waits below once the line being sung reaches its last word
    readonly property bool nextReady: {
        if (current < 0) return true;
        const words = lines[current] ? lines[current].words : [];
        return words.length === 0 || time >= words[words.length - 1].t;
    }

    FontMetrics { id: metrics; font.family: ThemeBackend.fontFamily; font.pixelSize: lyrics.bigSize; font.weight: Font.Black }
    // the line's words in rows, as they fit at full size
    function rowsOf(words) {
        const rows = [];
        let row = [], used = 0;
        for (let i = 0; i < words.length; i++) {
            const w = metrics.advanceWidth(words[i].w) + wordGap;
            if (row.length > 0 && used + w > width) { rows.push(row); row = []; used = 0; }
            row.push(words[i]);
            used += w;
        }
        if (row.length > 0) rows.push(row);
        return rows;
    }

    // no lyrics: a faint line in the lyrics' place
    Text {
        visible: lyrics.lines.length === 0 && lyrics.message !== ""
        width: parent.width
        text: lyrics.message
        horizontalAlignment: lyrics.alignment === "center" ? Text.AlignHCenter : lyrics.alignment === "right" ? Text.AlignRight : Text.AlignLeft
        font: metrics.font
        color: lyrics.color
        opacity: 0.42
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: lyrics.lines
        Item {
            id: line
            required property var modelData
            required property int index
            readonly property int rel: index - lyrics.current
            readonly property bool isCurrent: rel === 0
            readonly property var rows: lyrics.rowsOf(modelData.words)
            visible: rel >= -1 && rel <= 1
            width: lyrics.width
            height: rows.length * lyrics.rowHeight
            onHeightChanged: if (isCurrent) lyrics.curHeight = height
            onIsCurrentChanged: if (isCurrent) lyrics.curHeight = height

            // rises away when done, waits below while to come
            readonly property bool waiting: rel === 1 && !lyrics.nextReady
            y: rel < 0 ? -height - 6 : (rel === 0 ? 0 : lyrics.curHeight + 10 + (waiting ? 14 : 0))
            // lines further down stay unseen, so they never fade out in view on their way to waiting
            opacity: rel === 0 ? 1 : (rel === 1 && !waiting ? 0.42 : 0)
            scale: waiting ? 0.94 : 1
            transformOrigin: Item.TopLeft
            Behavior on y { NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
            Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutBack } }

            layer.enabled: rel !== 0 && visible
            layer.effect: MultiEffect { blurEnabled: true; blur: 0.25; blurMax: 12 }

            Column {
                width: parent.width
                Repeater {
                    model: line.rows
                    Row {
                        id: wordRow
                        required property var modelData
                        required property int index
                        // centred or to the right by the row's width as drawn, following its words as they grow
                        x: lyrics.alignment === "center" ? (lyrics.width - implicitWidth + lyrics.wordGap) / 2
                         : lyrics.alignment === "right" ? lyrics.width - implicitWidth + lyrics.wordGap : 0
                        height: lyrics.rowHeight
                        // a waiting line shows only its first row; the rest comes when it is sung
                        opacity: line.rel === 1 && index > 0 ? 0 : 1
                        Behavior on opacity { NumberAnimation { duration: 300 } }
                        Repeater {
                            model: wordRow.modelData
                            Item {
                                id: word
                                required property var modelData
                                readonly property bool sung: line.rel < 0 || (line.isCurrent && lyrics.time >= modelData.t)
                                property real grow: sung ? 1 : lyrics.smallScale
                                Behavior on grow { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                                width: (wordText.implicitWidth + lyrics.wordGap) * grow
                                height: lyrics.rowHeight
                                Text {
                                    id: wordText
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    transformOrigin: Item.BottomLeft
                                    scale: word.grow
                                    text: word.modelData.w
                                    font: metrics.font
                                    color: lyrics.color
                                    opacity: word.sung ? 1 : 0.42
                                    Behavior on opacity { NumberAnimation { duration: 220 } }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
