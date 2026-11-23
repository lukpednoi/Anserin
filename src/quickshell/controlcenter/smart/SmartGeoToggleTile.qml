import QtQuick

// Smart Home Toggle Tile:
// - OFF: normal circular icon button on quiet dark/glass Smart Home card.
// - ON:  circle springs & morphs into a UNIQUE geometric shape (no duplicates!)
//        AND a luminous gradient floods diagonally from TOP-LEFT to BOTTOM-RIGHT (like BoardCell's flood!).
Item {
    id: tile
    property string icon: "󰌵"
    property string title: "Toggle"
    property string geoShape: "cookie9"    // unique geometric shape per button!
    property bool checked: false
    property bool available: true
    property real cornerRadius: 16
    property bool liquidGlass: false
    property bool darkMode: true
    property color surface: "#171a20"
    property color surfaceHover: "#1f232b"
    property color accent: "#a5c8ff"
    property color accent2: "#dabde2"
    property color inkAccent: "#0c0e13"
    property color textColor: "#e8ecf2"
    property color subColor: "#9aa2b0"
    property string uiFont: "Noto Sans"
    property string iconFont: "Symbols Nerd Font Mono"

    signal toggled(bool value)

    implicitHeight: 84
    height: implicitHeight
    opacity: available ? 1.0 : 0.42
    enabled: available

    // Springs: flood sweep (top-left -> bottom-right), shape morph (circle -> geoShape), bouncy press
    SpringVal { id: floodSp; target: tile.checked ? 1.0 : 0.0; stiffness: 250; damping: 0.66; eps: 0.002 }
    SpringVal { id: morphSp; target: tile.checked ? 1.0 : 0.0; stiffness: 360; damping: 0.46; eps: 0.002 }
    SpringVal { id: spinSp;  target: tile.checked ? 26.0 : 0.0; stiffness: 310; damping: 0.48; eps: 0.05 }
    SpringVal { id: pressSp; target: ma.pressed ? 0.955 : (hov.hovered ? 1.015 : 1.0); stiffness: 520; damping: 0.46; eps: 0.001 }

    scale: pressSp.value

    // Card surface + top-left -> bottom-right diagonal gradient flood
    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: Math.max(10, Math.min(22, tile.cornerRadius))
        color: tile.liquidGlass
            ? Qt.rgba(hov.hovered ? tile.surfaceHover.r : tile.surface.r,
                      hov.hovered ? tile.surfaceHover.g : tile.surface.g,
                      hov.hovered ? tile.surfaceHover.b : tile.surface.b, tile.darkMode ? 0.56 : 0.68)
            : (hov.hovered ? tile.surfaceHover : tile.surface)
        border.width: 1
        border.color: tile.checked
            ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.42)
            : (tile.darkMode ? Qt.rgba(1, 1, 1, hov.hovered ? 0.14 : 0.08) : Qt.rgba(0, 0, 0, hov.hovered ? 0.12 : 0.07))
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }
        clip: true

        // Top-left -> bottom-right diagonal gradient flood!
        Canvas {
            id: floodCanvas
            anchors.fill: parent
            visible: floodSp.value > 0.004
            readonly property var _k: [
                Math.round(floodSp.value * 500),
                tile.accent.toString(), tile.accent2.toString(),
                tile.darkMode, cardBg.radius, width, height
            ]
            on_KChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (width <= 2 || height <= 2 || floodSp.value <= 0.004) return;
                const f = Math.max(0, floodSp.value);
                const r = cardBg.radius;

                // Clip to rounded card
                ctx.save();
                ctx.beginPath();
                ctx.roundedRect(0, 0, width, height, r, r);
                ctx.clip();

                // Expanding circular front originating from top-left icon center (26, 26)
                const ox = 26, oy = 26;
                const maxR = Math.hypot(width - ox, height - oy) * 1.15;
                const curR = maxR * f;

                // Diagonal top-left -> bottom-right colour gradient!
                const grad = ctx.createLinearGradient(0, 0, width, height);
                const aTop = tile.darkMode ? 0.30 : 0.24;
                const aMid = tile.darkMode ? 0.18 : 0.14;
                const aBot = tile.darkMode ? 0.08 : 0.06;
                grad.addColorStop(0.0, Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, aTop));
                grad.addColorStop(0.55, Qt.rgba(tile.accent2.r, tile.accent2.g, tile.accent2.b, aMid));
                grad.addColorStop(1.0, Qt.rgba(tile.accent2.r, tile.accent2.g, tile.accent2.b, aBot));

                ctx.beginPath();
                ctx.arc(ox, oy, curR, 0, Math.PI * 2);
                ctx.fillStyle = grad;
                ctx.fill();

                // Delicate luminous top-left rim sheen when ON
                if (f > 0.25) {
                    const sheen = ctx.createLinearGradient(0, 0, width * 0.7, height * 0.7);
                    sheen.addColorStop(0.0, Qt.rgba(1, 1, 1, (tile.darkMode ? 0.14 : 0.36) * Math.min(1, f)));
                    sheen.addColorStop(1.0, "transparent");
                    ctx.strokeStyle = sheen;
                    ctx.lineWidth = 1.4;
                    ctx.beginPath();
                    ctx.roundedRect(0.7, 0.7, width - 1.4, height - 1.4, r - 0.5, r - 0.5);
                    ctx.stroke();
                }
                ctx.restore();
            }
        }
    }

    // Top row: geometric shape button (circle when OFF -> unique geoShape when ON) + ON/OFF indicator dot
    Item {
        id: topRow
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 10
        height: 36

        SmartGeoShape {
            id: badge
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36
            fromShape: "circle"
            toShape: tile.geoShape
            morph: morphSp.value
            angleDeg: spinSp.value
            // Top-left -> bottom-right gradient on the active geometric shape too!
            fill: tile.checked ? tile.accent : (tile.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06))
            fill2: tile.checked ? tile.accent2 : "transparent"
            stroke: tile.checked ? "transparent" : (tile.darkMode ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.12))
            strokeWidth: 1.0
            Behavior on fill { ColorAnimation { duration: 180 } }

            Text {
                anchors.centerIn: parent
                text: tile.icon
                font.family: tile.iconFont
                font.pixelSize: 16
                color: tile.checked ? tile.inkAccent : tile.subColor
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        // Smart Home minimal status readout (top-right)
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Rectangle {
                width: 5; height: 5; radius: 2.5
                anchors.verticalCenter: parent.verticalCenter
                color: tile.checked ? tile.accent : Qt.rgba(tile.subColor.r, tile.subColor.g, tile.subColor.b, 0.40)
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            Text {
                text: tile.checked ? "ON" : "OFF"
                font.family: tile.uiFont
                font.pixelSize: 9
                font.weight: tile.checked ? Font.DemiBold : Font.Light
                font.letterSpacing: 0.9
                color: tile.checked ? tile.accent : tile.subColor
                Behavior on color { ColorAnimation { duration: 180 } }
            }
        }
    }

    // Bottom title (crisp Smart Home label)
    Text {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 13; anchors.rightMargin: 12; anchors.bottomMargin: 11
        elide: Text.ElideRight
        text: tile.title
        font.family: tile.uiFont
        font.pixelSize: 12
        font.weight: tile.checked ? Font.Medium : Font.Normal
        color: tile.textColor
    }

    HoverHandler { id: hov }

    MouseArea {
        id: ma
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            pressSp.kick(0.75);
            morphSp.kick(tile.checked ? -4.2 : 4.8);
            spinSp.kick(tile.checked ? -160 : 180);
            tile.toggled(!tile.checked);
        }
    }
}
