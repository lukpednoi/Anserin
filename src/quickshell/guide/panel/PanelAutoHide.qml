import QtQuick
import "../../"
import "../../controlcenter/settings"

// The top of the Control Center's Panel page: auto-hide of both edge panels, Workspace only, then the hide delay.
// (Edit panel opens from the pencil in the left panel's topbar.)
Column {
    spacing: 8
    CtlSetting { width: parent.width; icon: "󰘓"; title: "Auto-hide"; key: "controlcenter.autohide"; def: true }
    CtlSetting { width: parent.width; icon: "󰕰"; title: "Workspace only"; key: "panel.workspaceOnly"; def: true }
    CtlSetting { width: parent.width; icon: "󰔛"; title: "Hide delay"; kind: "slider"; key: "controlcenter.autohideDelay"; def: 1200; from: 300; to: 5000; step: 100; suffix: " ms" }
}
