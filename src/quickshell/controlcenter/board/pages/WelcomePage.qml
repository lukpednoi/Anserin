import QtQuick
import Quickshell
import "../../../"
import "../../../guide"
import ".."

// Welcome as a board (guide/AboutTab.qml): the real animated welcome (logo filling with water, name, version),
// laid out sideways (logo on the left; the name, a version chip and the author beside it),
// with the GitHub account as a chip in the card's bottom-right corner (styled like the version chip), then the
// hardware and the system.
BoardPage {
    id: page
    Component.onCompleted: SystemInfo.fetch()
    function fact(v, fallback) { return v !== undefined && v !== null && v !== "" && v !== 0 ? String(v) : (fallback ?? I18n.t("guide.about.unknown")); }

    BoardCard {
        accent: page.accent
        Item {
            implicitHeight: 150
            WelcomeTab { anchors.fill: parent; rootObj: page.rootObj; tabIndex: page.tabIndex; sideways: true; accent: page.accent }
            Rectangle {
                anchors.bottom: parent.bottom; anchors.right: parent.right
                implicitWidth: ghRow.implicitWidth + page.rootObj.s(20); implicitHeight: page.rootObj.s(24); radius: height / 2
                color: Qt.alpha(page.accent, ghMa.pressed ? 0.34 : (ghMa.containsMouse ? 0.26 : 0.18))
                Behavior on color { ColorAnimation { duration: 160 } }
                Row {
                    id: ghRow; anchors.centerIn: parent; spacing: page.rootObj.s(6)
                    Text { text: "󰊤"; font.family: ThemeBackend.iconFont; font.pixelSize: page.rootObj.s(13); color: page.accent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "lukpednoi"; font.family: ThemeBackend.fontFamily; font.pixelSize: page.rootObj.s(11); font.bold: true; color: page.accent; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: ghMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); Quickshell.execDetached(["xdg-open", "https://github.com/lukpednoi"]); }
                }
            }
        }
    }
    BoardCard {
        title: "Hardware"; icon: "󰍛"; accent: page.accent
        BoardCell { kind: "info"; icon: "󰌢"; title: I18n.t("guide.about.hardware.device_name"); info: page.fact(SystemInfo.hostname) }
        BoardCell { kind: "info"; icon: "󰻠"; title: I18n.t("guide.about.hardware.processor")
                    info: SystemInfo.cpuModel !== "" ? SystemInfo.cpuModel + (SystemInfo.cpuCores > 0 ? " (" + SystemInfo.cpuCores + ")" : "") : page.fact("") }
        BoardCell { kind: "info"; icon: "󰢮"; title: I18n.t("guide.about.hardware.graphics"); info: page.fact(SystemInfo.gpuModel) }
        BoardCell { kind: "info"; icon: "󰍛"; title: I18n.t("guide.about.hardware.memory"); info: SystemInfo.totalRamGb > 0 ? SystemInfo.totalRamGb + " GB" : page.fact("") }
        BoardCell { kind: "info"; icon: "󰋊"; title: I18n.t("guide.about.hardware.disk_capacity")
                    info: SystemInfo.diskTotalGb > 0 ? SystemInfo.diskUsedGb + " / " + SystemInfo.diskTotalGb + " GB" : page.fact("") }
    }
    BoardCard {
        title: "System"; icon: "󰌽"; accent: page.accent
        BoardCell { kind: "info"; icon: "⛁"; title: I18n.t("guide.about.system.os_name"); info: page.fact(SystemInfo.osName, I18n.t("guide.about.system.default_os")) }
        BoardCell { kind: "info"; icon: "󰌽"; title: I18n.t("guide.about.system.kernel_version"); info: page.fact(SystemInfo.kernelVersion) }
        BoardCell { kind: "info"; icon: "󰧨"; title: I18n.t("guide.about.system.desktop"); info: page.fact(SystemInfo.desktopEnv) }
        BoardCell { kind: "info"; icon: "󰆍"; title: I18n.t("guide.about.system.shell"); info: page.fact(SystemInfo.shell) }
        BoardCell { kind: "info"; icon: "󰔛"; title: I18n.t("guide.about.system.uptime"); info: page.fact(SystemInfo.uptime) }
    }
}
