import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../../"

// The current wallpaper (still images), blurred, filling the page and drifting a little with the pointer,
// darkened toward the bottom so text stays readable. `px` / `py` (-1..1) let content drift along with it.
ClippingRectangle {
    id: frame
    property string screenName: ""
    radius: ThemeBackend.clampedBorderRadius
    color: ThemeBackend.surface0

    property string path: ""
    function refresh() {
        const p = Wallpaper.getWallpaperPath(screenName);
        path = /\.(jpe?g|png|webp|bmp)$/i.test(p) ? "file://" + p : "";
    }
    onVisibleChanged: if (visible) refresh()
    Component.onCompleted: refresh()
    Connections { target: Wallpaper; function onWallpaperChanged() { frame.refresh(); } }

    HoverHandler { id: hover }
    property real px: hover.hovered ? (hover.point.position.x / width - 0.5) * 2 : 0
    property real py: hover.hovered ? (hover.point.position.y / height - 0.5) * 2 : 0
    Behavior on px { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on py { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    Image {
        id: wp
        anchors.fill: parent
        anchors.margins: -24
        source: frame.path
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 700
        visible: false
    }
    MultiEffect {
        anchors.fill: wp
        source: wp
        visible: wp.status === Image.Ready
        blurEnabled: true
        blur: 0.55
        blurMax: 48
        saturation: -0.1
        brightness: -0.08
        transform: Translate { x: -frame.px * 14; y: -frame.py * 10 }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(ThemeBackend.base, 0.15) }
            GradientStop { position: 0.55; color: Qt.alpha(ThemeBackend.base, 0.45) }
            GradientStop { position: 1.0; color: Qt.alpha(ThemeBackend.base, 0.92) }
        }
    }
}
