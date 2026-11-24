import QtQuick
import "../../"
import ".."
import "../smartweather" as SmartWeather

// Lazy-loaded host for BlankPanel's Weather page (Classic / Dashboard / Smart).
Item {
    id: host
    property var panel: null
    property bool active: false

    readonly property string style: PanelLayout.style("weather")

    Loader {
        anchors.fill: parent
        active: host.style !== "smart"
        visible: active
        asynchronous: true
        source: active ? Qt.resolvedUrl("../WeatherPage.qml") : ""
        onLoaded: {
            if (!item) return;
            item.active = Qt.binding(() => host.active && host.style !== "smart");
            item.dashboard = Qt.binding(() => host.style === "dashboard");
        }
    }

    // Smart: drawn at its design size (565 x 525) and scaled to the page
    Loader {
        active: host.style === "smart"
        width: 565
        height: 525
        scale: host.width / 565
        transformOrigin: Item.TopLeft
        sourceComponent: SmartWeather.SmartWeatherPage {
            running: host.active
            liveTime: true
            cornerRadius: Math.min(ThemeBackend.borderRadius, 20) / Math.max(0.01, host.width / 565)
            showArc: Config.getSetting("panel.smartWeather.arc", true) !== false
        }
    }
}
