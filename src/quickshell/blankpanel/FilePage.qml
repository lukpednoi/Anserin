import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../"
import "../reusables"

// The left panel's File page (the folder button in its topbar): one folder as a grid of tiles in the Launcher's
// emoji-grid look (the theme's glyphs, coloured by kind; images as their own cropped pictures), folders first, hidden
// files hidden. Each folder comes in row by row as the Launcher's lists do. Where it is, the history and the cut/copied items are kept by the panel
// (BlankPanel: filePath, fileGo, fileClip), so the topbar path and the sidebar's places follow it.
//   Mouse: a click selects (Ctrl adds, Shift a range), a double click opens (a folder here, a file in its
//   application, and the panel closes), the back/forward mouse buttons and Backspace go back/forward.
//   Right-click an item: Open, Open With…, Extract Here (an archive: beside it, one top item as it is, more in a
//   folder named after it, nothing overwritten), Cut, Copy, Rename, Change Extension (a file: the field opens with
//   only its extension picked), Move to Trash, Copy Path, Open in Dolphin.
//   Right-click the empty space: Paste, New Folder, New File (an empty "New File.txt", named in place at once),
//   Open Terminal Here, Show/Hide Hidden Files.
// Outside the Trash nothing is deleted for good: Move to Trash uses the Trash Dolphin uses, and a paste over a name
// already there asks first (Replace sends the old one to the Trash). The work is done by file_tool.py.
// The Trash shows ~/.local/share/Trash/files: right-click an item for Remove (for good, asked first) and Restore (back
// where it came from, asking as a paste does over a name already there); the empty space has Empty Trash (asked first).
Item {
    id: page
    required property var panel
    property bool active: false

    function s(v) { return panel.s(v); }

    readonly property string home: Quickshell.env("HOME")
    readonly property string trashDir: home + "/.local/share/Trash/files"
    readonly property bool inTrash: panel.filePath === trashDir || panel.filePath.startsWith(trashDir + "/")
    readonly property string toolPath: decodeURIComponent(Qt.resolvedUrl("file_tool.py").toString().replace(/^file:\/\//, ""))
    property bool showHidden: false

    // ---------- the folder ----------
    FolderListModel {
        id: folder
        folder: page.toUrl(page.panel.filePath)
        showDirsFirst: true
        showDotAndDotDot: false
        showHidden: page.showHidden
        sortCaseSensitive: false
        nameFilters: []
        onStatusChanged: if (status === FolderListModel.Ready) { page.playIntro(); page.afterLoad(); }
        onCountChanged: page.afterLoad()
    }

    function toUrl(p) { return "file://" + p.split("/").map(encodeURIComponent).join("/"); }
    function indexOfPath(p) { for (let i = 0; i < folder.count; i++) if (folder.get(i, "filePath") === p) return i; return -1; }

    // ---------- selection ----------
    property var selected: ({})
    property int anchorIndex: -1
    readonly property var selectedPaths: Object.keys(selected)
    function clearSelection() { selected = ({}); anchorIndex = -1; }
    function selectOnly(i) { const p = folder.get(i, "filePath"); selected = ({ [p]: true }); anchorIndex = i; }
    function toggleSelect(i) {
        const p = folder.get(i, "filePath"), next = Object.assign({}, selected);
        if (next[p]) delete next[p]; else next[p] = true;
        selected = next; anchorIndex = i;
    }
    function selectRange(i) {
        if (anchorIndex < 0) { selectOnly(i); return; }
        const next = {};
        for (let k = Math.min(anchorIndex, i); k <= Math.max(anchorIndex, i); k++) next[folder.get(k, "filePath")] = true;
        selected = next;
    }
    Connections {
        target: page.panel
        function onFilePathChanged() {
            page.clearSelection(); page.renaming = ""; page.pendingSelect = ""; menu.close(); ask.q = null;
            page.startIntro();
            grid.positionViewAtBeginning();
        }
    }

    // ---------- opening ----------
    function openItem(i) {
        const p = folder.get(i, "filePath");
        if (folder.get(i, "fileIsDir")) { panel.fileGo(p); return; }
        Quickshell.execDetached(["xdg-open", p]);
        panel.closePanel();
    }
    function openInDolphin(p) {
        if (p === "") Quickshell.execDetached(["dolphin", "--new-window", inTrash ? "trash:/" : panel.filePath]);
        else Quickshell.execDetached(["dolphin", "--new-window", "--select", p]);
        panel.closePanel();
    }

    // ---------- the tool (one job at a time) ----------
    property var toolDone: null
    function runTool(args, done) {
        if (tool.running) { toast("Still working on the last one…"); return; }
        toolDone = done;
        tool.command = ["python3", toolPath].concat(args);
        tool.running = true;
    }
    Process {
        id: tool
        stdout: StdioCollector { id: toolOut }
        onExited: {
            let r = {};
            try { r = JSON.parse(toolOut.text.trim().split("\n").pop()); } catch (e) { r = { error: "Something went wrong" }; }
            const done = page.toolDone;
            page.toolDone = null;
            if (r.error) page.toast(r.error);
            else if (r.errors && r.errors.length) page.toast(r.errors[0] + (r.errors.length > 1 ? " (+" + (r.errors.length - 1) + ")" : ""));
            if (done && !r.error) done(r);
        }
    }

    function copyItems(cut) {
        if (!selectedPaths.length) return;
        panel.fileClip = { mode: cut ? "move" : "copy", paths: selectedPaths.slice() };
    }
    function paste(policy) {
        const clip = panel.fileClip;
        if (!clip || !clip.paths.length || inTrash) return;
        runTool(["paste", clip.mode, policy, panel.filePath].concat(clip.paths), r => {
            if (r.conflicts) { page.askReplace(r.conflicts, "here", page.paste); return; }
            if (clip.mode === "move") panel.fileClip = null;
        });
    }
    // ---------- the Trash ----------
    function removeItems() {
        const paths = selectedPaths.slice();
        if (!paths.length || !inTrash) return;
        ask.q = { icon: "󰆴", danger: true,
                  title: paths.length === 1 ? "Remove “" + paths[0].split("/").pop() + "” for good?" : "Remove " + paths.length + " items for good?",
                  note: "This cannot be undone.",
                  buttons: [{ text: "Remove", danger: true, act: () => page.runTool(["remove"].concat(paths), r => page.clearSelection()) },
                            { text: "Cancel" }] };
    }
    function restoreItems(policy) {
        const paths = selectedPaths.slice();
        if (!paths.length || !inTrash) return;
        runTool(["restore", policy].concat(paths), r => {
            if (r.conflicts) { page.askReplace(r.conflicts, "there", page.restoreItems); return; }
            page.clearSelection();
        });
    }
    function emptyTrash() {
        if (!inTrash || folder.count === 0) return;
        ask.q = { icon: "󰩺", danger: true, title: "Empty the Trash?", note: "Everything in it is removed for good.",
                  buttons: [{ text: "Empty", danger: true, act: () => page.runTool(["empty-trash"], r => { page.clearSelection(); page.panel.fileGo(page.trashDir); }) },
                            { text: "Cancel" }] };
    }
    // ---------- drives (the panel's sidebar, under the places) ----------
    // a drive not mounted yet is mounted first (udisks, as Dolphin does), then opened
    function openDrive(dev, mount) {
        if (mount !== "") { panel.fileGo(mount); return; }
        runTool(["mount", dev], r => { if (r.mount) panel.fileGo(r.mount); });
    }
    // right-click a plugged-in drive: Eject, the menu at the page's right edge beside it
    function driveMenu(dev, mount, y) {
        menu.openWith(page.width, y, [{ icon: "󰇪", text: "Eject", act: () => page.eject(dev, mount) }]);
    }
    function eject(dev, mount) {
        runTool(["eject", dev], r => {
            if (mount !== "" && (panel.filePath === mount || panel.filePath.startsWith(mount + "/"))) panel.fileGo(panel.fileHome);
            toast("Safe to unplug");
        });
    }
    // ---------- archives ----------
    // what bsdtar (or unrar) can unpack, by name
    function isArchive(p) { return /\.(zip|7z|rar|tar|tgz|txz|tbz2?|tzst|iso|cpio|jar|xpi|apk)$|\.tar\.(gz|xz|bz2|zst|lz4)$/i.test(p); }
    // Extract Here: beside the archive (file_tool.py extract), then the new item is picked out
    function extractItem(p) {
        toast("Extracting…");
        runTool(["extract", p], r => {
            toast("Extracted “" + r.name + "”");
            page.pendingSelect = panel.filePath + "/" + r.name;
            page.afterLoad();
        });
    }
    // names already where the items are going ("here" for a paste, "there" for a restore): Replace / Skip / Cancel,
    // then `retry(policy)`
    function askReplace(names, where, retry) {
        ask.q = { icon: "󰉓", note: "Replace sends the ones " + where + " to the Trash.",
                  title: names.length === 1 ? "“" + names[0] + "” is already " + where + "." : names.length + " items are already " + where + ".",
                  buttons: [{ text: "Replace", primary: true, act: () => retry("replace") }, { text: "Skip", act: () => retry("skip") }, { text: "Cancel" }] };
    }
    function trashItems() {
        if (!selectedPaths.length || inTrash) return;
        runTool(["trash"].concat(selectedPaths), r => page.clearSelection());
    }
    function newFolder() {
        if (inTrash) return;
        runTool(["new-folder", panel.filePath], r => { page.pendingRename = panel.filePath + "/" + r.name; page.afterLoad(); });
    }
    // an empty text file, named in place right away as a new folder is (the name picked, ".txt" left as it is)
    function newFile() {
        if (inTrash) return;
        runTool(["new-file", panel.filePath], r => { page.pendingRename = panel.filePath + "/" + r.name; page.afterLoad(); });
    }

    // ---------- renaming in place ----------
    property string renaming: ""          // the path being renamed
    property bool renamingExt: false      // Change Extension: the field opens with only the part after the last dot picked
    property string pendingRename: ""     // a new folder to rename once it shows up
    property string pendingSelect: ""     // an extracted item to pick out once it shows up
    onRenamingChanged: { panel.fileTyping = renaming !== ""; if (renaming === "") renamingExt = false; }
    Component.onDestruction: panel.fileTyping = false
    function afterLoad() {
        if (pendingSelect !== "") {
            const k = indexOfPath(pendingSelect);
            if (k >= 0) { selectOnly(k); grid.positionViewAtIndex(k, GridView.Contain); pendingSelect = ""; }
        }
        if (pendingRename === "") return;
        const i = indexOfPath(pendingRename);
        if (i < 0) return;
        selectOnly(i);
        renaming = pendingRename;
        pendingRename = "";
        grid.positionViewAtIndex(i, GridView.Contain);
    }
    function commitRename(path, name) {
        renaming = "";
        page.forceActiveFocus();
        const old = path.split("/").pop();
        if (name.endsWith(".") && !old.endsWith(".")) name = name.slice(0, -1);   // Change Extension left empty
        if (name === "" || name === old) return;
        runTool(["rename", path, name], r => { page.clearSelection(); });
    }

    function copyPath(p) { Quickshell.execDetached(["wl-copy", p]); toast("Path copied"); }

    // ---------- keys ----------
    focus: true
    // Esc first closes what is open here (the menu, the replace question, the selection); only then does it reach the
    // panel's own Esc and close the panel. The panel's Esc is a window shortcut, so it is claimed before it fires.
    readonly property bool escapeHere: menu.shown || ask.open || selectedPaths.length > 0
    Keys.onShortcutOverride: (e) => { if (e.key === Qt.Key_Escape && escapeHere) e.accepted = true; }
    Keys.onPressed: (e) => {
        if (renaming !== "") return;
        if (e.key === Qt.Key_Backspace) { panel.fileBack(); e.accepted = true; }
        else if (e.key === Qt.Key_Escape && escapeHere) {
            if (menu.shown) menu.close(); else if (ask.open) ask.q = null; else clearSelection();
            e.accepted = true;
        }
    }

    // ---------- icons: the theme's glyphs, coloured by kind (folders in the accent) ----------
    readonly property var specialDirs: ({ Desktop: "󰍹", Documents: "󰲂", Downloads: "󰉍", Music: "󱍙", Pictures: "󰉏",
                                          Videos: "󱧺", Templates: "󱋣", Public: "󰉌" })
    // extension: [glyph, kind]
    readonly property var kinds: ({
        txt: ["󰈙", "text"], log: ["󰈙", "text"], md: ["󰍔", "text"], pdf: ["󰈦", "pdf"],
        png: ["󰈟", "image"], jpg: ["󰈟", "image"], jpeg: ["󰈟", "image"], gif: ["󰈟", "image"], webp: ["󰈟", "image"],
        bmp: ["󰈟", "image"], svg: ["󰈟", "image"], avif: ["󰈟", "image"],
        mp3: ["󰈣", "audio"], flac: ["󰈣", "audio"], ogg: ["󰈣", "audio"], wav: ["󰈣", "audio"], m4a: ["󰈣", "audio"], opus: ["󰈣", "audio"],
        mp4: ["󰈫", "video"], mkv: ["󰈫", "video"], webm: ["󰈫", "video"], mov: ["󰈫", "video"], avi: ["󰈫", "video"],
        zip: ["󰗄", "archive"], tar: ["󰗄", "archive"], gz: ["󰗄", "archive"], xz: ["󰗄", "archive"], zst: ["󰗄", "archive"],
        "7z": ["󰗄", "archive"], rar: ["󰗄", "archive"], deb: ["󰏖", "archive"], iso: ["󰗮", "archive"],
        sh: ["󰆍", "code"], py: ["󰌠", "code"], js: ["󰌞", "code"], ts: ["󰛦", "code"], qml: ["󰈮", "code"], json: ["󰘦", "code"],
        html: ["󰌝", "code"], css: ["󰌜", "code"], c: ["󰙱", "code"], cpp: ["󰙲", "code"], h: ["󰈮", "code"], rs: ["󱘗", "code"],
        lua: ["󰢱", "code"], go: ["󰟓", "code"], java: ["󰬷", "code"],
        doc: ["󰈬", "office"], docx: ["󰈬", "office"], odt: ["󰈬", "office"],
        xls: ["󰈛", "office"], xlsx: ["󰈛", "office"], ods: ["󰈛", "office"],
        ppt: ["󰈧", "office"], pptx: ["󰈧", "office"], odp: ["󰈧", "office"],
        desktop: ["󰣆", "code"], ttf: ["󰛖", "text"], otf: ["󰛖", "text"]
    })
    readonly property var kindColors: ({ text: ThemeBackend.subtext1, pdf: ThemeBackend.red, image: ThemeBackend.blue,
                                         audio: ThemeBackend.green, video: ThemeBackend.peach, archive: ThemeBackend.yellow,
                                         code: ThemeBackend.teal, office: ThemeBackend.sapphire })
    readonly property var thumbable: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg", "avif"]
    function glyphFor(name, ext, isDir, path) {
        if (isDir) return path.startsWith(home + "/") && path.split("/").length === home.split("/").length + 1 && specialDirs[name]
                          ? specialDirs[name] : "󰉋";
        return (kinds[ext] || ["󰈤"])[0];
    }
    function colorFor(ext, isDir) {
        if (isDir) return ThemeBackend.mauve;
        return kindColors[(kinds[ext] || [])[1]] || ThemeBackend.subtext0;
    }

    // ---------- each folder comes in row by row (the Launcher's grid intro) ----------
    property real introItems: 1
    property bool introPending: true
    function itemProgress(row) {
        if (introItems >= 1) return 1;
        if (introItems <= 0) return 0;
        const p = Math.min(1, Math.max(0, (introItems - Math.min(row, 10) * 0.04) / 0.42));
        if (p <= 0 || p >= 1) return p;
        const c1 = 0.85, c3 = c1 + 1;
        return 1 + c3 * Math.pow(p - 1, 3) + c1 * Math.pow(p - 1, 2);
    }
    function itemOpacity(row) {
        if (introItems >= 1) return 1;
        if (introItems <= 0) return 0;
        return Math.min(1, Math.max(0, (introItems - Math.min(row, 10) * 0.04) / 0.28));
    }
    function playIntro() {
        if (!introPending) return;
        introPending = false;
        introTimeout.stop();
        itemsIntro.restart();
    }
    SequentialAnimation {
        id: itemsIntro
        PauseAnimation { duration: 40 }
        NumberAnimation { target: page; property: "introItems"; from: 0; to: 1; duration: 520; easing.type: Easing.Linear }
    }
    // a folder that takes long to read still comes in
    Timer { id: introTimeout; interval: 400; onTriggered: page.playIntro() }
    function startIntro() { itemsIntro.stop(); introItems = 0; introPending = true; introTimeout.restart(); }
    Component.onCompleted: startIntro()

    // ---------- the grid ----------
    GridView {
        id: grid
        anchors.fill: parent
        anchors.margins: page.s(4)
        clip: true
        model: folder
        boundsBehavior: Flickable.StopAtBounds
        readonly property int columns: Math.max(1, Math.floor(width / page.s(108)))
        cellWidth: width / columns
        cellHeight: page.s(116)
        cacheBuffer: page.s(400)
        // reached and stopped like the panel's other pages; the wheel scrolls it
        flickDeceleration: 4000

        // a left press on the empty space closes the menu or clears the selection: the view keeps the left button for
        // flicking, so a handler on the view sees it (a press on an item is the item's)
        TapHandler {
            acceptedButtons: Qt.LeftButton
            onPressedChanged: {
                if (!pressed) return;
                page.forceActiveFocus();
                if (menu.shown) menu.close(); else page.clearSelection();
            }
        }
        // the other buttons on the empty space (behind the items, as tall as the view): right-click menu, back/forward
        MouseArea {
            width: grid.width
            height: Math.max(grid.height, grid.contentHeight)
            z: -1
            acceptedButtons: Qt.RightButton | Qt.BackButton | Qt.ForwardButton
            onPressed: (m) => {
                page.forceActiveFocus();
                if (m.button === Qt.BackButton) { page.panel.fileBack(); return; }
                if (m.button === Qt.ForwardButton) { page.panel.fileForward(); return; }
                if (menu.shown) { menu.close(); return; }
                page.clearSelection();
                if (m.button === Qt.RightButton) { const p = mapToItem(page, m.x, m.y); menu.openAt(p.x, p.y, ""); }
            }
        }

        delegate: Item {
            id: cell
            required property int index
            required property string fileName
            required property string filePath
            required property url fileUrl
            required property bool fileIsDir
            width: grid.cellWidth
            height: grid.cellHeight
            readonly property bool isSelected: page.selected[filePath] === true
            readonly property bool isCut: page.panel.fileClip && page.panel.fileClip.mode === "move" && page.panel.fileClip.paths.indexOf(filePath) >= 0
            // the last part after a dot (the model's suffix is everything after the first dot: "960x540.mp4")
            readonly property string ext: fileName.lastIndexOf(".") > 0 ? fileName.slice(fileName.lastIndexOf(".") + 1).toLowerCase() : ""
            readonly property bool thumb: !fileIsDir && page.thumbable.indexOf(ext) >= 0
            readonly property int row: Math.floor(index / grid.columns)

            opacity: page.itemOpacity(row)
            transform: Translate { y: page.s(15) * (1 - page.itemProgress(cell.row)) }

            // the tile: the Launcher's emoji tiles (selected in the accent, a lift under the pointer, a dip when pressed)
            Item {
                id: tile
                anchors.fill: parent
                anchors.margins: page.s(4)
                scale: cellMa.pressed ? 0.94 : cellMa.containsMouse && !cell.isSelected ? 1.03 : 1
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.25 } }

                Rectangle {
                    anchors.fill: parent
                    radius: ThemeBackend.borderRadius
                    color: cell.isSelected ? ThemeBackend.mauve
                         : cellMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.7) : Qt.alpha(ThemeBackend.surface0, 0.45)
                    border.width: cell.isSelected ? 0 : 1
                    border.color: Qt.alpha(ThemeBackend.surface2, 0.3)
                    Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                Item {
                    id: iconBox
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: page.s(10)
                    width: page.s(54); height: width
                    opacity: cell.isCut ? 0.4 : 1
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    // an image: its own picture, cropped square with the theme's corners, fading in once read
                    ClippingRectangle {
                        anchors.fill: parent
                        visible: cell.thumb
                        radius: Math.max(0, ThemeBackend.borderRadius - page.s(2))
                        color: Qt.alpha(ThemeBackend.surface1, 0.5)
                        border.width: cell.isSelected ? page.s(2) : 0
                        border.color: ThemeBackend.crust
                        Image {
                            id: thumbImage
                            anchors.fill: parent
                            source: cell.thumb ? cell.fileUrl : ""
                            sourceSize.width: page.s(108)
                            sourceSize.height: page.s(108)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            opacity: status === Image.Ready ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !cell.thumb || thumbImage.status === Image.Error
                        text: page.glyphFor(cell.fileName, cell.ext, cell.fileIsDir, cell.filePath)
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: page.s(cell.fileIsDir ? 46 : 40)
                        color: cell.isSelected ? ThemeBackend.crust : page.colorFor(cell.ext, cell.fileIsDir)
                        Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    }
                }

                Text {
                    visible: page.renaming !== cell.filePath
                    anchors.top: iconBox.bottom
                    anchors.topMargin: page.s(6)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - page.s(12)
                    text: cell.fileName
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    lineHeight: 0.95
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: page.s(11)
                    font.weight: cell.isSelected ? Font.Bold : Font.Normal
                    color: cell.isSelected ? ThemeBackend.crust : cellMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                    opacity: cell.isCut ? 0.6 : 1
                    Behavior on color { ColorAnimation { duration: 140; easing.type: Easing.OutCubic } }
                }

                // renaming: the name becomes a field; Enter keeps it, Esc or clicking elsewhere leaves it
                Rectangle {
                    visible: page.renaming === cell.filePath
                    anchors.top: iconBox.bottom
                    anchors.topMargin: page.s(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - page.s(10)
                    height: nameField.implicitHeight + page.s(8)
                    radius: Math.max(0, ThemeBackend.borderRadius - page.s(2))
                    color: ThemeBackend.base
                    border.width: 1
                    border.color: ThemeBackend.mauve
                    TextInput {
                        id: nameField
                        anchors.fill: parent
                        anchors.margins: page.s(4)
                        horizontalAlignment: TextInput.AlignHCenter
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: page.s(11)
                        color: ThemeBackend.text
                        selectionColor: Qt.alpha(ThemeBackend.mauve, 0.45)
                        selectedTextColor: ThemeBackend.text
                        property bool armed: false
                        onVisibleChanged: {
                            if (!visible) { armed = false; return; }
                            text = cell.fileName;
                            const dot = cell.fileIsDir ? -1 : text.lastIndexOf(".");
                            forceActiveFocus();
                            if (page.renamingExt) {
                                // the extension picked (a name without one gets a dot to type it after)
                                if (dot <= 0) { text = text + "."; cursorPosition = text.length; }
                                else select(dot + 1, text.length);
                            } else select(0, dot > 0 ? dot : text.length);
                            armed = true;
                        }
                        Keys.onReturnPressed: page.commitRename(cell.filePath, text.trim())
                        Keys.onEnterPressed: page.commitRename(cell.filePath, text.trim())
                        Keys.onShortcutOverride: (e) => { if (e.key === Qt.Key_Escape) e.accepted = true; }
                        Keys.onEscapePressed: { page.renaming = ""; page.forceActiveFocus(); }
                        onActiveFocusChanged: if (!activeFocus && armed && page.renaming === cell.filePath) page.renaming = ""
                    }
                }
            }

            MouseArea {
                id: cellMa
                anchors.fill: parent
                anchors.margins: page.s(4)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.BackButton | Qt.ForwardButton
                onPressed: (m) => {
                    if (page.renaming === cell.filePath) { m.accepted = false; return; }
                    page.forceActiveFocus();
                    if (m.button === Qt.BackButton) { page.panel.fileBack(); return; }
                    if (m.button === Qt.ForwardButton) { page.panel.fileForward(); return; }
                    if (menu.shown) menu.close();
                    if (m.button === Qt.RightButton) {
                        if (!cell.isSelected) page.selectOnly(cell.index);
                        const p = mapToItem(page, m.x, m.y);
                        menu.openAt(p.x, p.y, cell.filePath);
                        return;
                    }
                    if (m.modifiers & Qt.ShiftModifier) page.selectRange(cell.index);
                    else if (m.modifiers & Qt.ControlModifier) page.toggleSelect(cell.index);
                    else page.selectOnly(cell.index);
                }
                onDoubleClicked: (m) => { if (m.button === Qt.LeftButton) page.openItem(cell.index); }
            }
        }
    }

    // an empty folder says so (as the Launcher's "nothing found")
    Column {
        anchors.centerIn: parent
        spacing: page.s(6)
        visible: folder.status === FolderListModel.Ready && folder.count === 0 && !page.introPending
        opacity: page.itemOpacity(0)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: page.inTrash ? "󰩺" : "󰉖"
            font.family: ThemeBackend.iconFont
            font.pixelSize: page.s(28)
            color: ThemeBackend.subtext0
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: page.inTrash ? "The Trash is empty" : "This folder is empty"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: page.s(12)
            color: ThemeBackend.subtext0
        }
    }

    // ---------- the right-click menu (the desktop menu's look and its quick scale-in) ----------
    Item {
        id: menu
        property bool shown: false
        property string target: ""         // the item right-clicked, or "" for the empty space
        property var entries: []
        property real animProgress: 0
        z: 10
        visible: shown || closeAnim.running
        width: page.s(190)
        height: menuCol.implicitHeight + page.s(8)
        property real ax: 0
        property real ay: 0
        x: Math.max(page.s(4), Math.min(page.width - width - page.s(4), ax))
        y: Math.max(page.s(4), Math.min(page.height - height - page.s(4), ay))
        opacity: 0.75 + 0.25 * animProgress
        transform: Scale {
            origin.x: Math.max(0, Math.min(menu.width, menu.ax - menu.x))
            origin.y: Math.max(0, Math.min(menu.height, menu.ay - menu.y))
            xScale: 0.92 + 0.08 * menu.animProgress
            yScale: 0.92 + 0.08 * menu.animProgress
        }
        NumberAnimation { id: openAnim; target: menu; property: "animProgress"; from: 0; to: 1; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { id: closeAnim; target: menu; property: "animProgress"; to: 0; duration: 60; easing.type: Easing.InQuad }

        function itemEntries(p) {
            const n = page.selectedPaths.length;
            if (page.inTrash) return [
                { icon: "󰆴", text: "Remove", act: () => page.removeItems(), danger: true },
                { icon: "󰦛", text: "Restore", act: () => page.restoreItems("ask") }
            ];
            return [
                { icon: "󰏌", text: "Open", act: () => page.openItem(page.indexOfPath(p)), on: n === 1 },
                { icon: "󰘔", text: "Open With…", act: () => menu.showApps(p), keep: true, on: n === 1 && !page.isDir(p) },
                { icon: "󱉛", text: "Extract Here", act: () => page.extractItem(p), on: n === 1, show: page.isArchive(p) },
                { icon: "󰆐", text: "Cut", act: () => page.copyItems(true) },
                { icon: "󰆏", text: "Copy", act: () => page.copyItems(false) },
                { icon: "󰑕", text: "Rename", act: () => { page.renamingExt = false; page.renaming = p; }, on: n === 1 },
                { icon: "󰬲", text: "Change Extension", act: () => { page.renamingExt = true; page.renaming = p; }, on: n === 1 && !page.isDir(p) },
                { icon: "󰩺", text: "Move to Trash", act: () => page.trashItems(), danger: true },
                { icon: "󰅍", text: "Copy Path", act: () => page.copyPath(p), on: n === 1 },
                { icon: "󰉋", text: "Open in Dolphin", act: () => page.openInDolphin(p), on: n === 1 }
            ];
        }
        function spaceEntries() {
            const clip = page.panel.fileClip;
            if (page.inTrash) return [
                { icon: "󰩺", text: "Empty Trash", act: () => page.emptyTrash(), danger: true, on: folder.count > 0 },
                { icon: page.showHidden ? "󰈉" : "󰈈", text: page.showHidden ? "Hide Hidden Files" : "Show Hidden Files",
                  act: () => { page.showHidden = !page.showHidden; } }
            ];
            return [
                { icon: "󰆒", text: "Paste", act: () => page.paste("ask"), on: !page.inTrash && !!clip && clip.paths.length > 0 },
                { icon: "󰉗", text: "New Folder", act: () => page.newFolder(), on: !page.inTrash },
                { icon: "󰝒", text: "New File", act: () => page.newFile(), on: !page.inTrash },
                { icon: "󰆍", text: "Open Terminal Here", act: () => { Quickshell.execDetached(["kitty", "--directory", page.panel.filePath]); page.panel.closePanel(); }, on: !page.inTrash },
                { icon: page.showHidden ? "󰈉" : "󰈈", text: page.showHidden ? "Hide Hidden Files" : "Show Hidden Files",
                  act: () => { page.showHidden = !page.showHidden; } }
            ];
        }
        function openAt(x, y, p) {
            target = p;
            openWith(x, y, p === "" ? spaceEntries() : itemEntries(p));
        }
        function openWith(x, y, list) {
            entries = list.filter(e => e.show !== false);      // `show: false` leaves an entry out (`on` greys it)
            ax = x; ay = y;
            shown = true;
            closeAnim.stop(); animProgress = 0; openAnim.restart();
        }
        function close() {
            if (!shown) return;
            shown = false;
            openAnim.stop(); closeAnim.restart();
        }
        // Open With…: the menu turns into the list of applications for the file
        function showApps(p) {
            entries = [{ icon: "󰇘", text: "Looking…", act: () => {}, on: false, keep: true }];
            page.runTool(["apps", p], r => {
                if (!menu.shown) return;
                const list = (r.apps || []).map(a => ({ app: a.icon || "application-x-executable", text: a.name,
                                                        act: () => page.runTool(["open-with", a.id, p], () => page.panel.closePanel()) }));
                menu.entries = [{ icon: "󰁍", text: "Back", act: () => { menu.entries = menu.itemEntries(p); }, keep: true }]
                               .concat(list.length ? list : [{ icon: "󰅖", text: "No applications", act: () => {}, on: false, keep: true }]);
            });
        }

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.clampedBorderRadius
            color: ThemeBackend.base
            border.width: 1
            border.color: ThemeBackend.surface1
        }
        Column {
            id: menuCol
            x: page.s(4); y: page.s(4)
            width: parent.width - page.s(8)
            spacing: page.s(2)
            Repeater {
                model: menu.entries
                Item {
                    required property var modelData
                    width: menuCol.width
                    height: page.s(29)
                    ClickButton {
                        anchors.fill: parent
                        enabled: parent.modelData.on !== false
                        opacity: enabled ? 1 : 0.4
                        cornerRadius: page.s(8)
                        contentAlignment: Qt.AlignLeft
                        horizontalPadding: page.s(parent.modelData.app ? 32 : 10)
                        buttonIcon: parent.modelData.icon || ""
                        iconFontSize: page.s(15)
                        textFontSize: page.s(12)
                        buttonText: parent.modelData.text
                        accentColor: ThemeBackend.surface0
                        textColor: parent.modelData.danger ? ThemeBackend.red : ThemeBackend.text
                        onClicked: {
                            const e = parent.modelData;
                            if (!e.keep) menu.close();
                            e.act();
                        }
                    }
                    // an application's own icon (Open With…)
                    IconImage {
                        visible: !!parent.modelData.app
                        x: page.s(9)
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: page.s(16)
                        source: parent.modelData.app ? Quickshell.iconPath(parent.modelData.app, "application-x-executable") : ""
                    }
                }
            }
        }
    }
    function isDir(p) { const i = indexOfPath(p); return i >= 0 && folder.get(i, "fileIsDir"); }

    // ---------- a question (a paste or restore over names already there, Remove, Empty Trash): the page dims and a
    // card pops up (the menu's look). q: { icon, title, note, danger, buttons: [{ text, primary, danger, act }] }
    Item {
        id: ask
        property var q: null
        property var shown: null           // the last question, kept while the card fades out
        onQChanged: if (q) shown = q
        readonly property bool open: q !== null
        property real t: open ? 1 : 0
        Behavior on t { NumberAnimation { duration: ask.open ? 240 : 140; easing.type: ask.open ? Easing.OutCubic : Easing.InQuad } }
        z: 11
        anchors.fill: parent
        visible: t > 0

        Rectangle {
            anchors.fill: parent
            radius: ThemeBackend.clampedBorderRadius
            color: Qt.alpha(ThemeBackend.crust, 0.55)
            opacity: ask.t
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: ask.q = null }
        }
        Rectangle {
            id: askCard
            anchors.centerIn: parent
            width: page.s(310)
            height: askCol.implicitHeight + page.s(32)
            radius: ThemeBackend.clampedBorderRadius
            color: ThemeBackend.base
            border.width: 1
            border.color: ThemeBackend.surface1
            opacity: ask.t
            scale: 0.9 + 0.1 * ask.t
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }   // keeps clicks off the page below
            Column {
                id: askCol
                anchors.centerIn: parent
                width: parent.width - page.s(32)
                spacing: page.s(10)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ask.shown ? ask.shown.icon : ""
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: page.s(26)
                    color: ask.shown && ask.shown.danger ? ThemeBackend.red : ThemeBackend.mauve
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    text: ask.shown ? ask.shown.title : ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: page.s(13)
                    font.bold: true
                    color: ThemeBackend.text
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    text: ask.shown ? ask.shown.note : ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: page.s(11)
                    color: ThemeBackend.subtext0
                }
                Item { width: 1; height: page.s(2) }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: page.s(6)
                    Repeater {
                        model: ask.shown ? ask.shown.buttons : []
                        ClickButton {
                            required property var modelData
                            width: page.s(86); height: page.s(30)
                            cornerRadius: page.s(8)
                            buttonText: modelData.text
                            textFontSize: page.s(12)
                            accentColor: modelData.danger ? ThemeBackend.red : modelData.primary ? ThemeBackend.mauve : ThemeBackend.surface0
                            textColor: modelData.danger || modelData.primary ? ThemeBackend.crust : ThemeBackend.text
                            onClicked: {
                                const act = modelData.act;
                                ask.q = null;
                                if (act) act();
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------- a short note at the foot of the page (errors, "Path copied") ----------
    function toast(text) { toastText.text = text; toastAnim.restart(); }
    Rectangle {
        id: toastBox
        z: 12
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: page.s(12)
        width: Math.min(page.width - page.s(24), toastText.implicitWidth + page.s(32))
        height: page.s(34)
        radius: height / 2
        color: ThemeBackend.crust
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.mauve, 0.5)
        opacity: 0
        visible: opacity > 0
        transform: Translate { y: page.s(10) * (1 - toastBox.opacity) }
        Text {
            id: toastText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - page.s(24))
            elide: Text.ElideRight
            font.family: ThemeBackend.fontFamily
            font.pixelSize: page.s(12)
            font.bold: true
            color: ThemeBackend.text
        }
        SequentialAnimation {
            id: toastAnim
            NumberAnimation { target: toastBox; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            PauseAnimation { duration: 1800 }
            NumberAnimation { target: toastBox; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
        }
    }
}
