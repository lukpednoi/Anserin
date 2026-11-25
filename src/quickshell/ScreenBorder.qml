import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "reusables"

Scope {
    id: borderRoot
    signal leftEdgeTriggered(string screenName)
    signal rightEdgeTriggered(string screenName)

    // Use native C++ `anserin-core reserve` (pure CPU 1x1 wl_shm layer-shell, ~0.6 MB PSS, zero GL contexts)
    // instead of spawning 4 invisible Qt/OpenGL PanelWindows (~100 MB PSS). Never touches monitor scale/mode,
    // works on Hyprland, Niri & Sway, and vanishes automatically to 0px when Anserin stops.
    // Falls back to the 4 QML PanelWindows only if anserin-core could not be built.
    property bool reserveFailed: false
    readonly property bool useCoreReserve: CoreTools.core && !reserveFailed

    Process {
        id: reserveProc
        running: ScreenEdges.modern && CoreTools.core && !borderRoot.reserveFailed
        command: [CoreTools.coreBin, "reserve"]
        stdinEnabled: true
        onRunningChanged: {
            if (running) {
                for (let i = 0; i < screenVariants.instances.length; i++) {
                    const inst = screenVariants.instances[i];
                    if (inst && inst.pushReserve) inst.pushReserve(true);
                }
            }
        }
        onExited: function(code) {
            if (code !== 0 && ScreenEdges.modern && CoreTools.core) {
                borderRoot.reserveFailed = true;
            }
        }
    }

    Variants {
        id: screenVariants
        model: ScreenEdges.modern ? Quickshell.screens : []

        Scope {
            id: scope
            required property var modelData
            readonly property int inset: ScreenEdges.inset(modelData)
            readonly property string monName: String(modelData && modelData.name ? modelData.name : "")
            readonly property int resTop: Math.round(ScreenEdges.reserved(modelData, "top"))
            readonly property int resBottom: Math.round(ScreenEdges.reserved(modelData, "bottom"))
            readonly property int resLeft: Math.round(ScreenEdges.reserved(modelData, "left"))
            readonly property int resRight: Math.round(ScreenEdges.reserved(modelData, "right"))
            property string lastSent: ""

            function pushReserve(force) {
                if (!reserveProc.running || monName === "") return;
                const line = "set " + monName + " " + resTop + " " + resBottom + " " + resLeft + " " + resRight;
                if (!force && line === lastSent) return;
                lastSent = line;
                reserveProc.write(line + "\n");
            }

            Timer {
                id: reserveSync
                interval: 16
                repeat: false
                onTriggered: scope.pushReserve(false)
            }
            onResTopChanged: reserveSync.restart()
            onResBottomChanged: reserveSync.restart()
            onResLeftChanged: reserveSync.restart()
            onResRightChanged: reserveSync.restart()
            Component.onCompleted: pushReserve(true)

            // Fallback 4 PanelWindows ONLY when anserin-core is unavailable (no cmake/C++ compiler)
            Variants {
                model: (!CoreTools.ready || borderRoot.useCoreReserve) ? [] : ["top", "right", "bottom", "left"]
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
                    Region { item: leftPanelTrigger }
                    Region { item: rightPanelTrigger }
                }

                ScreenEdgeTrigger { id: barTrigger; target: LauncherController.bars[window.screen.name] || null }
                ScreenEdgeTrigger { id: dockTrigger; target: ScreenEdges.docks[window.screen.name] || null }

                // Left & right panel edge hover strips share this PanelWindow (avoids 2 extra OpenGL contexts / 4 Mesa threads)
                Item {
                    id: leftPanelTrigger
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: Math.max(160, Math.round(window.height * 0.3))
                    HoverHandler { id: leftEdgeHover }
                    Timer {
                        interval: 150
                        running: leftEdgeHover.hovered
                        onTriggered: borderRoot.leftEdgeTriggered(scope.modelData.name)
                    }
                }

                Item {
                    id: rightPanelTrigger
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: Math.max(160, Math.round(window.height * 0.3))
                    HoverHandler { id: rightEdgeHover }
                    Timer {
                        interval: 150
                        running: rightEdgeHover.hovered
                        onTriggered: borderRoot.rightEdgeTriggered(scope.modelData.name)
                    }
                }

                ScreenFrame {
                    anchors.fill: parent
                    inset: scope.inset
                }
            }
        }
    }
}
