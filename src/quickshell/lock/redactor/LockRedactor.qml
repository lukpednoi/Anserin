import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../"
import "../../reusables"
import "../../reusables/expressive"
import "../../widgets"

Scope {
    id: root

    property bool isActive: false
    property string targetMonitorName: ""
    readonly property int storeRevision: windowLoader.item ? windowLoader.item.layoutStore.revision : 0
    property bool sessionLocked: false
    onSessionLockedChanged: if (sessionLocked) close()

    function open(mon) {
        const monitor = (mon && typeof mon === "string") ? mon.trim() : "";
        if (root.isActive && root.targetMonitorName !== monitor) root.close();
        root.targetMonitorName = monitor;
        root.isActive = true;
    }

    function close() {
        if (windowLoader.item) windowLoader.item.layoutStore.flush();
        root.isActive = false;
        root.targetMonitorName = "";
    }

    function toggle(mon) {
        if (root.isActive) {
            root.close();
        } else {
            root.open(mon);
        }
    }

    // IPC target "lock-redactor" is owned by Shell.qml so this editor stays unloaded until opened.

    Loader {
        id: windowLoader
        active: root.isActive

        sourceComponent: Component {
            PanelWindow {
                id: win
                property alias layoutStore: layoutStore
                LockLayoutStore { id: layoutStore; monitorName: win.monitorName }
                color: "transparent"

                readonly property string monitorName: root.targetMonitorName !== "" ? root.targetMonitorName : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "")
                readonly property var targetScreen: Quickshell.screens.find(s => s.name === win.monitorName) || (Quickshell.screens.length > 0 ? Quickshell.screens[0] : null)
                readonly property string safeMonitorName: (win.monitorName || "default").replace(/[^a-zA-Z0-9_-]/g, "_")
                readonly property var lockSettings: Config.getSetting("lockscreen", {})
                readonly property bool simpleStyle: lockSettings.style === "simple"
                readonly property string customBackgroundPath: lockSettings.customBackground ? String(lockSettings.customBackground) : ""
                readonly property bool customBackgroundActive: lockSettings.backgroundMode === "custom" && customBackgroundPath !== ""
                readonly property string desktopWallpaperPath: {
                    Wallpaper.screenWallpaperPaths;
                    return Wallpaper.getWallpaperPath(win.monitorName);
                }
                readonly property string backgroundPath: customBackgroundActive ? customBackgroundPath : desktopWallpaperPath
                readonly property bool backgroundIsVideo: {
                    let lp = win.backgroundPath.toLowerCase();
                    return lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm");
                }
                readonly property string videoPath: win.customBackgroundActive && win.backgroundIsVideo ? win.backgroundPath : ""
                readonly property string wallpaperSource: {
                    if (win.customBackgroundActive && !win.backgroundIsVideo) {
                        return "file://" + win.customBackgroundPath.split("/").map(encodeURIComponent).join("/");
                    }
                    if (win.customBackgroundActive) {
                        return "";
                    }
                    return "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper_" + win.monitorName + ".png";
                }

                screen: win.targetScreen

                WlrLayershell.namespace: "qs-lock-redactor-" + win.safeMonitorName
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

                exclusionMode: ExclusionMode.Ignore
                focusable: true

                anchors.top: true
                anchors.left: true
                anchors.right: true
                anchors.bottom: true

                readonly property real screenW: win.targetScreen ? win.targetScreen.width : 1920
                readonly property real screenH: win.targetScreen ? win.targetScreen.height : 1080

                property int page: 0
                property real pageProgress: win.page
                property bool gridScreen: false
                property bool gridPanel: true
                property string pendingImageVariant: ""

                Component.onCompleted: {
                    layoutStore.setReference(win.screenW, win.screenH);
                    layoutStore.beginHistory();
                    Wallpaper.playbackChanged("all", "pause");
                    openAnim.start();
                }

                Component.onDestruction: {
                    layoutStore.endHistory();
                    Wallpaper.playbackChanged("all", "play");
                }

                readonly property Item activeScene: (win.simpleStyle || win.page === 0) ? screenScene : panelStage.scene
                readonly property bool gridOn: (win.simpleStyle || win.page === 0) ? win.gridScreen : win.gridPanel
                readonly property var selProxy: win.activeScene.selectedProxy

                Behavior on pageProgress { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                onPageChanged: {
                    categoryBar.typeId = "";
                    categoryBar.categoryId = "";
                }

                function go(delta) {
                    if (win.simpleStyle) return;
                    win.page = Math.max(0, Math.min(1, win.page + delta));
                }

                function toggleGrid() {
                    if (win.simpleStyle || win.page === 0) {
                        win.gridScreen = !win.gridScreen;
                        if (win.gridScreen) screenScene.snapAllToGrid();
                    } else {
                        win.gridPanel = !win.gridPanel;
                        if (win.gridPanel) panelStage.scene.snapAllToGrid();
                    }
                }

                function addItem(type, imagePath, variantOverride) {
                    let scene = win.activeScene;
                    if (!LockElementRegistry.allowedIn(type, scene.scope)) return;
                    if (type === "widget:image" && (!imagePath || imagePath === "")) {
                        win.pendingImageVariant = variantOverride || LockElementRegistry.defaultVariant(type);
                        win.openImagePicker("", "", false);
                        return;
                    }
                    let def = LockElementRegistry.defaultSize(type);
                    let w = def.w > 0 ? Math.min(def.w, scene.width) : 0;
                    let h = def.h > 0 ? Math.min(def.h, scene.height) : 0;
                    let x = w > 0 ? Math.max(0, (scene.width - w) / 2) : scene.width / 2;
                    let y = h > 0 ? Math.max(0, (scene.height - h) / 2) : scene.height / 2;
                    // Offset repeated spawns slightly so duplicate widgets don't stack pixel-for-pixel
                    if (scene.itemsModel) {
                        for (let tries = 0; tries < 12; tries++) {
                            let clash = false;
                            for (let i = 0; i < scene.itemsModel.count; i++) {
                                let row = scene.itemsModel.get(i);
                                if (Math.abs(row.ix - x) < 20 && Math.abs(row.iy - y) < 20) {
                                    clash = true;
                                    break;
                                }
                            }
                            if (!clash) break;
                            x += 28;
                            y += 28;
                            if (w > 0 && x + w > scene.width) x = 24;
                            if (h > 0 && y + h > scene.height) y = 24;
                        }
                    }
                    if (w > 0 && win.gridOn) {
                        x = Math.round(x / scene.gridStep) * scene.gridStep;
                        y = Math.round(y / scene.gridStep) * scene.gridStep;
                    }
                    let v = (variantOverride && variantOverride !== "") ? variantOverride : LockElementRegistry.defaultVariant(type);
                    let entry = layoutStore.makeEntry(type, v, x, y, w, h);
                    entry.iimage = imagePath || "";
                    scene.selectedId = layoutStore.addItem(scene.scope, entry);
                }

                function openImagePicker(itemId, currentPath, rounded) {
                    imagePickerLoader.targetItemId = itemId;
                    imagePickerLoader.currentPath = currentPath;
                    imagePickerLoader.rounded = rounded;
                    imagePickerLoader.active = true;
                    if (imagePickerLoader.item) imagePickerLoader.item.openPicker(currentPath, rounded);
                }

                Shortcut {
                    sequence: "Escape"
                    onActivated: {
                        if (categoryBar.typeId !== "") { categoryBar.typeId = ""; return; }
                        if (categoryBar.back()) return;
                        if (win.activeScene.selectedId !== "") { win.activeScene.selectedId = ""; return; }
                        root.close();
                    }
                }

                Shortcut {
                    sequence: "Left"
                    enabled: !win.simpleStyle
                    onActivated: win.go(-1)
                }

                Shortcut {
                    sequence: "Right"
                    enabled: !win.simpleStyle
                    onActivated: win.go(1)
                }

                Shortcut {
                    sequence: "Ctrl+Z"
                    onActivated: layoutStore.undo()
                }

                Shortcut {
                    sequences: ["Ctrl+Shift+Z", "Ctrl+Y"]
                    onActivated: layoutStore.redo()
                }

                Shortcut {
                    sequence: "Delete"
                    onActivated: win.activeScene.removeSelected()
                }

                Item {
                    id: ui
                    anchors.fill: parent

                    function s(val) { return Scaler.s(val); }

                    property real openProgress: 0
                    readonly property real layoutP: Math.max(0, Math.min(1, openProgress))
                    readonly property bool previewOpen: categoryBar.typeId !== ""
                    property real previewP: previewOpen ? 1.0 : 0.0
                    Behavior on previewP {
                        SpringAnimation {
                            spring: 4.0
                            damping: 0.34
                            epsilon: 0.0005
                        }
                    }
                    property string shownPreviewType: ""
                    onPreviewPChanged: if (previewP <= 0.008 && !previewOpen) shownPreviewType = ""

                    NumberAnimation {
                        id: openAnim
                        target: ui
                        property: "openProgress"
                        to: 1
                        duration: 520
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.2
                    }

                    readonly property real frameInset: ScreenEdges.inset(win.screen)
                    readonly property real edgeGap: s(14)
                    readonly property real innerMargin: frameInset + s(12)
                    readonly property real leftPanelWidth: Math.round(Math.max(s(280), Math.min(s(390), width * 0.28)))
                    readonly property real bottomBarHeight: Math.round(Math.max(s(92), Math.min(s(118), height * 0.145)))
                    readonly property real topStripHeight: s(78)
                    readonly property real previewSpan: Math.max(0, previewP) * (leftPanelWidth + edgeGap)
                    readonly property real stageAreaX: innerMargin + previewSpan
                    readonly property real stageAreaW: Math.max(200, width - stageAreaX - innerMargin)
                    readonly property real stageAreaY: innerMargin + topStripHeight + edgeGap
                    readonly property real stageAreaH: Math.max(160, height - stageAreaY - bottomBarHeight - edgeGap - innerMargin)
                    readonly property real k: Math.max(0.05, Math.min(stageAreaW / Math.max(1, win.screenW), stageAreaH / Math.max(1, win.screenH)))
                    readonly property real stageW: win.screenW * k
                    readonly property real stageH: win.screenH * k
                    readonly property real stageX: stageAreaX + (stageAreaW - stageW) / 2
                    readonly property real stageY: stageAreaY + (stageAreaH - stageH) / 2
                    readonly property real frameGap: width * 0.03

                    Image {
                        anchors.fill: parent
                        source: win.wallpaperSource
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(ui.width / 2, ui.height / 2)
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.78)
                    }

                    // Lock screen stage (glides smoothly right when the left preview panel springs open)
                    Item {
                        id: pager
                        x: ui.stageAreaX
                        y: ui.stageAreaY
                        width: ui.stageAreaW
                        height: ui.stageAreaH
                        clip: true
                        scale: 0.94 + 0.06 * ui.openProgress
                        opacity: ui.layoutP

                        LockStageFrame {
                            id: clockFrame
                            readonly property real distance: Math.abs(0 - win.pageProgress)
                            screenW: win.screenW
                            screenH: win.screenH
                            k: ui.k
                            current: win.simpleStyle || win.page === 0
                            contentActive: current || distance < 0.999
                            wallpaper: win.wallpaperSource
                            videoPath: win.videoPath
                            x: pager.width / 2 + (0 - win.pageProgress) * (width + ui.frameGap) - width / 2
                            y: (pager.height - height) / 2
                            opacity: Math.max(0.3, 1 - distance * 0.7)
                            scale: 1 - 0.1 * Math.min(1, distance)
                            onActivated: win.page = 0

                            LockScene {
                                id: screenScene
                                store: layoutStore
                                width: win.screenW
                                height: win.screenH
                                scope: "screen"
                                k: ui.k
                                active: win.simpleStyle || win.page === 0
                                gridEnabled: win.gridScreen
                                onImagePickRequested: (itemId, currentPath, rounded) => win.openImagePicker(itemId, currentPath, rounded)
                            }
                        }

                        LockStageFrame {
                            id: panelFrame
                            visible: !win.simpleStyle
                            readonly property real distance: Math.abs(1 - win.pageProgress)
                            screenW: win.screenW
                            screenH: win.screenH
                            k: ui.k
                            current: !win.simpleStyle && win.page === 1
                            contentActive: !win.simpleStyle && (current || distance < 0.999)
                            wallpaper: win.wallpaperSource
                            videoPath: win.videoPath
                            x: pager.width / 2 + (1 - win.pageProgress) * (width + ui.frameGap) - width / 2
                            y: (pager.height - height) / 2
                            opacity: Math.max(0.3, 1 - distance * 0.7)
                            scale: 1 - 0.1 * Math.min(1, distance)
                            onActivated: if (!win.simpleStyle) win.page = 1

                            LockPanelStage {
                                id: panelStage
                                store: layoutStore
                                width: win.screenW
                                height: win.screenH
                                k: ui.k
                                active: !win.simpleStyle && win.page === 1
                                gridEnabled: win.gridPanel
                                Component.onCompleted: scene.imagePickRequested.connect((itemId, currentPath, rounded) => win.openImagePicker(itemId, currentPath, rounded))
                            }
                        }

                        IconButton {
                            visible: !win.simpleStyle
                            anchors.left: parent.left
                            anchors.leftMargin: ui.s(16)
                            anchors.verticalCenter: parent.verticalCenter
                            size: ui.s(46)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰅁"
                            iconFontSize: ui.s(22)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            opacity: win.page > 0 ? 1.0 : 0.0
                            enabled: !win.simpleStyle && win.page > 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onClicked: win.go(-1)
                        }

                        IconButton {
                            visible: !win.simpleStyle
                            anchors.right: parent.right
                            anchors.rightMargin: ui.s(16)
                            anchors.verticalCenter: parent.verticalCenter
                            size: ui.s(46)
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰅂"
                            iconFontSize: ui.s(22)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            opacity: win.page < 1 ? 1.0 : 0.0
                            enabled: !win.simpleStyle && win.page < 1
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onClicked: win.go(1)
                        }
                    }

                    // Top toolbar strip above the lock stage (matches Open Redactor; tailored to lock-screen features)
                    Item {
                        id: topToolsHost
                        x: ui.stageX
                        width: ui.stageW
                        y: ui.innerMargin - (1 - ui.layoutP) * ui.s(28)
                        height: ui.topStripHeight
                        opacity: ui.layoutP
                        z: 150000

                        // Page switcher pill when in two-page mode and no element is selected
                        RowLayout {
                            visible: !win.simpleStyle && win.selProxy === null
                            anchors.centerIn: parent
                            spacing: ui.s(6)

                            Repeater {
                                model: [
                                    { idx: 0, icon: "󰌾", label: I18n.t("lock.redactor.page.screen", "Lock Screen") },
                                    { idx: 1, icon: "󰕮", label: I18n.t("lock.redactor.page.dashboard", "Dashboard") }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool active: win.page === modelData.idx
                                    implicitWidth: pgRow.implicitWidth + ui.s(20)
                                    implicitHeight: ui.s(34)
                                    radius: ThemeBackend.borderRadius
                                    color: active ? ThemeBackend.mauve : (pgMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.surface0, 0.92))
                                    border.width: 1
                                    border.color: active ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface1, 0.7)
                                    Behavior on color { ColorAnimation { duration: ExMotion.fast } }

                                    RowLayout {
                                        id: pgRow
                                        anchors.centerIn: parent
                                        spacing: ui.s(6)
                                        Text { text: modelData.icon; font.family: ThemeBackend.iconFont; font.pixelSize: ui.s(13); color: parent.parent.active ? ThemeBackend.crust : ThemeBackend.mauve }
                                        Text { text: modelData.label; font.family: ThemeBackend.fontFamily; font.pixelSize: ui.s(12); font.bold: true; color: parent.parent.active ? ThemeBackend.crust : ThemeBackend.text }
                                    }

                                    MouseArea {
                                        id: pgMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            Sounds.playSfx("reusables/clickbutton/click.wav");
                                            win.page = modelData.idx;
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            id: chrome
                            anchors.centerIn: parent
                            spacing: ui.s(6)
                            opacity: win.selProxy !== null ? 1.0 : 0.0
                            visible: opacity > 0.01
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            readonly property bool hasProxy: win.selProxy !== null
                            readonly property string pType: chrome.hasProxy ? win.selProxy.pType : ""
                            readonly property bool isWidget: chrome.hasProxy && LockElementRegistry.isWidget(chrome.pType)
                            readonly property string widgetKey: chrome.isWidget ? LockElementRegistry.widgetKey(chrome.pType) : ""
                            readonly property var variantsList: chrome.hasProxy ? LockElementRegistry.variantList(chrome.pType) : []
                            readonly property bool hasVariants: chrome.variantsList.length > 1

                            Component {
                                id: defaultSettingButton

                                IconButton {
                                    id: defBtn
                                    property var settingData: null
                                    size: ui.s(34)
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: (defBtn.settingData && defBtn.settingData.icon) ? defBtn.settingData.icon : ""
                                    iconFontSize: ui.s((defBtn.settingData && defBtn.settingData.iconFontSize) ? defBtn.settingData.iconFontSize : 16)
                                    accentColor: win.activeScene.resolveThemeColor((defBtn.settingData && defBtn.settingData.accentColor) ? defBtn.settingData.accentColor : "surface0")
                                    textColor: win.activeScene.resolveThemeColor((defBtn.settingData && defBtn.settingData.textColor) ? defBtn.settingData.textColor : "mauve")
                                    onClicked: {
                                        if (defBtn.settingData && defBtn.settingData.action && win.selProxy) {
                                            win.activeScene.handleAdditionalAction(defBtn.settingData.action, win.selProxy);
                                        }
                                    }
                                }
                            }

                            component Pill: Rectangle {
                                property alias label: pillText.text
                                implicitWidth: pillText.implicitWidth + ui.s(16)
                                implicitHeight: ui.s(34)
                                color: Qt.alpha(ThemeBackend.surface0, 0.92)
                                border.width: 1
                                border.color: Qt.alpha(ThemeBackend.surface1, 0.7)
                                radius: ThemeBackend.borderRadius

                                Text {
                                    id: pillText
                                    anchors.centerIn: parent
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: ui.s(12)
                                    font.bold: true
                                    color: ThemeBackend.text
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: ui.s(4)

                                Pill {
                                    label: chrome.hasProxy ? (Math.round(win.selProxy.gW) + "x" + Math.round(win.selProxy.gH)) : ""
                                }

                                Pill {
                                    label: chrome.hasProxy ? ((win.selProxy.gH > 0 ? (win.selProxy.gW / win.selProxy.gH).toFixed(2) : "0.00") + ":1") : ""
                                }

                                Pill {
                                    label: {
                                        if (!chrome.hasProxy) return "";
                                        let def = win.selProxy.getDefaultSize();
                                        return def.w > 0 ? Math.round((win.selProxy.gW / def.w) * 100) + "%" : "100%";
                                    }
                                }

                                LockSettingsRepeater {
                                    row: "top"
                                    widgetKey: chrome.widgetKey
                                    proxy: win.selProxy
                                    scene: win.activeScene
                                    buttonComponent: defaultSettingButton
                                }

                                IconButton {
                                    size: ui.s(34)
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰑖"
                                    iconFontSize: ui.s(16)
                                    accentColor: ThemeBackend.surface0
                                    textColor: ThemeBackend.text
                                    onClicked: if (win.selProxy) win.selProxy.rotateItem()
                                }

                                IconButton {
                                    size: ui.s(34)
                                    cornerRadius: ThemeBackend.borderRadius
                                    buttonIcon: "󰑐"
                                    iconFontSize: ui.s(15)
                                    accentColor: ThemeBackend.surface0
                                    textColor: ThemeBackend.text
                                    onClicked: if (win.selProxy) win.selProxy.resetItemSize()
                                }

                                DeleteButton {
                                    visible: chrome.hasProxy && win.selProxy.deletable
                                    size: ui.s(34)
                                    cornerRadius: ThemeBackend.borderRadius
                                    iconFontSize: ui.s(18)
                                    onClicked: win.activeScene.removeSelected()
                                }
                            }

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: ui.s(6)

                                LockSettingsRepeater {
                                    row: "bottom"
                                    widgetKey: chrome.widgetKey
                                    elementType: chrome.pType
                                    proxy: win.selProxy
                                    scene: win.activeScene
                                    buttonComponent: defaultSettingButton
                                }

                                // Opacity slider
                                Rectangle {
                                    implicitWidth: ui.s(280)
                                    implicitHeight: ui.s(34)
                                    color: Qt.alpha(ThemeBackend.surface0, 0.92)
                                    border.width: 1
                                    border.color: Qt.alpha(ThemeBackend.surface1, 0.7)
                                    radius: ThemeBackend.borderRadius

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: ui.s(10)
                                        anchors.rightMargin: ui.s(10)
                                        spacing: ui.s(8)

                                        Text {
                                            text: Math.round((chrome.hasProxy ? win.selProxy.pOpacity : 1) * 100) + "%"
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: ui.s(11)
                                            font.bold: true
                                            color: ThemeBackend.text
                                            Layout.preferredWidth: ui.s(32)
                                        }

                                        Draggable {
                                            id: opacitySlider
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: ui.s(16)
                                            Layout.alignment: Qt.AlignVCenter
                                            from: 0.0
                                            to: 100.0
                                            value: Math.round((chrome.hasProxy ? win.selProxy.pOpacity : 1) * 100)
                                            backgroundColor: ThemeBackend.surface1
                                            accentColor: ThemeBackend.mauve
                                            gradColor1: ThemeBackend.mauve
                                            gradColor2: Qt.lighter(ThemeBackend.mauve, 1.05)
                                            gradColor3: Qt.lighter(ThemeBackend.mauve, 1.10)
                                            cornerRadius: ThemeBackend.borderRadius
                                            handleSize: ui.s(16)
                                            handleColor: Qt.lighter(ThemeBackend.mauve, 1.15)
                                            handleHoverColor: Qt.lighter(ThemeBackend.mauve, 1.3)
                                            handleDragColor: Qt.lighter(ThemeBackend.mauve, 1.45)
                                            handleBorderColor: Qt.rgba(0, 0, 0, 0.2)
                                            showValueBubble: false

                                            onMoved: val => {
                                                if (win.selProxy) win.selProxy.setOpacity(val / 100.0);
                                            }

                                            onDragFinished: {
                                                if (win.selProxy) win.selProxy.finalizeSync();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Full-height left preview panel: hidden until clicked, slides smoothly via GPU Translate
                    LockPreviewPanel {
                        id: previewPanel
                        z: 200000
                        selectedProxy: win.selProxy
                        scope: win.activeScene.scope
                        typeId: ui.shownPreviewType
                        x: ui.innerMargin
                        y: ui.innerMargin
                        width: ui.leftPanelWidth
                        height: ui.height - ui.innerMargin * 2
                        transform: Translate {
                            x: -(1 - ui.previewP) * (previewPanel.width + ui.innerMargin * 1.4)
                        }
                        opacity: Math.max(0, Math.min(1, ui.previewP * 1.5)) * ui.layoutP
                        visible: ui.openProgress > 0.001 && ui.previewP > 0.008 && ui.shownPreviewType !== ""
                        onCloseRequested: categoryBar.typeId = ""
                        onVariantPicked: (tid, vid) => {
                            if (win.selProxy && win.selProxy.pType === tid) win.selProxy.applyVariant(vid);
                        }
                        onAddRequested: (tid, vid) => win.addItem(tid, "", vid)
                    }

                    // Bottom category bar matching stage width
                    LockCategoryBar {
                        id: categoryBar
                        z: 200000
                        redactorWin: win
                        layoutStore: layoutStore
                        scope: win.activeScene.scope
                        gridOn: win.gridOn
                        x: ui.stageX
                        width: ui.stageW
                        height: ui.bottomBarHeight
                        y: ui.height - height - ui.innerMargin + (1 - ui.openProgress) * (height + ui.innerMargin)
                        visible: ui.openProgress > 0.001
                        onTypeIdChanged: {
                            if (typeId !== "") ui.shownPreviewType = typeId;
                        }
                        onToggleGridRequested: win.toggleGrid()
                        onResetScopeRequested: {
                            win.activeScene.selectedId = "";
                            layoutStore.resetScope(win.activeScene.scope);
                        }
                        onDoneClicked: root.close()
                    }

                    ScreenFrame {
                        anchors.fill: parent
                        z: 250000
                        inset: ui.frameInset
                        visible: inset > 0
                    }

                    Loader {
                        id: imagePickerLoader
                        anchors.fill: parent
                        z: 300000
                        active: false

                        property string targetItemId: ""
                        property string currentPath: ""
                        property bool rounded: false

                        sourceComponent: ImagePicker {
                            rootObj: ui

                            onImageSelected: (filePath, fileName) => {
                                if (imagePickerLoader.targetItemId !== "") {
                                    layoutStore.setItemProperty(imagePickerLoader.targetItemId, "iimage", filePath);
                                } else if (filePath !== "") {
                                    let v = win.pendingImageVariant;
                                    win.pendingImageVariant = "";
                                    win.addItem("widget:image", filePath, v);
                                }
                                imagePickerLoader.targetItemId = "";
                            }
                        }

                        onLoaded: item.openPicker(imagePickerLoader.currentPath, imagePickerLoader.rounded)
                    }
                }
            }
        }
    }
}
