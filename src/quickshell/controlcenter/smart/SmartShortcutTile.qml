import QtQuick

// Hold-and-Release Multi-Key Shortcut Recorder:
// Click to arm -> hold down 2 or 3 keys together (e.g. SUPER + CTRL, or CTRL + SHIFT + K) ->
// release keys and the peak held combination is saved automatically! (Press Esc alone to cancel.)
Item {
    id: st
    property string icon: "󰌌"
    property string title: "Toggle shortcut"
    property string shortcut: "SUPER + CTRL"
    property real cornerRadius: 16
    property bool darkMode: true
    property bool liquidGlass: false
    property color surface: "#171a20"
    property color surfaceHover: "#222630"
    property color accent: "#a5c8ff"
    property color accent2: "#dabde2"
    property color inkAccent: "#0c0e13"
    property color textColor: "#edf1f8"
    property color subColor: "#8d96a8"
    property string uiFont: "Noto Sans"
    property string iconFont: "Symbols Nerd Font Mono"

    signal recorded(string combo)

    property bool listening: false
    property var heldList: []      // keys currently pressed down
    property var peakList: []      // widest combination held during this gesture

    implicitWidth: 200
    width: (parent && parent.columns === undefined) ? parent.width : implicitWidth
    implicitHeight: 74
    height: implicitHeight

    readonly property var keyParts: {
        if (listening && peakList.length > 0) return peakList;
        return String(shortcut || "").split("+").map(x => x.trim()).filter(x => x !== "");
    }

    function keyName(key, text) {
        switch (key) {
        case Qt.Key_Control: return "CTRL";
        case Qt.Key_Shift:   return "SHIFT";
        case Qt.Key_Alt:
        case Qt.Key_AltGr:   return "ALT";
        case Qt.Key_Meta:
        case Qt.Key_Super_L:
        case Qt.Key_Super_R: return "SUPER";
        case Qt.Key_Space:   return "SPACE";
        case Qt.Key_Tab:     return "TAB";
        case Qt.Key_Return:
        case Qt.Key_Enter:   return "ENTER";
        case Qt.Key_Up:      return "UP";
        case Qt.Key_Down:    return "DOWN";
        case Qt.Key_Left:    return "LEFT";
        case Qt.Key_Right:   return "RIGHT";
        default:
            if (key >= Qt.Key_F1 && key <= Qt.Key_F12) return "F" + (key - Qt.Key_F1 + 1);
            if (key >= Qt.Key_A && key <= Qt.Key_Z) return String.fromCharCode(key);
            if (key >= Qt.Key_0 && key <= Qt.Key_9) return String.fromCharCode(key);
            if (text && text.trim() !== "") return text.trim().toUpperCase();
            return "";
        }
    }

    function orderedKeys(list) {
        const order = ["SUPER", "CTRL", "ALT", "SHIFT"];
        const mods = [];
        const rest = [];
        for (let i = 0; i < list.length; i++) {
            if (order.indexOf(list[i]) >= 0) mods.push(list[i]);
            else rest.push(list[i]);
        }
        mods.sort((a, b) => order.indexOf(a) - order.indexOf(b));
        return mods.concat(rest);
    }

    function arm() {
        settleTimer.stop();
        listening = true;
        heldList = [];
        peakList = [];
        keyCatcher.forceActiveFocus();
    }

    function cancel() {
        settleTimer.stop();
        listening = false;
        heldList = [];
        peakList = [];
    }

    function commitPeak() {
        settleTimer.stop();
        if (!listening || peakList.length === 0) { cancel(); return; }
        const combo = peakList.join(" + ");
        listening = false;
        heldList = [];
        peakList = [];
        recorded(combo);
    }

    // Safety net for Wayland/Hyprland when a modifier key-up (e.g. SUPER) is swallowed by the compositor
    Timer {
        id: settleTimer
        interval: 450
        repeat: false
        onTriggered: st.commitPeak()
    }

    Item {
        id: keyCatcher
        focus: st.listening
        onActiveFocusChanged: {
            if (!activeFocus && st.listening) {
                if (st.peakList.length > 0) st.commitPeak();
                else st.cancel();
            }
        }
        Keys.onPressed: (ev) => {
            if (!st.listening || ev.isAutoRepeat) { if (st.listening) ev.accepted = true; return; }
            ev.accepted = true;
            settleTimer.stop();
            if (ev.key === Qt.Key_Escape && st.heldList.length === 0) {
                st.cancel();
                return;
            }
            const next = st.heldList.slice();
            // Include active modifiers + newly pressed key
            if ((ev.modifiers & Qt.MetaModifier)    && next.indexOf("SUPER") === -1) next.push("SUPER");
            if ((ev.modifiers & Qt.ControlModifier) && next.indexOf("CTRL")  === -1) next.push("CTRL");
            if ((ev.modifiers & Qt.AltModifier)     && next.indexOf("ALT")   === -1) next.push("ALT");
            if ((ev.modifiers & Qt.ShiftModifier)   && next.indexOf("SHIFT") === -1) next.push("SHIFT");
            const k = st.keyName(ev.key, ev.text);
            if (k !== "" && next.indexOf(k) === -1) next.push(k);

            const sorted = st.orderedKeys(next);
            st.heldList = sorted;
            if (sorted.length >= st.peakList.length) {
                st.peakList = sorted.slice();
            }
        }
        Keys.onReleased: (ev) => {
            if (!st.listening || ev.isAutoRepeat) { if (st.listening) ev.accepted = true; return; }
            ev.accepted = true;
            const k = st.keyName(ev.key, ev.text);
            let rem = st.heldList.filter(x => x !== k);
            // Also drop any modifier no longer held in ev.modifiers (handles synthetic shortcuts and fast modifier releases)
            if (!(ev.modifiers & Qt.MetaModifier))    rem = rem.filter(x => x !== "SUPER");
            if (!(ev.modifiers & Qt.ControlModifier)) rem = rem.filter(x => x !== "CTRL");
            if (!(ev.modifiers & Qt.AltModifier))     rem = rem.filter(x => x !== "ALT");
            if (!(ev.modifiers & Qt.ShiftModifier))   rem = rem.filter(x => x !== "SHIFT");
            // Fallback if Shift changed a symbol's character between press and release
            if (rem.length === st.heldList.length && k !== "") {
                rem = rem.filter(x => ["SUPER", "CTRL", "ALT", "SHIFT"].indexOf(x) >= 0);
            }
            st.heldList = rem;
            // Once all held keys are released, save immediately; otherwise settle shortly in case compositor swallowed a modifier key-up
            if (rem.length === 0 && st.peakList.length > 0) {
                st.commitPeak();
            } else if (st.peakList.length > 0) {
                settleTimer.restart();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.max(10, Math.min(20, st.cornerRadius))
        color: st.liquidGlass
            ? Qt.rgba(st.surface.r, st.surface.g, st.surface.b, st.darkMode ? 0.54 : 0.66)
            : st.surface
        border.width: st.listening ? 1.6 : 1
        border.color: st.listening
            ? st.accent
            : (st.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06))
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    Row {
        anchors.left: parent.left; anchors.top: parent.top
        anchors.leftMargin: 13; anchors.topMargin: 9
        spacing: 7
        Text { text: st.icon; font.family: st.iconFont; font.pixelSize: 13; color: st.accent; anchors.verticalCenter: parent.verticalCenter }
        Text { text: st.title; font.family: st.uiFont; font.pixelSize: 11; font.weight: Font.Medium; color: st.textColor; anchors.verticalCenter: parent.verticalCenter }
    }

    Item {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.bottomMargin: 9
        height: 30

        Row {
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            visible: !st.listening || st.peakList.length > 0
            Repeater {
                model: st.keyParts
                Row {
                    required property var modelData
                    required property int index
                    readonly property bool isHeld: st.listening && st.heldList.indexOf(modelData) >= 0
                    spacing: 5
                    Text { visible: index > 0; anchors.verticalCenter: parent.verticalCenter; text: "+"; font.family: st.uiFont; font.pixelSize: 11; color: st.subColor }
                    Rectangle {
                        height: 26; width: kTxt.implicitWidth + 16; radius: 8
                        color: isHeld ? st.accent : (st.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07))
                        border.width: 1; border.color: Qt.rgba(st.accent.r, st.accent.g, st.accent.b, isHeld ? 0.9 : 0.34)
                        Text { id: kTxt; anchors.centerIn: parent; text: modelData; font.family: st.uiFont; font.pixelSize: 10; font.bold: true; color: isHeld ? st.inkAccent : st.textColor }
                    }
                }
            }
        }

        Text {
            visible: st.listening && st.peakList.length === 0
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: "Hold keys & release to save… (Esc cancel)"
            font.family: st.uiFont; font.pixelSize: 10; font.italic: true; color: st.accent
        }

        Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
            height: 28; width: recTxt.implicitWidth + 22; radius: 14
            color: st.listening ? st.accent : Qt.rgba(st.accent.r, st.accent.g, st.accent.b, 0.18)
            border.width: st.listening ? 0 : 1; border.color: Qt.rgba(st.accent.r, st.accent.g, st.accent.b, 0.38)
            Text {
                id: recTxt; anchors.centerIn: parent
                text: st.listening ? (st.peakList.length > 0 ? "Release…" : "Holding…") : "Hold keys"
                font.family: st.uiFont; font.pixelSize: 10; font.bold: true
                color: st.listening ? st.inkAccent : st.accent
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (st.listening) {
                        if (st.peakList.length > 0) st.commitPeak();
                        else st.cancel();
                    } else {
                        st.arm();
                    }
                }
            }
        }
    }
}
