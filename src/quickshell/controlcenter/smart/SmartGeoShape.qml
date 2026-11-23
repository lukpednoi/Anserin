import QtQuick

// 22 distinct parametric geometric shapes with smooth polar morphing (supports spring overshoot!)
// OFF = "circle", ON = any unique geometric shape below, with optional top-left -> bottom-right gradient fill.
Canvas {
    id: geo
    property string fromShape: "circle"
    property string toShape: "cookie9"
    property real morph: 1.0          // 0 = fromShape, 1 = toShape (supports overshoot)
    property real angleDeg: 0.0
    property real inset: 0.91
    property color fill: "#a5c8ff"
    property color fill2: "transparent"
    property color stroke: "transparent"
    property real strokeWidth: 1.4

    implicitWidth: 44
    implicitHeight: 44

    readonly property var _key: [
        fromShape, toShape, Math.round(morph * 1000), Math.round(angleDeg * 10),
        fill.toString(), fill2.toString(), stroke.toString(), strokeWidth, width, height
    ]
    on_KeyChanged: requestPaint()

    function polyRadius(angle, n, roundness) {
        const sector = Math.PI * 2.0 / n;
        const half = sector * 0.5;
        const a = ((angle % sector) + sector) % sector - half;
        const raw = Math.cos(half) / Math.max(0.24, Math.cos(a));
        return raw * (1.0 - roundness) + 1.0 * roundness;
    }

    function shapeRadius(name, angle) {
        const c = Math.cos(angle);
        const s = Math.sin(angle);
        switch (name) {
        case "circle":    return 1.0;
        case "squircle":  return Math.pow(Math.pow(Math.abs(c), 4.2) + Math.pow(Math.abs(s), 4.2), -1.0 / 4.2) * 0.90;
        case "triangle":  return polyRadius(angle + Math.PI * 0.5, 3, 0.34) * 0.93;
        case "diamond":   return polyRadius(angle, 4, 0.25) * 0.89;
        case "pentagon":  return polyRadius(angle + Math.PI * 0.5, 5, 0.24) * 0.93;
        case "hexagon":   return polyRadius(angle, 6, 0.22) * 0.95;
        case "heptagon":  return polyRadius(angle + Math.PI * 0.5, 7, 0.20) * 0.95;
        case "octagon":   return polyRadius(angle + Math.PI / 8.0, 8, 0.20) * 0.95;
        case "cookie4":   return (1.0 + 0.14 * Math.cos(4.0 * angle)) / 1.14;
        case "cookie6":   return (1.0 + 0.12 * Math.cos(6.0 * angle)) / 1.12;
        case "cookie8":   return (1.0 + 0.10 * Math.cos(8.0 * angle)) / 1.10;
        case "cookie9":   return (1.0 + 0.09 * Math.cos(9.0 * angle)) / 1.09;
        case "cookie12":  return (1.0 + 0.075 * Math.cos(12.0 * angle)) / 1.075;
        case "softburst": return (1.0 + 0.115 * Math.cos(14.0 * angle)) / 1.115;
        case "clover3":   return 0.57 + 0.43 * Math.pow(Math.abs(Math.cos(1.5 * angle)), 0.74);
        case "clover4":   return 0.58 + 0.42 * Math.pow(Math.abs(Math.cos(2.0 * angle)), 0.72);
        case "flower5":   return 0.68 + 0.32 * Math.pow((1.0 + Math.cos(5.0 * angle)) * 0.5, 0.85);
        case "star4":     return 0.54 + 0.46 * Math.pow((1.0 + Math.cos(4.0 * angle)) * 0.5, 1.9);
        case "star5":     return 0.62 + 0.38 * Math.pow((1.0 + Math.cos(5.0 * (angle + Math.PI * 0.5))) * 0.5, 1.85);
        case "star6":     return 0.66 + 0.34 * Math.pow((1.0 + Math.cos(6.0 * angle)) * 0.5, 1.9);
        case "arch": {
            if (s < 0) return 0.97;
            return Math.pow(Math.pow(Math.abs(c), 4.6) + Math.pow(Math.abs(s), 4.6), -1.0 / 4.6) * 0.89;
        }
        case "shield": {
            // Broad rounded top shoulders, softly tapered shield point at bottom
            const top = s < 0 ? Math.pow(Math.pow(Math.abs(c), 3.6) + Math.pow(Math.abs(s), 3.6), -1.0 / 3.6) * 0.90
                              : 0.82 + 0.18 * Math.pow(Math.max(0, s), 1.4) - 0.14 * Math.abs(c * s);
            return Math.max(0.55, Math.min(1.0, top));
        }
        case "teardrop": {
            // Softly pointed top, plump round base
            const tip = s < 0 ? 0.74 + 0.26 * Math.pow(Math.abs(s), 1.6) : 0.92;
            return tip * (1.0 - 0.12 * Math.abs(c) * Math.max(0, -s));
        }
        default: return 1.0;
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width <= 1 || height <= 1) return;

        const cx = width * 0.5;
        const cy = height * 0.5;
        const maxR = Math.min(width, height) * 0.5 * inset;
        const rotRad = angleDeg * Math.PI / 180.0;
        const t = morph;
        const steps = 144;

        ctx.beginPath();
        for (let i = 0; i <= steps; i++) {
            const a = (i / steps) * Math.PI * 2.0;
            const r0 = shapeRadius(fromShape, a);
            const r1 = shapeRadius(toShape, a);
            const r = Math.max(0.10, r0 + (r1 - r0) * t) * maxR;
            const px = cx + Math.cos(a + rotRad) * r;
            const py = cy + Math.sin(a + rotRad) * r;
            if (i === 0) ctx.moveTo(px, py);
            else ctx.lineTo(px, py);
        }
        ctx.closePath();

        if (fill2.a > 0.01) {
            const g = ctx.createLinearGradient(0, 0, width, height);
            g.addColorStop(0.0, fill);
            g.addColorStop(1.0, fill2);
            ctx.fillStyle = g;
            ctx.fill();
        } else if (fill.a > 0.01) {
            ctx.fillStyle = fill;
            ctx.fill();
        }

        if (stroke.a > 0.01 && strokeWidth > 0) {
            ctx.lineWidth = strokeWidth;
            ctx.strokeStyle = stroke;
            ctx.stroke();
        }
    }
}
