import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../"
import "../reusables"

FocusScope {
    id: root
    required property var browser
    focus: true
    property alias view: grid
    ColumnLayout {
        anchors.fill: parent
        spacing: root.browser.s(12)
        GridView {
            id: grid
            objectName: "orbit-wallpaper-grid"
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            focus: true
            keyNavigationEnabled: !root.browser.isApplying && !root.browser.isScrollingBlocked
            onCurrentIndexChanged: if (visible && root.browser.activeView === grid) {
                root.browser.handleBrowserIndexChanged(currentIndex);
                if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain);
            }
            boundsBehavior: Flickable.StopAtBounds
            cellWidth: width / 3
            cellHeight: height / 2
            cacheBuffer: cellHeight
            model: root.browser.browseModel
            ScrollBar.vertical: ScrollBar {}
            Keys.onReturnPressed: if (currentItem && !root.browser.isApplying && !root.browser.isScrollingBlocked) {
                root.browser.initialFocusSet = true;
                root.browser.applyWallpaper(currentItem.fileName, currentItem.video);
            }
            delegate: Item {
                id: tile
                required property int index
                required property var model
                readonly property string fileName: String(model.fileName || "")
                readonly property bool video: !!model.isVideo
                readonly property var entry: root.browser.thumbLookup[fileName] || ({})
                readonly property string thumbnail: String(model.posterUrl || entry.posterUrl || (video ? "" : entry.thumbUrl || model.fileUrl || entry.fileUrl || ""))
                objectName: "orbit-wallpaper-tile-" + index
                width: grid.cellWidth; height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent; anchors.margins: root.browser.s(4)
                    color: ThemeBackend.surface0
                    radius: ThemeBackend.clampedBorderRadius
                    border.width: root.browser.targetWallName === tile.fileName ? 2 : 0
                    border.color: ThemeBackend.mauve
                }
                ImageBox {
                    x: root.browser.s(8); y: x
                    width: parent.width-2*x; height: parent.height-2*y
                    source: tile.thumbnail
                    cache: false
                    cornerRadius: ThemeBackend.clampedBorderRadius
                    backgroundColor: ThemeBackend.mantle
                    interactive: !root.browser.isApplying && !root.browser.isScrollingBlocked
                    onClicked: { root.browser.initialFocusSet=true; grid.currentIndex=tile.index; root.browser.applyWallpaper(tile.fileName,tile.video); }
                    Text { anchors.centerIn: parent; visible: tile.thumbnail === ""; text: tile.video ? "󰕧" : "󰸉"; color: ThemeBackend.subtext0; font { family: ThemeBackend.iconFont; pixelSize: root.browser.s(28) } }
                }
                // the carousel's favorite star: shown on hover, and always on a favorite
                HoverHandler { id: tileHover }
                Item {
                    readonly property bool isFavorite: root.browser.favoriteKeys[root.browser.getCleanBaseName(tile.fileName)] === true
                    x: root.browser.s(10); y: x
                    width: root.browser.s(28); height: width
                    visible: (isFavorite || tileHover.hovered) && root.browser.currentFilter !== "Search"
                    scale: starMouse.pressed ? 0.9 : (starMouse.containsMouse ? 1.15 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.isFavorite ? "󰓎" : "󰓒"
                        color: parent.isFavorite ? ThemeBackend.mauve : ThemeBackend.text
                        style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.45)
                        font { family: ThemeBackend.iconFont; pixelSize: root.browser.s(18) }
                    }
                    MouseArea {
                        id: starMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.browser.isApplying
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.browser.toggleFavorite(tile.fileName)
                    }
                }
            }
        }
        Text {
            visible: !root.browser.isLoading && root.browser.browseModel.count === 0
            Layout.fillWidth: true
            text: root.browser.currentFilter === "Video" ? "No videos in this folder" : root.browser.currentFilter === "Favorites" ? "No favorites yet: press the star on a wallpaper" : "No wallpapers in this category"
            color: ThemeBackend.subtext0
            horizontalAlignment: Text.AlignHCenter
            font { family: ThemeBackend.fontFamily; pixelSize: root.browser.s(12) }
        }
    }
}
