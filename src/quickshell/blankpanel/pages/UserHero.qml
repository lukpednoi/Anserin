import QtQuick
import "../../"
import "../../reusables"
import "."

// User page, style "Hero": the blurred wallpaper backdrop, the name in large type, and one power button that
// fans the five actions out above it. Log out, Reboot and Shut down fill with water while held (the Network
// popup's hold to disconnect, same FluidWave) and run when full; Lock and Suspend run on a click.
Item {
    id: page
    required property PowerActions power
    property string uptimeText: ""
    property string screenName: ""
    property bool powerOpen: false
    property string hint: ""
    property bool hintDanger: false
    onVisibleChanged: if (!visible) { powerOpen = false; hint = ""; }

    WallBackdrop {
        id: frame
        anchors.fill: parent
        screenName: page.screenName

        Avatar {
            x: 28; y: 28
            width: 96; height: 96; ring: 3
            transform: Translate { x: frame.px * 6; y: frame.py * 4 }
        }
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
            x: 28
            anchors.bottom: parent.bottom; anchors.bottomMargin: 28
            width: parent.width - 56 - powerRow.width
            spacing: 2
            transform: Translate { x: frame.px * 4 }
            Label {
                text: page.hint !== "" ? page.hint : "Hello,"
                font.pixelSize: 16
                color: page.hint !== "" ? (page.hintDanger ? ThemeBackend.red : ThemeBackend.mauve) : ThemeBackend.subtext0
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            Label { width: parent.width; text: SystemInfo.username; font.pixelSize: 60; font.bold: true; elide: Text.ElideRight }
        }

        // the power button, and the actions that fly up out of it
        Item {
            id: powerRow
            anchors.right: parent.right; anchors.rightMargin: 24
            anchors.bottom: parent.bottom; anchors.bottomMargin: 32
            width: 60; height: 60

            Repeater {
                model: page.power.list
                Rectangle {
                    id: act
                    required property var modelData
                    required property int index
                    readonly property int order: page.power.list.length - index   // nearest the button first
                    readonly property bool danger: modelData.danger
                    readonly property bool hot: ma.containsMouse || fill > 0
                    property real fill: 0
                    property int chargeSound: -1      // the hold sound (FillButton's charge loop) while held
                    function stopCharge() { if (chargeSound !== -1) { Sounds.stopSfx(chargeSound); chargeSound = -1; } }
                    Component.onDestruction: stopCharge()
                    property real flash: 0
                    property real bump: 1
                    width: 50; height: 50; radius: width / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: page.powerOpen ? -order * 58 : 5
                    opacity: page.powerOpen ? 1 : 0
                    scale: (page.powerOpen ? (hot ? 1.1 : 1) : 0.4) * bump
                    enabled: page.powerOpen
                    color: hot ? (danger ? Qt.tint(ThemeBackend.surface1, Qt.alpha(ThemeBackend.red, 0.75)) : ThemeBackend.mauve) : Qt.alpha(ThemeBackend.base, 0.7)
                    border.width: 1; border.color: Qt.alpha(hot && danger ? ThemeBackend.red : ThemeBackend.text, hot && danger ? 0.6 : 0.14)
                    Behavior on y { NumberAnimation { duration: 380 + act.order * 40; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                    Behavior on opacity { NumberAnimation { duration: 200 + act.order * 40 } }
                    Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    FluidWave {
                        anchors.fill: parent
                        visible: act.fill > 0
                        opacity: 0.95
                        radius: width / 2
                        fillLevel: act.fill
                        waveAmp: act.fill < 0.99 ? 5 * Math.sin(act.fill * Math.PI) : 0
                        color1: ThemeBackend.surface2
                        color2: ThemeBackend.crust
                        NumberAnimation on phase { running: act.fill > 0 && act.fill < 1; loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: 800 }
                    }
                    Rectangle { anchors.fill: parent; radius: width / 2; color: "#ffffff"; opacity: act.flash }
                    Icon { anchors.centerIn: parent; text: modelData.icon; font.pixelSize: 19
                           color: act.hot && !act.danger ? ThemeBackend.crust : ThemeBackend.text }

                    NumberAnimation { id: fillAnim; target: act; property: "fill"; to: 1; duration: 800 * (1 - act.fill); easing.type: Easing.InSine
                        onFinished: {
                            act.stopCharge();
                            if (!ma.pressed) { act.fill = 0; return; }
                            flashAnim.restart(); bumpAnim.restart();
                            Sounds.playSfx("reusables/fillbutton/button.wav");
                            act.fill = 0;
                            page.hint = "";
                            runLater.restart();
                        } }
                    NumberAnimation { id: drainAnim; target: act; property: "fill"; to: 0; duration: 1500 * act.fill; easing.type: Easing.OutQuad }
                    SequentialAnimation { id: flashAnim
                        PropertyAction { target: act; property: "flash"; value: 0.6 }
                        NumberAnimation { target: act; property: "flash"; to: 0; duration: 500; easing.type: Easing.OutExpo } }
                    SequentialAnimation { id: bumpAnim
                        NumberAnimation { target: act; property: "bump"; to: 1.15; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: act; property: "bump"; to: 1; duration: 600; easing.type: Easing.OutQuint } }

                    // lets the flash show before the action runs
                    Timer { id: runLater; interval: 350; onTriggered: { page.powerOpen = false; page.power.run(act.modelData.id); } }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            const label = act.modelData.name;
                            if (containsMouse) { page.hint = label; page.hintDanger = act.danger; }
                            else if (page.hint === label) page.hint = "";
                        }
                        onPressed: if (act.danger) {
                            act.stopCharge();
                            act.chargeSound = Sounds.playUntilStopped("reusables/fillbutton/charge_loop.wav", 0.6, false);
                            drainAnim.stop(); fillAnim.restart();
                        }
                        onReleased: if (act.danger && fillAnim.running) { act.stopCharge(); fillAnim.stop(); drainAnim.restart(); }
                        onCanceled: if (act.danger) { act.stopCharge(); fillAnim.stop(); drainAnim.restart(); }
                        onClicked: if (!act.danger) { Sounds.playSfx("system/quick_click.wav"); page.powerOpen = false; page.hint = ""; page.power.run(act.modelData.id); }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: page.powerOpen ? ThemeBackend.surface1 : ThemeBackend.mauve
                scale: mainMa.pressed ? 0.92 : (mainMa.containsMouse ? 1.06 : 1)
                rotation: page.powerOpen ? 90 : 0
                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                Behavior on rotation { NumberAnimation { duration: 320; easing.type: Easing.OutBack } }
                Icon { anchors.centerIn: parent; text: page.powerOpen ? "󰅖" : "󰐥"; font.pixelSize: 24; color: page.powerOpen ? ThemeBackend.text : ThemeBackend.crust }
                MouseArea { id: mainMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Sounds.playSfx("system/quick_click.wav"); page.powerOpen = !page.powerOpen; page.hint = ""; } }
            }
        }
    }
}
