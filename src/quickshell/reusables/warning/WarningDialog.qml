import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../../"
import "../"

// The warning as a clean panel (Mo's reference): the screen behind blurred and dark, a dark rounded panel in the
// middle with the warning icon and "Warning!" in the theme's accent, a line, the message, and the buttons. It glides in
// (rises a little, fades and grows a touch, no overshoot) with its alert sound (assets/sounds/warning/alert.wav).
// A plain warning has Got it; a change that reshapes something also shows Before → After and has Cancel.
// show({ title, text, before, after }); `accepted` (Got it / Enter) or `cancelled` (Cancel / Esc on a change),
// then `closed` once it has gone. Nothing else closes it.
FocusScope {
    id: root
    property Item behind: null
    property bool sound: true
    property real shown: 0
    property real panelIn: 0
    property string title: "Warning!"
    property string text: ""
    property url before: ""
    property url after: ""
    readonly property bool isChange: before.toString() !== "" && after.toString() !== ""
    readonly property bool active: shown > 0.001 || openAnim.running
    readonly property real u: Math.max(0.7, height / 900)
    readonly property color accent: ThemeBackend.mauve
    signal accepted()
    signal cancelled()
    signal closed()

    function show(cfg) {
        title = cfg.title || "Warning!";
        text = cfg.text || "";
        before = cfg.before || "";
        after = cfg.after || "";
        closeAnim.stop();
        openAnim.restart();
        root.forceActiveFocus();
    }
    function finish(ok) {
        if (closeAnim.running || shown <= 0) return;
        Sounds.playSfx("reusables/clickbutton/click.wav");
        if (ok) accepted(); else cancelled();
        openAnim.stop();
        closeAnim.restart();
    }

    visible: active
    Keys.onReturnPressed: finish(true)
    Keys.onEnterPressed: finish(true)
    Keys.onEscapePressed: if (isChange) finish(false)

    MultiEffect {
        anchors.fill: parent
        visible: root.behind !== null
        source: root.behind
        blurEnabled: true
        blurMax: 48
        blur: root.shown
        autoPaddingEnabled: false
    }
    Rectangle { anchors.fill: parent; color: "black"; opacity: 0.55 * root.shown }
    MouseArea { anchors.fill: parent; hoverEnabled: true }

    Item {
        id: panel
        anchors.centerIn: parent
        width: (root.isChange ? 640 : 520) * root.u
        height: col.implicitHeight + 40 * root.u
        // rises a little, grows a touch and fades in, with no overshoot
        opacity: root.panelIn
        scale: 0.965 + 0.035 * root.panelIn
        transform: Translate { y: (1 - root.panelIn) * 18 * root.u }

        Rectangle {
            anchors.fill: parent
            radius: 22 * root.u
            color: Qt.alpha(ThemeBackend.base, 0.92)
            border.width: 1
            border.color: Qt.alpha(root.accent, 0.35)
        }

        Column {
            id: col
            x: 26 * root.u; y: 20 * root.u
            width: parent.width - 52 * root.u
            spacing: 14 * root.u

            Row {
                spacing: 12 * root.u
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰀦"
                    font.family: ThemeBackend.iconFont; font.pixelSize: 26 * root.u
                    color: root.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 22 * root.u; font.bold: true
                    color: root.accent
                }
            }
            Rectangle { width: parent.width; height: 1; color: Qt.alpha(ThemeBackend.text, 0.1) }

            // Before → After, centred
            Row {
                visible: root.isChange
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16 * root.u
                Repeater {
                    model: root.isChange ? [{ src: root.before, label: "Before" }, { src: root.after, label: "After" }] : []
                    Row {
                        id: pair
                        required property var modelData
                        required property int index
                        spacing: 16 * root.u
                        Text {
                            visible: pair.index === 1
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: -10 * root.u
                            text: "󰁔"
                            font.family: ThemeBackend.iconFont; font.pixelSize: 24 * root.u
                            color: root.accent
                        }
                        Column {
                            spacing: 6 * root.u
                            ClippingRectangle {
                                width: 250 * root.u; height: 156 * root.u
                                radius: 12 * root.u
                                color: Qt.darker(ThemeBackend.surface0, 1.04)
                                border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.08)
                                Image {
                                    anchors.fill: parent
                                    source: pair.modelData.src
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pair.modelData.label
                                font.family: ThemeBackend.fontFamily; font.pixelSize: 11 * root.u; font.bold: true
                                color: ThemeBackend.subtext0
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: root.text
                visible: text !== ""
                wrapMode: Text.WordWrap
                lineHeight: 1.3
                font.family: ThemeBackend.fontFamily; font.pixelSize: 14 * root.u
                color: ThemeBackend.text
            }

            Row {
                anchors.right: parent.right
                spacing: 10 * root.u
                ClickButton {
                    visible: root.isChange
                    height: 36 * root.u
                    cornerRadius: height / 2
                    horizontalPadding: 22 * root.u
                    buttonIcon: "󰅖"; buttonText: "Cancel"
                    textFontSize: 13 * root.u; iconFontSize: 14 * root.u
                    accentColor: Qt.alpha(ThemeBackend.surface1, 0.6)
                    textColor: ThemeBackend.text
                    onClicked: root.finish(false)
                }
                ClickButton {
                    height: 36 * root.u
                    cornerRadius: height / 2
                    horizontalPadding: 26 * root.u
                    buttonIcon: "󰄬"; buttonText: "Got it"
                    textFontSize: 13 * root.u; iconFontSize: 14 * root.u
                    accentColor: root.accent
                    textColor: ThemeBackend.crust
                    onClicked: root.finish(true)
                }
            }
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "shown"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 60 }
            NumberAnimation { target: root; property: "panelIn"; from: 0; to: 1; duration: 420; easing.type: Easing.OutQuint }
        }
        SequentialAnimation {
            PauseAnimation { duration: 120 }
            ScriptAction { script: if (root.sound) Sounds.playSfx("warning/alert.wav", 0.8) }
        }
    }
    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: root; property: "panelIn"; to: 0; duration: 200; easing.type: Easing.InQuad }
        NumberAnimation { target: root; property: "shown"; to: 0; duration: 260; easing.type: Easing.InOutQuad }
        onFinished: root.closed()
    }
}
