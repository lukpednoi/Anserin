pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "WallpaperTransitions.js" as Transitions

Item {
    id: root

    signal wallpaperChanged(string screenName, string path, string transition)
    signal playbackChanged(string screenName, string state)
    signal wallpaperCleared(string screenName)

    // Lock screen → Select (Control's board page and the Settings window) opens Select Wallpaper for the lock screen:
    // while this is on, a pick there becomes the lock screen's background (lockscreen.backgroundMode "custom") and the
    // desktop and the theme stay as they are. Select turns it off when it closes.
    property bool pickForLock: false
    function openForLock() {
        pickForLock = true;
        Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "toggle", "wallpaper"]);
    }
    // From Control → Theme → Lock screen the Control Center stays open: Select comes up beside it in the main window
    // (Main.qml's lock picker) and a pick is sent back (lockPicked: the file, the card's place in the window, a picture
    // of it) for the page's swap, instead of Select setting it and closing everything.
    property bool lockPickInline: false
    signal lockPicked(string path, rect card, string picture)
    function openForLockHere() { pickForLock = true; lockPickInline = true; }
    function closeLockPicker() { lockPickInline = false; pickForLock = false; }
    function setLockBackground(path) {
        if (!path || !path.startsWith("/")) return;
        Config.updateJsonBulk({ "lockscreen.backgroundMode": "custom", "lockscreen.customBackground": path });
    }

    property var screenWallpapers: ({})
    property var screenWallpaperPaths: ({})
    property var engines: ({})
    property bool videoBridgeReady: false
    property string videoBridgeError: ""

    function shuffle(screen) {
        if (shuffleProcess.running) return;
        const name = screen ? screen.name : "all";
        const directory = Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || Quickshell.env("HOME") + "/Pictures/Wallpapers";
        shuffleProcess.screenName = name;
        shuffleProcess.command = ["python3", Caching.anserinDir + "/scripts/wallpaper/shuffle.py", directory, getWallpaperPath(name)];
        shuffleProcess.running = true;
    }
    Process {
        id: shuffleProcess
        property string screenName: "all"
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path) root.setWallpaper(shuffleProcess.screenName, path, "");
            }
        }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) console.warn("Wallpaper shuffle: " + text.trim()); } }
    }

    function ensureVideoBridge() {
        if (!videoBridgeReady && !videoBridgeBuild.running) videoBridgeBuild.running = true;
    }
    Process {
        id: videoBridgeBuild
        command: ["python3", Caching.anserinDir + "/scripts/build-glass-video.py"]
        stderr: StdioCollector { id: videoBridgeErrors }
        onExited: code => {
            root.videoBridgeReady = code === 0;
            root.videoBridgeError = code === 0 ? "" : videoBridgeErrors.text.trim();
            if (code !== 0) console.warn("Glass video: " + root.videoBridgeError);
        }
    }

    function registerEngine(screenName, engine) {
        if (!screenName) return;
        let next = Object.assign({}, engines);
        next[screenName] = engine;
        engines = next;
    }
    function unregisterEngine(screenName, engine) {
        if (engines[screenName] !== engine) return;
        let next = Object.assign({}, engines);
        delete next[screenName];
        engines = next;
    }


    readonly property var transitionIds: Transitions.ids
    readonly property var swipeDirections: Transitions.directions

    function transitionSettings() {
        return Transitions.settings(Config.getSetting("wallpaperTransition", {}));
    }

    function resolveTransition(type) {
        return Transitions.resolve(Config.getSetting("wallpaperTransition", {}), type);
    }

    function setWallpaper(screenName: string, path: string, transition: string): void {
        root.wallpaperChanged(screenName, path, transition || "");
    }

    function getWallpaper(screenName: string): string {
        if (!screenName || screenName === "") {
            let keys = Object.keys(root.screenWallpapers);
            return keys.length > 0 ? root.screenWallpapers[keys[0]] : "";
        }
        return root.screenWallpapers[screenName] || "";
    }

    function getWallpaperPath(screenName: string): string {
        if (!screenName || screenName === "") {
            let keys = Object.keys(root.screenWallpaperPaths);
            return keys.length > 0 ? root.screenWallpaperPaths[keys[0]] : "";
        }
        return root.screenWallpaperPaths[screenName] || "";
    }

    function setPlayback(screenName: string, state: string): void {
        root.playbackChanged(screenName, state);
    }

    function clearWallpaper(screenName: string): void {
        root.wallpaperCleared(screenName);
    }

    IpcHandler {
        target: "wallpaper"

        function setWallpaper(screenName: string, path: string, transition: string): void {
            root.setWallpaper(screenName, path, transition);
        }

        function getWallpaper(screenName: string): string {
            return root.getWallpaper(screenName);
        }

        function getWallpaperPath(screenName: string): string {
            return root.getWallpaperPath(screenName);
        }

        function setPlayback(screenName: string, state: string): void {
            root.setPlayback(screenName, state);
        }

        function clearWallpaper(screenName: string): void {
            root.clearWallpaper(screenName);
        }
    }
}
