import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"

// Anserin interface fallback: standalone edge hover PanelWindow ONLY when ScreenEdges.modern is disabled
// (when ScreenEdges.modern is true, ScreenBorder hosts both left & right edge triggers with zero extra GL contexts).
Variants {
    id: root
    property string edge: "right"
    signal triggered(string screenName)
    model: ScreenEdges.modern ? [] : Quickshell.screens

    PanelWindow {
        required property var modelData
        screen: modelData
        WlrLayershell.namespace: root.edge === "right" ? "anserin-edge-battery" : "anserin-edge-" + root.edge
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Ignore
        anchors.right: root.edge === "right"
        anchors.left: root.edge === "left"
        implicitWidth: 2
        implicitHeight: Math.max(160, Math.round(modelData.height * 0.3))
        color: "transparent"

        HoverHandler { id: hover }
        Timer {
            interval: 150
            running: hover.hovered
            onTriggered: root.triggered(modelData.name)
        }
    }
}
