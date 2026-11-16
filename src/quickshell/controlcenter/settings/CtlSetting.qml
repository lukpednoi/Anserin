import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

// One real setting bound to settings.json through Config. kind: toggle | seg | slider | action.
// `tile: true` draws a toggle as a square-ish tile for 2-column grids.
Item {
    id: s
    property string kind: "toggle"
    property string key: ""
    property var def: false
    property string icon: ""
    property string title: ""
    property string hint: ""
    property var options: []          // seg labels
    property var values: []           // seg values (defaults to labels)
    property real from: 0
    property real to: 100
    property real step: 1
    property string suffix: ""
    property bool tile: false
    property string actionText: ""
    property color accent: ThemeBackend.mauve
    property bool active: true
    signal triggered()
    signal edited(var value)          // used when `key` is empty (value is managed by the page)

    readonly property var current: key !== "" ? Config.getSetting(key, def) : def
    readonly property var vals: values.length ? values : options
    readonly property int segIndex: Math.max(-1, vals.indexOf(current))
    property real sliderValue: Number(current)
    onCurrentChanged: if (kind === "slider" && !wave.dragging) sliderValue = Number(current)
    function write(v) { if (key !== "") Config.setSetting(key, v); else edited(v); }
    Timer { id: debounce; interval: 140; onTriggered: s.write(s.sliderValue) }

    // width a segmented control needs; too wide for one line -> it moves under the title
    readonly property real segEst: { let m = 0; for (let i = 0; i < options.length; i++) m = Math.max(m, String(options[i]).length); return options.length * (m * 7.8 + 30); }
    readonly property bool stacked: kind === "seg" && segEst > 236
    implicitHeight: tile ? 74 : (kind === "slider" ? 84 : (stacked ? 88 : 52))
    implicitWidth: 200

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Math.min(ThemeBackend.borderRadius, 14)
        color: s.tile && s.kind === "toggle" && s.current ? Qt.alpha(s.accent, 0.2) : (tileGlass1.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
        GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
        border.width: s.tile && s.current ? 1 : 0
        border.color: Qt.alpha(s.accent, 0.6)
        Behavior on color { ColorAnimation { duration: 180 } }
        scale: tileMa.pressed ? 0.97 : 1
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuart } }
        HoverHandler { id: hov }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: ThemeBackend.text; opacity: hov.hovered ? 0.04 : 0; Behavior on opacity { NumberAnimation { duration: 140 } } }
    }

    // ---------- tile toggle ----------
    Item {
        visible: s.tile
        anchors.fill: parent
        Rectangle { x: 12; y: 12; width: 32; height: 32; radius: 10; color: s.current ? s.accent : Qt.alpha(s.accent, 0.16)
            Behavior on color { ColorAnimation { duration: 180 } }
            Text { anchors.centerIn: parent; text: s.icon; font.family: ThemeBackend.iconFont; font.pixelSize: 16; color: s.current ? ThemeBackend.crust : s.accent } }
        Text { x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; width: parent.width - 24; elide: Text.ElideRight; text: s.title
            font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: ThemeBackend.text }
        Text { anchors.right: parent.right; anchors.rightMargin: 12; y: 16; text: s.current ? "ON" : "OFF"
            font.family: ThemeBackend.fontFamily; font.pixelSize: 10; font.weight: Font.Black; font.letterSpacing: 1.2; color: s.current ? s.accent : ThemeBackend.overlay1 }
        MouseArea { id: tileMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: s.write(!s.current) }
    }

    // ---------- list row ----------
    RowLayout {
        visible: !s.tile && !s.stacked && s.kind !== "slider"
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 10
        Rectangle { Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 9; color: Qt.alpha(s.accent, 0.16)
            Text { anchors.centerIn: parent; text: s.icon; font.family: ThemeBackend.iconFont; font.pixelSize: 15; color: s.accent } }
        ColumnLayout { Layout.fillWidth: true; spacing: 0
            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: s.title; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: ThemeBackend.text }
            Text { visible: s.hint !== ""; Layout.fillWidth: true; elide: Text.ElideRight; text: s.hint; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; color: ThemeBackend.overlay1 } }
        CtlToggle { visible: s.kind === "toggle"; checked: !!s.current; accent: s.accent; onToggled: (v) => s.write(v) }
        CtlSeg { visible: s.kind === "seg"; options: s.options; current: s.segIndex; accent: s.accent; Layout.preferredWidth: s.segEst; onPicked: (i) => s.write(s.vals[i]) }
        Rectangle { visible: s.kind === "action"; Layout.preferredHeight: 30; Layout.preferredWidth: actLab.implicitWidth + 26; radius: 15; color: actMa.pressed ? ThemeBackend.surface2 : (actMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(s.accent, 0.22))
            Text { id: actLab; anchors.centerIn: parent; text: s.actionText; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: ThemeBackend.text }
            MouseArea { id: actMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: s.triggered() } }
    }

    // ---------- stacked segment (many options) ----------
    Item {
        visible: s.stacked
        anchors.fill: parent; anchors.margins: 12
        Row { spacing: 10
            Rectangle { width: 30; height: 30; radius: 9; color: Qt.alpha(s.accent, 0.16)
                Text { anchors.centerIn: parent; text: s.icon; font.family: ThemeBackend.iconFont; font.pixelSize: 15; color: s.accent } }
            Column { anchors.verticalCenter: parent.verticalCenter
                Text { text: s.title; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: ThemeBackend.text }
                Text { visible: s.hint !== ""; text: s.hint; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; color: ThemeBackend.overlay1 } } }
        CtlSeg { anchors.bottom: parent.bottom; width: parent.width; options: s.options; current: s.segIndex; accent: s.accent; onPicked: (i) => s.write(s.vals[i]) }
    }

    // ---------- slider ----------
    Item {
        visible: s.kind === "slider"
        anchors.fill: parent; anchors.margins: 12
        Row { spacing: 10
            Rectangle { width: 30; height: 30; radius: 9; color: Qt.alpha(s.accent, 0.16)
                Text { anchors.centerIn: parent; text: s.icon; font.family: ThemeBackend.iconFont; font.pixelSize: 15; color: s.accent } }
            Column { anchors.verticalCenter: parent.verticalCenter
                Text { text: s.title; font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: ThemeBackend.text }
                Text { visible: s.hint !== ""; text: s.hint; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; color: ThemeBackend.overlay1 } } }
        Text { anchors.right: parent.right; y: 4; text: Math.round(s.sliderValue) + s.suffix; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Black; color: s.accent }
        CtlWave {
            id: wave
            anchors.bottom: parent.bottom; anchors.bottomMargin: -2; width: parent.width; height: 26
            value: s.sliderValue; from: s.from; to: s.to; step: s.step; accent: s.accent; active: s.active
            onMoved: (v) => { s.sliderValue = v; debounce.restart(); }
            onReleased: { debounce.stop(); s.write(s.sliderValue); }
        }
    }
}
