import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"
import "../../blankpanel"
import "."

// Smart Music style ("m5" — Smart Glasses HUD + Liquid Mercury Wave GPU EQ + B · Harp SFX).
// Drawn at exact Left Panel Music design size (625 x 565) and scaled by MusicPopup (`host`).
Item {
    id: stage

    required property Item host
    property real renderScale: 1
    property real pageScale: 1

    width: 625
    height: 565

    // ---------- Live host / service bindings ----------
    readonly property var player: host.targetPlayer
    readonly property bool active: Boolean(stage.visible && host && host.active)
    readonly property bool playing: Boolean(player && player.isPlaying)
    readonly property bool eqOpen: host.sectionIndex === 0
    readonly property bool toneTheme: Boolean(PanelLayout.music && PanelLayout.music.m5Tone === "theme")
    readonly property real length: player ? Math.max(0, Number(player.length || 0)) : 0
    readonly property real trackPos: Math.max(0, Number(host.currentLivePosition || 0))
    readonly property real progressFrac: length > 0 ? Math.max(0, Math.min(1, trackPos / length)) : 0

    // Debounced album cover (holds briefly on same song to avoid browser seek cover flashes)
    function fileUrl(path) { return path ? (path.startsWith("file://") || path.startsWith("http") ? path : "file://" + path) : ""; }
    function plainTitle(t) { return String(t || "").replace(/^\(\d+\)\s*/, "").replace(/\s+-\s+YouTube$/, "").trim(); }
    readonly property string liveCover: host.hasTargetPlayer ? fileUrl(host.activeArtUrl) : ""
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

    // Audio volume & output cycling
    readonly property real volumePct: Audio.defaultSink && Audio.defaultSink.audio ? Math.round(Audio.defaultSink.audio.volume * 100) : 0
    readonly property bool outputMuted: Boolean(Audio.defaultSink && Audio.defaultSink.audio && Audio.defaultSink.audio.muted)
    readonly property string deviceIcon: host.activeDeviceIcon || "󰓃"
    readonly property string deviceName: host.activeDeviceName || I18n.t("music.speaker")
    readonly property string sourceLabel: player ? (player.identity || player.desktopEntry || "Media") : I18n.t("music.offline")
    readonly property string trackTitleText: player && player.trackTitle ? plainTitle(player.trackTitle) : I18n.t("music.nothing_playing")
    readonly property string trackSubText: {
        if (!player) return "";
        const a = String(player.trackArtist || "").trim();
        const b = String(player.trackAlbum || "").trim();
        if (a && b && a !== b) return a + "  ·  " + b;
        return a || b;
    }

    function cycleOutput() {
        const list = Audio.outputs || [];
        if (list.length < 2) return;
        let idx = -1;
        for (let i = 0; i < list.length; i++) {
            if (Audio.defaultSink && list[i].id === Audio.defaultSink.id) { idx = i; break; }
        }
        Audio.setDefaultOutput(list[(idx + 1) % list.length]);
        Sounds.playSfx("reusables/iconbutton/click.wav");
    }

    function stepVolume(delta) {
        if (!Audio.defaultSink) return;
        const next = Math.max(0, Math.min(100, Math.round(volumePct + delta)));
        if (next > 0 && outputMuted) Audio.toggleMute(Audio.defaultSink);
        Audio.setVolume(Audio.defaultSink, next);
        Sounds.playSfx("reusables/draggable/tick.wav", 0.6);
    }

    // ---------- Palette (Mirror white or Matugen Theme accent) ----------
    readonly property color cAccent: ThemeBackend.mauve
    readonly property color ink: toneTheme ? Qt.tint("#ffffff", Qt.rgba(cAccent.r, cAccent.g, cAccent.b, 0.22)) : "#ffffff"
    readonly property color inkSoft: Qt.rgba(ink.r, ink.g, ink.b, 0.74)
    readonly property color inkMuted: Qt.rgba(ink.r, ink.g, ink.b, 0.45)
    readonly property color hairline: toneTheme ? Qt.rgba(cAccent.r, cAccent.g, cAccent.b, 0.30) : Qt.rgba(1, 1, 1, 0.16)
    readonly property color accent: toneTheme ? cAccent : "#ffffff"
    readonly property color onAccent: {
        const lum = 0.2126 * accent.r + 0.7152 * accent.g + 0.0722 * accent.b;
        return lum > 0.52 ? "#06080c" : "#ffffff";
    }
    readonly property color glowColor: toneTheme ? ThemeBackend.mauve : Qt.tint(ThemeBackend.mauve, Qt.rgba(0.5, 0.65, 1.0, 0.35))

    // ---------- Live Lyrics ----------
    readonly property var lyricLines: Lyrics.hasLyrics ? (Lyrics.lyrics || []) : []
    readonly property int activeLyricIdx: {
        const ls = lyricLines;
        if (!ls || ls.length === 0) return -1;
        const pos = Number(Lyrics.currentPosition || stage.trackPos || 0);
        let idx = 0;
        for (let i = 0; i < ls.length; i++) {
            const t = Number(ls[i].time !== undefined ? ls[i].time : (ls[i].t || 0));
            if (pos >= t) idx = i;
        }
        return idx;
    }
    readonly property string emptyLyricsMsg: !host.hasTargetPlayer
        ? I18n.t("music.nothing_playing")
        : (Lyrics.loading ? I18n.t("music.searching_lyrics") : I18n.t("music.no_lyrics"))

    // ---------- 10-band Equalizer + GPU Shader + Ball-Impact Cascade ----------
    EqAudioEngine { id: eqAudio }

    readonly property var presets: [
        { name: "Flat",    gains: [ 0,  0,  0,  0,  0,  0,  0,  0,  0,  0] },
        { name: "Bass",    gains: [ 5,  7,  5,  2,  1,  0,  0,  0,  1,  2] },
        { name: "Treble",  gains: [-2, -1,  0,  1,  2,  3,  4,  5,  6,  6] },
        { name: "Vocal",   gains: [-2, -1,  1,  3,  5,  5,  4,  2,  1,  0] },
        { name: "Pop",     gains: [ 2,  4,  2,  0,  1,  2,  4,  2,  1,  2] },
        { name: "Rock",    gains: [ 5,  4,  2, -1, -2, -1,  2,  4,  5,  6] },
        { name: "Jazz",    gains: [ 3,  3,  1,  1,  1,  1,  2,  1,  2,  3] },
        { name: "Classic", gains: [ 0,  1,  2,  2,  2,  2,  1,  2,  3,  4] }
    ]
    readonly property var freqLabels: ["31", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]

    function readGainsFrom(obj) {
        const d = obj || {};
        const out = [];
        for (let i = 1; i <= 10; i++) out.push(Number(d["b" + i]) || 0);
        return out;
    }

    property var eqGains:      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]   // Ghost / pending target gains
    property var eqShown:      [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]   // Live liquid mercury wave
    property var eqLiveTarget: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]   // Spring target for live wave
    property var eqVel:        [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var cascadeStart: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var cascadeGoal:  [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var bandHitFired: [false, false, false, false, false, false, false, false, false, false]

    property bool presetMenuOpen: false
    property real shaderTime: 1.4
    property real cascadeProgress: -2.0
    property real cascadeFade: 0.0
    property bool cascadeActive: false
    property real dragPulse: 0.0
    property real rippleBand: -1.0
    property real rippleAge: 1.0

    readonly property bool eqPending: Boolean(host.eqData && host.eqData.pending)
    readonly property string activePresetName: (host.eqData && host.eqData.preset) ? String(host.eqData.preset) : "Flat"
    readonly property int presetIdx: {
        for (let i = 0; i < presets.length; i++) if (presets[i].name === activePresetName) return i;
        return 0;
    }
    readonly property bool customPreset: activePresetName === "Custom"

    function syncEqFromHost(snapAll) {
        const saved = readGainsFrom(host.savedEqData || host.eqData);
        const live = readGainsFrom(host.eqData);
        eqGains = live;
        if (!cascadeActive) {
            eqLiveTarget = saved;
            if (snapAll) {
                eqShown = saved.slice();
                eqVel = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
            }
        }
    }

    Connections {
        target: stage.host
        ignoreUnknownSignals: true
        function onEqDataChanged() {
            if (!eqStage.dragging && !stage.cascadeActive) stage.syncEqFromHost(false);
        }
        function onSavedEqDataChanged() {
            if (!stage.cascadeActive) stage.syncEqFromHost(false);
        }
    }

    onEqOpenChanged: presetMenuOpen = false

    Component.onCompleted: {
        takeCover();
        syncEqFromHost(true);
    }

    function launchCascade(fromGains, toGains) {
        cascadeAnim.stop();
        cascadeStart = fromGains.slice();
        cascadeGoal = toGains.slice();
        eqGains = toGains.slice();
        bandHitFired = [false, false, false, false, false, false, false, false, false, false];
        cascadeFade = 0.0;
        cascadeProgress = -1.0;
        cascadeActive = true;
        eqAudio.playSweepBed();
        cascadeAnim.restart();
    }

    function pickPreset(i) {
        if (!host.manualEqEnabled) return;
        const idx = (i + presets.length) % presets.length;
        const p = presets[idx];
        presetMenuOpen = false;
        launchCascade(eqShown.slice(), p.gains.slice());
        host.applyPresetOptimistically(p.name);
    }

    function saveEq() {
        if (!host.manualEqEnabled || !eqPending) return;
        presetMenuOpen = false;
        launchCascade(eqShown.slice(), eqGains.slice());
        host.applyPendingEq();
    }

    function toggleEq() {
        presetMenuOpen = false;
        host.sectionIndex = eqOpen ? 1 : 0;
        Sounds.playSfx("reusables/iconbutton/click.wav");
    }

    function clipRoundedRect(ctx, w, h, r) {
        ctx.beginPath();
        ctx.moveTo(r, 0);
        ctx.lineTo(w - r, 0);
        ctx.arcTo(w, 0, w, r, r);
        ctx.lineTo(w, h - r);
        ctx.arcTo(w, h, w - r, h, r);
        ctx.lineTo(r, h);
        ctx.arcTo(0, h, 0, h - r, r);
        ctx.lineTo(0, r);
        ctx.arcTo(0, 0, r, 0, r);
        ctx.closePath();
        ctx.clip();
    }

    // Exact 1.6s Ball-Impact Cascade timeline (650ms OutSine + 150ms hold + 800ms OutQuad)
    SequentialAnimation {
        id: cascadeAnim
        NumberAnimation {
            target: stage; property: "cascadeProgress"
            from: -1.0; to: 10.0
            duration: 650
            easing.type: Easing.OutSine
        }
        PauseAnimation { duration: 150 }
        NumberAnimation {
            target: stage; property: "cascadeFade"
            from: 0.0; to: 1.0
            duration: 800
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: {
                stage.cascadeActive = false;
                stage.cascadeProgress = -2.0;
                stage.cascadeFade = 0.0;
                stage.eqLiveTarget = stage.cascadeGoal.slice();
            }
        }
    }

    // 60fps Ball-Impact Firing + Liquid Spring Physics (zero-idle: strictly paused when hidden or in Lyrics mode)
    FrameAnimation {
        running: stage.active && stage.eqOpen
        onTriggered: {
            const dt = Math.min(0.033, Math.max(0.004, frameTime));
            stage.shaderTime += dt * (stage.playing ? 1.0 : 0.35);

            if (stage.cascadeActive) {
                let liveChanged = false;
                const nextLive = stage.eqLiveTarget.slice();
                const nextVHit = stage.eqVel.slice();
                const nextFired = stage.bandHitFired.slice();
                for (let i = 0; i < 10; i++) {
                    if (!nextFired[i] && stage.cascadeProgress >= i) {
                        nextFired[i] = true;
                        const delta = stage.cascadeGoal[i] - stage.cascadeStart[i];
                        const dir = delta > 0.25 ? 1 : (delta < -0.25 ? -1 : 0);
                        nextLive[i] = stage.cascadeGoal[i];
                        if (dir !== 0) {
                            nextVHit[i] += dir * (18.0 + Math.abs(delta) * 4.6);
                            stage.rippleBand = i;
                            stage.rippleAge = 0.01;
                        }
                        eqAudio.playBand(i, dir);
                        liveChanged = true;
                    }
                }
                if (liveChanged) {
                    stage.bandHitFired = nextFired;
                    stage.eqLiveTarget = nextLive;
                    stage.eqVel = nextVHit;
                }
            }

            let changed = false;
            const nextS = stage.eqShown.slice();
            const nextV = stage.eqVel.slice();
            const k = 220.0, d = 15.0;
            for (let i = 0; i < 10; i++) {
                const diff = stage.eqLiveTarget[i] - nextS[i];
                if (Math.abs(diff) > 0.003 || Math.abs(nextV[i]) > 0.003) {
                    const acc = diff * k - nextV[i] * d;
                    nextV[i] += acc * dt;
                    nextS[i] += nextV[i] * dt;
                    changed = true;
                } else if (nextS[i] !== stage.eqLiveTarget[i]) {
                    nextS[i] = stage.eqLiveTarget[i];
                    nextV[i] = 0;
                    changed = true;
                }
            }
            if (changed) {
                stage.eqShown = nextS;
                stage.eqVel = nextV;
            }

            if (stage.rippleAge < 1.0) stage.rippleAge = Math.min(1.0, stage.rippleAge + dt * 1.45);
            const dpTarget = eqStage.dragging ? 1.0 : 0.0;
            stage.dragPulse += (dpTarget - stage.dragPulse) * Math.min(1.0, dt * 12.0);
        }
    }

    property real beatPhase: 0.0
    NumberAnimation on beatPhase {
        from: 0; to: Math.PI * 2; duration: 2400; loops: Animation.Infinite
        running: stage.active && stage.playing
    }

    // ==================== EXACT 625 x 565 SMART GLASSES SURFACE ====================
    Rectangle {
        id: page
        anchors.fill: parent
        radius: Math.min(ThemeBackend.clampedBorderRadius, 22)
        color: "#06080c"
        clip: true
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.14)

        // Subtle blurred cover tint + optical sheen + right-disc halo
        Image {
            id: bgArt
            anchors.fill: parent
            source: stage.cover
            sourceSize.width: 180
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            retainWhileLoading: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: bgArt
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: 0.25
            autoPaddingEnabled: false
            opacity: stage.cover !== "" ? 0.22 : 0.0
            Behavior on opacity { NumberAnimation { duration: 450 } }
        }

        Canvas {
            anchors.fill: parent
            readonly property var _k: [stage.glowColor.toString(), stage.beatPhase, stage.toneTheme, page.radius, width, height]
            on_KChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                if (width <= 8 || height <= 8) return;
                ctx.save();
                stage.clipRoundedRect(ctx, width, height, page.radius);

                const g = ctx.createLinearGradient(0, 0, width, height);
                g.addColorStop(0.0, Qt.rgba(1, 1, 1, 0.05));
                g.addColorStop(0.45, "transparent");
                g.addColorStop(1.0, Qt.rgba(0.5, 0.7, 1.0, 0.06));
                ctx.fillStyle = g;
                ctx.fillRect(0, 0, width, height);

                const c1 = stage.glowColor;
                const pulse = 0.025 * Math.sin(stage.beatPhase);
                const dg = ctx.createRadialGradient(width * 0.88, height * 0.50, 20, width * 0.88, height * 0.50, 255);
                dg.addColorStop(0.0, Qt.rgba(c1.r, c1.g, c1.b, 0.28 + pulse));
                dg.addColorStop(1.0, "transparent");
                ctx.fillStyle = dg;
                ctx.fillRect(0, 0, width, height);
                ctx.restore();
            }
        }

        // ==================== RIGHT ARCHITECTURAL VINYL DISC (340 x 340) ====================
        Item {
            id: discWrap
            x: parent.width - 196
            y: (parent.height - 340) * 0.5
            width: 340; height: 340
            opacity: stage.host.introCover

            Canvas {
                anchors.centerIn: parent; width: 372; height: 372
                readonly property var _k: [stage.progressFrac, stage.playing, stage.accent.toString(), stage.toneTheme]
                on_KChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const cx = width * 0.5, cy = height * 0.5, R = 178;
                    ctx.beginPath(); ctx.arc(cx, cy, R, 0, Math.PI * 2);
                    ctx.lineWidth = 1.2; ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.14); ctx.stroke();

                    if (stage.progressFrac > 0.002) {
                        ctx.beginPath();
                        ctx.arc(cx, cy, R, -Math.PI * 0.5, -Math.PI * 0.5 - Math.PI * stage.progressFrac, true);
                        ctx.lineWidth = 2.6; ctx.lineCap = "round"; ctx.strokeStyle = stage.accent; ctx.stroke();
                    }
                }
            }

            Item {
                id: cDisc
                anchors.fill: parent
                RotationAnimation on rotation {
                    from: 0; to: 360; duration: 14000; loops: Animation.Infinite
                    running: stage.active && stage.playing
                }
                Rectangle { anchors.fill: parent; radius: 170; color: "#11151e" }
                Rectangle { id: cMask; anchors.fill: parent; radius: 170; visible: false; layer.enabled: true }
                Image {
                    id: cImg
                    anchors.fill: parent
                    visible: false
                    source: stage.cover
                    sourceSize.width: Math.round(340 * Math.max(1, stage.renderScale))
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    retainWhileLoading: true
                    smooth: true
                }
                MultiEffect { anchors.fill: parent; source: cImg; maskEnabled: true; maskSource: cMask; visible: cImg.status === Image.Ready }
                Text {
                    visible: cImg.status !== Image.Ready
                    anchors.centerIn: parent
                    text: "󰎈"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: 64
                    color: Qt.rgba(1, 1, 1, 0.16)
                }
                Rectangle { anchors.fill: parent; radius: 170; color: "transparent"; border.width: 1.6; border.color: Qt.rgba(1, 1, 1, 0.28) }
                Rectangle { anchors.centerIn: parent; width: 250; height: 250; radius: 125; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10) }
                Rectangle { anchors.centerIn: parent; width: 170; height: 170; radius: 85; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.10) }
                Rectangle { anchors.centerIn: parent; width: 58; height: 58; radius: 29; color: "#06080c"; border.width: 1.8; border.color: stage.accent }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (stage.player) {
                        Sounds.playSfx(stage.playing ? "reusables/toggle/sfx.wav" : "reusables/switch/sfx.wav");
                        MprisController.togglePlaying(stage.player);
                    }
                }
            }
        }

        // ==================== LEFT SMART GLASSES AR HUD STACK ====================
        ColumnLayout {
            id: hudCol
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.margins: 28
            width: 376
            spacing: 14

            // 1. HERO ELAPSED CLOCK + HAIRLINE SCRUBBER + TRACK INFO
            Column {
                Layout.fillWidth: true; Layout.fillHeight: false; spacing: 4
                opacity: stage.host.introText

                Row {
                    spacing: 6
                    Text {
                        text: stage.host.formatTime(stage.trackPos)
                        font.family: ThemeBackend.fontFamily; font.pixelSize: 44; font.weight: Font.ExtraLight
                        font.letterSpacing: -1.2; color: stage.ink; lineHeight: 0.95
                    }
                    Text {
                        text: "/ " + stage.host.formatTime(stage.length)
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                        font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Light; color: stage.inkMuted
                    }
                }

                // Hairline progress scrubber (click & drag to seek)
                Item {
                    width: 244; height: 12
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: stage.hairline } GradientStop { position: 1.0; color: "transparent" } }
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * stage.progressFrac
                        height: scrubMa.containsMouse || scrubMa.pressed ? 2.2 : 1.4
                        radius: 1; color: stage.accent
                        Behavior on height { NumberAnimation { duration: 140 } }
                    }
                    MouseArea {
                        id: scrubMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: stage.length > 0 && Boolean(stage.player && stage.player.canSeek)
                        onPressed: (e) => {
                            stage.host.seekTo(Math.max(0, Math.min(1, e.x / width)) * stage.length);
                            Sounds.playSfx("reusables/draggable/tick.wav", 0.55);
                        }
                        onPositionChanged: (e) => { if (pressed) stage.host.seekTo(Math.max(0, Math.min(1, e.x / width)) * stage.length); }
                    }
                }

                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: stage.trackTitleText
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 20; font.weight: Font.Light; color: stage.ink; topPadding: 1
                }
                Text {
                    visible: stage.trackSubText !== ""
                    width: parent.width; elide: Text.ElideRight
                    text: stage.trackSubText
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Light; color: stage.inkSoft
                }
            }

            // 2. HUD TELEMETRY ROWS: Speaker · Vol% & via <Player>
            Column {
                Layout.fillWidth: true; Layout.fillHeight: false; spacing: 7
                opacity: stage.host.introControls

                // Row 1: Speaker (click cycles output, wheel adjusts volume)
                Item {
                    width: Math.min(340, spkRow.implicitWidth + 8); height: 22
                    Row {
                        id: spkRow; anchors.verticalCenter: parent.verticalCenter; spacing: 9
                        Text { text: stage.outputMuted ? "󰖁" : stage.deviceIcon; font.family: ThemeBackend.iconFont; font.pixelSize: 15; color: stage.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            width: Math.min(implicitWidth, 300); elide: Text.ElideRight
                            text: stage.deviceName + "  ·  " + (stage.outputMuted ? "Muted" : (Math.round(stage.volumePct) + "%"))
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Light
                            color: spkMa.containsMouse ? stage.ink : stage.inkSoft
                        }
                    }
                    MouseArea {
                        id: spkMa; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: stage.cycleOutput()
                        onWheel: (w) => { stage.stepVolume(w.angleDelta.y > 0 ? 5 : -5); w.accepted = true; }
                    }
                }

                // Row 2: via <Source> (click cycles MPRIS players when >= 2)
                Item {
                    readonly property bool canCycle: stage.host.playerList && stage.host.playerList.length >= 2
                    width: Math.min(340, viaRow.implicitWidth + 8); height: 22
                    Row {
                        id: viaRow; anchors.verticalCenter: parent.verticalCenter; spacing: 9
                        Text { text: "󰎈"; font.family: ThemeBackend.iconFont; font.pixelSize: 15; color: stage.accent; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            width: Math.min(implicitWidth, 300); elide: Text.ElideRight
                            text: I18n.t("music.via_source", { "source": stage.sourceLabel })
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Light
                            color: viaMa.containsMouse && parent.parent.canCycle ? stage.ink : stage.inkSoft
                        }
                    }
                    MouseArea {
                        id: viaMa; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true
                        cursorShape: parent.canCycle ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: if (parent.canCycle) {
                            Sounds.playSfx("reusables/iconbutton/click.wav");
                            stage.host.selectPlayerByIndex((stage.host.currentPlayerIndex + 1) % stage.host.playerList.length);
                        }
                    }
                }
            }

            // Hairline divider
            Rectangle {
                Layout.fillWidth: false; Layout.preferredWidth: 244; Layout.preferredHeight: 1; Layout.fillHeight: false
                opacity: stage.host.introSeparator
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: stage.hairline } GradientStop { position: 1.0; color: "transparent" } }
            }

            // 3. ADAPTIVE MIDDLE STAGE: Lyrics <-> 10-band Liquid Mercury GPU Equalizer
            Item {
                id: midStage
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ----- A. FLOATING HUD LYRICS -----
                Item {
                    anchors.fill: parent
                    opacity: !stage.eqOpen ? stage.host.introControls : 0.0
                    visible: opacity > 0.01
                    y: !stage.eqOpen ? 0 : -12
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on y { SpringAnimation { spring: 4.2; damping: 0.36 } }

                    Text {
                        visible: stage.lyricLines.length === 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; wrapMode: Text.WordWrap
                        text: stage.emptyLyricsMsg
                        font.family: ThemeBackend.fontFamily; font.pixelSize: 13; font.weight: Font.Light
                        color: stage.inkMuted
                    }

                    Column {
                        visible: stage.lyricLines.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width; spacing: 9

                        Repeater {
                            model: stage.lyricLines
                            Text {
                                required property var modelData; required property int index
                                readonly property bool cur: index === stage.activeLyricIdx
                                readonly property real lineTime: Number(modelData.time !== undefined ? modelData.time : (modelData.t || 0))
                                visible: stage.activeLyricIdx >= 0 && Math.abs(index - stage.activeLyricIdx) <= 1
                                width: parent.width; wrapMode: Text.WordWrap
                                text: String(modelData.text || "♪")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: cur ? 16 : 12
                                font.weight: cur ? Font.Normal : Font.ExtraLight
                                color: cur ? stage.ink : stage.inkMuted
                                Behavior on opacity { NumberAnimation { duration: 220 } }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        stage.host.seekTo(lineTime);
                                        Sounds.playSfx("reusables/clickbutton/click.wav");
                                    }
                                }
                            }
                        }
                    }
                }

                // ----- B. 10-BAND LIQUID MERCURY GPU-SHADER EQUALIZER -----
                Item {
                    id: eqStage
                    anchors.fill: parent
                    enabled: stage.host.manualEqEnabled
                    opacity: stage.eqOpen ? (stage.host.introControls * (enabled ? 1.0 : 0.45)) : 0.0
                    visible: opacity > 0.01
                    y: stage.eqOpen ? 0 : 14
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on y { SpringAnimation { spring: 4.2; damping: 0.36 } }

                    property int activeBand: -1
                    property bool dragging: false
                    readonly property real pL: 24
                    readonly property real pR: 6
                    readonly property real pT: 16
                    readonly property real pB: 22
                    readonly property real pW: Math.max(10, width - pL - pR)
                    readonly property real pH: Math.max(10, height - pT - pB)
                    readonly property real zY: pT + pH * 0.5
                    function bx(i) { return pL + (pW / 10.0) * (i + 0.5); }
                    function by(db) { return zY - (db / 12.0) * (pH * 0.43); }

                    Text { x: 0; y: eqStage.pT - 5; text: "+12"; font.family: ThemeBackend.fontFamily; font.pixelSize: 8; font.weight: Font.Light; color: stage.inkMuted }
                    Text { x: 4; y: eqStage.zY - 5; text: "0";   font.family: ThemeBackend.fontFamily; font.pixelSize: 8; font.weight: Font.Light; color: stage.inkMuted }
                    Text { x: 0; y: eqStage.pT + eqStage.pH - 6; text: "-12"; font.family: ThemeBackend.fontFamily; font.pixelSize: 8; font.weight: Font.Light; color: stage.inkMuted }

                    // Compiled Qt 6 GPU Fragment Shader (Liquid Mercury Wave + Ghost Line + Ball-Impact Cascade)
                    ShaderEffect {
                        id: eqShader
                        anchors.fill: parent
                        visible: stage.active && stage.eqOpen && eqStage.visible
                        blending: true
                        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/vfx/smart_eq_vfx.frag.qsb"

                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real time: stage.shaderTime
                        property real playing: stage.playing ? 1.0 : 0.0
                        property real activeBand: eqStage.activeBand
                        property real dragPulse: stage.dragPulse
                        property real cascadeProgress: stage.cascadeProgress
                        property real cascadeFade: stage.cascadeFade
                        property real cascadeActive: stage.cascadeActive ? 1.0 : 0.0
                        property real showGhost: (stage.eqPending || stage.cascadeActive) ? 1.0 : 0.0
                        property color accentColor: stage.accent
                        property vector4d bands0:  Qt.vector4d(stage.eqShown[0], stage.eqShown[1], stage.eqShown[2], stage.eqShown[3])
                        property vector4d bands1:  Qt.vector4d(stage.eqShown[4], stage.eqShown[5], stage.eqShown[6], stage.eqShown[7])
                        property vector4d bands2:  Qt.vector4d(stage.eqShown[8], stage.eqShown[9], eqStage.pL, eqStage.pR)
                        property vector4d target0: Qt.vector4d(stage.eqGains[0], stage.eqGains[1], stage.eqGains[2], stage.eqGains[3])
                        property vector4d target1: Qt.vector4d(stage.eqGains[4], stage.eqGains[5], stage.eqGains[6], stage.eqGains[7])
                        property vector4d target2: Qt.vector4d(stage.eqGains[8], stage.eqGains[9], eqStage.pT, eqStage.pB)
                        property vector4d start0:  Qt.vector4d(stage.cascadeStart[0], stage.cascadeStart[1], stage.cascadeStart[2], stage.cascadeStart[3])
                        property vector4d start1:  Qt.vector4d(stage.cascadeStart[4], stage.cascadeStart[5], stage.cascadeStart[6], stage.cascadeStart[7])
                        property vector4d start2:  Qt.vector4d(stage.cascadeStart[8], stage.cascadeStart[9], stage.rippleBand, stage.rippleAge)
                    }

                    // Live floating dB badge above dragged ghost marker
                    Rectangle {
                        visible: eqStage.dragging && eqStage.activeBand >= 0
                        x: eqStage.activeBand >= 0 ? Math.max(eqStage.pL, Math.min(eqStage.width - width, eqStage.bx(eqStage.activeBand) - width * 0.5)) : 0
                        y: eqStage.activeBand >= 0 ? Math.max(0, eqStage.by(stage.eqGains[eqStage.activeBand]) - 30) : 0
                        height: 20; width: dbTxt.implicitWidth + 12; radius: 10
                        color: stage.accent
                        Text {
                            id: dbTxt; anchors.centerIn: parent
                            readonly property int val: eqStage.activeBand >= 0 ? Math.round(stage.eqGains[eqStage.activeBand]) : 0
                            text: (val > 0 ? "+" : "") + val + " dB"
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 9; font.bold: true; color: stage.onAccent
                        }
                    }

                    // Frequency labels (31 .. 16k)
                    Repeater {
                        model: stage.freqLabels
                        Text {
                            required property var modelData; required property int index
                            x: eqStage.bx(index) - width * 0.5
                            y: eqStage.height - 16
                            text: modelData
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 9
                            font.weight: index === eqStage.activeBand ? Font.DemiBold : Font.Light
                            color: index === eqStage.activeBand ? stage.ink : stage.inkMuted
                        }
                    }

                    // Direct hover + drag interaction across all 10 frequency bands
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.SizeVerCursor
                        property var touchedBands: ({})
                        function bandAt(mx) { return Math.max(0, Math.min(9, Math.floor(((mx - eqStage.pL) / eqStage.pW) * 10))); }
                        function updateBand(mx, my, playSfx) {
                            const b = bandAt(mx);
                            const db = Math.max(-12, Math.min(12, Math.round(((eqStage.zY - my) / (eqStage.pH * 0.43)) * 12)));
                            eqStage.activeBand = b;
                            if (Math.round(stage.eqGains[b]) !== db) {
                                const nxt = stage.eqGains.slice();
                                nxt[b] = db;
                                stage.eqGains = nxt;
                                touchedBands[b] = db;
                                // Optimistically mark pending on host so Save button highlights immediately
                                if (stage.host.eqData && !stage.host.eqData.pending) {
                                    const tmp = Object.assign({}, stage.host.eqData);
                                    tmp["b" + (b + 1)] = db;
                                    tmp.preset = "Custom";
                                    tmp.pending = true;
                                    stage.host.eqData = tmp;
                                }
                                if (playSfx) Sounds.playSfx("reusables/draggable/tick.wav", 0.55);
                            }
                        }
                        function flushTouched() {
                            for (const k in touchedBands) stage.host.setEqBand(parseInt(k) + 1, touchedBands[k]);
                            touchedBands = ({});
                        }
                        onPressed: (e) => {
                            stage.presetMenuOpen = false;
                            touchedBands = ({});
                            eqStage.dragging = true;
                            updateBand(e.x, e.y, true);
                        }
                        onPositionChanged: (e) => {
                            if (pressed) updateBand(e.x, e.y, false);
                            else eqStage.activeBand = bandAt(e.x);
                        }
                        onReleased: { eqStage.dragging = false; flushTouched(); }
                        onCanceled: { eqStage.dragging = false; flushTouched(); }
                        onExited: if (!pressed) eqStage.activeBand = -1
                    }

                    // Quick 2x4 Preset Popover (opens when clicking preset name in bottom bar)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                        width: parent.width; height: 92; radius: 16
                        color: Qt.rgba(0.07, 0.09, 0.13, 0.96)
                        border.width: 1; border.color: stage.hairline
                        opacity: stage.eqOpen && stage.presetMenuOpen ? 1.0 : 0.0
                        scale: stage.eqOpen && stage.presetMenuOpen ? 1.0 : 0.94
                        visible: opacity > 0.01
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on scale { SpringAnimation { spring: 5.0; damping: 0.38 } }

                        GridLayout {
                            anchors.fill: parent; anchors.margins: 8
                            columns: 4; columnSpacing: 6; rowSpacing: 6
                            Repeater {
                                model: stage.presets
                                Rectangle {
                                    required property var modelData; required property int index
                                    readonly property bool cur: !stage.customPreset && index === stage.presetIdx
                                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
                                    color: cur ? stage.accent : (pmMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.04))
                                    Text {
                                        anchors.centerIn: parent
                                        text: I18n.t("music.presets." + modelData.name.toLowerCase(), modelData.name)
                                        font.family: ThemeBackend.fontFamily; font.pixelSize: 10; font.bold: cur
                                        color: cur ? stage.onAccent : stage.inkSoft
                                    }
                                    MouseArea {
                                        id: pmMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: stage.pickPreset(index)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 4. DYNAMIC BOTTOM BAR (width = 376px)
            Item {
                id: bottomBar
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                Layout.fillHeight: false
                opacity: stage.host.introControls

                // 4A. TRANSPORT CLUSTER (slides left + shrinks + hides when Equalizer opens)
                Item {
                    id: transportGroup
                    width: 134; height: 42
                    x: stage.eqOpen ? -34 : 0
                    opacity: stage.eqOpen ? 0.0 : 1.0
                    scale: stage.eqOpen ? 0.84 : 1.0
                    enabled: !stage.eqOpen
                    visible: opacity > 0.01
                    Behavior on x       { SpringAnimation { spring: 4.5; damping: 0.36 } }
                    Behavior on scale   { SpringAnimation { spring: 4.5; damping: 0.36 } }
                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Rectangle {
                            width: 36; height: 36; radius: 18; anchors.verticalCenter: parent.verticalCenter
                            color: prevMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            border.width: 1; border.color: stage.hairline
                            Text { anchors.centerIn: parent; text: "󰒮"; font.family: ThemeBackend.iconFont; font.pixelSize: 15; color: stage.ink }
                            MouseArea {
                                id: prevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (stage.player && stage.player.canGoPrevious) { Sounds.playSfx("reusables/iconbutton/click.wav"); stage.player.previous(); }
                            }
                        }
                        Rectangle {
                            width: 42; height: 42; radius: 21; anchors.verticalCenter: parent.verticalCenter
                            color: stage.accent
                            scale: playMa.pressed ? 0.92 : 1.0
                            Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.35 } }
                            Text { anchors.centerIn: parent; text: stage.playing ? "󰏤" : "󰐊"; font.family: ThemeBackend.iconFont; font.pixelSize: 18; color: stage.onAccent }
                            MouseArea {
                                id: playMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: if (stage.player) {
                                    Sounds.playSfx(stage.playing ? "reusables/toggle/sfx.wav" : "reusables/switch/sfx.wav");
                                    MprisController.togglePlaying(stage.player);
                                }
                            }
                        }
                        Rectangle {
                            width: 36; height: 36; radius: 18; anchors.verticalCenter: parent.verticalCenter
                            color: nextMa.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                            border.width: 1; border.color: stage.hairline
                            Text { anchors.centerIn: parent; text: "󰒭"; font.family: ThemeBackend.iconFont; font.pixelSize: 15; color: stage.ink }
                            MouseArea {
                                id: nextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: if (stage.player && stage.player.canGoNext) { Sounds.playSfx("reusables/iconbutton/click.wav"); stage.player.next(); }
                            }
                        }
                    }
                }

                // 4B. EQUALIZER TOGGLE PILL (glides to x = 0 when pressed)
                Rectangle {
                    id: eqBtn
                    x: stage.eqOpen ? 0 : 148
                    anchors.verticalCenter: parent.verticalCenter
                    width: 96; height: 36; radius: 18
                    z: 4
                    color: stage.eqOpen
                        ? Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, 0.18)
                        : (eqBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.06))
                    border.width: 1
                    border.color: stage.eqOpen ? Qt.rgba(stage.accent.r, stage.accent.g, stage.accent.b, 0.65) : stage.hairline
                    scale: eqBtnMa.pressed ? 0.94 : 1.0

                    Behavior on x            { SpringAnimation { spring: 4.6; damping: 0.34 } }
                    Behavior on scale        { SpringAnimation { spring: 6.0; damping: 0.35 } }
                    Behavior on color        { ColorAnimation  { duration: 180 } }
                    Behavior on border.color { ColorAnimation  { duration: 180 } }

                    Row {
                        anchors.centerIn: parent; spacing: 6
                        Text {
                            text: stage.eqOpen ? "󰁍" : "󰺢"
                            font.family: ThemeBackend.iconFont; font.pixelSize: 13
                            color: stage.eqOpen ? stage.accent : stage.inkSoft
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: "Equalizer"
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 11
                            font.weight: stage.eqOpen ? Font.Medium : Font.Normal
                            color: stage.eqOpen ? stage.ink : stage.inkSoft
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: eqBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: stage.toggleEq()
                    }
                }

                // 4C. PRESET STRIP (emerges right of Equalizer pill when eqOpen)
                Rectangle {
                    id: presetPill
                    x: stage.eqOpen ? 104 : 68
                    anchors.verticalCenter: parent.verticalCenter
                    width: 184; height: 36; radius: 18
                    opacity: stage.eqOpen ? (stage.host.manualEqEnabled ? 1.0 : 0.45) : 0.0
                    scale: stage.eqOpen ? 1.0 : 0.88
                    enabled: stage.eqOpen && stage.host.manualEqEnabled
                    visible: opacity > 0.01
                    z: 2
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1; border.color: stage.hairline

                    Behavior on x       { SpringAnimation { spring: 4.6; damping: 0.35 } }
                    Behavior on scale   { SpringAnimation { spring: 4.6; damping: 0.35 } }
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                    Item {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 34
                        Text { anchors.centerIn: parent; text: "󰅁"; font.family: ThemeBackend.iconFont; font.pixelSize: 15; color: pPrevMa.containsMouse ? stage.ink : stage.inkMuted }
                        MouseArea { id: pPrevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: stage.pickPreset(stage.presetIdx - 1) }
                    }

                    Item {
                        anchors.left: parent.left; anchors.leftMargin: 34
                        anchors.right: parent.right; anchors.rightMargin: 34
                        anchors.top: parent.top; anchors.bottom: parent.bottom
                        Row {
                            anchors.centerIn: parent; spacing: 5
                            Rectangle {
                                visible: stage.customPreset
                                width: 5; height: 5; radius: 2.5; anchors.verticalCenter: parent.verticalCenter
                                color: stage.accent
                            }
                            Text {
                                text: stage.customPreset ? "Custom" : I18n.t("music.presets." + stage.activePresetName.toLowerCase(), stage.activePresetName)
                                font.family: ThemeBackend.fontFamily; font.pixelSize: 11; font.weight: Font.Medium
                                color: stage.ink; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { stage.presetMenuOpen = !stage.presetMenuOpen; Sounds.playSfx("reusables/clickbutton/click.wav"); }
                            onWheel: (w) => { stage.pickPreset(stage.presetIdx + (w.angleDelta.y > 0 ? -1 : 1)); w.accepted = true; }
                        }
                    }

                    Item {
                        anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: 34
                        Text { anchors.centerIn: parent; text: "󰅂"; font.family: ThemeBackend.iconFont; font.pixelSize: 15; color: pNextMa.containsMouse ? stage.ink : stage.inkMuted }
                        MouseArea { id: pNextMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: stage.pickPreset(stage.presetIdx + 1) }
                    }
                }

                // 4D. MORPHING ACTION PILL: [ Select ] in Lyrics mode <-> [ Save / Saved ] in Equalizer mode
                Rectangle {
                    id: actionBtn
                    x: stage.eqOpen ? 296 : 254
                    width: stage.eqOpen ? 80 : 84
                    height: 36; radius: 18
                    anchors.verticalCenter: parent.verticalCenter
                    z: 3
                    readonly property bool usable: stage.eqOpen ? stage.host.manualEqEnabled : (stage.host.hasTargetPlayer && !Lyrics.loading)
                    readonly property bool highlight: stage.eqOpen && stage.eqPending
                    opacity: usable ? 1.0 : 0.45
                    color: highlight
                        ? stage.accent
                        : (actMa.containsMouse ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.06))
                    border.width: highlight ? 0 : 1
                    border.color: stage.hairline
                    scale: actMa.pressed ? 0.94 : 1.0

                    Behavior on x     { SpringAnimation { spring: 4.6; damping: 0.35 } }
                    Behavior on width { SpringAnimation { spring: 4.6; damping: 0.35 } }
                    Behavior on scale { SpringAnimation { spring: 6.0; damping: 0.35 } }
                    Behavior on color { ColorAnimation  { duration: 180 } }

                    Row {
                        anchors.centerIn: parent; spacing: 5
                        Text {
                            text: stage.eqOpen ? (stage.eqPending ? "󰆓" : "󰄬") : "󰈔"
                            font.family: ThemeBackend.iconFont; font.pixelSize: 13
                            color: actionBtn.highlight ? stage.onAccent : (stage.eqOpen ? stage.inkMuted : stage.inkSoft)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: stage.eqOpen ? (stage.eqPending ? "Save" : "Saved") : "Select"
                            font.family: ThemeBackend.fontFamily; font.pixelSize: 11
                            font.weight: actionBtn.highlight ? Font.DemiBold : Font.Normal
                            color: actionBtn.highlight ? stage.onAccent : (stage.eqOpen ? stage.inkMuted : stage.inkSoft)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: actMa; anchors.fill: parent; enabled: actionBtn.usable; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (stage.eqOpen) {
                                stage.saveEq();
                            } else {
                                Sounds.playSfx("reusables/clickbutton/click.wav");
                                stage.host.openLyricsPicker();
                            }
                        }
                    }
                }
            }
        }
    }
}
