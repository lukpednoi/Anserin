import QtQuick
import "../../"
import "."

// The left edge panel's System page in the chosen style (panel.styles.system: "graphs", "rings", "bubble", "bento", "smart").
// Data flows only while the page is shown; Bubble reads its own feed, and detailed telemetry runs ONLY for "bento"/"smart".
Item {
    id: page
    property bool active: false
    readonly property string style: Config.getSetting("panel.styles.system", "graphs")

    SystemFeed {
        id: sysFeed
        active: page.active && page.style !== "bubble"
        detailed: page.style === "bento" || page.style === "smart"
    }
    // the Quick Actions System monitor's sound, each time the page is shown
    onActiveChanged: if (active) Sounds.playSfx("quickactions/usage.wav", 0.25)

    Loader {
        anchors.fill: parent
        sourceComponent: page.style === "rings" ? rings
                       : page.style === "bubble" ? bubble
                       : page.style === "bento" ? bento
                       : page.style === "smart" ? smart
                       : graphs
    }
    Component { id: graphs; SystemGraphs { feed: sysFeed; visible: page.active } }
    Component { id: rings; SystemRings { feed: sysFeed; visible: page.active } }
    Component { id: bubble; BubbleMonitor { active: page.active } }
    Component { id: bento; SystemBento { feed: sysFeed; visible: page.active } }
    Component { id: smart; SystemSmart { feed: sysFeed; visible: page.active } }
}
