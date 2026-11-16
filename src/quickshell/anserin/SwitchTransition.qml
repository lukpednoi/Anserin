import QtQuick

// Black circle grows from `origin` until it covers this item, three white dots bounce in a
// wave twice, then the circle shrinks back to `origin`. Slow and soft (~3 s at speed 1; the black circle moves at the Lock screen fade speed (400 ms)), using the same InOutCubic as the startup panel reveal.
Item {
    id: root
    property point origin: Qt.point(width / 2, height / 2)
    property real speed: 1
    readonly property bool running: anim.running
    property real grow: 0      // 0 = point, 1 = covers the item
    property real wave: 0      // 0..1 across both bounces
    property real dotsOpacity: 0

    signal covered()
    signal finished()

    function play() { anim.restart(); }
    function stop() { anim.stop(); grow = 0; wave = 0; dotsOpacity = 0; }

    readonly property real fullRadius: Math.sqrt(
        Math.pow(Math.max(origin.x, width - origin.x), 2) + Math.pow(Math.max(origin.y, height - origin.y), 2))
    readonly property real dotSize: Math.max(10, Math.min(width, height) * 0.025)

    visible: grow > 0
    enabled: visible

    Rectangle {
        x: root.origin.x - width / 2
        y: root.origin.y - height / 2
        width: root.fullRadius * 2 * root.grow
        height: width
        radius: width / 2
        color: "black"
    }

    // Blocks clicks while the circle is on screen.
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true }

    Row {
        anchors.centerIn: parent
        spacing: root.dotSize * 0.9
        opacity: root.dotsOpacity
        Repeater {
            model: 3
            Rectangle {
                required property int index
                readonly property real phase: root.wave * 2.5 - index * 0.25
                width: root.dotSize; height: width; radius: width / 2
                color: "white"
                transform: Translate {
                    y: (phase >= 0 && phase <= 2) ? -root.dotSize * 1.8 * 0.5 * (1 - Math.cos(phase * 2 * Math.PI)) : 0
                }
            }
        }
    }

    SequentialAnimation {
        id: anim
        ScriptAction { script: { root.grow = 0; root.wave = 0; root.dotsOpacity = 0; } }
        NumberAnimation { target: root; property: "grow"; to: 1; duration: 400 / root.speed; easing.type: Easing.InOutCubic }
        ScriptAction { script: root.covered() }
        NumberAnimation { target: root; property: "dotsOpacity"; to: 1; duration: 300 / root.speed; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "wave"; to: 1; duration: 1600 / root.speed }
        NumberAnimation { target: root; property: "dotsOpacity"; to: 0; duration: 300 / root.speed; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "grow"; to: 0; duration: 400 / root.speed; easing.type: Easing.InOutCubic }
        ScriptAction { script: root.finished() }
    }
}
