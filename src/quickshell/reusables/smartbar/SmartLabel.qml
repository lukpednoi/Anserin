import QtQuick
import "../../"

// A small name in front of a group of pills on the Smart bar ("Look", "Cover"...), or a short note.
Text {
    property bool strong: false
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    font.family: ThemeBackend.fontFamily
    font.pixelSize: Scaler.s(strong ? 12 : 10.5)
    font.bold: strong
    color: strong ? ThemeBackend.text : Qt.alpha(ThemeBackend.text, 0.55)
}
