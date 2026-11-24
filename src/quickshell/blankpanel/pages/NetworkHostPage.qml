import QtQuick
import "../../"
import ".."

// Lazy-loaded host for BlankPanel's Network page (Classic / Radar / Gargantua).
Item {
    id: host
    property var panel: null
    property bool active: false

    function s(v) { return panel ? panel.s(v) : Scaler.s(v); }
    readonly property string style: PanelLayout.style("network")

    Loader {
        anchors.fill: parent
        active: host.style === "classic"
        asynchronous: true
        source: active ? Qt.resolvedUrl("../../network/NetworkPopup.qml") : ""
        onLoaded: {
            if (!item) return;
            const factor = 0.78;
            item.anchors.centerIn = parent;
            item.width = Qt.binding(() => host.s(720) * factor);
            item.height = Qt.binding(() => host.s(600) * factor);
            item.sizeFactor = factor;
            item.visible = true;
        }
    }

    Timer { id: networkRelease; interval: 400 }
    onActiveChanged: if (!active) networkRelease.restart()

    Loader {
        active: host.style !== "classic" && (host.active || networkRelease.running || PanelLayout.networkPowerBusy)
        width: 565
        height: 525
        scale: host.width / 565
        transformOrigin: Item.TopLeft
        asynchronous: true
        source: active ? Qt.resolvedUrl("../../network/orbit/NetworkStyleShell.qml") : ""
        onLoaded: {
            if (!item) return;
            item.style = Qt.binding(() => host.style);
            item.shown = Qt.binding(() => host.active);
        }
    }
}
