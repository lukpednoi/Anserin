import QtQuick
import QtQuick.Effects
import "../../"
import "."

// The Ambient Music style, drawn at the page's design size (625 x 565) and scaled by its host (MusicPopup, `host`,
// whose player, cover, lyrics, equalizer and output it shows): over a blurred, shaded wash of the cover, the cover
// fills a huge disc reaching into the top-right corner, with the song's position along its edge inside and the
// visualizer's bars outside; the song and artist sit at the top. The lyrics (word by word) or the equalizer fill
// the space under the disc, switched by the Lyrics and EQ buttons among the five round buttons in the bottom-right
// corner; the bottom row has the panel's action (Select a lyrics file, or Apply the equalizer), the sound output,
// the player (a click moves to the next one when there are several) and the time.
Item {
    id: stage

    required property Item host
    // device pixels per page unit, for drawing the cover sharp (see AmbientDial)
    property real renderScale: 1
    // how much the stage is stretched on the page, so a size can be given in the page's own pixels
    property real pageScale: 1
    readonly property var player: host.targetPlayer
    readonly property bool lyricsMode: host.sectionIndex === 1

    width: 625
    height: 565

    function fileUrl(path) { return path ? (path.startsWith("file://") || path.startsWith("http") ? path : "file://" + path) : ""; }
    // the cover shown: a new song's at once; for the same song a different cover only once it has stayed 1.5 s,
    // so a cover flashed for a moment (a browser's two players trading places while seeking) never shows
    readonly property string liveCover: host.hasTargetPlayer ? fileUrl(host.activeArtUrl) : ""
    function plainTitle(t) { return String(t || "").replace(/^\(\d+\)\s*/, "").replace(/\s+-\s+YouTube$/, "").trim(); }
    readonly property string songKey: player ? plainTitle(player.trackTitle) + "\n" + (player.trackArtist || "") : ""
    property string cover: ""
    property string coverSong: ""
    function takeCover() { coverHold.stop(); cover = liveCover; coverSong = songKey; }
    function weighCover() {
        if (liveCover === cover) { coverHold.stop(); return; }
        if (cover === "" || songKey !== coverSong) takeCover();
        else coverHold.restart();
    }
    onLiveCoverChanged: weighCover()
    onSongKeyChanged: weighCover()
    Timer { id: coverHold; interval: 1500; onTriggered: stage.takeCover() }
    readonly property real length: player ? player.length : 0

    Component.onCompleted: takeCover()

    // ---------- the wash ----------
    Rectangle { anchors.fill: parent; color: ThemeBackend.base }
    Image {
        id: wash
        anchors.fill: parent
        source: stage.cover
        sourceSize.width: 200
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        retainWhileLoading: true        // the old picture stays until the new one is ready: no blank frame
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wash
        blurEnabled: true
        blur: 1
        blurMax: 64
        saturation: 0.15
        autoPaddingEnabled: false
        opacity: stage.cover !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 500 } }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.12) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.3) }
        }
    }

    // ---------- the cover, its position line and the visualizer ----------
    AmbientDial {
        anchors.fill: parent
        opacity: stage.host.introCover
        cover: stage.cover
        position: stage.host.currentLivePosition
        duration: stage.length
        renderScale: stage.renderScale
        levels: stage.host.cavaRegistered ? Cava.barLevels : []
        eqGains: eqPanel.gains
        onSeeked: (p) => stage.host.seekTo(p)
    }

    // a name that runs round when it is wider than its place, as the other styles' titles do: a pause, then the
    // name and a copy of it slide by one length and start over (centred when it fits)
    component Marquee: Item {
        id: marquee
        property string text: ""
        property int size: 12
        property int weight: Font.Bold
        readonly property real gap: 40
        readonly property bool scrolling: label.implicitWidth > width
        property real offset: 0
        height: label.implicitHeight
        clip: true
        onTextChanged: { offset = 0; if (run.running) run.restart(); }
        Row {
            x: marquee.scrolling ? -marquee.offset : (marquee.width - label.implicitWidth) / 2
            spacing: marquee.gap
            Text {
                id: label
                text: marquee.text
                font.family: ThemeBackend.fontFamily; font.pixelSize: marquee.size; font.weight: marquee.weight; color: "white"
                style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.25)
            }
            Text {
                visible: marquee.scrolling
                text: marquee.text
                font: label.font; color: "white"
                style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.25)
            }
        }
        SequentialAnimation {
            id: run
            running: marquee.scrolling && marquee.visible && stage.host.active
            loops: Animation.Infinite
            onStopped: marquee.offset = 0
            PauseAnimation { duration: 3000 }
            NumberAnimation { target: marquee; property: "offset"; from: 0; to: label.implicitWidth + marquee.gap; duration: (label.implicitWidth + marquee.gap) * 25 }
            PropertyAction { target: marquee; property: "offset"; value: 0 }
        }
    }

    // the song and the artist at the top
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 12
        width: 360
        spacing: 1
        opacity: stage.host.introText
        Marquee {
            width: parent.width
            text: stage.player && stage.player.trackTitle ? stage.player.trackTitle : I18n.t("music.nothing_playing")
            size: 15
        }
        Marquee {
            width: parent.width
            visible: text !== ""
            opacity: 0.85
            text: stage.player ? (stage.player.trackArtist || "") : ""
            size: 11
            weight: Font.DemiBold
        }
    }

    // ---------- the lyrics or the equalizer, under the disc ----------
    property real eqMix: lyricsMode ? 0 : 1
    Behavior on eqMix { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }

    AmbientLyrics {
        x: 26
        y: 352
        width: 525
        height: stage.height - y - 62
        opacity: (1 - stage.eqMix) * stage.host.introControls
        visible: opacity > 0
        transform: Translate { y: stage.eqMix * 16 }
        // the size of the Classic style's lyrics on the page
        bigSize: stage.host.s(18) / stage.pageScale
        // each line lights up whole at its own time, which is when Lyrics moves its position
        time: Lyrics.currentPosition
        lines: Lyrics.hasLyrics ? Lyrics.wordLines : []
        message: !stage.host.hasTargetPlayer ? I18n.t("music.nothing_playing")
                 : (Lyrics.loading ? I18n.t("music.searching_lyrics") : I18n.t("music.no_lyrics"))
    }

    AmbientEqualizer {
        id: eqPanel
        x: 26
        y: 352
        width: 525
        height: stage.height - y - 62
        opacity: stage.eqMix * stage.host.introControls * (enabled ? 1 : 0.45)
        visible: stage.eqMix > 0
        enabled: stage.host.manualEqEnabled
        transform: Translate { y: (1 - stage.eqMix) * 16 }
        gains: {
            const d = stage.host.eqData || {};
            const g = [];
            for (let i = 1; i <= 10; i++) g.push(Number(d["b" + i]) || 0);
            return g;
        }
        preset: stage.host.eqData && stage.host.eqData.preset ? stage.host.eqData.preset : "Flat"
        lightningProgress: stage.host.eqLightningProgress
        lightningFade: stage.host.eqLightningFade
        accentColor: stage.host.eqAccentColor
        running: stage.host.active
        onBandSet: (band, db) => stage.host.setEqBand(band, db)
        onPresetPicked: (name) => stage.host.applyPresetOptimistically(name)
    }

    // ---------- the bottom row: action, output, player, time ----------
    Row {
        x: 26
        y: stage.height - 18 - height
        height: 30
        spacing: 8
        opacity: stage.host.introControls

        Item {
            id: action
            width: 78
            height: 30
            readonly property bool pending: !!(stage.host.eqData && stage.host.eqData.pending)
            readonly property bool usable: stage.lyricsMode ? (stage.host.hasTargetPlayer && !Lyrics.loading) : stage.host.manualEqEnabled
            opacity: usable ? 1 : 0.45
            scale: actionMa.pressed ? 0.94 : 1
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            // Select: an outline with a folder
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                opacity: 1 - stage.eqMix
                visible: opacity > 0
                color: Qt.rgba(1, 1, 1, actionMa.containsMouse ? 0.12 : 0)
                border.width: 1.2
                border.color: Qt.rgba(1, 1, 1, 0.55)
                Behavior on color { ColorAnimation { duration: 150 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "\u{F024B}"; font.family: ThemeBackend.iconFont; font.pixelSize: 12; color: "white" }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Select"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: "white" }
                }
            }
            // Apply while the equalizer has changes, Saved (filled, with a tick) once they are applied
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                opacity: stage.eqMix
                visible: opacity > 0
                color: !action.pending ? Qt.rgba(1, 1, 1, 0.88) : Qt.rgba(1, 1, 1, actionMa.containsMouse ? 0.24 : 0.16)
                Behavior on color { ColorAnimation { duration: 180 } }
                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !action.pending; text: ""; font.family: ThemeBackend.iconFont
                           font.pixelSize: 11; color: Qt.rgba(0.08, 0.09, 0.1, 1) }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: action.pending ? I18n.t("music.eq.apply") : I18n.t("music.eq.saved")
                           font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Bold
                           color: action.pending ? "white" : Qt.rgba(0.08, 0.09, 0.1, 1) }
                }
            }
            MouseArea {
                id: actionMa
                anchors.fill: parent
                enabled: action.usable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Sounds.playSfx("reusables/clickbutton/click.wav");
                    if (stage.lyricsMode) stage.host.openLyricsPicker();
                    else stage.host.applyPendingEq();
                }
            }
        }

        // the sound output, and the player it plays through (a click moves to the next player when there are several)
        Repeater {
            model: [
                { label: (stage.host.activeDeviceIcon || "\u{F04C3}") + "  " + (stage.host.activeDeviceName || I18n.t("music.speaker")), next: false },
                { label: I18n.t("music.via_source", { "source": stage.player ? (stage.player.identity || stage.player.desktopEntry || "Media") : I18n.t("music.offline") }), next: true }
            ]
            Rectangle {
                id: pill
                required property var modelData
                readonly property bool clickable: modelData.next && stage.host.playerList.length >= 2
                width: pillText.implicitWidth + 24
                height: 30
                radius: 15
                color: Qt.rgba(1, 1, 1, pillMa.pressed && pill.clickable ? 0.3 : (pillMa.containsMouse && pill.clickable ? 0.24 : 0.16))
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                scale: pillMa.pressed && pill.clickable ? 0.94 : 1
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                Text {
                    id: pillText
                    anchors.centerIn: parent
                    text: pill.modelData.label
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    color: "white"
                }
                MouseArea {
                    id: pillMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: pill.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: if (pill.clickable) {
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                        stage.host.selectPlayerByIndex((stage.host.currentPlayerIndex + 1) % stage.host.playerList.length);
                    }
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 4
            text: stage.host.formatTime(stage.host.currentLivePosition) + " / " + stage.host.formatTime(stage.length)
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: "white"
            opacity: 0.75
        }
    }

    // ---------- the five round buttons in the bottom-right corner ----------
    Column {
        x: stage.width - 18 - 40
        y: stage.height - 18 - height
        spacing: 10
        opacity: stage.host.introControls
        transform: Translate { x: 18 * (1 - stage.host.introControls) }
        AmbientButton { icon: ""; iconSize: 14; active: stage.lyricsMode; onClicked: stage.host.sectionIndex = 1 }
        AmbientButton { icon: ""; iconSize: 14; active: !stage.lyricsMode; onClicked: stage.host.sectionIndex = 0 }
        AmbientButton { icon: ""; iconSize: 13; onClicked: if (stage.player && stage.player.canGoPrevious) stage.player.previous() }
        AmbientButton { icon: stage.player && stage.player.isPlaying ? "" : ""; iconSize: 13; onClicked: MprisController.togglePlaying(stage.player) }
        AmbientButton { icon: ""; iconSize: 13; onClicked: if (stage.player && stage.player.canGoNext) stage.player.next() }
    }
}
