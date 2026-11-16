#!/usr/bin/env python3
"""Turns the duck rig (duck-rig-34.svg: the locked three-quarter design split into <g id> parts) into
src/quickshell/pet/DuckRig.qml.
Each part becomes an Item drawn with Qt Shapes, with the transform and visibility listed in PARTS below, driven by
DuckRig's pose properties. Edit the drawing in the SVG, then run: python3 rig2qml.py"""
import os, re, sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from svg2qml import NS, ellipse, gradients, shape_path as plain_shape_path  # noqa: E402

SVG = os.path.join(HERE, "duck-rig-34.svg")
OUT = os.path.join(HERE, "..", "..", "quickshell", "pet", "DuckRig.qml")

# gradients that take their colours from the palette (DuckColours.js): gradient id -> palette key
PAL_GRADIENTS = {"plumage": "body", "headPlumage": "head", "tailPlumage": "tail", "wing": "wing", "primaries": "primaries",
                 "wingOpen": "wingOpen", "farWing": "farWing", "billTop": "bill"}


def palette_gradients(grads):
    for gid, key in PAL_GRADIENTS.items():
        head, _, stops = grads[gid]
        body = " ".join(f"GradientStop {{ position: {pos}; color: duck.pal.{key}[{i}] }}" for i, (pos, _) in enumerate(stops))
        grads[gid] = (head, body, stops)
    return grads


def shape_path(d, attrs, grads):
    """As svg2qml's, plus fill="pal:<key>": a flat colour from the palette (transparent where a variety has none)."""
    fill, stroke = attrs.get("fill", ""), attrs.get("stroke", "none")
    op = float(attrs.get("opacity", "1"))
    plain = dict(attrs)
    if fill.startswith("pal:"):
        plain["fill"] = "none"
    if stroke.startswith("pal:"):
        plain["stroke"] = "#000000"
    out = plain_shape_path(d, plain, grads)

    def pal(key, alpha):  # Qt.alpha() would turn "transparent" into black, so keep it as it is
        return f'(duck.pal.{key} === "transparent" ? "transparent" : Qt.alpha(duck.pal.{key}, {alpha:g}))'
    if fill.startswith("pal:"):
        out = out.replace('fillColor: "transparent"', f"fillColor: {pal(fill[4:], op)}", 1)
    if stroke.startswith("pal:"):
        sop = float(attrs.get("stroke-opacity", "1")) * op
        out = re.sub(r'strokeColor: "#[0-9a-f]*000000"', f"strokeColor: {pal(stroke[4:], sop)}", out, count=1)
    return out


BREATH = "Scale { origin.x: 194; origin.y: 252; xScale: 1 + 0.012 * duck.breath; yScale: 1 + 0.03 * duck.breath }"
# part id -> (visible / opacity bindings, transforms)
PARTS = {
    "shadow":      (["visible: duck.shadowVisible"], []),
    "farWingOpen": (["visible: duck.wingsOpen"], [BREATH, "Rotation { origin.x: 216; origin.y: 142; angle: -0.8 * duck.flap }"]),
    "farLeg":      (["visible: duck.legsVisible"], ["Rotation { origin.x: 214; origin.y: 246; angle: duck.farLegSwing }"]),
    "tail":        ([], [BREATH, "Rotation { origin.x: 124; origin.y: 160; angle: duck.tailWag }"]),
    "body":        ([], [BREATH]),
    "head":        ([], [BREATH,
                         "Scale { origin.x: 258; origin.y: 160; xScale: duck.headFlip ? -1 : 1 }",
                         "Rotation { origin.x: 258; origin.y: 160; angle: duck.headAngle }",
                         "Translate { x: duck.headX; y: duck.headY }"]),
    # eyes are open or shut, never half: shut is just the soft curved line (no grey lid)
    "farEye":      (["visible: duck.eyesClosed < 0.5"], []),
    "nearEye":     (["visible: duck.eyesClosed < 0.5"], []),
    "lids":        (["visible: duck.eyesClosed >= 0.5"], []),
    "mouth":       (["visible: duck.jawOpen > 0.5"], []),
    "jaw":         ([], ["Rotation { origin.x: 292; origin.y: 122; angle: duck.jawOpen }"]),
    "bill":        ([], ["Rotation { origin.x: 290; origin.y: 112; angle: -0.3 * duck.jawOpen }"]),
    "breast":      ([], [BREATH]),
    "headSheen":   (["opacity: duck.pal.sheen"], []),
    "rearShadeShade": (["opacity: duck.pal.shade"], []),
    "bellyShade":  (["opacity: duck.pal.shade"], []),
    "breastSheen": (["opacity: duck.pal.sheen"], []),
    "wingFolded":  (["visible: !duck.wingsOpen"], [BREATH]),
    "wingOpen":    (["visible: duck.wingsOpen"], [BREATH, "Rotation { origin.x: 234; origin.y: 164; angle: -duck.flap }"]),
    "nearLeg":     (["visible: duck.legsVisible"], ["Rotation { origin.x: 180; origin.y: 248; angle: duck.legSwing }"]),
}


