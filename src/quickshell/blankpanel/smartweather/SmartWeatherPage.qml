import QtQuick
import QtQuick.Layouts

/**
 * Smart Mirror / Smart Home Weather page.
 * Responsive across Anserin's exact 565x525 Left Panel slot and 1920x1080 Fullscreen.
 * Combines full-page Atmospheric Blur + Horizon Sun/Moon cycle with thin MagicMirror2
 * typography, hairline dividers, vector line icons, and interactive day/time exploration.
 */
Item {
    id: page

    // Controlled by preview host (or live shell when integrated)
    property real hour: 12.0               // 0 - 24 (live or test override)
    property bool liveTime: true
    property string conditionOverride: ""  // "" = use selected day's weather
    property real windOverride: -1         // < 0 = use selected day's wind
    property real cornerRadius: 20
    property bool showArc: true
    property bool running: true
    property bool isFullscreen: false

    // Emitted when user drags horizontally across the sky/horizon to scrub time
    signal hourScrubbed(real newHour)
    signal daySelected(int index)

    readonly property bool isWide: width >= 880
    readonly property real sc: isWide ? Math.max(1.15, Math.min(width / 1180, height / 700)) : 1.0
    function s(v) { return Math.round(v * sc); }

    // Live clock for date & seconds readout (updates 1/s only when visible & running). It reads the time the
    // moment the page shows (no old time from when it was last closed) and ticks on each real second.
    property var nowDate: new Date()
    Timer {
        interval: 1000
        running: page.running && page.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            page.nowDate = new Date();
            interval = 1000 - page.nowDate.getMilliseconds() + 5;
        }
    }

    // Selected forecast day (0 = Today .. 4)
    property int day: 0
    property int targetDay: 0
    property real dayFade: 1.0
    property real dayShift: 0.0
    property int dayDir: 1

    readonly property var forecast: SmartWeatherData.forecast
    readonly property int dayCount: Math.min(5, forecast ? forecast.length : 0)
    readonly property var dayData: (forecast && forecast[day]) ? forecast[day] : null

    function setDay(idx) {
        if (idx < 0 || idx >= dayCount || idx === targetDay) return;
        if (dayAnim.running) {
            dayAnim.stop();
            backdrop.animateNextChange();
            day = targetDay;
            dayFade = 1.0;
            dayShift = 0.0;
        }
        dayDir = idx > day ? 1 : -1;
        targetDay = idx;
        dayAnim.start();
        page.daySelected(idx);
    }

    function animateWeatherTransition() {
        backdrop.animateNextChange();
    }

    SequentialAnimation {
        id: dayAnim
        ParallelAnimation {
            NumberAnimation { target: page; property: "dayFade"; to: 0.0; duration: 200; easing.type: Easing.InSine }
            NumberAnimation { target: page; property: "dayShift"; to: -18 * page.dayDir; duration: 200; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                backdrop.animateNextChange();
                page.day = page.targetDay;
                page.dayShift = 18 * page.dayDir;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: page; property: "dayFade"; to: 1.0; duration: 360; easing.type: Easing.OutQuint }
            NumberAnimation { target: page; property: "dayShift"; to: 0.0; duration: 360; easing.type: Easing.OutQuint }
        }
    }

    // Active hour, date, condition & wind feeding the full-page backdrop
    readonly property real activeHour: liveTime
        ? (nowDate.getHours() + nowDate.getMinutes() / 60 + nowDate.getSeconds() / 3600)
        : hour

    readonly property var activeDate: {
        const d = new Date(nowDate.getTime());
        d.setDate(d.getDate() + day);
        return d;
    }

    readonly property string activeCondition: {
        if (conditionOverride !== "") return conditionOverride;
        if (day === 0 && SmartWeatherData.hasLiveData) {
            return SmartWeatherData.conditionFromCode(SmartWeatherData.currentCode, dayData ? dayData.icon : "");
        }
        return dayData ? SmartWeatherData.conditionFromCode(dayData.code, dayData.icon) : "clear";
    }

    readonly property real activeWind: {
        if (windOverride >= 0) return windOverride;
        return dayData ? Number(dayData.wind || 0) : 3.2;
    }

    readonly property string activeConditionDesc: {
        if (conditionOverride !== "") return SmartWeatherData.conditionLabel(conditionOverride);
        // today's line follows the weather now, as the icon does
        if (day === 0 && SmartWeatherData.hasLiveData) return SmartWeatherData.conditionLabel(activeCondition);
        return dayData && dayData.desc ? dayData.desc : SmartWeatherData.conditionLabel(activeCondition);
    }

    // Counting temperature transition (just like Dashboard WeatherArcBox!)
    readonly property real targetTemp: {
        if (targetDay === 0 && SmartWeatherData.hasLiveData) return SmartWeatherData.currentTemp;
        return (forecast && forecast[targetDay]) ? Number(forecast[targetDay].max) : SmartWeatherData.currentTemp;
    }
    property real displayedTemp: targetTemp
    Behavior on displayedTemp {
        NumberAnimation { id: tempCounter; duration: 700; easing.type: Easing.OutQuart }
    }

    // Formatted clock reflecting live time or scrubbed/test hour
    readonly property int dispHourInt: Math.floor(((activeHour % 24) + 24) % 24)
    readonly property int dispMinInt: Math.floor(((((activeHour % 24) + 24) % 24) - dispHourInt) * 60)
    readonly property string clockHm: (dispHourInt < 10 ? "0" : "") + dispHourInt + ":" + (dispMinInt < 10 ? "0" : "") + dispMinInt
    readonly property string clockSec: {
        const sec = liveTime ? nowDate.getSeconds() : Math.floor((((activeHour * 3600) % 60) + 60) % 60);
        return (sec < 10 ? "0" : "") + sec;
    }
    readonly property string dateHeading: Qt.formatDate(activeDate, "dddd, MMMM d")

    // one row of the atmosphere list (0 humidity, 1 rain chance, 2 wind, 3 daylight or the moon)
    function telemetryRow(i) {
        if (i === 0) return { icon: "humidity", label: "Humidity",
                              val: dayData ? (Math.round(dayData.humidity) + "%") : "--",
                              ratio: dayData ? Math.max(0, Math.min(1, Number(dayData.humidity) / 100)) : 0 };
        if (i === 1) return { icon: "rain", label: "Rain chance",
                              val: dayData ? (Math.round(dayData.pop) + "%") : "--",
                              ratio: dayData ? Math.max(0, Math.min(1, Number(dayData.pop) / 100)) : 0 };
        if (i === 2) return { icon: "wind", label: "Wind speed",
                              val: activeWind.toFixed(1) + " " + SmartWeatherData.windUnit,
                              ratio: Math.max(0, Math.min(1, activeWind / 20)) };
        return { icon: backdrop.sunUp ? "sunrise" : "clear", label: backdrop.sunUp ? "Daylight" : "Moon phase",
                 val: backdrop.sunUp ? daylightDuration : backdrop.moonName,
                 ratio: backdrop.sunUp ? backdrop.arcT : backdrop.moonLit };
    }

    readonly property string daylightDuration: {
        const sr = SmartWeatherData.parseHourFloat(dayData ? dayData.sunrise : "06:18", 6.3);
        const ss = SmartWeatherData.parseHourFloat(dayData ? dayData.sunset : "17:49", 17.8);
        const diff = Math.max(0, ss - sr);
        const hrs = Math.floor(diff);
        const mins = Math.round((diff - hrs) * 60);
        return hrs + "h " + (mins < 10 ? "0" : "") + mins + "m";
    }

    // =========================================================================
    // FULL-PAGE ATMOSPHERIC BLUR + HORIZON SKY BACKDROP
    // =========================================================================
    SmartSkyBackdrop {
        id: backdrop
        anchors.fill: parent
        hour: page.activeHour
        date: page.activeDate
        condition: page.activeCondition
        wind: page.activeWind
        horizonFrac: page.isWide ? 0.57 : 0.54
        cornerRadius: page.cornerRadius
        showArc: page.showArc
        arcAccent: SmartMirrorTheme.accent
        useAccentArc: SmartMirrorTheme.toneMode === "theme"
        running: page.running
    }

    // Subtle crisp glass rim border in Panel mode
    Rectangle {
        anchors.fill: parent
        radius: page.cornerRadius
        color: "transparent"
        border.width: page.cornerRadius > 0 ? 1 : 0
        border.color: Qt.rgba(1, 1, 1, 0.14)
        visible: page.cornerRadius > 0
        z: 5
    }

    // =========================================================================
    // INTERACTIVE HORIZON TIME SCRUBBER (drag across the sky zone!)
    // =========================================================================
    MouseArea {
        id: skyScrubber
        x: 0
        y: page.s(94)
        width: page.width
        height: Math.max(40, backdrop.horizonY - y + page.s(14))
        hoverEnabled: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        z: 3

        property bool scrubbing: false
        function applyScrub(mx) {
            const leftX = page.width * 0.10;
            const rightX = page.width * 0.90;
            const t = Math.max(0, Math.min(1, (mx - leftX) / Math.max(1, rightX - leftX)));
            // Scrub across current celestial half (day 06..18 or night 18..06), or full 0..24 with Shift
            const fullDay = t * 24.0;
            page.hourScrubbed(fullDay);
        }
        onPressed: (mouse) => { scrubbing = true; applyScrub(mouse.x); }
        onPositionChanged: (mouse) => { if (scrubbing) applyScrub(mouse.x); }
        onReleased: scrubbing = false
        onCanceled: scrubbing = false
    }

    // =========================================================================
    // HORIZON ENDPOINT MARKERS & CELESTIAL READOUT (pinned right to horizonY)
    // =========================================================================
    Item {
        id: horizonMarks
        anchors.fill: parent
        z: 4
        enabled: false

        readonly property real leftAnchorX: page.width * 0.5 - backdrop.arcRx
        readonly property real rightAnchorX: page.width * 0.5 + backdrop.arcRx
        readonly property real hY: backdrop.horizonY

        // Left horizon dot (Sunrise / Moonrise) + label tucked crisply on dark reflection edge below horizon
        Rectangle {
            width: page.s(5); height: width; radius: width / 2
            x: horizonMarks.leftAnchorX - width / 2
            y: horizonMarks.hY - height / 2
            color: SmartMirrorTheme.ink
            opacity: 0.80
        }
        Text {
            text: backdrop.sunUp ? (page.dayData ? page.dayData.sunrise : "06:18") : "18:00"
            x: Math.max(page.s(18), horizonMarks.leftAnchorX - implicitWidth * 0.4)
            y: horizonMarks.hY + page.s(5)
            font.family: SmartMirrorTheme.uiFont
            font.weight: Font.Light
            font.pixelSize: page.s(10)
            font.letterSpacing: 0.8
            color: SmartMirrorTheme.inkSoft
            opacity: 0.86
        }

        // Right horizon dot (Sunset / Moonset) + label below horizon
        Rectangle {
            width: page.s(5); height: width; radius: width / 2
            x: horizonMarks.rightAnchorX - width / 2
            y: horizonMarks.hY - height / 2
            color: SmartMirrorTheme.ink
            opacity: 0.80
        }
        Text {
            text: backdrop.sunUp ? (page.dayData ? page.dayData.sunset : "17:49") : "06:00"
            x: Math.min(page.width - implicitWidth - page.s(18), horizonMarks.rightAnchorX - implicitWidth * 0.6)
            y: horizonMarks.hY + page.s(5)
            font.family: SmartMirrorTheme.uiFont
            font.weight: Font.Light
            font.pixelSize: page.s(10)
            font.letterSpacing: 0.8
            color: SmartMirrorTheme.inkSoft
            opacity: 0.86
        }
    }

    // =========================================================================
    // TOP SMART MIRROR HERO HEADER (Date/Clock Left  |  Temp/Conditions Right)
    // =========================================================================
    Item {
        id: headerZone
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: page.isWide ? page.s(36) : 18
        anchors.leftMargin: page.isWide ? page.s(54) : 22
        anchors.rightMargin: page.isWide ? page.s(54) : 22
        height: page.isWide ? page.s(126) : 92
        z: 4

        // ---- TOP-LEFT: Smart Mirror Date + Thin Clock w/ Superscript Seconds ----
        Column {
            anchors.left: parent.left
            anchors.top: parent.top
            spacing: page.isWide ? page.s(2) : 1

            Text {
                text: page.dateHeading
                font.family: SmartMirrorTheme.uiFont
                font.weight: Font.Light
                font.pixelSize: page.isWide ? page.s(15) : 12
                font.letterSpacing: 0.4
                color: SmartMirrorTheme.inkSoft
                opacity: page.dayFade
                transform: Translate { x: page.dayShift * 0.4 }
            }

            Row {
                spacing: page.s(3)

                Text {
                    text: page.clockHm
                    font.family: SmartMirrorTheme.uiFont
                    font.weight: Font.ExtraLight
                    font.pixelSize: page.isWide ? page.s(58) : 38
                    font.letterSpacing: -1.0
                    color: SmartMirrorTheme.ink
                    lineHeight: 0.96
                }

                Text {
                    text: page.clockSec
                    anchors.top: parent.top
                    anchors.topMargin: page.isWide ? page.s(8) : 5
                    font.family: SmartMirrorTheme.uiFont
                    font.weight: Font.Light
                    font.pixelSize: page.isWide ? page.s(18) : 13
                    color: SmartMirrorTheme.inkMuted
                }
            }

            Row {
                spacing: page.s(6)
                topPadding: page.isWide ? page.s(4) : 2

                Rectangle {
                    width: page.s(5); height: width; radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: SmartMirrorTheme.toneMode === "theme" ? SmartMirrorTheme.accent : "#ffffff"
                    opacity: 0.85
                }

                Text {
                    text: (SmartWeatherData.cityName !== "" ? SmartWeatherData.cityName + "  ·  " : "") + page.activeConditionDesc
                    font.family: SmartMirrorTheme.uiFont
                    font.weight: Font.Light
                    font.pixelSize: page.isWide ? page.s(13) : 11
                    font.letterSpacing: 0.3
                    color: SmartMirrorTheme.inkSoft
                    opacity: page.dayFade
                    transform: Translate { x: page.dayShift * 0.5 }
                }
            }
        }

        // ---- TOP-RIGHT: MagicMirror2 Micro-Strip + Hero Temperature + Hairline ----
        Column {
            anchors.right: parent.right
            anchors.top: parent.top
            spacing: page.isWide ? page.s(3) : 1

            // Micro-metrics row above temp (wind + next sunrise/sunset, just like new weather.png!)
            Row {
                anchors.right: parent.right
                spacing: page.s(10)

                Row {
                    spacing: page.s(4)
                    SmartLineIcon {
                        width: page.isWide ? page.s(15) : 13
                        height: width
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "wind"
                        color: SmartMirrorTheme.inkSoft
                        strokeWidth: 1.4
                    }
                    Text {
                        text: page.activeWind.toFixed(1) + " " + SmartWeatherData.windUnit
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: SmartMirrorTheme.uiFont
                        font.weight: Font.Light
                        font.pixelSize: page.isWide ? page.s(13) : 11
                        color: SmartMirrorTheme.inkSoft
                    }
                }

                Row {
                    spacing: page.s(4)
                    SmartLineIcon {
                        width: page.isWide ? page.s(15) : 13
                        height: width
                        anchors.verticalCenter: parent.verticalCenter
                        icon: backdrop.sunUp ? "sunset" : "sunrise"
                        color: SmartMirrorTheme.inkSoft
                        strokeWidth: 1.4
                    }
                    Text {
                        text: backdrop.sunUp
                            ? (page.dayData ? page.dayData.sunset : "17:49")
                            : (page.dayData ? page.dayData.sunrise : "06:18")
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: SmartMirrorTheme.uiFont
                        font.weight: Font.Light
                        font.pixelSize: page.isWide ? page.s(13) : 11
                        color: SmartMirrorTheme.inkSoft
                    }
                }
            }

            // Hero weather icon + large thin temperature
            Row {
                anchors.right: parent.right
                spacing: page.isWide ? page.s(12) : 8

                SmartLineIcon {
                    width: page.isWide ? page.s(46) : 32
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    icon: page.activeCondition
                    isNight: !backdrop.sunUp
                    color: SmartMirrorTheme.ink
                    strokeWidth: 1.35
                    animated: page.running
                }

                Text {
                    text: (SmartWeatherData.offline ? "--" : page.displayedTemp.toFixed(1)) + SmartWeatherData.unitSym
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: SmartMirrorTheme.uiFont
                    font.weight: Font.Thin
                    font.pixelSize: page.isWide ? page.s(56) : 38
                    font.letterSpacing: -1.2
                    color: SmartMirrorTheme.ink
                    lineHeight: 0.96
                }
            }

            // Feels like + High/Low
            Text {
                anchors.right: parent.right
                text: page.dayData
                    ? ("Feels " + Math.round(page.dayData.feels_like) + "°   ·   H " + Math.round(page.dayData.max) + "°  L " + Math.round(page.dayData.min) + "°")
                    : "Feels 28°"
                font.family: SmartMirrorTheme.uiFont
                font.weight: Font.Light
                font.pixelSize: page.isWide ? page.s(13) : 11
                font.letterSpacing: 0.3
                color: SmartMirrorTheme.inkSoft
                opacity: page.dayFade
            }

            // Signature Smart Mirror thin hairline underline
            Rectangle {
                anchors.right: parent.right
                width: page.isWide ? page.s(260) : 176
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.35; color: SmartMirrorTheme.hairline }
                    GradientStop { position: 1.0; color: SmartMirrorTheme.hairlineStrong }
                }
            }
        }
    }

    // =========================================================================
    // LOWER SMOKED-MIRROR DATA ZONE (Below Horizon — Hourly + 5-Day + Telemetry)
    // =========================================================================
    Item {
        id: lowerZone
        x: page.isWide ? page.s(54) : 20
        y: Math.round(backdrop.horizonY) + (page.isWide ? page.s(30) : 22)
        width: page.width - x * 2
        height: Math.max(120, page.height - y - (page.isWide ? page.s(26) : 12))
        z: 4

        ColumnLayout {
            anchors.fill: parent
            spacing: page.isWide ? page.s(12) : 6

            // ---- 1) ULTRA-CLEAN HOURLY STRIP ----
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: page.isWide ? page.s(74) : 52

                RowLayout {
                    anchors.fill: parent
                    spacing: page.isWide ? page.s(8) : 4

                    Repeater {
                        model: {
                            const list = page.dayData && page.dayData.hourly ? page.dayData.hourly : [];
                            return page.isWide ? list.slice(0, 8) : list.slice(0, 6);
                        }

                        Item {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            readonly property real slotHour: SmartWeatherData.parseHourFloat(modelData.time, index * 3)
                            readonly property bool isNearestNow: {
                                const diff = Math.abs(slotHour - page.activeHour);
                                return diff <= 1.6 || diff >= 22.4;
                            }
                            readonly property string slotCond: modelData.cond
                                ? modelData.cond
                                : SmartWeatherData.conditionFromCode(modelData.code, modelData.icon)

                            // Hover / nearest-hour whisper highlight
                            Rectangle {
                                anchors.fill: parent
                                radius: page.s(8)
                                color: SmartMirrorTheme.toneMode === "theme"
                                    ? Qt.alpha(SmartMirrorTheme.accent, isNearestNow ? 0.12 : (hrMa.containsMouse ? 0.08 : 0.0))
                                    : Qt.rgba(1, 1, 1, isNearestNow ? 0.08 : (hrMa.containsMouse ? 0.05 : 0.0))
                                Behavior on color { ColorAnimation { duration: 160 } }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: page.isWide ? page.s(5) : 3
                                opacity: page.dayFade
                                transform: Translate { x: page.dayShift * 0.35 }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.time || "--:--"
                                    font.family: SmartMirrorTheme.uiFont
                                    font.weight: isNearestNow ? Font.Normal : Font.Light
                                    font.pixelSize: page.isWide ? page.s(12) : 10
                                    color: isNearestNow ? SmartMirrorTheme.ink : SmartMirrorTheme.inkMuted
                                }

                                SmartLineIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: page.isWide ? page.s(20) : 16
                                    height: width
                                    icon: slotCond
                                    isNight: slotHour < 6 || slotHour >= 18
                                    color: isNearestNow ? SmartMirrorTheme.ink : SmartMirrorTheme.inkSoft
                                    strokeWidth: 1.4
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: Math.round(modelData.temp) + "°"
                                    font.family: SmartMirrorTheme.uiFont
                                    font.weight: isNearestNow ? Font.Normal : Font.Light
                                    font.pixelSize: page.isWide ? page.s(14) : 12
                                    color: isNearestNow ? SmartMirrorTheme.ink : SmartMirrorTheme.inkSoft
                                }
                            }

                            // Thin bottom accent hairline on nearest hour
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                width: isNearestNow ? parent.width * 0.48 : 0
                                height: 1.2
                                color: SmartMirrorTheme.accent
                                opacity: isNearestNow ? 0.85 : 0
                                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                            }

                            MouseArea {
                                id: hrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.hourScrubbed(slotHour)
                            }
                        }
                    }
                }
            }

            // Full-width subtle hairline rule
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.10; color: SmartMirrorTheme.hairline }
                    GradientStop { position: 0.90; color: SmartMirrorTheme.hairline }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // ---- 2) SPLIT BOTTOM: 5-DAY FORECAST (LEFT) | ATMOSPHERE TELEMETRY (RIGHT) ----
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: page.isWide ? page.s(26) : 14

                // LEFT: 5-Day Interactive Forecast List
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: page.isWide ? 56 : 57
                    spacing: 0

                    // Section micro-title
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: page.isWide ? page.s(6) : 3
                        Text {
                            text: "FORECAST"
                            font.family: SmartMirrorTheme.uiFont
                            font.weight: Font.Normal
                            font.pixelSize: page.isWide ? page.s(10.5) : 9
                            font.letterSpacing: 1.8
                            color: SmartMirrorTheme.inkMuted
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "CLICK DAY TO TRANSITION"
                            visible: page.isWide
                            font.family: SmartMirrorTheme.uiFont
                            font.weight: Font.Light
                            font.pixelSize: page.s(9.5)
                            font.letterSpacing: 1.2
                            color: SmartMirrorTheme.inkFaint
                        }
                    }

                    Repeater {
                        model: page.dayCount

                        Item {
                            id: dayRow
                            required property int index
                            readonly property var d: page.forecast[index]
                            readonly property bool selected: index === page.targetDay
                            readonly property string dCond: d ? SmartWeatherData.conditionFromCode(d.code, d.icon) : "clear"

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Subtle row wash when selected or hovered
                            Rectangle {
                                anchors.fill: parent
                                radius: page.s(5)
                                color: selected
                                    ? (SmartMirrorTheme.toneMode === "theme" ? Qt.alpha(SmartMirrorTheme.accent, 0.13) : Qt.rgba(1, 1, 1, 0.09))
                                    : (dayRowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.045) : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }

                            // Crisp thin vertical active indicator
                            Rectangle {
                                x: 0
                                anchors.verticalCenter: parent.verticalCenter
                                width: 1.8
                                height: selected ? parent.height * 0.56 : 0
                                radius: 1
                                color: SmartMirrorTheme.accent
                                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: page.s(8)
                                anchors.rightMargin: page.s(6)
                                spacing: page.s(8)

                                Text {
                                    Layout.preferredWidth: page.isWide ? page.s(62) : 44
                                    text: d ? d.day : ""
                                    font.family: SmartMirrorTheme.uiFont
                                    font.weight: selected ? Font.Normal : Font.Light
                                    font.pixelSize: page.isWide ? page.s(13.5) : 11
                                    color: selected ? SmartMirrorTheme.ink : SmartMirrorTheme.inkSoft
                                }

                                SmartLineIcon {
                                    Layout.preferredWidth: page.isWide ? page.s(17) : 14
                                    Layout.preferredHeight: Layout.preferredWidth
                                    icon: dCond
                                    isNight: false
                                    color: selected ? SmartMirrorTheme.ink : SmartMirrorTheme.inkSoft
                                    strokeWidth: 1.4
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: d ? (d.desc || SmartWeatherData.conditionLabel(dCond)) : ""
                                    elide: Text.ElideRight
                                    font.family: SmartMirrorTheme.uiFont
                                    font.weight: Font.Light
                                    font.pixelSize: page.isWide ? page.s(12.5) : 10
                                    color: selected ? SmartMirrorTheme.inkSoft : SmartMirrorTheme.inkMuted
                                }

                                // Rain chance badge when > 20%
                                Text {
                                    visible: d && Number(d.pop) >= 20
                                    text: d ? (Math.round(d.pop) + "%") : ""
                                    font.family: SmartMirrorTheme.uiFont
                                    font.weight: Font.Light
                                    font.pixelSize: page.isWide ? page.s(12) : 10
                                    color: SmartMirrorTheme.toneMode === "theme" ? SmartMirrorTheme.sapphire : Qt.rgba(0.75, 0.87, 1.0, 0.72)
                                }

                                // Low / High temperatures
                                Row {
                                    spacing: page.s(6)
                                    Text {
                                        text: d ? (Math.round(d.min) + "°") : "--"
                                        font.family: SmartMirrorTheme.uiFont
                                        font.weight: Font.Light
                                        font.pixelSize: page.isWide ? page.s(13) : 11
                                        color: SmartMirrorTheme.inkMuted
                                    }
                                    Text {
                                        text: d ? (Math.round(d.max) + "°") : "--"
                                        font.family: SmartMirrorTheme.uiFont
                                        font.weight: selected ? Font.Normal : Font.Light
                                        font.pixelSize: page.isWide ? page.s(13.5) : 11
                                        color: selected ? SmartMirrorTheme.ink : SmartMirrorTheme.inkSoft
                                    }
                                }
                            }

                            MouseArea {
                                id: dayRowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.setDay(index)
                            }
                        }
                    }
                }

                // Vertical Hairline Divider
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.fillHeight: true
                    Layout.topMargin: page.s(4)
                    Layout.bottomMargin: page.s(4)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.18; color: SmartMirrorTheme.hairline }
                        GradientStop { position: 0.82; color: SmartMirrorTheme.hairline }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // RIGHT: Smart Mirror Atmosphere Telemetry
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: page.isWide ? 44 : 43
                    spacing: 0

                    // Section header + day prev/next arrows
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: page.isWide ? page.s(6) : 3

                        Text {
                            text: "ATMOSPHERE"
                            font.family: SmartMirrorTheme.uiFont
                            font.weight: Font.Normal
                            font.pixelSize: page.isWide ? page.s(10.5) : 9
                            font.letterSpacing: 1.8
                            color: SmartMirrorTheme.inkMuted
                        }
                        Item { Layout.fillWidth: true }

                        Row {
                            spacing: page.s(6)
                            Text {
                                text: "‹"
                                font.family: SmartMirrorTheme.uiFont
                                font.pixelSize: page.isWide ? page.s(16) : 13
                                color: page.targetDay > 0 ? SmartMirrorTheme.inkSoft : SmartMirrorTheme.inkFaint
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4
                                    enabled: page.targetDay > 0
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: page.setDay(page.targetDay - 1)
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: page.dayData ? page.dayData.day : "Today"
                                font.family: SmartMirrorTheme.uiFont
                                font.weight: Font.Light
                                font.pixelSize: page.isWide ? page.s(11) : 10
                                color: SmartMirrorTheme.inkSoft
                            }
                            Text {
                                text: "›"
                                font.family: SmartMirrorTheme.uiFont
                                font.pixelSize: page.isWide ? page.s(16) : 13
                                color: page.targetDay < page.dayCount - 1 ? SmartMirrorTheme.inkSoft : SmartMirrorTheme.inkFaint
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -4
                                    enabled: page.targetDay < page.dayCount - 1
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: page.setDay(page.targetDay + 1)
                                }
                            }
                        }
                    }

                    // 4 Minimal Smart-Mirror Telemetry Rows: the rows stay; only their values change (a list rebuilt
                    // on every tick would make each line grow in from nothing again every second)
                    Repeater {
                        model: 4
                        Item {
                            required property int index
                            readonly property var modelData: page.telemetryRow(index)
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                spacing: page.isWide ? page.s(5) : 3
                                opacity: page.dayFade

                                RowLayout {
                                    width: parent.width
                                    spacing: page.s(6)

                                    SmartLineIcon {
                                        Layout.preferredWidth: page.isWide ? page.s(15) : 12
                                        Layout.preferredHeight: Layout.preferredWidth
                                        icon: modelData.icon
                                        isNight: !backdrop.sunUp
                                        color: SmartMirrorTheme.inkMuted
                                        strokeWidth: 1.4
                                    }

                                    Text {
                                        text: modelData.label
                                        font.family: SmartMirrorTheme.uiFont
                                        font.weight: Font.Light
                                        font.pixelSize: page.isWide ? page.s(13) : 11
                                        color: SmartMirrorTheme.inkSoft
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: modelData.val
                                        font.family: SmartMirrorTheme.uiFont
                                        font.weight: Font.Normal
                                        font.pixelSize: page.isWide ? page.s(13) : 11
                                        color: SmartMirrorTheme.ink
                                    }
                                }

                                // Hair-thin progress hairline
                                Rectangle {
                                    width: parent.width
                                    height: 1.2
                                    color: Qt.rgba(1, 1, 1, 0.09)
                                    Rectangle {
                                        width: parent.width * Math.max(0.03, Math.min(1, modelData.ratio))
                                        height: parent.height
                                        color: SmartMirrorTheme.toneMode === "theme"
                                            ? Qt.alpha(SmartMirrorTheme.accent, 0.72)
                                            : Qt.rgba(1, 1, 1, 0.42)
                                        Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
