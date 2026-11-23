import QtQuick
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Networking
import "WindowRegistry.js" as Registry
import "notifications" as Notifs

PanelWindow {
    id: masterWindow
    readonly property int frameInset: ScreenEdges.inset(screen)
    margins { top: frameInset; bottom: frameInset; left: frameInset; right: frameInset }
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: masterWindow.isVisible && !masterWindow.isClosing && masterWindow.openModalCount === 0 && !masterWindow.shortcutListening
        // Esc closes the lock screen's Select first (lockPicker), the Control Center under it stays
        onActivated: { if (lockPicker.active) Wallpaper.closeLockPicker(); else switchWidget("hidden", ""); }
    }

    function resolveTargetScreen() {
        if (masterWindow.popupScreenName) return LauncherController.getScreen(masterWindow.popupScreenName);
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedMonitor) {
                let monName = Hyprland.focusedMonitor.name;
                let screens = Quickshell.screens || [];
                let len = screens.length !== undefined ? screens.length : (screens.count !== undefined ? screens.count : 0);
                for (let i = 0; i < len; i++) {
                    let s = screens[i] !== undefined ? screens[i] : screens.get(i);
                    if (s && s.name === monName) return s;
                }
            }
        } catch (e) {}

        try {
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.screens && ToplevelManager.activeToplevel.screens.length > 0) {
                return ToplevelManager.activeToplevel.screens[0];
            }
        } catch (e) {}

        if (masterWindow.screen) return masterWindow.screen;
        return (Quickshell.screens && (Quickshell.screens.length > 0 || Quickshell.screens.count > 0))
            ? (Quickshell.screens[0] || Quickshell.screens.get(0))
            : null;
    }

    function reportWidgetState() {
        if (typeof Caching === "undefined" || !Caching.runDir) return;
        let sName = (masterWindow.currentActive === "hidden" || !masterWindow.screen) ? "" : (masterWindow.screen.name || "");
        let payload = JSON.stringify({
            widget: masterWindow.currentActive,
            screen: sName,
            barScreen: masterWindow.popupBarScreen
        });
        Quickshell.execDetached(["bash", "-c", "echo '" + payload + "' > " + Caching.runDir + "/current_widget"]);
    }

    Process {
        id: startupResetProcess
        command: ["bash", "-c", `[ -n "${Caching.runDir}" ] && echo '{"widget":"hidden","screen":""}' > "${Caching.runDir}/current_widget"`]
        running: true
    }

    Connections {
        target: (typeof Caching !== "undefined") ? Caching : null
        function onRunDirChanged() {
            masterWindow.reportWidgetState();
        }
    }

    IpcHandler {
        target: "main"

        function toggleFromBar(widget: string, arg: string, screenName: string): void {
            const targetScreen = LauncherController.getScreen(screenName);
            if (!targetScreen || targetScreen.name !== screenName) return;
            if (widget === "launcher") {
                ClipboardController.hide();
                LauncherController.toggle(targetScreen, true);
                return;
            }
            masterWindow.barRequestScreen = screenName;
            try {
                handleCommand("toggle", widget, arg);
            } finally {
                masterWindow.barRequestScreen = "";
            }
        }

        function forceReload(): void {
            Config.requestShellReload();
        }

        function clearNotifications(): void {
            NotificationManager.clearNotifications();
        }

        function handleCommand(cmd: string, targetWidget: string, arg: string): void {
            cmd = cmd || "";
            targetWidget = targetWidget || "";
            arg = arg || "";
            if (cmd === "clearNotifications" || cmd === "clear_notifications" || cmd === "clearNotifs") {
                NotificationManager.clearNotifications();
                return;
            }

            if (cmd === "launcher" || targetWidget === "launcher") {
                if (cmd === "close") {
                    LauncherController.hide();
                } else if (cmd === "open") {
                    ClipboardController.hide();
                    LauncherController.show();
                } else {
                    ClipboardController.hide();
                    LauncherController.toggle();
                }
                return;
            }

            if (cmd === "clipboard" || targetWidget === "clipboard" || cmd === "clip" || targetWidget === "clip") {
                if (cmd === "close") {
                    ClipboardController.hide();
                } else if (cmd === "open") {
                    LauncherController.hide();
                    ClipboardController.show();
                } else {
                    LauncherController.hide();
                    ClipboardController.toggle();
                }
                return;
            }

            if (cmd === "airplane" || targetWidget === "airplane" || cmd === "flight" || targetWidget === "flight") {
                let isAirplane = !Networking.wifiEnabled && !(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled);
                if (isAirplane) {
                    Networking.wifiEnabled = true;
                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = true;
                } else {
                    Networking.wifiEnabled = false;
                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = false;
                }
                return;
            }

            if (cmd === "autohide" || targetWidget === "autohide") {
                let bar = Config.getSetting("bar", {});
                bar.autohide = !bar.autohide;
                Config.setSetting("bar", bar);
                return;
            }

            let effectivelyActive = masterWindow.targetActive;

            if (cmd === "close") {
                switchWidget("hidden", "");
            } else if (cmd === "toggle" || cmd === "open") {
                if (targetWidget === effectivelyActive) {
                    let currentItem = widgetCache[targetWidget] || widgetStack.currentItem;

                    if (arg !== "" && arg !== masterWindow.activeArg) {
                        masterWindow.activeArg = arg;
                        if (currentItem && currentItem.activeMode !== undefined) {
                            currentItem.activeMode = arg;
                        }
                        if (currentItem && currentItem.gotoTab !== undefined) {
                            currentItem.gotoTab(arg);
                        }
                    } else if (cmd === "toggle") {
                        switchWidget("hidden", "");
                    }
                } else if (opens(targetWidget)) {
                    switchWidget(targetWidget, arg);
                }
            } else if (opens(cmd)) {
                let legacyArg = targetWidget;

                if (cmd === effectivelyActive) {
                    let currentItem = widgetCache[cmd] || widgetStack.currentItem;
                    if (legacyArg !== "" && currentItem && currentItem.activeMode !== undefined && currentItem.activeMode !== legacyArg) {
                        currentItem.activeMode = legacyArg;
                    } else if (legacyArg !== "" && currentItem && currentItem.gotoTab !== undefined) {
                        currentItem.gotoTab(legacyArg);
                    } else {
                        switchWidget("hidden", "");
                    }
                } else {
                    switchWidget(cmd, legacyArg);
                }
            }
        }

        function getWidgetGeometry(widgetName: string): void {
            let layout = getLayout(widgetName);
            if (layout) {
                let geo = {
                    startX: Math.round(layout.rx + masterWindow.frameInset),
                    startY: Math.round(layout.ry + masterWindow.frameInset),
                    endX: Math.round(layout.rx + masterWindow.frameInset + layout.w),
                    endY: Math.round(layout.ry + masterWindow.frameInset + layout.h)
                };
                Quickshell.execDetached(["bash", "-c", "echo '" + JSON.stringify(geo) + "' > " + Caching.runDir + "/tutorial_target.json"]);
            }
        }
    }

    WlrLayershell.namespace: "qs-master"
    WlrLayershell.layer: WlrLayer.Overlay

    exclusionMode: ExclusionMode.Ignore
    focusable: true

    implicitWidth: masterWindow.screen ? masterWindow.screen.width : 0
    implicitHeight: masterWindow.screen ? masterWindow.screen.height : 0

    visible: isVisible

    readonly property Item popupOverlay: contentItem ? contentItem.Overlay.overlay : null
    property int openModalCount: 0
    property bool shortcutListening: false
    readonly property bool needsPopupInput: lockPicker.active || openModalCount > 0

    mask: Region {
        item: masterWindow.needsPopupInput ? masterWindow.contentItem : (masterWindow.isCurrentDraggable ? animContainer : topBarHole)
        intersection: masterWindow.needsPopupInput || masterWindow.isCurrentDraggable ? Intersection.Combine : Intersection.Xor
    }

    property var rawBarSettings: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({})
    property string barPosition: (rawBarSettings && rawBarSettings.position !== undefined) ? rawBarSettings.position : "top"
    // the Anserin interface has no Bar: nothing keeps room for it
    property bool barAutohide: true

    readonly property bool isFullscreenActive: {
        if (ScreenEdges.modern) return ScreenEdges.fullscreen(screen);
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isBarEffectivelyHidden: isFullscreenActive || (barAutohide && popupBarScreen === "")
    readonly property bool screenReady: masterWindow.width >= 100 && masterWindow.height >= 100
    readonly property bool isCurrentDraggable: {
        let t = getLayout(masterWindow.currentActive);
        return Boolean(t && t.draggable);
    }

    Item {
        id: topBarHole

        property int barThickness: 48
        property string bp: masterWindow.barPosition
        property bool activeBar: !masterWindow.isBarEffectivelyHidden

        property bool overlapTopLeft: masterWindow.currentActive !== "hidden" && animContainer.x < 10 && animContainer.y < barThickness
        property bool overlapTopRight: masterWindow.currentActive !== "hidden" && (animContainer.x + animContainer.width) > (masterWindow.width - 10) && animContainer.y < barThickness
        property bool overlapBottomLeft: masterWindow.currentActive !== "hidden" && animContainer.x < 10 && (animContainer.y + animContainer.height) > (masterWindow.height - barThickness)
        property bool overlapBottomRight: masterWindow.currentActive !== "hidden" && (animContainer.x + animContainer.width) > (masterWindow.width - 10) && (animContainer.y + animContainer.height) > (masterWindow.height - barThickness)

        x: {
            if (!activeBar) return 0;
            if (bp === "left") return 0;
            if (bp === "right") return masterWindow.width - barThickness;
            if (overlapTopLeft && bp === "top") return animContainer.width;
            if (overlapBottomLeft && bp === "bottom") return animContainer.width;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "top") return 0;
            if (bp === "bottom") return masterWindow.height - barThickness;
            if (overlapTopLeft && bp === "left") return animContainer.height;
            if (overlapTopRight && bp === "right") return animContainer.height;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return barThickness;
            let w = masterWindow.width;
            if (overlapTopLeft && bp === "top") w -= animContainer.width;
            if (overlapTopRight && bp === "top") w -= animContainer.width;
            if (overlapBottomLeft && bp === "bottom") w -= animContainer.width;
            if (overlapBottomRight && bp === "bottom") w -= animContainer.width;
            return Math.max(0, w);
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return barThickness;
            let h = masterWindow.height;
            if (overlapTopLeft && bp === "left") h -= animContainer.height;
            if (overlapBottomLeft && bp === "left") h -= animContainer.height;
            if (overlapTopRight && bp === "right") h -= animContainer.height;
            if (overlapBottomRight && bp === "right") h -= animContainer.height;
            return Math.max(0, h);
        }

        Behavior on x {
            enabled: masterWindow.currentActive !== "hidden" && !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: masterWindow.currentActive !== "hidden" && !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: masterWindow.currentActive !== "hidden" && !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: masterWindow.currentActive !== "hidden" && !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: masterWindow.isVisible && !masterWindow.isCurrentDraggable && !masterWindow.isClosing && masterWindow.openModalCount === 0
        onClicked: switchWidget("hidden", "")
    }

    Item {
        id: preloaderContainer
        visible: false
    }

    // Control → Theme → Lock screen → Select: Select Wallpaper across the whole screen as it always is, under the Control
    // Center, which stays open and usable on top of it. While it is up the window takes the pointer everywhere
    // (needsPopupInput); a click outside its cards or Esc puts it away.
    Loader {
        id: lockPicker
        active: Wallpaper.lockPickInline && masterWindow.currentActive === "controlcenter" && !masterWindow.isClosing
        onActiveChanged: if (!active && Wallpaper.lockPickInline) Wallpaper.closeLockPicker()
        // no z: declared after the click-outside area above (so the cards take their clicks) and before animContainer
        // (so the panel stays on top)
        anchors.fill: parent
        sourceComponent: Item {
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: Wallpaper.closeLockPicker() }
            Loader {
                width: parent.width
                height: Scaler.s(650)
                y: (parent.height - height) / 2
                source: "wallpaper/WallpaperPicker.qml"
                onLoaded: {
                    item.visible = true                // Select waits hidden until its host shows it
                    item.barRoom = Qt.binding(() => masterWindow._animX - Scaler.s(16))   // its bar clear of the panel
                }
            }
        }
    }

    property var widgetCache: ({})
    property var componentCache: ({})

    function widgetNameForItem(item) {
        for (let name in widgetCache) {
            if (widgetCache[name] === item) return name;
        }
        return null;
    }

    function ensureWidgetItem(name, t) {
        let cached = widgetCache[name];
        if (cached) return cached;

        let comp = componentCache[name];
        if (!comp) {
            comp = typeof t.comp === "string" ? Qt.createComponent(t.comp) : t.comp;
            if (comp) componentCache[name] = comp;
        }
        if (!comp) return null;

        if (comp.status === Component.Loading) return null;
        if (comp.status === Component.Error) {
            console.warn("Widget component failed to load:", name, comp.errorString());
            return null;
        }

        let item = comp.createObject(preloaderContainer);
        if (item) {
            item.visible = false;
            widgetCache[name] = item;
            builtWidgets = Object.keys(widgetCache).length;
            if (name === "wallpaper") pristineWallpaper = true;
        }
        return item;
    }

    // A panel is built on its first open and kept while it is in use, so reopening it soon is instant. Once every panel
    // has been closed for a while they are all let go, giving back their pictures, textures and objects; the next open
    // builds the panel again (the compiled component stays cached). The wallpaper picker is built again right away,
    // hidden, as at start: unshown it holds almost nothing and its first open stays instant.
    property int builtWidgets: 0
    property bool pristineWallpaper: false
    function releaseHiddenWidgets() {
        if (masterWindow.currentActive !== "hidden" || masterWindow.targetActive !== "hidden" || masterWindow.isClosing
            || masterWindow.isVisible) return;
        let names = Object.keys(widgetCache);
        widgetStack.clear(StackView.Immediate);
        for (let name of names) {
            let it = widgetCache[name];
            delete widgetCache[name];
            if (it) it.destroy();
        }
        builtWidgets = 0;
        Qt.callLater(function() {
            gc();
            masterWindow.preloadWallpaper();
        });
    }
    function preloadWallpaper() {
        if (masterWindow.currentActive !== "hidden") return;
        let w = masterWindow.getLayout("wallpaper");
        if (w) masterWindow.ensureWidgetItem("wallpaper", w);
    }

    Timer {
        // a picker that was only preloaded, never shown, is left alone
        interval: 30000
        running: masterWindow.currentActive === "hidden" && masterWindow.targetActive === "hidden" && !masterWindow.isVisible
            && !masterWindow.isClosing
            && masterWindow.builtWidgets > 0 && !(masterWindow.builtWidgets === 1 && masterWindow.pristineWallpaper)
        onTriggered: masterWindow.releaseHiddenWidgets()
    }

    Component.onCompleted: {
        applyConfigSettings();
        reportWidgetState();
        Qt.callLater(masterWindow.preloadWallpaper);
    }

    Component.onDestruction: {
        if (typeof Caching !== "undefined" && Caching.runDir) {
            Quickshell.execDetached(["bash", "-c", "echo '{\"widget\":\"hidden\",\"screen\":\"\"}' > " + Caching.runDir + "/current_widget"]);
        }
    }

    property string targetActive: "hidden"
    property string barRequestScreen: ""
    property string popupBarScreen: ""
    property string popupScreenName: ""
    property string currentActive: "hidden"

    onCurrentActiveChanged: {
        reportWidgetState();
    }

    onScreenChanged: {
        applyConfigSettings();
        if (currentActive !== "hidden") {
            reportWidgetState();
        }
    }

    property bool isVisible: false
    property bool isClosing: false
    property string activeArg: ""
    // Anserin interface: what the Settings window was asked to show; Control Center > Control shows it instead
    property var pendingControl: null
    property bool disableMorph: true
    property int switchGeneration: 0
    property bool userMoved: false

    property int morphDuration:       300
    property int morphDurationSwitch: 300
    property int exitDuration:        180

    property real _animW: 1
    property real _animH: 1
    property real _animX: 0
    property real _animY: 0

    property real _stageW: 1
    property real _stageH: 1

    property real globalUiScale: 1.0

    Notifs.NotificationPopups {
        id: osdPopups
    }

    function applyConfigSettings() {
        let parsed = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings : {};
        let sVal = undefined;

        if (parsed.general && parsed.general.uiScale !== undefined) {
            sVal = parsed.general.uiScale;
        } else if (parsed.uiScale !== undefined) {
            sVal = parsed.uiScale;
        }

        let targetScale = (sVal !== undefined && typeof sVal === "number" && !isNaN(sVal) && sVal > 0) ? sVal : 1.0;
        if (masterWindow.globalUiScale !== targetScale) {
            masterWindow.globalUiScale = targetScale;
        }

        let b = parsed.bar || {};
        masterWindow.rawBarSettings = b;
        if (b.position !== undefined) masterWindow.barPosition = b.position;
        if (b.autohide !== undefined) masterWindow.barAutohide = Boolean(b.autohide);
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            masterWindow.applyConfigSettings();
        }
    }

    function getLayout(name) {
        let bp = masterWindow.barPosition;
        let effHidden = masterWindow.isBarEffectivelyHidden;
        let scrW = (masterWindow.screen ? masterWindow.screen.width : masterWindow.width) - masterWindow.frameInset * 2;
        let scrH = (masterWindow.screen ? masterWindow.screen.height : masterWindow.height) - masterWindow.frameInset * 2;

        let result = Registry.getLayout(name, 0, 0, scrW, scrH, masterWindow.globalUiScale, bp);
        if (!result) return null;

        let scale = masterWindow.globalUiScale || 1.0;
        let isFixed = (name === "wallpaper" || name === "notifications" || name === "system" || name === "controlcenter" || name === "blankpanel" || name === "hidden");

        if (effHidden && !isFixed) {
            let offsetAdjustment = Math.round(46 * scale);
            let adjusted = {
                w: result.w,
                h: result.h,
                rx: result.rx,
                ry: result.ry,
                comp: result.comp,
                draggable: result.draggable
            };

            if (bp === "top") {
                adjusted.ry = Math.max(Math.round(6 * scale), result.ry - offsetAdjustment);
            } else if (bp === "bottom") {
                adjusted.ry = Math.min(masterWindow.height - result.h - Math.round(6 * scale), result.ry + offsetAdjustment);
            } else if (bp === "left" && name !== "calendar" && name !== "dashboard") {
                adjusted.rx = Math.max(Math.round(6 * scale), result.rx - offsetAdjustment);
            } else if (bp === "right" && name !== "calendar" && name !== "dashboard") {
                adjusted.rx = Math.min(masterWindow.width - result.w - Math.round(6 * scale), result.rx + offsetAdjustment);
            }

            return adjusted;
        }

        return result;
    }

    function recenterX(t, dynW) {
        let originalCenterX = t.rx + Math.floor(t.w / 2);
        return Math.floor(originalCenterX - (dynW / 2));
    }

    readonly property var targetLayout: {
        if (currentActive === "hidden" || currentActive === "") return null;
        if (!screenReady) return null;

        let t = getLayout(currentActive);
        if (!t || !t.w || !t.h || t.w < 10 || t.h < 10) return null;

        if (t.rx < -t.w - 50 || t.ry < -t.h - 50 ||
            t.rx > masterWindow.width + 50 || t.ry > masterWindow.height + 50) {
            return null;
        }

        let item = widgetCache[currentActive];
        let tw = t.w, th = t.h;
        if (item) {
            if (typeof item.targetMasterWidth === "number" && !isNaN(item.targetMasterWidth) && item.targetMasterWidth >= 50) {
                tw = item.targetMasterWidth;
            }
            if (typeof item.targetMasterHeight === "number" && !isNaN(item.targetMasterHeight) && item.targetMasterHeight >= 50) {
                th = item.targetMasterHeight;
            }
        }

        let x = (tw !== t.w) ? recenterX(t, tw) : t.rx;
        return { x: x, y: t.ry, w: tw, h: th };
    }

    onTargetLayoutChanged: {
        if (!targetLayout || masterWindow.currentActive === "hidden" || !masterWindow.isVisible) return;
        if (!masterWindow.userMoved || !masterWindow.isCurrentDraggable) {
            masterWindow._animX = targetLayout.x;
            masterWindow._animY = targetLayout.y;
        }
        masterWindow._animW = targetLayout.w;
        masterWindow._animH = targetLayout.h;
        masterWindow._stageW = targetLayout.w;
        masterWindow._stageH = targetLayout.h;
    }

    onIsVisibleChanged: {
        if (isVisible) {
            widgetStack.forceActiveFocus();
        } else if (currentActive === "hidden" && !delayedClear.running) {
            for (let k in widgetCache) {
                let it = widgetCache[k];
                if (it) it.visible = false;
            }
        }
    }

    Item {
        id: animContainer
        x: masterWindow._animX
        y: masterWindow._animY
        width: masterWindow._animW
        height: masterWindow._animH
        clip: true

        Item {
            id: windowDragRegion
            anchors.fill: parent
            containmentMask: QtObject {
                function contains(point: point): bool {
                    let item = masterWindow.widgetCache[masterWindow.currentActive];
                    return !item || typeof item.windowDragContains !== "function"
                        || item.windowDragContains(item.mapFromItem(windowDragRegion, point));
                }
            }

            DragHandler {
                id: windowDragHandler
                parent: windowDragRegion
                target: null
                acceptedButtons: Qt.LeftButton
                enabled: masterWindow.isCurrentDraggable

                property real startX: 0
                property real startY: 0

                onActiveChanged: {
                    if (active) {
                        masterWindow.disableMorph = true;
                        startX = masterWindow._animX;
                        startY = masterWindow._animY;
                    } else {
                        masterWindow.disableMorph = false;
                    }
                }

                onTranslationChanged: {
                    if (active) {
                        masterWindow.userMoved = true;
                        masterWindow._animX = startX + translation.x;
                        masterWindow._animY = startY + translation.y;
                    }
                }
            }

            Item {
                id: contentStage
                width: masterWindow._stageW
                height: masterWindow._stageH
                x: (animContainer.width - width) / 2
                y: (animContainer.height - height) / 2
                transformOrigin: Item.Center

                scale: masterWindow.isVisible ? 1.0 : 0.96
                Behavior on scale {
                    NumberAnimation {
                        duration: masterWindow.isVisible ? 280 : 160
                        easing.type: masterWindow.isVisible ? Easing.OutCubic : Easing.InCubic
                    }
                }

                opacity: masterWindow.isVisible ? 1.0 : 0.0
                visible: masterWindow.isVisible || opacity > 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: masterWindow.isVisible ? 200 : 140
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea { anchors.fill: parent }

                StackView {
                    id: widgetStack
                    anchors.fill: parent
                    focus: true

                    replaceEnter: null
                    replaceExit: null
                    pushEnter: null
                    pushExit: null
                    popEnter: null
                    popExit: null

                    Keys.onEscapePressed: (event) => {
                        switchWidget("hidden", "");
                        event.accepted = true;
                    }

                    onCurrentItemChanged: {
                        if (currentItem) currentItem.forceActiveFocus();
                    }
                }
            }
        }

        Behavior on x {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on width {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            enabled: !masterWindow.disableMorph
            NumberAnimation { duration: masterWindow.morphDuration; easing.type: Easing.OutCubic }
        }
    }

    // Edge panels ask before auto-hiding: a pointer resting on their screen edge still counts as being on
    // them. Hover events can't tell, because the edge strip stops receiving them while a panel is open.
    Process {
        id: cursorProbe
        property string edge: ""
        property var answer: null
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector { id: cursorOutput }
        onExited: code => {
            let onEdge = false;
            try {
                const screen = masterWindow.screen;
                const x = JSON.parse(cursorOutput.text).x - screen.x;
                const band = Math.max(masterWindow.frameInset, 2);
                onEdge = code === 0 && (edge === "left" ? x < band : x >= screen.width - band);
            } catch (failure) {
                onEdge = false;
            }
            const done = answer;
            answer = null;
            if (done) done(onEdge);
        }
    }

    function checkPointerOnEdge(edge, done) {
        if (cursorProbe.running) return;
        cursorProbe.edge = edge;
        cursorProbe.answer = done;
        cursorProbe.running = true;
    }

    function openFromEdge(widgetName, screenName) {
        if (masterWindow.targetActive === widgetName) return;
        masterWindow.barRequestScreen = screenName;
        try {
            switchWidget(widgetName, "");
        } finally {
            masterWindow.barRequestScreen = "";
        }
    }

    // a window that can be asked for: a layout of its own, or Settings ("guide"), shown in Control Center > Control
    function opens(name) { return name === "guide" || !!getLayout(name); }

    function switchWidget(newWidget, arg) {
        // There is no Bar, so no popups of its own: Network and Music open as pages of the left panel.
        const panelPage = ({ network: "network", music: "music" })[newWidget];
        if (panelPage) {
            newWidget = "blankpanel";
            arg = panelPage;
            if (masterWindow.currentActive === "blankpanel" && !masterWindow.isClosing && widgetCache.blankpanel) {
                widgetCache.blankpanel.gotoTab(panelPage);
                return;
            }
        }
        // There is no Settings window: its pages live in Control Center > Control.
        if (newWidget === "guide") {
            masterWindow.pendingControl = arg || "";
            newWidget = "controlcenter";
            arg = "";
            if (masterWindow.currentActive === "controlcenter" && !masterWindow.isClosing && widgetCache.controlcenter) {
                widgetCache.controlcenter.applyPendingControl();
                return;
            }
        }
        // A close asked for while one is already playing (Esc then a click outside, or the panel's own auto-hide) lets that
        // one finish: starting over would drop its callback and leave the window stuck closing, never hidden.
        if (newWidget === "hidden" && masterWindow.isClosing) return;
        if (newWidget !== "hidden") {
            masterWindow.popupScreenName = masterWindow.barRequestScreen;
            // Panels opened from a screen edge are independent of the bar: they must not reveal an auto-hidden bar.
            masterWindow.popupBarScreen = (newWidget === "controlcenter" || newWidget === "blankpanel") ? "" : masterWindow.barRequestScreen;
        }
        masterWindow.switchGeneration++;
        let gen = masterWindow.switchGeneration;
        masterWindow.targetActive = newWidget;

        masterWindow.userMoved = false;

        if (delayedClear.running) {
            delayedClear.stop();
        }
        if (exitSafetyTimer.running) {
            exitSafetyTimer.stop();
        }

        if (newWidget === "hidden") {
            if (currentActive !== "hidden" && !masterWindow.isClosing) {
                let closingGen = gen;
                masterWindow.isClosing = true;
                masterWindow.targetActive = "hidden";

                let activeItem = widgetCache[currentActive] || widgetStack.currentItem;

                let finalizeClose = function() {
                    if (closingGen !== masterWindow.switchGeneration) return;
                    masterWindow.isClosing = false;
                    masterWindow.currentActive = "hidden";
                    masterWindow.morphDuration = masterWindow.exitDuration;
                    masterWindow.disableMorph = true;
                    masterWindow.isVisible = false;

                    for (let k in widgetCache) {
                        let it = widgetCache[k];
                        if (it) it.visible = false;
                    }
                    reportWidgetState();
                };

                if (activeItem && typeof activeItem.startExit === "function") {
                    exitSafetyTimer.scheduledGeneration = closingGen;
                    exitSafetyTimer.restart();
                    activeItem.startExit(finalizeClose);
                } else {
                    finalizeClose();
                }
            }
        } else {
            masterWindow.isClosing = false;
            let targetScreen = resolveTargetScreen();
            if (targetScreen && masterWindow.screen !== targetScreen) {
                masterWindow.screen = targetScreen;
            }
            executeSwitch(newWidget, arg, gen);
        }
    }

    function executeSwitch(newWidget, arg, gen) {
        if (gen !== masterWindow.switchGeneration || newWidget === "hidden") return;

        let targetScreen = resolveTargetScreen();
        if (targetScreen && masterWindow.screen !== targetScreen) {
            masterWindow.screen = targetScreen;
        }

        let t = getLayout(newWidget);
        if (!t || !t.w || !t.h || t.w < 10 || t.h < 10) {
            Qt.callLater(function() {
                if (gen === masterWindow.switchGeneration) {
                    executeSwitch(newWidget, arg, gen);
                }
            });
            return;
        }

        let cachedItem = ensureWidgetItem(newWidget, t);
        if (!cachedItem) {
            Qt.callLater(function() {
                if (gen === masterWindow.switchGeneration) {
                    executeSwitch(newWidget, arg, gen);
                }
            });
            return;
        }

        if (gen !== masterWindow.switchGeneration) return;

        if (cachedItem.targetMasterWidth !== undefined)  cachedItem.targetMasterWidth  = t.w;
        if (cachedItem.targetMasterHeight !== undefined) cachedItem.targetMasterHeight = t.h;

        let isComingFromHidden = (!masterWindow.isVisible || widgetStack.currentItem === null || masterWindow.currentActive === "hidden");

        masterWindow.currentActive = newWidget;
        masterWindow.activeArg = arg;
        if (newWidget === "wallpaper") masterWindow.pristineWallpaper = false;

        let finalW = (typeof cachedItem.targetMasterWidth === "number" && cachedItem.targetMasterWidth >= 50) ? cachedItem.targetMasterWidth : t.w;
        let finalH = (typeof cachedItem.targetMasterHeight === "number" && cachedItem.targetMasterHeight >= 50) ? cachedItem.targetMasterHeight : t.h;
        let finalX = (finalW !== t.w) ? recenterX(t, finalW) : t.rx;
        let finalY = t.ry;

        if (!masterWindow.userMoved || !masterWindow.isCurrentDraggable) {
            masterWindow._animX = finalX;
            masterWindow._animY = finalY;
        }
        masterWindow._animW = finalW;
        masterWindow._animH = finalH;
        masterWindow._stageW = finalW;
        masterWindow._stageH = finalH;

        if (isComingFromHidden) {
            masterWindow.disableMorph = true;
        } else {
            masterWindow.morphDuration = masterWindow.morphDurationSwitch;
            masterWindow.disableMorph = false;
        }

        if (newWidget === "wallpaper" && cachedItem.widgetArg !== undefined) cachedItem.widgetArg = arg;
        if (newWidget === "wallpaper" && cachedItem.refreshForDisplay !== undefined) cachedItem.refreshForDisplay();
        if (arg !== "" && cachedItem.activeMode !== undefined) cachedItem.activeMode = arg;
        if (arg !== "" && cachedItem.gotoTab !== undefined) cachedItem.gotoTab(arg);

        if (widgetStack.currentItem !== cachedItem) {
            widgetStack.replace(cachedItem, {}, StackView.Immediate);
        }

        for (let k in widgetCache) {
            let it = widgetCache[k];
            if (it && it !== cachedItem) {
                it.visible = false;
            }
        }
        cachedItem.visible = true;

        masterWindow.isVisible = true;

        if (isComingFromHidden) {
            Qt.callLater(function() {
                if (gen === masterWindow.switchGeneration && masterWindow.isVisible && masterWindow.currentActive === newWidget) {
                    masterWindow.disableMorph = false;
                }
            });
        }
    }

    Timer {
        id: exitSafetyTimer
        interval: 450
        property int scheduledGeneration: -1
        onTriggered: {
            if (scheduledGeneration === masterWindow.switchGeneration && masterWindow.isClosing) {
                masterWindow.isClosing = false;
                masterWindow.currentActive = "hidden";
                masterWindow.morphDuration = masterWindow.exitDuration;
                masterWindow.disableMorph = true;
                masterWindow.isVisible = false;
                for (let k in widgetCache) {
                    let it = widgetCache[k];
                    if (it) it.visible = false;
                }
                reportWidgetState();
            }
        }
    }

    Timer {
        id: delayedClear
        interval: 200
        property int scheduledGeneration: -1
        onTriggered: {
            if (masterWindow.currentActive === "hidden" && scheduledGeneration === masterWindow.switchGeneration) {
                masterWindow.disableMorph = true;
                for (let k in widgetCache) {
                    let it = widgetCache[k];
                    if (it) it.visible = false;
                }
            }
        }
    }
}
