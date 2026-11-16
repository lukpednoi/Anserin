import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../../../"
import ".."
import "../../../guide/terminal"

// Terminal as a board, all through TerminalAppearance as guide/TerminalTab.qml does: Kitty and desktop
// appearance (blur strength while the background is Blur), scrollable tiling, the infinite desktop
// (guide/terminal/InfiniteDesktopSection.qml) and Fastfetch with its ASCII / picture files
// (guide/terminal/FastfetchSection.qml).
BoardPage {
    id: page
    readonly property var ta: TerminalAppearance.settings
    readonly property var ff: TerminalAppearance.fastfetchSettings
    function opt(key) { return ta[key] || TerminalAppearance.defaults[key]; }
    function names(values) { return values.map(v => I18n.t("guide.terminal.options." + v)); }
    property var asciiNames: []
    property var picNames: []
    function refreshFiles() {
        let n = [];
        for (let i = 0; i < asciiFiles.count; i++) n.push(asciiFiles.get(i, "fileName"));
        asciiNames = n;
        n = [];
        for (let i = 0; i < picFiles.count; i++) n.push(picFiles.get(i, "fileName"));
        picNames = n;
    }
    extras: [
        FolderListModel {
            id: asciiFiles
            folder: "file://" + TerminalAppearance.fastfetchDir + "/ascii"
            nameFilters: ["*.txt"]; caseSensitive: false; showDirs: false; showDotAndDotDot: false; sortField: FolderListModel.Name
            onCountChanged: Qt.callLater(page.refreshFiles); onDataChanged: Qt.callLater(page.refreshFiles); onStatusChanged: Qt.callLater(page.refreshFiles)
        },
        FolderListModel {
            id: picFiles
            folder: "file://" + TerminalAppearance.fastfetchDir + "/pngs"
            nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.gif", "*.bmp", "*.avif"]; caseSensitive: false; showDirs: false; showDotAndDotDot: false; sortField: FolderListModel.Name
            onCountChanged: Qt.callLater(page.refreshFiles); onDataChanged: Qt.callLater(page.refreshFiles); onStatusChanged: Qt.callLater(page.refreshFiles)
        }
    ]

    BoardCard {
        title: "Desktop & Appearance"; icon: "󰆍"; accent: page.accent
        BoardCell { kind: "info"; icon: "󰀪"; title: "Terminal"; hidden: (TerminalAppearance.error || TerminalAppearance.shortcutError) === ""
                    info: TerminalAppearance.error || TerminalAppearance.shortcutError }
        Repeater {
            model: [
                { key: "background", icon: "󰆍", values: ["default", "blur", "clear"] },
                { key: "prompt", icon: "󰘳", values: ["default", "hex"] },
                { key: "border", icon: "󰖯", values: ["white", "default", "theme", "none"] },
                { key: "workspace", icon: "󰹑", values: ["vertical", "horizontal"] }
            ]
            BoardCell {
                required property var modelData
                kind: "select"; icon: modelData.icon; title: I18n.t("guide.terminal." + modelData.key + ".title")
                options: page.names(modelData.values); values: modelData.values
                value: modelData.values.indexOf(page.opt(modelData.key)) >= 0 ? page.opt(modelData.key) : TerminalAppearance.defaults[modelData.key]
                onPicked: (v) => TerminalAppearance.setOption(modelData.key, v)
            }
        }
        BoardCell {
            kind: "slider"; icon: "󰂚"; title: I18n.t("guide.terminal.blur_size.title"); hidden: page.ta.background !== "blur"
            from: 1; to: 20; step: 1
            property real live: NaN
            value: isNaN(live) ? (page.ta.blurSize || TerminalAppearance.defaults.blurSize) : live
            onMoving: (v) => live = Math.round(v)
            onReleased: { if (!isNaN(live)) TerminalAppearance.setOption("blurSize", live); live = NaN; }
        }
    }

    BoardCard {
        title: "Scrollable Tiling"; icon: "󰖯"; accent: page.accent
        BoardCell { kind: "select"; icon: "󰆍"; title: I18n.t("guide.terminal.scrollable.window_layout")
                    options: ["Hyprland", "niri", I18n.t("guide.terminal.scrollable.hybrid")]; values: ["hyprland", "niri", "hybrid"]
                    value: TerminalAppearance.scrollableSettings.windowLayout || "hyprland"
                    onPicked: (v) => TerminalAppearance.setScrollableOption("windowLayout", v) }
        BoardCell { kind: "toggle"; icon: "󰀻"; title: I18n.t("guide.terminal.scrollable.apps")
                    value: TerminalAppearance.scrollableSettings.appsScrollable
                    onPicked: (v) => TerminalAppearance.setScrollableOption("appsScrollable", v) }
    }

    BoardCard {
        title: "Infinite Desktop  ·  " + (TerminalAppearance.infiniteActive ? "Active" : "Inactive"); icon: "󰍹"; accent: page.accent
        BoardCell {
            kind: "custom"; wide: true; icon: "󰌌"; title: I18n.t("guide.terminal.infinite.toggle_shortcut"); customHeight: 34
            Row {
                width: parent.width; spacing: 8
                ShortcutRecorder {
                    id: sc
                    width: parent.width - saveSc.width - 8; height: 34; cornerRadius: Math.min(ThemeBackend.borderRadius, 10)
                    value: TerminalAppearance.infiniteSettings.toggleShortcut
                    hasError: TerminalAppearance.shortcutError !== ""
                    accentColor: page.accent
                }
                Rectangle {
                    id: saveSc
                    width: sl.implicitWidth + 28; height: 34; radius: 17
                    color: sMa.pressed ? Qt.darker(page.accent, 1.15) : page.accent
                    Text { id: sl; anchors.centerIn: parent; text: I18n.t("guide.terminal.infinite.save_shortcut"); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.crust }
                    MouseArea { id: sMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); TerminalAppearance.saveToggleShortcut(sc.combo); } }
                }
            }
        }
        BoardCell {
            kind: "slider"; icon: "󰙖"; title: "Window size (one cell of 2×2)"; from: 50; to: 150; step: 10; suffix: "%"
            property real live: NaN
            value: isNaN(live) ? TerminalAppearance.infiniteSettings.cellScale : live
            onMoving: (v) => live = Math.round(v / 10) * 10
            onReleased: { if (!isNaN(live)) TerminalAppearance.setInfiniteOption("cellScale", live); live = NaN; }
        }
        BoardCell { kind: "action"; icon: "󰕰"; title: I18n.t("guide.terminal.infinite.arrange"); actionText: I18n.t("guide.terminal.infinite.arrange")
                    available: TerminalAppearance.infiniteActive; onActivated: TerminalAppearance.infiniteAction("arrange") }
        // CLI toy: what a terminal drawn with the right button runs, one of the picked programs at random (installed only)
        BoardCell { kind: "select"; multi: true; icon: "󰆍"; title: "CLI toy"
                    options: TerminalAppearance.availableDragPrograms.map(p => p.name); values: TerminalAppearance.availableDragPrograms.map(p => p.id)
                    value: TerminalAppearance.cliToys; onPicked: (v) => TerminalAppearance.setCliToys(v)
                    Component.onCompleted: TerminalAppearance.refreshDragPrograms() }
    }

    // inf desktop: Pan — Anserin's fixed way, or keys chosen here (shown only for Custom keys)
    BoardCard {
        title: "Pan"; icon: "󰆾"; accent: page.accent
        BoardCell { kind: "seg"; wide: true; icon: "󰆾"; title: "Mode"
                    options: ["Anserin", "Custom keys"]; values: ["anserin", "custom"]
                    value: TerminalAppearance.infiniteSettings.panMode
                    onPicked: (v) => TerminalAppearance.setInfiniteOption("panMode", v) }
        BoardCell { kind: "info"; wide: true; icon: "󰋼"; title: "How"
                    info: TerminalAppearance.infiniteSettings.panMode === "custom" ? "Hold the keys and move the mouse" : "Drag the empty desktop with the left button" }
        BoardCell {
            kind: "custom"; wide: true; icon: "󰌌"; title: "Keys"; customHeight: 34
            hidden: TerminalAppearance.infiniteSettings.panMode !== "custom"
            Row {
                width: parent.width; spacing: 8
                ShortcutRecorder {
                    id: panRec
                    width: parent.width - panSave.width - 8; height: 34; cornerRadius: Math.min(ThemeBackend.borderRadius, 10)
                    value: TerminalAppearance.infiniteSettings.panKeys
                    hasError: !!TerminalAppearance.keysError.panKeys
                    accentColor: page.accent
                }
                Rectangle {
                    id: panSave
                    width: panSaveText.implicitWidth + 28; height: 34; radius: 17
                    color: panSaveMa.pressed ? Qt.darker(page.accent, 1.15) : page.accent
                    Text { id: panSaveText; anchors.centerIn: parent; text: I18n.t("guide.terminal.infinite.save_shortcut"); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.crust }
                    MouseArea { id: panSaveMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); TerminalAppearance.saveInfiniteKeys("panKeys", panRec.combo); } }
                }
            }
        }
        BoardCell { kind: "info"; wide: true; icon: "󰀪"; title: "Keys"; info: TerminalAppearance.keysError.panKeys || ""
                    hidden: TerminalAppearance.infiniteSettings.panMode !== "custom" || !TerminalAppearance.keysError.panKeys }
    }

    // inf desktop: Go to window — Anserin's fixed way, or keys chosen here (shown only for Custom keys)
    BoardCard {
        title: "Go to window"; icon: "󰁔"; accent: page.accent
        BoardCell { kind: "seg"; wide: true; icon: "󰁔"; title: "Mode"
                    options: ["Anserin", "Custom keys"]; values: ["anserin", "custom"]
                    value: TerminalAppearance.infiniteSettings.navigateMode
                    onPicked: (v) => TerminalAppearance.setInfiniteOption("navigateMode", v) }
        BoardCell { kind: "info"; wide: true; icon: "󰋼"; title: "How"
                    info: TerminalAppearance.infiniteSettings.navigateMode === "custom" ? "Keys + arrows bring the next window to the middle" : "Win + arrows bring the next window to the middle" }
        BoardCell {
            kind: "custom"; wide: true; icon: "󰌌"; title: "Keys"; customHeight: 34
            hidden: TerminalAppearance.infiniteSettings.navigateMode !== "custom"
            Row {
                width: parent.width; spacing: 8
                ShortcutRecorder {
                    id: navigateRec
                    width: parent.width - navigateSave.width - 8; height: 34; cornerRadius: Math.min(ThemeBackend.borderRadius, 10)
                    value: TerminalAppearance.infiniteSettings.navigateKeys
                    hasError: !!TerminalAppearance.keysError.navigateKeys
                    accentColor: page.accent
                }
                Rectangle {
                    id: navigateSave
                    width: navigateSaveText.implicitWidth + 28; height: 34; radius: 17
                    color: navigateSaveMa.pressed ? Qt.darker(page.accent, 1.15) : page.accent
                    Text { id: navigateSaveText; anchors.centerIn: parent; text: I18n.t("guide.terminal.infinite.save_shortcut"); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.crust }
                    MouseArea { id: navigateSaveMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); TerminalAppearance.saveInfiniteKeys("navigateKeys", navigateRec.combo); } }
                }
            }
        }
        BoardCell { kind: "info"; wide: true; icon: "󰀪"; title: "Keys"; info: TerminalAppearance.keysError.navigateKeys || ""
                    hidden: TerminalAppearance.infiniteSettings.navigateMode !== "custom" || !TerminalAppearance.keysError.navigateKeys }
    }

    // inf desktop: Move window — Anserin's fixed way, or keys chosen here (shown only for Custom keys)
    BoardCard {
        title: "Move window"; icon: "󰁁"; accent: page.accent
        BoardCell { kind: "seg"; wide: true; icon: "󰁁"; title: "Mode"
                    options: ["Anserin", "Custom keys"]; values: ["anserin", "custom"]
                    value: TerminalAppearance.infiniteSettings.moveMode
                    onPicked: (v) => TerminalAppearance.setInfiniteOption("moveMode", v) }
        BoardCell { kind: "info"; wide: true; icon: "󰋼"; title: "How"
                    info: TerminalAppearance.infiniteSettings.moveMode === "custom" ? "Keys + arrows: 90 px a press; at an edge the canvas moves" : "Win + drag; into a screen edge pushes the canvas" }
        BoardCell {
            kind: "custom"; wide: true; icon: "󰌌"; title: "Keys"; customHeight: 34
            hidden: TerminalAppearance.infiniteSettings.moveMode !== "custom"
            Row {
                width: parent.width; spacing: 8
                ShortcutRecorder {
                    id: moveRec
                    width: parent.width - moveSave.width - 8; height: 34; cornerRadius: Math.min(ThemeBackend.borderRadius, 10)
                    value: TerminalAppearance.infiniteSettings.moveKeys
                    hasError: !!TerminalAppearance.keysError.moveKeys
                    accentColor: page.accent
                }
                Rectangle {
                    id: moveSave
                    width: moveSaveText.implicitWidth + 28; height: 34; radius: 17
                    color: moveSaveMa.pressed ? Qt.darker(page.accent, 1.15) : page.accent
                    Text { id: moveSaveText; anchors.centerIn: parent; text: I18n.t("guide.terminal.infinite.save_shortcut"); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.crust }
                    MouseArea { id: moveSaveMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); TerminalAppearance.saveInfiniteKeys("moveKeys", moveRec.combo); } }
                }
            }
        }
        BoardCell { kind: "info"; wide: true; icon: "󰀪"; title: "Keys"; info: TerminalAppearance.keysError.moveKeys || ""
                    hidden: TerminalAppearance.infiniteSettings.moveMode !== "custom" || !TerminalAppearance.keysError.moveKeys }
    }

    // inf desktop: Resize — Anserin's fixed way, or keys chosen here (shown only for Custom keys)
    BoardCard {
        title: "Resize"; icon: "󰩨"; accent: page.accent
        BoardCell { kind: "seg"; wide: true; icon: "󰩨"; title: "Mode"
                    options: ["Anserin", "Custom keys"]; values: ["anserin", "custom"]
                    value: TerminalAppearance.infiniteSettings.resizeMode
                    onPicked: (v) => TerminalAppearance.setInfiniteOption("resizeMode", v) }
        BoardCell { kind: "info"; wide: true; icon: "󰋼"; title: "How"
                    info: TerminalAppearance.infiniteSettings.resizeMode === "custom" ? "Keys + arrows: right/down grow, left/up shrink by 90 px" : "Drag a window edge with the left button" }
        BoardCell {
            kind: "custom"; wide: true; icon: "󰌌"; title: "Keys"; customHeight: 34
            hidden: TerminalAppearance.infiniteSettings.resizeMode !== "custom"
            Row {
                width: parent.width; spacing: 8
                ShortcutRecorder {
                    id: resizeRec
                    width: parent.width - resizeSave.width - 8; height: 34; cornerRadius: Math.min(ThemeBackend.borderRadius, 10)
                    value: TerminalAppearance.infiniteSettings.resizeKeys
                    hasError: !!TerminalAppearance.keysError.resizeKeys
                    accentColor: page.accent
                }
                Rectangle {
                    id: resizeSave
                    width: resizeSaveText.implicitWidth + 28; height: 34; radius: 17
                    color: resizeSaveMa.pressed ? Qt.darker(page.accent, 1.15) : page.accent
                    Text { id: resizeSaveText; anchors.centerIn: parent; text: I18n.t("guide.terminal.infinite.save_shortcut"); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.crust }
                    MouseArea { id: resizeSaveMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); TerminalAppearance.saveInfiniteKeys("resizeKeys", resizeRec.combo); } }
                }
            }
        }
        BoardCell { kind: "info"; wide: true; icon: "󰀪"; title: "Keys"; info: TerminalAppearance.keysError.resizeKeys || ""
                    hidden: TerminalAppearance.infiniteSettings.resizeMode !== "custom" || !TerminalAppearance.keysError.resizeKeys }
    }

    BoardCard {
        title: "Fastfetch"; icon: "󰒓"; accent: page.accent
        BoardCell { kind: "info"; icon: "󰀪"; title: "Fastfetch"; hidden: TerminalAppearance.fastfetchError === ""; info: TerminalAppearance.fastfetchError }
        BoardCell { kind: "toggle"; icon: "󰆍"; title: "Auto Fastfetch"; value: page.ff.auto; onPicked: (v) => TerminalAppearance.setFastfetchOption("auto", v) }
        BoardCell { kind: "toggle"; icon: "󰈉"; title: "Hide ASCII / Pic"; value: page.ff.hideLogo; onPicked: (v) => TerminalAppearance.setFastfetchOption("hideLogo", v) }
        BoardCell { kind: "select"; icon: "󰆍"; title: I18n.t("guide.terminal.fastfetch.mode", "Fastfetch logo"); available: !page.ff.random
                    options: ["Default", "ASCII", "Pic"]; values: ["default", "ascii", "pic"]
                    value: page.ff.mode; onPicked: (v) => TerminalAppearance.setFastfetchOption("mode", v) }
        BoardCell { kind: "toggle"; icon: "󰒟"; title: "Random"; value: page.ff.random; onPicked: (v) => TerminalAppearance.setFastfetchOption("random", v) }
        BoardCell { kind: "select"; icon: "󰒟"; title: I18n.t("guide.terminal.fastfetch.random_source", "Random source"); hidden: !page.ff.random
                    options: ["ASCII", "Pic", "Both"]; values: ["ascii", "pic", "both"]
                    value: page.ff.randomMode; onPicked: (v) => TerminalAppearance.setFastfetchOption("randomMode", v) }
        Repeater {
            model: ["ascii", "pic"]
            BoardCell {
                required property string modelData
                readonly property var files: modelData === "ascii" ? page.asciiNames : page.picNames
                kind: "select"; icon: modelData === "ascii" ? "󰆍" : "󰋩"; title: modelData === "ascii" ? "ASCII" : "Pic"
                hidden: !(page.ff.random ? (page.ff.randomMode === "both" || page.ff.randomMode === modelData) : page.ff.mode === modelData)
                available: !page.ff.random && files.length > 0
                options: files.length ? files : [I18n.t("guide.terminal.fastfetch.empty", "No files")]; values: files.length ? files : [""]
                value: files.length ? (files.indexOf(page.ff[modelData]) >= 0 ? page.ff[modelData] : files[0]) : ""
                onPicked: (v) => TerminalAppearance.setFastfetchOption(modelData, v)
            }
        }
        Repeater {
            model: ["ascii", "pic"]
            BoardCell {
                required property string modelData
                kind: "action"; icon: "󰐕"; title: modelData === "ascii" ? "Add ASCII" : "Add Pic"; actionText: "Open folder"
                hidden: !(page.ff.random ? (page.ff.randomMode === "both" || page.ff.randomMode === modelData) : page.ff.mode === modelData)
                onActivated: FileManager.openFolder(TerminalAppearance.fastfetchDir + (modelData === "ascii" ? "/ascii" : "/pngs"), false)
            }
        }
    }
}
