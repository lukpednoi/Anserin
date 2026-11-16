import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../../"

Item {
    id: root
    implicitWidth: mainRow.implicitWidth + horizontalPadding * 2
    implicitHeight: 32

    property int horizontalPadding: 10
    property int cornerRadius: 16

    property string buttonText: ""
    property string buttonIcon: ""
    property int iconFontSize: 15
    property int textFontSize: 12

    property bool checked: false
    property color accentColor: "#89b4fa"
    property color baseColor: "#313244"
    property color handleColor: "#11111b"
    property color handleOffColor: "#cdd6f4"
    property color textColor: "#cdd6f4"

    property bool action_highlight: false
    property string toggleSound: "reusables/toggle/sfx.wav"

    signal toggled(bool checked)
    signal clicked()
    signal triggered()

    property real flashOpacity: 0.0
    property real popScale: 1.0

    // True when this control sits inside the Control Center's Control tab (its settings host sets ctlControls).
    property bool ctlStyle: false
    Component.onCompleted: { let p = root.parent; while (p) { if (p.ctlControls === true) { root.ctlStyle = true; break; } p = p.parent; } }

    property bool isHoveredOrHighlighted: (btnMa.containsMouse || root.action_highlight) && root.enabled

    RowLayout {
        id: mainRow
        layoutDirection: I18n.layoutDirection
        anchors.centerIn: parent
        spacing: 10

        Text {
            id: iconLabel
            visible: root.buttonIcon !== ""
            text: root.buttonIcon
            font.family: "Iosevka Nerd Font"
            font.pixelSize: root.iconFontSize
            color: root.textColor
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            id: mainLabel
            visible: root.buttonText !== ""
            text: root.buttonText
            font.family: "JetBrains Mono"
            font.weight: Font.Bold
            font.pixelSize: root.textFontSize
            color: root.textColor
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            id: track
            implicitWidth: 44
            implicitHeight: 24
            radius: height / 2
            color: trackGlass.active ? "transparent" : (root.checked ? root.accentColor : (root.isHoveredOrHighlighted ? Qt.lighter(root.baseColor, 1.2) : root.baseColor))
            GlassFill { id: trackGlass; anchors.fill: parent; radius: parent.radius; tintColor: root.checked ? root.accentColor : root.baseColor; tintAmount: 0.4 }
            opacity: root.enabled ? 1.0 : 0.5
            Layout.alignment: Qt.AlignVCenter

            Behavior on color { ColorAnimation { duration: 200 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            scale: (!root.enabled ? 1.0 : (btnMa.pressed ? 0.95 : (root.isHoveredOrHighlighted ? 1.04 : 1.0))) * root.popScale
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            Rectangle {
                id: handle
                width: parent.height - 6
                height: parent.height - 6
                radius: height / 2
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? parent.width - width - 3 : 3
                color: root.checked ? root.handleColor : root.handleOffColor

                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            Rectangle {
                id: ripple
                visible: root.ctlStyle
                width: 4; height: 4; radius: width / 2
                x: handle.x + handle.width / 2 - width / 2; y: parent.height / 2 - height / 2
                color: root.accentColor; opacity: 0
                ParallelAnimation {
                    id: rippleAnim
                    NumberAnimation { target: ripple; property: "width"; from: 6; to: track.height * 2.2; duration: 420; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ripple; property: "height"; from: 6; to: track.height * 2.2; duration: 420; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.45; to: 0; duration: 420 }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "#ffffff"
                opacity: root.flashOpacity
                PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
            }
        }
    }

    SequentialAnimation {
        id: btnPopAnim
        NumberAnimation { target: root; property: "popScale"; to: 1.05; duration: 100; easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
    }

    MouseArea {
        id: btnMa
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: {
            if (!root.enabled) return;
            root.checked = !root.checked;
            btnPopAnim.start();
            if (root.ctlStyle) rippleAnim.restart();
            root.flashOpacity = 0.2;
            btnFlashAnim.start();
            if (typeof Sounds !== "undefined") {
                Sounds.playSfx(root.toggleSound);
            }
            root.toggled(root.checked);
            root.clicked();
            root.triggered();
        }
    }
}
