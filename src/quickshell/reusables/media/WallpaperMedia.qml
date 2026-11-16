import QtQuick
import QtQuick.Window
import QtMultimedia

Item {
    id: root
    property string path: ""
    property bool active: visible
    property bool crop: true
    readonly property bool isVideo: /\.(mp4|mkv|mov|webm)$/i.test(path)
    readonly property url mediaUrl: {
        if (!path) return "";
        if (path.startsWith("file://")) return path;
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }
    readonly property bool failed: mediaLoader.status === Loader.Error || !!(mediaLoader.item && mediaLoader.item.failed)
    readonly property bool ready: !!(mediaLoader.item && mediaLoader.item.ready)
    readonly property real paintedWidth: mediaLoader.item ? mediaLoader.item.paintedWidth : 0
    readonly property real paintedHeight: mediaLoader.item ? mediaLoader.item.paintedHeight : 0

    Loader {
        id: mediaLoader
        anchors.fill: parent
        active: root.active && root.path !== ""
        visible: !root.failed
        sourceComponent: {
            if (root.isVideo) return videoComponent;
            if (/\.gif$/i.test(root.path)) return animatedComponent;
            return imageComponent;
        }
    }

    Component {
        id: imageComponent
        Image {
            readonly property bool failed: status === Image.Error
            readonly property bool ready: status === Image.Ready
            source: root.mediaUrl
            fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
            asynchronous: true
            cache: false
            mipmap: true
        }
    }

    Component {
        id: animatedComponent
        AnimatedImage {
            readonly property bool failed: status === Image.Error
            readonly property bool ready: status === Image.Ready
            source: root.mediaUrl
            fillMode: root.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            asynchronous: true
            cache: false
            playing: root.active
        }
    }

    Component {
        id: videoComponent
        Item {
            readonly property bool failed: player.error !== MediaPlayer.NoError
            readonly property bool ready: !failed && output.sourceRect.width > 0
            readonly property real paintedWidth: output.contentRect.width
            readonly property real paintedHeight: output.contentRect.height
            MediaPlayer {
                id: player
                source: root.mediaUrl
                videoOutput: output
                loops: MediaPlayer.Infinite
                onMediaStatusChanged: {
                    if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) play();
                }
            }
            VideoOutput {
                id: output
                anchors.fill: parent
                fillMode: root.crop ? VideoOutput.PreserveAspectCrop : VideoOutput.PreserveAspectFit
            }
        }
    }
}
