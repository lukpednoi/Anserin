import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtMultimedia
import "../"

ShellRoot {
    id: globalRoot

    Variants {
        id: root
        model: Quickshell.screens

        delegate: Component {
            PanelWindow {
                id: barWindow

                required property var modelData
                screen: modelData

                WlrLayershell.namespace: "wallpaper-bg"
                WlrLayershell.layer: WlrLayer.Background

                focusable: false
                exclusionMode: ExclusionMode.Ignore
                color: "#0a0a0f"

                anchors { top: true; bottom: true; left: true; right: true }

                readonly property string wpCacheDir: Caching.getCacheDir("wallpaper")
                readonly property string wpStatePath: wpCacheDir + "/current_" + barWindow.screen.name
                readonly property string wpCopyDir: wpCacheDir + "/copy_" + barWindow.screen.name
                readonly property string wpSnapshotPath: wpCacheDir + "/current_wallpaper.png"
                readonly property string wpMonitorSnapshotPath: wpCacheDir + "/current_wallpaper_" + barWindow.screen.name + ".png"

                property string currentWallpaperPath: ""
                property string originalFileName: ""
                property int activeLayer: 0
                property string pathA: ""
                property bool isVideoA: false
                property string pathB: ""
                property bool isVideoB: false
                property bool playbackPaused: false
                readonly property var videoSinkA: videoLoaderA.item ? videoLoaderA.item.videoSink : null
                readonly property var videoSinkB: videoLoaderB.item ? videoLoaderB.item.videoSink : null

                property int transitionDuration: 1000
                property real transitionProgress: 1.0
                property bool isPreloading: false
                property int activeTransitionType: 0
                property bool wipeIsVertical: false
                property int swipeDirection: 0
                property real transitionSeed: 0.0
                property real transitionOriginX: 0.5
                property real transitionOriginY: 0.5
                property bool isInitialLoad: true

                Component.onCompleted: {
                    Wallpaper.registerEngine(screen ? screen.name : "", barWindow);
                    restorePoller.running = true;
                }
                Component.onDestruction: Wallpaper.unregisterEngine(screen ? screen.name : "", barWindow)

                onCurrentWallpaperPathChanged: {
                    if (barWindow.screen && barWindow.screen.name) {
                        let map = Object.assign({}, Wallpaper.screenWallpaperPaths);
                        map[barWindow.screen.name] = currentWallpaperPath;
                        Wallpaper.screenWallpaperPaths = map;
                    }
                }

                onOriginalFileNameChanged: {
                    if (barWindow.screen && barWindow.screen.name) {
                        let map = Object.assign({}, Wallpaper.screenWallpapers);
                        map[barWindow.screen.name] = originalFileName;
                        Wallpaper.screenWallpapers = map;
                    }
                }

                Connections {
                    target: Wallpaper

                    function onWallpaperChanged(screenName, path, transition) {
                        if (screenName === "all" || screenName === barWindow.screen.name)
                            barWindow.changeWallpaper(path, transition);
                    }

                    function onPlaybackChanged(screenName, state) {
                        if (screenName === "all" || screenName === barWindow.screen.name) {
                            if (state === "pause") {
                                barWindow.playbackPaused = true;
                                barWindow.stopA();
                                barWindow.stopB();
                            } else if (state === "play") {
                                barWindow.playbackPaused = false;
                                if (barWindow.activeLayer === 0 && barWindow.isVideoA) barWindow.playA();
                                if (barWindow.activeLayer === 1 && barWindow.isVideoB) barWindow.playB();
                            }
                        }
                    }

                    function onWallpaperCleared(screenName) {
                        if (screenName === "all" || screenName === barWindow.screen.name) {
                            barWindow.currentWallpaperPath = "";
                            barWindow.pathA = "";
                            barWindow.pathB = "";
                            barWindow.isVideoA = false;
                            barWindow.isVideoB = false;
                            barWindow.originalFileName = "";
                            barWindow.stopA();
                            barWindow.stopB();
                            Quickshell.execDetached(["bash", "-c", "rm -f '" + barWindow.wpStatePath + "' '" + barWindow.wpStatePath + "_name'"]);
                        }
                    }
                }

                Process {
                    id: restorePoller
                    running: false
                    command: [
                        "bash", "-c",
                        "F1='" + barWindow.wpStatePath + "'; F2='" + barWindow.wpStatePath + "_name'; [ -f \"$F1\" ] && cat \"$F1\" || true; echo '---SPLIT---'; [ -f \"$F2\" ] && cat \"$F2\" || true"
                    ]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let parts = this.text.split("---SPLIT---");
                            let savedPath = parts[0] ? parts[0].trim() : "";
                            let savedName = parts[1] ? parts[1].trim() : "";
                            if (savedPath !== "") {
                                barWindow.originalFileName = savedName;
                                barWindow._loadNew(savedPath, false);
                                if (barWindow.isVideo(savedPath)) {
                                    videoSnapshotProcess.targetPath = savedPath;
                                    videoSnapshotProcess.running = false;
                                    videoSnapshotProcess.running = true;
                                }
                                if (savedName !== "") {
                                    let histFile = barWindow.wpCacheDir + "/history.txt";
                                    Quickshell.execDetached(["bash", "-c",
                                        "HIST='" + histFile + "'; if [ -f \"$HIST\" ]; then if [ \"$(head -n 1 \"$HIST\" 2>/dev/null)\" != '" + savedName + "' ]; then grep -v -F -x '" + savedName + "' \"$HIST\" > \"$HIST.tmp\" 2>/dev/null || true; printf '%s\n' '" + savedName + "' | cat - \"$HIST.tmp\" > \"$HIST\"; rm -f \"$HIST.tmp\"; fi; else printf '%s\n' '" + savedName + "' > \"$HIST\"; fi"
                                    ]);
                                }
                            } else {
                                // nothing saved for this screen yet (new install): use one of Anserin's own
                                defaultWallpaperProcess.running = true;
                            }
                        }
                    }
                }

                Process {
                    id: defaultWallpaperProcess
                    running: false
                    command: ["bash", Caching.anserinDir + "/scripts/wallpaper/default-wallpaper.sh",
                        Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "")
                            || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers"),
                        Caching.anserinDir + "/assets/wallpapers"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            let path = this.text.trim();
                            if (path !== "" && barWindow.currentWallpaperPath === "") barWindow.changeWallpaper(path, "fade");
                        }
                    }
                }

                Timer {
                    id: videoWarmUpTimer
                    interval: 250
                    repeat: false
                    onTriggered: barWindow.triggerTransition()
                }

                Process {
                    id: videoSnapshotProcess
                    running: false
                    property string targetPath: ""
                    command: [
                        "bash", "-c",
                        "ffmpeg -y -hide_banner -loglevel error -ss 00:00:01 -i \"$1\" -frames:v 1 -q:v 2 \"$2\" 2>/dev/null || ffmpeg -y -hide_banner -loglevel error -i \"$1\" -frames:v 1 -q:v 2 \"$2\" 2>/dev/null; cp -f \"$2\" \"$3\" 2>/dev/null || true",
                        "_",
                        targetPath,
                        barWindow.wpSnapshotPath,
                        barWindow.wpMonitorSnapshotPath
                    ]
                    onExited: exitCode => {
                        if (exitCode === 0 && typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                            Matugen.generate(barWindow.wpSnapshotPath);
                        }
                    }
                }

                function isVideo(p) {
                    let lp = p.toLowerCase();
                    return lp.endsWith(".mp4") || lp.endsWith(".mkv") ||
                           lp.endsWith(".mov") || lp.endsWith(".webm");
                }

                function isSupportedMedia(p) {
                    if (!p) return false;
                    let lp = p.toLowerCase();
                    return lp.endsWith(".jpg") || lp.endsWith(".jpeg") || lp.endsWith(".png") ||
                           lp.endsWith(".webp") || lp.endsWith(".gif") || lp.endsWith(".bmp") ||
                           lp.endsWith(".avif") || barWindow.isVideo(p);
                }

                function playA() {
                    if (videoLoaderA.item && typeof videoLoaderA.item.play === "function") {
                        videoLoaderA.item.play();
                    }
                }

                function stopA() {
                    if (videoLoaderA.item && typeof videoLoaderA.item.stop === "function") {
                        videoLoaderA.item.stop();
                    }
                }

                function playB() {
                    if (videoLoaderB.item && typeof videoLoaderB.item.play === "function") {
                        videoLoaderB.item.play();
                    }
                }

                function stopB() {
                    if (videoLoaderB.item && typeof videoLoaderB.item.stop === "function") {
                        videoLoaderB.item.stop();
                    }
                }

                function triggerTransition() {
                    videoWarmUpTimer.stop();
                    barWindow.isPreloading = false;
                    transitionAnim.restart();
                }

                function _loadNew(path, force) {
                    if (!path) return;
                    if (!force && path === barWindow.currentWallpaperPath) return;

                    let cleanPath = String(path).trim();
                    let vid = barWindow.isVideo(cleanPath);

                    let slash = cleanPath.lastIndexOf("/");
                    let filename = cleanPath.substring(slash + 1);
                    if (!filename.startsWith("wallpaper.")) {
                        barWindow.originalFileName = filename;
                    }

                    if (barWindow.isInitialLoad) {
                        barWindow.isInitialLoad = false;
                        barWindow.transitionProgress = 1.0;
                        barWindow.isPreloading = false;
                        if (barWindow.activeLayer === 1) {
                            barWindow.pathA = cleanPath;
                            barWindow.isVideoA = vid;
                            barWindow.activeLayer = 0;
                            if (vid) barWindow.playA();
                        } else {
                            barWindow.pathB = cleanPath;
                            barWindow.isVideoB = vid;
                            barWindow.activeLayer = 1;
                            if (vid) barWindow.playB();
                        }
                        barWindow.currentWallpaperPath = cleanPath;
                        return;
                    }

                    transitionAnim.stop();
                    videoWarmUpTimer.stop();
                    barWindow.transitionProgress = 0.0;
                    barWindow.isPreloading = true;

                    if (barWindow.activeLayer === 1) {
                        barWindow.pathA = cleanPath;
                        barWindow.isVideoA = vid;
                        barWindow.activeLayer = 0;
                        if (vid) {
                            barWindow.playA();
                            videoWarmUpTimer.restart();
                        } else {
                            barWindow.triggerTransition();
                        }
                    } else {
                        barWindow.pathB = cleanPath;
                        barWindow.isVideoB = vid;
                        barWindow.activeLayer = 1;
                        if (vid) {
                            barWindow.playB();
                            videoWarmUpTimer.restart();
                        } else {
                            barWindow.triggerTransition();
                        }
                    }

                    barWindow.currentWallpaperPath = cleanPath;
                }

                function changeWallpaper(path, ttype) {
                    if (!path) return;

                    let isInterrupted = transitionAnim.running && barWindow.transitionProgress > 0.1 && barWindow.transitionProgress < 0.85;

                    barWindow.isInitialLoad = false;

                    let fromMenu = false;
                    let customOriginX = -1;
                    let customOriginY = -1;
                    let chosenType = -1;

                    if (typeof ttype === "object" && ttype !== null) {
                        if (ttype.type !== undefined) chosenType = Number(ttype.type);
                        if (ttype.originX !== undefined) customOriginX = Number(ttype.originX);
                        if (ttype.originY !== undefined) customOriginY = Number(ttype.originY);
                        fromMenu = true;
                    } else if (typeof ttype === "string" && ttype.indexOf("circle") !== -1) {
                        chosenType = 2;
                        let parts = ttype.split(":");
                        if (parts.length >= 3) {
                            customOriginX = parseFloat(parts[1]);
                            customOriginY = parseFloat(parts[2]);
                        }
                        fromMenu = true;
                    } else if (typeof ttype === "string" && Wallpaper.transitionIds.indexOf(ttype) >= 0) {
                        chosenType = Wallpaper.transitionIds.indexOf(ttype);
                    } else if (typeof ttype === "number" && ttype >= 0) {
                        chosenType = ttype;
                    }

                    if (typeof DesktopMenuController !== "undefined" && DesktopMenuController.isMenuShuffle) {
                        let isTargetScreen = !DesktopMenuController.screen || !DesktopMenuController.screen.name || (barWindow.screen && DesktopMenuController.screen.name === barWindow.screen.name);
                        if (isTargetScreen) {
                            fromMenu = true;
                            chosenType = 2;
                            customOriginX = DesktopMenuController.menuOriginX;
                            customOriginY = DesktopMenuController.menuOriginY;
                        }
                    }

                    let resolved = Wallpaper.resolveTransition(chosenType);
                    if (isInterrupted) {
                        resolved = Wallpaper.resolveTransition(0);
                        barWindow.activeTransitionType = 0;
                    } else if (chosenType >= 0) {
                        barWindow.activeTransitionType = chosenType;
                    } else {
                        barWindow.activeTransitionType = resolved.type;
                    }

                    barWindow.transitionDuration = resolved.duration;
                    barWindow.wipeIsVertical = resolved.vertical;
                    barWindow.swipeDirection = resolved.direction;
                    barWindow.transitionSeed = Math.random() * 100.0;

                    if (fromMenu && customOriginX >= 0 && customOriginY >= 0) {
                        barWindow.transitionOriginX = customOriginX;
                        barWindow.transitionOriginY = customOriginY;
                    } else if (resolved.centered) {
                        barWindow.transitionOriginX = 0.5;
                        barWindow.transitionOriginY = 0.5;
                    } else {
                        barWindow.transitionOriginX = 0.15 + Math.random() * 0.70;
                        barWindow.transitionOriginY = 0.15 + Math.random() * 0.70;
                    }

                    if (typeof DesktopMenuController !== "undefined") {
                        DesktopMenuController.isMenuShuffle = false;
                    }

                    let cleanPath = String(path).trim();
                    let slash = cleanPath.lastIndexOf("/");
                    let origName = cleanPath.substring(slash + 1);
                    let dot = cleanPath.lastIndexOf(".");
                    let ext = (dot !== -1 && dot > slash) ? cleanPath.substring(dot) : "";
                    let dest = wpCopyDir + "/wallpaper" + ext;
                    let histFile = wpCacheDir + "/history.txt";
                    let vid = barWindow.isVideo(cleanPath);
                    let snapshotPath = barWindow.wpSnapshotPath;
                    let monSnapshotPath = barWindow.wpMonitorSnapshotPath;
                    Quickshell.execDetached(["bash", "-c",
                        "mkdir -p '" + wpCopyDir + "'" +
                        " && printf '%s' '" + cleanPath + "' > '" + wpStatePath + "'" +
                        " && printf '%s' '" + origName + "' > '" + wpStatePath + "_name'" +
                        " && cp -f '" + cleanPath + "' '" + dest + "'" +
                        (vid ? "" : " && cp -f '" + cleanPath + "' '" + snapshotPath + "' && cp -f '" + cleanPath + "' '" + monSnapshotPath + "'") +
                        " && ( HIST='" + histFile + "'; if [ -f \"$HIST\" ]; then grep -v -F -x '" + origName + "' \"$HIST\" > \"$HIST.tmp\" 2>/dev/null || true; printf '%s\n' '" + origName + "' | cat - \"$HIST.tmp\" > \"$HIST\"; rm -f \"$HIST.tmp\"; else printf '%s\n' '" + origName + "' > \"$HIST\"; fi )"
                    ]);

                    if (vid) {
                        videoSnapshotProcess.targetPath = cleanPath;
                        videoSnapshotProcess.running = false;
                        videoSnapshotProcess.running = true;
                    } else {
                        if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                            Matugen.generate(cleanPath);
                        }
                    }

                    barWindow._loadNew(cleanPath, true);
                }

                function handleDrop(drop) {
                    let raw = "";
                    if (drop.hasUrls && drop.urls.length > 0) {
                        raw = drop.urls[0].toString();
                    } else if (drop.hasText && drop.text.length > 0) {
                        let lines = drop.text.trim().split("\n");
                        raw = lines[0].trim();
                    }
                    if (!raw) return;

                    let cleanPath = decodeURIComponent(raw.replace(/^file:\/\//, "")).trim();
                    if (!barWindow.isSupportedMedia(cleanPath)) return;

                    let scrW = barWindow.width > 0 ? barWindow.width : (barWindow.screen && barWindow.screen.geometry ? barWindow.screen.geometry.width : 1920);
                    let scrH = barWindow.height > 0 ? barWindow.height : (barWindow.screen && barWindow.screen.geometry ? barWindow.screen.geometry.height : 1080);
                    let normX = scrW > 0 ? Math.max(0.0, Math.min(1.0, drop.x / scrW)) : 0.5;
                    let normY = scrH > 0 ? Math.max(0.0, Math.min(1.0, drop.y / scrH)) : 0.5;

                    barWindow.changeWallpaper(cleanPath, {
                        type: 2,
                        originX: normX,
                        originY: normY
                    });
                }

                NumberAnimation {
                    id: transitionAnim
                    target: barWindow
                    property: "transitionProgress"
                    from: 0.0
                    to: 1.0
                    duration: barWindow.transitionDuration
                    easing.type: Easing.InOutCubic

                    onFinished: {
                        if (barWindow.activeLayer === 0) {
                            barWindow.stopB();
                            barWindow.pathB = "";
                            barWindow.isVideoB = false;
                        } else {
                            barWindow.stopA();
                            barWindow.pathA = "";
                            barWindow.isVideoA = false;
                        }
                    }
                }

                Component {
                    id: videoLayerCompA
                    Item {
                        anchors.fill: parent
                        function play() { playerA.play(); }
                        function stop() { playerA.stop(); }
                        readonly property var videoSink: videoOutputA.videoSink

                        MediaPlayer {
                            id: playerA
                            objectName: "wallpaper-player-a"
                            source: barWindow.isVideoA && barWindow.pathA ? "file://" + barWindow.pathA : ""
                            videoOutput: videoOutputA
                            loops: MediaPlayer.Infinite
                            onMediaStatusChanged: {
                                if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) && barWindow.activeLayer === 0 && barWindow.isVideoA && !barWindow.playbackPaused) {
                                    playerA.play();
                                }
                            }
                        }

                        VideoOutput {
                            id: videoOutputA
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectCrop
                        }
                    }
                }

                Component {
                    id: videoLayerCompB
                    Item {
                        anchors.fill: parent
                        function play() { playerB.play(); }
                        function stop() { playerB.stop(); }
                        readonly property var videoSink: videoOutputB.videoSink

                        MediaPlayer {
                            id: playerB
                            objectName: "wallpaper-player-b"
                            source: barWindow.isVideoB && barWindow.pathB ? "file://" + barWindow.pathB : ""
                            videoOutput: videoOutputB
                            loops: MediaPlayer.Infinite
                            onMediaStatusChanged: {
                                if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) && barWindow.activeLayer === 1 && barWindow.isVideoB && !barWindow.playbackPaused) {
                                    playerB.play();
                                }
                            }
                        }

                        VideoOutput {
                            id: videoOutputB
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectCrop
                        }
                    }
                }

                Item {
                    id: scene
                    anchors.fill: parent
                    clip: true

                    ShaderEffect {
                        id: transitionShaderA
                        anchors.fill: parent
                        visible: false
                        layer.enabled: layerA.layer.enabled

                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real progress: barWindow.transitionProgress
                        property real transitionType: barWindow.activeTransitionType
                        property vector2d origin: Qt.vector2d(barWindow.transitionOriginX, barWindow.transitionOriginY)
                        property vector4d params: Qt.vector4d(barWindow.wipeIsVertical ? 1.0 : 0.0, barWindow.swipeDirection, barWindow.transitionSeed, 0.0)
                        property color tint: "transparent"

                        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/transitions/wallpaper_transition.frag.qsb"
                    }

                    Item {
                        id: layerA
                        width: parent.width
                        height: parent.height

                        readonly property bool isIncoming: barWindow.activeLayer === 0
                        readonly property real p: barWindow.transitionProgress

                        z: isIncoming ? 2 : 1
                        visible: isIncoming || p < 1.0

                        opacity: {
                            if (barWindow.isPreloading && isIncoming) return 0.0;
                            if (barWindow.activeTransitionType !== 0) return 1.0;
                            return isIncoming ? p : 1.0 - p;
                        }

                        layer.enabled: barWindow.activeTransitionType !== 0 && isIncoming && !barWindow.isPreloading && p < 1.0
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: transitionShaderA
                            maskThresholdMin: 0.0
                            maskSpreadAtMin: 0.0
                        }

                        Image {
                            id: imgA
                            anchors.fill: parent
                            source: !barWindow.isVideoA && barWindow.pathA ? "file://" + barWindow.pathA : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: !barWindow.isVideoA && barWindow.pathA !== ""
                            cache: true
                            sourceSize.width: parent.width > 0 ? Math.ceil(parent.width * (Screen.devicePixelRatio || 1)) : 0
                            sourceSize.height: parent.height > 0 ? Math.ceil(parent.height * (Screen.devicePixelRatio || 1)) : 0
                        }

                        Loader {
                            id: videoLoaderA
                            anchors.fill: parent
                            active: barWindow.isVideoA && barWindow.pathA !== ""
                            asynchronous: false
                            sourceComponent: videoLayerCompA
                            visible: barWindow.isVideoA
                            onLoaded: {
                                if (item && barWindow.activeLayer === 0 && barWindow.isVideoA && !barWindow.playbackPaused) {
                                    item.play();
                                }
                            }
                        }
                    }

                    ShaderEffect {
                        id: transitionShaderB
                        anchors.fill: parent
                        visible: false
                        layer.enabled: layerB.layer.enabled

                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real progress: barWindow.transitionProgress
                        property real transitionType: barWindow.activeTransitionType
                        property vector2d origin: Qt.vector2d(barWindow.transitionOriginX, barWindow.transitionOriginY)
                        property vector4d params: Qt.vector4d(barWindow.wipeIsVertical ? 1.0 : 0.0, barWindow.swipeDirection, barWindow.transitionSeed, 0.0)
                        property color tint: "transparent"

                        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/transitions/wallpaper_transition.frag.qsb"
                    }

                    Item {
                        id: layerB
                        width: parent.width
                        height: parent.height

                        readonly property bool isIncoming: barWindow.activeLayer === 1
                        readonly property real p: barWindow.transitionProgress

                        z: isIncoming ? 2 : 1
                        visible: isIncoming || p < 1.0

                        opacity: {
                            if (barWindow.isPreloading && isIncoming) return 0.0;
                            if (barWindow.activeTransitionType !== 0) return 1.0;
                            return isIncoming ? p : 1.0 - p;
                        }

                        layer.enabled: barWindow.activeTransitionType !== 0 && isIncoming && !barWindow.isPreloading && p < 1.0
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: transitionShaderB
                            maskThresholdMin: 0.0
                            maskSpreadAtMin: 0.0
                        }

                        Image {
                            id: imgB
                            anchors.fill: parent
                            source: !barWindow.isVideoB && barWindow.pathB ? "file://" + barWindow.pathB : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: !barWindow.isVideoB && barWindow.pathB !== ""
                            cache: true
                            sourceSize.width: parent.width > 0 ? Math.ceil(parent.width * (Screen.devicePixelRatio || 1)) : 0
                            sourceSize.height: parent.height > 0 ? Math.ceil(parent.height * (Screen.devicePixelRatio || 1)) : 0
                        }

                        Loader {
                            id: videoLoaderB
                            anchors.fill: parent
                            active: barWindow.isVideoB && barWindow.pathB !== ""
                            asynchronous: false
                            sourceComponent: videoLayerCompB
                            visible: barWindow.isVideoB
                            onLoaded: {
                                if (item && barWindow.activeLayer === 1 && barWindow.isVideoB && !barWindow.playbackPaused) {
                                    item.play();
                                }
                            }
                        }
                    }

                    // Paint: a short glow in the theme colour on the cells that were just painted in
                    ShaderEffect {
                        anchors.fill: parent
                        z: 3
                        visible: barWindow.activeTransitionType === 4 && !barWindow.isPreloading && barWindow.transitionProgress < 1.0

                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real progress: barWindow.transitionProgress
                        property real transitionType: barWindow.activeTransitionType
                        property vector2d origin: Qt.vector2d(barWindow.transitionOriginX, barWindow.transitionOriginY)
                        property vector4d params: Qt.vector4d(0.0, 0.0, barWindow.transitionSeed, 1.0)
                        property color tint: ThemeBackend.mauve

                        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/transitions/wallpaper_transition.frag.qsb"
                    }
                }

                DropArea {
                    anchors.fill: parent

                    onEntered: drag => {
                        if (drag.hasUrls || drag.hasText) {
                            if (typeof drag.acceptProposedAction === "function") {
                                drag.acceptProposedAction();
                            } else if (typeof drag.accept === "function") {
                                drag.accept();
                            }
                            drag.accepted = true;
                        }
                    }

                    onDropped: drop => {
                        barWindow.handleDrop(drop);
                        if (typeof drop.acceptProposedAction === "function") {
                            drop.acceptProposedAction();
                        } else if (typeof drop.accept === "function") {
                            drop.accept();
                        }
                        drop.accepted = true;
                    }

                    MouseArea {
                        id: desktopMouse
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton | Qt.LeftButton

                        // the box being drawn, above the windows; it takes no input and exists only while drawing
                        LazyLoader {
                            active: desktopMouse.drawing
                            PanelWindow {
                                screen: barWindow.screen
                                WlrLayershell.namespace: "anserin-infterm-box"
                                WlrLayershell.layer: WlrLayer.Overlay
                                exclusionMode: ExclusionMode.Ignore
                                focusable: false
                                color: "transparent"
                                anchors { top: true; bottom: true; left: true; right: true }
                                mask: Region {}
                                Rectangle {
                                    x: desktopMouse.drawBox.x; y: desktopMouse.drawBox.y
                                    width: desktopMouse.drawBox.width; height: desktopMouse.drawBox.height
                                    radius: ThemeBackend.clampedBorderRadius
                                    color: Qt.alpha(ThemeBackend.overlay0, 0.18)
                                    border.width: 2
                                    border.color: Qt.alpha(ThemeBackend.overlay1, 0.75)
                                }
                            }
                        }
                        property point pressPoint: Qt.point(0, 0)
                        property point lastPoint: Qt.point(0, 0)
                        property bool panning: false
                        property bool panAllowed: false
                        // inf desktop: a box drawn with the right button opens a terminal of that size (drawn on an overlay)
                        property bool drawAllowed: false
                        property bool drawing: false
                        property bool drew: false
                        property rect drawBox: Qt.rect(0, 0, 0, 0)
                        property real scrollRemainder: 0
                        onWheel: wheel => {
                            // inf desktop: no wheel action for now (view zoom is on hold)
                            if (TerminalAppearance.infiniteActive) {
                                wheel.accepted = true;
                                return;
                            }
                            if (!TerminalAppearance.scrollableEnabled) {
                                scrollRemainder = 0;
                                wheel.accepted = false;
                                return;
                            }
                            scrollRemainder += wheel.angleDelta.y || wheel.angleDelta.x;
                            if (Math.abs(scrollRemainder) >= 120) {
                                TerminalAppearance.scrollPage(scrollRemainder < 0 ? 1 : -1, barWindow.screen.name);
                                scrollRemainder = 0;
                            }
                            wheel.accepted = true;
                        }
                        onPressed: mouse => {
                            pressPoint = lastPoint = Qt.point(mouse.x, mouse.y);
                            panning = false;
                            drew = false;
                            panAllowed = mouse.button === Qt.LeftButton && TerminalAppearance.infiniteActive;
                            drawAllowed = mouse.button === Qt.RightButton && TerminalAppearance.infiniteActive;
                        }
                        onPositionChanged: mouse => {
                            if (drawAllowed && (pressedButtons & Qt.RightButton)) {
                                if (!drawing && Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) < 4) return;
                                if (!drawing) DesktopMenuController.hide();
                                drawing = true;
                                drawBox = Qt.rect(Math.min(pressPoint.x, mouse.x), Math.min(pressPoint.y, mouse.y),
                                                  Math.abs(mouse.x - pressPoint.x), Math.abs(mouse.y - pressPoint.y));
                                return;
                            }
                            if (!panAllowed || !(pressedButtons & Qt.LeftButton)) return;
                            if (panning || Math.hypot(mouse.x - pressPoint.x, mouse.y - pressPoint.y) < 4) return;
                            // from here inf desktop's Lua pans the canvas (cursor hidden, no edge stop) until release
                            panning = true;
                            DesktopMenuController.hide();
                            TerminalAppearance.panBegin(barWindow.screen.name);
                        }
                        onReleased: {
                            panAllowed = false;
                            TerminalAppearance.panEnd();
                            if (drawing) {
                                drew = true;
                                TerminalAppearance.spawnTerminal(barWindow.screen.x + drawBox.x, barWindow.screen.y + drawBox.y, drawBox.width, drawBox.height);
                            }
                            drawing = false;
                            drawAllowed = false;
                        }
                        onCanceled: { panAllowed = false; drawAllowed = false; drawing = false; TerminalAppearance.panEnd(); }
                        onClicked: mouse => {
                            if (panning || drew) return;
                            // right-click on the desktop: its menu (Open Redactor, Restart desktop, Lock screen)
                            if (mouse.button === Qt.RightButton) DesktopMenuController.toggle(barWindow.screen, mouse.x, mouse.y, "desktop");
                            else DesktopMenuController.hide();
                        }
                    }
                }
            }
        }
    }
}
