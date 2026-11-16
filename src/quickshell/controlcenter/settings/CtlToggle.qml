import QtQuick
import "../../"

// Pill switch with a small ripple when it flips.
Item {
    id: t
    property bool checked: false
    property color accent: ThemeBackend.mauve
    signal toggled(bool value)
    implicitWidth: 46
    implicitHeight: 26

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: t.checked ? t.accent : ThemeBackend.surface1
        Behavior on color { ColorAnimation { duration: 180 } }
        Rectangle {
            id: knob
            y: 3; width: parent.height - 6; height: width; radius: width / 2
            x: t.checked ? parent.width - width - 3 : 3
            color: t.checked ? ThemeBackend.crust : ThemeBackend.text
            Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
            Behavior on color { ColorAnimation { duration: 180 } }
        }
        Rectangle {
            id: ripple
            width: 4; height: 4; radius: width / 2
            x: knob.x + knob.width / 2 - width / 2; y: parent.height / 2 - height / 2
            color: t.accent; opacity: 0
            ParallelAnimation {
                id: rippleAnim
                NumberAnimation { target: ripple; property: "width"; from: 6; to: pill.height * 2.2; duration: 420; easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "height"; from: 6; to: pill.height * 2.2; duration: 420; easing.type: Easing.OutCubic }
                NumberAnimation { target: ripple; property: "opacity"; from: 0.45; to: 0; duration: 420 }
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: { rippleAnim.restart(); Sounds.playSfx("reusables/toggle/sfx.wav"); t.toggled(!t.checked); }
    }
}
