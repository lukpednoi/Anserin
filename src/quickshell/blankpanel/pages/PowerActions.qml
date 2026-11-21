import QtQuick
import Quickshell
import "../../"

// The User pages' power actions, using the shell's own scripts and its lock. The panel closes first.
QtObject {
    readonly property var list: [
        { id: "lock", icon: "󰌾", name: "Lock", danger: false },
        { id: "logout", icon: "󰍃", name: "Log out", danger: true },
        { id: "suspend", icon: "󰤄", name: "Suspend", danger: false },
        { id: "reboot", icon: "󰜉", name: "Reboot", danger: true },
        { id: "poweroff", icon: "󰐥", name: "Shut down", danger: true }
    ]

    function run(id) {
        const dir = Caching.anserinDir + "/scripts/system/";
        const commands = {
            lock: ["quickshell", "-p", Caching.mainQml, "ipc", "call", "lock", "activate"],
            logout: ["bash", dir + "exit.sh"],
            suspend: ["bash", dir + "suspend.sh"],
            reboot: ["bash", dir + "reboot.sh"],
            poweroff: ["bash", dir + "poweroff.sh"]
        };
        if (!commands[id]) return;
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) masterWindow.switchWidget("hidden", "");
        Quickshell.execDetached(commands[id]);
    }
}
