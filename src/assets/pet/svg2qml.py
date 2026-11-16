#!/usr/bin/env python3
"""Shared helpers for rig2qml.py: SVG paths, ellipses and gradients as Qt Shapes (ShapePath, PathSvg, gradients).
Run on its own it turns the plain locked drawing (duck-design-34.svg, not split into parts) into a Duck34.qml next to
this file, for reference only; the shell draws the duck from DuckRig.qml (rig2qml.py)."""
import math, os, re
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
SVG = os.path.join(HERE, "duck-design-34.svg")
OUT = os.path.join(HERE, "Duck34.qml")
NS = "{http://www.w3.org/2000/svg}"

# which part each commented block of the SVG belongs to
PARTS = [("ground shadow", "shadow"), ("far leg", "farLeg"), ("tail", "tail"), ("far eye", "eyes"),
         ("near eye", "eyes"), ("near leg", "nearLeg")]


def part_of(comment):
    for key, part in PARTS:
        if key in comment:
            return part
    return "body"


def argb(color, alpha):
    color = color.strip()
    if len(color) == 4:  # #rgb -> #rrggbb
        color = "#" + "".join(ch * 2 for ch in color[1:])
    if alpha >= 0.999:
        return color
    return "#%02x%s" % (round(alpha * 255), color[1:])


def ellipse(cx, cy, rx, ry, rot=None):
    k = 0.5523
    pts = [(cx - rx, cy), (cx - rx, cy - ry * k), (cx - rx * k, cy - ry), (cx, cy - ry), (cx + rx * k, cy - ry),
           (cx + rx, cy - ry * k), (cx + rx, cy), (cx + rx, cy + ry * k), (cx + rx * k, cy + ry), (cx, cy + ry),
           (cx - rx * k, cy + ry), (cx - rx, cy + ry * k), (cx - rx, cy)]
    if rot:
        a, ox, oy = math.radians(rot[0]), rot[1], rot[2]
        pts = [(ox + (x - ox) * math.cos(a) - (y - oy) * math.sin(a), oy + (x - ox) * math.sin(a) + (y - oy) * math.cos(a)) for x, y in pts]
    f = lambda p: f"{p[0]:.2f} {p[1]:.2f}"
    d = f"M {f(pts[0])}"
    for i in range(1, 13, 3):
        d += f" C {f(pts[i])} {f(pts[i+1])} {f(pts[i+2])}"
    return d + " Z"


def gradients(root):
    out = {}
    for g in root.iter():
        if not isinstance(g.tag, str):
            continue
        tag = g.tag.replace(NS, "")
        if tag not in ("radialGradient", "linearGradient"):
            continue
        stops = []
        for s in g:
            if s.tag.replace(NS, "") == "stop":
                stops.append((float(s.get("offset")), argb(s.get("stop-color"), float(s.get("stop-opacity", "1")))))
        if tag == "radialGradient":
            cx, cy, r = (float(g.get(k)) for k in ("cx", "cy", "r"))
            head = f"RadialGradient {{ centerX: {cx}; centerY: {cy}; centerRadius: {r}; focalX: {cx}; focalY: {cy}; focalRadius: 0"
        else:
            x1, y1, x2, y2 = (float(g.get(k)) for k in ("x1", "y1", "x2", "y2"))
            head = f"LinearGradient {{ x1: {x1}; y1: {y1}; x2: {x2}; y2: {y2}"
        body = " ".join(f"GradientStop {{ position: {p}; color: \"{c}\" }}" for p, c in stops)
        out[g.get("id")] = (head, body, stops)
    return out


