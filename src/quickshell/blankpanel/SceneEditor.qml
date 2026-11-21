import QtQuick
import "../"
import "../reusables"

// Edit panel's Smart bar for the Dashboard Weather scene, above the big preview. Adjust sets what is saved
// (panel.weatherScene.*: look, moon, strength, arc line and its colour), at once, as the Style previews do. Test
// changes the time, date, weather and wind of the big preview only (nothing is saved; `test` is null outside Test).
SmartBar {
    id: card

    property string mode: "adjust"            // adjust, test
    signal finished()

    // ---------- saved settings ----------
    readonly property var settings: Config.getSetting("panel.weatherScene", {}) || {}
    readonly property string look: settings.look || "flat"
    readonly property string moon: settings.moon || "yellow"
    readonly property real strength: settings.strength !== undefined ? settings.strength : 1
    readonly property bool arcOn: settings.path === true
    readonly property string arcTone: settings.pathTone || "theme"
    function save(key, value) { Config.setSetting("panel.weatherScene." + key, value); }

    // ---------- test values ----------
    // the big preview's live time, day, weather and wind ({ hour, dayOffset, condition, wind }): Test starts from
    // them, so switching modes shows the same scene
    property var live: null
    onModeChanged: {
        if (mode !== "test" || !live) return;
        testHour = live.hour;
        testDay = live.dayOffset;
        testWeather = live.condition;
        testWind = live.wind;
    }
    property real testHour: new Date().getHours() + new Date().getMinutes() / 60
    property int testDay: 0
    property string testWeather: "clear"
    property real testWind: 3
    readonly property var test: mode === "test" ? { hour: testHour, dayOffset: testDay, condition: testWeather, wind: testWind } : null

    function clock(h) {
        const m = Math.floor(h * 60 + 0.0001);
        return String(Math.floor(m / 60) % 24).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }

    // the title, the two modes and Done
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartLabel { strong: true; text: "Weather scene"; rightPadding: card.s(4) }
        SmartChoices {
            current: card.mode
            options: [{ id: "adjust", name: "Adjust" }, { id: "test", name: "Test" }]
            onChosen: (id) => card.mode = id
        }
        SmartDivider {}
        SmartPill { label: I18n.t("widgets.redactor.done"); onClicked: card.finished() }
    }

    // ---------- Adjust ----------
    Row {
        visible: card.mode === "adjust"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartChoices {
            name: "Look"
            current: card.look
            options: [{ id: "flat", name: "Flat" }, { id: "pixel", name: "Pixel" }, { id: "soft", name: "Soft" }]
            onChosen: (id) => card.save("look", id)
        }
        SmartDivider {}
        SmartChoices {
            name: "Moon"
            current: card.moon
            options: [{ id: "yellow", name: "Yellow" }, { id: "white", name: "White" }]
            onChosen: (id) => card.save("moon", id)
        }
        SmartDivider {}
        SmartSlider {
            label: "Strength"
            from: 0.2; to: 1; stepSize: 0.05
            value: card.strength
            valueText: Math.round(value * 100) + "%"
            onMoved: (v) => card.save("strength", Math.round(v * 100) / 100)
        }
    }
    Row {
        visible: card.mode === "adjust"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartChoices {
            name: "Arc line"
            current: card.arcOn ? "on" : "off"
            options: [{ id: "off", name: "Off" }, { id: "on", name: "On" }]
            onChosen: (id) => card.save("path", id === "on")
        }
        SmartDivider {}
        SmartChoices {
            name: "Arc colour"
            enabledRow: card.arcOn
            current: card.arcTone
            options: [{ id: "theme", name: "Theme" }, { id: "daynight", name: "Day & night" }]
            onChosen: (id) => card.save("pathTone", id)
        }
    }

    // ---------- Test (the big preview only) ----------
    Row {
        visible: card.mode === "test"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(10)
        SmartSlider {
            label: "Time"
            trackWidth: card.s(150)
            from: 0; to: 23 + 59 / 60; stepSize: 1 / 60
            value: card.testHour
            valueText: card.clock(value)
            onMoved: (v) => card.testHour = v
        }
        SmartDivider {}
        SmartSlider {
            label: "Date (moon)"
            trackWidth: card.s(120)
            from: 0; to: 29; stepSize: 1
            value: card.testDay
            valueText: {
                const d = new Date();
                d.setDate(d.getDate() + card.testDay);
                return d.toLocaleDateString(Qt.locale(I18n.currentLang), "d MMM");
            }
            onMoved: (v) => card.testDay = Math.round(v)
        }
    }
    Row {
        visible: card.mode === "test"
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartChoices {
            current: card.testWeather
            options: [{ id: "clear", name: "Clear" }, { id: "cloudy", name: "Cloudy" }, { id: "overcast", name: "Overcast" },
                      { id: "mist", name: "Mist" }, { id: "rain", name: "Rain" }, { id: "snow", name: "Snow" }, { id: "storm", name: "Storm" }]
            onChosen: (id) => card.testWeather = id
        }
        SmartDivider {}
        SmartSlider {
            label: "Wind"
            from: 0; to: 30; stepSize: 1
            value: card.testWind
            valueText: Math.round(value) + " m/s"
            onMoved: (v) => card.testWind = v
        }
    }
}
