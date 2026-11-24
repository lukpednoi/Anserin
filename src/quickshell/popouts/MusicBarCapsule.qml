import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "../"

// Reusable unified Music Bar capsule + drooping Cava wave with continuous 1px border (zero seam!).
// Always a sleek single-line stadium pill: long lyrics auto-paginate cleanly onto the next page as sung.
Item {
    id: pill

    property bool preview: false
    property real maxWidth: Scaler.s(460)
    property bool liveActive: true
    property real waveHeight: Scaler.s(20)
    property string previewOverrideText: ""

    signal openMusicRequested()

    readonly property var player: MprisController.activePlayer
    readonly property bool hasSong: player !== null && String(player.trackTitle || "").trim() !== ""
    readonly property bool isPlaying: player ? (player.playbackState === MprisPlaybackState.Playing || player.isPlaying) : false
    readonly property bool effectivePlaying: preview ? (hasSong ? isPlaying : true) : isPlaying

    readonly property real pillHeight: Scaler.s(34)
    readonly property color fillColor: "#090b10"
    property color borderColor: pillMa.containsMouse ? Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.52) : Qt.rgba(1, 1, 1, 0.16)
    Behavior on borderColor { ColorAnimation { duration: 160 } }

    // Exposed interactive hit region (covers only the stadium pill, not the drooping wave below)
    readonly property alias hitItem: pillBody

    function escHtml(s) {
        return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
    function plainTitle(t) {
        return String(t || "").replace(/^\(\d+\)\s*/, "").replace(/\s+-\s+YouTube$/, "").trim();
    }

    readonly property string rawArt: MprisController.artUrl || (player ? (player.trackArtUrl || "") : "")
    readonly property string coverSource: {
        if (!rawArt) return "";
        return (rawArt.startsWith("file://") || rawArt.startsWith("http")) ? rawArt : ("file://" + rawArt);
    }

    readonly property color dotColor: ThemeBackend.green
    readonly property color accentColor: ThemeBackend.mauve

    // Exact pixel width measurement in the active font (handles Thai, CJK, English, monospace cleanly!)
    FontMetrics {
        id: fm
        font.family: ThemeBackend.fontFamily
        font.pixelSize: Scaler.s(12)
        font.bold: true
    }

    // Smoothly track song position while lyrics are visible & playing (150ms lightweight timer, 0% when paused/hidden)
    property real livePos: player ? Number(player.position || 0) : 0
    Timer {
        interval: 150
        repeat: true
        running: !pill.preview && pill.liveActive && pill.visible && pill.isPlaying && Lyrics.hasLyrics
        onTriggered: {
            if (pill.player) pill.livePos = Number(pill.player.position || 0);
        }
    }
    Connections {
        target: pill.player
        ignoreUnknownSignals: true
        function onPositionChanged() { if (pill.player) pill.livePos = Number(pill.player.position || 0); }
        function onPostTrackChanged() { if (pill.player) pill.livePos = Number(pill.player.position || 0); }
    }

    readonly property real chromeWidth: Scaler.s(118)
    readonly property real maxTextWidth: Math.max(Scaler.s(80), maxWidth - chromeWidth)

    // Paginate long single-token text (e.g. spaceless Thai/Japanese lyrics) cleanly by pixel width
    function paginateString(str, frac) {
        const limit = Math.max(Scaler.s(72), pill.maxTextWidth - Scaler.s(6));
        if (fm.advanceWidth(str) <= limit) return str;
        const pages = [];
        let cur = "";
        for (let i = 0; i < str.length; i++) {
            const ch = str.charAt(i);
            if (cur.length > 0 && fm.advanceWidth(cur + ch) > limit) {
                pages.push(cur);
                cur = ch;
            } else {
                cur += ch;
            }
        }
        if (cur.length > 0) pages.push(cur);
        if (pages.length === 0) return str;
        const pIdx = Math.max(0, Math.min(pages.length - 1, Math.floor(Math.max(0, Math.min(0.999, frac)) * pages.length)));
        return pages[pIdx];
    }

    // Active synced lyric page with word-level bold white highlight (flips to next page instead of overflowing!)
    readonly property string formattedText: {
        if (preview && previewOverrideText !== "") return previewOverrideText;
        if (preview && !hasSong) {
            return "<font color='#aeb5c7'>Now I'm Slipping</font> <font color='#ffffff'><b>Through</b></font> <font color='#7c8396'>The Cracks</font>";
        }
        if (!hasSong) {
            return "<font color='#8b92a6'>" + escHtml(I18n.t("music.nothing_playing")) + "</font>";
        }
        const kLines = Lyrics.hasLyrics ? (Lyrics.karaokeLines || []) : [];
        if (kLines.length > 0) {
            const pos = Math.max(0, Number(pill.livePos || Lyrics.currentPosition || 0));
            let lineIdx = -1;
            for (let i = 0; i < kLines.length; i++) {
                if (pos >= Number(kLines[i].start || 0)) lineIdx = i;
                else break;
            }
            if (lineIdx >= 0) {
                const ln = kLines[lineIdx];
                const words = ln.words || [];
                const lineDur = Math.max(0.5, Number(ln.end || (Number(ln.start || 0) + 4.0)) - Number(ln.start || 0));
                const lineFrac = Math.max(0, Math.min(1, (pos - Number(ln.start || 0)) / lineDur));

                if (words.length > 1) {
                    let wIdx = 0;
                    for (let j = 0; j < words.length; j++) {
                        if (pos >= Number(words[j].t || 0)) wIdx = j;
                    }
                    const limit = Math.max(Scaler.s(72), pill.maxTextWidth - Scaler.s(6));
                    const pages = [];
                    let curIndices = [];
                    let curStr = "";
                    for (let j = 0; j < words.length; j++) {
                        const w = String(words[j].w || "");
                        const cand = curStr === "" ? w : (curStr + " " + w);
                        if (curIndices.length > 0 && fm.advanceWidth(cand) > limit) {
                            pages.push(curIndices);
                            curIndices = [j];
                            curStr = w;
                        } else {
                            curIndices.push(j);
                            curStr = cand;
                        }
                    }
                    if (curIndices.length > 0) pages.push(curIndices);

                    let activePage = pages[0] || [];
                    for (let p = 0; p < pages.length; p++) {
                        if (pages[p].indexOf(wIdx) >= 0) { activePage = pages[p]; break; }
                    }

                    if (activePage.length === 1) {
                        const onlyWord = String(words[activePage[0]].w || "");
                        if (fm.advanceWidth(onlyWord) > limit) {
                            return "<font color='#ffffff'><b>" + escHtml(paginateString(onlyWord, lineFrac)) + "</b></font>";
                        }
                    }

                    let out = "";
                    for (let k = 0; k < activePage.length; k++) {
                        const j = activePage[k];
                        if (k > 0) out += " ";
                        const tok = escHtml(words[j].w);
                        if (j === wIdx) out += "<font color='#ffffff'><b>" + tok + "</b></font>";
                        else if (j < wIdx) out += "<font color='#aeb5c7'>" + tok + "</font>";
                        else out += "<font color='#7c8396'>" + tok + "</font>";
                    }
                    return out;
                }
                const singleText = words.length === 1 ? String(words[0].w || "") : String(ln.text || "");
                if (singleText !== "") {
                    return "<font color='#ffffff'><b>" + escHtml(paginateString(singleText, lineFrac)) + "</b></font>";
                }
            }
        }
        const title = escHtml(plainTitle(player.trackTitle));
        const artist = escHtml(String(player.trackArtist || "").trim());
        return artist
            ? ("<font color='#f2f5fb'><b>" + title + "</b></font> <font color='#8b92a6'>· " + artist + "</font>")
            : ("<font color='#f2f5fb'><b>" + title + "</b></font>");
    }

    function bandAvg(start, end) {
        const arr = Cava.barLevels;
        if (!arr || arr.length === 0) return 0.25;
        let sum = 0, cnt = 0;
        for (let i = start; i < Math.min(end, arr.length); i++) { sum += Number(arr[i] || 0); cnt++; }
        return cnt > 0 ? Math.max(0.18, Math.min(1.0, (sum / cnt) * 1.35)) : 0.25;
    }

    readonly property real b0: preview && !hasSong ? 0.62 : (effectivePlaying ? bandAvg(0, 12) : 0.0)
    readonly property real b1: preview && !hasSong ? 0.92 : (effectivePlaying ? bandAvg(12, 32) : 0.0)
    readonly property real b2: preview && !hasSong ? 0.56 : (effectivePlaying ? bandAvg(32, 54) : 0.0)

    readonly property real targetWidth: Math.min(maxWidth, Math.max(Scaler.s(132), contentRow.implicitWidth + Scaler.s(26)))

    width: targetWidth
    height: pillHeight + waveHeight + 2
    Behavior on width { NumberAnimation { duration: 380; easing.type: Easing.OutQuint } }

    // 1. SINGLE UNIFIED GPU SDF SHELL: stadium pill + seamless drooping Cava wave + continuous 1px rim border!
    MusicBarWave {
        id: unifiedShell
        anchors.fill: parent
        pillHeight: pill.pillHeight
        fillColor: pill.fillColor
        borderColor: pill.borderColor
        borderWidth: 1.0
        active: pill.preview ? pill.liveActive : (pill.liveActive && pill.visible && pill.hasSong && pill.isPlaying)
        previewDemo: pill.preview
        count: 24
        mirrored: true
        rise: 0.45
        fall: 0.22
    }

    // 2. Pill content area (aligned exactly to the padded pill inside unifiedShell)
    Item {
        id: pillBody
        x: 1
        y: 1
        width: parent.width - 2
        height: pill.pillHeight
        clip: true

        // Click opens Left Panel Music; no wheel scrolling so the bar stays steady
        MouseArea {
            id: pillMa
            anchors.fill: parent
            enabled: !pill.preview
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sounds.playSfx("reusables/iconbutton/click.wav");
                pill.openMusicRequested();
            }
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Scaler.s(8)

            // Status dot
            Rectangle {
                width: Scaler.s(6); height: Scaler.s(6); radius: width * 0.5
                anchors.verticalCenter: parent.verticalCenter
                color: pill.effectivePlaying ? pill.dotColor : Qt.rgba(1, 1, 1, 0.28)
                Behavior on color { ColorAnimation { duration: 180 } }
            }

            // Circular Album Cover (hover reveals Play/Pause micro-button without widening pill)
            Item {
                width: Scaler.s(22); height: Scaler.s(22); anchors.verticalCenter: parent.verticalCenter
                Rectangle { id: covMask; anchors.fill: parent; radius: width * 0.5; visible: false; layer.enabled: true }
                Rectangle {
                    anchors.fill: parent; radius: width * 0.5; color: "#1c212c"
                    Text { visible: covImg.status !== Image.Ready; anchors.centerIn: parent; text: "󰎈"; font.family: ThemeBackend.iconFont; font.pixelSize: Scaler.s(11); color: pill.accentColor }
                }
                Image {
                    id: covImg; anchors.fill: parent; visible: false
                    source: pill.coverSource; sourceSize.width: 64; fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true
                }
                MultiEffect { anchors.fill: parent; source: covImg; maskEnabled: true; maskSource: covMask; visible: covImg.status === Image.Ready }
                Rectangle { anchors.fill: parent; radius: width * 0.5; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22) }

                Rectangle {
                    anchors.fill: parent; radius: width * 0.5
                    color: Qt.rgba(0.04, 0.05, 0.08, 0.72)
                    opacity: !pill.preview && (pillMa.containsMouse || covMa.containsMouse) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Text {
                        anchors.centerIn: parent
                        text: pill.isPlaying ? "󰏤" : "󰐊"
                        font.family: ThemeBackend.iconFont; font.pixelSize: Scaler.s(11); color: "#ffffff"
                    }
                }
                MouseArea {
                    id: covMa; anchors.fill: parent; enabled: !pill.preview; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: (e) => {
                        e.accepted = true;
                        if (pill.player) {
                            Sounds.playSfx(pill.isPlaying ? "reusables/toggle/sfx.wav" : "reusables/switch/sfx.wav");
                            MprisController.togglePlaying(pill.player);
                        }
                    }
                }
            }

            // Music note glyph + Single-Line Paginated Synced Lyric
            Row {
                anchors.verticalCenter: parent.verticalCenter; spacing: Scaler.s(5)
                Text {
                    text: "♪"
                    font.family: ThemeBackend.fontFamily; font.pixelSize: Scaler.s(11)
                    color: pill.effectivePlaying ? Qt.rgba(1, 1, 1, 0.65) : Qt.rgba(1, 1, 1, 0.32)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: lyricTxt
                    text: pill.formattedText
                    textFormat: Text.StyledText
                    font.family: ThemeBackend.fontFamily; font.pixelSize: Scaler.s(12)
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, pill.maxTextWidth)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Divider tick + 3-bar mini Cava visualizer
            Row {
                anchors.verticalCenter: parent.verticalCenter; spacing: Scaler.s(6)

                Rectangle {
                    width: 2; height: Scaler.s(8); radius: 1
                    anchors.verticalCenter: parent.verticalCenter
                    color: pill.effectivePlaying ? Qt.rgba(pill.dotColor.r, pill.dotColor.g, pill.dotColor.b, 0.55) : Qt.rgba(1, 1, 1, 0.16)
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 2.2
                    height: Scaler.s(14)
                    Repeater {
                        model: [pill.b0, pill.b1, pill.b2]
                        Rectangle {
                            required property real modelData
                            width: 2.5; radius: 1.25
                            height: pill.effectivePlaying ? Math.max(3.5, Scaler.s(13.5) * modelData) : 3.5
                            anchors.verticalCenter: parent.verticalCenter
                            color: pill.effectivePlaying ? pill.accentColor : Qt.rgba(1, 1, 1, 0.30)
                            Behavior on height { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
                        }
                    }
                }
            }
        }
    }
}
