import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Window
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import "../../"
import "../"

Popup {
    id: pickerRoot
    parent: {
        if (rootObj) {
            return rootObj.contentItem ? rootObj.contentItem : rootObj;
        }
        return Overlay.overlay ? Overlay.overlay : undefined;
    }
    x: parent && parent.width > 0 ? Math.max(0, Math.round((parent.width - width) / 2)) : 0
    y: parent && parent.height > 0 ? Math.max(0, Math.round((parent.height - height) / 2)) : 0
    modal: true
    dim: true
    z: 300000
    width: Scaler.s(960)
    height: Scaler.s(640)
    padding: Scaler.s(18)
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    property var rootObj
    property var nameFilters: ["*"]
    property string titleText: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.title") : ""
    property var places: []
    property Component previewComponent: null
    property bool showPreview: false
    property real previewWidth: Scaler.s(360)
    property bool mediaPicker: false
    property string mediaType: "image"
    readonly property bool showThumbnails: mediaPicker && Config.getSetting("mediaPicker.showThumbnails", true)
    readonly property var fileView: showThumbnails ? gridView : listView
    readonly property string thumbnailDirectory: mediaPicker && visible && showThumbnails ? Caching.getCacheDir("media-thumbnails") : ""
    property var thumbnailQueue: []
    property var thumbnailRequests: ({})
    property var thumbnailVersions: ({})
    property bool thumbnailBusy: false
    readonly property var imageFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.gif", "*.bmp", "*.avif"]
    readonly property var videoFilters: ["*.mp4", "*.mkv", "*.mov", "*.webm"]

    function setMediaType(type) {
        if (type !== "image" && type !== "video") return;
        cancelThumbnails();
        mediaType = type;
        selectedFilePath = "";
        selectedFileName = "";
        updateNameFilters();
    }

    function requestThumbnail(path, target) {
        if (!opened || !showThumbnails || mediaType !== "video" || thumbnailRequests[target]) return;
        if (path.slice(0, path.lastIndexOf("/")) !== getAbsolutePath(folderModel.folder).replace(/\/$/, "")) return;
        thumbnailRequests[target] = true;
        thumbnailQueue.push({ path: path, target: target });
        nextThumbnail();
    }

    function nextThumbnail() {
        if (thumbnailBusy || !opened || !showThumbnails || thumbnailQueue.length === 0) return;
        let job = thumbnailQueue.shift();
        thumbnailGenerator.sourcePath = job.path;
        thumbnailGenerator.targetPath = job.target;
        thumbnailBusy = true;
        thumbnailGenerator.running = true;
        thumbnailTimeout.restart();
    }

    function cancelThumbnails() {
        thumbnailQueue = [];
        thumbnailRequests = ({});
        thumbnailVersions = ({});
        thumbnailTimeout.stop();
        thumbnailGenerator.running = false;
    }

    onAboutToHide: cancelThumbnails()
    onShowThumbnailsChanged: {
        if (!showThumbnails) cancelThumbnails();
        galleryRefresh.restart();
    }

    Process {
        id: thumbnailGenerator
        property string sourcePath: ""
        property string targetPath: ""
        command: ["bash", "-c", 'mkdir -p -- "$1" && exec ffmpeg -nostdin -hide_banner -loglevel error -threads 1 -i "$2" -frames:v 1 -vf "scale=240:-2:force_original_aspect_ratio=decrease" -threads 1 -y "$3"', "_", pickerRoot.thumbnailDirectory, sourcePath, targetPath]
        onExited: exitCode => {
            thumbnailTimeout.stop();
            thumbnailBusy = false;
            if (exitCode === 0 && pickerRoot.opened && pickerRoot.thumbnailRequests[targetPath]) {
                let versions = Object.assign({}, pickerRoot.thumbnailVersions);
                versions[targetPath] = (versions[targetPath] || 0) + 1;
                pickerRoot.thumbnailVersions = versions;
            }
            pickerRoot.nextThumbnail();
        }
    }

    Timer {
        id: thumbnailTimeout
        interval: 8000
        onTriggered: thumbnailGenerator.running = false
    }

    FolderListModel {
        id: folderModel
        showDirsFirst: true
        showDotAndDotDot: false
        showFiles: true
        showDirs: true
        showHidden: false
        caseSensitive: false
        sortField: FolderListModel.Name
        nameFilters: pickerRoot.nameFilters
    }

    ListModel { id: galleryModel }

    function refreshGallery() {
        galleryModel.clear();
        if (!showThumbnails || !visible) return;
        let query = searchInput.text.trim().toLowerCase();
        for (let i = 0; i < folderModel.count; i++) {
            let name = folderModel.get(i, "fileName");
            if (query !== "" && name.toLowerCase().indexOf(query) < 0) continue;
            galleryModel.append({
                fileName: name,
                filePath: folderModel.get(i, "filePath"),
                fileIsDir: folderModel.get(i, "fileIsDir"),
                fileSize: folderModel.get(i, "fileSize"),
                fileModified: folderModel.get(i, "fileModified").getTime()
            });
        }
    }

    Timer {
        id: galleryRefresh
        interval: 0
        onTriggered: pickerRoot.refreshGallery()
    }

    Connections {
        target: folderModel
        function onCountChanged() { galleryRefresh.restart(); }
        function onStatusChanged() { galleryRefresh.restart(); }
        function onDataChanged() { galleryRefresh.restart(); }
    }

    onVisibleChanged: galleryRefresh.restart()

    property real crLarge: ThemeBackend.borderRadius
    property real crMedium: Math.max(0, ThemeBackend.borderRadius - 2)
    property real crSmall: Math.max(0, ThemeBackend.borderRadius - 4)

    property real toolbarHeight: Scaler.s(32)
    property real actionHeight: Scaler.s(42)

    signal fileSelected(string filePath, string fileName)

    property string selectedFilePath: ""
    property string selectedFileName: ""
    property string lastVisitedFolder: ""

    property int currentPlaceIndex: {
        let cur = folderModel.folder.toString();
        if (cur.endsWith("/")) cur = cur.slice(0, -1);
        for (let i = 0; i < pickerRoot.places.length; i++) {
            let p = pickerRoot.places[i].path.toString();
            if (p.endsWith("/")) p = p.slice(0, -1);
            if (cur === p) return i;
        }
        return -1;
    }

    Connections {
        target: pickerRoot.rootObj ? pickerRoot.rootObj : null
        function onVisibleChanged() {
            if (pickerRoot.rootObj && !pickerRoot.rootObj.visible) {
                pickerRoot.close();
            }
        }
    }

    Connections {
        target: pickerRoot.parent && pickerRoot.parent !== pickerRoot.rootObj ? pickerRoot.parent : null
        function onVisibleChanged() {
            if (pickerRoot.parent && !pickerRoot.parent.visible) {
                pickerRoot.close();
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: pickerRoot.opened
        onActivated: pickerRoot.close()
    }

    Shortcut {
        sequence: "Tab"
        enabled: pickerRoot.opened && pickerRoot.places && pickerRoot.places.length > 0
        onActivated: {
            let nextIdx = pickerRoot.currentPlaceIndex >= 0 ? (pickerRoot.currentPlaceIndex + 1) % pickerRoot.places.length : 0;
            pickerRoot.gotoFolder(pickerRoot.places[nextIdx].path);
        }
    }

    Shortcut {
        sequences: ["Backtab", "Shift+Tab"]
        enabled: pickerRoot.opened && pickerRoot.places && pickerRoot.places.length > 0
        onActivated: {
            let len = pickerRoot.places.length;
            let prevIdx = pickerRoot.currentPlaceIndex >= 0 ? (pickerRoot.currentPlaceIndex - 1 + len) % len : len - 1;
            pickerRoot.gotoFolder(pickerRoot.places[prevIdx].path);
        }
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: pickerRoot.opened
        onActivated: {
            if (pickerRoot.fileView.activeFocus && pickerRoot.fileView.currentItem) {
                let item = pickerRoot.fileView.currentItem;
                let obj = item.fileIsDir;
                let fp = item.filePath;
                let fn = item.fileName;
                if (obj) {
                    pickerRoot.gotoFolder(fp);
                } else {
                    pickerRoot.selectedFilePath = pickerRoot.getAbsolutePath(fp);
                    pickerRoot.selectedFileName = fn;
                    pickerRoot.confirmSelection();
                }
            } else if (pickerRoot.selectedFilePath !== "") {
                pickerRoot.confirmSelection();
            }
        }
    }

    function confirmSelection() {
        if (pickerRoot.selectedFilePath !== "") {
            pickerRoot.fileSelected(pickerRoot.selectedFilePath, pickerRoot.selectedFileName);
            pickerRoot.close();
        }
    }

    function getAbsolutePath(pathStr) {
        if (!pathStr) return "";
        let str = pathStr.toString();
        if (!str.startsWith("file://")) return str;
        str = str.substring(7);
        try {
            return decodeURIComponent(str);
        } catch (e) {
            return str;
        }
    }

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function openWithOptionalPath(initialPath) {
        if (searchInput) {
            searchInput.clear();
        }

        let p = getAbsolutePath(initialPath);

        if (p !== "") {
            selectedFilePath = p;
            let parts = p.split("/");
            selectedFileName = parts[parts.length - 1];

            let dir = parts.slice(0, -1).join("/");
            if (dir !== "") {
                lastVisitedFolder = fileUrl(dir);
            }
        } else {
            selectedFilePath = "";
            selectedFileName = "";
            if (lastVisitedFolder === "") {
                let home = Quickshell.env("HOME") || "";
                if (home !== "") {
                    lastVisitedFolder = fileUrl(home);
                }
            }
        }

        folderModel.folder = lastVisitedFolder || "file:///";
        updateNameFilters();
        open();

        Qt.callLater(() => {
            if (breadcrumbFlickable.contentWidth > breadcrumbFlickable.width) {
                breadcrumbFlickable.contentX = breadcrumbFlickable.contentWidth - breadcrumbFlickable.width;
            }
        });
    }

    function gotoFolder(path) {
        cancelThumbnails();
        let normalizedPath = path.toString();
        if (!normalizedPath.startsWith("file://")) {
            normalizedPath = fileUrl(normalizedPath);
        }
        folderModel.folder = normalizedPath;
        lastVisitedFolder = normalizedPath;
        selectedFilePath = "";
        selectedFileName = "";
    }

    function updateNameFilters() {
        let st = searchInput.text ? searchInput.text.trim() : "";
        let base = mediaPicker ? (mediaType === "video" ? videoFilters : imageFilters) : pickerRoot.nameFilters;
        if (st.length > 0) {
            let filters = [];
            for (let i = 0; i < base.length; i++) {
                filters.push("*" + st + "*" + base[i].replace("*", ""));
            }
            if (!mediaPicker) filters.push("*" + st + "*");
            folderModel.nameFilters = filters;
        } else {
            folderModel.nameFilters = base;
        }
        galleryRefresh.restart();
    }

    Timer {
        id: searchDebounceTimer
        interval: 150
        repeat: false
        onTriggered: pickerRoot.updateNameFilters()
    }

    Component {
        id: fileDelegate
        Rectangle {
            id: entry
            required property int index
            required property string fileName
            required property string filePath
            required property bool fileIsDir
            required property var fileModified
            required property real fileSize
            readonly property bool gallery: !!GridView.view
            property bool canLoadThumbnail: true
            GridView.onPooled: canLoadThumbnail = false
            GridView.onReused: canLoadThumbnail = true
            readonly property var view: gallery ? GridView.view : ListView.view
            readonly property bool matchesSearch: searchInput.text.trim() === "" || fileName.toLowerCase().indexOf(searchInput.text.trim().toLowerCase()) >= 0
            readonly property bool isVideo: /\.(mp4|mkv|mov|webm)$/i.test(fileName)
            readonly property string localPath: pickerRoot.getAbsolutePath(filePath)
            readonly property string posterPath: gallery && isVideo && !fileIsDir && pickerRoot.thumbnailDirectory !== ""
                ? pickerRoot.thumbnailDirectory + "/" + Qt.md5(filePath + "|" + fileSize + "|" + fileModified) + ".jpg" : ""
            width: gallery ? gridView.cellWidth - Scaler.s(4) : listView.width
            height: gallery ? gridView.cellHeight - Scaler.s(4) : (matchesSearch ? Scaler.s(32) : 0)
            visible: matchesSearch
            radius: pickerRoot.crSmall
            color: pickerRoot.selectedFilePath === localPath ? Qt.alpha(ThemeBackend.mauve, 0.15) : (entryMouse.containsMouse ? ThemeBackend.surface1 : "transparent")
            Accessible.role: Accessible.ListItem
            Accessible.name: fileName

            Item {
                id: thumbnailArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: nameLabel.top
                anchors.margins: Scaler.s(5)
                clip: true
                visible: entry.gallery
                Loader {
                    id: thumbnailLoader
                    anchors.fill: parent
                    active: entry.gallery && entry.canLoadThumbnail && entry.visible && !entry.fileIsDir && pickerRoot.opened
                        && entry.y + entry.height >= gridView.contentY && entry.y < gridView.contentY + gridView.height
                    sourceComponent: Image {
                        readonly property string imagePath: entry.isVideo ? entry.posterPath : entry.localPath
                        source: imagePath ? pickerRoot.fileUrl(imagePath) + (entry.isVideo ? "?v=" + (pickerRoot.thumbnailVersions[entry.posterPath] || 0) : "") : ""
                        sourceSize: Qt.size(Math.ceil(width * Screen.devicePixelRatio), Math.ceil(height * Screen.devicePixelRatio))
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                        onStatusChanged: {
                            if (status === Image.Error && entry.isVideo) pickerRoot.requestThumbnail(entry.localPath, entry.posterPath);
                        }
                    }
                }
                Text {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    visible: entry.isVideo
                    text: "󰐊"
                    color: "white"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: Scaler.s(15)
                }
            }

            Text {
                anchors.left: entry.gallery ? undefined : parent.left
                anchors.leftMargin: Scaler.s(8)
                anchors.horizontalCenter: entry.gallery ? parent.horizontalCenter : undefined
                anchors.verticalCenter: entry.gallery ? thumbnailArea.verticalCenter : parent.verticalCenter
                visible: !entry.gallery || entry.fileIsDir || !thumbnailLoader.item || thumbnailLoader.item.status !== Image.Ready
                text: entry.fileIsDir ? "󰉋" : (entry.isVideo ? "󰕧" : "󰋩")
                font.family: "Iosevka Nerd Font"
                font.pixelSize: Scaler.s(entry.gallery ? 28 : 16)
                color: entry.fileIsDir ? ThemeBackend.blue : ThemeBackend.text
            }

            Text {
                id: nameLabel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Scaler.s(entry.gallery ? 5 : 30)
                anchors.rightMargin: Scaler.s(8)
                anchors.bottom: entry.gallery ? parent.bottom : undefined
                anchors.bottomMargin: Scaler.s(4)
                anchors.verticalCenter: entry.gallery ? undefined : parent.verticalCenter
                text: entry.fileName
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Scaler.s(entry.gallery ? 11 : 13)
                color: ThemeBackend.text
                elide: Text.ElideRight
            }

            MouseArea {
                id: entryMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    entry.view.forceActiveFocus();
                    entry.view.currentIndex = entry.index;
                    if (entry.fileIsDir) {
                        pickerRoot.gotoFolder(entry.filePath);
                    } else {
                        pickerRoot.selectedFilePath = entry.localPath;
                        pickerRoot.selectedFileName = entry.fileName;
                    }
                }
                onDoubleClicked: if (entry.fileIsDir) pickerRoot.gotoFolder(entry.filePath)
            }
        }
    }

    background: Rectangle {
        color: ThemeBackend.base
        radius: pickerRoot.crLarge
        border.color: ThemeBackend.surface0
        border.width: 1
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.4)
            shadowVerticalOffset: Scaler.s(4)
            shadowBlur: 0.5
        }
    }

    contentItem: ColumnLayout {
        spacing: Scaler.s(14)

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: pickerRoot.titleText
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Scaler.s(16)
                font.weight: Font.Bold
                Layout.fillWidth: true
            }
            IconButton {
                Layout.preferredWidth: pickerRoot.toolbarHeight
                Layout.preferredHeight: pickerRoot.toolbarHeight
                cornerRadius: pickerRoot.crSmall
                buttonIcon: "󰅖"
                iconFontSize: Scaler.s(14)
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onClicked: pickerRoot.close()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Scaler.s(14)

            Rectangle {
                Layout.preferredWidth: Scaler.s(180)
                Layout.fillHeight: true
                color: "transparent"
                visible: pickerRoot.places.length > 0

                ColumnLayout {
                    anchors.fill: parent
                    spacing: Scaler.s(2)

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: pickerRoot.places.length * Scaler.s(34)

                        Rectangle {
                            id: activeHighlight
                            width: parent.width
                            height: Scaler.s(34)
                            radius: pickerRoot.crSmall
                            color: ThemeBackend.mauve
                            z: 0
                            visible: pickerRoot.currentPlaceIndex !== -1
                            opacity: pickerRoot.currentPlaceIndex !== -1 ? 1.0 : 0.0

                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            property int curIdx: pickerRoot.currentPlaceIndex
                            property real targetY: curIdx >= 0 ? curIdx * Scaler.s(34) : 0
                            y: targetY

                            Behavior on y {
                                NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                            }
                        }

                        Column {
                            anchors.fill: parent
                            spacing: 0

                            Repeater {
                                model: pickerRoot.places

                                Rectangle {
                                    width: parent.width
                                    height: Scaler.s(34)
                                    radius: pickerRoot.crSmall
                                    z: 1

                                    property bool isActive: pickerRoot.currentPlaceIndex === index
                                    color: isActive ? "transparent" : (placeMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.5) : "transparent")

                                    Behavior on color {
                                        ColorAnimation { duration: 150 }
                                    }

                                    scale: placeMa.pressed ? 0.98 : 1.0
                                    Behavior on scale {
                                        NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Scaler.s(10) + (parent.isActive ? Scaler.s(2) : 0)
                                        anchors.rightMargin: Scaler.s(10)
                                        spacing: Scaler.s(8)

                                        Behavior on anchors.leftMargin {
                                            NumberAnimation { duration: 400; easing.type: Easing.OutQuint }
                                        }

                                        Item {
                                            Layout.preferredWidth: Scaler.s(20)
                                            Layout.alignment: Qt.AlignVCenter

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.icon
                                                font.family: "Iosevka Nerd Font"
                                                font.pixelSize: Scaler.s(16)
                                                color: parent.parent.parent.isActive ? ThemeBackend.crust : (placeMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)

                                                Behavior on color {
                                                    ColorAnimation { duration: 150 }
                                                }
                                            }
                                        }

                                        Text {
                                            text: modelData.name
                                            font.family: ThemeBackend.fontFamily
                                            font.weight: parent.parent.isActive ? Font.Bold : Font.Medium
                                            font.pixelSize: Scaler.s(13)
                                            color: parent.parent.isActive ? ThemeBackend.crust : (placeMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            elide: Text.ElideRight

                                            Behavior on color {
                                                ColorAnimation { duration: 150 }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: placeMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: pickerRoot.gotoFolder(modelData.path)
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                Layout.preferredWidth: 0
                spacing: Scaler.s(10)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Scaler.s(6)

                    IconButton {
                        Layout.preferredWidth: pickerRoot.toolbarHeight
                        Layout.preferredHeight: pickerRoot.toolbarHeight
                        Layout.minimumWidth: pickerRoot.toolbarHeight
                        Layout.maximumWidth: pickerRoot.toolbarHeight
                        cornerRadius: pickerRoot.crSmall
                        buttonIcon: "󰁍"
                        iconFontSize: Scaler.s(16)
                        accentColor: ThemeBackend.surface1
                        textColor: ThemeBackend.text
                        enabled: folderModel.folder.toString() !== "file:///"
                        onClicked: {
                            pickerRoot.gotoFolder(folderModel.parentFolder);
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.minimumWidth: Scaler.s(50)
                        Layout.preferredHeight: pickerRoot.toolbarHeight
                        radius: pickerRoot.crSmall
                        color: ThemeBackend.surface0
                        clip: true

                        Flickable {
                            id: breadcrumbFlickable
                            anchors.fill: parent
                            contentWidth: breadcrumbRow.width
                            boundsBehavior: Flickable.StopAtBounds
                            clip: true

                            onContentWidthChanged: {
                                Qt.callLater(() => {
                                    if (breadcrumbFlickable.contentWidth > breadcrumbFlickable.width) {
                                        breadcrumbFlickable.contentX = breadcrumbFlickable.contentWidth - breadcrumbFlickable.width;
                                    } else {
                                        breadcrumbFlickable.contentX = 0;
                                    }
                                });
                            }

                            Row {
                                id: breadcrumbRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Scaler.s(2)
                                leftPadding: Scaler.s(6)
                                rightPadding: Scaler.s(6)

                                Repeater {
                                    id: breadcrumbRepeater
                                    model: {
                                        let rawPath = folderModel.folder.toString().replace("file://", "");
                                        try {
                                            rawPath = decodeURIComponent(rawPath);
                                        } catch (e) {}
                                        let parts = rawPath.split("/").filter(p => p !== "");
                                        let rootName = typeof I18n !== "undefined" ? I18n.t("guide.file_picker.root") : "Root";
                                        let arr = [{ name: rootName, path: "file:///" }];
                                        let cp = "";
                                        for (let i = 0; i < parts.length; i++) {
                                            cp += "/" + parts[i];
                                            arr.push({ name: parts[i], path: pickerRoot.fileUrl(cp) });
                                        }
                                        return arr;
                                    }

                                    delegate: Row {
                                        spacing: Scaler.s(2)
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            text: "󰅂"
                                            color: ThemeBackend.surface2
                                            font.family: "Iosevka Nerd Font"
                                            font.pixelSize: Scaler.s(14)
                                            visible: index > 0
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Rectangle {
                                            property bool isCurrent: index === breadcrumbRepeater.count - 1
                                            height: pickerRoot.toolbarHeight - Scaler.s(6)
                                            width: bcTxt.implicitWidth + Scaler.s(14)
                                            radius: Scaler.s(6)
                                            color: isCurrent ? ThemeBackend.surface1 : (bcMa.containsMouse ? ThemeBackend.surface0 : "transparent")
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                id: bcTxt
                                                anchors.centerIn: parent
                                                text: modelData.name
                                                font.family: ThemeBackend.fontFamily
                                                color: parent.isCurrent ? ThemeBackend.mauve : (bcMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                                                font.pixelSize: Scaler.s(12)
                                            }

                                            MouseArea {
                                                id: bcMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: pickerRoot.gotoFolder(modelData.path)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        visible: !pickerRoot.mediaPicker
                        Layout.preferredWidth: Scaler.s(84)
                        Layout.preferredHeight: pickerRoot.toolbarHeight
                        Layout.minimumWidth: Scaler.s(84)
                        Layout.maximumWidth: Scaler.s(84)
                        radius: pickerRoot.crSmall
                        color: ThemeBackend.surface0
                        clip: true

                        Toggle {
                            id: hiddenToggle
                            anchors.fill: parent
                            buttonText: ""
                            buttonIcon: "󰈈"
                            iconFontSize: Scaler.s(16)
                            accentColor: ThemeBackend.mauve
                            baseColor: "transparent"
                            cornerRadius: pickerRoot.crSmall
                            textColor: ThemeBackend.text
                            checked: folderModel.showHidden
                            onToggled: function(chk) {
                                folderModel.showHidden = chk;
                            }
                        }
                    }

                    Repeater {
                        model: pickerRoot.mediaPicker ? ["image", "video"] : []
                        IconButton {
                            required property string modelData
                            Layout.preferredWidth: pickerRoot.toolbarHeight
                            Layout.preferredHeight: pickerRoot.toolbarHeight
                            buttonIcon: modelData === "image" ? "󰋩" : "󰕧"
                            iconFontSize: Scaler.s(16)
                            cornerRadius: pickerRoot.crSmall
                            accentColor: pickerRoot.mediaType === modelData ? ThemeBackend.mauve : ThemeBackend.surface0
                            textColor: pickerRoot.mediaType === modelData ? ThemeBackend.base : ThemeBackend.text
                            Accessible.name: I18n.t(modelData === "image" ? "guide.file_picker.images" : "guide.file_picker.videos")
                            ToolTip.visible: isHoveredOrHighlighted
                            ToolTip.text: Accessible.name
                            onClicked: pickerRoot.setMediaType(modelData)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Scaler.s(6)

                    Input {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredHeight: pickerRoot.toolbarHeight
                        leadingIcon: "󰍉"
                        showClearButton: true
                        placeholderText: {
                            let raw = typeof I18n !== "undefined" ? I18n.t("guide.file_picker.input_placeholder") : "Search...";
                            let cleaned = raw.replace(/^[\uE000-\uF8FF\s]+/g, "").trim();
                            return cleaned !== "" ? cleaned : "Search...";
                        }
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: "transparent"
                        cornerRadius: pickerRoot.crSmall
                        horizontalPadding: Scaler.s(10)
                        verticalPadding: Scaler.s(4)
                        fontPixelSize: Scaler.s(12)
                        onTextEdited: function(txt) {
                            searchDebounceTimer.restart();
                        }
                        onCleared: {
                            searchDebounceTimer.restart();
                        }
                        onAccepted: pickerRoot.confirmSelection()
                    }
                    Toggle {
                        visible: pickerRoot.mediaPicker
                        Layout.preferredHeight: pickerRoot.toolbarHeight
                        implicitWidth: Scaler.s(205)
                        buttonText: I18n.t("guide.file_picker.show_thumbnails")
                        buttonIcon: "󰋩"
                        textFontSize: Scaler.s(11)
                        checked: pickerRoot.showThumbnails
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        onToggled: checked => Config.setSetting("mediaPicker.showThumbnails", checked)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 0
                    color: ThemeBackend.surface0
                    radius: pickerRoot.crMedium
                    clip: true

                    Text {
                        anchors.centerIn: parent
                        text: typeof I18n !== "undefined" ? I18n.t("guide.file_picker.not_found") : "No files found"
                        color: ThemeBackend.subtext0
                        font.pixelSize: Scaler.s(14)
                        font.family: ThemeBackend.fontFamily
                        visible: pickerRoot.fileView.count === 0
                    }

                    ListView {
                        id: listView
                        anchors.fill: parent
                        anchors.margins: Scaler.s(2)
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        focus: visible
                        visible: !pickerRoot.showThumbnails
                        model: visible && pickerRoot.visible ? folderModel : null
                        delegate: fileDelegate
                    }

                    GridView {
                        id: gridView
                        anchors.fill: parent
                        anchors.margins: Scaler.s(4)
                        cellWidth: width / 5
                        cellHeight: cellWidth * 0.75 + Scaler.s(24)
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true
                        focus: visible
                        visible: pickerRoot.showThumbnails
                        cacheBuffer: 0
                        reuseItems: true
                        model: visible && pickerRoot.visible ? galleryModel : null
                        delegate: fileDelegate
                    }
                }
            }

            Loader {
                Layout.preferredWidth: pickerRoot.previewWidth
                Layout.fillHeight: true
                active: pickerRoot.visible && pickerRoot.showPreview
                sourceComponent: pickerRoot.previewComponent
                visible: pickerRoot.showPreview
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Scaler.s(14)

            Text {
                Layout.fillWidth: true
                text: {
                    if (pickerRoot.selectedFileName !== "") {
                        return pickerRoot.selectedFileName;
                    }
                    return typeof I18n !== "undefined" ? I18n.t("guide.file_picker.no_file_selected") : "No file selected";
                }
                color: pickerRoot.selectedFileName !== "" ? ThemeBackend.text : ThemeBackend.subtext0
                font.pixelSize: Scaler.s(14)
                font.family: ThemeBackend.fontFamily
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: Scaler.s(6)

                IconButton {
                    Layout.preferredWidth: pickerRoot.actionHeight
                    Layout.preferredHeight: pickerRoot.actionHeight
                    cornerRadius: pickerRoot.crMedium
                    buttonIcon: "󰅖"
                    iconFontSize: Scaler.s(18)
                    accentColor: ThemeBackend.surface1
                    textColor: ThemeBackend.text
                    onClicked: {
                        pickerRoot.fileSelected("", "");
                        pickerRoot.close();
                    }
                }

                IconButton {
                    Layout.preferredWidth: pickerRoot.actionHeight
                    Layout.preferredHeight: pickerRoot.actionHeight
                    cornerRadius: pickerRoot.crMedium
                    buttonIcon: "󰄬"
                    iconFontSize: Scaler.s(18)
                    accentColor: pickerRoot.selectedFilePath !== "" ? ThemeBackend.mauve : ThemeBackend.surface0
                    textColor: pickerRoot.selectedFilePath !== "" ? ThemeBackend.crust : ThemeBackend.subtext0
                    enabled: pickerRoot.selectedFilePath !== ""
                    onClicked: pickerRoot.confirmSelection()
                }
            }
        }
    }
}
