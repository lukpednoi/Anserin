pragma Singleton
import QtQuick
import Quickshell
import "../../"

// The Smart Weather style's weather: the shell's own Weather data (the same weather.json the Classic and Dashboard
// styles read) reshaped for SmartWeatherPage — five days, each with its hourly readings and a condition — and the
// city from Location. `offline` while there is no forecast; the page then shows dashes.
Singleton {
    id: root

    readonly property var wData: Weather.data
    readonly property bool offline: !wData || wData.offline === true || !Array.isArray(wData.forecast) || wData.forecast.length === 0
    readonly property bool hasLiveData: !offline
    readonly property string unitSym: Weather.unitSym || "°C"
    readonly property string windUnit: Weather.unit === "imperial" ? "mph" : "m/s"
    readonly property string cityName: Location.city && Location.city !== "Unknown" ? Location.city : ""
    readonly property real currentTemp: !offline && wData.current_temp !== undefined && wData.current_temp !== null ? Number(wData.current_temp) : 0
    readonly property int currentCode: !offline && wData.current_code !== undefined ? Number(wData.current_code) : 0
    readonly property var forecast: {
        if (offline) return [];
        const out = [];
        const count = Math.min(5, wData.forecast.length);
        for (let i = 0; i < count; i++) {
            const f = wData.forecast[i];
            const hrs = (Array.isArray(f.hourly) ? f.hourly : []).map(h => ({
                time: formatTimeShort(h.time),
                temp: Number(h.temp),
                icon: h.icon || "",
                cond: conditionFromCode(h.code, h.icon)
            }));
            // Today shows the weather now everywhere (the forecast's day summary is one hour's snapshot, so it
            // could say Sunny under a sky that is raining)
            const now = i === 0 && hasLiveData;
            out.push({
                day: i === 0 ? "Today" : (f.day || ("Day " + (i + 1))),
                day_full: f.day_full || f.day || "",
                date: f.date || "",
                max: Number(f.max),
                min: Number(f.min),
                feels_like: Number(f.feels_like !== undefined ? f.feels_like : f.max),
                wind: Number(f.wind || 0),
                humidity: Number(f.humidity || 0),
                pop: Number(f.pop || 0),
                sunrise: formatTimeShort(f.sunrise),
                sunset: formatTimeShort(f.sunset),
                // today's row uses the same words as the page's header for the weather now
                desc: now ? conditionLabel(conditionFromCode(currentCode, wData.current_icon))
                          : (f.desc || conditionLabel(conditionFromCode(f.code, f.icon))),
                code: now ? currentCode : (f.code !== undefined ? Number(f.code) : 0),
                icon: now ? (wData.current_icon || f.icon || "") : (f.icon || ""),
                hourly: hrs
            });
        }
        return out;
    }

    function conditionFromCode(code, iconFallback) {
        if (code !== null && code !== undefined && !isNaN(Number(code))) {
            const c = Number(code);
            if (c === 0) return "clear";
            if (c === 1 || c === 2) return "cloudy";
            if (c === 3) return "overcast";
            if (c === 45 || c === 48) return "mist";
            if ((c >= 51 && c <= 57) || (c >= 61 && c <= 67) || (c >= 80 && c <= 82)) return "rain";
            if ((c >= 71 && c <= 77) || c === 85 || c === 86) return "snow";
            if (c >= 95) return "storm";
            return "clear";
        }
        if (iconFallback) {
            if (iconFallback === "") return "cloudy";
            if (iconFallback === "\u{F0591}") return "mist";
            if (iconFallback === "\u{F0597}") return "rain";
            if (iconFallback === "") return "snow";
            if (iconFallback === "") return "storm";
        }
        return "clear";
    }

    function conditionLabel(cond) {
        return ({ clear: "Clear sky", cloudy: "Partly cloudy", overcast: "Overcast", mist: "Atmospheric mist",
                  rain: "Rain showers", snow: "Snowfall", storm: "Thunderstorm" })[cond] || "Clear sky";
    }

    function formatTimeShort(raw) {
        if (!raw) return "--:--";
        const m = String(raw).match(/(\d{1,2}:\d{2})/);
        return m ? m[1] : String(raw);
    }

    function parseHourFloat(raw, fallbackHour) {
        if (!raw) return fallbackHour;
        const m = String(raw).match(/(\d{1,2}):(\d{2})/);
        return m ? Number(m[1]) + Number(m[2]) / 60 : fallbackHour;
    }
}
