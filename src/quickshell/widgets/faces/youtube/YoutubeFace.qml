import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../../../"
import "YoutubePip.js" as Pip

Item {
    id: root
    anchors.fill: parent

    property var widgetWindow: null
    readonly property var youtube: Pip.session(Mpris.players.values)
    readonly property bool controlling: widgetWindow !== null && visible && youtube !== null
    property var original: null
    property string error: ""
    property bool attached: false
    property var lastTarget: null
    property var pendingGeometry: null

    function applyPointerGeometry() {
        if (!pendingGeometry || !original || apply.running) return;
        const code = Pip.command(original, pendingGeometry, false);
        pendingGeometry = null;
        if (code) Hyprland.dispatch("function() " + code + " end");
    }

    function release() {
        if (original) {
            const code = Pip.command(original, {x: original.at[0], y: original.at[1], w: original.size[0], h: original.size[1]}, true, Caching.qsDir + "/../scripts/infinite-desktop-v2/layout.lua");
            if (code) Quickshell.execDetached(["hyprctl", "eval", code]);
        }
        original = null;
        lastTarget = null;
        pendingGeometry = null;
        attached = false;
        if (Pip.owner === root) Pip.owner = null;
    }

    function refresh() {
        if (!controlling) { release(); return; }
        if (Pip.owner && Pip.owner !== root) return;
        Pip.owner = root;
        if (!pointer.pressed && !pendingGeometry && !clients.running && !apply.running) clients.running = true;
    }

    onControllingChanged: refresh()
    onYoutubeChanged: {
        if (original && (!youtube || original.pid !== youtube.pid)) release();
        refresh();
    }
    Component.onDestruction: release()

    Timer {
        interval: 1000
        repeat: true
        running: root.controlling
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Process {
        id: clients
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.controlling || Pip.owner !== root) return;
                if (pointer.pressed || root.pendingGeometry) return;
                try {
                    const windows = JSON.parse(text);
                    const pip = Pip.findPip(windows, root.youtube.pid);
                    if (!pip) { root.release(); return; }
                    if (root.original && root.original.stableId !== pip.stableId) root.release();
                    Pip.owner = root;
                    if (!root.original) {
                        pip.tiledPeers = windows.filter(w => !w.floating && w.mapped && !w.hidden
                            && w.monitor === pip.monitor && w.workspace.id === pip.workspace.id);
                        root.original = pip;
                    }
                    const target = Pip.geometry(root.widgetWindow);
                    const dragged = Pip.draggedGeometry(pip, target, root.lastTarget);
                    root.lastTarget = dragged || target;
                    root.attached = true;
                    root.error = "";
                    if (dragged) {
                        const widget = root.widgetWindow;
                        WidgetSync.setGeometry(widget.screen.name, widget.wId,
                            dragged.x - widget.screen.x, dragged.y - widget.screen.y,
                            dragged.w, dragged.h, widget.wOpacity, widget.wRotation);
                        return;
                    }
                    if (pip.pinned && pip.at[0] === target.x && pip.at[1] === target.y
                        && pip.size[0] === target.w && pip.size[1] === target.h) return;
                    apply.command = ["hyprctl", "eval", Pip.command(pip, target, false)];
                    apply.running = true;
                } catch (e) {
                    console.warn("YouTube PiP:", e);
                    root.error = I18n.t("widgets.youtube.error", "Cannot read Brave PiP window");
                    root.release();
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = I18n.t("widgets.youtube.error", "Cannot read Brave PiP window");
                root.release();
            }
        }
    }

    Process {
        id: apply
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("YouTube PiP:", text.trim());
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.error = I18n.t("widgets.youtube.error", "Cannot read Brave PiP window");
                root.release();
            } else if (!root.controlling) root.release();
            else if (!pointer.pressed) root.applyPointerGeometry();
        }
    }

    PanelWindow {
        id: controlsGate
        property bool revealed: false
        readonly property real resizeMargin: Scaler.s(8)
        readonly property var video: root.lastTarget || ({x: 0, y: 0, w: 0, h: 0})

        screen: root.widgetWindow ? root.widgetWindow.screen : null
        visible: root.controlling && root.attached && !root.widgetWindow.isRedacting
        color: "transparent"
        focusable: false
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.namespace: "qs-youtube-controls-" + (root.widgetWindow ? root.widgetWindow.wId : "preview")
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        onVisibleChanged: revealed = false

        // After the first click, catch only the exit so Brave keeps its native controls and mouse grabs.
        mask: Region {
            x: controlsGate.video.x - (controlsGate.screen ? controlsGate.screen.x : 0) - (controlsGate.revealed ? 0 : controlsGate.resizeMargin)
            y: controlsGate.video.y - (controlsGate.screen ? controlsGate.screen.y : 0) - (controlsGate.revealed ? 0 : controlsGate.resizeMargin)
            width: controlsGate.video.w + (controlsGate.revealed ? 0 : controlsGate.resizeMargin * 2)
            height: controlsGate.video.h + (controlsGate.revealed ? 0 : controlsGate.resizeMargin * 2)
            intersection: controlsGate.revealed ? Intersection.Xor : Intersection.Combine
        }

        Connections {
            target: Hyprland
            function onFocusedMonitorChanged() {
                if (Hyprland.focusedMonitor && controlsGate.screen
                    && Hyprland.focusedMonitor.name !== controlsGate.screen.name) controlsGate.revealed = false;
            }
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            preventStealing: true
            property var startVideo: null
            property var edges: ({})
            property point startMouse
            property bool moved: false
            readonly property real globalX: mouseX + (controlsGate.screen ? controlsGate.screen.x : 0)
            readonly property real globalY: mouseY + (controlsGate.screen ? controlsGate.screen.y : 0)
            readonly property var hoverEdges: Pip.resizeEdges(controlsGate.video, globalX, globalY, controlsGate.resizeMargin)
            cursorShape: {
                const e = pressed ? edges : hoverEdges;
                if ((e.left && e.top) || (e.right && e.bottom)) return Qt.SizeFDiagCursor;
                if ((e.right && e.top) || (e.left && e.bottom)) return Qt.SizeBDiagCursor;
                if (e.left || e.right) return Qt.SizeHorCursor;
                if (e.top || e.bottom) return Qt.SizeVerCursor;
                return moved ? Qt.ClosedHandCursor : Qt.ArrowCursor;
            }

            onPressed: {
                startVideo = controlsGate.video;
                startMouse = Qt.point(mouseX, mouseY);
                edges = Pip.resizeEdges(startVideo, globalX, globalY, controlsGate.resizeMargin);
                moved = false;
            }
            onReleased: {
                if (moved) finishDrag();
                else if (Pip.containsPoint(controlsGate.video, globalX, globalY)) controlsGate.revealed = true;
            }
            onCanceled: if (moved) finishDrag()
            onEntered: checkExit()
            onPositionChanged: {
                if (!pressed) { checkExit(); return; }
                const dx = mouseX - startMouse.x, dy = mouseY - startMouse.y;
                if (!moved && Math.hypot(dx, dy) < Qt.styleHints.startDragDistance) return;
                moved = true;
                root.lastTarget = Pip.pointerGeometry(startVideo, edges, dx, dy);
                root.pendingGeometry = root.lastTarget;
            }

            function finishDrag() {
                moved = false;
                if (!root.controlling || !root.attached) return;
                root.applyPointerGeometry();
                const widget = root.widgetWindow, target = root.lastTarget;
                WidgetSync.setGeometry(widget.screen.name, widget.wId,
                    target.x - widget.screen.x, target.y - widget.screen.y,
                    target.w, target.h, widget.wOpacity, widget.wRotation);
            }

            function checkExit() {
                if (!pressed && controlsGate.revealed
                    && !Pip.containsPoint(controlsGate.video, globalX, globalY)) controlsGate.revealed = false;
            }
        }

        Timer {
            interval: 16
            repeat: true
            running: pointer.pressed && pointer.moved
            onTriggered: root.applyPointerGeometry()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.base
        radius: ThemeBackend.borderRadius
        visible: !root.attached

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Scaler.s(24)
            spacing: Scaler.s(8)

            Text {
                text: String.fromCodePoint(0xF05C3)
                font.family: ThemeBackend.iconFont
                font.pixelSize: Scaler.s(32)
                color: ThemeBackend.red
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: root.error || (root.youtube
                    ? I18n.t("widgets.youtube.open_pip", "In Brave: right-click the video twice → Picture in picture")
                    : I18n.t("widgets.youtube.open_youtube", "Play a YouTube video in Brave first"))
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Scaler.s(12)
                color: ThemeBackend.subtext0
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }
    }
}
