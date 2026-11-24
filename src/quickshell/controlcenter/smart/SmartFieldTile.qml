import QtQuick

// Smart Home Text Field Tile (optional right action pill button, used for Preset name, Time format, Shortcuts, Search).
Item {
    id: ft
    property string icon: "󰌌"
    property string title: "Field"
    property string text: ""
    property string placeholder: ""
    property string actionText: ""
    property real cornerRadius: 16
    property bool darkMode: true
    property bool liquidGlass: false
    property color surface: "#171a20"
    property color surfaceHover: "#222630"
    property color accent: "#a5c8ff"
    property color accent2: "#dabde2"
    property color inkAccent: "#0c0e13"
    property color textColor: "#edf1f8"
    property color subColor: "#8d96a8"
    property string uiFont: "Noto Sans"
    property string iconFont: "Symbols Nerd Font Mono"

    signal edited(string val)
    signal submitted(string val)

    width: parent ? parent.width : 460
    implicitHeight: 74
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Math.max(10, Math.min(20, ft.cornerRadius))
        color: ft.liquidGlass
            ? Qt.rgba(ft.surface.r, ft.surface.g, ft.surface.b, ft.darkMode ? 0.54 : 0.66)
            : ft.surface
        border.width: 1
        border.color: inp.activeFocus
            ? Qt.rgba(ft.accent.r, ft.accent.g, ft.accent.b, 0.52)
            : (ft.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06))
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    Row {
        anchors.left: parent.left; anchors.top: parent.top
        anchors.leftMargin: 13; anchors.topMargin: 9
        spacing: 7
        Text { text: ft.icon; font.family: ft.iconFont; font.pixelSize: 13; color: ft.accent; anchors.verticalCenter: parent.verticalCenter }
        Text { text: ft.title; font.family: ft.uiFont; font.pixelSize: 11; font.weight: Font.Medium; color: ft.textColor; anchors.verticalCenter: parent.verticalCenter }
    }

    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 9
        height: 30

        Rectangle {
            anchors.left: parent.left
            anchors.right: actBtn.visible ? actBtn.left : parent.right
            anchors.rightMargin: actBtn.visible ? 8 : 0
            height: 30; radius: 11
            color: ft.darkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.05)
            border.width: inp.activeFocus ? 1 : 0
            border.color: ft.accent

            TextInput {
                id: inp
                anchors.left: parent.left; anchors.right: parent.right
                anchors.leftMargin: 10; anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                text: ft.text
                font.family: ft.uiFont; font.pixelSize: 11; color: ft.textColor
                selectionColor: Qt.rgba(ft.accent.r, ft.accent.g, ft.accent.b, 0.35)
                onTextEdited: ft.edited(text)
                onAccepted: { ft.submitted(text); focus = false; }
                Keys.onEscapePressed: focus = false
            }
            Text {
                visible: inp.text === "" && !inp.activeFocus
                anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                text: ft.placeholder; font.family: ft.uiFont; font.pixelSize: 11; color: ft.subColor
            }
        }

        Rectangle {
            id: actBtn
            visible: ft.actionText !== ""
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            height: 30; width: actLbl.implicitWidth + 22; radius: 15
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: ft.accent }
                GradientStop { position: 1.0; color: ft.accent2 }
            }
            Text { id: actLbl; anchors.centerIn: parent; text: ft.actionText; font.family: ft.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold; color: ft.inkAccent }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { inp.focus = false; ft.submitted(inp.text); }
            }
        }
    }
}
