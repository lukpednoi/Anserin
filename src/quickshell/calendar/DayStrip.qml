import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

// The Dashboard's five-day strip: each day's name, icon, temperature range bar and high; clicking a day picks
// it and the highlight slides to it. Used by the calendar Dashboard and the left panel's Dashboard weather page.
Item {
    id: strip

    property var days: []                  // the forecast list (the range bars span all of it)
    property int selected: 0
    property bool offline: false
    property color accent: ThemeBackend.mauve
    signal picked(int index)

    readonly property real rangeMin: {
        let v = Infinity;
        for (let i = 0; i < (strip.days || []).length; i++) {
            let n = Number(strip.days[i].min);
            if (!isNaN(n) && n < v) v = n;
        }
        return v;
    }

    readonly property real rangeMax: {
        let v = -Infinity;
        for (let i = 0; i < (strip.days || []).length; i++) {
            let n = Number(strip.days[i].max);
            if (!isNaN(n) && n > v) v = n;
        }
        return v;
    }

    implicitHeight: Scaler.s(70)

    Rectangle {
        id: dayHighlight
        // rebuilt is bumped when the Repeater remakes its cells (a weather refresh keeps the count at five)
        property int rebuilt: 0
        readonly property Item currentItem: (rebuilt, dayRepeater.count > 0) ? dayRepeater.itemAt(Math.min(strip.selected, dayRepeater.count - 1)) : null
        property real targetLeft: currentItem ? currentItem.x : 0
        property real targetRight: currentItem ? currentItem.x + currentItem.width : 0
        property real actualLeft: targetLeft
        property real actualRight: targetRight
        property int prevIdx: 0
        property int curIdx: strip.selected

        onCurIdxChanged: {
            if (curIdx > prevIdx) { dayRightAnim.duration = 200; dayLeftAnim.duration = 350; }
            else if (curIdx < prevIdx) { dayLeftAnim.duration = 200; dayRightAnim.duration = 350; }
            prevIdx = curIdx;
        }

        Behavior on actualLeft { NumberAnimation { id: dayLeftAnim; duration: 250; easing.type: Easing.OutExpo } }
        Behavior on actualRight { NumberAnimation { id: dayRightAnim; duration: 250; easing.type: Easing.OutExpo } }

        readonly property bool isMoving: Math.abs(actualLeft - targetLeft) > 0.5 || Math.abs(actualRight - targetRight) > 0.5
        property real lift: (dayHighlightGlass.active && isMoving) ? 1.0 : 0.0
        Behavior on lift { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        x: actualLeft
        width: Math.max(0, actualRight - actualLeft)
        height: parent.height
        radius: Scaler.s(9)
        scale: 1.0 + 0.1 * lift
        transformOrigin: Item.Center
        visible: dayRepeater.count > 0
        color: dayHighlightGlass.active ? "transparent" : Qt.alpha(strip.accent, 0.2)
        Behavior on color { ColorAnimation { duration: 150 } }

        GlassFill {
            id: dayHighlightGlass
            anchors.fill: parent
            radius: parent.radius
            tintColor: strip.accent
            tintAmount: 0.4
            shadow: 1
            press: 0.35 + 0.65 * dayHighlight.lift
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Scaler.s(4)
        layoutDirection: I18n.layoutDirection

        Repeater {
            id: dayRepeater
            model: (strip.days || []).slice(0, 5)
            onItemAdded: dayHighlight.rebuilt++

            Rectangle {
                id: dayCell
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1

                readonly property bool selected: index === strip.selected
                readonly property real dMin: Number(modelData.min)
                readonly property real dMax: Number(modelData.max)
                readonly property bool hasRange: !strip.offline && !isNaN(dMin) && !isNaN(dMax) && isFinite(strip.rangeMin) && isFinite(strip.rangeMax)
                readonly property real span: Math.max(0.0001, strip.rangeMax - strip.rangeMin)

                radius: Scaler.s(9)
                color: (selected || dayGlass.active) ? "transparent" : (dayMa.containsMouse ? Qt.alpha(ThemeBackend.surface0, 0.6) : "transparent")
                Behavior on color { ColorAnimation { duration: 150 } }

                GlassFill {
                    id: dayGlass
                    anchors.fill: parent
                    radius: parent.radius
                    forceClear: true
                    allowed: dayMa.containsMouse && !dayCell.selected
                    tintColor: ThemeBackend.surface0
                    tintAmount: 0.2
                    tintStrength: 1.0
                    press: dayMa.pressed ? 0.8 : 0.25
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Scaler.s(4)
                    spacing: Scaler.s(2)

                    Text {
                        Layout.fillWidth: true
                        text: modelData.day || ""
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: Scaler.s(10.5)
                        color: dayCell.selected ? ThemeBackend.text : ThemeBackend.overlay1
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: modelData.icon || ""
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Scaler.s(15)
                        color: modelData.hex || ThemeBackend.text
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Scaler.s(4)
                        Layout.leftMargin: Scaler.s(4)
                        Layout.rightMargin: Scaler.s(4)

                        Rectangle {
                            anchors.fill: parent
                            radius: height / 2
                            color: Qt.alpha(ThemeBackend.overlay0, 0.3)
                        }

                        Rectangle {
                            visible: dayCell.hasRange
                            height: parent.height
                            radius: height / 2
                            x: (dayCell.dMin - strip.rangeMin) / dayCell.span * (parent.width - width)
                            width: Math.max(parent.height, (dayCell.dMax - dayCell.dMin) / dayCell.span * parent.width)
                            color: modelData.hex || strip.accent
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: dayCell.hasRange ? Math.round(dayCell.dMax) + "°" : "--"
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Bold
                        font.pixelSize: Scaler.s(10.5)
                        color: ThemeBackend.text
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                MouseArea {
                    id: dayMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.picked(index)
                }
            }
        }
    }
}
