import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"
import "../bar"

// Workspace only: a small capsule on the left screen edge holding just the workspaces (the one shared set,
// PanelLayout.strip), joined to the frame like the left edge panel, its dots exactly where the panel draws them
// (PanelLayout.workspaceX). A click on the capsule around the dots opens the panel, which takes the workspaces
// where they are and slides out from under them, as it does from the edge; the capsule goes once it is out. The window is as big as the panel from the start (it never
// resizes) but takes input only on the capsule, so clicks beside it reach the windows behind. The dots switch workspace as on the panel. It hides like
// the panel (Auto-hide and Hide delay), staying while the pointer rests on the screen edge.
PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === PanelLayout.capsuleScreen) || Quickshell.screens[0]
    color: "transparent"

    WlrLayershell.namespace: "anserin-workspace-capsule"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    anchors.left: true

    // asks the shell whether the pointer is still on the left edge (Main.checkPointerOnEdge)
    property var checkEdge: null

    function s(v) { return Scaler.s(v); }

    // just wide enough for the dots, which sit 2 px inside the screen frame
    readonly property real stripW: ScreenEdges.thickness + s(2 + 18 + 12)
    readonly property real joinH: s(40)                  // room for the concave joins above and below
    readonly property real capsuleH: slot.height + s(28)
    // the panel's size on the screen: it starts inside the frame and is 717 wide (BlankPanel)
    readonly property real fullW: ScreenEdges.thickness + s(717)
    // As big as the panel from the start, so it never resizes (a resize stretches the picture for a moment);
    // input only on the capsule, so clicks beside it reach the windows behind.
    property bool big: false
    implicitWidth: fullW
    // an even height, so the compositor centres it on a whole pixel; its middle is then exactly the panel's
    implicitHeight: Math.ceil(s(693) / 2) * 2
    mask: Region { x: body.x; y: body.y; width: body.width; height: body.height }
    // should the panel never take over, the capsule goes away rather than staying in the way
    Timer { id: unfoldSafety; interval: 1500; onTriggered: PanelLayout.hideCapsule() }

    readonly property var settings: Config.getSetting("controlcenter", null)
    readonly property bool autoHideEnabled: !settings || settings.autohide !== false
    readonly property int autoHideDelay: (settings && !isNaN(parseInt(settings.autohideDelay))) ? Math.max(300, parseInt(settings.autohideDelay)) : 1200

    property real shown: 0
    property bool hoverSeen: false

    Component.onCompleted: intro.restart()
    NumberAnimation { id: intro; target: win; property: "shown"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: outro
        NumberAnimation { target: win; property: "shown"; to: 0; duration: 220; easing.type: Easing.InCubic }
        ScriptAction { script: PanelLayout.hideCapsule() }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (hovered) win.hoverSeen = true
    }
    Timer {
        id: autoHide
        interval: win.hoverSeen ? win.autoHideDelay : win.autoHideDelay + 2500
        running: win.autoHideEnabled && !hover.hovered && !outro.running && !win.big
        onTriggered: {
            if (!win.checkEdge) { outro.restart(); return; }
            win.checkEdge(onEdge => {
                if (hover.hovered) return;
                if (onEdge) autoHide.restart(); else outro.restart();
            });
        }
    }

    Item {
        anchors.fill: parent
        opacity: win.shown
        transform: Translate { x: -win.stripW * (1 - win.shown) }

        EdgeBackground {
            id: body
            x: 0
            y: (parent.height - height) / 2
            width: win.stripW
            height: win.capsuleH
            edge: "left"
            color: ScreenEdges.modern ? ThemeBackend.base : Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.97)
            cornerRadius: ScreenEdges.modern ? ScreenEdges.rounding : Math.min(ThemeBackend.borderRadius, win.s(28))
        }

        // a click around the dots opens the full panel (the dots above take their own clicks)
        MouseArea {
            anchors.fill: body
            enabled: !win.big
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sounds.playSfx("reusables/switch/sfx.wav");
                win.big = true;
                unfoldSafety.restart();
                PanelLayout.expand();
            }
        }

        // the one set of workspaces (PanelLayout.strip), held here until the panel takes it
        Item {
            id: slot
            x: PanelLayout.workspaceX
            // half a pixel up: at the 1.2 screen scale this window and the panel's land on the pixel grid half a
            // pixel apart, and this lines the dots up with the panel's exactly
            y: body.y + (body.height - height) / 2 - 0.5
            width: win.s(40)
            height: PanelLayout.strip ? PanelLayout.strip.height : win.s(120)
            Component.onCompleted: PanelLayout.hostStrip(slot)
            Component.onDestruction: PanelLayout.releaseStrip(slot)
            // back here if the panel closes while the capsule is still up
            Connections { target: PanelLayout; function onPanelShownChanged() { if (!PanelLayout.panelShown) PanelLayout.hostStrip(slot); } }
        }
    }
}
