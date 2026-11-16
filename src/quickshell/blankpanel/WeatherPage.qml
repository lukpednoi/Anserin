import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"
import "../controlcenter"
import "."

// The panel's weather page, with the Calendar popup's behaviour: the orbit (temperature in its centre, the
// forecast day in the corner), this month, the day's four readings, and the faint drifting circles behind.
// The Dashboard style puts WeatherArcBox (the animated weather scene and the day's hourly cards) in the orbit's place.
Item {
    id: root
    property bool active: false
    property bool dashboard: false
    // the Dashboard box's scene and swaying cards run while the page is shown, or always in a preview that asks
    property bool animate: active
    // the Edit panel's test values for the scene ({ hour, dayOffset, condition, wind }), null for live weather
    property var sceneTest: null
    readonly property Item box: top.item
    function s(v) { return Scaler.s(v); }
    readonly property real boxRadius: Math.min(ThemeBackend.borderRadius, s(20))
    readonly property var forecast: (box && box.wData && box.wData.forecast) ? box.wData.forecast[box.targetDay] : null

    Shortcut {
        sequence: "Left"
        enabled: root.active
        onActivated: { if (calendar.hovered) calendar.setMonth(calendar.targetOffset - 1); else if (root.box) root.box.setDay(root.box.targetDay - 1); }
    }
    Shortcut {
        sequence: "Right"
        enabled: root.active
        onActivated: { if (calendar.hovered) calendar.setMonth(calendar.targetOffset + 1); else if (root.box) root.box.setDay(root.box.targetDay + 1); }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.s(12)

        Loader {
            id: top
            Layout.fillWidth: true
            Layout.preferredHeight: root.dashboard ? root.s(262) : root.s(290)
            sourceComponent: root.dashboard ? arcBox : orbitBox
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.s(12)

            MonthCalendar {
                id: calendar
                Layout.fillWidth: true
                Layout.fillHeight: true
                cornerRadius: root.boxRadius
                accent: root.box ? root.box.textAccent : ThemeBackend.mauve
            }

            Rectangle {
                Layout.preferredWidth: root.s(138)
                Layout.fillHeight: true
                radius: root.boxRadius
                color: (tileGlass1.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
                GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }

                Column {
                    anchors.centerIn: parent
                    spacing: root.s(8)
                    Repeater {
                        model: 4
                        ClickButton {
                            required property int index
                            width: root.s(118)
                            height: root.s(42)
                            cornerRadius: root.s(9)
                            horizontalPadding: root.s(8)
                            buttonIcon: index === 0 ? "" : index === 1 ? "" : index === 2 ? "" : ""
                            buttonText: (!root.box || root.box.offline) ? "--" : root.forecast ? (
                                index === 0 ? root.forecast.wind + (Weather.unit === "imperial" ? "mph" : "m/s") :
                                index === 1 ? root.forecast.humidity + "%" :
                                index === 2 ? root.forecast.pop + "%" :
                                root.forecast.feels_like + "°"
                            ) : ""
                            subText: index === 0 ? I18n.t("calendar.weather.wind") : index === 1 ? I18n.t("calendar.weather.humid") : index === 2 ? I18n.t("calendar.weather.rain") : I18n.t("calendar.weather.feels")
                            iconFontSize: root.s(14)
                            textFontSize: root.s(11.5)
                            accentColor: ThemeBackend.surface0
                            textColor: isHoveredOrHighlighted && root.box ? root.box.textAccent : ThemeBackend.overlay0
                        }
                    }
                }
            }
        }
    }

    Component {
        id: orbitBox
        WeatherOrbitBox { active: root.active; cornerRadius: root.boxRadius; weatherFace: true; ringHalfWidth: 188 }
    }
    Component {
        id: arcBox
        WeatherArcBox { cornerRadius: root.boxRadius; active: root.animate; test: root.sceneTest }
    }

    // Faint circles drifting over the whole page, as in the Calendar popup.
    Item {
        anchors.fill: parent
        enabled: false
        clip: true

        component Drifter: Rectangle {
            id: drifter
            property real rangeX: 0
            property real rangeY: 0
            property int cycle: 60000
            radius: width / 2
            Behavior on color { ColorAnimation { duration: 1000 } }
            transform: Translate {
                SequentialAnimation on x {
                    loops: Animation.Infinite
                    running: root.active
                    NumberAnimation { from: drifter.rangeX; to: -drifter.rangeX; duration: drifter.cycle / 2; easing.type: Easing.InOutSine }
                    NumberAnimation { from: -drifter.rangeX; to: drifter.rangeX; duration: drifter.cycle / 2; easing.type: Easing.InOutSine }
                }
                SequentialAnimation on y {
                    loops: Animation.Infinite
                    running: root.active
                    NumberAnimation { from: -drifter.rangeY; to: drifter.rangeY; duration: drifter.cycle / 2; easing.type: Easing.InOutSine }
                    NumberAnimation { from: drifter.rangeY; to: -drifter.rangeY; duration: drifter.cycle / 2; easing.type: Easing.InOutSine }
                }
            }
        }

        Drifter {
            width: parent.width * 0.5; height: width
            x: parent.width * 0.75 - width / 2
            y: parent.height * 0.3 - height / 2
            opacity: 0.012
            color: root.box ? root.box.weatherColor : "transparent"
            rangeX: root.s(175); rangeY: root.s(100); cycle: 60000
        }
        Drifter {
            width: parent.width * 0.6; height: width
            x: parent.width * 0.25 - width / 2
            y: parent.height * 0.7 - height / 2
            opacity: 0.01
            color: root.box ? root.box.timeColor : "transparent"
            rangeX: root.s(150); rangeY: root.s(125); cycle: 75000
        }
        Drifter {
            width: parent.width * 0.45; height: width
            x: parent.width * 0.5 - width / 2
            y: parent.height * 0.5 - height / 2
            opacity: 0.007
            color: root.box ? root.box.timeAccent : "transparent"
            rangeX: root.s(200); rangeY: root.s(175); cycle: 50000
        }
    }
}
