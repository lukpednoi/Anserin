import QtQuick
import "../../"

// A field that records a shortcut from the keys pressed, not typed text. Click it, then press the modifiers and one
// key (SUPER + F10), or press and release SUPER + CTRL / SUPER + ALT alone. `combo` is what Save should store; Escape
// or leaving the field goes back to the saved `value`. Used by the Infinite Desktop's toggle shortcut in the Settings
// window and the Control Center's board.
Rectangle {
    id: rec

    property string value: ""
    property bool hasError: false
    property color baseColor: ThemeBackend.surface0
    property color accentColor: ThemeBackend.mauve
    property color textColor: ThemeBackend.text
    property color subTextColor: ThemeBackend.subtext0
    property int fontPixelSize: 12
    property real cornerRadius: 12

    property string pending: ""
    readonly property string combo: pending !== "" ? pending : value
    readonly property bool recording: activeFocus

    // held modifiers in this press, the most held at once, and whether a key came with them
    property var held: []
    property var peak: []
    property bool gotKey: false

    implicitWidth: 190
    implicitHeight: 32
    radius: cornerRadius
    color: baseColor
    border.width: recording || hasError ? 2 : 0
    border.color: hasError ? ThemeBackend.red : accentColor
    clip: true

    readonly property var modOrder: ["SUPER", "CTRL", "ALT", "SHIFT"]
    function modName(key) {
        if (key === Qt.Key_Meta || key === Qt.Key_Super_L || key === Qt.Key_Super_R) return "SUPER";
        if (key === Qt.Key_Control) return "CTRL";
        if (key === Qt.Key_Alt || key === Qt.Key_AltGr) return "ALT";
        if (key === Qt.Key_Shift) return "SHIFT";
        return "";
    }
    function modsOf(modifiers) {
        const out = [];
        if (modifiers & Qt.MetaModifier) out.push("SUPER");
        if (modifiers & Qt.ControlModifier) out.push("CTRL");
        if (modifiers & Qt.AltModifier) out.push("ALT");
        if (modifiers & Qt.ShiftModifier) out.push("SHIFT");
        return out;
    }
    function sorted(mods) { return modOrder.filter(m => mods.indexOf(m) !== -1); }
    // Hyprland key names (xkb keysyms); other keys are not taken
    function keyName(key) {
        if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key);
        if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key);
        if (key >= Qt.Key_F1 && key <= Qt.Key_F24) return "F" + (key - Qt.Key_F1 + 1);
        const named = {};
        named[Qt.Key_Space] = "SPACE"; named[Qt.Key_Return] = "RETURN"; named[Qt.Key_Enter] = "RETURN";
        named[Qt.Key_Tab] = "TAB"; named[Qt.Key_Backtab] = "TAB"; named[Qt.Key_Backspace] = "BACKSPACE";
        named[Qt.Key_Left] = "LEFT"; named[Qt.Key_Right] = "RIGHT"; named[Qt.Key_Up] = "UP"; named[Qt.Key_Down] = "DOWN";
        named[Qt.Key_Home] = "HOME"; named[Qt.Key_End] = "END"; named[Qt.Key_PageUp] = "PAGE_UP"; named[Qt.Key_PageDown] = "PAGE_DOWN";
        named[Qt.Key_Insert] = "INSERT"; named[Qt.Key_Delete] = "DELETE";
        return named[key] || "";
    }
    function reset() { held = []; peak = []; gotKey = false; }

    onActiveFocusChanged: { reset(); if (!activeFocus) pending = ""; }
    // saved: leave the field showing the stored shortcut
    onValueChanged: if (pending !== "" && value === pending) rec.focus = false

    // A key went down / up (also called by tests). Returns nothing; `pending` holds the recorded shortcut.
    function press(key, modifiers, autoRepeat) {
        if (key === Qt.Key_Escape) { pending = ""; rec.focus = false; return; }
        if (autoRepeat) return;
        const mod = modName(key);
        if (mod !== "") {
            if (held.indexOf(mod) === -1) held = held.concat([mod]);
            if (held.length > peak.length) peak = held.slice();
            return;
        }
        const name = keyName(key);
        const mods = sorted(modsOf(modifiers).concat(held));
        if (name === "" || mods.length === 0) return;
        gotKey = true;
        pending = mods.concat([name]).join(" + ");
    }
    function release(key, autoRepeat) {
        if (autoRepeat) return;
        const mod = modName(key);
        if (mod === "") return;
        held = held.filter(m => m !== mod);
        if (held.length > 0) return;
        const only = sorted(peak).join(" + ");
        if (!gotKey && (only === "SUPER + CTRL" || only === "SUPER + ALT")) pending = only;
        reset();
    }
    Keys.onPressed: (event) => { event.accepted = true; rec.press(event.key, event.modifiers, event.isAutoRepeat); }
    Keys.onReleased: (event) => { event.accepted = true; rec.release(event.key, event.isAutoRepeat); }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        x: 12; width: parent.width - 24
        elide: Text.ElideRight
        text: rec.recording && rec.pending === "" ? (rec.held.length ? rec.sorted(rec.held).join(" + ") + " + …" : "Press keys…") : rec.combo
        color: rec.recording && rec.pending === "" ? rec.subTextColor : rec.textColor
        font.family: ThemeBackend.fontFamily
        font.pixelSize: rec.fontPixelSize
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: rec.forceActiveFocus()
    }
}
