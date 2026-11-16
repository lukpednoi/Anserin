pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"

Item {
    id: root
    readonly property bool busy: writer.running || probe.running
    property string appliedStyle: ""
    property string error: ""
    readonly property string helper: Caching.anserinDir + "/scripts/theming/sddm-theme.py"

    function select(style) {
        if (busy || ["old", "new"].indexOf(style) < 0) return;
        error = "";
        writer.style = style;
        writer.running = true;
    }

    Process {
        id: probe
        running: true
        command: ["python3", root.helper, "--status"]
        stdout: StdioCollector { id: statusOutput }
        stderr: StdioCollector { id: statusError }
        onExited: code => {
            if (code === 0) {
                try { root.appliedStyle = JSON.parse(statusOutput.text).style; }
                catch (error) { root.error = "Could not read the active SDDM theme"; }
            } else root.error = statusError.text.trim();
        }
    }

    Process {
        id: writer
        property string style: ""
        command: ["pkexec", "/usr/bin/python3", "-I", root.helper, "--apply", style]
        stdout: StdioCollector { id: output }
        stderr: StdioCollector { id: errors }
        onExited: code => {
            if (code !== 0) {
                root.error = code === 126 ? "Administrator authentication cancelled · theme unchanged" : errors.text.trim() || "Could not apply the SDDM theme";
                return;
            }
            try {
                root.appliedStyle = JSON.parse(output.text).style;
                Config.setSetting("theme.sddmStyle", root.appliedStyle);
                root.error = "";
            } catch (error) { root.error = "Could not verify the applied SDDM theme"; }
        }
    }
}
