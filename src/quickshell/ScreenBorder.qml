import QtQuick
import Quickshell
import Quickshell.Wayland
import "reusables"

Variants {
    model: ScreenEdges.modern ? Quickshell.screens : []

    Scope {
        id: scope
        required property var modelData
        readonly property int inset: ScreenEdges.inset(modelData)

        Variants {
            model: ["top", "right", "bottom", "left"]
            PanelWindow {
                required property string modelData
                screen: scope.modelData
                visible: scope.inset > 0
                WlrLayershell.namespace: "anserin-border-exclusion-" + modelData
                WlrLayershell.layer: WlrLayer.Top
                exclusiveZone: ScreenEdges.reserved(screen, modelData)
                anchors.top: modelData === "top"
                anchors.right: modelData === "right"
                anchors.bottom: modelData === "bottom"
                anchors.left: modelData === "left"
                implicitWidth: 1
                implicitHeight: 1
                color: "transparent"
                mask: Region {}
            }
        }

        PanelWindow {
            id: window
            screen: scope.modelData
            visible: scope.inset > 0
            WlrLayershell.namespace: "anserin-screen-border"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true; bottom: true; left: true }
            color: "transparent"
            mask: Region {
                Region { item: barTrigger.visible ? barTrigger : null }
                Region { item: dockTrigger.visible ? dockTrigger : null }
            }

            ScreenEdgeTrigger { id: barTrigger; target: LauncherController.bars[window.screen.name] || null }
            ScreenEdgeTrigger { id: dockTrigger; target: ScreenEdges.docks[window.screen.name] || null }

            ScreenFrame {
                anchors.fill: parent
                inset: scope.inset
            }
        }
    }
}
