pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root

    property var locationData: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.general && Config.rawSettings.general.location) ? Config.rawSettings.general.location : ({})
    property bool isDetecting: false

    readonly property string ip: locationData.ip || ""
    readonly property real latitude: locationData.latitude !== undefined ? Number(locationData.latitude) : 0.0
    readonly property real longitude: locationData.longitude !== undefined ? Number(locationData.longitude) : 0.0
    readonly property string city: locationData.city || "Unknown"
    readonly property string region: locationData.region || "Unknown"
    readonly property string regionCode: locationData.region_code || ""
    readonly property string countryName: locationData.country_name || locationData.country || "Unknown"
    readonly property string countryCode: locationData.country_code || ""
    readonly property string postal: locationData.postal || locationData.zip || ""
    readonly property string timezone: locationData.timezone || "UTC"
    readonly property string utcOffset: locationData.utc_offset || ""
    readonly property string currency: locationData.currency || ""
    readonly property string languages: locationData.languages || ""
    readonly property string asn: locationData.asn || ""
    readonly property string org: locationData.org || ""
    readonly property string source: locationData.source || "unknown"
    readonly property var updatedAt: locationData.updated_at !== undefined ? locationData.updated_at : 0
    // the place a manual lock was set to (Country / Province fields), or the detected country and region to start from
    readonly property string placeCountry: locationData.place_country || (countryName !== "Unknown" ? countryName : "")
    readonly property string placeProvince: locationData.place_province || (region !== "Unknown" ? region : "")
    // why the last lock did not apply ("Not found"), cleared on the next try
    property string placeError: ""

    // ---------- names offered while typing Country / Province (Open-Meteo's geocoding, as Apply looks them up) ----------
    // suggestKind says which field `suggestions` belong to; nothing runs until a field is typed in.
    property var suggestions: []
    property string suggestKind: ""
    // country names seen in Country suggestions → their codes: a province is then looked up in that country only (the
    // geocoder returns the world's first 100 names otherwise, which can leave a province out)
    property var countryCodes: ({})
    function codeOf(country) {
        const c = String(country || "").trim().toLowerCase();
        if (c === "") return "";
        if (countryCodes[c]) return countryCodes[c];
        if (c === countryName.toLowerCase() || c === countryCode.toLowerCase()) return countryCode;
        return c.length === 2 ? c.toUpperCase() : "";
    }
    function suggest(kind, text, country) {
        const q = String(text).trim();
        if (q.length < 2) { clearSuggestions(); return; }
        suggestTimer.pending = { kind: kind, q: q, country: String(country || "").trim() };
        suggestTimer.restart();
    }
    function clearSuggestions() {
        suggestTimer.stop();
        suggestTimer.pending = null;
        suggestProcess.running = false;
        root.suggestions = [];
        root.suggestKind = "";
    }
    Timer {
        id: suggestTimer
        property var pending: null
        interval: 300
        onTriggered: {
            suggestProcess.running = false;
            suggestProcess.query = pending;
            const code = pending.kind === "province" ? root.codeOf(pending.country) : "";
            suggestProcess.command = ["curl", "-s", "--max-time", "8", "-G", "https://geocoding-api.open-meteo.com/v1/search",
                                      "--data-urlencode", "name=" + pending.q, "-d", "count=100", "-d", "language=en", "-d", "format=json"]
                                     .concat(code !== "" ? ["-d", "countryCode=" + code] : []);
            suggestProcess.running = true;
        }
    }
    Process {
        id: suggestProcess
        property var query: null
        stdout: StdioCollector { id: suggestOut }
        onExited: {
            const q = query;
            if (!q || suggestTimer.pending !== q) return;     // a newer query is on its way
            let results = [];
            try { results = JSON.parse(suggestOut.text).results || []; } catch (e) { results = []; }
            // a name matches when one of its words starts as typed ("mai" finds Chiang Mai)
            const typed = q.q.toLowerCase();
            const matches = n => n.toLowerCase().startsWith(typed) || n.toLowerCase().split(/[\s-]+/).some(w => w.startsWith(typed));
            const c = q.country.toLowerCase();
            const names = [];
            for (const r of results) {
                const code = r.feature_code || "";
                let name = "";
                if (q.kind === "country") {
                    if (code.startsWith("PCL")) {
                        name = r.name || "";
                        if (name !== "" && r.country_code) { const m = Object.assign({}, root.countryCodes); m[name.toLowerCase()] = r.country_code; root.countryCodes = m; }
                    }
                }
                else if (/^PPL(A|C)$/.test(code) && (c === "" || (r.country || "").toLowerCase() === c || (r.country_code || "").toLowerCase() === c))
                    name = r.admin1 || r.name || "";
                if (name !== "" && matches(name) && names.indexOf(name) < 0) names.push(name);
                if (names.length >= 6) break;
            }
            root.suggestKind = q.kind;
            root.suggestions = names;
        }
    }

    readonly property var entries: {
        let arr = [];
        if (root.locationData) {
            for (let key in root.locationData) {
                let val = root.locationData[key];
                if (key === "updated_at" && typeof val === "number") {
                    val = new Date(val * 1000).toLocaleString();
                }
                arr.push({ label: key, value: String(val) });
            }
        }
        return arr;
    }

    signal locationUpdated()

    Connections {
        target: typeof Config !== "undefined" ? Config : null
        function onSettingsLoaded() {
            let gs = Config.getSetting("general", {});
            root.locationData = gs && gs.location ? gs.location : {};
            root.isDetecting = false;
            root.locationUpdated();
        }
        function onDataReadyChanged() {
            if (Config.dataReady) root.refreshAuto();
        }
    }

    onLocationDataChanged: {
        root.locationUpdated();
    }

    function get(key, fallbackValue) {
        if (root.locationData && root.locationData.hasOwnProperty(key)) {
            return root.locationData[key];
        }
        return fallbackValue !== undefined ? fallbackValue : "";
    }

    function detectAuto() {
        if (!Caching.anserinDir) return;
        root.isDetecting = true;
        root.placeError = "";
        autoProcess.running = false;
        autoProcess.forceRefresh = true;
        autoProcess.running = true;
    }

    function refreshAuto() {
        if (!Caching.anserinDir || !Config.dataReady || root.source === "manual" || autoProcess.running) return;
        root.isDetecting = true;
        autoProcess.forceRefresh = false;
        autoProcess.running = true;
    }

    // lock to a province of a country: everything that reads the location stays there until Auto-detect
    function setPlace(country, province) {
        if (!Caching.anserinDir || manualProcess.running) return;
        root.placeError = "";
        root.isDetecting = true;
        autoProcess.running = false;   // a detection still running would save over the lock
        manualProcess.command = ["bash", Caching.anserinDir + "/scripts/location_manual.sh", String(country), String(province)];
        manualProcess.running = true;
    }

    Process {
        id: autoProcess
        property bool forceRefresh: false
        command: ["bash", Caching.anserinDir + "/scripts/location.sh"].concat(forceRefresh ? ["--refresh"] : [])
        onExited: {
            root.isDetecting = manualProcess.running;
        }
    }

    Process {
        id: manualProcess
        stdout: StdioCollector { id: manualOut }
        onExited: {
            root.isDetecting = autoProcess.running;
            let r = {};
            try { r = JSON.parse(manualOut.text.trim().split("\n").pop()); } catch (e) { r = { error: "Not found" }; }
            root.placeError = r.error || "";
        }
    }

    Component.onCompleted: {
        if (typeof Config !== "undefined" && Config.dataReady) {
            let gs = Config.getSetting("general", {});
            if (gs && gs.location) {
                root.locationData = gs.location;
            }
            root.refreshAuto();
        }
    }
}
