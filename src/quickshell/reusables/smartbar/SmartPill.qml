import QtQuick
import "../../"

// A pill button of the Smart bar: faint until hovered; the one in use fills with the theme's main colour.
Rectangle {
    id: pill
    property string label: ""
    property bool active: false
    signal clicked()

    function s(v) { return Scaler.s(v); }

    implicitWidth: text.implicitWidth + s(16)
    implicitHeight: s(24)
    radius: height / 2
    opacity: enabled ? 1 : 0.4
    color: active ? Qt.alpha(ThemeBackend.mauve, 0.30)
         : ma.containsMouse ? Qt.alpha(ThemeBackend.text, 0.11) : Qt.alpha(ThemeBackend.text, 0.04)
    border.width: 1
    border.color: active ? Qt.alpha(ThemeBackend.mauve, 0.75) : Qt.alpha(ThemeBackend.text, 0.12)
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Text {
        id: text
        anchors.centerIn: parent
        text: pill.label
        font.family: ThemeBackend.fontFamily
        font.pixelSize: pill.s(11)
        font.bold: pill.active
        color: pill.active ? ThemeBackend.text : Qt.alpha(ThemeBackend.text, 0.78)
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Sounds.playSfx("reusables/clickbutton/click.wav", 0.4);
            pill.clicked();
        }
    }
}
