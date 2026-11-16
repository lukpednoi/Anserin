import QtQuick
import "../../"
import "../../reusables"

// Segmented choice with a capsule that glides to the chosen option.
Rectangle {
    id: g
    property var options: []
    property int current: 0
    property color accent: ThemeBackend.mauve
    signal picked(int index)
    implicitHeight: 30
    implicitWidth: Math.max(120, options.length * 76)
    radius: height / 2
    color: (tileGlass1.active ? "transparent" : ThemeBackend.surface0)
    GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }

    Rectangle {
        visible: g.options.length > 0 && g.current >= 0
        x: 3 + Math.max(0, g.current) * (g.width - 6) / Math.max(1, g.options.length)
        y: 3; width: (g.width - 6) / Math.max(1, g.options.length); height: g.height - 6
        radius: height / 2; color: g.accent
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.7 } }
    }
    Row {
        anchors.fill: parent; anchors.margins: 3
        Repeater {
            model: g.options
            Item {
                width: (g.width - 6) / Math.max(1, g.options.length); height: g.height - 6
                Text {
                    anchors.centerIn: parent; text: modelData
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold
                    color: index === g.current ? ThemeBackend.crust : ThemeBackend.subtext0
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (index !== g.current) Sounds.playSfx("reusables/switch/sfx.wav"); g.picked(index); } }
            }
        }
    }
}
