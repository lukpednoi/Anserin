import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

// Full-screen overlay that plays SwitchTransition on the screen where Mo chose Anserin.
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: window
        required property var modelData
        screen: modelData
        visible: AnserinMode.busy && AnserinMode.screenName === modelData.name
        WlrLayershell.namespace: "anserin-switch-transition"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true; bottom: true; left: true }
        color: "transparent"

        SwitchTransition {
            id: transition
            anchors.fill: parent
            onCovered: AnserinMode.commit()
            onFinished: AnserinMode.finish()
        }

        Connections {
            target: AnserinMode
            function onPlayRequested() {
                if (AnserinMode.screenName !== window.modelData.name) return;
                transition.play();
            }
        }
    }
}
