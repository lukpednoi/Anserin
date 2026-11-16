import QtQuick
import QtQuick.Window
import "../../../reusables"
import "../../../"

// The Timer, Stopwatch and Pomodoro on the desktop: the same Timer as Quick Actions and the left panel
// (quickactions/actions/Timer.qml on TimerState), so all of them show the same time. A click arms the widget for
// the keyboard (Enter starts/pauses, arrows set the time); Escape, the desktop menu or clicking elsewhere disarms it.
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 200
    property real minHeight: 170
    property real maxWidth: 800
    property real maxHeight: 700
    property real minAspect: 0.8
    property real maxAspect: 2.2
    property bool isRound: false

    property bool previewMode: false
    property bool armed: false
    property bool gotFocus: false
    readonly property bool menuOpen: DesktopMenuController.isVisible
    readonly property bool wantsKeyboardFocus: !previewMode && ((armed && !menuOpen) || (timer.item !== null && timer.item.isEditingTime === true))

    onMenuOpenChanged: if (menuOpen) { armed = false; gotFocus = false; }

    Connections {
        target: root.Window.window
        ignoreUnknownSignals: true
        function onActiveChanged() {
            if (root.Window.active) root.gotFocus = true;
            else if (root.gotFocus) { root.gotFocus = false; root.armed = false; }
        }
    }

    Shortcut {
        enabled: !root.previewMode && root.Window.active && !(timer.item !== null && timer.item.isEditingTime === true)
        sequence: "Escape"
        onActivated: root.armed = false
    }

    readonly property real baseW: Scaler.s(380)
    readonly property real baseH: Scaler.s(330)

    Loader {
        id: timer
        // what Timer.qml reads from its host
        property var scaleFunc: v => Scaler.s(v)
        property string activeEdge: "left"
        property bool isCurrentTarget: !root.previewMode && root.Window.active
        width: root.baseW
        height: root.baseH
        transformOrigin: Item.TopLeft
        scale: Math.min(root.width / root.baseW, root.height / root.baseH)
        x: (root.width - width * scale) / 2
        y: (root.height - height * scale) / 2
        enabled: !root.previewMode
        source: "../../../quickactions/actions/Timer.qml"
    }

    MouseArea {
        anchors.fill: parent
        z: 100
        enabled: !root.previewMode
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            if (!root.menuOpen) root.armed = true;
            mouse.accepted = false;
        }
    }
}
