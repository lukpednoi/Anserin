import QtQuick
import "../"

// The sidebar face of a module that has no bar module of its own (System, User): its icon.
Item {
    id: root
    property var module: null
    property string glyph: ""
    implicitWidth: parent ? parent.width : Scaler.s(40)
    implicitHeight: Scaler.s(44)
    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: ThemeBackend.iconFont
        font.pixelSize: Scaler.s(17)
        color: ThemeBackend.subtext0
    }
}
