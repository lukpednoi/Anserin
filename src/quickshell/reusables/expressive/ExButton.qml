import QtQuick
import "../../"

// Expressive button: a pill at rest that squares its corners a little while pressed (and when a toggle is on),
// on a fast spatial spring, with a hover / press tint. Variants: filled, tonal, text. Sizes: xs s m l.
Item {
    id: root
    property string text: ""
    property string icon: ""
    property string variant: "tonal"
    property string size: "s"
    property bool toggleable: false
    property bool checked: false
    property bool selected: false          // shown as on without toggling itself (a group's chosen button)
    property bool square: false            // rest as a rounded square instead of a pill
    property real extraWidth: 0            // set by a connected group's bump
    property string clickSound: "reusables/clickbutton/click.wav"
    readonly property alias pressed: ma.pressed
    readonly property alias hovered: ma.containsMouse
    signal clicked()

    function s(v) { return Scaler.s(v); }
    // [height, side padding, icon, font, square radius, pressed radius]
    readonly property var spec: ({ xs: [32, 12, 16, 12, 12, 8], s: [40, 16, 18, 13, 12, 8],
                                   m: [56, 22, 22, 15, 16, 12], l: [88, 36, 30, 20, 26, 16] })[size]
    readonly property real h: s(spec[0])
    readonly property bool on: (toggleable && checked) || selected
    readonly property real restR: (square !== on) ? s(spec[4]) : h / 2
    ExSpring { id: rad; token: "spatialFast"; eps: 0.05; target: ma.pressed ? root.s(root.spec[5]) : root.restR }
    ExSpring { id: grow; token: "spatialFast"; eps: 0.05; target: root.extraWidth }

    readonly property color fill: variant === "filled" || on ? ThemeBackend.mauve
                                : variant === "tonal" ? ThemeBackend.surface1 : "transparent"
    readonly property color ink: variant === "filled" || on ? ThemeBackend.crust : ThemeBackend.text

    implicitHeight: h
    implicitWidth: Math.max(h, row.implicitWidth + s(spec[1]) * 2) + grow.value
    opacity: enabled ? 1 : 0.38

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Math.max(0, Math.min(height / 2, rad.value))
        color: root.fill
        Behavior on color { ColorAnimation { duration: ExMotion.fast } }
    }
    ExStateLayer {
        anchors.fill: parent
        radius: body.radius
        color: root.ink
        hovered: ma.containsMouse
        pressed: ma.pressed
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.s(8)
        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.s(root.spec[2])
            color: root.ink
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            visible: root.text !== ""
            text: root.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(root.spec[3])
            font.weight: Font.DemiBold
            color: root.ink
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (root.clickSound !== "") Sounds.playSfx(root.clickSound);
            if (root.toggleable) root.checked = !root.checked;
            root.clicked();
        }
    }
}
