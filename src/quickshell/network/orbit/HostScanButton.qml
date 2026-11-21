import QtQuick
import "../../"
import "."

/**
 * Circular Computer / Host icon button without text label.
 * Hovering emits delicate expanding signal ripples; clicking triggers Sonar scan.
 */
Item {
    id: hostBtn

    property color accentColor: ThemeBackend.mauve
    property bool active: true
    property bool winVisible: true
    property int buttonSize: 44

    signal clicked()

    property real ripplePhase: 0
    readonly property bool hovered: ma.containsMouse

    implicitWidth: buttonSize
    implicitHeight: buttonSize

    NumberAnimation on ripplePhase {
        running: hostBtn.hovered && hostBtn.active && hostBtn.winVisible && hostBtn.visible
        from: 0.0
        to: 1.0
        duration: 1450
        loops: Animation.Infinite
        onRunningChanged: if (!running) hostBtn.ripplePhase = 0
    }

    // Subtle expanding signal ripples while hovered
    Repeater {
        model: 2
        Rectangle {
            required property int index
            readonly property real p: (hostBtn.ripplePhase + index * 0.5) % 1.0
            readonly property real easeP: 1.0 - Math.pow(1.0 - p, 2)

            anchors.centerIn: parent
            width: hostBtn.buttonSize + easeP * 28
            height: width
            radius: width / 2
            visible: hostBtn.hovered
            color: "transparent"
            border.width: 1.4
            border.color: Qt.alpha(hostBtn.accentColor, (1.0 - easeP) * 0.65)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: hostBtn.hovered ? Qt.alpha(hostBtn.accentColor, 0.24) : Qt.alpha(hostBtn.accentColor, 0.13)
        border.width: 1.5
        border.color: hostBtn.hovered ? hostBtn.accentColor : Qt.alpha(hostBtn.accentColor, 0.5)
        scale: ma.pressed ? 0.93 : (hostBtn.hovered ? 1.06 : 1.0)

        Behavior on color { ColorAnimation { duration: 170 } }
        Behavior on border.color { ColorAnimation { duration: 170 } }
        Behavior on scale { NumberAnimation { duration: 170; easing.type: Easing.OutBack } }

        // Slow gentle breathing halo when idle
        SequentialAnimation on opacity {
            running: hostBtn.active && hostBtn.winVisible && hostBtn.visible && !hostBtn.hovered
            loops: Animation.Infinite
            NumberAnimation { to: 0.72; duration: 3100; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 3100; easing.type: Easing.InOutSine }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "󰌢"
        font.family: ThemeBackend.iconFont
        font.pixelSize: Math.round(hostBtn.buttonSize * 0.44)
        color: hostBtn.accentColor
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: hostBtn.clicked()
    }
}
