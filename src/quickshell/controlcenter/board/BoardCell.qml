import QtQuick
import Quickshell.Widgets
import "../../"
import "../settings"
import "../../reusables"

// One option as a cell of a board card: its icon and name on top, its control under them. Half a line, or the
// whole line for wide controls (sliders, long lists, text, facts) and for a half cell left alone in its run.
//   flood: an on/off cell is one big switch; turning it on floods it with colour from the icon outwards
//   expand: a list or number cell opens in place to the whole line, to be set there (chips / a slider); the
//           card makes room without any cell crossing another (see `place` below)
// kind: toggle | slider | seg | select | stepper | action | info | field | custom (children fill the control area)
Item {
    id: c
    visible: !hidden
    property string kind: "toggle"
    property string icon: ""
    property string title: ""
    property var value
    property var options: []              // labels
    property var values: []               // stored values (default: the labels' indexes)
    property real from: 0
    property real to: 100
    property real step: 1
    property string suffix: ""
    property int decimals: 0
    property string actionText: ""
    property string info: ""
    property string placeholder: ""
    property string valueText: ""         // shown instead of the value (e.g. a scale for a slider over indexes)
    property bool wide: false             // always take the whole line
    property bool hidden: false           // left out of the card (use this, not visible)
    property bool available: true         // false: shown dimmed and does nothing (e.g. a service not ready)
    property bool multi: false            // select: several options at once; value is the array of stored values picked
    enabled: available
    property real customHeight: 40
    default property alias custom: customArea.data
    signal picked(var value)
    signal moving(real value)
    signal released()
    signal activated()

    // set by the card
    property color accent: ThemeBackend.mauve
    property bool flood: true
    property bool expand: true
    property bool expanded: false
    property var card: null
    readonly property bool isBoardCell: true
    property real dragValue: NaN

    readonly property var stored: values.length ? values : options.map((o, i) => i)
    readonly property int optionIndex: stored.indexOf(value)
    // a multi value can arrive as a Qt list (through a var property), not a JS array: read it as a plain array
    readonly property var pickedList: {
        if (!multi || value === undefined || value === null) return [];
        if (Array.isArray(value)) return value;
        const out = [];
        for (let i = 0; i < (value.length || 0); i++) out.push(value[i]);
        return out;
    }
    function isPicked(i) { return multi ? pickedList.indexOf(stored[i]) >= 0 : i === optionIndex; }
    function pickChip(i) {
        if (!multi) { picked(stored[i]); if (card) card.toggle(c); return; }
        const current = pickedList;
        picked(isPicked(i) ? current.filter(v => v !== stored[i]) : current.concat([stored[i]]));
    }
    readonly property string label: valueText !== "" ? valueText
                                  : kind === "select" && multi ? (options.filter((o, i) => isPicked(i)).join(", ") || "None")
                                  : kind === "select" || kind === "seg" ? (optionIndex >= 0 ? String(options[optionIndex]) : String(value ?? ""))
                                  : kind === "slider" || kind === "stepper" ? Number(value).toFixed(decimals) + suffix : String(value ?? "")
    readonly property bool opens: expand && (kind === "select" || kind === "stepper")
    readonly property bool on: kind === "toggle" && !!value
    readonly property bool wantsLine: wide || kind === "slider" || kind === "field" || kind === "info" || kind === "custom"
                                      || (kind === "seg" && options.length > 2) || (kind === "select" && (!expand || expanded))
                                      || (kind === "stepper" && expanded)
    readonly property real chipsH: chipFlow.implicitHeight
    readonly property real targetHeight: kind === "custom" ? 46 + customHeight + 12
                                       : expanded ? (kind === "select" ? 50 + chipsH + 12 : 112) : (kind === "slider" ? 82 : 88)
    onTargetHeightChanged: if (card) card.relayout()
    onWantsLineChanged: if (card) card.relayout()

    // The card gives each cell its final spot (`place`) and reads its final height (targetHeight). So that no cell
    // runs over another on the way: a cell that only moves up or down, or the one being opened or shut (`pivot`),
    // glides there; a cell that changes column fades out, jumps, and fades back in once the others are in place.
    // Everything waits a moment first, so cells leaving a column are gone before the opened one grows.
    property real fullWidth: 300
    property var place: ({ x: 0, y: 0, w: 0, h: 0 })
    property bool pivot: false
    property bool settled: false
    property var last: null
    property bool jumped: false
    readonly property int pause: 90
    readonly property int glide: 300
    onPlaceChanged: relayout()
    // the first real spot is taken at once; only later moves are animated
    Component.onCompleted: relayout()
    function relayout() {
        const p = place;
        if (last && last.x === p.x && last.y === p.y && last.w === p.w && last.h === p.h) return;
        const sideways = last !== null && (Math.abs(p.x - last.x) > 0.5 || Math.abs(p.w - last.w) > 0.5);
        last = { x: p.x, y: p.y, w: p.w, h: p.h };
        if (!settled) { x = p.x; y = p.y; width = p.w; height = p.h; if (p.w > 0) settled = true; return; }
        // a cell already hopping keeps hopping: before its jump it lands on the newest place by itself, after it it
        // is still hidden or fading in, so it can be moved there at once
        if (hop.running) { if (jumped) { x = p.x; y = p.y; width = p.w; height = p.h; } return; }
        geo.stop();
        if (sideways && !pivot) { jumped = false; hop.restart(); } else geo.restart();
    }
    SequentialAnimation {
        id: geo
        PauseAnimation { duration: c.pause }
        ParallelAnimation {
            NumberAnimation { target: c; property: "x"; to: c.place.x; duration: c.glide; easing.type: Easing.OutCubic }
            NumberAnimation { target: c; property: "y"; to: c.place.y; duration: c.glide; easing.type: Easing.OutCubic }
            NumberAnimation { target: c; property: "width"; to: c.place.w; duration: c.glide; easing.type: Easing.OutCubic }
            NumberAnimation { target: c; property: "height"; to: c.place.h; duration: c.glide; easing.type: Easing.OutCubic }
        }
    }
    SequentialAnimation {
        id: hop
        NumberAnimation { target: c; property: "opacity"; to: 0; duration: c.pause; easing.type: Easing.InQuad }
        ScriptAction { script: { c.x = c.place.x; c.y = c.place.y; c.width = c.place.w; c.height = c.place.h; c.scale = 0.96; c.jumped = true; } }
        PauseAnimation { duration: c.glide - 60 }
        ParallelAnimation {
            NumberAnimation { target: c; property: "opacity"; to: 1; duration: 200 }
            NumberAnimation { target: c; property: "scale"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
    }

    ClippingRectangle {
        id: body
        anchors.fill: parent
        radius: Math.min(ThemeBackend.borderRadius, 14)
        color: Qt.alpha(ThemeBackend.text, hov.hovered ? 0.06 : 0.04)
        Behavior on color { ColorAnimation { duration: 160 } }
        scale: wholeMa.pressed ? 0.98 : 1
        Behavior on scale { NumberAnimation { duration: 120 } }
        // the flood of colour
        Rectangle {
            visible: c.flood && c.kind === "toggle"
            width: body.width * 2.6; height: width; radius: width / 2
            x: 22 - width / 2; y: 22 - height / 2
            color: Qt.alpha(c.accent, 0.24)
            scale: c.on ? 1 : 0
            Behavior on scale { NumberAnimation { duration: c.on ? 520 : 260; easing.type: c.on ? Easing.OutCubic : Easing.InCubic } }
        }
        Rectangle { anchors.fill: parent; color: Qt.alpha(c.accent, 0.08); visible: c.expanded }
    }
    HoverHandler { id: hov }
    // the whole cell is the switch (flood) or opens (expand)
    MouseArea {
        id: wholeMa
        anchors.fill: parent
        enabled: (c.flood && c.kind === "toggle") || c.opens
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (c.kind === "toggle") { Sounds.playSfx("reusables/toggle/sfx.wav"); c.picked(!c.on); }
            else if (c.card) c.card.toggle(c);
        }
    }

    Row {
        x: 12; y: 12; spacing: 8; width: parent.width - 24
        Rectangle {
            width: 22; height: 22; radius: 11; anchors.verticalCenter: parent.verticalCenter
            color: c.flood && c.on ? c.accent : "transparent"
            Behavior on color { ColorAnimation { duration: 240 } }
            Text { anchors.centerIn: parent; text: c.icon; font.family: ThemeBackend.iconFont; font.pixelSize: 14
                   color: c.flood && c.on ? ThemeBackend.crust : c.accent }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - (valueRow.visible ? valueRow.width + 40 : 30); elide: Text.ElideRight
               text: c.title; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.text }
    }
    // the value at the right of the name: sliders, and cells that open (when open)
    Row {
        id: valueRow
        anchors.right: parent.right; anchors.rightMargin: 12; y: 14; spacing: 6
        visible: c.kind === "slider" || c.opens
        Text { visible: !c.opens || c.expanded; text: c.label; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: c.accent }
        Text { visible: c.opens; text: "󰅀"; font.family: ThemeBackend.iconFont; font.pixelSize: 13; color: ThemeBackend.subtext0
               rotation: c.expanded ? 180 : 0; Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } } }
    }

    // ---------- the control ----------
    Item {
        id: control
        x: 12; width: parent.width - 24; y: 46; height: c.kind === "custom" ? c.customHeight : 30
        opacity: c.expanded ? 0 : 1
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 140 } }
        CtlToggle { visible: c.kind === "toggle"; anchors.verticalCenter: parent.verticalCenter; checked: c.on; accent: c.accent; onToggled: (v) => c.picked(v) }
        Text { visible: c.kind === "toggle"; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
               text: c.on ? "On" : "Off"; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; color: c.on ? c.accent : ThemeBackend.subtext1 }
        CtlSeg { visible: c.kind === "seg" || (c.kind === "select" && !c.expand); width: parent.width; anchors.verticalCenter: parent.verticalCenter
                 options: c.options; current: c.optionIndex; accent: c.accent; onPicked: (i) => c.picked(c.stored[i]) }
        BoardStepper { visible: c.kind === "stepper"; width: parent.width; anchors.verticalCenter: parent.verticalCenter
                       value: Number(c.value) || 0; from: c.from; to: c.to; step: c.step; suffix: c.suffix; decimals: c.decimals; accent: c.accent
                       onChanged: (v) => c.picked(v) }
        Rectangle { visible: c.kind === "select" && c.expand; width: parent.width; height: 30; radius: 15; color: selGlass.active ? "transparent" : ThemeBackend.surface0
            GlassFill { id: selGlass; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
           
            Text { x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: c.label
                   font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.text } }
        Rectangle {
            visible: c.kind === "field"; width: parent.width; height: 30; radius: Math.min(ThemeBackend.borderRadius, 10); color: ThemeBackend.surface0
            border.width: input.activeFocus ? 2 : 0; border.color: c.accent
            TextInput { id: input; x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; clip: true
                        text: String(c.value ?? ""); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.text
                        selectionColor: Qt.alpha(c.accent, 0.4); onEditingFinished: if (text !== String(c.value ?? "")) c.picked(text)
                        Keys.onEscapePressed: focus = false }
            Text { visible: input.text === "" && !input.activeFocus; x: 12; anchors.verticalCenter: parent.verticalCenter; text: c.placeholder
                   font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext1 }
        }
        Rectangle {
            visible: c.kind === "action"; anchors.verticalCenter: parent.verticalCenter
            width: actLab.implicitWidth + 28; height: 30; radius: 15
            color: actMa.pressed ? ThemeBackend.surface2 : (actMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(c.accent, 0.22))
            Behavior on color { ColorAnimation { duration: 140 } }
            Text { id: actLab; anchors.centerIn: parent; text: c.actionText; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.text }
            MouseArea { id: actMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); c.activated(); } }
        }
        Text { visible: c.kind === "info"; width: parent.width; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
               text: c.info; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext0 }
        CtlWave { visible: c.kind === "slider"; x: -8; width: parent.width + 16; height: 26; anchors.verticalCenter: parent.verticalCenter
                  value: Number(c.value) || 0; from: c.from; to: c.to; step: c.step; accent: c.accent; active: c.visible
                  onMoved: (v) => c.moving(v); onReleased: c.released() }
        Item { id: customArea; anchors.fill: parent; visible: c.kind === "custom" }
    }

    // ---------- opened in place ----------
    Item {
        x: 12; width: parent.width - 24; y: 46
        height: Math.max(0, parent.height - 58)
        opacity: c.expanded ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Flow {
            id: chipFlow
            visible: c.kind === "select"
            width: c.fullWidth - 24; spacing: 6
            Repeater {
                model: c.kind === "select" ? c.options : []
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool cur: c.isPicked(index)
                    width: Math.min(chipText.implicitWidth + 26, chipFlow.width); height: 30; radius: 15
                    color: cur ? c.accent : (tileGlass1.active ? "transparent" : chMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
                    GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Text { id: chipText; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 20); elide: Text.ElideRight
                           text: modelData; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: parent.cur
                           color: parent.cur ? ThemeBackend.crust : ThemeBackend.text }
                    MouseArea { id: chMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/switch/sfx.wav"); c.pickChip(index); } }
                }
            }
        }
        Column {
            visible: c.kind === "stepper"
            width: parent.width; spacing: 6
            // while dragging, the number follows the wave; it is saved once, on release
            BoardStepper { width: parent.width; value: isNaN(c.dragValue) ? (Number(c.value) || 0) : c.dragValue
                           from: c.from; to: c.to; step: c.step; suffix: c.suffix; decimals: c.decimals; accent: c.accent
                           onChanged: (v) => c.picked(v) }
            CtlWave { x: -8; width: parent.width + 16; height: 24; active: c.expanded
                      value: isNaN(c.dragValue) ? (Number(c.value) || 0) : c.dragValue; from: c.from; to: c.to; step: c.step; accent: c.accent
                      onMoved: (v) => c.dragValue = Math.round(v / c.step) * c.step
                      onReleased: { if (!isNaN(c.dragValue)) c.picked(c.dragValue); c.dragValue = NaN; } }
        }
    }
    // not available: dimmed (disabled semantics come from enabled)
    Rectangle { anchors.fill: parent; radius: Math.min(ThemeBackend.borderRadius, 14); visible: !c.available; color: Qt.alpha(ThemeBackend.base, 0.5) }
}
