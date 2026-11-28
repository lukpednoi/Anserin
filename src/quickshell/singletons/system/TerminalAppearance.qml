pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "../../"

Item {
    id: root
    readonly property var defaults: ({ background: "clear", blurSize: 8, prompt: "hex", border: "white", workspace: "horizontal",
        // pan / move / resize: "anserin" ways are fixed, "custom" uses the keys (defaults as in the original repo)
        infiniteDesktop: { toggleShortcut: "SUPER + CTRL", cliToys: ["shell"], panMode: "anserin", panKeys: "SUPER + ALT",
                           navigateMode: "anserin", navigateKeys: "SUPER", moveMode: "anserin", moveKeys: "SUPER + SHIFT",
                           resizeMode: "anserin", resizeKeys: "SUPER + CTRL", cellScale: 100 },
        scrollableTiling: { windowLayout: "hyprland", appsScrollable: false } })
    readonly property var settings: {
        let current = Config.getSetting("terminal", defaults);
        if (["up", "down"].indexOf(current.workspace) >= 0) current.workspace = "vertical";
        else if (["left", "right"].indexOf(current.workspace) >= 0) current.workspace = "horizontal";
        return current;
    }
    readonly property string payload: JSON.stringify({
        settings: settings,
        palette: { accent: ThemeBackend.mauve.toString(), text: ThemeBackend.text.toString(), base: ThemeBackend.base.toString() }
    })
    readonly property var infiniteSettings: Object.assign({}, defaults.infiniteDesktop, settings.infiniteDesktop || {})
    readonly property var scrollableSettings: {
        const stored = settings.scrollableTiling || {};
        const result = Object.assign({}, defaults.scrollableTiling, stored);
        // Window layout was called terminalMode before
        if (stored.windowLayout === undefined && stored.terminalMode !== undefined) result.windowLayout = stored.terminalMode;
        delete result.terminalMode;
        return result;
    }
    readonly property bool scrollableEnabled: scrollableSettings.windowLayout !== "hyprland" || scrollableSettings.appsScrollable
    property string error: ""
    property string lastPayload: ""
    property bool infiniteActive: false
    property string shortcutError: ""
    // the last refusal for each inf desktop action's keys (panKeys, navigateKeys, moveKeys, resizeKeys)
    property var keysError: ({})
    readonly property string fastfetchDir: Caching.home + "/.config/anserin/fastfetch"
    readonly property var fastfetchDefaults: ({ mode: "ascii", ascii: "berserk.txt", pic: "Mark.png", random: true, randomMode: "ascii", auto: true, hideLogo: false })
    readonly property var fastfetchSettings: Object.assign({}, fastfetchDefaults, Config.getSetting("fastfetch", fastfetchDefaults))
    property string fastfetchError: ""

    FileView {
        path: Caching.stateDir + "/infinite-desktop-v2.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let match = /\bactive=(true|false)/.exec(text());
            root.infiniteActive = match ? match[1] === "true" : false;
        }
    }

    function initialize() {
        debounce.restart();
        if (!fastfetchSync.running) fastfetchSync.running = true;
        keybindsDebounce.restart();
    }

    // Anserin's shortcuts take only keys the user's own Hyprland binds leave free (src/scripts/hypr-keybinds.py): made
    // at start and again after every Hyprland config reload (its own reload changes nothing, so it settles).
    Process {
        id: keybindsSync
        command: ["python3", Caching.anserinDir + "/scripts/hypr-keybinds.py"]
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) console.warn(text.trim()); } }
    }
    Timer { id: keybindsDebounce; interval: 400; onTriggered: { if (!keybindsSync.running) keybindsSync.running = true; else restart(); } }
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") keybindsDebounce.restart(); }
    }

    function setFastfetchOption(key, value) {
        let current = Object.assign({}, fastfetchSettings);
        current[key] = value;
        Config.setSetting("fastfetch", current);
    }

    Process {
        id: fastfetchSync
        command: ["python3", Caching.anserinDir + "/scripts/fastfetch.py", "--sync"]
        stderr: StdioCollector { id: fastfetchSyncErrors }
        onExited: function(code) {
            root.fastfetchError = code === 0 ? "" : fastfetchSyncErrors.text.trim();
        }
    }

    function setOption(key, value) {
        let current = Config.getSetting("terminal", defaults);
        current[key] = value;
        Config.setSetting("terminal", current);
    }

    function setInfiniteOption(key, value) {
        let current = Config.getSetting("terminal", defaults);
        current.infiniteDesktop = Object.assign({}, defaults.infiniteDesktop, current.infiniteDesktop || {});
        current.infiniteDesktop[key] = value;
        Config.setSetting("terminal", current);
    }

    function infiniteAction(action) {
        if (!infiniteActive || action !== "arrange") return;
        Quickshell.execDetached(["hyprctl", "eval", "MoInfiniteDesktop." + action + "()"]);
    }

    function setScrollableOption(key, value) {
        let current = Config.getSetting("terminal", defaults);
        current.scrollableTiling = Object.assign({}, scrollableSettings);
        current.scrollableTiling[key] = value;
        Config.setSetting("terminal", current);
    }

    function scrollPage(direction, screen) {
        if (!scrollableEnabled || infiniteActive || scrollProcess.running) return;
        scrollProcess.command = ["hyprctl", "eval", "if AnserinScrollable then AnserinScrollable.step(" + direction + "," + JSON.stringify(screen) + ") end"];
        scrollProcess.running = true;
    }

    Process {
        id: scrollProcess
        stderr: StdioCollector { id: scrollErrors }
        onExited: function(code) {
            if (code !== 0) root.error = scrollErrors.text.trim() || "Scrollable Tiling failed";
        }
    }

    // Dragging the empty desktop: inf desktop's Lua pans the canvas itself with the cursor hidden and held in place, so
    // the drag is not stopped by the screen's edges. The shell only says when it starts, that it goes on, and when it ends.
    property bool panGrabbed: false
    function panBegin(screen) {
        if (!infiniteActive || panGrabbed) return;
        panGrabbed = true;
        Quickshell.execDetached(["hyprctl", "eval", "MoInfiniteDesktop.pan_begin(" + JSON.stringify(screen) + ")"]);
    }
    function panEnd() {
        if (!panGrabbed) return;
        panGrabbed = false;
        Quickshell.execDetached(["hyprctl", "eval", "MoInfiniteDesktop.pan_end()"]);
    }
    Timer {
        interval: 500; repeat: true; running: root.panGrabbed
        onTriggered: Quickshell.execDetached(["hyprctl", "eval", "MoInfiniteDesktop.pan_alive()"])
    }

    // CLI toy: a box drawn with the right button on the inf desktop opens a terminal there, running one of the programs
    // picked in Settings (infiniteDesktop.cliToys), at random each time; only programs installed here are offered.
    readonly property var dragPrograms: [
        { id: "shell", name: "Shell", command: "" },
        { id: "fastfetch", name: "Fastfetch", command: "fastfetch" },
        { id: "lavat", name: "Lavat", command: "lavat" },
        { id: "cmatrix", name: "cmatrix", command: "cmatrix" },
        { id: "btop", name: "btop", command: "btop" },
        { id: "htop", name: "htop", command: "htop" },
        { id: "cava", name: "Cava", command: "cava" },
        { id: "pipes.sh", name: "pipes.sh", command: "pipes.sh" },
        { id: "cbonsai", name: "cbonsai", command: "cbonsai -l" }
    ]
    property var installedDragPrograms: ["shell"]
    readonly property var availableDragPrograms: dragPrograms.filter(p => installedDragPrograms.indexOf(p.id) >= 0)
    // lists can arrive as Qt lists (through a signal or a var property), where Array.isArray is false
    function toList(value) {
        if (value === undefined || value === null || typeof value === "string") return [];
        const out = [];
        for (let i = 0; i < (value.length || 0); i++) out.push(value[i]);
        return out;
    }
    readonly property var cliToys: toList(infiniteSettings.cliToys).filter(id => installedDragPrograms.indexOf(id) >= 0)
    function setCliToys(ids) { setInfiniteOption("cliToys", toList(ids).filter(id => typeof id === "string")); }
    function refreshDragPrograms() { if (!dragProbe.running) dragProbe.running = true; }
    Process {
        id: dragProbe
        running: true
        command: ["sh", "-c", "for p in \"$@\"; do command -v \"$p\" >/dev/null 2>&1 && echo \"$p\"; done", "_"].concat(root.dragPrograms.slice(1).map(p => p.id))
        stdout: StdioCollector {
            onStreamFinished: root.installedDragPrograms = ["shell"].concat(text.split("\n").map(s => s.trim()).filter(s => s !== ""))
        }
    }
    function spawnTerminal(x, y, w, h) {
        if (!infiniteActive) return;
        const pool = cliToys.length ? cliToys : ["shell"];
        const pick = pool[Math.floor(Math.random() * pool.length)];
        const program = dragPrograms.find(p => p.id === pick) || dragPrograms[0];
        let command = "kitty --class anserin-infterm";
        // the terminal's own shell (config/terminal/bashrc) runs the program first, then stays an ordinary shell
        if (program.command !== "") command += " env ANSERIN_CLI_TOY='" + program.command + "' bash --rcfile '" + Caching.anserinDir + "/../config/terminal/bashrc'";
        Quickshell.execDetached(["hyprctl", "eval", "MoInfiniteDesktop.spawn_terminal(" + [Math.round(x), Math.round(y), Math.round(w), Math.round(h)].join(",") + "," + JSON.stringify(command) + ")"]);
    }

    function saveToggleShortcut(value) {
        if (shortcutCheck.running) return;
        shortcutError = "";
        shortcutCheck.command = ["python3", Caching.anserinDir + "/scripts/terminal-appearance.py", "--check-shortcut", value];
        shortcutCheck.running = true;
    }

    function saveInfiniteKeys(kind, value) {
        if (keysCheck.running) return;
        const errors = Object.assign({}, keysError); delete errors[kind]; keysError = errors;
        keysCheck.kind = kind;
        keysCheck.command = ["python3", Caching.anserinDir + "/scripts/terminal-appearance.py", "--check-keys", kind, value, JSON.stringify(infiniteSettings)];
        keysCheck.running = true;
    }

    Process {
        id: keysCheck
        property string kind: ""
        stdout: StdioCollector { id: keysOutput }
        stderr: StdioCollector { id: keysErrors }
        onExited: function(code) {
            const errors = Object.assign({}, root.keysError);
            if (code === 0) { delete errors[kind]; root.setInfiniteOption(kind, keysOutput.text.trim()); }
            else errors[kind] = (keysErrors.text.trim().split("\n").pop() || "Cannot use these keys").replace(/^Terminal appearance: /, "");
            root.keysError = errors;
        }
    }

    Process {
        id: shortcutCheck
        stdout: StdioCollector { id: shortcutOutput }
        stderr: StdioCollector { id: shortcutErrors }
        onExited: function(code) {
            root.shortcutError = code === 0 ? "" : shortcutErrors.text.trim();
            if (code === 0) root.setInfiniteOption("toggleShortcut", shortcutOutput.text.trim());
        }
    }

    onPayloadChanged: debounce.restart()
    Connections {
        target: Config
        function onDataReadyChanged() { root.initialize(); }
    }

    Timer {
        id: debounce
        interval: 250
        onTriggered: {
            if (!Config.dataReady) return;
            if (writer.running) { restart(); return; }
            if (root.payload === root.lastPayload) return;
            writer.command = ["python3", Caching.anserinDir + "/scripts/terminal-appearance.py", root.payload, "--apply"];
            writer.requestPayload = root.payload;
            writer.running = true;
        }
    }

    Process {
        id: writer
        property string requestPayload: ""
        stderr: StdioCollector { id: errorOutput }
        onExited: function(exitCode) {
            root.error = exitCode === 0 ? "" : errorOutput.text.trim();
            if (exitCode === 0) root.lastPayload = requestPayload;
            if (root.payload !== requestPayload) debounce.restart();
        }
    }
}
