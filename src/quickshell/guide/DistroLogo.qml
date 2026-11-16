import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"

Rectangle {
    id: root
    objectName: "distro-logo"
    radius: ThemeBackend.borderRadius
    color: ThemeBackend.surface1
    property string distroId: ""
    readonly property string iconSource: distroId ? (Quickshell.iconPath(distroId + "-icon", true) || Quickshell.iconPath(distroId, true) || Quickshell.iconPath("distributor-logo-" + distroId, true)) : ""
    Accessible.role: Accessible.Graphic
    Accessible.name: SystemInfo.osName

    Image {
        id: logo
        anchors.centerIn: parent
        width: parent.width / 2
        height: width
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        layer.enabled: true
        visible: false
    }
    Rectangle { id: tint; anchors.fill: logo; color: ThemeBackend.text; visible: false }
    MultiEffect {
        anchors.fill: logo
        source: tint
        maskEnabled: true
        maskSource: logo
        visible: logo.status === Image.Ready
    }
    Text {
        anchors.centerIn: parent
        text: ""
        font.family: ThemeBackend.iconFont
        font.pixelSize: parent.width / 2
        color: ThemeBackend.text
        visible: logo.status !== Image.Ready
    }
    Process {
        running: true
        command: ["fastfetch", "--config", "none", "--structure", "os", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    if (data[0] && data[0].result) root.distroId = data[0].result.id || "";
                } catch (error) { console.warn("Fastfetch distro detection failed:", error); }
            }
        }
        onExited: (code) => {
            if (code !== 0) console.warn("Fastfetch distro detection failed:", code);
        }
    }
}
