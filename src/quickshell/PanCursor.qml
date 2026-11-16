import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// inf desktop pan: the cursor stays still where the pan began. desktop.lua hides the real cursor meanwhile and
// writes "x y" to inf-pan-cursor (empty when no pan); this draws the theme's pointer there, on top of everything.
Scope {
    id: root
    property point at: Qt.point(0, 0)
    property bool shown: false
    // the pointer image of the cursor theme: {path, size, hotX, hotY} (scripts/cursor-image.py)
    property var pointer: null
    readonly property real cursorSize: Number(Quickshell.env("XCURSOR_SIZE")) || 24

    FileView {
        path: Caching.runDir + "/inf-pan-cursor"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const m = /^(-?\d+) (-?\d+)/.exec(text());
            if (m) root.at = Qt.point(Number(m[1]), Number(m[2]));
            root.shown = !!m;
        }
        onLoadFailed: root.shown = false
    }

    Process {
        running: true
        command: ["python3", Caching.anserinDir + "/scripts/cursor-image.py", Caching.cacheDir + "/cursor",
                  String(Math.ceil(root.cursorSize * Math.max(1, ...Quickshell.screens.map(s => s.devicePixelRatio || 1))))]
        stdout: StdioCollector {
            onStreamFinished: { try { root.pointer = JSON.parse(text); } catch (e) { root.pointer = null; } }
        }
    }

    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            readonly property real k: root.pointer ? root.cursorSize / root.pointer.size : 1
            screen: modelData
            visible: root.shown && root.pointer !== null
                     && root.at.x >= modelData.x && root.at.x < modelData.x + modelData.width
                     && root.at.y >= modelData.y && root.at.y < modelData.y + modelData.height
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "anserin-pan-cursor"
            exclusionMode: ExclusionMode.Ignore
            anchors.left: true
            anchors.top: true
            margins.left: Math.round(root.at.x - modelData.x - (root.pointer ? root.pointer.hotX * k : 0))
            margins.top: Math.round(root.at.y - modelData.y - (root.pointer ? root.pointer.hotY * k : 0))
            implicitWidth: Math.ceil(root.cursorSize)
            implicitHeight: Math.ceil(root.cursorSize)
            color: "transparent"
            mask: Region {}
            Image {
                anchors.fill: parent
                source: root.pointer ? "file://" + root.pointer.path : ""
                smooth: true
                mipmap: true
            }
        }
    }
}
