import QtQuick
import "../../../"

// Desktop Clock Widget variant: Flip (3D Split-Flap HH:MM:SS).
// RAM-Saver: 340 ms 3D hinge animation runs ONLY when a digit actually changes; zero idle FrameAnimation!
Item {
    id: root
    anchors.fill: parent
    clip: false

    property real minWidth: 160
    property real minHeight: 54
    property real maxWidth: 900
    property real maxHeight: 340
    property real minAspect: 2.3
    property real maxAspect: 3.8
    property bool isRound: false

    readonly property real designW: 318
    readonly property real designH: 104
    readonly property real fitScale: Math.min(width / designW, height / designH)

    readonly property string uiFont: ThemeBackend.fontFamily
    readonly property color cardColor: Qt.darker(ThemeBackend.surface0, 1.18)
    readonly property color textColor: "#ffffff"
    readonly property color secAccent: ThemeBackend.mauve

    function fmtPad(n) { return (n < 10 ? "0" : "") + n; }

    property string hhText: fmtPad(new Date().getHours())
    property string mmText: fmtPad(new Date().getMinutes())
    property string ssText: fmtPad(new Date().getSeconds())

    function syncNow() {
        const d = new Date();
        hhText = fmtPad(d.getHours());
        mmText = fmtPad(d.getMinutes());
        ssText = fmtPad(d.getSeconds());
    }

    Component.onCompleted: syncNow()

    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.syncNow()
    }

    component FlipCard: Item {
        id: fc
        property string value: "00"
        property color digitColor: "#ffffff"
        width: 98; height: 104

        property string prevValue: value
        property string nextValue: value
        property real topFoldAngle: 0.0
        property real botUnfoldAngle: 90.0
        property bool flipping: false

        onValueChanged: {
            if (value === nextValue) return;
            prevValue = nextValue;
            nextValue = value;
            flipAnim.restart();
        }

        SequentialAnimation {
            id: flipAnim
            PropertyAction { target: fc; property: "flipping"; value: true }
            PropertyAction { target: fc; property: "topFoldAngle"; value: 0.0 }
            PropertyAction { target: fc; property: "botUnfoldAngle"; value: 90.0 }
            NumberAnimation { target: fc; property: "topFoldAngle"; from: 0.0; to: -90.0; duration: 155; easing.type: Easing.InCubic }
            NumberAnimation { target: fc; property: "botUnfoldAngle"; from: 90.0; to: 0.0; duration: 185; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
            PropertyAction { target: fc; property: "prevValue"; value: fc.nextValue }
            PropertyAction { target: fc; property: "flipping"; value: false }
        }

        Rectangle {
            anchors.fill: parent; radius: 22
            color: root.cardColor
            border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.09)
        }

        // 1. Static top half (NEW value revealed underneath folding top flap)
        Item {
            x: 0; y: 0; width: parent.width; height: parent.height * 0.5; clip: true
            Rectangle {
                width: fc.width; height: fc.height; radius: 22
                color: Qt.lighter(root.cardColor, 1.06)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.09)
            }
            Text {
                width: fc.width; height: fc.height
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: fc.nextValue
                font.family: root.uiFont; font.pixelSize: 54; font.weight: Font.Black; font.letterSpacing: -1.5
                color: fc.digitColor
            }
        }

        // 2. Static bottom half (OLD value while top flap falls, then NEW value)
        Item {
            x: 0; y: parent.height * 0.5; width: parent.width; height: parent.height * 0.5; clip: true
            Rectangle {
                y: -fc.height * 0.5; width: fc.width; height: fc.height; radius: 22
                color: Qt.darker(root.cardColor, 1.05)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
            }
            Text {
                y: -fc.height * 0.5; width: fc.width; height: fc.height
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: fc.flipping ? fc.prevValue : fc.nextValue
                font.family: root.uiFont; font.pixelSize: 54; font.weight: Font.Black; font.letterSpacing: -1.5
                color: fc.digitColor
            }
        }

        // 3. Folding top flap (OLD value 0 -> -90 deg)
        Item {
            visible: fc.flipping && fc.topFoldAngle > -89.5
            x: 0; y: 0; width: parent.width; height: parent.height * 0.5; clip: true
            transform: Rotation {
                origin.x: fc.width * 0.5; origin.y: fc.height * 0.5
                axis { x: 1; y: 0; z: 0 }
                angle: fc.topFoldAngle
            }
            Rectangle {
                width: fc.width; height: fc.height; radius: 22
                color: Qt.lighter(root.cardColor, 1.06)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.09)
            }
            Text {
                width: fc.width; height: fc.height
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: fc.prevValue
                font.family: root.uiFont; font.pixelSize: 54; font.weight: Font.Black; font.letterSpacing: -1.5
                color: fc.digitColor
            }
            Rectangle {
                anchors.fill: parent; color: "#000000"
                opacity: Math.max(0, Math.min(0.45, -fc.topFoldAngle / 90.0 * 0.45))
            }
        }

        // 4. Unfolding bottom flap (NEW value 90 -> 0 deg)
        Item {
            visible: fc.flipping && fc.botUnfoldAngle < 89.5
            x: 0; y: parent.height * 0.5; width: parent.width; height: parent.height * 0.5; clip: true
            transform: Rotation {
                origin.x: fc.width * 0.5; origin.y: 0
                axis { x: 1; y: 0; z: 0 }
                angle: fc.botUnfoldAngle
            }
            Rectangle {
                y: -fc.height * 0.5; width: fc.width; height: fc.height; radius: 22
                color: Qt.darker(root.cardColor, 1.05)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
            }
            Text {
                y: -fc.height * 0.5; width: fc.width; height: fc.height
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                text: fc.nextValue
                font.family: root.uiFont; font.pixelSize: 54; font.weight: Font.Black; font.letterSpacing: -1.5
                color: fc.digitColor
            }
        }

        // 5. Signature split-flap center hinge line
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.right: parent.right
            height: 2.2; color: Qt.rgba(0.02, 0.03, 0.05, 0.72)
        }
        Rectangle {
            y: parent.height * 0.5 + 1.2
            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 3; anchors.rightMargin: 3
            height: 1; color: Qt.rgba(1, 1, 1, 0.05)
        }
    }

    Row {
        id: cardsRow
        width: root.designW
        height: root.designH
        anchors.centerIn: parent
        spacing: 12
        scale: root.fitScale
        transformOrigin: Item.Center

        FlipCard { value: root.hhText; digitColor: root.textColor }
        FlipCard { value: root.mmText; digitColor: root.textColor }
        FlipCard { value: root.ssText; digitColor: root.secAccent }
    }
}
