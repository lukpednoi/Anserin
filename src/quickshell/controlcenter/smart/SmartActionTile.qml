import QtQuick

// Smart Home Action Tile with bouncy spring pop and subtle top-left -> bottom-right hover sheen.
Item {
    id: act
    property string icon: "󰉋"
    property string title: "Action"
    property string actionText: "Open"
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
    property bool interactive: true      // false: a read-only fact (no hover, press or click), the pill holds the value

    signal triggered()

    implicitHeight: 54
    height: implicitHeight

    SpringVal { id: scSp; target: !act.interactive ? 1.0 : (ma.pressed ? 0.96 : (hov.hovered ? 1.015 : 1.0)); stiffness: 540; damping: 0.44; eps: 0.001 }
    scale: scSp.value

    Rectangle {
        anchors.fill: parent
        radius: Math.max(10, Math.min(20, act.cornerRadius))
        color: act.liquidGlass
            ? Qt.rgba(hov.hovered ? act.surfaceHover.r : act.surface.r,
                      hov.hovered ? act.surfaceHover.g : act.surface.g,
                      hov.hovered ? act.surfaceHover.b : act.surface.b, act.darkMode ? 0.56 : 0.68)
            : (hov.hovered ? act.surfaceHover : act.surface)
        border.width: 1
        border.color: hov.hovered
            ? Qt.rgba(act.accent.r, act.accent.g, act.accent.b, 0.34)
            : (act.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06))
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 160 } }
    }

    Row {
        anchors.left: parent.left; anchors.leftMargin: 13
        anchors.right: pillBtn.left; anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Rectangle {
            width: 30; height: 30; radius: 15
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(act.accent.r, act.accent.g, act.accent.b, 0.14)
            Text {
                anchors.centerIn: parent; text: act.icon
                font.family: act.iconFont; font.pixelSize: 14; color: act.accent
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40; elide: Text.ElideRight
            text: act.title; font.family: act.uiFont; font.pixelSize: 12; font.weight: Font.Medium; color: act.textColor
        }
    }

    Rectangle {
        id: pillBtn
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        height: 28; width: pTxt.implicitWidth + 22; radius: 14
        color: Qt.rgba(act.accent.r, act.accent.g, act.accent.b, hov.hovered ? 0.28 : 0.16)
        border.width: 1
        border.color: Qt.rgba(act.accent.r, act.accent.g, act.accent.b, 0.36)
        Behavior on color { ColorAnimation { duration: 150 } }
        Text {
            id: pTxt; anchors.centerIn: parent; text: act.actionText
            font.family: act.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold; color: act.accent
        }
    }

    HoverHandler { id: hov; enabled: act.interactive }
    MouseArea {
        id: ma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: act.interactive
        onClicked: { scSp.kick(0.75); act.triggered(); }
    }
}
