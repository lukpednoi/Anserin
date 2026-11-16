import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Saving the current setup as a preset, without a look: a name (or the next free one), and when the setup is new,
// a snapshot of the widgets and wallpaper first (config-profile-widgets.py) with the theme's palette. Used by the
// Settings page (DisplayPresetsTab.qml) and the Control Center's board.
Item {
    id: saver
    property string pendingName: ""
    property string captureError: ""
    readonly property bool busy: capture.running || !ConfigProfiles.available

    function savePreset(typedName) {
        const name = (typedName || "").trim() || ConfigProfiles.nextName;
        if (!ConfigProfiles.valid({
            "name": name,
            "settings": Config.rawSettings
        }) || ConfigProfiles.profiles.some((profile) => {
            return profile.name === name;
        })) {
            ConfigProfiles.save(name);
            return ;
        }
        pendingName = name;
        captureError = "";
        capture.running = true;
    }
    Process {
        id: capture

        command: ["python3", Caching.anserinDir + "/scripts/config-profile-widgets.py", "snapshot", Caching.stateDir, Caching.cacheDir]
        onExited: (code) => {
            if (code !== 0) {
                saver.captureError = errors.text.trim();
                return ;
            }
            try {
                const saved = JSON.parse(output.text);
                const screen = Quickshell.screens[0];
                const palette = {
                };
                for (const key of ["base", "mantle", "crust", "surface0", "surface1", "surface2", "text", "subtext0", "mauve", "blue", "green", "peach", "red"]) palette[key] = String(ThemeBackend[key])
                ConfigProfiles.save(saver.pendingName, {
                    "widgets": saved.widgets,
                    "wallpapers": {
                        "preview": saved.wallpaper
                    },
                    "palette": palette,
                    "created": Date.now(),
                    "snapshot": {
                        "screen": screen ? screen.name : "",
                        "width": screen ? screen.width : 1920,
                        "height": screen ? screen.height : 1080
                    }
                });
            } catch (failure) {
                saver.captureError = String(failure);
            }
        }

        stdout: StdioCollector {
            id: output
        }

        stderr: StdioCollector {
            id: errors
        }

    }
}
