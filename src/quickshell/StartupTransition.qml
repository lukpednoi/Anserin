import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property real darkness: 0
    property int readyScreens: 0

    function finish() {
        fadeIn.stop();
        fadeOut.start();
        exitTimer.start();
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            property bool counted: false
            screen: modelData
            color: "transparent"
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "anserin-startup-transition"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            onBackingWindowVisibleChanged: {
                if (backingWindowVisible && !counted) {
                    counted = true;
                    root.readyScreens++;
                    if (root.readyScreens === Quickshell.screens.length) fadeIn.start();
                }
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: root.darkness
                MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
            }
        }
    }

    NumberAnimation {
        id: fadeIn
        target: root
        property: "darkness"
        to: 1
        duration: 400
        easing.type: Easing.InOutQuad
        onFinished: console.log("ANSERIN_STARTUP_BLACK")
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "darkness"
        to: 0
        duration: 400
        easing.type: Easing.InOutQuad
        onFinished: Qt.quit()
    }

    IpcHandler {
        target: "startup-transition"
        function finish(): void { root.finish(); }
    }

    // A lock can hide the overlay and stop frame callbacks; its process must still exit.
    Timer { id: exitTimer; interval: 450; onTriggered: Qt.quit() }
    Timer { interval: 30000; running: true; onTriggered: root.finish() }
}