def emit_group(node, grads, inherited, pad):
    """The children of one part: runs of paths become one Shape each, nested parts become Items, in paint order."""
    out, run = [], []

    def flush():
        if run:
            inner = "\n".join(run)
            out.append(f"{pad}Shape {{\n{pad}    anchors.fill: parent\n{pad}    preferredRendererType: Shape.CurveRenderer\n{inner}\n{pad}}}")
            run.clear()

    def walk(n, inh):
        for el in n:
            if not isinstance(el.tag, str):
                continue
            tag = el.tag.replace(NS, "")
            attrs = dict(inh)
            attrs.update({k: v for k, v in el.attrib.items() if k not in ("id", "display")})
            if tag == "g" and el.get("id"):
                flush()
                out.append(emit_part(el, grads, attrs, pad))
            elif tag == "g":
                if "opacity" in inh and "opacity" in el.attrib:
                    attrs["opacity"] = str(float(inh["opacity"]) * float(el.attrib["opacity"]))
                walk(el, {k: v for k, v in attrs.items() if k != "transform"})
            elif tag == "path":
                run.append(shape_path(el.get("d"), attrs, grads))
            elif tag == "ellipse":
                rot = None
                m = re.match(r"rotate\(([-\d.]+) ([-\d.]+) ([-\d.]+)\)", el.get("transform", ""))
                if m:
                    rot = tuple(float(v) for v in m.groups())
                run.append(shape_path(ellipse(float(el.get("cx")), float(el.get("cy")), float(el.get("rx")), float(el.get("ry")), rot), attrs, grads))

    walk(node, inherited)
    flush()
    return "\n".join(out)


# The neck's join: a band from where the neck leaves the body to where the head's neck ends, following the head, so
# the head never floats free of the body however it turns. Drawn just before the head.
NECK_BRIDGE = """{pad}Shape {{  // neck join
{pad}    id: neckJoin
{pad}    anchors.fill: parent
{pad}    preferredRendererType: Shape.CurveRenderer
{pad}    transform: [ {breath} ]
{pad}    // only as the head moves off its place, so at rest the duck is exactly the locked design
{pad}    // (not for the small nods of walking: its shape is worked out again on every frame it shows)
{pad}    opacity: Math.max(0, Math.min(1, (Math.hypot(duck.headX, duck.headY) + Math.abs(duck.headAngle) * 0.4 - 4) / 6))
{pad}    visible: opacity > 0
{pad}    // the head's transform applied to a point of the drawing
{pad}    function hp(x, y) {{
{pad}        if (duck.headFlip) x = 516 - x;
{pad}        const a = duck.headAngle * Math.PI / 180, dx = x - 258, dy = y - 160;
{pad}        return (258 + dx * Math.cos(a) - dy * Math.sin(a) + duck.headX) + " " + (160 + dx * Math.sin(a) + dy * Math.cos(a) + duck.headY);
{pad}    }}
{pad}    // back of the neck: from the back line, curving up into the nape; front: from under the chin down onto the breast
{pad}    readonly property string back: "M 212 135 C 222 137 " + hp(219, 138) + " " + hp(221, 126)
{pad}    readonly property string front: "M " + hp(300, 150) + " C " + hp(304, 176) + " 318 184 306 198"
{pad}    ShapePath {{
{pad}        strokeWidth: -1; strokeColor: "transparent"
{pad}        fillGradient: RadialGradient {{ centerX: 236; centerY: 150; centerRadius: 178; focalX: 236; focalY: 150; focalRadius: 0
{pad}            GradientStop {{ position: 0; color: duck.pal.head[0] }} GradientStop {{ position: 0.5; color: duck.pal.head[1] }} GradientStop {{ position: 0.82; color: duck.pal.head[2] }} GradientStop {{ position: 1; color: duck.pal.head[3] }} }}
{pad}        PathSvg {{ path: neckJoin.back + " L " + neckJoin.hp(262, 150) + " L " + neckJoin.hp(300, 150)
{pad}                         + " C " + neckJoin.hp(304, 176) + " 318 184 306 198 Q 262 200 212 135 Z" }}
{pad}    }}
{pad}    ShapePath {{
{pad}        fillColor: "transparent"; strokeColor: Qt.alpha(duck.pal.outline, 0.7); strokeWidth: 1.1; capStyle: ShapePath.RoundCap
{pad}        PathSvg {{ path: neckJoin.back + " " + neckJoin.front }}
{pad}    }}
{pad}}}"""


