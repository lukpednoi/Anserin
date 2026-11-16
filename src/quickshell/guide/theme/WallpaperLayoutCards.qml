import "../../"
import "../../reusables"
import QtQuick
import QtQuick.Layouts

// The wallpaper picker's layout as two preview cards (Original / 3 columns); a click picks one
// (theme.wallpaperStyle). Shared by Theme → Style (WallpaperTransitions.qml) and the Control Center's board.
RowLayout {
    id: root
    required property var rootObj
    function s(value) { return rootObj.s(value); }
    readonly property string selectedLayout: Config.getSetting("theme.wallpaperStyle", "original") === "grid" ? "grid" : "original"
    objectName: "wallpaper-layout-cards"
    Layout.fillWidth: true
    spacing: root.s(12)
    Repeater {
        model: [{key: "original", name: "Original"}, {key: "grid", name: "3 columns"}]
        Rectangle {
            id: layoutCard
            required property var modelData
            readonly property bool selected: root.selectedLayout === modelData.key
            property real popScale: 1
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: layoutPreviewBox.height + root.s(48)
            radius: ThemeBackend.clampedBorderRadius
            color: layoutMouse.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
            border.width: selected ? root.s(2) : 1
            border.color: selected ? ThemeBackend.mauve : ThemeBackend.surface1
            scale: popScale
            Behavior on color { ColorAnimation { duration: 180 } }
            SequentialAnimation {
                id: layoutPop
                NumberAnimation { target: layoutCard; property: "popScale"; to: 0.97; duration: 100; easing.type: Easing.OutQuad }
                NumberAnimation { target: layoutCard; property: "popScale"; to: 1; duration: 250; easing.type: Easing.OutBack }
            }
            Rectangle {
                id: layoutPreviewBox
                x: root.s(8); y: root.s(8)
                width: parent.width - root.s(16)
                height: width * 0.5
                radius: ThemeBackend.clampedBorderRadius
                color: ThemeBackend.mantle
                clip: true
                Loader {
                    anchors.fill: parent
                    active: root.visible
                    enabled: false
                    sourceComponent: WallpaperLayoutPreview {
                        gridLayout: layoutCard.modelData.key === "grid"
                        currentWallpaper: "file://" + Caching.cacheDir + "/wallpaper/current_wallpaper.png"
                    }
                }
            }
            Text {
                x: root.s(12); y: layoutPreviewBox.y + layoutPreviewBox.height + root.s(10)
                text: layoutCard.modelData.name
                color: layoutCard.selected ? ThemeBackend.mauve : ThemeBackend.text
                font { family: ThemeBackend.fontFamily; pixelSize: root.s(12); bold: true }
            }
            MouseArea {
                id: layoutMouse
                objectName: "wallpaper-layout-" + layoutCard.modelData.key
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    layoutPop.restart();
                    Sounds.playSfx("reusables/clickbutton/click.wav");
                    Config.setSetting("theme.wallpaperStyle", layoutCard.modelData.key);
                }
            }
        }
    }
}
