import QtQuick
import Quickshell
import "../../"

// The User pages' power actions, using the shell's own scripts. The panel closes first. (Lock is the corner
// revolver's, in the Anserin interface.)
QtObject {
    readonly property var list: [
        { id: "logout", icon: "󰍃", name: "Log out", danger: true },
        { id: "suspend", icon: "󰤄", name: "Suspend", danger: false },
        { id: "reboot", icon: "󰜉", name: "Reboot", danger: true },
        { id: "poweroff", icon: "󰐥", name: "Shut down", danger: true }
    ]

    function run(id) {
        const dir = Caching.anserinDir + "/scripts/system/";
        const commands = {
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
