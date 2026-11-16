import QtQuick
import "../../"
import "../"

// An AttachedSurface that follows an existing card (a sibling with the same parent) so a popup can join the
// bar through SurfaceField without its own layout changing. `edge` is the card side that sits on the bar:
// its corners stay square, the rest get `cardRadius`.
AttachedSurface {
    id: cs
    property Item card: null
    property real cardRadius: 0
    property string edge: ""
    attachTo: ["bar"]
    // a hidden popup window must not keep flattening the bar's corners
    publishShape: hostWindow ? hostWindow.visible : true
    rects: card && card.width > 0.5 && card.height > 0.5 ? [{
        x: card.x, y: card.y, w: card.width, h: card.height,
        r: [(edge === "top" || edge === "left") ? 0 : cardRadius, (edge === "top" || edge === "right") ? 0 : cardRadius,
            (edge === "bottom" || edge === "right") ? 0 : cardRadius, (edge === "bottom" || edge === "left") ? 0 : cardRadius]
    }] : []

    // the parent's place in the window (it may slide or be laid out by ancestors)
    function track() {
        if (!parent) return;
        const p = parent.mapToItem(null, 0, 0);
        if (p.x !== offset.x || p.y !== offset.y) offset = Qt.point(p.x, p.y);
    }
    FrameAnimation { running: cs.visible; onTriggered: cs.track() }
    onVisibleChanged: if (visible) track()
    Component.onCompleted: track()
}
