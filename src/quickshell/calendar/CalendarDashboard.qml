import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"
import "../reusables"
import "."

Item {
    id: window
    visible: false
    focus: true

    function s(val) {
        return Scaler.s(val);
    }

    // tall and narrow beside a side bar (the Settings > Calendar "Dashboard" style); a host can set it
    property bool vertical: { let p = Config.getSetting("bar", {}).position || "top"; return p === "left" || p === "right"; }

    implicitWidth: vertical ? window.s(380) : window.s(1080)
    implicitHeight: vertical ? window.s(980) : window.s(420)

    readonly property real panelRadius: Math.min(ThemeBackend.borderRadius, window.s(28))
    property color backgroundColor: Qt.alpha(ThemeBackend.base, 1.0)
    property real cornerTopLeft: panelRadius
    property real cornerTopRight: panelRadius
    property real cornerBottomLeft: panelRadius
    property real cornerBottomRight: panelRadius

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: window.forceActiveFocus()
    }

    Shortcut {
        sequence: "Left"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset - 1);
            } else {
                window.setWeatherView(window.targetWeatherView - 1);
            }
        }
    }

    Shortcut {
        sequence: "Right"
        enabled: window.visible
        onActivated: {
            if (calHover.hovered) {
                window.setMonthOffset(window.targetMonthOffset + 1);
            } else {
                window.setWeatherView(window.targetWeatherView + 1);
            }
        }
    }

    readonly property color timeColor: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return ThemeBackend.peach;
        if (h >= 12 && h < 17) return ThemeBackend.sapphire;
        if (h >= 17 && h < 21) return ThemeBackend.mauve;
        return ThemeBackend.blue;
    }

    readonly property color timeAccent: {
        let h = window.currentTime.getHours();
        if (h >= 5 && h < 12) return ThemeBackend.yellow;
        if (h >= 12 && h < 17) return ThemeBackend.teal;
        if (h >= 17 && h < 21) return ThemeBackend.pink;
        return ThemeBackend.mauve;
    }

    readonly property color textAccent: Qt.tint(window.timeAccent, Qt.alpha(ThemeBackend.text, 0.35))

    property bool startupComplete: false
    property real introAmbient: 0
    property real introClock: 0
    property real introCalendar: 0
    property real introWeather: 0

    function resetState() {
        introAnim.stop();
        dayFadeAnim.stop();
        calendarTransitionAnim.stop();
        startupComplete = false;
        introAmbient = 0;
        introClock = 0;
        introCalendar = 0;
        introWeather = 0;
        dayOpacity = 1.0;
        dayOffset = 0.0;
        calendarContentOpacity = 1.0;
        calendarContentOffset = 0.0;
    }

    onVisibleChanged: {
        if (visible) {
            resetState();
            forceActiveFocus();
            focusTimer.restart();
            window.gridDay = DateTime.now.getDate();
            updateCalendarGrid();
            Weather.refresh(false);
            introAnim.restart();
        } else {
            resetState();
        }
    }

    SequentialAnimation {
        id: introAnim

        ParallelAnimation {
            SequentialAnimation {
                PauseAnimation { duration: 40 }
                NumberAnimation { target: window; property: "introAmbient"; from: 0; to: 1.0; duration: 560; easing.type: Easing.OutSine }
            }

            SequentialAnimation {
                PauseAnimation { duration: 60 }
                NumberAnimation { target: window; property: "introClock"; from: 0; to: 1.0; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
            }

            SequentialAnimation {
                PauseAnimation { duration: 120 }
                NumberAnimation { target: window; property: "introCalendar"; from: 0; to: 1.0; duration: 460; easing.type: Easing.OutQuint }
            }

            SequentialAnimation {
                PauseAnimation { duration: 120 }
                NumberAnimation { target: window; property: "introWeather"; from: 0; to: 1.0; duration: 460; easing.type: Easing.OutQuint }
            }
        }
        ScriptAction { script: window.startupComplete = true }
    }

    property var currentTime: DateTime.now
    property int gridDay: -1

    property real secondPulse: 1.0
    NumberAnimation on secondPulse {
        id: pulseReset
        to: 1.0; duration: 600; easing.type: Easing.OutQuint; running: false
    }

    Connections {
        target: DateTime
        enabled: window.visible
        function onNowChanged() {
            window.secondPulse = 1.02;
            pulseReset.start();

            let day = DateTime.now.getDate();
            if (day !== window.gridDay) {
                window.gridDay = day;
                window.updateCalendarGrid();
            }
        }
    }

    readonly property var weatherData: Weather.data
    readonly property var forecastList: weatherData && weatherData.forecast ? weatherData.forecast : []
    readonly property bool offline: !!(weatherData && weatherData.offline)

    property int weatherView: 0
    property int targetWeatherView: 0
    property real dayOpacity: 1.0
    property real dayOffset: 0.0
    property int dayAnimDirection: 1

    readonly property var dayData: forecastList[weatherView] || null
    readonly property var targetDayData: forecastList[targetWeatherView] || null
    readonly property var todayData: forecastList[0] || null

    property real targetTemp: {
        if (!window.weatherData || window.offline) return 0;
        if (window.targetWeatherView === 0 && window.weatherData.current_temp !== undefined) {
            return Number(window.weatherData.current_temp);
        }
        if (window.targetDayData) return Number(window.targetDayData.max);
        return 0;
    }

    property real displayedTemp: targetTemp

    Behavior on displayedTemp {
        NumberAnimation {
            id: tempAnim
            duration: 800
            easing.type: Easing.OutQuart
        }
    }

    property bool isTempAnimating: tempAnim.running
    property color tempGlowColor: {
        if (!isTempAnimating || !window.startupComplete) return ThemeBackend.text;
        if (window.targetTemp > window.displayedTemp) return ThemeBackend.red;
        if (window.targetTemp < window.displayedTemp) return ThemeBackend.blue;
        return ThemeBackend.text;
    }

    readonly property string heroIcon: {
        if (!window.weatherData) return "";
        if (window.weatherView === 0 && window.weatherData.current_icon) return window.weatherData.current_icon;
        return window.dayData ? window.dayData.icon : "";
    }

    readonly property color heroHex: {
        if (!window.weatherData) return ThemeBackend.mauve;
        if (window.weatherView === 0 && window.weatherData.current_hex) return window.weatherData.current_hex;
        return window.dayData && window.dayData.hex ? window.dayData.hex : ThemeBackend.mauve;
    }

    readonly property string cityName: (typeof Location !== "undefined" && Location.city && Location.city !== "") ? Location.city : (window.weatherData && window.weatherData.city ? window.weatherData.city : "")

    function parseClock(str) {
        if (!str) return null;
        let clockPart = String(str).trim().split(" ");
        clockPart = clockPart.length > 1 && clockPart[0].indexOf("-") !== -1 ? clockPart[1] : clockPart[0];
        let p = clockPart.split(":");
        let h = parseInt(p[0]);
        let m = parseInt(p[1] || "0");
        if (isNaN(h) || isNaN(m)) return null;
        return { h: h, m: m };
    }

    function fmtClock(str) {
        let c = window.parseClock(str);
        if (!c) return "";
        return DateTime.format(DateTime.timeFormat.replace(/[:.]s{1,2}/, ""), new Date(2000, 0, 1, c.h, c.m));
    }

    function clockMinutes(str) {
        let c = window.parseClock(str);
        return c ? c.h * 60 + c.m : -1;
    }

    readonly property real sunriseMin: window.todayData ? window.clockMinutes(window.todayData.sunrise) : -1
    readonly property real sunsetMin: window.todayData ? window.clockMinutes(window.todayData.sunset) : -1
    readonly property bool hasSun: !window.offline && sunriseMin >= 0 && sunsetMin > sunriseMin


    SequentialAnimation {
        id: dayFadeAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "dayOpacity"; to: 0.0; duration: 180; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "dayOffset"; to: -window.s(24) * window.dayAnimDirection; duration: 180; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.weatherView = window.targetWeatherView;
                window.dayOffset = window.s(24) * window.dayAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "dayOpacity"; to: 1.0; duration: 320; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "dayOffset"; to: 0.0; duration: 320; easing.type: Easing.OutQuart }
        }
    }

    function setWeatherView(idx) {
        if (idx < 0 || idx > 4 || idx >= window.forecastList.length) return;
        if (idx === window.targetWeatherView) return;

        if (dayFadeAnim.running) {
            dayFadeAnim.stop();
            window.weatherView = window.targetWeatherView;
            window.dayOpacity = 1.0;
            window.dayOffset = 0.0;
        }

        window.dayAnimDirection = idx > window.weatherView ? 1 : -1;
        window.targetWeatherView = idx;
        dayFadeAnim.start();
    }

    property int monthOffset: 0
    property int targetMonthOffset: 0
    property string targetMonthName: ""
    ListModel { id: calendarModel }

    property real calendarContentOpacity: 1.0
    property real calendarContentOffset: 0.0
    property int calendarAnimDirection: 1

    SequentialAnimation {
        id: calendarTransitionAnim
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 0.0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: -window.s(20) * calendarAnimDirection; duration: 250; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                window.monthOffset = window.targetMonthOffset;
                window.calendarContentOffset = window.s(20) * calendarAnimDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: window; property: "calendarContentOpacity"; to: 1.0; duration: 400; easing.type: Easing.OutQuart }
            NumberAnimation { target: window; property: "calendarContentOffset"; to: 0.0; duration: 400; easing.type: Easing.OutQuart }
        }
    }

    function setMonthOffset(newOffset) {
        if (newOffset === window.targetMonthOffset) return;

        if (calendarTransitionAnim.running) {
            calendarTransitionAnim.stop();
            window.monthOffset = window.targetMonthOffset;
            window.calendarContentOpacity = 1.0;
            window.calendarContentOffset = 0.0;
        }

        window.calendarAnimDirection = newOffset > window.targetMonthOffset ? 1 : -1;
        window.targetMonthOffset = newOffset;
        calendarTransitionAnim.start();
    }

    function updateCalendarGrid() {
        let d = new Date(window.currentTime.getTime());
        d.setDate(1);
        d.setMonth(d.getMonth() + window.monthOffset);

        let targetMonth = d.getMonth();
        let targetYear = d.getFullYear();

        let actualToday = new Date();
        let isRealCurrentMonth = (actualToday.getMonth() === targetMonth && actualToday.getFullYear() === targetYear);
        let todayDate = actualToday.getDate();

        let monthLoc = Qt.locale(I18n.qtLocaleName);
        let monthName = monthLoc.standaloneMonthName(d.getMonth(), Locale.LongFormat);
        window.targetMonthName = monthName.charAt(0).toUpperCase() + monthName.slice(1) + " " + d.getFullYear();

        let firstDay = new Date(targetYear, targetMonth, 1).getDay();
        firstDay = (firstDay === 0) ? 6 : firstDay - 1;

        let daysInMonth = new Date(targetYear, targetMonth + 1, 0).getDate();
        let daysInPrevMonth = new Date(targetYear, targetMonth, 0).getDate();

        let cells = [];
        for (let i = firstDay - 1; i >= 0; i--) {
            cells.push({ dayNum: (daysInPrevMonth - i).toString(), isCurrentMonth: false, isToday: false });
        }
        for (let i = 1; i <= daysInMonth; i++) {
            cells.push({ dayNum: i.toString(), isCurrentMonth: true, isToday: (isRealCurrentMonth && i === todayDate) });
        }
        let remaining = 42 - cells.length;
        for (let i = 1; i <= remaining; i++) {
            cells.push({ dayNum: i.toString(), isCurrentMonth: false, isToday: false });
        }

        if (calendarModel.count !== cells.length) {
            calendarModel.clear();
            for (let i = 0; i < cells.length; i++) calendarModel.append(cells[i]);
            return;
        }
        for (let i = 0; i < cells.length; i++) {
            let c = cells[i];
            let cur = calendarModel.get(i);
            if (cur.dayNum !== c.dayNum) calendarModel.setProperty(i, "dayNum", c.dayNum);
            if (cur.isCurrentMonth !== c.isCurrentMonth) calendarModel.setProperty(i, "isCurrentMonth", c.isCurrentMonth);
            if (cur.isToday !== c.isToday) calendarModel.setProperty(i, "isToday", c.isToday);
        }
    }

    onMonthOffsetChanged: updateCalendarGrid()

    Component.onCompleted: {
        updateCalendarGrid();
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            Weather.refresh(false);
            introAnim.restart();
        }
    }

    component Blob: Rectangle {
        id: blob
        property real fx: 0.5
        property real fy: 0.5
        property real sizeFactor: 0.5
        property real strength: 0.01
        property real rangeX: 0
        property real rangeY: 0
        property int period: 30000

        width: parent.width * sizeFactor
        height: width
        radius: width / 2
        x: parent.width * fx - width / 2
        y: parent.height * fy - height / 2
        opacity: strength * window.introAmbient
        Behavior on color { ColorAnimation { duration: 1000 } }

        transform: Translate {
            SequentialAnimation on x {
                loops: Animation.Infinite
                running: window.visible && window.startupComplete
                NumberAnimation { from: blob.rangeX; to: -blob.rangeX; duration: blob.period; easing.type: Easing.InOutSine }
                NumberAnimation { from: -blob.rangeX; to: blob.rangeX; duration: blob.period; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on y {
                loops: Animation.Infinite
                running: window.visible && window.startupComplete
                NumberAnimation { from: -blob.rangeY; to: blob.rangeY; duration: blob.period * 0.75; easing.type: Easing.InOutSine }
                NumberAnimation { from: blob.rangeY; to: -blob.rangeY; duration: blob.period * 0.75; easing.type: Easing.InOutSine }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: window.panelRadius
        topLeftRadius: window.cornerTopLeft
        topRightRadius: window.cornerTopRight
        bottomLeftRadius: window.cornerBottomLeft
        bottomRightRadius: window.cornerBottomRight
        color: dashGlass.active ? "transparent" : window.backgroundColor
        clip: true

        // Liquid Glass, as on the classic calendar
        WallpaperBlur {
            id: dashGlass
            anchors.fill: parent
            radius: parent.radius
        }

        Blob {
            fx: 0.75; fy: 0.3; sizeFactor: 0.5; strength: 0.012
            rangeX: window.s(260); rangeY: window.s(150); period: 30000
            color: window.heroHex
        }

        Blob {
            fx: 0.25; fy: 0.7; sizeFactor: 0.6; strength: 0.01
            rangeX: window.s(220); rangeY: window.s(180); period: 37500
            color: window.timeColor
        }

        Blob {
            fx: 0.5; fy: 0.5; sizeFactor: 0.45; strength: 0.007
            rangeX: window.s(300); rangeY: window.s(240); period: 25000
            color: window.timeAccent
        }

        Text {
            anchors.centerIn: parent
            text: window.heroIcon
            font.family: ThemeBackend.fontFamily
            font.pixelSize: window.s(400)
            color: window.heroHex
            opacity: 0.015 * window.introAmbient * window.dayOpacity
            Behavior on color { ColorAnimation { duration: 1500 } }

            transform: [
                Translate {
                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: window.visible && window.startupComplete
                        NumberAnimation { to: -window.s(8); duration: 6000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 6000; easing.type: Easing.InOutSine }
                    }
                },
                Translate { x: window.dayOffset * 2 }
            ]
        }

        GridLayout {
            anchors.fill: parent
            anchors.margins: window.vertical ? window.s(20) : window.s(28)
            columns: window.vertical ? 1 : 3
            rowSpacing: window.s(16)
            columnSpacing: window.s(24)

            Rectangle {
                id: calendarRect
                Layout.row: window.vertical ? 2 : 0
                Layout.column: 0
                Layout.fillWidth: window.vertical
                Layout.preferredWidth: window.s(270)
                Layout.preferredHeight: window.vertical ? window.s(290) : window.s(330)
                Layout.alignment: Qt.AlignVCenter
                color: calendarGlass.active ? "transparent" : Qt.alpha(ThemeBackend.surface0, 0.2)
                radius: ThemeBackend.borderRadius

                opacity: window.introCalendar
                transform: Translate { x: -window.s(40) * (1.0 - window.introCalendar) }

                GlassFill {
                    id: calendarGlass
                    anchors.fill: parent
                    radius: parent.radius
                    tintColor: ThemeBackend.surface0
                    tintAmount: 0.25
                }

                HoverHandler { id: calHover }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: window.s(12)
                    anchors.bottomMargin: window.s(12)
                    anchors.leftMargin: window.s(14)
                    anchors.rightMargin: window.s(14)
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: window.s(12)
                        layoutDirection: I18n.layoutDirection

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: "󰃭"
                            iconFontSize: window.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            opacity: window.targetMonthOffset !== 0 ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            onClicked: { if (window.targetMonthOffset !== 0) window.setMonthOffset(0) }
                        }

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset - 1)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: window.targetMonthName.toUpperCase()
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: window.s(14)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: window.s(8)
                            color: ThemeBackend.text
                            horizontalAlignment: Text.AlignHCenter

                            opacity: window.calendarContentOpacity
                            transform: Translate { x: window.calendarContentOffset }
                        }

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: ThemeBackend.text
                            onClicked: window.setMonthOffset(window.targetMonthOffset + 1)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.bottomMargin: window.s(4)
                        spacing: 0
                        layoutDirection: I18n.layoutDirection

                        Repeater {
                            model: [I18n.t("calendar.days.mo"), I18n.t("calendar.days.tu"), I18n.t("calendar.days.we"), I18n.t("calendar.days.th"), I18n.t("calendar.days.fr"), I18n.t("calendar.days.sa"), I18n.t("calendar.days.su")]
                            Text {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                text: modelData
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: window.s(11.5)
                                color: ThemeBackend.overlay0
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: window.s(2)
                        columnSpacing: window.s(3)
                        layoutDirection: I18n.layoutDirection

                        opacity: window.calendarContentOpacity
                        transform: Translate { x: window.calendarContentOffset }

                        Repeater {
                            model: calendarModel
                            ClickButton {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 1
                                enabled: false
                                buttonText: dayNum
                                textFontSize: window.s(11.5)
                                cornerRadius: window.s(5)
                                horizontalPadding: 0
                                accentColor: isToday ? window.textAccent : ((ThemeBackend.liquidGlass && !isCurrentMonth) ? ThemeBackend.surface0 : "transparent")
                                textColor: ThemeBackend.liquidGlass ? (isCurrentMonth ? ThemeBackend.text : ThemeBackend.subtext0) : (isToday ? ThemeBackend.base : (isCurrentMonth ? ThemeBackend.text : ThemeBackend.surface0))
                            }
                        }
                    }
                }
            }

            Item {
                id: centralHub
                Layout.row: 0
                Layout.column: window.vertical ? 0 : 1
                Layout.fillWidth: true
                Layout.fillHeight: !window.vertical
                Layout.preferredHeight: window.vertical ? window.s(290) : -1

                opacity: window.introClock
                scale: 0.85 + (0.15 * window.introClock)
                transform: Translate { y: window.s(25) * (1.0 - window.introClock) }

                ColumnLayout {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: window.s(14)

                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Math.min(window.s(340), centralHub.width)
                        Layout.preferredHeight: window.s(190)

                        SunArc {
                            anchors.fill: parent
                            anchors.topMargin: window.vertical ? window.s(8) : -window.s(16)
                            anchors.leftMargin: window.vertical ? window.s(8) : -window.s(12)
                            anchors.rightMargin: window.vertical ? window.s(8) : -window.s(12)
                            revealed: window.introClock > 0.3
                            opacity: window.hasSun ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 400 } }
                            sunriseMin: window.sunriseMin
                            sunsetMin: window.sunsetMin
                            nowMin: window.currentTime.getHours() * 60 + window.currentTime.getMinutes()
                            sunriseText: window.todayData ? window.fmtClock(window.todayData.sunrise) : ""
                            sunsetText: window.todayData ? window.fmtClock(window.todayData.sunset) : ""
                            trackColor: Qt.alpha(window.textAccent, 0.3)
                            progressColor: window.textAccent
                            labelColor: ThemeBackend.overlay1
                        }

                        ColumnLayout {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: window.s(24)
                            spacing: 0
                            scale: 0.98 + (0.02 * window.secondPulse)

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: DateTime.time
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Black
                                font.pixelSize: {
                                    let baseSize = window.s(70);
                                    let len = (DateTime.time || "").length;
                                    if (len <= 5) return baseSize;
                                    let scaleFactor = Math.min(1.0, Math.pow(5 / len, 0.7));
                                    return Math.round(Math.max(window.s(32), baseSize * scaleFactor));
                                }
                                color: ThemeBackend.text
                                style: Text.Outline
                                styleColor: Qt.alpha(ThemeBackend.crust, 0.4)
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: DateTime.fullDate
                                font.family: ThemeBackend.fontFamily
                                font.weight: Font.Bold
                                font.pixelSize: window.s(15)
                                color: ThemeBackend.subtext0
                                opacity: 0.9
                            }
                        }
                    }

                    HourStrip {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        days: window.forecastList
                        day: window.targetWeatherView
                        count: window.vertical ? 6 : 8
                        now: window.currentTime
                        accent: window.textAccent
                        fallbackIcon: window.dayData ? window.dayData.icon : ""
                    }
                }
            }

            Item {
                id: weatherContainer
                Layout.row: window.vertical ? 1 : 0
                Layout.column: window.vertical ? 0 : 2
                Layout.fillWidth: window.vertical
                Layout.fillHeight: true
                Layout.preferredWidth: window.s(260)
                Layout.preferredHeight: window.vertical ? window.s(330) : -1

                opacity: window.introWeather
                transform: Translate { x: window.s(40) * (1.0 - window.introWeather) }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: window.s(10)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: window.s(10)
                        layoutDirection: I18n.layoutDirection

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(12)
                            accentColor: ThemeBackend.surface0
                            textColor: isHoveredOrHighlighted ? window.textAccent : ThemeBackend.overlay1
                            onClicked: window.setWeatherView(window.targetWeatherView - 1)
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: window.dayData && window.dayData.day_full ? window.dayData.day_full.toUpperCase() : I18n.t("calendar.loading")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: window.s(14)
                            fontSizeMode: Text.Fit
                            minimumPixelSize: window.s(8)
                            color: ThemeBackend.text
                        }

                        IconButton {
                            Layout.preferredWidth: window.s(28)
                            Layout.preferredHeight: window.s(28)
                            size: window.s(28)
                            cornerRadius: window.s(8)
                            buttonIcon: I18n.rtl ? "" : ""
                            iconFontSize: window.s(12)
                            accentColor: ThemeBackend.surface0
                            textColor: isHoveredOrHighlighted ? window.textAccent : ThemeBackend.overlay1
                            onClicked: window.setWeatherView(window.targetWeatherView + 1)
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.alignment: window.vertical ? Qt.AlignHCenter : Qt.AlignRight
                            text: (window.offline ? "--" : window.displayedTemp.toFixed(1)) + (Weather.unitSym || "°")
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: window.s(58)
                            color: window.tempGlowColor
                            style: Text.Outline
                            styleColor: window.isTempAnimating ? Qt.alpha(window.tempGlowColor, 0.5) : Qt.alpha(ThemeBackend.crust, 0.4)

                            Behavior on color { ColorAnimation { duration: 250 } }
                            Behavior on styleColor { ColorAnimation { duration: 250 } }
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: window.vertical ? Text.AlignHCenter : Text.AlignRight
                            text: window.cityName
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: window.s(14)
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                            visible: text !== ""
                        }

                        Text {
                            Layout.fillWidth: true
                            Layout.topMargin: window.s(2)
                            horizontalAlignment: window.vertical ? Text.AlignHCenter : Text.AlignRight
                            text: window.dayData ? window.dayData.desc : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Medium
                            font.pixelSize: window.s(13)
                            elide: Text.ElideRight
                            color: window.textAccent
                            Behavior on color { ColorAnimation { duration: 1000 } }
                            opacity: window.dayOpacity
                        }
                    }

                    Item { Layout.fillHeight: true }

                    DayStrip {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.s(70)
                        days: window.forecastList
                        selected: window.targetWeatherView
                        offline: window.offline
                        accent: window.textAccent
                        onPicked: (index) => window.setWeatherView(index)
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: window.s(8)
                        columnSpacing: window.s(8)
                        layoutDirection: I18n.layoutDirection

                        Repeater {
                            model: 4

                            ClickButton {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: window.s(40)
                                cornerRadius: window.s(9)
                                horizontalPadding: window.s(8)

                                buttonIcon: index === 0 ? "" : index === 1 ? "" : index === 2 ? "" : ""
                                buttonText: window.offline ? "--" : window.targetDayData ? (
                                    index === 0 ? window.targetDayData.wind + (Weather.unit === "imperial" ? "mph" : "m/s") :
                                    index === 1 ? window.targetDayData.humidity + "%" :
                                    index === 2 ? window.targetDayData.pop + "%" :
                                    window.targetDayData.feels_like + "°"
                                ) : ""
                                subText: index === 0 ? I18n.t("calendar.weather.wind") : index === 1 ? I18n.t("calendar.weather.humid") : index === 2 ? I18n.t("calendar.weather.rain") : I18n.t("calendar.weather.feels")

                                iconFontSize: window.s(14)
                                textFontSize: window.s(11.5)

                                accentColor: ThemeBackend.surface0
                                textColor: isHoveredOrHighlighted ? window.textAccent : ThemeBackend.overlay0
                            }
                        }
                    }
                }
            }
        }
    }
}
