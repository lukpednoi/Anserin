import QtQuick
import "../../"

// A live area graph that keeps sliding left. It is painted once per sample, one step wider than shown, and the
// painting is moved left by one step over the sample interval (no repaint while it moves).
Item {
    id: spark
    property var data: []
    property int capacity: 40
    property real maxValue: 100
    property color color: ThemeBackend.mauve
    property int interval: 1000
    property bool running: true
    clip: true

    readonly property real step: width / Math.max(1, capacity - 1)

    // the slide restarts only once the new painting is up, so the graph never jumps back a step for a frame
    onDataChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onWidthChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        width: spark.width + spark.step
        height: spark.height
        NumberAnimation on x { id: glide; from: 0; to: -spark.step; duration: spark.interval; running: false }
        onPainted: glide.restart()
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const d = spark.data, n = d.length;
            if (n < 2) return;
            const step = spark.step, x0 = width - (n - 1) * step;
            const y = v => height - 2 - (height - 4) * Math.min(1, v / spark.maxValue);
            ctx.beginPath();
            ctx.moveTo(x0, y(d[0]));
            for (let i = 1; i < n; i++) ctx.lineTo(x0 + i * step, y(d[i]));
            ctx.lineWidth = 2;
            ctx.strokeStyle = spark.color;
            ctx.lineJoin = "round";
            ctx.stroke();
            ctx.lineTo(width, height);
            ctx.lineTo(x0, height);
            ctx.closePath();
            const g = ctx.createLinearGradient(0, 0, 0, height);
            g.addColorStop(0, Qt.rgba(spark.color.r, spark.color.g, spark.color.b, 0.28));
            g.addColorStop(1, Qt.rgba(spark.color.r, spark.color.g, spark.color.b, 0));
            ctx.fillStyle = g;
            ctx.fill();
        }
    }
}
