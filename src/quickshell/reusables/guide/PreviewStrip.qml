import QtQuick
import QtQuick.Layouts
import "../../"

// Row of preview cards. By default it is a plain grid (what the Settings window shows).
// With `carousel: true` (the Anserin interface) the same cards sit in one row that slides sideways:
// the centred card is full size, its neighbours are a little smaller, dimmed and peek in at the edges.
// Scroll the wheel (one card per notch), drag, or click a side card to bring a card to the middle;
// each of those reports it through cardChosen, so a page can use the card straight away.
Item {
    id: strip
    objectName: "preview-strip"
    default property alias content: grid.data
    property alias columns: grid.columns
    property alias columnSpacing: grid.columnSpacing
    property alias rowSpacing: grid.rowSpacing
    property bool carousel: false
    property int focusIndex: -1            // index of the card in use; centred when it changes
    readonly property int count: Math.max(1, grid.columns)
    readonly property real gap: grid.columnSpacing
    property real cardWidth: -1            // a fixed card width (the Control Center's board); -1: follow the width
    readonly property real cardW: cardWidth > 0 ? cardWidth : Math.min(Math.max(220, width * 0.62), 360)
    property color edgeColor: ThemeBackend.base   // what the side covers and soft edges fade into
    readonly property real step: cardW + gap
    property real sideScale: 0.86  // size of a card one step away from the middle
    implicitHeight: grid.implicitHeight
    clip: carousel

    property real pos: 0                    // card index sitting in the middle (fractional while sliding)
    readonly property int centred: Math.max(0, Math.min(count - 1, Math.round(pos)))
    property bool ready: false
    property bool dim: true
    signal cardChosen(int index)
    property int chosen: -1                 // card picked here that focusIndex has not caught up with yet
    onCentredChanged: { if (carousel && ready && typeof Sounds !== "undefined") Sounds.playSfx("reusables/dropdown/list.wav"); }

    function away(i) { return Math.min(1, Math.abs(i - pos)); }
    function scaleOf(i) { return 1 - (1 - sideScale) * away(i); }
    function goTo(i) {
        slide.stop();
        slide.to = Math.max(0, Math.min(count - 1, i));
        slide.restart();
    }
    function choose(i) {
        const target = Math.max(0, Math.min(count - 1, i));
        goTo(target);
        chosen = target === focusIndex ? -1 : target;
        cardChosen(target);
    }
    onFocusIndexChanged: {
        if (chosen >= 0) { if (focusIndex === chosen) chosen = -1; return; }
        if (carousel && focusIndex >= 0) goTo(focusIndex);
    }
    NumberAnimation { id: slide; target: strip; property: "pos"; duration: 380; easing.type: Easing.OutQuart }

    // every card gets its own scale (the cards are declared elsewhere, so it is attached here)
    property var scaled: []
    Component {
        id: scaleComp
        Scale {
            property Item card
            readonly property int slot: card ? Math.round(card.x / strip.step) : 0
            origin.x: card ? card.width / 2 : 0
            origin.y: card ? card.height / 2 : 0
            xScale: strip.carousel ? strip.scaleOf(slot) : 1
            yScale: xScale
        }
    }
    function attachScales() {
        for (let i = 0; i < grid.children.length; i++) {
            const c = grid.children[i];
            if (typeof c.itemAt === "function") continue;   // the Repeater itself
            if (scaled.indexOf(c) < 0) {
                c.transform = [scaleComp.createObject(c, { card: c })];
                scaled.push(c);
            }
        }
    }
    Connections { target: grid; function onChildrenChanged() { Qt.callLater(strip.attachScales); } }

    Item {
        id: track
        x: strip.carousel ? (strip.width - strip.cardW) / 2 - strip.pos * strip.step : 0
        y: 0
        width: strip.carousel ? strip.count * strip.cardW + (strip.count - 1) * strip.gap : strip.width
        height: grid.implicitHeight

        GridLayout {
            id: grid
            width: track.width
            columns: 2
            columnSpacing: 12
        }

        // side cards are dimmed with a cover (a plain colour is far cheaper than fading the live previews);
        // the cover also catches the click so a side card only moves to the middle
        Repeater {
            model: strip.carousel && strip.dim ? strip.count : 0
            Rectangle {
                x: index * strip.step; y: 0; z: 5
                width: strip.cardW; height: grid.height
                radius: ThemeBackend.clampedBorderRadius
                color: strip.edgeColor
                opacity: 0.55 * strip.away(index)
                scale: strip.scaleOf(index)
                MouseArea {
                    anchors.fill: parent
                    enabled: index !== strip.centred
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.choose(index)
                }
            }
        }
    }

    // drag sideways; letting go settles on the nearest card (a flick carries one card further)
    DragHandler {
        id: drag
        enabled: strip.carousel
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        property real startPos: 0
        onActiveChanged: {
            if (active) { slide.stop(); startPos = strip.pos; }
            else {
                const carry = Math.max(-0.45, Math.min(0.45, -centroid.velocity.x / 3000));
                strip.choose(Math.round(strip.pos + carry));
            }
        }
        onTranslationChanged: {
            if (active) strip.pos = Math.max(0, Math.min(strip.count - 1, startPos - translation.x / strip.step));
        }
    }

    // soft edges while it is a carousel
    Rectangle {
        visible: strip.carousel
        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 30
        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: strip.edgeColor } GradientStop { position: 1; color: Qt.rgba(strip.edgeColor.r, strip.edgeColor.g, strip.edgeColor.b, 0) } }
    }
    Rectangle {
        visible: strip.carousel
        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 30
        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Qt.rgba(strip.edgeColor.r, strip.edgeColor.g, strip.edgeColor.b, 0) } GradientStop { position: 1; color: strip.edgeColor } }
    }

    // Touchpad: the row follows a sideways swipe and settles when the fingers stop; up/down swipes stay
    // with the page behind. Mouse wheel: each click of the wheel moves one card at once.
    // Here both report a touchpad device with pixel deltas, so only angleDelta tells them apart:
    // a wheel click is one event of a whole multiple of 120, a swipe is a stream of small values.
    // Anything else that large is not a real movement (one arrives when a swipe ends) and is ignored.
    // Past the first or last card the wheel scrolls the page behind instead.
    readonly property real swipeGain: 1.5
    property int swipeDir: 0
    Timer { id: swipeIdle; interval: 120; onTriggered: strip.choose(Math.round(strip.pos + 0.4 * strip.swipeDir)) }
    function swipe(delta) {
        slide.stop();
        swipeDir = delta < 0 ? 1 : -1;
        pos = Math.max(0, Math.min(count - 1, pos - delta * swipeGain / step));
        swipeIdle.restart();
    }
    function pageScroll(d) {
        for (let p = parent; p; p = p.parent) {
            if (p.contentY === undefined || !p.contentItem) continue;
            p.contentY = Math.max(0, Math.min(p.contentHeight - p.height, p.contentY - d));
            return;
        }
    }
    function isClick(angle) { return !swipeIdle.running && Math.abs(angle) % 120 === 0; }
    function notch(d) {
        const from = slide.running ? slide.to : centred;
        const target = Math.max(0, Math.min(count - 1, from - Math.round(d / 120)));
        if (target === from) pageScroll(d); else choose(target);
    }
    // A handler only starts on events along its own axis, so sideways swipes need their own.
    WheelHandler {
        enabled: strip.carousel
        orientation: Qt.Horizontal
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            const x = e.angleDelta.x;
            if (x === 0 || Math.abs(x) < Math.abs(e.angleDelta.y)) return;
            if (strip.isClick(x)) strip.notch(x);
            else if (Math.abs(x) < 120) strip.swipe(x / 8);
        }
    }
    WheelHandler {
        enabled: strip.carousel
        orientation: Qt.Vertical
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            const y = e.angleDelta.y;
            if (y === 0 || Math.abs(y) <= Math.abs(e.angleDelta.x)) return;
            if (strip.isClick(y)) strip.notch(y);
            else if (Math.abs(y) < 120) strip.pageScroll(y / 8);
        }
    }

    Component.onCompleted: {
        if (carousel) pos = Math.max(0, Math.min(count - 1, focusIndex >= 0 ? focusIndex : 0));
        Qt.callLater(attachScales);
        ready = true;
    }
}
