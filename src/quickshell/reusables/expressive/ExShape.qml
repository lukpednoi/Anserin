import QtQuick
import QtQuick.Shapes
import "../../"

// A playful filled shape (circle, cookie, clover, star, burst, flower, square) that morphs smoothly from one to
// another and can spin. Used behind icons, as toggle thumbs and as loading marks. Polar outline, 120 points.
Item {
    id: root
    property string shape: "cookie"
    property color color: ThemeBackend.mauve
    property real spin: 0                   // degrees
    property int lobes: 6                   // for cookie / clover / star / burst / flower
    implicitWidth: 48; implicitHeight: 48

    // morph: the outline blends from the last shape to the new one on a spring
    property string _from: shape
    property string _to: shape
    ExSpring { id: blend; token: "spatialDefault"; eps: 0.002; target: 1 }
    onShapeChanged: { root._from = root._to; root._to = root.shape; blend.target = 0; blend.snap(0); blend.target = 1; }

    function radius(kind, a) {
        const n = root.lobes;
        switch (kind) {
        case "circle": return 1;
        case "cookie": return 0.9 + 0.1 * Math.cos(n * a);
        case "clover": return 0.62 + 0.38 * Math.pow(Math.abs(Math.cos(n * a / 2)), 0.9);
        case "star":   return 0.64 + 0.36 * Math.pow((1 + Math.cos(n * a)) / 2, 2.2);
        case "burst":  return 0.78 + 0.22 * Math.pow((1 + Math.cos(n * a)) / 2, 6);
        case "flower": return 0.72 + 0.28 * Math.abs(Math.cos(n * a / 2));
        case "square": {                      // a squircle
            const c = Math.abs(Math.cos(a)), s = Math.abs(Math.sin(a));
            return 1 / Math.pow(Math.pow(c, 5) + Math.pow(s, 5), 1 / 5) * 0.86;
        }
        }
        return 1;
    }
    readonly property var points: {
        const out = [];
        const t = Math.max(0, Math.min(1.2, blend.value));
        const r0 = Math.min(width, height) / 2;
        const rot = root.spin * Math.PI / 180;
        for (let i = 0; i <= 120; i++) {
            const a = i / 120 * 2 * Math.PI;
            const r = r0 * (root.radius(root._from, a) * (1 - t) + root.radius(root._to, a) * t);
            out.push(Qt.point(width / 2 + r * Math.cos(a + rot), height / 2 + r * Math.sin(a + rot)));
        }
        return out;
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.color
            strokeWidth: -1
            PathPolyline { path: root.points }
        }
    }
}
