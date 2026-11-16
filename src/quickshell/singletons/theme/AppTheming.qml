pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Theme for other apps (adapted from Serpantinum's app theming): each picked app gets a theme file rendered from
// the shell's colours and one marked include/import in its own config (src/scripts/theming/apptheme.py), with the
// original kept so turning the app off puts its config back exactly. No app is themed until it is picked
// (theme.apps). App definitions are src/assets/matugen/apps/<id>/app.json; user ones go in
// ~/.config/anserin/matugen/apps. Apps pick up new colours when they reload or reopen.
Item {
    id: root

    property var apps: []
    property string userDir: ""
    property bool loaded: false
    property string error: ""
    readonly property bool busy: applyProcess.running || paletteCheck.running || paletteFile.saving
    readonly property var enabledIds: Array.isArray(Config.getSetting("theme", {}).apps) ? Config.getSetting("theme", {}).apps : []
    readonly property var installedApps: apps.filter(a => a.installed).sort((a, b) => a.name.localeCompare(b.name))

    readonly property string scriptPath: Caching.anserinDir + "/scripts/theming/apptheme.py"
    readonly property var processEnv: ({ "QS_STATE_DIR": Caching.stateDir, "QS_SETTINGS": Config.settingsJsonPath })

    property string _pendingEnabled: ""
    property bool _applyPending: false
    property bool _forcePending: false

    function refresh() { if (!listProcess.running) listProcess.running = true; }

    function setEnabled(appId, on) { setApps(enabledIds.filter(id => id !== appId).concat(on ? [appId] : [])); }
    function setApps(ids) {
        ids = Array.prototype.slice.call(ids || []);   // a Qt list from a signal is not a JS array
        let next = ids.filter((id, i) => typeof id === "string" && ids.indexOf(id) === i).sort();
        let theme = Config.getSetting("theme", {});
        theme.apps = next;
        Config.setSetting("theme", theme);
        _pendingEnabled = next.length > 0 ? next.join(",") : "-";
        apply(false);
    }

    function apply(force) {
        if (force) _forcePending = true;
        if (busy) { _applyPending = true; return; }
        _applyPending = false;
        error = "";
        // Matugen keeps the palette (Matugen.palettePath) and re-themes the picked apps after each new one; until it
        // has written one, the shell's current colours stand in
        paletteCheck.running = true;
    }
    function _run() {
        let cmd = ["python3", scriptPath, "apply", "--mode", Matugen.colorMode];
        if (_pendingEnabled !== "") { cmd.push("--enabled=" + (_pendingEnabled === "-" ? "" : _pendingEnabled)); _pendingEnabled = ""; }
        if (_forcePending) { cmd.push("--force"); _forcePending = false; }
        applyProcess.command = cmd;
        applyProcess.running = true;
    }

    function openFolder(path) {
        FileManager.openFolder(path || userDir, true);
    }
    function customize(appId) { if (!actionProcess.running) { actionProcess.kind = "customize"; actionProcess.command = ["python3", scriptPath, "customize", appId]; actionProcess.running = true; } }
    function reset(appId) { if (!actionProcess.running) { actionProcess.kind = "reset"; actionProcess.command = ["python3", scriptPath, "reset", appId]; actionProcess.running = true; } }

    Process {
        id: paletteCheck
        command: ["test", "-s", Matugen.palettePath]
        onExited: code => {
            if (code === 0) { root._run(); return; }
            paletteFile.saving = true;
            paletteFile.setText(JSON.stringify(Matugen.toMd3(ThemeBackend)) + "\n");
        }
    }
    FileView {
        id: paletteFile
        property bool saving: false
        path: Matugen.palettePath
        preload: false
        printErrors: false
        onSaved: { saving = false; root._run(); }
        onSaveFailed: { saving = false; root.error = "Could not write the colour palette."; }
    }

    Process {
        id: applyProcess
        environment: root.processEnv
        stdout: StdioCollector {
            id: applyOut
            onStreamFinished: {
                let result = null;
                try { result = JSON.parse(applyOut.text); } catch (e) {}
                if (result && result.ok === false) root.error = "Could not theme apps (" + (result.error || "unknown error") + ").";
            }
        }
        onExited: {
            if (root._applyPending || root._forcePending) root.apply(false);
            else root.refresh();
        }
    }

    Process {
        id: listProcess
        command: ["python3", root.scriptPath, "list"]
        environment: root.processEnv
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: {
                try {
                    let data = JSON.parse(listOut.text);
                    if (data && Array.isArray(data.apps)) {
                        root.apps = data.apps;
                        root.userDir = data.userDir || "";
                        root.loaded = true;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: actionProcess
        property string kind: ""
        environment: root.processEnv
        stdout: StdioCollector {
            id: actionOut
            onStreamFinished: {
                let data = null;
                try { data = JSON.parse(actionOut.text); } catch (e) {}
                if (data && data.ok) {
                    if (actionProcess.kind === "customize") root.openFolder(data.dir);
                    root.apply(true);
                }
            }
        }
    }

    Connections {
        target: Config
        function onDataReadyChanged() { if (Config.dataReady) root.refresh(); }
    }
    Component.onCompleted: if (Config.dataReady) refresh()
}
