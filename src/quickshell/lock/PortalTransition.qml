pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root
    required property url imageSource
    property bool authenticated: false
    property bool large: false
    property real speed: 1
    property string stage: "ready"
    property real morph: large ? 1 : 0
    property real frameScale: 0.08
    property real frameOpacity: 0
    property real portalReveal: 0
    property real portalOpacity: 0
    property real slide: 0
    readonly property real turn: 0
    readonly property real dashboardOpacity: Math.max(0, (morph - 0.7) / 0.3)
    readonly property bool busy: opening.running || retracting.running || unlocking.running
    signal unlockFinished()

    function reset() {
        opening.stop(); retracting.stop(); unlocking.stop();
        stage = "ready";
        morph = large ? 1 : 0; frameScale = 0.08; frameOpacity = 0;
        portalReveal = 0; portalOpacity = 0; slide = 0;
    }
    function open() {
        if (authenticated) return;
        reset();
        opening.start();
    }
    function close() {
        if (authenticated) return;
        opening.stop(); retracting.stop();
        retracting.start();
    }
    function startUnlock() {
        if (!authenticated || retracting.running || unlocking.running || stage === "desktop") return;
        opening.stop(); retracting.stop();
        retracting.start();
    }
    onAuthenticatedChanged: {
        if (authenticated) Qt.callLater(startUnlock);
        else if (busy && stage !== "desktop") reset();
    }
    onLargeChanged: reset()
    onVisibleChanged: { if (!visible) reset(); }

    Loader {
        id: artwork
        objectName: "portal-artwork"
        anchors.centerIn: parent
        width: 640
        height: 640
        transform: Scale {
            origin.x: artwork.width / 2
            origin.y: artwork.height / 2
            xScale: root.width / artwork.width
            yScale: root.height / artwork.height
        }
        scale: root.portalReveal
        opacity: root.portalOpacity
        visible: opacity > 0.001 && root.portalReveal > 0
        active: root.visible && visible
        sourceComponent: Image {
            source: root.imageSource
            sourceClipRect: Qt.rect(60, 52, 1137, 1108)
            fillMode: Image.Stretch
            smooth: true
            mipmap: true
            cache: false
            NumberAnimation on rotation {
                from: 0; to: 360; duration: 5200; loops: Animation.Infinite
                running: artwork.active
            }
        }
    }

    SequentialAnimation {
        id: opening
        ScriptAction { script: { root.stage = "spin"; root.portalOpacity = 1; } }
        ParallelAnimation {
            NumberAnimation { target: root; property: "frameScale"; to: root.large ? 0.12 : 1; duration: 780 / root.speed; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "portalReveal"; to: 1; duration: 780 / root.speed; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: root.stage = "morph" }
        ParallelAnimation {
            NumberAnimation { target: root; property: "morph"; to: 1; duration: 600 / root.speed; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "frameScale"; to: 1; duration: 600 / root.speed; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "frameOpacity"; to: 1; duration: 240 / root.speed }
        }
        NumberAnimation { target: root; property: "portalOpacity"; to: root.large ? 1 : 0; duration: 220 / root.speed }
        ScriptAction { script: root.stage = "dashboard" }
    }

    SequentialAnimation {
        id: retracting
        ScriptAction { script: { root.stage = root.authenticated ? "collapse" : "closing"; root.portalOpacity = 1; } }
        ParallelAnimation {
            NumberAnimation { target: root; property: "morph"; to: root.large ? 1 : 0; duration: 520 / root.speed; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "frameScale"; to: 0; duration: 520 / root.speed; easing.type: Easing.InOutCubic }
            NumberAnimation { target: root; property: "frameOpacity"; to: 0; duration: 520 / root.speed; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "portalReveal"; to: 1; duration: 280 / root.speed }
        }
        ScriptAction { script: root.stage = "unlatch" }
        NumberAnimation { target: root; property: "portalReveal"; to: 0; duration: 380 / root.speed; easing.type: Easing.InCubic }
        ScriptAction { script: { if (root.authenticated) unlocking.start(); else root.reset(); } }
    }

    SequentialAnimation {
        id: unlocking
        PauseAnimation { duration: 160 / root.speed }
        ScriptAction { script: root.stage = "slide" }
        NumberAnimation { target: root; property: "slide"; to: 1; duration: 680 / root.speed; easing.type: Easing.InOutCubic }
        ScriptAction { script: { root.stage = "desktop"; root.unlockFinished(); } }
    }
}
