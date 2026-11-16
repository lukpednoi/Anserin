import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../../"
import "../../reusables"

// The left panel's Wallpaper page, laid out as its Launcher page: in place of the search field, Select Wallpaper's
// colour squares (WallpaperColorRow) with a Pictures / Videos switch before them, and below them the wallpapers one
// to a row, as pictures only (no names): the pictures in Select's colour order, or the videos (their posters). The
// wallpaper in use is left out.
//   A colour square scrolls to the first picture of that colour, as in Select; the square of the colour at the top
//   of the list is lit as it scrolls. With Videos the squares rest (dimmed).
//   A click puts it on as Select does (all screens, the transition chosen in Theme, Matugen at once) while its row
//   goes and the rows below move up into its place. The old wallpaper comes back into the list.
// The list is the Select index (indexer.py, current_index.json), read each time the page is shown.
Item {
    id: page
    required property var panel
    property bool active: false
    function s(v) { return panel.s(v); }

    readonly property string srcDir: {
        const dummy = Config.rawSettings;
        return Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR")
               || (Quickshell.env("HOME") + "/Pictures/Wallpapers");
    }
    readonly property var bucketOrder: ["Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Brown", "Black", "Gray", "White"]

    // ---------- the list ----------
    property var items: []          // every wallpaper from the index, in the order shown
    property string pendingPath: "" // picked, flying: kept out of the list until it is the wallpaper
    property bool videos: false     // the switch: the videos instead of the pictures
    function inUse(path) {
        const paths = Wallpaper.screenWallpaperPaths || {};
        for (const k in paths) if (paths[k] === path) return true;
        return path === pendingPath;
    }
    ListModel { id: shown }         // { filePath, url, isVideo, hex, bucket }
    // the model follows `items` minus the wallpapers in use, by inserting and removing rows only (so the rows move)
    function sync() {
        const want = items.filter(it => it.isVideo === videos && !inUse(it.filePath));
        const keep = {};
        for (const it of want) keep[it.filePath] = true;
        for (let i = shown.count - 1; i >= 0; i--) if (!keep[shown.get(i).filePath]) shown.remove(i);
        for (let i = 0; i < want.length; i++) {
            if (i < shown.count && shown.get(i).filePath === want[i].filePath) continue;
            let at = -1;
            for (let k = i + 1; k < shown.count; k++) if (shown.get(k).filePath === want[i].filePath) { at = k; break; }
            if (at >= 0) shown.move(at, i, 1);
            else shown.insert(i, want[i]);
        }
    }
    function load(data) {
        if (!data || !Array.isArray(data.items)) return;
        const pics = [], vids = [];
        for (const it of data.items) {
            if (!it || !it.filePath) continue;
            const video = !!it.isVideo || /\.(mp4|mkv|mov|webm)$/i.test(it.filePath);
            const bucket = it.bucket === "Monochrome" ? "Gray" : (it.bucket || "Gray");
            const row = { filePath: String(it.filePath), url: String(video ? (it.posterUrl || "") : (it.fileUrl || ("file://" + it.filePath))),
                          poster: String(it.posterPath || ""), isVideo: video, hex: String(it.hex || "#808080"), bucket: video ? "" : bucket };
            (video ? vids : pics).push(row);
        }
        const rank = b => { const i = bucketOrder.indexOf(b); return i < 0 ? bucketOrder.length : i; };
        pics.sort((a, b) => rank(a.bucket) - rank(b.bucket) || a.filePath.localeCompare(b.filePath));
        vids.sort((a, b) => a.filePath.localeCompare(b.filePath));
        items = pics.concat(vids);
        sync();
    }
    Process {
        id: indexer
        command: ["python3", Caching.anserinDir + "/scripts/wallpaper/indexer.py", page.srcDir,
                  Caching.getCacheDir("wallpaper"), Caching.getRunDir("wallpaper")]
        stdout: StdioCollector {
            onStreamFinished: { try { page.load(JSON.parse(this.text.trim())); } catch (e) {} }
        }
    }
    onActiveChanged: if (active) { indexer.running = false; indexer.running = true; introRun.restart(); }
    Connections {
        target: Wallpaper
        function onScreenWallpaperPathsChanged() {
            if (page.pendingPath !== "" && page.inUseNow(page.pendingPath)) page.pendingPath = "";
            page.sync();
        }
    }
    function inUseNow(path) {
        const paths = Wallpaper.screenWallpaperPaths || {};
        for (const k in paths) if (paths[k] === path) return true;
        return false;
    }

    // ---------- putting one on ----------
    function pick(index, tile) {
        if (pendingPath !== "" || index < 0 || index >= shown.count) return;
        const it = shown.get(index);
        pendingPath = it.filePath;
        // as Select puts one on: the transition chosen in Theme (""), and the theme from it (a video's poster)
        Wallpaper.setWallpaper("all", it.filePath, "");
        const themeFrom = it.isVideo ? it.poster : it.filePath;
        if (themeFrom !== "" && typeof Matugen !== "undefined" && typeof Matugen.generate === "function") Matugen.generate(themeFrom);
        pendingGuard.restart();
        Sounds.playSfx("reusables/clickbutton/click.wav");
        shown.remove(index);
    }
    // the wallpaper never reported back (a file that would not load): let the list have it again
    Timer { id: pendingGuard; interval: 4000; onTriggered: { page.pendingPath = ""; page.sync(); } }

    // ---------- the colour squares ----------
    property string litColor: ""
    property bool anchoring: false
    function bucketAtTop() {
        const i = list.indexAt(page.s(10), list.contentY + page.s(10));
        return i >= 0 && i < shown.count ? shown.get(i).bucket : litColor;
    }
    function scrollTo(name) {
        for (let i = 0; i < shown.count; i++) {
            if (shown.get(i).bucket !== name) continue;
            const target = Math.max(list.originY, Math.min(list.originY + list.contentHeight - list.height,
                                                          list.originY + i * (rowH + list.spacing)));
            litColor = name;
            anchoring = true;
            scrollAnim.stop(); scrollAnim.to = Math.max(list.originY, target); scrollAnim.restart();
            return;
        }
    }
    NumberAnimation { id: scrollAnim; target: list; property: "contentY"; duration: 420; easing.type: Easing.OutCubic
                      onStopped: page.anchoring = false }

    // switching shows the other kind from the top, coming in as on opening
    onVideosChanged: { scrollAnim.stop(); anchoring = false; shown.clear(); sync(); list.positionViewAtBeginning(); introRun.restart(); }

    WallpaperColorRow {
        id: colorRow
        // across the top, after the switch
        x: kindSwitch.x + kindSwitch.width + page.s(12)
        y: page.s(14)
        width: parent.width - x - page.s(14)
        current: page.videos ? "" : page.litColor
        active: !page.videos
        opacity: page.videos ? 0.35 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }
        scaler: page.s
        onPicked: (name) => page.scrollTo(name)
    }

    // Pictures / Videos: two squares the size of the colour squares, the one shown filled with the accent
    Rectangle {
        id: kindSwitch
        x: page.s(11)
        y: page.s(11)
        width: kindRow.width + page.s(6)
        height: kindRow.height + page.s(6)
        radius: ThemeBackend.borderRadius + page.s(3)
        color: ThemeBackend.surface0
        Row {
            id: kindRow
            anchors.centerIn: parent
            spacing: page.s(2)
            Repeater {
                model: [{ icon: "󰋩", video: false }, { icon: "󰕧", video: true }]
                Rectangle {
                    required property var modelData
                    readonly property bool on: page.videos === modelData.video
                    width: colorRow.cell; height: width
                    radius: ThemeBackend.borderRadius
                    color: on ? ThemeBackend.mauve : (kindMa.containsMouse ? ThemeBackend.surface1 : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }
                    scale: kindMa.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuart } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.icon
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: page.s(16)
                        color: parent.on ? ThemeBackend.crust : ThemeBackend.text
                    }
                    MouseArea {
                        id: kindMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (page.videos === parent.modelData.video) return;
                            Sounds.playSfx("reusables/clickbutton/click.wav");
                            page.videos = parent.modelData.video;
                        }
                    }
                }
            }
        }
    }

    // ---------- the rows ----------
    readonly property real rowH: s(150)
    property real intro: 1
    NumberAnimation { id: introRun; target: page; property: "intro"; from: 0; to: 1; duration: 520; easing.type: Easing.OutCubic }

    ListView {
        id: list
        x: page.s(14)
        y: colorRow.y + colorRow.height + page.s(12)
        width: parent.width - x - page.s(14)
        height: parent.height - y - page.s(14)
        clip: true
        spacing: page.s(8)
        model: shown
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: page.s(600)
        onContentYChanged: if (!page.anchoring) page.litColor = page.bucketAtTop()
        onCountChanged: if (!page.anchoring) Qt.callLater(() => page.litColor = page.bucketAtTop())

        add: Transition { NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic } }
        displaced: Transition { NumberAnimation { properties: "y"; duration: 340; easing.type: Easing.OutCubic } }

        delegate: Item {
            id: rowItem
            required property int index
            required property string url
            width: list.width
            height: page.rowH
            // the rows come in one after another as the Launcher's do
            readonly property real reveal: Math.max(0, Math.min(1, page.intro * 6 - Math.min(index, 5) * 0.6))
            opacity: reveal
            transform: Translate { y: page.s(15) * (1 - rowItem.reveal) }

            ClippingRectangle {
                id: tile
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: ThemeBackend.surface0
                scale: rowMa.pressed ? 0.97 : (rowMa.containsMouse ? 1.012 : 1)
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
                Image {
                    anchors.fill: parent
                    source: rowItem.url
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: Math.max(1, tile.width)
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                // under the pointer, a rim in the accent
                Rectangle {
                    anchors.fill: parent
                    radius: tile.radius      // (a ClippingRectangle's children sit in its inner item)
                    color: "transparent"
                    border.width: page.s(2)
                    border.color: ThemeBackend.mauve
                    opacity: rowMa.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
            MouseArea {
                id: rowMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.pick(rowItem.index, tile)
            }
        }
    }

    // nothing to show (an empty folder, or only the wallpaper in use)
    Text {
        anchors.centerIn: list
        visible: shown.count === 0 && !indexer.running
        text: page.videos ? "No videos" : "No wallpapers"
        font.family: ThemeBackend.fontFamily
        font.pixelSize: page.s(13)
        color: ThemeBackend.subtext0
    }
}
