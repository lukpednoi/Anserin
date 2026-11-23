import QtQuick

// Smart Home Numeric Stepper Tile ([ − ]   value   [ + ]) — centered numeral, zero overlap!
Item {
    id: stp
    property string icon: "󰔛"
    property string title: "Value"
    property real value: 15
    property real from: 0
    property real to: 100
    property real step: 1
    property string suffix: ""
    property real cornerRadius: 16
    property bool darkMode: true
    property bool liquidGlass: false
    property color surface: "#171a20"
    property color surfaceHover: "#222630"
    property color accent: "#a5c8ff"
    property color textColor: "#e8ecf2"
    property color subColor: "#9aa2b0"
    property string uiFont: "Noto Sans"
    property string iconFont: "Symbols Nerd Font Mono"

    property string valueText: Math.round(stp.value) + stp.suffix
    signal changed(real v)

    implicitWidth: 200
    width: (parent && parent.columns === undefined) ? parent.width : implicitWidth
    implicitHeight: 82
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Math.max(10, Math.min(20, stp.cornerRadius))
        color: stp.liquidGlass
            ? Qt.rgba(stp.surface.r, stp.surface.g, stp.surface.b, stp.darkMode ? 0.54 : 0.66)
            : stp.surface
        border.width: 1
        border.color: stp.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)
    }

    Row {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 10
        spacing: 7
        Text { anchors.verticalCenter: parent.verticalCenter; text: stp.icon; font.family: stp.iconFont; font.pixelSize: 13; color: stp.accent }
        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 22; elide: Text.ElideRight; text: stp.title; font.family: stp.uiFont; font.pixelSize: 12; font.weight: Font.Medium; color: stp.textColor }
    }

    component StepBtn: Item {
        id: sb
        property string glyph: "−"
        property bool canClick: true
        signal hit()
        SpringVal { id: bSc; target: bMa.pressed ? 0.86 : (bHov.hovered ? 1.07 : 1.0); stiffness: 560; damping: 0.42; eps: 0.001 }
        width: 32; height: 28; scale: bSc.value; opacity: canClick ? 1.0 : 0.32
        Rectangle {
            anchors.fill: parent; radius: 14
            color: bHov.hovered ? stp.surfaceHover : (stp.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07))
            border.width: 1; border.color: stp.darkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.09)
        }
        Text { anchors.centerIn: parent; text: sb.glyph; font.family: stp.uiFont; font.pixelSize: 15; font.bold: true; color: stp.textColor }
        HoverHandler { id: bHov }
        MouseArea {
            id: bMa; anchors.fill: parent; enabled: sb.canClick; cursorShape: Qt.PointingHandCursor
            onClicked: { bSc.kick(0.9); sb.hit(); }
        }
    }

    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 10
        height: 28

        StepBtn {
            id: minusBtn
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            glyph: "−"
            canClick: stp.value > stp.from
            onHit: stp.changed(Math.max(stp.from, stp.value - stp.step))
        }

        Text {
            anchors.left: minusBtn.right; anchors.right: plusBtn.left
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: stp.valueText
            font.family: stp.uiFont; font.pixelSize: 14; font.weight: Font.Medium
            color: stp.accent
        }

        StepBtn {
            id: plusBtn
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            glyph: "+"
            canClick: stp.value < stp.to
            onHit: stp.changed(Math.min(stp.to, stp.value + stp.step))
        }
    }
}
