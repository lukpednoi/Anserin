import QtQuick
import "../../"
import "../../reusables"
import "."

// User page, style "Slide": only the essentials, on the same blurred wallpaper backdrop as Hero. Pick an action
// from the row of icons, then drag the knob to the end of the track to run it; let go early and it springs back.
Item {
    id: page
    required property PowerActions power
    property string uptimeText: ""
    property string screenName: ""
    property int chosen: Math.max(0, page.power.list.findIndex(a => !a.danger))   // a harmless one first
    readonly property var action: page.power.list[chosen]
    readonly property color tone: action.danger ? ThemeBackend.red : ThemeBackend.mauve

    WallBackdrop {
        id: frame
        anchors.fill: parent
        screenName: page.screenName

        // uptime, as on Hero
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 24; y: 32
            width: upRow.implicitWidth + 24; height: 30; radius: height / 2
            color: Qt.alpha(ThemeBackend.base, 0.55)
            border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.12)
            Row {
                id: upRow
                anchors.centerIn: parent; spacing: 6
                Icon { text: "󰅐"; font.pixelSize: 12; color: ThemeBackend.mauve; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Up " + page.uptimeText; font.pixelSize: 12; font.bold: true }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 64
            spacing: 6
            transform: Translate { x: frame.px * 5; y: frame.py * 4 }
            Avatar { anchors.horizontalCenter: parent.horizontalCenter; width: 92; height: 92; ring: 3 }
            Item { width: 1; height: 10 }
            Label { anchors.horizontalCenter: parent.horizontalCenter; text: SystemInfo.username; font.pixelSize: 30; font.bold: true }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 36
            width: parent.width - 64
            spacing: 18

            // which action the slider confirms
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Repeater {
                    model: page.power.list
                    Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool on: page.chosen === index
                        width: 46; height: 46; radius: 14
                        color: on ? Qt.alpha(page.tone, 0.24) : (ma.containsMouse ? Qt.alpha(ThemeBackend.base, 0.6) : Qt.alpha(ThemeBackend.base, 0.35))
                        border.width: on ? 1 : 0; border.color: Qt.alpha(page.tone, 0.6)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Icon { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 18
                               color: on ? page.tone : ThemeBackend.subtext0 }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { Sounds.playSfx("system/quick_click.wav"); page.chosen = index; knob.x = knob.minX; } }
                    }
                }
            }

            // slide to confirm
            Rectangle {
                id: track
                width: parent.width
                height: 60
                radius: height / 2
                color: Qt.alpha(ThemeBackend.base, 0.55)
                border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.12)
                readonly property real progress: Math.max(0, Math.min(1, (knob.x - knob.minX) / Math.max(1, knob.maxX - knob.minX)))

                Rectangle {
                    x: 4; y: 4
                    height: parent.height - 8
                    width: knob.x + knob.width - 4
                    radius: height / 2
                    color: Qt.alpha(page.tone, 0.18 + 0.2 * track.progress)
                }
                Label {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 20
                    text: page.action.name
                    font.pixelSize: 14; font.bold: true
                    color: ThemeBackend.subtext0
                    opacity: 1 - track.progress * 1.6
                }
                Rectangle {
                    id: knob
                    readonly property real minX: 4
                    readonly property real maxX: track.width - width - 4
                    x: minX; y: 4
                    width: parent.height - 8; height: width; radius: width / 2
                    color: page.tone
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Icon { anchors.centerIn: parent; text: page.action.icon; font.pixelSize: 20; color: ThemeBackend.crust }
                    NumberAnimation { id: springBack; target: knob; property: "x"; to: knob.minX; duration: 420; easing.type: Easing.OutBack }
                }
                MouseArea {
                    anchors.fill: knob
                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: knob
                    drag.axis: Drag.XAxis
                    drag.minimumX: knob.minX
                    drag.maximumX: knob.maxX
                    property int chargeSound: -1      // the hold sound (FillButton's charge loop) while the knob is held
                    function stopCharge() { if (chargeSound !== -1) { Sounds.stopSfx(chargeSound); chargeSound = -1; } }
                    Component.onDestruction: stopCharge()
                    onCanceled: { stopCharge(); springBack.restart(); }
                    onPressed: {
                        springBack.stop();
                        stopCharge();
                        chargeSound = Sounds.playUntilStopped("reusables/fillbutton/charge_loop.wav", 0.6, false);
                    }
                    onReleased: {
                        stopCharge();
                        if (knob.x >= knob.maxX - 2) { Sounds.playSfx("reusables/fillbutton/button.wav"); page.power.run(page.action.id); }
                        springBack.restart();
                    }
                }
            }
        }
    }
}
