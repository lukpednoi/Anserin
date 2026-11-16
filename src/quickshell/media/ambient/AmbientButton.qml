import QtQuick
import "../../"

// A round see-through button of the Ambient Music style (Lyrics, EQ, back, play / pause, forward); the Lyrics or EQ
// button in use fills white. Clicks play the shell's click sound.
Rectangle {
    id: root
    property string icon: ""
    property real iconSize: 15
    property bool active: false
    signal clicked()

    width: 40; height: 40; radius: 20
    color: active ? Qt.rgba(1, 1, 1, ma.containsMouse ? 0.95 : 0.88) : Qt.rgba(1, 1, 1, ma.pressed ? 0.3 : (ma.containsMouse ? 0.24 : 0.16))
    Behavior on color { ColorAnimation { duration: 150 } }
    scale: ma.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.family: ThemeBackend.iconFont
        font.pixelSize: root.iconSize
        color: root.active ? Qt.rgba(0.08, 0.09, 0.1, 1) : "white"
        Behavior on color { ColorAnimation { duration: 150 } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); root.clicked(); }
    }
}