def shape_path(d, attrs, grads):
    op = float(attrs.get("opacity", "1"))
    fill = attrs.get("fill", "#000")
    stroke = attrs.get("stroke", "none")
    lines = []
    if fill.startswith("url("):
        head, body, _ = grads[fill[5:-1]]
        if op < 1:  # fold the element's opacity into the stops
            body = " ".join(f"GradientStop {{ position: {p}; color: \"{_mul(c, op)}\" }}" for p, c in grads[fill[5:-1]][2])
        lines.append(f"fillGradient: {head}; {body} }}")
        lines.append('fillColor: "transparent"')
    elif fill == "none":
        lines.append('fillColor: "transparent"')
    else:
        lines.append(f'fillColor: "{argb(fill, op)}"')
    if stroke == "none":
        lines.append("strokeWidth: -1")
        lines.append('strokeColor: "transparent"')
    else:
        if stroke.startswith("url("):  # Shapes cannot stroke with a gradient: use its middle colour
            stops = grads[stroke[5:-1]][2]
            stroke = stops[len(stops) // 2][1]
        sop = float(attrs.get("stroke-opacity", "1")) * op
        lines.append(f'strokeColor: "{argb(stroke, sop)}"')
        lines.append(f"strokeWidth: {attrs.get('stroke-width', '1')}")
        lines.append("capStyle: ShapePath.RoundCap" if attrs.get("stroke-linecap") == "round" else "capStyle: ShapePath.FlatCap")
        lines.append("joinStyle: ShapePath.RoundJoin")
    d = re.sub(r"\s+", " ", d).strip()
    # one property per line: a gradient object binding cannot be followed by ';'
    return "ShapePath {\n" + "\n".join(lines) + f'\nPathSvg {{ path: "{d}" }}\n}}'


def _mul(c, op):
    if len(c) == 9:
        a = int(c[1:3], 16) / 255
        return argb("#" + c[3:], a * op)
    return argb(c, op)


def collect(root, grads):
    parts = {"shadow": [], "farLeg": [], "tail": [], "body": [], "eyes": [], "nearLeg": []}
    current = "body"

    def walk(node, inherited):
        nonlocal current
        for el in node:
            if el.tag is ET.Comment:
                current = part_of(el.text or "")
                continue
            tag = el.tag.replace(NS, "")
            if tag == "defs":
                continue
            attrs = dict(inherited)
            attrs.update({k: v for k, v in el.attrib.items()})
            if tag == "g":
                if "opacity" in inherited and "opacity" in el.attrib:
                    attrs["opacity"] = str(float(inherited["opacity"]) * float(el.attrib["opacity"]))
                walk(el, {k: v for k, v in attrs.items() if k not in ("id", "transform")})
            elif tag == "path":
                parts[current].append(shape_path(el.get("d"), attrs, grads))
            elif tag == "ellipse":
                rot = None
                m = re.match(r"rotate\(([-\d.]+) ([-\d.]+) ([-\d.]+)\)", el.get("transform", ""))
                if m:
                    rot = tuple(float(v) for v in m.groups())
                d = ellipse(float(el.get("cx")), float(el.get("cy")), float(el.get("rx")), float(el.get("ry")), rot)
                parts[current].append(shape_path(d, attrs, grads))

    walk(root, {})
    return parts


def shape(paths, indent):
    pad = " " * indent
    inner = "\n".join(pad + "    " + p for p in paths)
    return f"{pad}Shape {{\n{pad}    anchors.fill: parent\n{pad}    preferredRendererType: Shape.CurveRenderer\n{inner}\n{pad}}}"


def main():
    parser = ET.XMLParser(target=ET.TreeBuilder(insert_comments=True))
    root = ET.parse(SVG, parser).getroot()
    p = collect(root, gradients(root))
    qml = f'''import QtQuick
import QtQuick.Shapes

// The white Call duck, three-quarter view, drawn live. Written by duck/svg2qml.py from duck/duck-design-34.svg
// (the locked design): edit the drawing there, not here. The parts that move are split out; a pose sets:
//   breath (0..1) swells the body, rock (deg) tips it over its feet, bob (px) lifts it, legSwing (deg) swings
//   the near leg forward and the far one back, tailWag (deg), eyesClosed (0..1), legsVisible, shadowVisible.
// The drawing is 400x300 and scales to fit the item.
Item {{
    id: duck
    property real breath: 0
    property real rock: 0
    property real bob: 0
    property real legSwing: 0
    property real tailWag: 0
    property real eyesClosed: 0
    property bool legsVisible: true
    property bool shadowVisible: true
    implicitWidth: 400
    implicitHeight: 300

    Item {{
        width: 400
        height: 300
        scale: Math.min(duck.width / 400, duck.height / 300)
        transformOrigin: Item.TopLeft
        x: (duck.width - 400 * scale) / 2
        y: (duck.height - 300 * scale) / 2

        Item {{
            anchors.fill: parent
            visible: duck.shadowVisible
{shape(p["shadow"], 12)}
        }}

        Item {{
            anchors.fill: parent
            transform: [
                Rotation {{ origin.x: 194; origin.y: 272; angle: duck.rock }},
                Translate {{ y: -duck.bob }}
            ]

            Item {{
                anchors.fill: parent
                visible: duck.legsVisible
                transform: Rotation {{ origin.x: 214; origin.y: 246; angle: -duck.legSwing }}
{shape(p["farLeg"], 16)}
            }}
            Item {{
                anchors.fill: parent
                transform: Rotation {{ origin.x: 118; origin.y: 160; angle: duck.tailWag }}
{shape(p["tail"], 16)}
            }}
            Item {{
                anchors.fill: parent
                transform: Scale {{ origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath }}
{shape(p["body"], 16)}
                Item {{
                    anchors.fill: parent
                    opacity: 1 - duck.eyesClosed
                    visible: opacity > 0
{shape(p["eyes"], 20)}
                }}
                // closed eyes: the eyes fade out and a soft lash line shows
                Shape {{
                    anchors.fill: parent
                    opacity: duck.eyesClosed
                    visible: opacity > 0
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {{ fillColor: "transparent"; strokeColor: "#3b4150"; strokeWidth: 1.7; capStyle: ShapePath.RoundCap
                                PathSvg {{ path: "M 260.5 90.5 Q 268 96.5 275.5 90.5 M 310.4 89 Q 313 92.6 315.6 89" }} }}
                }}
            }}
            Item {{
                anchors.fill: parent
                visible: duck.legsVisible
                transform: Rotation {{ origin.x: 180; origin.y: 248; angle: duck.legSwing }}
{shape(p["nearLeg"], 16)}
            }}
        }}
    }}
}}
'''
    open(OUT, "w").write(qml)
    print("wrote", OUT, {k: len(v) for k, v in p.items()})


if __name__ == "__main__":
    main()
