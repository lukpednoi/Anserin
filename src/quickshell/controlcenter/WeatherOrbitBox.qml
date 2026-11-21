import QtQuick
import "../"
import "../reusables"

// Overview weather box for the System panel: the time & date style orbit (dashed ellipse,
// hourly cards circling a large clock, faint weather icon) with the temperature in the top-right corner.
Rectangle {
    id: box

    property real cornerRadius: 20
    property bool active: false
    // weatherFace: the temperature takes the clock's place, with the place and conditions below it
    // and the weather icon in the corner. ringHalfWidth (unscaled) fixes the ring's size; 0 follows the box.
    property bool weatherFace: false
    property real ringHalfWidth: 0

    // Weather face only: the forecast day shown (0 = today), changed with the Calendar popup's animation.
    property int day: 0
    property int targetDay: 0
    property real contentOpacity: 1
    property real contentOffset: 0
    property real transitionSpin: 0
    property real transitionScale: 1
    property int dayDirection: 1
    readonly property int dayCount: (wData && wData.forecast) ? Math.min(5, wData.forecast.length) : 0
    function setDay(index) {
        if (index < 0 || index >= dayCount || index === targetDay) return;
        if (dayChange.running) {
            dayChange.stop();
            day = targetDay;
            contentOpacity = 1;
            contentOffset = 0;
            transitionSpin = 0;
            transitionScale = 1;
        }
        dayDirection = index > day ? 1 : -1;
        targetDay = index;
        dayChange.start();
    }
    SequentialAnimation {
        id: dayChange
        ParallelAnimation {
            NumberAnimation { target: box; property: "contentOpacity"; to: 0; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: box; property: "contentOffset"; to: -box.s(40) * box.dayDirection; duration: 250; easing.type: Easing.InSine }
            NumberAnimation { target: box; property: "transitionSpin"; to: 180 * box.dayDirection; duration: 300; easing.type: Easing.InCubic }
            NumberAnimation { target: box; property: "transitionScale"; to: 0.8; duration: 300; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                box.day = box.targetDay;
                box.contentOffset = box.s(40) * box.dayDirection;
                box.transitionSpin = -180 * box.dayDirection;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: box; property: "contentOpacity"; to: 1; duration: 450; easing.type: Easing.OutQuint }
            NumberAnimation { target: box; property: "contentOffset"; to: 0; duration: 450; easing.type: Easing.OutQuint }
            NumberAnimation { target: box; property: "transitionSpin"; to: 0; duration: 600; easing.type: Easing.OutBack }
            NumberAnimation { target: box; property: "transitionScale"; to: 1; duration: 500; easing.type: Easing.OutBack }
        }
    }
    property real orbitOffset: 0
    NumberAnimation on orbitOffset { from: 0; to: -360; duration: 60000; loops: Animation.Infinite; running: box.active && box.weatherFace }

    readonly property real targetTemp: {
        if (offline || !wData || !wData.forecast) return 0;
        if (targetDay === 0 && wData.current_temp !== undefined) return Number(wData.current_temp);
        return wData.forecast[targetDay] ? Number(wData.forecast[targetDay].max) : 0;
    }
    property real displayedTemp: targetTemp
    Behavior on displayedTemp { NumberAnimation { id: tempCount; duration: 800; easing.type: Easing.OutQuart } }
    readonly property color tempColor: !tempCount.running ? ThemeBackend.text
        : (targetTemp > displayedTemp ? ThemeBackend.red : (targetTemp < displayedTemp ? ThemeBackend.blue : ThemeBackend.text))

    function s(v) { return Scaler.s(v); }

    readonly property var wData: Weather.data
    readonly property var today: (wData && wData.forecast && wData.forecast[day]) ? wData.forecast[day] : null
    readonly property var hours: (today && today.hourly) ? today.hourly.slice(0, 8) : []
    readonly property bool offline: !wData || wData.offline === true
    readonly property color weatherColor: (day > 0 && today && today.hex) ? today.hex : ((wData && wData.current_hex) ? wData.current_hex : ThemeBackend.mauve)
    readonly property string weatherIcon: (day > 0 && today) ? (today.icon || "") : ((wData && wData.current_icon) ? wData.current_icon : "")
    readonly property color timeColor: {
        let h = nowHour;
        if (h >= 5 && h < 12) return ThemeBackend.peach;
        if (h >= 12 && h < 17) return ThemeBackend.sapphire;
        if (h >= 17 && h < 21) return ThemeBackend.mauve;
        return ThemeBackend.blue;
    }
    readonly property color timeAccent: {
        let h = new Date().getHours();
        if (h >= 5 && h < 12) return ThemeBackend.yellow;
        if (h >= 12 && h < 17) return ThemeBackend.teal;
        if (h >= 17 && h < 21) return ThemeBackend.pink;
        return ThemeBackend.mauve;
    }
    readonly property color textAccent: Qt.tint(timeAccent, Qt.alpha(ThemeBackend.text, 0.35))

    // Everything scales down together when the box is short (full look from 250 px of height).
    readonly property real fit: Math.max(0.45, Math.min(1.0, height / s(250)))
    readonly property real rx: ringHalfWidth > 0 ? s(ringHalfWidth) : Math.max(s(60), width * 0.36)
    readonly property real ry: ringHalfWidth > 0 ? rx * 0.46 : Math.max(s(40) * fit, Math.min(rx * 0.46, height * 0.2))
    readonly property string tempText: (offline || !Weather.isReady || Weather.currentTemp === "" ? "--" : displayedTemp.toFixed(1)) + (Weather.unitSym || "°C")
    readonly property string placeText: {
        const location = Weather.activeLocation;
        // today follows the weather now, as the icon does (the forecast's day line is one hour's snapshot)
        const desc = day === 0 && wData && wData.current_desc ? wData.current_desc : (today && today.desc ? today.desc : "");
        const parts = [location && location.city ? location.city : "", desc];
        return parts.filter(part => part !== "").join(" · ");
    }
    readonly property real cardScale: Math.max(0.35, Math.min(0.85, width / s(560))) * fit

    property real oscPhase: 0
    property real hubY: 0
    property int nowHour: new Date().getHours()

    radius: cornerRadius
    color: (tileGlass1.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
    GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
    clip: true

    NumberAnimation on oscPhase { from: 0; to: Math.PI * 2; duration: 9000; loops: Animation.Infinite; running: box.active }
    SequentialAnimation on hubY {
        loops: Animation.Infinite
        running: box.active
        NumberAnimation { to: -box.s(5); duration: 4500; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 4500; easing.type: Easing.InOutSine }
    }
    Timer {
        interval: 60000; repeat: true; running: box.active
        onTriggered: box.nowHour = new Date().getHours()
    }

    readonly property int activeHourIndex: {
        let best = -1, minDiff = 999;
        for (let i = 0; i < hours.length; i++) {
            let parts = (hours[i].time || "00:00").trim().split(" ");
            let clock = parts.length > 1 && parts[0].includes("-") ? parts[1] : parts[0];
            let h = parseInt(clock.split(":")[0]);
            if (isNaN(h)) h = 0;
            let d = Math.abs(h - nowHour);
            if (d < minDiff) { minDiff = d; best = i; }
        }
        return best;
    }

    // Faint weather icon behind the clock
    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: box.hubY
        text: box.weatherIcon
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Math.min(box.width, box.height) * 0.9
        color: box.weatherColor
        opacity: 0.025
    }

    Item {
        id: hub
        anchors.centerIn: parent
        anchors.verticalCenterOffset: box.hubY
        width: 1
        height: 1

        Canvas {
            id: orbitCanvas
            anchors.centerIn: parent
            width: box.rx * 2 + box.s(8)
            height: box.ry * 2 + box.s(8)
            opacity: 0.35
            visible: box.active
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Connections {
                target: box
                function onTextAccentChanged() { orbitCanvas.requestPaint(); }
            }
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                ctx.beginPath();
                for (var i = 0; i <= Math.PI * 2; i += 0.05) {
                    var xx = width / 2 + Math.cos(i) * box.rx;
                    var yy = height / 2 + Math.sin(i) * box.ry;
                    if (i === 0) ctx.moveTo(xx, yy); else ctx.lineTo(xx, yy);
                }
                ctx.strokeStyle = Qt.alpha(box.textAccent, 0.45);
                ctx.lineWidth = Math.max(1, box.s(2));
                ctx.lineCap = "round";
                ctx.setLineDash([box.s(4), box.s(12)]);
                ctx.stroke();
            }
        }

        Column {
            anchors.centerIn: parent
            // on the weather face the wider caption would otherwise run under the nearest hour card
            anchors.verticalCenterOffset: box.weatherFace ? -box.s(24) : 0
            z: 1
            // the temperature stays put and only counts to the new day's value
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: box.weatherFace ? box.tempText : DateTime.time
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Black
                font.pixelSize: {
                    let base = box.s(64) * box.fit;
                    let len = ((box.weatherFace ? box.tempText : DateTime.time) || "").length;
                    if (len <= 5) return base;
                    return Math.round(Math.max(box.s(28) * box.fit, base * Math.min(1.0, Math.pow(5 / len, 0.7))));
                }
                color: box.weatherFace ? box.tempColor : ThemeBackend.text
                style: Text.Outline
                styleColor: Qt.alpha(ThemeBackend.crust, 0.4)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: box.weatherFace ? box.placeText : DateTime.fullDate
                transform: Translate { x: box.contentOffset }
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Bold
                font.pixelSize: box.s(13) * Math.max(0.8, box.fit)
                color: ThemeBackend.subtext0
                opacity: 0.9 * box.contentOpacity
            }
        }

        Repeater {
            model: box.hours

            delegate: Item {
                id: card
                readonly property bool isToday: box.day === 0
                readonly property bool highlighted: isToday && index === box.activeHourIndex
                readonly property int relIdx: index - Math.max(0, box.activeHourIndex)
                readonly property real rad: (isToday ? 65 + relIdx * 30 + Math.sin(box.oscPhase + index) * 2.5
                                                     : index * (360 / Math.max(1, box.hours.length)) + box.orbitOffset) * Math.PI / 180
                                            + box.transitionSpin * Math.PI / 180
                readonly property real depth: (Math.sin(rad) + 1.0) / 2.0

                width: box.s(52)
                height: box.s(86)
                x: Math.cos(rad) * box.rx - width / 2 + box.contentOffset * 1.5
                y: Math.sin(rad) * box.ry - height / 2
                z: Math.sin(rad) * 100 + (highlighted ? 10 : 0)
                scale: box.cardScale * box.transitionScale * (highlighted ? (0.80 + 0.55 * depth) : (0.68 + 0.42 * depth))
                opacity: box.contentOpacity * (highlighted ? (0.75 + 0.25 * depth) : (0.55 + 0.45 * depth))

                Rectangle {
                    anchors.fill: parent
                    radius: Math.min(box.s(26), ThemeBackend.borderRadius * 1.75)
                    color: card.highlighted ? box.textAccent : ThemeBackend.surface0
                    border.width: 1
                    border.color: card.highlighted ? Qt.lighter(box.textAccent, 1.1) : Qt.alpha(ThemeBackend.surface1, 0.6)

                    Column {
                        anchors.centerIn: parent
                        spacing: box.s(3)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData ? modelData.time : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Bold
                            font.pixelSize: box.s(11.5)
                            color: card.highlighted ? ThemeBackend.base : ThemeBackend.overlay1
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData ? (modelData.icon || "") : ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: box.s(16.5)
                            color: card.highlighted ? ThemeBackend.base : (modelData && modelData.hex ? modelData.hex : ThemeBackend.text)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData ? (modelData.temp + "°") : ""
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: box.s(12.5)
                            color: card.highlighted ? ThemeBackend.base : ThemeBackend.text
                        }
                    }
                }
            }
        }
    }

    // The date of the day shown, with its arrows, top-right (weather face)
    Item {
        visible: box.weatherFace
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: box.s(10)
        anchors.rightMargin: box.s(10)
        width: dayRow.implicitWidth
        height: dayRow.implicitHeight
        Row {
            id: dayRow
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
                    box.nowHour;
                    const date = new Date();
                    date.setDate(date.getDate() + box.day);
                    return date.toLocaleDateString(Qt.locale(I18n.currentLang), "ddd d MMM");
                }
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Bold
                font.pixelSize: box.s(12)
                color: ThemeBackend.subtext0
                opacity: box.contentOpacity
                transform: Translate { x: box.contentOffset }
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

    // Temperature, top-right
    Text {
        visible: !box.weatherFace
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: box.s(8)
        anchors.rightMargin: box.s(12)
        text: (box.offline || !Weather.isReady || Weather.currentTemp === "" ? "--" : Number(Weather.currentTemp).toFixed(1)) + (Weather.unitSym || "°")
        font.family: ThemeBackend.fontFamily
        font.weight: Font.Black
        font.pixelSize: box.s(44) * box.fit
        color: ThemeBackend.text
        style: Text.Outline
        styleColor: Qt.alpha(ThemeBackend.crust, 0.4)
    }
}
