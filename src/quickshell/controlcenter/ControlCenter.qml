import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"
import "../reusables"
import "../bar"
import "."
import "./smart" as Smart

// Control Center: right-edge panel opened by hovering the middle of the right screen edge.
// Independent of the bar; same size as the System panel. Overview = sliders, quick toggles and notifications, Control = settings.
Item {
    id: root
    // what the GlassFill tiles inside refract: the panel's own glass (EdgeBackground), as the bar does
    readonly property Item glassBackdropItem: panelBody.glassBackdrop
    visible: false
    focus: true
    enabled: visible

    function s(val) {
        return Scaler.s(val);
    }

    property string page: "overview"
    // a Settings page asked for in the Anserin interface (Main.qml pendingControl): opened in the Control tab
    property string requestedSettings: ""
    function applyPendingControl() {
        if (typeof masterWindow === "undefined" || masterWindow.pendingControl === null || masterWindow.pendingControl === undefined) return;
        const k = String(masterWindow.pendingControl);
        masterWindow.pendingControl = null;
        root.page = "control";
        root.requestedSettings = "";
        root.requestedSettings = k;
    }
    readonly property bool levelsActive: root.visible && root.page === "overview"

    readonly property real slideDistance: sidebarPanel.width > 0 ? sidebarPanel.width : root.s(420)
    readonly property real rowSlideDistance: root.s(36)
    readonly property real boxRadius: Math.min(ThemeBackend.borderRadius, root.s(20))
    readonly property real cardRadius: Math.min(ThemeBackend.borderRadius, root.s(14))

    readonly property color briColor: Qt.lighter(ThemeBackend.mauve, 1.1)
    readonly property color micColor: Qt.lighter(ThemeBackend.teal, 1.3)
    readonly property color volColor: Qt.lighter(ThemeBackend.sapphire, 1.5)

    readonly property real sysVolume: Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0
    readonly property bool sysMuted: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio.muted : false

    property real sysBrightness: 0

    property bool wifiRadioEnabled: Networking.wifiEnabled
    property bool btRadioEnabled: Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)

    Connections {
        target: Bluetooth
        ignoreUnknownSignals: true
        function onDefaultAdapterChanged() {
            root.btRadioEnabled = Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled);
        }
    }

    Connections {
        target: Bluetooth.defaultAdapter || null
        ignoreUnknownSignals: true
        function onEnabledChanged() {
            root.btRadioEnabled = Boolean(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled);
        }
    }

    property bool isDraggingVol: false
    property bool isDraggingBri: false
    property bool usesDdcBrightness: false

    property bool btStateBeforeAirplane: false
    property bool wifiStateBeforeAirplane: true

    // Microphone (default input)
    readonly property real sysMicVolume: Audio.defaultSource && Audio.defaultSource.audio ? Math.round(Audio.defaultSource.audio.volume * 100) : 0
    readonly property bool sysMicMuted: Audio.defaultSource && Audio.defaultSource.audio ? Audio.defaultSource.audio.muted : false
    property bool isDraggingMic: false

    // The dial's 0% is the dimmest level that is still lit (never a black screen).
    readonly property real briFloor: 5
    function briFromActual(a) { return Math.max(0, Math.min(100, (a - briFloor) / (100 - briFloor) * 100)); }
    function briToActual(p) { return Math.round(briFloor + Math.max(0, Math.min(100, p)) * (100 - briFloor) / 100); }

    // Levels shown on the wave dials. They follow the system unless the user is changing them.
    property real volLevel: sysVolume
    property real briLevel: briFromActual(sysBrightness)
    property real micLevel: sysMicVolume

    onSysVolumeChanged: { if (!root.isDraggingVol) root.volLevel = sysVolume; }
    onSysBrightnessChanged: { if (!root.isDraggingBri) root.briLevel = briFromActual(sysBrightness); }
    onSysMicVolumeChanged: { if (!root.isDraggingMic) root.micLevel = sysMicVolume; }

    // Airplane mode is its own switch: turning Wi-Fi off does not turn it on.
    // It turns itself off if a radio is switched back on by hand.
    property bool airplaneOn: false
    onWifiRadioEnabledChanged: { if (airplaneOn && (wifiRadioEnabled || btRadioEnabled)) airplaneOn = false; }
    onBtRadioEnabledChanged: { if (airplaneOn && (wifiRadioEnabled || btRadioEnabled)) airplaneOn = false; }

    function applyMic(pct) {
        pct = Math.max(0, Math.min(100, Math.round(pct)));
        root.micLevel = pct;
        root.isDraggingMic = true;
        micSyncDelay.restart();
        micCmdThrottle.targetPct = pct;
        if (!micCmdThrottle.running) micCmdThrottle.start();
    }

    function applyVolume(pct) {
        pct = Math.max(0, Math.min(100, Math.round(pct)));
        root.volLevel = pct;
        root.isDraggingVol = true;
        volSyncDelay.restart();
        volCmdThrottle.targetPct = pct;
        if (!volCmdThrottle.running) volCmdThrottle.start();
    }

    function applyBrightness(pct) {
        pct = Math.max(0, Math.min(100, Math.round(pct)));
        root.briLevel = pct;
        root.isDraggingBri = true;
        briSyncDelay.restart();
        briCmdThrottle.targetPct = root.briToActual(pct);
        if (!briCmdThrottle.running) briCmdThrottle.start();
    }

    // Screen recording state (same files the Bar's recording indicator reads).
    readonly property string recDir: Caching.cacheDir ? Caching.getCacheDir("recording") : ""
    property bool isRecording: false
    property real recStartEpoch: 0
    property int recSeconds: 0
    readonly property string recTimeText: String(Math.floor(recSeconds / 60)).padStart(2, "0") + ":" + String(recSeconds % 60).padStart(2, "0")

    // Auto-hide: close the panel once the pointer has been away from it for a moment.
    // settings.json -> controlcenter.autohide (default on), controlcenter.autohideDelay in ms (default 1200).
    readonly property var ccSettings: Config.getSetting("controlcenter", {})
    readonly property bool autoHideEnabled: !ccSettings || ccSettings.autohide !== false
    readonly property int autoHideDelay: (ccSettings && !isNaN(parseInt(ccSettings.autohideDelay))) ? Math.max(300, parseInt(ccSettings.autohideDelay)) : 1200
    property bool hoverSeen: false
    // also while the lock screen's Select is up beside the panel (Main.qml's lock picker), and after it goes (a pick or
    // a cancel) until the pointer has come back into the panel: the panel is not put away with it
    property bool waitForPointer: false
    Connections {
        target: Wallpaper
        function onLockPickInlineChanged() { if (!Wallpaper.lockPickInline && root.visible) root.waitForPointer = true; }
    }
    readonly property bool shortcutListening: root.visible && Boolean(controlLoader.item && controlLoader.item.shortcutListening)
    onShortcutListeningChanged: if (typeof masterWindow !== "undefined" && masterWindow && masterWindow.shortcutListening !== undefined) masterWindow.shortcutListening = shortcutListening
    readonly property bool holdOpen: isDraggingVol || isDraggingBri || isDraggingMic || Wallpaper.lockPickInline || waitForPointer || shortcutListening || (typeof masterWindow !== "undefined" && masterWindow.openModalCount > 0)

    function popupOpen() {
        const ov = Overlay.overlay;
        if (!ov) return false;
        for (let i = 0; i < ov.children.length; i++) if (ov.children[i].visible) return true;
        return false;
    }

    HoverHandler {
        id: panelHover
        onHoveredChanged: { if (hovered) { root.hoverSeen = true; root.waitForPointer = false; } }
    }
    Timer {
        id: autoHideTimer
        // a little longer when the pointer never came into the panel (opened from the edge or by keyboard)
        interval: root.hoverSeen ? root.autoHideDelay : root.autoHideDelay + 2500
        running: root.visible && root.autoHideEnabled && !panelHover.hovered && !root.holdOpen && !closeSequence.running
        onTriggered: {
            // a dropdown list that spills outside the panel still counts as the panel
            if (root.popupOpen()) { restart(); return; }
            if (typeof masterWindow === "undefined" || !masterWindow.switchWidget) { closeSequence.restart(); return; }
            masterWindow.checkPointerOnEdge("right", onEdge => {
                if (panelHover.hovered || !root.visible) return;
                if (onEdge) autoHideTimer.restart(); else masterWindow.switchWidget("hidden", "");
            });
        }
    }

    // Close the panel first, then start the screenshot / recording overlay so the panel is not in the picture.
    function launchCapture(mode) {
        root.startExit(function() {
            Quickshell.execDetached(["bash", "-c",
                'bash "$1/scripts/qs_manager.sh" close; sleep 0.4; exec bash "$1/scripts/screenshot.sh" --mode "$2"',
                "_", Caching.anserinDir, mode]);
        });
    }

    property real introContent: 0.0
    property real introTop: 0.0
    property real introSliders: 0.0
    property real introQuickActions: 0.0
    property real introNotifs: 0.0
    property real pageFade: 1.0

    onPageChanged: {
        pageFadeAnim.restart();
        if (page === "overview") {
            if (!isDraggingVol) root.volLevel = sysVolume;
            if (!isDraggingBri) root.briLevel = briFromActual(sysBrightness);
            if (!isDraggingMic) root.micLevel = sysMicVolume;
            nightLightBtn.updateState();
            coffeeBtn.updateState();
        }
    }

    NumberAnimation {
        id: pageFadeAnim
        target: root; property: "pageFade"; from: 0.0; to: 1.0; duration: 220; easing.type: Easing.OutCubic
    }

    function resetAndPlayIntro() {
        introContent = 0.0;
        introTop = 0.0;
        introSliders = 0.0;
        introQuickActions = 0.0;
        introNotifs = 0.0;
        closeSequence.stop();
        startupSequence.restart();
    }

    // Every time the panel is opened it starts on Overview, collapsed, with the Control tab back on its first page.
    Connections {
        target: typeof masterWindow !== "undefined" ? masterWindow : null
        ignoreUnknownSignals: true
        function onTargetActiveChanged() {
            if (masterWindow.targetActive === "controlcenter") {
                root.page = "overview";
                if (root.visible) Qt.callLater(root.applyPendingControl);
            }
        }
    }

    onVisibleChanged: {
        if (!visible) waitForPointer = false;
        if (visible) {
            forceActiveFocus();
            page = "overview";
            hoverSeen = panelHover.hovered;
            resetAndPlayIntro();
            Qt.callLater(root.applyPendingControl);
        } else {
            startupSequence.stop();
            closeSequence.stop();
        }
    }

    onLevelsActiveChanged: {
        if (levelsActive) {
            briPollerTimer.interval = 150;
            briPollerTimer.restart();
        } else {
            briPollerTimer.stop();
            briPoller.running = false;
        }
    }

    Component.onCompleted: {
        if (visible) {
            resetAndPlayIntro();
            forceActiveFocus();
        }
    }

    Component.onDestruction: briPollerTimer.stop()

    Timer {
        id: volCmdThrottle
        interval: 50
        property int targetPct: -1
        onTriggered: {
            if (targetPct >= 0) {
                if (targetPct > 0 && root.sysMuted) {
                    if (Audio.defaultSink && Audio.defaultSink.audio && Audio.defaultSink.audio.muted) {
                        Audio.toggleMute(Audio.defaultSink);
                    }
                }
                if (Audio.defaultSink) {
                    Audio.setVolume(Audio.defaultSink, targetPct);
                }
                targetPct = -1;
            }
        }
    }

    Timer {
        id: briCmdThrottle
        interval: root.usesDdcBrightness ? 400 : 120
        property int targetPct: -1
        onTriggered: {
            if (targetPct >= 0) {
                Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/brightness.sh", "set", targetPct.toString()]);
                targetPct = -1;
            }
        }
    }

    // Recording state is only checked while the panel is open.
    Timer {
        id: recPoll
        interval: 2000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: { if (root.recDir !== "") recCheck.running = true; }
    }
    Timer {
        id: recTick
        interval: 1000
        repeat: true
        running: root.visible && root.isRecording
        onTriggered: root.recSeconds = Math.max(0, Math.floor(Date.now() / 1000 - root.recStartEpoch))
    }
    Process {
        id: recCheck
        command: root.recDir ? [
            "bash", "-c",
            "d='" + root.recDir + "'; if [ -f \"$d/rec_pid\" ] && [ -f \"$d/rec_start_epoch\" ]; then p=$(cat \"$d/rec_pid\" 2>/dev/null); if [ -n \"$p\" ] && kill -0 \"$p\" 2>/dev/null; then cat \"$d/rec_start_epoch\" 2>/dev/null; else echo 'NONE'; fi; else echo 'NONE'; fi"
        ] : []
        stdout: StdioCollector {
            onStreamFinished: {
                let epoch = parseInt(this.text.trim());
                if (!isNaN(epoch) && epoch > 0) {
                    root.recStartEpoch = epoch;
                    root.recSeconds = Math.max(0, Math.floor(Date.now() / 1000 - epoch));
                    root.isRecording = true;
                } else {
                    root.isRecording = false;
                    root.recSeconds = 0;
                }
            }
        }
    }

    Timer {
        id: micSyncDelay
        interval: 800
        repeat: false
        onTriggered: root.isDraggingMic = false
    }

    Timer {
        id: micCmdThrottle
        interval: 50
        property int targetPct: -1
        onTriggered: {
            if (targetPct >= 0) {
                if (targetPct > 0 && root.sysMicMuted && Audio.defaultSource && Audio.defaultSource.audio) {
                    Audio.toggleMute(Audio.defaultSource);
                }
                if (Audio.defaultSource) Audio.setVolume(Audio.defaultSource, targetPct);
                targetPct = -1;
            }
        }
    }

    Timer {
        id: volSyncDelay
        interval: 800
        repeat: false
        onTriggered: root.isDraggingVol = false
    }

    Timer {
        id: briSyncDelay
        interval: 800
        repeat: false
        onTriggered: root.isDraggingBri = false
    }

    Timer {
        id: briPollerTimer
        interval: root.usesDdcBrightness ? 10000 : 1500
        repeat: false
        onTriggered: {
            if (root.levelsActive) {
                briPoller.running = true;
                interval = root.usesDdcBrightness ? 10000 : 1500;
            }
        }
    }

    Process {
        id: briBackend
        command: ["bash", Caching.qsDir + "/../scripts/brightness.sh", "backend"]
        running: root.levelsActive
        stdout: StdioCollector {
            onStreamFinished: root.usesDdcBrightness = this.text.trim() === "ddc"
        }
    }

    Process {
        id: briPoller
        command: ["bash", Caching.qsDir + "/../scripts/brightness.sh", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out !== "" && !root.isDraggingBri) {
                    root.sysBrightness = parseInt(out) || 0;
                }
                if (root.levelsActive) briPollerTimer.start();
            }
        }
    }

    ParallelAnimation {
        id: startupSequence
        NumberAnimation { target: root; property: "introContent"; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "introTop"; from: 0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 30 }
            NumberAnimation { target: root; property: "introSliders"; from: 0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 55 }
            NumberAnimation { target: root; property: "introQuickActions"; from: 0; to: 1.0; duration: 320; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {
            PauseAnimation { duration: 80 }
            NumberAnimation { target: root; property: "introNotifs"; from: 0; to: 1.0; duration: 330; easing.type: Easing.OutCubic }
        }
    }

    property var exitCallback: null

    function startExit(onFinished) {
        startupSequence.stop();
        exitCallback = onFinished;
        closeSequence.restart();
    }

    SequentialAnimation {
        id: closeSequence
        ParallelAnimation {
            NumberAnimation { target: root; property: "introContent"; to: 0.0; duration: 260; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introTop"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introSliders"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introQuickActions"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "introNotifs"; to: 0.0; duration: 220; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "close"]);
                }
            }
        }
    }

    Keys.onEscapePressed: (event) => {
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            closeSequence.restart();
        }
        event.accepted = true;
    }

    readonly property bool darkMode: (0.2126 * ThemeBackend.base.r + 0.7152 * ThemeBackend.base.g + 0.0722 * ThemeBackend.base.b) < 0.5
    readonly property color cAccent: ThemeBackend.mauve
    readonly property color cAccent2: ThemeBackend.peach
    readonly property color cOnAccent: {
        const lum = 0.2126 * cAccent.r + 0.7152 * cAccent.g + 0.0722 * cAccent.b;
        return lum > 0.52 ? "#0b0e14" : "#ffffff";
    }

    // Minimal Icon-Only Quick Action Tile:
    // - Pure centered icon (NO geometric badge, NO names, NO On/Off labels)
    // - Original WaveFill water-wave wipe sweep when toggling ON <-> OFF
    // - Spring-animated 2-pass diagonal strikethrough slash ONLY on Wi-Fi & Bluetooth when OFF
    component QuickActionBtn : Item {
        id: qaBtn
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 1

        property bool isActive: false
        property string iconText: ""
        property string dynamicText: ""
        property bool slashWhenOff: false
        property color activeColor: root.cAccent
        property color activeColor2: root.cAccent2
        readonly property bool isHovered: qaMa.containsMouse

        signal leftClicked()
        signal rightClicked()

        Smart.SpringVal { id: qSc;     target: qaMa.pressed ? 0.94 : (qaMa.containsMouse ? 1.02 : 1.0); stiffness: 520; damping: 0.46; eps: 0.001 }
        Smart.SpringVal { id: slashSp; target: (qaBtn.slashWhenOff && !qaBtn.isActive) ? 1.0 : 0.0; stiffness: 360; damping: 0.56; eps: 0.003 }
        scale: qSc.value

        property color idleColor: qaMa.containsMouse ? ThemeBackend.surface1 : Qt.darker(ThemeBackend.surface0, 1.04)
        Behavior on idleColor {
            enabled: root.visible
            ColorAnimation { duration: 150 }
        }
        readonly property color tileBgColor: qaBtn.isActive ? qaBtn.activeColor : qaBtn.idleColor

        property real sweep: 1
        property color sweptFrom: "transparent"
        onIsActiveChanged: {
            if (!root.visible) return;
            sweptFrom = isActive ? idleColor : activeColor;
            sweepAnim.restart();
        }
        NumberAnimation { id: sweepAnim; target: qaBtn; property: "sweep"; from: 0; to: 1; duration: 560; easing.type: Easing.InOutCubic }

        Rectangle {
            id: qaRect
            anchors.fill: parent
            radius: Math.min(ThemeBackend.borderRadius, root.s(16))
            color: qaBtn.isActive ? qaBtn.activeColor : (qaGlass.active ? "transparent" : qaBtn.idleColor)
            border.width: 1
            border.color: qaBtn.isActive
                ? Qt.rgba(qaBtn.activeColor.r, qaBtn.activeColor.g, qaBtn.activeColor.b, 0.55)
                : (root.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.07))
            clip: true

            GlassFill {
                id: qaGlass
                anchors.fill: parent
                radius: parent.radius
                tintColor: ThemeBackend.surface0
                tintAmount: ThemeBackend.glassTint
                sharp: true
                frost: ThemeBackend.glassFrost
                rim: 0.9
                z: -1
            }

            // Original water-wave wipe sweep uncovering the new state underneath
            WaveFill {
                radius: qaRect.radius
                oldColor: qaBtn.sweptFrom
                sweep: qaBtn.sweep
            }
        }

        readonly property color activeInk: {
            const c = qaBtn.activeColor;
            return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.52 ? "#0b0e14" : "#ffffff";
        }

        // Pure centered icon + 2-pass spring diagonal slash on OFF (Wi-Fi & Bluetooth only)
        Item {
            visible: qaBtn.dynamicText === ""
            anchors.centerIn: parent
            width: root.s(32); height: root.s(32)

            Text {
                anchors.centerIn: parent
                text: qaBtn.iconText
                font.family: ThemeBackend.iconFont
                font.pixelSize: root.s(19)
                color: qaBtn.isActive ? qaBtn.activeInk : (qaMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                opacity: qaBtn.isActive ? 1.0 : (qaBtn.slashWhenOff ? 0.78 : 0.88)
                Behavior on color { enabled: root.visible; ColorAnimation { duration: 150 } }
                Behavior on opacity { enabled: root.visible; NumberAnimation { duration: 150 } }
            }

            Canvas {
                anchors.fill: parent
                visible: slashSp.value > 0.01
                readonly property var _k: [slashSp.value, qaBtn.idleColor.toString(), ThemeBackend.subtext0.toString(), width, height]
                on_KChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const t = Math.max(0, Math.min(1.08, slashSp.value));
                    if (t <= 0.01 || width <= 4) return;
                    const pad = root.s(6.5);
                    const x0 = pad, y0 = pad;
                    const x1 = x0 + (width - pad * 2) * Math.min(1.0, t);
                    const y1 = y0 + (height - pad * 2) * Math.min(1.0, t);

                    // Pass 1: cutout halo matching tile background so slash slices cleanly through icon
                    ctx.beginPath();
                    ctx.moveTo(x0, y0);
                    ctx.lineTo(x1, y1);
                    ctx.lineWidth = root.s(4.8);
                    ctx.lineCap = "round";
                    ctx.strokeStyle = qaBtn.idleColor;
                    ctx.stroke();

                    // Pass 2: crisp foreground diagonal slash
                    ctx.beginPath();
                    ctx.moveTo(x0, y0);
                    ctx.lineTo(x1, y1);
                    ctx.lineWidth = root.s(2.1);
                    ctx.lineCap = "round";
                    ctx.strokeStyle = ThemeBackend.subtext0;
                    ctx.stroke();
                }
            }
        }

        // Dynamic live timer text (Caffeine hover countdown or active Recording MM:SS)
        Text {
            visible: qaBtn.dynamicText !== ""
            anchors.centerIn: parent
            text: qaBtn.dynamicText
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(12)
            font.bold: true
            color: qaBtn.isActive ? qaBtn.activeInk : ThemeBackend.text
        }

        MouseArea {
            id: qaMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (mouse) => {
                qSc.kick(1.14);
                if (mouse.button === Qt.RightButton) qaBtn.rightClicked();
                else qaBtn.leftClicked();
            }
        }
    }

    Item {
        id: sidebarPanel
        anchors.fill: parent
        readonly property real radius: ScreenEdges.modern ? ScreenEdges.rounding : Math.min(ThemeBackend.borderRadius, root.s(28))
        // room above and below the body for the concave joins into the screen frame
        readonly property real joinRoom: ScreenEdges.modern ? radius : 0
        opacity: root.introContent
        transform: Translate { x: root.slideDistance * (1.0 - root.introContent) }

        // Same surface the Edge bar uses: flat on the screen edge, rounded on the inside,
        // with concave joins where it meets the frame.
        EdgeBackground {
            id: panelBody
            anchors.fill: parent
            anchors.topMargin: sidebarPanel.joinRoom
            anchors.bottomMargin: sidebarPanel.joinRoom
            edge: "right"
            color: ScreenEdges.modern ? ThemeBackend.base : Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.97)
            cornerRadius: sidebarPanel.radius
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(8)
            anchors.topMargin: root.s(8) + sidebarPanel.joinRoom
            anchors.bottomMargin: root.s(8) + sidebarPanel.joinRoom
            spacing: root.s(5)

            // ---------- Overview / Control header (spring-sliding gradient pill) ----------
            Rectangle {
                id: pageBox
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(42)
                Layout.maximumHeight: root.s(42)
                radius: Math.min(ThemeBackend.borderRadius, root.s(17))
                color: ThemeBackend.liquidGlass ? "transparent" : ThemeBackend.mantle
                border.width: 1
                border.color: root.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
                opacity: root.introTop
                transform: Translate { x: root.rowSlideDistance * (1.0 - root.introTop) }

                readonly property real pad: root.s(4)
                readonly property real halfW: Math.max(10, (width - pad * 2) * 0.5)
                readonly property int tabIdx: root.page === "control" ? 1 : 0
                Smart.SpringVal { id: tabPillX; target: pageBox.pad + pageBox.tabIdx * pageBox.halfW; stiffness: 420; damping: 0.56; eps: 0.3 }
                onWidthChanged: if (width > 20 && !tabPillX.moving) tabPillX.snap(pad + tabIdx * halfW)

                Rectangle {
                    x: tabPillX.value
                    y: pageBox.pad
                    width: pageBox.halfW
                    height: pageBox.height - pageBox.pad * 2
                    radius: Math.max(root.s(8), pageBox.radius - pageBox.pad)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.cAccent }
                        GradientStop { position: 1.0; color: root.cAccent2 }
                    }
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: pageBox.pad
                    Repeater {
                        model: [
                            { id: "overview", ic: "󰕮", name: I18n.t("syspanel.pages.overview") },
                            { id: "control",  ic: "󰘮", name: I18n.t("syspanel.pages.control") }
                        ]
                        Item {
                            required property var modelData
                            required property int index
                            readonly property bool cur: index === pageBox.tabIdx
                            width: pageBox.halfW
                            height: parent.height
                            Row {
                                anchors.centerIn: parent
                                spacing: root.s(7)
                                Text {
                                    text: modelData.ic
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(14)
                                    color: cur ? root.cOnAccent : ThemeBackend.subtext0
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: modelData.name
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12)
                                    font.bold: cur
                                    color: cur ? root.cOnAccent : ThemeBackend.text
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.page !== modelData.id) {
                                        root.page = modelData.id;
                                        Sounds.playSfx("reusables/iconbutton/click.wav");
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: pageArea
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ================= Overview (Style A: 3 Wave Dials + 7 Icon-Only Tiles + Smart Notifications) =================
                ColumnLayout {
                    id: overviewPage
                    anchors.fill: parent
                    anchors.margins: root.s(4)
                    visible: root.page === "overview"
                    opacity: root.pageFade
                    spacing: root.s(9)

                    // ---- layer 1: brightness + volume + mic (3 Expressive Wave Dials) ----
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: root.s(138)
                        Layout.maximumHeight: root.s(138)
                        spacing: root.s(8)
                        opacity: root.introSliders
                        transform: Translate { x: root.rowSlideDistance * (1.0 - root.introSliders) }

                        WaveDial {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            active: root.levelsActive
                            icon: root.briLevel > 66 ? "󰃠" : (root.briLevel > 33 ? "󰃟" : "󰃞")
                            mutedIcon: "󰃞"
                            geoShape: "star6"
                            accent: root.cAccent
                            accent2: root.cAccent2
                            value: root.briLevel
                            onAdjusted: (v) => root.applyBrightness(v)
                            onDragStarted: briSyncDelay.stop()
                            onDragFinished: briSyncDelay.restart()
                            onStepped: Sounds.playSfx("reusables/draggable/tick.wav", 0.6)
                            onLockedFull: Sounds.playSfx("reusables/draggable/lock.wav")
                            onClicked: {
                                briCmdThrottle.stop();
                                briCmdThrottle.targetPct = -1;
                                let target = root.briLevel > 5 ? 0 : 100;
                                root.briLevel = target;
                                root.isDraggingBri = true;
                                briSyncDelay.restart();
                                Sounds.playSfx(target > 0 ? "reusables/switch/sfx.wav" : "reusables/toggle/sfx.wav");
                                Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/brightness.sh", "set", root.briToActual(target).toString()]);
                            }
                        }

                        WaveDial {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            active: root.levelsActive
                            icon: root.volLevel > 50 ? "󰕾" : "󰖀"
                            mutedIcon: "󰖁"
                            geoShape: "clover4"
                            accent: root.cAccent
                            accent2: root.cAccent2
                            muted: root.sysMuted
                            value: root.volLevel
                            onAdjusted: (v) => root.applyVolume(v)
                            onDragStarted: volSyncDelay.stop()
                            onDragFinished: volSyncDelay.restart()
                            onStepped: Sounds.playSfx("reusables/draggable/tick.wav", 0.6)
                            onLockedFull: Sounds.playSfx("reusables/draggable/lock.wav")
                            onClicked: {
                                if (Audio.defaultSink) {
                                    Sounds.playSfx(root.sysMuted ? "reusables/switch/sfx.wav" : "reusables/toggle/sfx.wav");
                                    Audio.toggleMute(Audio.defaultSink);
                                }
                            }
                        }

                        WaveDial {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            active: root.levelsActive
                            icon: "󰍬"
                            mutedIcon: "󰍭"
                            geoShape: "cookie6"
                            accent: root.cAccent
                            accent2: root.cAccent2
                            muted: root.sysMicMuted
                            value: root.micLevel
                            onAdjusted: (v) => root.applyMic(v)
                            onDragStarted: micSyncDelay.stop()
                            onDragFinished: micSyncDelay.restart()
                            onStepped: Sounds.playSfx("reusables/draggable/tick.wav", 0.6)
                            onLockedFull: Sounds.playSfx("reusables/draggable/lock.wav")
                            onClicked: {
                                if (Audio.defaultSource) {
                                    Sounds.playSfx(root.sysMicMuted ? "reusables/switch/sfx.wav" : "reusables/toggle/sfx.wav");
                                    Audio.toggleMute(Audio.defaultSource);
                                }
                            }
                        }
                    }

                    // ---- layer 2: Wi-Fi, Bluetooth (slashWhenOff: true), Airplane (slashWhenOff: false) ----
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: root.s(54)
                        Layout.maximumHeight: root.s(54)
                        spacing: root.s(8)
                        opacity: root.introQuickActions
                        transform: Translate { x: root.rowSlideDistance * (1.0 - root.introQuickActions) }

                        QuickActionBtn {
                            iconText: "󰤨"
                            slashWhenOff: true
                            activeColor: root.cAccent
                            activeColor2: root.cAccent2
                            isActive: root.wifiRadioEnabled
                            onLeftClicked: {
                                const next = !Networking.wifiEnabled;
                                Sounds.playSfx(next ? "reusables/switch/sfx.wav" : "reusables/toggle/sfx.wav");
                                Networking.wifiEnabled = next;
                            }
                            onRightClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                closeSequence.start();
                                Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "toggle", "blankpanel", "network"]);
                            }
                        }

                        QuickActionBtn {
                            iconText: "󰂯"
                            slashWhenOff: true
                            activeColor: root.cAccent
                            activeColor2: root.cAccent2
                            isActive: root.btRadioEnabled
                            onLeftClicked: {
                                if (Bluetooth.defaultAdapter) {
                                    const next = !Bluetooth.defaultAdapter.enabled;
                                    Sounds.playSfx(next ? "reusables/switch/sfx.wav" : "reusables/toggle/sfx.wav");
                                    Bluetooth.defaultAdapter.enabled = next;
                                }
                            }
                            onRightClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                closeSequence.start();
                                Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "toggle", "blankpanel", "network"]);
                            }
                        }

                        QuickActionBtn {
                            iconText: "󰀝"
                            slashWhenOff: false
                            activeColor: "#ff8c8c"
                            activeColor2: "#ffb4a2"
                            isActive: root.airplaneOn
                            onLeftClicked: {
                                let enableAirplane = !isActive;
                                Sounds.playSfx(enableAirplane ? "reusables/switch/sfx.wav" : "reusables/toggle/sfx.wav");
                                root.airplaneOn = enableAirplane;
                                if (enableAirplane) {
                                    root.btStateBeforeAirplane = root.btRadioEnabled;
                                    root.wifiStateBeforeAirplane = root.wifiRadioEnabled;
                                    Networking.wifiEnabled = false;
                                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = false;
                                } else {
                                    let restoreWifi = root.wifiStateBeforeAirplane;
                                    let restoreBt = root.btStateBeforeAirplane;
                                    if (!restoreWifi && !restoreBt) restoreWifi = true;
                                    Networking.wifiEnabled = restoreWifi;
                                    if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = restoreBt;
                                }
                            }
                        }
                    }

                    // ---- layer 3: Night Light, Caffeine, Screenshot, Record (NO slashWhenOff) ----
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        Layout.preferredHeight: root.s(52)
                        Layout.maximumHeight: root.s(52)
                        spacing: root.s(8)
                        opacity: root.introQuickActions
                        transform: Translate { x: root.rowSlideDistance * (1.0 - root.introQuickActions) }

                        QuickActionBtn {
                            id: nightLightBtn
                            iconText: "󰖔"
                            slashWhenOff: false
                            activeColor: "#f5b971"
                            activeColor2: "#f79d65"

                            function updateState() {
                                let anyEnabled = false;
                                if (typeof BlueLight !== "undefined" && typeof BlueLight.isAnyEnabled === "function") {
                                    anyEnabled = BlueLight.isAnyEnabled();
                                } else if (typeof Config !== "undefined") {
                                    let ds = Config.getSetting("display", {"monitors": {}});
                                    let mons = (ds && ds.monitors) ? ds.monitors : {};
                                    for (let mName in mons) {
                                        if (mons[mName] && mons[mName].enabled) { anyEnabled = true; break; }
                                    }
                                }
                                isActive = anyEnabled;
                            }

                            Component.onCompleted: updateState()

                            Connections {
                                target: typeof Config !== "undefined" ? Config : null
                                enabled: root.visible
                                ignoreUnknownSignals: true
                                function onSettingsLoaded() { nightLightBtn.updateState(); }
                            }
                            Connections {
                                target: typeof BlueLight !== "undefined" ? BlueLight : null
                                enabled: root.visible
                                ignoreUnknownSignals: true
                                function onSettingsChanged() { nightLightBtn.updateState(); }
                            }

                            onLeftClicked: {
                                let target = !nightLightBtn.isActive;
                                Sounds.playSfx(target ? "reusables/switch/sfx.wav" : "reusables/toggle/sfx.wav");
                                nightLightBtn.isActive = target;
                                let monNames = [];
                                let ds = typeof Config !== "undefined" ? Config.getSetting("display", {"monitors": {}}) : {"monitors": {}};
                                let mons = (ds && ds.monitors) ? ds.monitors : {};
                                for (let m in mons) if (monNames.indexOf(m) === -1) monNames.push(m);
                                if (typeof Quickshell !== "undefined" && Quickshell.screens) {
                                    for (let i = 0; i < Quickshell.screens.length; i++) {
                                        let scr = Quickshell.screens[i];
                                        if (scr && scr.name && monNames.indexOf(scr.name) === -1) monNames.push(scr.name);
                                    }
                                }
                                if (monNames.length > 0) {
                                    for (let i = 0; i < monNames.length; i++) BlueLight.setEnabled(monNames[i], target);
                                } else {
                                    BlueLight.setEnabled("", target);
                                }
                                nightLightBtn.updateState();
                            }

                            onRightClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                closeSequence.start();
                                Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "toggle", "guide", "display"]);
                            }
                        }

                        QuickActionBtn {
                            id: coffeeBtn
                            iconText: "󰅶"
                            slashWhenOff: false
                            activeColor: "#e6b87d"
                            activeColor2: root.cAccent2
                            isActive: Caffeine.enabled
                            readonly property bool showsTime: isActive && isHovered && !Caffeine.forever
                            dynamicText: showsTime ? Caffeine.remainingTimeString : ""
                            function updateState() { Caffeine.updateRemaining(); }
                            onLeftClicked: {
                                const next = !Caffeine.enabled;
                                Sounds.playSfx(next ? "reusables/switch/sfx.wav" : "reusables/toggle/sfx.wav");
                                Caffeine.toggle();
                            }
                            onRightClicked: {
                                Sounds.playSfx("network/tick-1.wav");
                                Caffeine.extend();
                            }
                        }

                        QuickActionBtn {
                            iconText: "󰹑"
                            slashWhenOff: false
                            activeColor: root.cAccent
                            activeColor2: root.cAccent2
                            onLeftClicked: {
                                Sounds.playSfx("system/quick_click.wav");
                                root.launchCapture("photo");
                            }
                        }

                        QuickActionBtn {
                            id: recordBtn
                            iconText: "󰑊"
                            slashWhenOff: false
                            isActive: root.isRecording
                            activeColor: "#ff6b6b"
                            activeColor2: "#ff9e7d"
                            dynamicText: isActive ? root.recTimeText : ""
                            onLeftClicked: {
                                Sounds.playSfx(root.isRecording ? "reusables/toggle/sfx.wav" : "reusables/switch/sfx.wav");
                                if (root.isRecording) {
                                    Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/screenshot.sh"]);
                                    recRecheck.restart();
                                } else {
                                    root.launchCapture("video");
                                }
                            }
                        }
                    }

                    Timer { id: recRecheck; interval: 1500; onTriggered: { if (root.recDir !== "") recCheck.running = true; } }

                    // ---- layer 4: Original NotificationBox (DuckNest + DND + group expand/collapse + swipe dismiss) ----
                    NotificationBox {
                        id: notifBox
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        cornerRadius: root.boxRadius
                        cardRadius: root.cardRadius
                        baseColor: ThemeBackend.mantle
                        borderColor: root.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
                        borderWidth: 1
                        rootContext: root
                        opacity: root.introNotifs
                        transform: Translate { x: root.rowSlideDistance * (1.0 - root.introNotifs) }
                    }
                }

                // ================= Control =================
                Item {
                    id: controlPage
                    anchors.fill: parent
                    visible: root.page === "control"
                    opacity: root.pageFade

                    // Settings live only while the Control tab is open
                    Loader {
                        id: controlLoader
                        anchors.fill: parent
                        asynchronous: true
                        active: root.visible && root.page === "control"
                        sourceComponent: smartControl
                        function showRequested() {
                            if (!item || root.requestedSettings === "") return;
                            item.gotoKey(root.requestedSettings);
                            root.requestedSettings = "";
                        }
                        onLoaded: showRequested()
                        Connections { target: root; function onRequestedSettingsChanged() { controlLoader.showRequested(); } }
                    }
                    // the Smart Home Control (smart/SmartControl.qml: Antigravity's approved design on the real settings)
                    Component {
                        id: smartControl
                        Smart.SmartControl {
                            active: root.visible && root.page === "control"
                            onCloseRequested: closeSequence.start()
                        }
                    }
                }
            }
        }
    }
}
