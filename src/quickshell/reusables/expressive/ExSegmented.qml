import QtQuick
import "../../"

// Segmented pill: a row of choices with one indicator that slides and stretches to the chosen one on a spatial
// spring (it reaches ahead with its leading edge, then the trailing edge catches up).
Item {
    id: root
    property var model: []                  // [{ icon, text }]
    property int current: 0
    signal activated(int index)
    function s(v) { return Scaler.s(v); }
    implicitHeight: s(40)
    implicitWidth: row.implicitWidth + s(8)
    Rectangle { anchors.fill: parent; radius: height / 2; color: ThemeBackend.surface0 }
    readonly property Item target: rep.count > root.current ? rep.itemAt(root.current) : null
    ExSpring { id: lead; token: "spatialFast"; eps: 0.1; target: root.target ? root.target.x + (root.target.width) : 0 }
    ExSpring { id: tail; token: "spatialDefault"; eps: 0.1; target: root.target ? root.target.x : 0 }
    Rectangle {
        readonly property real a: Math.min(lead.value, tail.value)
        readonly property real b: Math.max(lead.value, tail.value)
        x: row.x + Math.min(a, b - root.s(24)); y: root.s(4)
        width: Math.max(root.s(24), b - a); height: parent.height - root.s(8)
        radius: height / 2
        color: ThemeBackend.mauve
    }
    Row {
        id: row
        x: root.s(4); y: root.s(4)
        height: parent.height - root.s(8)
        Repeater {
            id: rep
            model: root.model
            Item {
                required property var modelData
                required property int index
                width: lbl.implicitWidth + root.s(28); height: row.height
                Row {
                    id: lbl
                    anchors.centerIn: parent
                    spacing: root.s(6)
                    Text {
                        visible: (modelData.icon || "") !== ""
                        text: modelData.icon || ""
                        font.family: ThemeBackend.iconFont; font.pixelSize: root.s(15)
                        color: index === root.current ? ThemeBackend.crust : ThemeBackend.subtext1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: modelData.text || ""
                        font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(13); font.weight: Font.DemiBold
                        color: index === root.current ? ThemeBackend.crust : ThemeBackend.subtext1
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); root.current = index; root.activated(index); }
                }
            }
        }
    }
}
