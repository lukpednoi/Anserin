import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"
import "../../wallpaper" as WallpaperUi

Item {
    id: root
    objectName: "wallpaper-layout-sample"
    property bool gridLayout: false
    property bool showLayout: true   // false: only pick the sample images, draw nothing
    property url currentWallpaper: ""
    property var samples: []
    readonly property url sampleWallpaper: samples.length ? samples[0].thumbnail : currentWallpaper
    readonly property string directory: Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    readonly property real unit: height / 650
    enabled: false

    function chooseSamples(text) {
        let items = [];
        try {
            const index = JSON.parse(text);
            if (index.srcDir === directory && Array.isArray(index.items)) {
                items = index.items.filter(entry => {
                    const thumbnail = entry && (entry.isVideo ? entry.posterUrl : entry.fileUrl);
                    return typeof thumbnail === "string" && thumbnail.startsWith("file://");
                }).map(entry => ({
                    fileName: String(entry.fileName || ""),
                    fileUrl: String(entry.fileUrl || ""),
                    posterUrl: String(entry.posterUrl || ""),
                    isVideo: !!entry.isVideo,
                    thumbnail: String(entry.isVideo ? entry.posterUrl : (entry.thumbUrl || entry.fileUrl))
                }));
            }
        } catch (error) { console.warn("Wallpaper preview index: " + error); }
        for (let i = items.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            const previous = items[i]; items[i] = items[j]; items[j] = previous;
        }
        samples = items.slice(0, 6);
        sampleModel.clear();
        for (const entry of samples) sampleModel.append(entry);
    }

    ListModel { id: sampleModel }
    FileView {
        path: Caching.cacheDir + "/wallpaper/current_index.json"
        watchChanges: false
        onLoaded: root.chooseSamples(text())
    }

    Loader {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height * 2.4)
        height: parent.height
        active: root.showLayout
        sourceComponent: root.gridLayout ? gridComponent : carouselComponent
    }

    Component {
        id: gridComponent
        WallpaperUi.WallpaperGrid {
            objectName: "wallpaper-preview-grid"
            width: Math.min(parent.width, parent.height * 2.4)
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            browser: QtObject {
                readonly property var browseModel: sampleModel
                readonly property var thumbLookup: ({})
                readonly property var activeView: null
                readonly property bool isApplying: false
                readonly property bool isScrollingBlocked: false
                readonly property bool isLoading: false
                readonly property string currentFilter: "All"
                readonly property string targetWallName: ""
                function s(value) { return value * root.unit; }
            }
        }
    }

    Component {
        id: carouselComponent
        Item {
            id: carousel
            objectName: "wallpaper-preview-carousel"
            // an odd number of cards, so the middle one has the same number on each side
            readonly property var cards: root.samples.slice(0, Math.max(0, root.samples.length - (root.samples.length + 1) % 2))
            readonly property int center: Math.floor((cards.length - 1) / 2)
            function distanceOf(index) { return Math.abs(index - center); }
            function widthOf(index) {
                const distance = distanceOf(index);
                return (distance === 0 ? 600 : 192 * Math.max(0.58, Math.pow(0.88, Math.max(0, distance - 1)))) * root.unit;
            }
            // cards touch each other; the row is placed so the middle card sits in the centre of the view
            function xOf(index) {
                let x = (width - widthOf(center)) / 2;
                for (let i = center; i > index; i--) x -= widthOf(i - 1);
                for (let i = center; i < index; i++) x += widthOf(i);
                return x;
            }
            Repeater {
                model: carousel.cards
                Item {
                    required property var modelData
                    required property int index
                    readonly property int distance: carousel.distanceOf(index)
                    x: carousel.xOf(index)
                    width: carousel.widthOf(index)
                    height: carousel.height
                    z: distance === 0 ? 100 : 50 - distance
                    ImageBox {
                        objectName: "wallpaper-preview-card"
                        anchors.centerIn: parent
                        width: parent.width
                        height: (parent.distance === 0 ? 450 : 420 * Math.max(0.62, Math.pow(0.9, Math.max(0, parent.distance - 1)))) * root.unit
                        opacity: parent.distance === 0 ? 1 : Math.max(0.3, 1 - parent.distance * 0.15)
                        source: parent.modelData.thumbnail
                        cornerRadius: ThemeBackend.clampedBorderRadius * root.unit
                        backgroundColor: ThemeBackend.surface0
                        transform: Matrix4x4 { matrix: Qt.matrix4x4(1, -0.35, 0, height * 0.175, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    }
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.showLayout && root.samples.length === 0
        text: "No wallpapers in this folder"
        color: ThemeBackend.text
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Scaler.s(11)
    }
}
