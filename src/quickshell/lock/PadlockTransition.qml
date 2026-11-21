pragma ComponentBehavior: Bound
import QtQuick
import "../"

Item {
    id: root
    property bool authenticated: false
    property real speed: 1
    property color glyphColor: "#dce6ed"
    property real glyphSize: 100
    property string stage: "ready"
    property real morph: 0
    property real objectScale: 0.08
    property real turn: 0
    property real shackleOpen: 0
    property real shrinkPulse: 0
    property real frameOpacity: 0
    property real slide: 0
    readonly property real frameScale: objectScale * (1 - 0.58 * Math.pow(Math.sin(Math.PI * shrinkPulse), 2))
    readonly property real dashboardOpacity: Math.max(0, (morph - 0.7) / 0.3)
    readonly property bool busy: opening.running || closing.running || unlocking.running
    signal unlockFinished()

    opacity: Math.max(0, 1 - morph * 4)

    function reset() {
        opening.stop(); closing.stop(); unlocking.stop();
        stage = "ready";
        morph = 0; objectScale = 0.08; turn = 0;
        shackleOpen = 0; shrinkPulse = 0; frameOpacity = 0; slide = 0;
    }
    function open() {
        if (authenticated) return;
        reset();
        opening.start();
    }
    function close() {
        if (authenticated) return;
        opening.stop(); closing.stop();
        shrinkPulse = 0;
        closing.start();
    }
    function startUnlock() {
        if (!authenticated || unlocking.running || stage === "desktop") return;
        opening.stop(); closing.stop();
        if (frameOpacity === 0) {
            morph = 0; objectScale = 1; turn = 360;
        }
        shrinkPulse = 0;
        frameOpacity = 1;
        unlocking.start();
    }
    onAuthenticatedChanged: {
        if (authenticated) Qt.callLater(startUnlock);
        else if (unlocking.running && stage !== "desktop") reset();
    }

    Repeater {
        // closed and open padlock from the Nerd Font symbols Anserin ships (the Material Symbols font this used is
        // not installed with Anserin, so the words "lock" / "lock_open" showed instead)
        model: ["\u{F033E}", "\u{F033F}"]
        Text {
            required property int index
            required property string modelData
            anchors.centerIn: parent
            text: modelData
            font.family: ThemeBackend.iconFont
            font.pixelSize: root.glyphSize
            color: root.glyphColor
            opacity: index === 0 ? 1 - root.shackleOpen : root.shackleOpen
        }
    }

    SequentialAnimation {
        id: opening
        ScriptAction { script: { root.stage = "spin"; root.frameOpacity = 1; } }
        ParallelAnimation {
            NumberAnimation { target: root; property: "turn"; to: 360; duration: 780 / root.speed; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "objectScale"; to: 1; duration: 780 / root.speed; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root.stage = "morph" }
        ParallelAnimation {
            NumberAnimation { target: root; property: "morph"; to: 1; duration: 600 / root.speed; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "shrinkPulse"; to: 1; duration: 600 / root.speed; easing.type: Easing.OutQuad }
        }
        ScriptAction { script: root.stage = "dashboard" }
    }

    SequentialAnimation {
        id: closing
        ScriptAction { script: root.stage = "closing" }
        NumberAnimation { target: root; property: "morph"; to: 0; duration: 400 / root.speed; easing.type: Easing.InOutCubic }
        ParallelAnimation {
            NumberAnimation { target: root; property: "objectScale"; to: 0.08; duration: 160 / root.speed; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "frameOpacity"; to: 0; duration: 160 / root.speed }
        }
        ScriptAction { script: root.stage = "ready" }
    }

    SequentialAnimation {
        id: unlocking
        ScriptAction { script: root.stage = "collapse" }
        ParallelAnimation {
            NumberAnimation { target: root; property: "morph"; to: 0; duration: 520 / root.speed; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "objectScale"; to: 1; duration: 520 / root.speed; easing.type: Easing.InOutCubic }
        }
        ScriptAction { script: root.stage = "unlatch" }
        NumberAnimation { target: root; property: "shackleOpen"; to: 1; duration: 320 / root.speed; easing.type: Easing.InOutCubic }
        PauseAnimation { duration: 160 / root.speed }
        ScriptAction { script: root.stage = "slide" }
        NumberAnimation { target: root; property: "slide"; to: 1; duration: 680 / root.speed; easing.type: Easing.InOutCubic }
        ScriptAction { script: { root.stage = "desktop"; root.unlockFinished(); } }
    }
}
