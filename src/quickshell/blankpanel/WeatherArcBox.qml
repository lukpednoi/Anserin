import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"
import "../calendar"
import "scene"

// The Dashboard style's top box of the left panel's Weather page, in the Classic page's place and tile: the
// animated weather scene (scene/WeatherScene.qml: sky, sun or moon, clouds, meadow, the day's weather) behind the
// temperature, place and sky and the shown day's small hourly cards, with the day picker in the corner and the
// Classic orbit's day change. It offers the orbit box's day and colour properties, so WeatherPage drives either
// box the same way. The scene's look comes from panel.weatherScene.* (Edit panel); `test` overrides its time,
// date, weather and wind for the Edit panel's test mode.
Rectangle {
    id: box

    property real cornerRadius: 20
    property bool active: false
    property var test: null                // { hour, dayOffset, condition, wind } while testing in Edit panel

    function s(v) { return Scaler.s(v); }

    readonly property var wData: Weather.data
    readonly property var forecast: (wData && wData.forecast) ? wData.forecast : []
    readonly property bool offline: !wData || wData.offline === true
    readonly property int dayCount: Math.min(5, forecast.length)

    // the day shown (0 = today), changed with the Classic orbit's fade and slide
    property int day: 0
    property int targetDay: 0
    property real dayOpacity: 1
    property real dayOffset: 0
    property int dayDirection: 1
    // the cards flow out card by card along their curve, and the new day's flow in (HourStrip.flow)
    property real stripFlow: 0
    function setDay(index) {
        if (index < 0 || index >= dayCount || index === targetDay) return;
        if (dayChange.running) {
            dayChange.stop();
            // a quick second press: the scene keeps easing on from where it is towards the newest day
            scene.animateNextChange();
            day = targetDay;
            dayOpacity = 1;
            dayOffset = 0;
            stripFlow = 0;
        }
        dayDirection = index > day ? 1 : -1;
        targetDay = index;
        dayChange.start();
    }
    SequentialAnimation {
        id: dayChange
        ParallelAnimation {
            NumberAnimation { target: box; property: "dayOpacity"; to: 0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: box; property: "dayOffset"; to: -box.s(40) * box.dayDirection; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: box; property: "stripFlow"; from: 0; to: 1; duration: 420 }
        }
        ScriptAction {
            script: {
                // the scene eases into the new day's weather and moon, in stages, instead of jumping
                scene.animateNextChange();
                box.day = box.targetDay;
                box.dayOffset = box.s(40) * box.dayDirection;
                box.stripFlow = -1;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: box; property: "dayOpacity"; to: 1; duration: 450; easing.type: Easing.OutQuint }
            NumberAnimation { target: box; property: "dayOffset"; to: 0; duration: 450; easing.type: Easing.OutQuint }
            NumberAnimation { target: box; property: "stripFlow"; to: 0; duration: 700 }
        }
    }

    // the cards' gentle sway, as the Classic orbit's cards
    property real oscPhase: 0
    NumberAnimation on oscPhase { from: 0; to: Math.PI * 2; duration: 9000; loops: Animation.Infinite; running: box.active }

    readonly property var dayData: forecast[day] || null
    readonly property var todayData: forecast[0] || null

    // the temperature stays put and counts to the new day's value, red when rising and blue when falling
    readonly property real targetTemp: {
        if (offline) return 0;
        if (targetDay === 0 && wData.current_temp !== undefined) return Number(wData.current_temp);
        return forecast[targetDay] ? Number(forecast[targetDay].max) : 0;
    }
    property real displayedTemp: targetTemp
    Behavior on displayedTemp { NumberAnimation { id: tempCount; duration: 800; easing.type: Easing.OutQuart } }
    readonly property color tempColor: !tempCount.running ? ThemeBackend.text
        : (targetTemp > displayedTemp ? ThemeBackend.red : (targetTemp < displayedTemp ? ThemeBackend.blue : ThemeBackend.text))

    readonly property color weatherColor: (day > 0 && dayData && dayData.hex) ? dayData.hex : ((wData && wData.current_hex) ? wData.current_hex : ThemeBackend.mauve)
    readonly property string weatherIcon: (day > 0 && dayData) ? (dayData.icon || "") : ((wData && wData.current_icon) ? wData.current_icon : "")
    readonly property int nowHour: DateTime.now.getHours()
    readonly property color timeColor: {
        let h = nowHour;
        if (h >= 5 && h < 12) return ThemeBackend.peach;
        if (h >= 12 && h < 17) return ThemeBackend.sapphire;
        if (h >= 17 && h < 21) return ThemeBackend.mauve;
        return ThemeBackend.blue;
    }
    readonly property color timeAccent: {
        let h = nowHour;
        if (h >= 5 && h < 12) return ThemeBackend.yellow;
        if (h >= 12 && h < 17) return ThemeBackend.teal;
        if (h >= 17 && h < 21) return ThemeBackend.pink;
        return ThemeBackend.mauve;
    }
    readonly property color textAccent: Qt.tint(timeAccent, Qt.alpha(ThemeBackend.text, 0.35))

    readonly property string cityName: (Location.city && Location.city !== "") ? Location.city : (wData && wData.city ? wData.city : "")

    // the scene's weather for a day: from the forecast's weather code (current for today), else from its icon
    function sceneCondition(d) {
        const code = d === 0 && wData && wData.current_code !== undefined ? wData.current_code
                   : (forecast[d] && forecast[d].code !== undefined ? forecast[d].code : null);
        if (code !== null && code !== undefined) {
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
        const icon = d === 0 && wData && wData.current_icon ? wData.current_icon : (forecast[d] ? forecast[d].icon : "");
        return ({ "\uf0c2": "cloudy", "\u{F0591}": "mist", "\u{F0597}": "rain", "\uf2dc": "snow", "\uf0e7": "storm" })[icon] || "clear";
    }
    readonly property var sceneSettings: Config.getSetting("panel.weatherScene", {}) || {}
    readonly property string liveCondition: sceneCondition(day)
    readonly property real liveWind: dayData ? (Number(dayData.wind) || 0) * (Weather.unit === "imperial" ? 0.447 : 1) : 0

    radius: cornerRadius
    color: (tileGlass.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
    GlassFill { id: tileGlass; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
    clip: true

    // the scene, drawn at its design size and stretched over the box
    WeatherScene {
        id: scene
        width: 565
        height: 262
        transform: Scale { xScale: box.width / 565; yScale: box.height / 262 }
        cornerRadius: box.cornerRadius * 565 / Math.max(1, box.width)
        running: box.active
        hour: box.test ? box.test.hour : DateTime.now.getHours() + DateTime.now.getMinutes() / 60
        date: {
            const d = new Date(DateTime.now.getTime());
            d.setDate(d.getDate() + (box.test ? box.test.dayOffset : box.day));
            return d;
        }
        condition: box.test ? box.test.condition : box.liveCondition
        wind: box.test ? box.test.wind : box.liveWind
        look: box.sceneSettings.look || "flat"
        moonTone: box.sceneSettings.moon || "yellow"
        intensity: box.sceneSettings.strength !== undefined ? box.sceneSettings.strength : 1
        showPath: box.sceneSettings.path === true
        pathTone: box.sceneSettings.pathTone || "theme"
        themeColor: box.textAccent
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: box.s(8)
        anchors.bottomMargin: box.s(10)
        anchors.leftMargin: box.s(14)
        anchors.rightMargin: box.s(14)
        spacing: 0

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(box.s(300), parent.width)
            Layout.fillHeight: true

            // the temperature in the clock's place, then "place · sky" on one line
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: box.s(20)
                width: parent.width - box.s(96)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: (box.offline ? "--" : box.displayedTemp.toFixed(1)) + (Weather.unitSym || "°")
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Black
                    font.pixelSize: box.s(52)
                    color: box.tempColor
                    style: Text.Outline
                    styleColor: tempCount.running ? Qt.alpha(box.tempColor, 0.5) : Qt.alpha(ThemeBackend.crust, 0.4)
                    Behavior on color { ColorAnimation { duration: 250 } }
                    Behavior on styleColor { ColorAnimation { duration: 250 } }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        id: placeText
                        width: Math.min(implicitWidth, parent.parent.width * 0.55)
                        text: box.cityName
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: box.s(13)
                        color: ThemeBackend.text
                        elide: Text.ElideRight
                        visible: text !== ""
                        // an outline as on the temperature, readable over a bright sky
                        style: Text.Outline
                        styleColor: Qt.alpha(ThemeBackend.crust, 0.4)
                    }
                    Text {
                        text: " · "
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: box.s(13)
                        color: ThemeBackend.overlay1
                        visible: placeText.visible && skyText.text !== ""
                    }
                    Text {
                        id: skyText
                        width: Math.min(implicitWidth, parent.parent.width - (placeText.visible ? placeText.width + box.s(16) : 0))
                        // today follows the weather now, as the icon and scene do
                        text: box.day === 0 && box.wData && box.wData.current_desc ? box.wData.current_desc
                            : (box.dayData ? (box.dayData.desc || "") : "")
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Medium
                        font.pixelSize: box.s(13)
                        elide: Text.ElideRight
                        color: box.textAccent
                        Behavior on color { ColorAnimation { duration: 1000 } }
                        // an outline as on the temperature, readable over a bright sky
                        style: Text.Outline
                        styleColor: Qt.alpha(ThemeBackend.crust, 0.4)
                        opacity: box.dayOpacity
                        transform: Translate { x: box.dayOffset }
                    }
                }
            }
        }

        // the shown day's hours as small swaying cards; on a day change they flow out card by card and the new day's in
        HourStrip {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: implicitWidth
            Layout.preferredHeight: implicitHeight
            days: box.forecast
            day: box.day
            oneDay: true
            count: 8
            accent: box.textAccent
            fallbackIcon: box.day === 0 && box.wData && box.wData.current_icon ? box.wData.current_icon
                : (box.dayData ? (box.dayData.icon || "") : "")
            cardScale: 0.78
            swaying: true
            swayPhase: box.oscPhase
            flow: box.stripFlow
            flowDir: box.dayDirection
        }
    }

    // The date of the day shown, with its arrows, top-right (as on the Classic orbit)
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: box.s(10)
        anchors.rightMargin: box.s(10)
        spacing: box.s(6)
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: box.s(24)
            cornerRadius: box.s(8)
            buttonIcon: I18n.rtl ? "" : ""
            iconFontSize: box.s(11)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            onClicked: box.setDay(box.targetDay - 1)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                const date = new Date(DateTime.now.getTime());
                date.setDate(date.getDate() + box.day);
                return date.toLocaleDateString(Qt.locale(I18n.currentLang), "ddd d MMM");
            }
            font.family: ThemeBackend.fontFamily
            font.weight: Font.Bold
            font.pixelSize: box.s(12)
            color: ThemeBackend.subtext0
            opacity: box.dayOpacity
            transform: Translate { x: box.dayOffset }
        }
        IconButton {
            anchors.verticalCenter: parent.verticalCenter
            size: box.s(24)
            cornerRadius: box.s(8)
            buttonIcon: I18n.rtl ? "" : ""
            iconFontSize: box.s(11)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            onClicked: box.setDay(box.targetDay + 1)
        }
    }
}
