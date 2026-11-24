import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../"

// Floating Music Bar overlay (enabled from Control → Panel → Music → "Music bar").
// Fixed-max-width transparent PanelWindow + Region mask on capsule.hitItem: width glides smoothly on the GPU
// with zero Wayland resize jitter, and the entire pill + drooping Cava wave + 1px border is one unified SDF shape!
PanelWindow {
    id: win

    signal openMusicRequested()

    readonly property string barPos: Config.getSetting("panel.musicBar.position", "top") === "bottom" ? "bottom" : "top"
    readonly property var player: MprisController.activePlayer
    readonly property bool hasSong: player !== null && String(player.trackTitle || "").trim() !== ""
    readonly property bool isPlaying: player ? (player.playbackState === MprisPlaybackState.Playing || player.isPlaying) : false
    readonly property real maxCapsuleWidth: Math.min(Scaler.s(500), (win.screen ? win.screen.width * 0.46 : Scaler.s(500)))

    property real showT: hasSong ? 1.0 : 0.0
    Behavior on showT { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

    visible: hasSong || showT > 0.01
    color: "transparent"

    WlrLayershell.namespace: "anserin-music-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    // Only the stadium pill takes pointer input; empty transparent space & drooping wave pass clicks through
    mask: Region { item: capsule.hitItem }

    anchors {
        top: barPos === "top"
        bottom: barPos === "bottom"
    }
    margins {
        top: barPos === "top" ? (ScreenEdges.thickness + Scaler.s(8)) : 0
        bottom: barPos === "bottom" ? (ScreenEdges.thickness + Scaler.s(6)) : 0
    }

    implicitWidth: maxCapsuleWidth + Scaler.s(24)
    implicitHeight: capsule.height + Scaler.s(4)

    // Strict zero-idle subscriptions for Lyrics & Cava
    property bool lyricsSub: false
    property bool cavaSub: false
    function syncSubs() {
        const wantLyrics = win.visible && win.hasSong;
        if (wantLyrics !== lyricsSub) {
            lyricsSub = wantLyrics;
            if (wantLyrics) Lyrics.subscribe();
            else Lyrics.unsubscribe();
        }
        const wantCava = win.visible && win.hasSong && win.isPlaying;
        if (wantCava !== cavaSub) {
            cavaSub = wantCava;
            if (wantCava) Cava.registerConsumer();
            else Cava.unregisterConsumer();
        }
    }
    onVisibleChanged: syncSubs()
    onHasSongChanged: syncSubs()
    onIsPlayingChanged: syncSubs()
    Component.onCompleted: syncSubs()
    Component.onDestruction: {
        if (lyricsSub) { lyricsSub = false; Lyrics.unsubscribe(); }
        if (cavaSub) { cavaSub = false; Cava.unregisterConsumer(); }
    }

    Item {
        anchors.fill: parent
        opacity: win.showT
        transform: Translate {
            y: (1 - win.showT) * Scaler.s(win.barPos === "top" ? -10 : 10)
        }

        MusicBarCapsule {
            id: capsule
            anchors.top: parent.top
            anchors.topMargin: Scaler.s(2)
            anchors.horizontalCenter: parent.horizontalCenter
            liveActive: win.visible && win.hasSong
            maxWidth: win.maxCapsuleWidth
            waveHeight: Scaler.s(22)
            onOpenMusicRequested: win.openMusicRequested()
        }
    }
}
