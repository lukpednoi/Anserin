import QtQuick

// The press bump of a connected row: the pressed cell grows and its neighbours give way, then all settle with
// a short damped wobble. Cells read their extra width from dw(i, n) and their shift from dx(i).
QtObject {
    id: bc
    property int idx: -1
    property real px: 10            // how far the wobble reaches
    property real t: 1              // 0 → 1 over the bump
    readonly property real val: (t <= 0 || t >= 1) ? 0 : 1.9 * Math.exp(-4.5 * t) * Math.sin(9.4 * t)
    function bump(i) { idx = i; anim.stop(); t = 0; anim.start(); }
    function dw(i, n) {
        if (idx < 0 || val === 0) return 0;
        const g = px * val;
        if (i === idx) return (i > 0 ? g : 0) + (i < n - 1 ? g : 0);
        if (i === idx - 1 || i === idx + 1) return -g;
        return 0;
    }
    property NumberAnimation anim: NumberAnimation { target: bc; property: "t"; from: 0; to: 1; duration: 720 }
}
