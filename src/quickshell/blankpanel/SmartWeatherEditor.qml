import QtQuick
import "../"
import "../reusables"
import "smartweather" as SmartWeather

// Edit panel's Smart bar for the Smart Weather style, above the big preview: the test bar of the Smart Weather
// design. Its first row sets the preview's time (Dawn, Noon, Sunset, Night, Live, a 24-hour Cycle, or the slider);
// its second row the weather and wind (preview only, nothing saved), and the arc line and tone, which are saved at
// once (panel.smartWeather.arc, .tone). The big preview reads `hour`, `liveTime`, `condition` and `wind`.
SmartBar {
    id: card
    signal finished()

    property bool open: false               // the editor is out: Cycle runs only then
    property bool liveTime: true
    property bool cycling: false
    property real testHour: new Date().getHours() + new Date().getMinutes() / 60
    property string condition: ""           // "" = the day's own weather
    property real wind: -1                  // < 0 = the day's own wind
    property real liveHour: testHour        // the preview's hour while Live (for the slider)
    readonly property real shownHour: liveTime ? liveHour : testHour
    readonly property bool arcOn: Config.getSetting("panel.smartWeather.arc", true) !== false
    readonly property string tone: SmartWeather.SmartMirrorTheme.toneMode
    signal conditionPicked()

    function reset() {
        liveTime = true;
        cycling = false;
        condition = "";
        wind = -1;
    }
    function setHour(h) {
        liveTime = false;
        cycling = false;
        testHour = ((h % 24) + 24) % 24;
    }
    function clock(h) {
        const v = ((h % 24) + 24) % 24;
        const m = Math.floor(v * 60 + 0.0001);
        return String(Math.floor(m / 60) % 24).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0");
    }

    // a whole day and night in 22 seconds
    FrameAnimation {
        running: card.cycling && card.open
        onTriggered: card.testHour = (card.testHour + Math.min(frameTime, 0.05) * (24 / 22)) % 24
    }

    // ---------- the time ----------
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(6)
        SmartLabel { strong: true; text: "Smart weather"; rightPadding: card.s(4) }
        SmartDivider {}
        SmartPill { label: "Dawn"; active: !card.liveTime && !card.cycling && Math.abs(card.testHour - 6.2) < 0.3; onClicked: card.setHour(6.2) }
        SmartPill { label: "Noon"; active: !card.liveTime && !card.cycling && Math.abs(card.testHour - 12.5) < 0.3; onClicked: card.setHour(12.5) }
        SmartPill { label: "Sunset"; active: !card.liveTime && !card.cycling && Math.abs(card.testHour - 17.75) < 0.3; onClicked: card.setHour(17.75) }
        SmartPill { label: "Night"; active: !card.liveTime && !card.cycling && (card.testHour >= 22.5 || card.testHour <= 1); onClicked: card.setHour(23.25) }
        SmartPill { label: "Live"; active: card.liveTime; onClicked: { card.liveTime = true; card.cycling = false; } }
        SmartPill {
            label: card.cycling ? "❚❚ Cycle" : "▶ Cycle"
            active: card.cycling
            onClicked: {
                if (card.liveTime) card.testHour = card.liveHour;
                card.liveTime = false;
                card.cycling = !card.cycling;
            }
        }
        SmartSlider {
            trackWidth: card.s(128)
            from: 0; to: 23.98; stepSize: 1 / 60
            value: card.shownHour
            valueText: card.clock(card.shownHour)
            onMoved: (v) => card.setHour(v)
        }
        SmartDivider {}
        SmartPill { label: I18n.t("widgets.redactor.done"); onClicked: card.finished() }
    }

    // ---------- the weather, the wind, the arc and the tone ----------
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: card.s(5)
        SmartChoices {
            current: card.condition
            options: [{ id: "", name: "Auto" }, { id: "clear", name: "Clear" }, { id: "cloudy", name: "Cloudy" },
                      { id: "overcast", name: "Overcast" }, { id: "mist", name: "Mist" }, { id: "rain", name: "Rain" },
                      { id: "snow", name: "Snow" }, { id: "storm", name: "Storm" }]
            onChosen: (id) => { card.conditionPicked(); card.condition = id; }
        }
        SmartDivider {}
        SmartSlider {
            label: "Wind"
            trackWidth: card.s(76)
            from: 0; to: 20; stepSize: 0.5
            value: Math.max(0, card.wind)
            valueText: card.wind < 0 ? "auto" : Math.round(card.wind) + ""
            onMoved: (v) => card.wind = v
        }
        SmartDivider {}
        SmartPill {
            label: card.arcOn ? "Arc On" : "Arc Off"
            active: card.arcOn
            onClicked: Config.setSetting("panel.smartWeather.arc", !card.arcOn)
        }
        SmartPill {
            label: card.tone === "theme" ? "Theme Tint" : "Mirror White"
            active: card.tone === "theme"
            onClicked: Config.setSetting("panel.smartWeather.tone", card.tone === "theme" ? "mirror" : "theme")
        }
    }
}
