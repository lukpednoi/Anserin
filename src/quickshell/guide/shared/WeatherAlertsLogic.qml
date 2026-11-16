import QtQuick
import Quickshell
import "../../"

// Weather alerts settings ("weatherAlerts", read by singletons/environment/WeatherAlerts.qml and GovAlerts.qml):
// the main switch, the twice-daily forecast, official warnings, quiet hours and which kinds of alert to send.
// Used by the Settings page (guide/general/GeneralTab.qml) and the Control Center's board (GeneralPage.qml).
Item {
    id: logic
    readonly property var defaults: WeatherAlerts.defaults
    readonly property var settings: Object.assign({}, defaults, Config.getSetting("weatherAlerts", defaults))
    readonly property bool alertsOn: !!settings.enabled
    readonly property bool quietOn: alertsOn && !!settings.quietHours

    readonly property var kinds: [
        { key: "rain_soon", title: "Rain soon" }, { key: "snow_soon", title: "Snow soon" },
        { key: "heavy_rain", title: "Heavy rain" }, { key: "heavy_snow", title: "Heavy snow" },
        { key: "thunderstorm", title: "Thunderstorms" }, { key: "ice", title: "Ice" }, { key: "fog", title: "Fog" },
        { key: "temp_rise", title: "Temperature rise" }, { key: "temp_drop", title: "Temperature drop" },
        { key: "hot", title: "Heat" }, { key: "cold", title: "Cold" }, { key: "wind", title: "Strong wind" },
        { key: "uv", title: "UV index" }, { key: "air_quality", title: "Air quality" }
    ]
    readonly property var pickedKinds: kinds.filter(k => settings[k.key] === true).map(k => k.key)

    function set(key, value) {
        let next = Object.assign({}, defaults, Config.getSetting("weatherAlerts", defaults));
        next[key] = value;
        Config.setSetting("weatherAlerts", next);
    }
    function setQuiet(start, end) {
        let next = Object.assign({}, defaults, Config.getSetting("weatherAlerts", defaults));
        next.quietStart = start;
        next.quietEnd = end;
        Config.setSetting("weatherAlerts", next);
    }
    function setKinds(keys) {
        keys = Array.prototype.slice.call(keys || []);   // a Qt list from a signal is not a JS array
        let next = Object.assign({}, defaults, Config.getSetting("weatherAlerts", defaults));
        for (const k of kinds) next[k.key] = keys.indexOf(k.key) >= 0;
        Config.setSetting("weatherAlerts", next);
    }
    function govStatusText() {
        const labels = { ok: "Connected", partial: "Partially connected", unavailable: "Unavailable", disabled: "Disabled" };
        const last = GovAlerts.lastSuccess > 0 ? Qt.formatDateTime(new Date(GovAlerts.lastSuccess), "yyyy-MM-dd HH:mm") : "Never";
        return (labels[GovAlerts.status] || "Unknown") + " · Last success: " + last + " · Sources reachable: " + GovAlerts.sourcesOk + "/" + GovAlerts.sourcesTotal;
    }
}
