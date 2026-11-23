import QtQuick

// Smart Home Choice Tile (single-select or multi-select chips with top-left -> bottom-right gradient on active!)
Item {
    id: ct
    property string icon: "󰏘"
    property string title: "Mode"
    property var options: []
    property int currentIndex: 0
    property bool multi: false
    property var selectedList: []
    property real cornerRadius: 16
    property bool darkMode: true
    property bool liquidGlass: false
    property color surface: "#171a20"
    property color surfaceHover: "#222630"
    property color accent: "#a5c8ff"
    property color accent2: "#dabde2"
    property color inkAccent: "#0c0e13"
    property color textColor: "#e8ecf2"
    property color subColor: "#9aa2b0"
    property string uiFont: "Noto Sans"
    property string iconFont: "Symbols Nerd Font Mono"

    signal picked(int index)
    signal multiToggled(string label)

    implicitWidth: 200
    width: (parent && parent.columns === undefined) ? parent.width : implicitWidth
    implicitHeight: 40 + chipFlow.implicitHeight + 12
    height: implicitHeight

    function isSelected(idx, label) {
        if (multi) return selectedList && selectedList.indexOf(label) >= 0;
        return idx === currentIndex;
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.max(10, Math.min(20, ct.cornerRadius))
        color: ct.liquidGlass
            ? Qt.rgba(ct.surface.r, ct.surface.g, ct.surface.b, ct.darkMode ? 0.54 : 0.66)
            : ct.surface
        border.width: 1
        border.color: ct.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)
    }

    Row {
        anchors.left: parent.left; anchors.top: parent.top
        anchors.leftMargin: 13; anchors.topMargin: 10
        spacing: 8
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ct.icon
            font.family: ct.iconFont
            font.pixelSize: 14
            color: ct.accent
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ct.title
            font.family: ct.uiFont
            font.pixelSize: 12
            font.weight: Font.Medium
            color: ct.textColor
        }
    }

    Flow {
        id: chipFlow
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 38
        spacing: 6

        Repeater {
            model: ct.options
            Item {
                id: chip
                required property var modelData
                required property int index
                readonly property string lab: String(modelData)
                readonly property bool on: ct.isSelected(index, lab)

                SpringVal { id: scSp; target: chipMa.pressed ? 0.92 : (chipHov.hovered ? 1.04 : 1.0); stiffness: 540; damping: 0.44; eps: 0.001 }
                width: Math.min(chipFlow.width, cLab.implicitWidth + 24)
                height: 30
                scale: scSp.value

                Rectangle {
                    anchors.fill: parent
                    radius: 15
                    color: chip.on
                        ? "transparent"
                        : (chipHov.hovered
                           ? ct.surfaceHover
                           : (ct.darkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.05)))
                    border.width: chip.on ? 0 : 1
                    border.color: ct.darkMode ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.08)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: 15
                        visible: chip.on
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: ct.accent }
                            GradientStop { position: 1.0; color: ct.accent2 }
                        }
                    }
                }

                Text {
                    id: cLab
                    anchors.centerIn: parent
                    text: chip.lab
                    font.family: ct.uiFont
                    font.pixelSize: 11
                    font.weight: chip.on ? Font.DemiBold : Font.Normal
                    color: chip.on ? ct.inkAccent : ct.textColor
                }

                HoverHandler { id: chipHov }
                MouseArea {
                    id: chipMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        scSp.kick(0.75);
                        if (ct.multi) ct.multiToggled(chip.lab);
                        else ct.picked(chip.index);
                    }
                }
            }
        }
    }
}
