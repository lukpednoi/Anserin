import QtQuick
import "../../"

// A connected row of buttons. Pressing one makes it grow while its neighbours give way, then the row settles
// with a small wobble (ExBump). model: [{ icon, text }], `current` is the chosen one (or -1 for plain buttons).
Item {
    id: root
    property var model: []
    property int current: -1
    property string size: "s"
    property bool selectable: true
    signal activated(int index)
    function s(v) { return Scaler.s(v); }
    implicitHeight: row.implicitHeight
    implicitWidth: row.implicitWidth
    ExBump { id: bump; px: root.s(9) }
    Row {
        id: row
        spacing: root.s(3)
        Repeater {
            model: root.model
            ExButton {
                required property var modelData
                required property int index
                icon: modelData.icon || ""
                text: modelData.text || ""
                size: root.size
                variant: "tonal"
                selected: root.selectable && index === root.current
                extraWidth: bump.dw(index, root.model.length)
                onPressedChanged: if (pressed) bump.bump(index)
                onClicked: { if (root.selectable) root.current = index; root.activated(index); }
            }
        }
    }
}
