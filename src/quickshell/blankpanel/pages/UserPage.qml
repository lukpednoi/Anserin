import QtQuick
import Quickshell.Io
import "../../"
import "."

// The left edge panel's User page in the chosen style (panel.styles.user: "hero" or "slide").
Item {
    id: page
    property bool active: false
    property string screenName: ""
    readonly property string style: Config.getSetting("panel.styles.user", "hero")

    PowerActions { id: powerActions }

    property string uptimeText: ""
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: {
            const sec = Math.round(parseFloat(text().split(" ")[0]) || 0);
            const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
            page.uptimeText = d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m");
        }
    }
    onActiveChanged: if (active) uptimeFile.reload()

    Loader {
        anchors.fill: parent
        sourceComponent: page.style === "slide" ? slide : hero
    }
    Component { id: hero; UserHero { power: powerActions; uptimeText: page.uptimeText; screenName: page.screenName; visible: page.active } }
    Component { id: slide; UserSlide { power: powerActions; uptimeText: page.uptimeText; screenName: page.screenName; visible: page.active } }
}
