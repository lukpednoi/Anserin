import QtQuick
import QtMultimedia
import "../../native/video"

Item {
    id: root
    objectName: "live-wallpaper-video"
    property var videoSink: null
    readonly property bool ready: mirror.ready
    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
    VideoFrameMirror {
        id: mirror
        source: root.videoSink
        output: output.videoSink
    }
}
