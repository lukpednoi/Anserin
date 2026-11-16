import QtQuick
import "../../"
import "../../reusables"

// A board card: one section of a page, its name with an icon, and its options as cells two to a line (wide ones
// and a half cell left alone take the whole line). Anything that is not a BoardCell (a preview, a picker) takes
// the whole line in its place. Only one cell is open at a time. The card places the cells itself (relayout):
// every cell gets its final spot at once and goes there without crossing another (BoardCell.qml).
Rectangle {
    id: card
    property string title: ""
    property string icon: ""
    property color accent: ThemeBackend.mauve
    property bool flood: true
    property bool expand: true
    default property alias cells: grid.data
    property Item openCell: null
    property Item pivotCell: null
    width: parent ? parent.width : 300
    implicitHeight: (title !== "" ? 54 : 12) + grid.height + 12
    radius: Math.min(ThemeBackend.borderRadius, 20)
    color: (tileGlass1.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
    GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }

    function toggle(cell) { pivotCell = cell; openCell = openCell === cell ? null : cell; relayout(); }

    Row {
        visible: card.title !== ""
        x: 12; y: 12; height: 30; spacing: 10
        Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 9; color: Qt.alpha(card.accent, 0.18)
            Text { anchors.centerIn: parent; text: card.icon; font.family: ThemeBackend.iconFont; font.pixelSize: 13; color: card.accent } }
        Text { anchors.verticalCenter: parent.verticalCenter; text: card.title; font.family: ThemeBackend.fontFamily; font.pixelSize: 14; font.bold: true; color: ThemeBackend.text }
    }

    Item {
        id: grid
        x: 12; y: card.title !== "" ? 54 : 12
        width: card.width - 24
        property int shown: 0
        property bool settled: false
        Behavior on height { enabled: grid.settled; SequentialAnimation { PauseAnimation { duration: 90 } NumberAnimation { duration: 300; easing.type: Easing.OutCubic } } }
        onChildrenChanged: card.relayout()
        onWidthChanged: card.relayout()
        Component.onCompleted: card.relayout()
    }

    // place every visible child: cells two to a line, everything else on its own line
    property bool layoutPending: false
    function relayout() { if (!layoutPending) { layoutPending = true; Qt.callLater(doLayout); } }
    function doLayout() {
        layoutPending = false;
        // children hidden with `hidden: true` (not `visible`, which also follows the card's own visibility) are left out
        const list = [];
        for (let i = 0; i < grid.children.length; i++) {
            const k = grid.children[i];
            if (k.hidden !== true && k.delegate === undefined) list.push(k);   // a Repeater places its items, not itself
        }
        const half = (grid.width - 8) / 2;
        // a cell is wide when it wants the line, or is left alone at the end of a run of half cells
        const full = []; let run = [];
        const close = () => { if (run.length % 2 === 1) full[run[run.length - 1]] = true; run = []; };
        for (let k = 0; k < list.length; k++) {
            const it = list[k];
            if (!it.isBoardCell || it.wantsLine) { close(); full[k] = true; } else { full[k] = false; run.push(k); }
        }
        close();
        let y = 0, col = 0, rowH = 0;
        for (let k = 0; k < list.length; k++) {
            const it = list[k];
            if (it.isBoardCell) {
                it.card = card; it.accent = card.accent; it.flood = card.flood; it.expand = card.expand;
                it.expanded = card.openCell === it; it.pivot = card.pivotCell === it; it.fullWidth = grid.width;
            }
            const h = it.isBoardCell ? it.targetHeight : it.implicitHeight;
            let place;
            if (full[k]) {
                if (col === 1) { y += rowH + 8; col = 0; rowH = 0; }
                place = { x: 0, y: y, w: grid.width, h: h }; y += h + 8;
            } else {
                place = { x: col === 0 ? 0 : half + 8, y: y, w: half, h: h };
                rowH = Math.max(rowH, h);
                if (col === 1) { y += rowH + 8; col = 0; rowH = 0; } else col = 1;
            }
            if (it.isBoardCell) it.place = place;
            else { it.x = place.x; it.y = place.y; it.width = place.w; }
        }
        if (col === 1) y += rowH + 8;
        // the first layout is taken at once, later ones animate
        grid.height = Math.max(0, y - 8);
        if (!grid.settled && grid.width > 0) grid.settled = true;
        grid.shown = list.length;
    }
    // a child that appears, disappears or changes height asks for a new layout
    Instantiator {
        model: grid.children.length
        delegate: Connections {
            required property int index
            target: grid.children[index] ?? null
            ignoreUnknownSignals: true
            function onHiddenChanged() { card.relayout(); }
            function onImplicitHeightChanged() { card.relayout(); }
        }
    }
}
