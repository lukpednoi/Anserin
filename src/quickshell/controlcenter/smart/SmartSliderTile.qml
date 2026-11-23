import QtQuick

// Smart Home Slider Tile wrapping SmartWaveSlider with crisp Smart Mirror tabular readout.
Item {
    id: st
    property string icon: "󰕾"
    property string title: "Level"
    property real value: 0.65            // 0..1
    property real step: 0.04
    property string valueText: Math.round(value * 100) + "%"
    property bool active: true
    property real cornerRadius: 16
    property bool darkMode: true
    property bool liquidGlass: false
    property color surface: "#171a20"
    property color accent: "#a5c8ff"
    property color accent2: "#dabde2"
    property color textColor: "#e8ecf2"
    property color subColor: "#9aa2b0"
    property string uiFont: "Noto Sans"
    property string iconFont: "Symbols Nerd Font Mono"

    signal moved(real v)
    signal stepped()
    signal lockedFull()
    signal released()

    width: parent ? parent.width : 460
    implicitHeight: 78
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Math.max(10, Math.min(20, st.cornerRadius))
        color: st.liquidGlass
            ? Qt.rgba(st.surface.r, st.surface.g, st.surface.b, st.darkMode ? 0.54 : 0.66)
            : st.surface
        border.width: 1
        border.color: slider.dragging
            ? Qt.rgba(st.accent.r, st.accent.g, st.accent.b, 0.42)
            : (st.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06))
        Behavior on border.color { ColorAnimation { duration: 160 } }
    }

    // Top metadata row
    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: 13; anchors.rightMargin: 13; anchors.topMargin: 10
        height: 22

        Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: st.icon
                font.family: st.iconFont
                font.pixelSize: 14
                color: st.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: st.title
                font.family: st.uiFont
                font.pixelSize: 12
                font.weight: Font.Medium
                color: st.textColor
            }
        }

        Text {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            text: st.valueText
            font.family: st.uiFont
            font.pixelSize: 13
            font.weight: Font.Light
            font.letterSpacing: 0.4
            color: st.accent
        }
    }

    SmartWaveSlider {
        id: slider
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 6; anchors.rightMargin: 6; anchors.bottomMargin: 6
        height: 36
        value: st.value
        step: st.step
        active: st.active
        accent: st.accent
        accent2: st.accent2
        trackColor: st.darkMode ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
        handleColor: st.darkMode ? "#ffffff" : "#141820"
        onMoved: (v) => st.moved(v)
        onStepped: st.stepped()
        onLockedFull: st.lockedFull()
        onReleased: st.released()
    }
}
