import QtQuick

// Smart Home Room / Section Card:
// Clean hairline header (Smart Mirror + Home Dashboard inspired) with subtle live telemetry pill.
Item {
    id: card
    property string title: "Section"
    property string icon: "󰒓"
    property string statusText: ""
    property real cornerRadius: 18
    property bool darkMode: true
    property bool liquidGlass: false
    property color surface: "#12151b"
    property color accent: "#a5c8ff"
    property color textColor: "#e8ecf2"
    property color subColor: "#8f98a6"
    property string uiFont: "Noto Sans"
    property string iconFont: "Symbols Nerd Font Mono"
    default property alias content: bodyCol.data

    width: parent ? parent.width : 480
    implicitHeight: headerRow.height + 1 + bodyCol.implicitHeight + 22
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Math.max(12, Math.min(24, card.cornerRadius))
        color: card.liquidGlass
            ? Qt.rgba(card.surface.r, card.surface.g, card.surface.b, card.darkMode ? 0.44 : 0.58)
            : card.surface
        border.width: 1
        border.color: card.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
    }

    // Header bar
    Item {
        id: headerRow
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 38

        Row {
            anchors.left: parent.left; anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.icon
                font.family: card.iconFont
                font.pixelSize: 13
                color: card.accent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.title.toUpperCase()
                font.family: card.uiFont
                font.pixelSize: 10
                font.weight: Font.Medium
                font.letterSpacing: 1.25
                color: card.subColor
            }
        }

        // Optional right telemetry pill (e.g. "1920×1080 · 60Hz" or "2 ACTIVE")
        Text {
            visible: card.statusText !== ""
            anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            text: card.statusText
            font.family: card.uiFont
            font.pixelSize: 10
            font.weight: Font.Light
            font.letterSpacing: 0.4
            color: Qt.rgba(card.accent.r, card.accent.g, card.accent.b, 0.88)
        }
    }

    // Crisp Smart Mirror hairline divider
    Rectangle {
        id: hairline
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 14; anchors.rightMargin: 14
        anchors.top: headerRow.bottom
        height: 1
        color: card.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)
    }

    Column {
        id: bodyCol
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: hairline.bottom
        anchors.margins: 10
        anchors.topMargin: 11
        spacing: 9
    }
}
