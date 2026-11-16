import QtQuick

// The "water wave" behind a button that just changed state: the old colour is wiped to the right by a
// wavy front, uncovering the new colour underneath. Sits on top of a button and draws only while it moves.
Canvas {
    id: c
    property real radius: 0
    property color oldColor: "transparent"
    property real sweep: 1            // 0 = just flipped, 1 = settled
    anchors.fill: parent
    visible: sweep < 1
    onSweepChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        if (sweep >= 1) return;
        var amp = height * 0.16;
        var front = -amp * 2 + sweep * (width + amp * 4);
        ctx.save();
        ctx.beginPath();
        ctx.roundedRect(0, 0, width, height, c.radius, c.radius);
        ctx.clip();
        ctx.beginPath();
        ctx.moveTo(width + amp * 4, 0);
        for (var y = 0; y <= height; y += 2) ctx.lineTo(front + amp * Math.sin(y / height * Math.PI * 3 + sweep * 9), y);
        ctx.lineTo(width + amp * 4, height);
        ctx.closePath();
        ctx.fillStyle = c.oldColor;
        ctx.fill();
        ctx.restore();
    }
}
