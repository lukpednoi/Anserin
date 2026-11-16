pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: store
    readonly property string path: Config.settingsJsonPath.slice(0, Config.settingsJsonPath.lastIndexOf("/")) + "/profiles.json"
    property var profiles: []
    property var pendingProfiles: null
    property var previousSettings: null
    property var previousWidgets: null
    property var pendingProfile: null
    property string widgetOperation: ""
    property bool ready: false
    property bool saving: false
    property bool loading: false
    property bool deleting: false
    property string error: ""
    property string message: ""
    property string pendingName: ""
    readonly property bool available: ready && Config.dataReady && !saving && !loading && !deleting && !Config.isWriting
    readonly property string nextName: {
        let number = 1;
        while (profiles.some(profile => profile.name === "config-" + number)) number++;
        return "config-" + number;
    }

    // Presets belong to the interface they were saved in; older ones without a style are Default's.
    readonly property var styleProfiles: profiles.map((profile, index) => ({ profile: profile, index: index })).filter(entry =>
        ((entry.profile.settings.display || {}).settingsStyle === "anserin" ? "anserin" : "default") === AnserinMode.style)

    function validValue(value) {
        if (value === null || typeof value === "string" || typeof value === "boolean") return true;
        if (typeof value === "number") return Number.isFinite(value);
        if (Array.isArray(value)) return value.every(validValue);
        if (!value || typeof value !== "object") return false;
        return Object.keys(value).every(key => ["__proto__", "prototype", "constructor", "hasOwnProperty"].indexOf(key) < 0 && validValue(value[key]));
    }

    function valid(profile) {
        if (!profile || typeof profile.name !== "string" || !profile.name.trim() || profile.name.length > 80 || /[\x00-\x1f\x7f]/.test(profile.name)) return false;
        if (!validValue(profile)) return false;
        if (profile.widgets !== undefined) {
            if (!profile.widgets || Array.isArray(profile.widgets) || typeof profile.widgets !== "object") return false;
            for (const monitor of Object.keys(profile.widgets)) {
                if (!/^[A-Za-z0-9_-]+$/.test(monitor) || /^(lockscreen|dashboard)-/.test(monitor)) return false;
                if (!Array.isArray(profile.widgets[monitor]) || !profile.widgets[monitor].every(row => row && typeof row === "object" && !Array.isArray(row))) return false;
            }
        }
        let settings = profile.settings;
        if (!(settings && !Array.isArray(settings) && typeof settings === "object"
            && settings.general && typeof settings.general === "object" && !Array.isArray(settings.general)
            && settings.bar && typeof settings.bar === "object" && !Array.isArray(settings.bar)
            && validValue(settings))) return false;
        let bar = settings.bar;
        if (bar.position !== undefined && ["top", "bottom", "left", "right"].indexOf(bar.position) < 0) return false;
        if (bar.alignment !== undefined && ["start", "center", "end"].indexOf(bar.alignment) < 0) return false;
        if (bar.width !== undefined && (typeof bar.width !== "number" || bar.width < 5 || bar.width > 100)) return false;
        if (bar.opacity !== undefined && (typeof bar.opacity !== "number" || bar.opacity < 0 || bar.opacity > 100)) return false;
        if (bar.modules !== undefined) {
            if (!bar.modules || typeof bar.modules !== "object" || Array.isArray(bar.modules)) return false;
            for (let edge of ["left", "center", "right", "active"]) {
                let items = bar.modules[edge];
                if (items !== undefined && (!Array.isArray(items) || !items.every(item => typeof item === "string" || (Array.isArray(item) && item.every(id => typeof id === "string"))))) return false;
            }
        }
        return true;
    }

    function save(name, details) {
        if (!available) return;
        name = name.trim() || nextName;
        let profile = {name: name, settings: JSON.parse(JSON.stringify(Config.rawSettings))};
        if (details) for (const key of ["widgets", "wallpapers", "snapshot", "palette", "created"]) {
            if (details[key] !== undefined) profile[key] = JSON.parse(JSON.stringify(details[key]));
        }
        error = "";
        message = "";
        if (!valid(profile)) { error = "Use a config name of 1–80 characters and valid settings."; return; }
        if (profiles.some(entry => entry.name === name)) { error = "This config name already exists."; return; }
        pendingProfiles = profiles.concat([profile]);
        pendingName = name;
        saving = true;
        file.setText(JSON.stringify(pendingProfiles, null, 2) + "\n");
    }

    // Settings that only make sense on this machine: left out of an exported preset, and kept from the current
    // settings when a preset without them is applied.
    readonly property var machineKeys: [["general", "location"], ["general", "avatarPath"], ["notifications", "soundFile"], ["wallpaperDir"], ["wallpaper_dir"], ["screenshotDir"]]
    function shareable(profile) {
        let copy = JSON.parse(JSON.stringify(profile));
        delete copy.wallpapers;
        for (const path of machineKeys) {
            let holder = path.length > 1 ? copy.settings[path[0]] : copy.settings;
            if (holder && typeof holder === "object") delete holder[path[path.length - 1]];
        }
        return copy;
    }
    function withMachineSettings(settings) {
        let current = Config.rawSettings || {};
        for (const path of machineKeys) {
            let key = path[path.length - 1];
            let src = path.length > 1 ? current[path[0]] : current;
            if (!src || src[key] === undefined) continue;
            let dst = settings;
            if (path.length > 1) {
                if (!dst[path[0]] || typeof dst[path[0]] !== "object") dst[path[0]] = {};
                dst = dst[path[0]];
            }
            if (dst[key] === undefined) dst[key] = JSON.parse(JSON.stringify(src[key]));
        }
        return settings;
    }

    // Export: a shareable copy in Downloads (<name>.json, numbered when taken). Import: a preset file is checked
    // like a saved one and added under a free name; its wallpaper preview stays behind.
    function exportProfile(index) {
        if (!ready || index < 0 || index >= profiles.length || exporter.running) return;
        error = "";
        message = "";
        let profile = profiles[index];
        let base = String(profile.name).replace(/[^A-Za-z0-9_\- ]/g, "").trim().replace(/ +/g, "_") || "preset";
        // the preset can be larger than one command argument may be, so it goes through a file first
        exportBase = base;
        exportStage.setText(JSON.stringify(shareable(profile), null, 2) + "\n");
    }
    function importFile(path) {
        if (!available || !path || importer.running) return;
        error = "";
        message = "";
        importer.command = ["bash", "-c", "[ \"$(stat -c %s \"$1\")\" -le 4194304 ] && cat \"$1\"", "_", String(path).replace(/^file:\/\//, "")];
        importer.running = true;
    }
    function addImported(text) {
        let profile;
        try { profile = JSON.parse(text); } catch (failure) { error = "This file is not a preset."; return; }
        if (profile && profile.settings) delete profile.wallpapers;
        if (!valid(profile)) { error = "This file is not a valid preset."; return; }
        let name = profile.name, n = 2;
        while (profiles.some(entry => entry.name === name)) name = profile.name.slice(0, 74) + " (" + (n++) + ")";
        profile.name = name;
        pendingProfiles = profiles.concat([profile]);
        pendingName = name;
        saving = true;
        file.setText(JSON.stringify(pendingProfiles, null, 2) + "\n");
    }
    property string exportBase: ""
    function moveExport() {
        exporter.command = ["bash", "-c", "d=\"${XDG_DOWNLOAD_DIR:-$HOME/Downloads}\"; mkdir -p \"$d\" || exit 1; f=\"$d/$2.json\"; n=2; while [ -e \"$f\" ]; do f=\"$d/$2-$n.json\"; n=$((n+1)); done; mv -f \"$1\" \"$f\" && printf '%s' \"$f\"", "_", exportStage.path, store.exportBase];
        exporter.running = true;
    }
    FileView {
        id: exportStage
        path: Caching.runDir + "/preset-export.json"
        preload: false
        printErrors: false
        onSaved: store.moveExport()
        onSaveFailed: store.error = "Could not export the preset."
    }
    Process {
        id: exporter
        stdout: StdioCollector { id: exportPath }
        onExited: code => {
            if (code === 0) store.message = "Exported to " + exportPath.text.replace(Quickshell.env("HOME"), "~");
            else store.error = "Could not export the preset.";
        }
    }
    Process {
        id: importer
        stdout: StdioCollector { id: importText }
        onExited: code => {
            if (code === 0) store.addImported(importText.text);
            else store.error = "Could not read that file (presets are at most 4 MB).";
        }
    }

    // A preset restores its own interface; what the other interface has parked stays as it is now.
    function settingsOf(profile) {
        let next = withMachineSettings(JSON.parse(JSON.stringify(profile.settings)));
        let parked = (Config.rawSettings.display || {}).styleSettings;
        if (parked !== undefined) {
            next.display = next.display || {};
            next.display.styleSettings = JSON.parse(JSON.stringify(parked));
        }
        return next;
    }

    function load(index) {
        if (!available || index < 0 || index >= profiles.length) return;
        let profile = profiles[index];
        error = "";
        message = "";
        if (!valid(profile)) { error = "This config is invalid. Current settings were kept."; return; }
        previousSettings = JSON.parse(JSON.stringify(Config.rawSettings));
        pendingName = profile.name;
        loading = true;
        pendingProfile = profile;
        if (profile.widgets !== undefined) {
            widgetOperation = "apply";
            layoutWriter.command = ["python3", Caching.anserinDir + "/scripts/config-profile-widgets.py", "apply", Caching.stateDir, JSON.stringify(profile.widgets)];
            layoutWriter.running = true;
            return;
        }
        Config.rawSettings = settingsOf(profile);
        Config.dispatchWrite(Config.rawSettings);
    }

    function refreshWidgets(layouts) {
        for (const monitor of Object.keys(layouts || {}))
            Quickshell.execDetached(["quickshell", "-p", Caching.mainQml, "ipc", "call", "widgets-" + monitor, "reload"]);
    }

    Process {
        id: layoutWriter
        stdout: StdioCollector { id: layoutOutput }
        stderr: StdioCollector { id: layoutErrors }
        onExited: code => {
            if (store.widgetOperation === "rollback") {
                store.refreshWidgets(store.previousWidgets);
                store.previousWidgets = null;
                store.loading = false;
                if (code !== 0) store.error += " Widget rollback failed: " + layoutErrors.text.trim();
                return;
            }
            if (code !== 0) {
                store.loading = false;
                store.previousSettings = null;
                store.error = "Could not apply widget layouts. " + layoutErrors.text.trim();
                return;
            }
            try {
                store.previousWidgets = JSON.parse(layoutOutput.text).previous;
                Config.rawSettings = store.settingsOf(store.pendingProfile);
                Config.dispatchWrite(Config.rawSettings);
            } catch (failure) {
                store.loading = false;
                store.error = String(failure);
            }
        }
    }

    function remove(index) {
        if (!available || !Number.isInteger(index) || index < 0 || index >= profiles.length) return;
        error = "";
        message = "";
        pendingProfiles = profiles.filter((profile, position) => position !== index);
        pendingName = profiles[index].name;
        deleting = true;
        archive.path = path.slice(0, path.lastIndexOf("/")) + "/_to_delete/profiles.json." + Date.now();
        archiveDirectory.running = true;
    }

    function deleteFailed(reason) {
        pendingProfiles = null;
        deleting = false;
        error = "Could not delete config. Saved configs were kept. " + reason;
    }

    Process {
        id: archiveDirectory
        command: ["mkdir", "-p", store.path.slice(0, store.path.lastIndexOf("/")) + "/_to_delete"]
        onExited: code => {
            if (code !== 0) store.deleteFailed("Could not create the archive folder.");
            else archive.setText(JSON.stringify(store.profiles, null, 2) + "\n");
        }
    }

    FileView {
        id: archive
        atomicWrites: true
        printErrors: false
        onSaved: file.setText(JSON.stringify(store.pendingProfiles, null, 2) + "\n")
        onSaveFailed: error => store.deleteFailed(FileViewError.toString(error))
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            if (!store.loading) return;
            store.loading = false;
            store.refreshWidgets(store.pendingProfile ? store.pendingProfile.widgets : null);
            store.previousWidgets = null;
            store.previousSettings = null;
            store.message = "Loaded " + store.pendingName;
        }
        function onSettingsWriteFailed(message) {
            if (!store.loading) return;
            Config.rawSettings = store.previousSettings;
            store.previousSettings = null;
            store.error = "Could not load config. Previous settings were kept. " + message;
            if (store.previousWidgets !== null) {
                store.widgetOperation = "rollback";
                layoutWriter.command = ["python3", Caching.anserinDir + "/scripts/config-profile-widgets.py", "apply", Caching.stateDir, JSON.stringify(store.previousWidgets)];
                layoutWriter.running = true;
            } else store.loading = false;
        }
    }

    FileView {
        id: file
        path: store.path
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try {
                let data = JSON.parse(text());
                let names = new Set();
                if (!Array.isArray(data)) throw new Error("Expected a list of configs");
                for (let profile of data) {
                    if (!store.valid(profile) || names.has(profile.name)) throw new Error("Invalid config");
                    names.add(profile.name);
                }
                store.profiles = data;
                store.ready = true;
            } catch (error) {
                store.error = "Could not read saved configs. The original file was kept.";
            }
        }
        onLoadFailed: error => {
            store.ready = error === FileViewError.FileNotFound;
            if (!store.ready) store.error = "Could not read saved configs: " + FileViewError.toString(error);
        }
        onSaved: {
            store.profiles = store.pendingProfiles;
            store.pendingProfiles = null;
            store.saving = false;
            store.message = (store.deleting ? "Deleted " : "Saved ") + store.pendingName;
            store.deleting = false;
        }
        onSaveFailed: error => {
            store.pendingProfiles = null;
            store.saving = false;
            if (store.deleting) store.deleteFailed(FileViewError.toString(error));
            else store.error = "Could not save config: " + FileViewError.toString(error);
        }
    }
}
