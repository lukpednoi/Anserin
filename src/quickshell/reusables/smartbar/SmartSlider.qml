import QtQuick
import "../../"

// A slider of the Smart bar: its name and value on the left, a hairline track with a small round knob; drag, click
// or wheel. `moved` gives the new value (rounded to `stepSize`); the owner sets `value`.
Item {
    id: slider
    property string label: ""
    property string valueText: ""
    property real from: 0
    property real to: 1
    property real stepSize: 0.05
    property real value: 0
    property real trackWidth: s(110)
    signal moved(real value)

    function s(v) { return Scaler.s(v); }
    function pick(px) {
        const t = Math.max(0, Math.min(1, px / Math.max(1, track.width)));
        moved(Math.max(from, Math.min(to, Math.round((from + t * (to - from)) / stepSize) * stepSize)));
    }

    implicitWidth: caption.implicitWidth + s(6) + trackWidth
    implicitHeight: s(24)
    opacity: enabled ? 1 : 0.4

    Text {
        id: caption
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: slider.label + (slider.label !== "" && slider.valueText !== "" ? " " : "") + slider.valueText
        font.family: ThemeBackend.fontFamily
        font.pixelSize: slider.s(10.5)
        color: Qt.alpha(ThemeBackend.text, 0.8)
    }

    Item {
        id: track
        anchors.left: caption.right
        anchors.leftMargin: slider.s(6)
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: slider.s(18)
        readonly property real frac: slider.to > slider.from ? Math.max(0, Math.min(1, (slider.value - slider.from) / (slider.to - slider.from))) : 0

        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 2
            radius: 1
            color: Qt.alpha(ThemeBackend.text, 0.2)
            Rectangle {
                width: parent.width * track.frac
                height: parent.height
                radius: 1
                color: ThemeBackend.mauve
            }
        }
        Rectangle {
            width: drag.pressed ? slider.s(12) : slider.s(10)
            height: width
            radius: width / 2
            x: Math.max(0, Math.min(parent.width - width, parent.width * track.frac - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            color: ThemeBackend.text
            Behavior on width { NumberAnimation { duration: 120 } }
        }
        MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onPressed: (m) => slider.pick(m.x)
            onPositionChanged: (m) => { if (pressed) slider.pick(m.x); }
            onWheel: (e) => {
                const dir = (e.angleDelta.y || e.angleDelta.x) > 0 ? 1 : -1;
                slider.moved(Math.max(slider.from, Math.min(slider.to, slider.value + dir * slider.stepSize)));
            }
        }
    }
}
