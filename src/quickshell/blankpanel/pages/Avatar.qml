import QtQuick
import Quickshell.Widgets
import "../../"

// The account picture Anserin uses elsewhere (SystemInfo.avatarPath), or the first letter of the user name.
Item {
    id: a
    property real ring: 3
    property color ringColor: ThemeBackend.mauve
    Rectangle { anchors.fill: parent; radius: width / 2; color: a.ringColor; visible: a.ring > 0 }
    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: a.ring > 0 ? a.ring + 2 : 0
        radius: width / 2
        color: ThemeBackend.surface1
        Image {
            id: img
            anchors.fill: parent
            source: SystemInfo.avatarPath !== "" ? "file://" + SystemInfo.avatarPath : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: width * 2
            sourceSize.height: height * 2
        }
        Text {
            anchors.centerIn: parent
            visible: img.status !== Image.Ready
            text: SystemInfo.username.charAt(0).toUpperCase()
            font.family: ThemeBackend.fontFamily
            font.pixelSize: parent.height * 0.42
            font.bold: true
            color: ThemeBackend.mauve
        }
    }
}
