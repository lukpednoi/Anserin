import QtQuick
import QtQuick.Shapes
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

            readonly property real rounding: Math.max(0, Math.min(ScreenEdges.rounding, (width - scope.inset * 2) / 2, (height - scope.inset * 2) / 2))

            ScreenEdgeTrigger { id: barTrigger; target: LauncherController.bars[window.screen.name] || null }
            ScreenEdgeTrigger { id: dockTrigger; target: ScreenEdges.docks[window.screen.name] || null }

            WallpaperBlur {
                id: glass
                anchors.fill: parent
                radius: window.rounding
                inverted: true
                boxRect: Qt.rect(scope.inset, scope.inset, width - scope.inset * 2, height - scope.inset * 2)
                bezelSize: scope.inset
            }

            Shape {
                anchors.fill: parent
                visible: !glass.active
                ShapePath {
                    fillColor: ThemeBackend.base
                    strokeWidth: -1
                    fillRule: ShapePath.OddEvenFill
                    startX: 0; startY: 0
                    PathLine { x: window.width; y: 0 }
                    PathLine { x: window.width; y: window.height }
                    PathLine { x: 0; y: window.height }
                    PathLine { x: 0; y: 0 }
                    PathMove { x: scope.inset + window.rounding; y: scope.inset }
                    PathLine { x: window.width - scope.inset - window.rounding; y: scope.inset }
                    PathArc { x: window.width - scope.inset; y: scope.inset + window.rounding; radiusX: window.rounding; radiusY: window.rounding }
                    PathLine { x: window.width - scope.inset; y: window.height - scope.inset - window.rounding }
                    PathArc { x: window.width - scope.inset - window.rounding; y: window.height - scope.inset; radiusX: window.rounding; radiusY: window.rounding }
                    PathLine { x: scope.inset + window.rounding; y: window.height - scope.inset }
                    PathArc { x: scope.inset; y: window.height - scope.inset - window.rounding; radiusX: window.rounding; radiusY: window.rounding }
                    PathLine { x: scope.inset; y: scope.inset + window.rounding }
                    PathArc { x: scope.inset + window.rounding; y: scope.inset; radiusX: window.rounding; radiusY: window.rounding }
                }
            }
        }
    }
}
