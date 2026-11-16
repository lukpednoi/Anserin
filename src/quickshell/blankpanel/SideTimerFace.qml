import QtQuick
import "../"

// The Timer page's sidebar icon: a stopwatch, with the time of whatever is counting below it, laid out like
// the bar's Wi-Fi module (icon over a short label).
Item {
    id: root
    property var module: null

    function s(v) { return Scaler.s(v); }

    readonly property string runningTime: TimerState.entries.length > 0 ? TimerState.entries[0].time : ""

    implicitWidth: parent ? parent.width : s(40)
    implicitHeight: col.implicitHeight + s(24)

    Column {
        id: col
        anchors.centerIn: parent
        spacing: root.s(3)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "󰔛"
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.s(15)
            color: root.runningTime !== "" ? ThemeBackend.mauve : ThemeBackend.subtext0
            Behavior on color { ColorAnimation { duration: 200 } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.runningTime !== ""
            text: root.runningTime
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(10)
            font.bold: true
            color: ThemeBackend.text
        }
    }
}
