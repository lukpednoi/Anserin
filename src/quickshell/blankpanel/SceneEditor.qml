import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

// Edit panel's side card for the Dashboard Weather scene. Adjust sets what is saved (panel.weatherScene.*: look,
// moon, strength, arc line and its colour), at once, as the Style previews do. Test changes the time, date,
// weather and wind of the big preview only (nothing is saved; `test` is null outside Test).
Rectangle {
    id: card

    property string mode: "adjust"            // adjust, test
    signal finished()

    function s(v) { return Scaler.s(v); }

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

    implicitHeight: content.implicitHeight + s(36)
    radius: ThemeBackend.clampedBorderRadius
    color: Qt.darker(ThemeBackend.surface0, 1.22)

    // a named track; drag, click or wheel
    component Track: Item {
        id: track
        property string name: ""
        property string valueText: ""
        property real from: 0
        property real to: 1
        property real stepSize: 0.05
        property real value: 0
        signal moved(real value)
        implicitHeight: card.s(46)
        function pick(px) {
            const t = Math.max(0, Math.min(1, (px - knob.width / 2) / Math.max(1, bar.width - knob.width)));
            moved(Math.max(from, Math.min(to, Math.round((from + t * (to - from)) / stepSize) * stepSize)));
        }
        Text {
            text: track.name
            font.family: ThemeBackend.fontFamily; font.pixelSize: card.s(12); font.bold: true
            color: ThemeBackend.subtext0
        }
        Text {
            anchors.right: parent.right
            text: track.valueText
            font.family: ThemeBackend.fontFamily; font.pixelSize: card.s(12); font.bold: true
            color: ThemeBackend.mauve
        }
        Rectangle {
            id: bar
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: parent.bottom; anchors.bottomMargin: card.s(6)
            height: card.s(8)
            radius: height / 2
            color: ThemeBackend.surface1
            Rectangle {
                width: knob.x + knob.width / 2
                height: parent.height
                radius: parent.radius
                color: Qt.alpha(ThemeBackend.mauve, 0.6)
            }
            Rectangle {
                id: knob
                readonly property real t: track.to > track.from ? (track.value - track.from) / (track.to - track.from) : 0
                x: t * (bar.width - width)
                anchors.verticalCenter: parent.verticalCenter
                width: drag.pressed ? card.s(20) : card.s(16)
                height: width
                radius: width / 2
                color: ThemeBackend.mauve
                Behavior on width { NumberAnimation { duration: 120 } }
            }
        }
        MouseArea {
            id: drag
            anchors.fill: bar
            anchors.margins: -card.s(10)
            cursorShape: Qt.PointingHandCursor
            onPressed: (e) => track.pick(e.x - card.s(10))
            onPositionChanged: (e) => { if (pressed) track.pick(e.x - card.s(10)); }
            onWheel: (e) => {
                const dir = (e.angleDelta.y || e.angleDelta.x) > 0 ? 1 : -1;
                track.moved(Math.max(track.from, Math.min(track.to, track.value + dir * track.stepSize)));
            }
        }
    }

    ColumnLayout {
        id: content
        x: card.s(18); y: card.s(18)
        width: card.width - card.s(36)
        spacing: card.s(14)

        Text {
            text: "Weather scene"
            font.family: ThemeBackend.fontFamily
            font.pixelSize: card.s(16)
            font.bold: true
            color: ThemeBackend.text
        }

        // the two modes
        EditorChoices {
            Layout.fillWidth: true
            name: "Mode"
            current: card.mode
            options: [{ id: "adjust", name: "Adjust" }, { id: "test", name: "Test" }]
            onChosen: (id) => card.mode = id
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(ThemeBackend.text, 0.08) }

        // ---------- Adjust ----------
        ColumnLayout {
            Layout.fillWidth: true
            visible: card.mode === "adjust"
            spacing: card.s(14)

            EditorChoices {
                Layout.fillWidth: true
                name: "Look"
                current: card.look
                options: [{ id: "flat", name: "Flat" }, { id: "pixel", name: "Pixel" }, { id: "soft", name: "Soft" }]
                onChosen: (id) => card.save("look", id)
            }
            EditorChoices {
                Layout.fillWidth: true
                name: "Moon"
                current: card.moon
                options: [{ id: "yellow", name: "Yellow" }, { id: "white", name: "White" }]
                onChosen: (id) => card.save("moon", id)
            }
            Track {
                Layout.fillWidth: true
                name: "Strength"
                from: 0.2; to: 1; stepSize: 0.05
                value: card.strength
                valueText: Math.round(value * 100) + "%"
                onMoved: (v) => card.save("strength", Math.round(v * 100) / 100)
            }
            EditorChoices {
                Layout.fillWidth: true
                name: "Arc line"
                current: card.arcOn ? "on" : "off"
                options: [{ id: "off", name: "Off" }, { id: "on", name: "On" }]
                onChosen: (id) => card.save("path", id === "on")
            }
            EditorChoices {
                Layout.fillWidth: true
                name: "Arc colour"
                enabledRow: card.arcOn
                current: card.arcTone
                options: [{ id: "theme", name: "Theme" }, { id: "daynight", name: "Day & night" }]
                onChosen: (id) => card.save("pathTone", id)
            }
        }

        // ---------- Test (the big preview only) ----------
        ColumnLayout {
            Layout.fillWidth: true
            visible: card.mode === "test"
            spacing: card.s(14)

            Track {
                Layout.fillWidth: true
                name: "Time of day"
                from: 0; to: 23 + 59 / 60; stepSize: 1 / 60
                value: card.testHour
                valueText: card.clock(value)
                onMoved: (v) => card.testHour = v
            }
            Track {
                Layout.fillWidth: true
                name: "Date (moon phase)"
                from: 0; to: 29; stepSize: 1
                value: card.testDay
                valueText: {
                    const d = new Date();
                    d.setDate(d.getDate() + card.testDay);
                    return d.toLocaleDateString(Qt.locale(I18n.currentLang), "d MMM");
                }
                onMoved: (v) => card.testDay = Math.round(v)
            }
            EditorChoices {
                Layout.fillWidth: true
                name: "Weather"
                current: card.testWeather
                options: [{ id: "clear", name: "Clear" }, { id: "cloudy", name: "Cloudy" }, { id: "overcast", name: "Overcast" },
                          { id: "mist", name: "Mist" }, { id: "rain", name: "Rain" }, { id: "snow", name: "Snow" }, { id: "storm", name: "Storm" }]
                onChosen: (id) => card.testWeather = id
            }
            Track {
                Layout.fillWidth: true
                name: "Wind"
                from: 0; to: 30; stepSize: 1
                value: card.testWind
                valueText: Math.round(value) + " m/s"
                onMoved: (v) => card.testWind = v
            }
        }

        ClickButton {
            Layout.alignment: Qt.AlignRight
            implicitHeight: card.s(34)
            horizontalPadding: card.s(16)
            cornerRadius: ThemeBackend.borderRadius
            buttonText: I18n.t("widgets.redactor.done")
            textFontSize: card.s(12)
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.crust
            onClicked: card.finished()
        }
    }
}
