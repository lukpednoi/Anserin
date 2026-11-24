import QtQuick
import Quickshell
import Quickshell.Io
import "widgets"
import "anserin"
import "claude"

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false

    // Lazy overlay host: mounts heavy full-screen PanelWindows only while open + a short grace period for close
    // animations and rapid re-opens, then destroys them and trims freed heap pages back to the OS.
    component LazyOverlay: Item {
        id: host
        property bool wantOpen: false
        property string sourceUrl: ""
        property int graceMs: 1500
        property bool keepAlive: wantOpen

        onWantOpenChanged: {
            if (wantOpen) {
                unloadTimer.stop();
                keepAlive = true;
            } else if (keepAlive) {
                unloadTimer.restart();
            }
        }

        Timer {
            id: unloadTimer
            interval: host.graceMs
            repeat: false
            onTriggered: {
                if (!host.wantOpen) {
                    host.keepAlive = false;
                    Qt.callLater(function() {
                        gc();
                        if (typeof Sounds !== "undefined") Sounds.trimMemory();
                    });
                }
            }
        }

        Loader {
            active: host.wantOpen || host.keepAlive
            source: active ? host.sourceUrl : ""
        }
    }

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    // ScreenshotOverlay (1600+ lines) stays unloaded until IPC requests it, then unloads after closing.
    Item {
        id: screenshotHost
        property bool keepAlive: false
        property var pendingArgs: null

        function dispatchActivate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon) {
            screenshotUnloadTimer.stop();
            keepAlive = true;
            if (screenshotLoader.item) {
                screenshotLoader.item.activate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
            } else {
                pendingArgs = [img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon];
            }
        }

        readonly property bool overlayBusy: !!(screenshotLoader.item && (
            screenshotLoader.item.isActive || screenshotLoader.item.isLoading
            || screenshotLoader.item.isRefreezing || screenshotLoader.item.showQrPopup
            || screenshotLoader.item.isScanningQr
        ))

        onOverlayBusyChanged: {
            if (overlayBusy) {
                screenshotUnloadTimer.stop();
            } else if (keepAlive && !pendingArgs) {
                screenshotUnloadTimer.restart();
            }
        }

        Timer {
            id: screenshotUnloadTimer
            interval: 2500
            repeat: false
            onTriggered: {
                if (!screenshotHost.overlayBusy && !screenshotHost.pendingArgs) {
                    screenshotHost.keepAlive = false;
                    Qt.callLater(function() {
                        gc();
                        if (typeof Sounds !== "undefined") Sounds.trimMemory();
                    });
                }
            }
        }

        IpcHandler {
            target: "screenshotOverlay"

            function toggle(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
                if (screenshotLoader.item && screenshotLoader.item.isActive) {
                    if (img && img !== "") Quickshell.execDetached(["bash", "-c", "rm -f " + img]);
                    screenshotLoader.item.deactivate();
                } else {
                    screenshotHost.dispatchActivate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
                }
            }

            function activate(img: string, editMode: string, audioPrefs: string, cGeom: string, cGeomVideo: string, cMode: string, cBackend: string, targetMon: string): void {
                screenshotHost.dispatchActivate(img, editMode, audioPrefs, cGeom, cGeomVideo, cMode, cBackend, targetMon);
            }

            function deactivate(): void {
                screenshotHost.pendingArgs = null;
                if (screenshotLoader.item) screenshotLoader.item.deactivate();
            }
        }

        Loader {
            id: screenshotLoader
            active: screenshotHost.keepAlive
            source: active ? Qt.resolvedUrl("screenshot/ScreenshotOverlay.qml") : ""
            onLoaded: {
                if (item && screenshotHost.pendingArgs) {
                    const a = screenshotHost.pendingArgs;
                    screenshotHost.pendingArgs = null;
                    item.activate(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]);
                } else if (!screenshotHost.overlayBusy) {
                    screenshotUnloadTimer.restart();
                }
            }
        }
    }

    Main { id: mainWindow }
    EdgeBatteryTrigger { onTriggered: function(screenName) { mainWindow.openFromEdge("controlcenter", screenName); } }
    // the left edge: the full panel, or in Workspace only the small workspace capsule first
    EdgeBatteryTrigger {
        edge: "left"
        onTriggered: function(screenName) {
            if (mainWindow.currentActive === "blankpanel") return;
            if (PanelLayout.workspaceOnly) PanelLayout.showCapsule(screenName);
            else mainWindow.openFromEdge("blankpanel", screenName);
        }
    }
    Loader {
        active: PanelLayout.capsuleScreen !== ""
        sourceComponent: WorkspaceCapsule { checkEdge: done => mainWindow.checkPointerOnEdge("left", done) }
    }
    ScreenBorder {}
    // inf desktop: the still cursor shown while the canvas pans (only while the mode is on somewhere)
    Loader {
        active: TerminalAppearance.infiniteActive
        sourceComponent: PanCursor {}
    }
    Lock { id: sessionLock }

    // LockRedactor (740 lines) and WidgetRedactor (2850 lines) stay completely unloaded until opened via IPC,
    // then unload after closing and trim freed heap pages back to the OS.
    Item {
        id: redactorsHost
        property bool lockKeepAlive: false
        property var lockPendingMon: null
        property bool widgetKeepAlive: false
        property var widgetPending: null

        function openLock(mon) {
            lockUnloadTimer.stop();
            lockKeepAlive = true;
            if (lockRedactorLoader.item) {
                lockRedactorLoader.item.open(mon);
            } else {
                lockPendingMon = mon !== undefined ? mon : "";
            }
        }
        function closeLock() {
            lockPendingMon = null;
            if (lockRedactorLoader.item) lockRedactorLoader.item.close();
        }
        function toggleLock(mon) {
            if (lockRedactorLoader.item && lockRedactorLoader.item.isActive) closeLock();
            else openLock(mon);
        }

        function openWidget(mon, widgetId, context) {
            if (context === "lockscreen" || context === "dashboard") {
                openLock(mon);
                return;
            }
            widgetUnloadTimer.stop();
            widgetKeepAlive = true;
            if (widgetRedactorLoader.item) {
                widgetRedactorLoader.item.open(mon, widgetId, "");
            } else {
                widgetPending = [mon !== undefined ? mon : "", widgetId !== undefined ? widgetId : ""];
            }
        }
        function closeWidget() {
            widgetPending = null;
            if (widgetRedactorLoader.item) widgetRedactorLoader.item.close();
        }
        function toggleWidget(mon, widgetId) {
            if (widgetRedactorLoader.item && widgetRedactorLoader.item.isActive) closeWidget();
            else openWidget(mon, widgetId, "");
        }

        readonly property bool lockBusy: !!(lockRedactorLoader.item && lockRedactorLoader.item.isActive)
        readonly property bool widgetBusy: !!(widgetRedactorLoader.item && widgetRedactorLoader.item.isActive)

        onLockBusyChanged: {
            if (lockBusy) lockUnloadTimer.stop();
            else if (lockKeepAlive && lockPendingMon === null) lockUnloadTimer.restart();
        }
        onWidgetBusyChanged: {
            if (widgetBusy) widgetUnloadTimer.stop();
            else if (widgetKeepAlive && widgetPending === null) widgetUnloadTimer.restart();
        }

        Timer {
            id: lockUnloadTimer
            interval: 1500
            repeat: false
            onTriggered: {
                if (!redactorsHost.lockBusy && redactorsHost.lockPendingMon === null) {
                    redactorsHost.lockKeepAlive = false;
                    Qt.callLater(function() {
                        gc();
                        if (typeof Sounds !== "undefined") Sounds.trimMemory();
                    });
                }
            }
        }

        Timer {
            id: widgetUnloadTimer
            interval: 1500
            repeat: false
            onTriggered: {
                if (!redactorsHost.widgetBusy && redactorsHost.widgetPending === null) {
                    redactorsHost.widgetKeepAlive = false;
                    Qt.callLater(function() {
                        gc();
                        if (typeof Sounds !== "undefined") Sounds.trimMemory();
                    });
                }
            }
        }

        IpcHandler {
            target: "lock-redactor"
            function open(mon: string): void { redactorsHost.openLock(mon); }
            function toggle(): void { redactorsHost.toggleLock(""); }
            function close(): void { redactorsHost.closeLock(); }
        }

        IpcHandler {
            target: "redactor"
            function activate(): void { redactorsHost.openWidget("", "", ""); }
            function open(mon: string, widgetId: string): void { redactorsHost.openWidget(mon, widgetId, ""); }
            function toggle(): void { redactorsHost.toggleWidget("", ""); }
            function close(): void { redactorsHost.closeWidget(); }
        }

        IpcHandler {
            target: "widget-redactor"
            function editLayout(context: string, mon: string): void {
                if (context !== "lockscreen" && context !== "dashboard") return;
                redactorsHost.openWidget(mon, "", context);
            }
            function activate(): void { redactorsHost.openWidget("", "", ""); }
            function open(mon: string, widgetId: string): void { redactorsHost.openWidget(mon, widgetId, ""); }
            function toggle(): void { redactorsHost.toggleWidget("", ""); }
            function close(): void { redactorsHost.closeWidget(); }
        }

        Loader {
            id: lockRedactorLoader
            active: redactorsHost.lockKeepAlive
            source: active ? Qt.resolvedUrl("lock/redactor/LockRedactor.qml") : ""
            onLoaded: {
                if (!item) return;
                item.sessionLocked = Qt.binding(() => sessionLock.isLocked);
                if (redactorsHost.lockPendingMon !== null) {
                    const m = redactorsHost.lockPendingMon;
                    redactorsHost.lockPendingMon = null;
                    item.open(m);
                } else if (!redactorsHost.lockBusy) {
                    lockUnloadTimer.restart();
                }
            }
        }

        Loader {
            id: widgetRedactorLoader
            active: redactorsHost.widgetKeepAlive
            source: active ? Qt.resolvedUrl("widgets/WidgetRedactor.qml") : ""
            onLoaded: {
                if (!item) return;
                item.sessionLocked = Qt.binding(() => sessionLock.isLocked);
                if (redactorsHost.widgetPending !== null) {
                    const p = redactorsHost.widgetPending;
                    redactorsHost.widgetPending = null;
                    item.open(p[0], p[1], "");
                } else if (!redactorsHost.widgetBusy) {
                    widgetUnloadTimer.restart();
                }
            }
        }
    }

    // Edit panel for the left edge panel's sidebar, made only while it is open; the panel reopens after it.
    Loader {
        active: PanelLayout.editing
        sourceComponent: PanelEditor {}
    }
    Connections {
        target: PanelLayout
        function onEditFinished(screenName) { mainWindow.openFromEdge("blankpanel", screenName); }
        function onExpandRequested(screenName) { mainWindow.openFromEdge("blankpanel", screenName); }
    }

    LazyOverlay { wantOpen: LauncherController.isVisible; sourceUrl: Qt.resolvedUrl("launcher/Launcher.qml"); graceMs: 1500 }
    LazyOverlay { wantOpen: ClipboardController.isVisible; sourceUrl: Qt.resolvedUrl("clipboard/Clipboard.qml"); graceMs: 1500 }

    // the pet (Anserin interface): the duck on the desktop while Theme → Pet's Desktop pet is on, and its editor while
    // open; neither is made otherwise
    Loader {
        active: Config.dataReady && PetState.desktopOn
        sourceComponent: PetDesktop {}
    }
    Loader {
        active: PetState.editorShown
        sourceComponent: PetEditorWindow {}
    }

    LazyOverlay { wantOpen: PolkitService.isActive; sourceUrl: Qt.resolvedUrl("polkit/Polkit.qml"); graceMs: 600 }
    // Claude Panel (right-click menu / SUPER + C): made only while open or folded into its corner dome
    Loader {
        active: ClaudePanel.shown
        sourceComponent: ClaudeWelcomeOverlay {
            targetScreen: ClaudePanel.screen
            controller: ClaudePanel
            onFinished: ClaudePanel.closed()
        }
    }
    PopoutManager {}

    // Floating Music Bar capsule (Control → Panel → Music → "Music bar"): created ONLY when enabled
    Loader {
        active: !performanceMode && Config.getSetting("panel.musicBar.enabled", false) === true
        source: "popouts/MusicBar.qml"
        onLoaded: if (item) item.openMusicRequested.connect(() => mainWindow.switchWidget("music", ""))
    }

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Loader {
        active: !performanceMode
        sourceComponent: Idle {}
    }
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }

    // One-shot heap trim after startup settles so transient boot allocations return to the OS.
    Timer {
        id: startupTrimTimer
        interval: 12000
        repeat: false
        running: true
        onTriggered: {
            gc();
            if (typeof Sounds !== "undefined") Sounds.trimMemory();
        }
    }

    Component.onCompleted: {
        Qt.application.organization = "anserin";
        Qt.application.domain = "anserin";
        Qt.application.name = "anserin";
        AudioProcessor.initializeIfNeeded();
        FirstLaunch.checkFirstLaunch();
        TerminalAppearance.initialize();
        SysNotif.checkBattery();
        // anyone still on the old Default interface moves to Anserin once (its settings are kept)
        AnserinMode.migrate();
        // weather warnings from the forecast, and official warnings for this location (Settings → Weather)
        WeatherAlerts.isQuietNow();
        GovAlerts.refresh();
        // update posts: checks GitHub a minute after start, then every 6 hours (Settings → Update)
        Updates.localVersion;
    }
}