def emit_part(g, grads, inherited, pad):
    pid = g.get("id")
    props, transforms = PARTS.get(pid, ([], []))
    lines = [f"{pad}Item {{  // {pid}", f"{pad}    anchors.fill: parent"]
    lines += [f"{pad}    {p}" for p in props]
    if transforms:
        lines.append(f"{pad}    transform: [")
        lines.append(",\n".join(f"{pad}        {t}" for t in transforms))
        lines.append(f"{pad}    ]")
    lines.append(emit_group(g, grads, {k: v for k, v in inherited.items() if k != "transform"}, pad + "    "))
    lines.append(f"{pad}}}")
    return "\n".join(lines)


def main():
    root = ET.parse(SVG, ET.XMLParser(target=ET.TreeBuilder(insert_comments=False))).getroot()
    grads = palette_gradients(gradients(root))
    parts = []
    for g in root:
        if isinstance(g.tag, str) and g.tag.replace(NS, "") == "g":
            if g.get("id") == "head":
                parts.append(NECK_BRIDGE.format(pad=" " * 12, breath=BREATH))
            parts.append(emit_part(g, grads, {}, " " * 12))
    shadow, rest = parts[0], parts[1:]
    qml = f'''import QtQuick
import QtQuick.Shapes
import "DuckColours.js" as DuckColours

// The white Call duck, three-quarter view, as a rig: the locked design split into parts that move. Written by
// src/assets/pet/rig2qml.py from src/assets/pet/duck-rig-34.svg; edit the drawing there, not here. At rest it draws the locked design.
// Pose properties (an action animates them):
//   whole duck: rock (deg, over its feet), bob (px up), shakeX (px sideways), stretchY (squash < 0 < stretch),
//               breath (0..1)
//   head:       headAngle (deg, + dips it forward), headX / headY (px), headFlip (looks back), eyesClosed (shut at 0.5+),
//               jawOpen (deg, opens the bill)
//   wings:      wingsOpen (spread instead of folded), flap (deg, + raises them)
//   tail / legs: tailWag (deg), legSwing / farLegSwing (deg), legsVisible, shadowVisible
//   colour:     one of DuckColours.list's ids ("white", the locked design, by default)
// The drawing is 400x300 and scales to fit the item.
Item {{
    id: duck
    property real rock: 0
    property real bob: 0
    property real shakeX: 0
    property real stretchY: 0
    property real breath: 0
    property real headAngle: 0
    property real headX: 0
    property real headY: 0
    property bool headFlip: false
    property real eyesClosed: 0
    property real jawOpen: 0
    property bool wingsOpen: false
    property real flap: 0
    property real tailWag: 0
    property real legSwing: 0
    property real farLegSwing: -legSwing
    property bool legsVisible: true
    property bool shadowVisible: true
    property string colour: "white"
    readonly property var pal: DuckColours.palette(colour)
    implicitWidth: 400
    implicitHeight: 300

    Item {{
        width: 400
        height: 300
        scale: Math.min(duck.width / 400, duck.height / 300)
        transformOrigin: Item.TopLeft
        x: (duck.width - 400 * scale) / 2
        y: (duck.height - 300 * scale) / 2

{shadow}

        Item {{
            anchors.fill: parent
            transform: [
                Scale {{ origin.x: 194; origin.y: 272; xScale: 1 - 0.45 * duck.stretchY; yScale: 1 + duck.stretchY }},
                Rotation {{ origin.x: 194; origin.y: 272; angle: duck.rock }},
                Translate {{ x: duck.shakeX; y: -duck.bob }}
            ]

{chr(10).join(rest)}
        }}
    }}
}}
'''
    open(OUT, "w").write(qml)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
