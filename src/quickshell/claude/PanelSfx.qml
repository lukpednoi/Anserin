import QtQuick
import Quickshell
import Quickshell.Io

// Shared path & SFX helper of src/quickshell/claude/ so both the live overlay
// and the Workspace 7 preview resolve repo shaders/sounds cleanly without parent-dir imports.
Item {
    id: helper
    visible: false

    readonly property string repoRoot: {
        const env = Quickshell.env("ANSERIN_DIR");          // <repo>/src
        if (env) return env.replace(/\/src\/?$/, "");
        const d = Quickshell.shellDir ? Quickshell.shellDir.toString() : "";
        const clean = d.startsWith("file://") ? d.substring(7) : d;
        return clean.replace(/\/src\/quickshell(\/claude)?\/?$/, "");
    }
    readonly property string shaderUrl: "file://" + repoRoot + "/src/assets/shaders/effects/claude_box_wipe.frag.qsb"
    readonly property string soundsRoot: repoRoot + "/src/assets/sounds/"
    readonly property string homeDir: Quickshell.env("HOME") || ""

    property bool muted: false
    property real volume: 1.0

    FileView {
        path: helper.homeDir ? (helper.homeDir + "/.config/anserin/settings.json") : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && data.general) {
                    helper.muted = data.general.muteSfx === true;
                    const v = data.general.sfxVolume !== undefined ? Number(data.general.sfxVolume) : 100;
                    helper.volume = Math.max(0.0, Math.min(1.0, v / 100.0));
                }
            } catch (e) {}
        }
    }

    function play(relPath, vol) {
        if (muted || volume <= 0.01 || !relPath) return;
        const v = Math.max(0.0, Math.min(1.5, (vol === undefined ? 0.6 : vol) * volume));
        if (v <= 0.01) return;
        const fullPath = soundsRoot + relPath;
        const propsJson = "{\"application.id\":\"anserin-sfx\",\"application.name\":\"anserin-sfx\",\"media.role\":\"event\"}";
        try {
            Quickshell.execDetached(["pw-play", "-P", propsJson, "--volume=" + v.toFixed(2), fullPath]);
        } catch (e) {}
    }
}
