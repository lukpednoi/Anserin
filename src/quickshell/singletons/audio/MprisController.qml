pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../"

Singleton {
    id: root

    readonly property var _playerWatch: {
        let players = Mpris.players.values;
        let states = [];
        for (let i = 0; i < players.length; i++) {
            states.push(players[i].isPlaying);
            states.push(players[i].canControl);
            states.push(players[i].dbusName);
            states.push(players[i].trackArtUrl);
            states.push(players[i].trackTitle);
            states.push(players[i].length);
            states.push(players[i].metadata ? players[i].metadata["xesam:url"] : "");
        }
        return states;
    }

    property string preferredPlayerId: ""
    property string controlledPlayerId: ""

    function resolvePlayer(player) {
        if (!player || !player.identity || !player.length || (player.metadata && player.metadata["xesam:url"])) return player;
        // Native browser metadata can retain the previous YouTube title during autoplay.
        let integrated = Mpris.players.values.find(p => p !== player
            && p.dbusName === "org.mpris.MediaPlayer2.plasma-browser-integration"
            && p.identity === player.identity && p.isPlaying === player.isPlaying
            && Math.abs(p.length - player.length) < 1 && p.trackTitle
            && p.metadata && /(?:youtube\.com|youtu\.be)\//i.test(String(p.metadata["xesam:url"] || "")));
        return integrated || player;
    }

    readonly property MprisPlayer activePlayer: {
        let _ = _playerWatch;
        let players = Mpris.players.values.slice().sort((a, b) => (a.dbusName || "").localeCompare(b.dbusName || ""));
        let controlled = players.find(p => p.dbusName === controlledPlayerId);
        if (controlled) return resolvePlayer(controlled);
        let previous = players.find(p => p.dbusName === preferredPlayerId);
        let playingWithArt = players.find(p => p.isPlaying && p.trackArtUrl);
        if (previous && previous.isPlaying && (previous.trackArtUrl || !playingWithArt)) return resolvePlayer(previous);
        let playing = playingWithArt || players.find(p => p.isPlaying);
        if (playing) return resolvePlayer(playing);
        if (previous && previous.trackArtUrl) return resolvePlayer(previous);
        let controllable = players.find(p => p.canControl && p.trackArtUrl) || previous || players.find(p => p.canControl);
        if (controllable) return resolvePlayer(controllable);
        return players.length > 0 ? resolvePlayer(players[0]) : null;
    }

    readonly property string activePlayerId: activePlayer ? (activePlayer.dbusName || activePlayer.identity || "") : ""
    readonly property bool hasActivePlayer: activePlayer !== null
    readonly property bool isPlaying: activePlayer ? activePlayer.isPlaying : false
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string currentArtUrl: {
        if (!activePlayer) return "";
        if (activePlayer.trackArtUrl && activePlayer.trackArtUrl !== "") return activePlayer.trackArtUrl;
        if (activePlayer.metadata) {
            let m = activePlayer.metadata;
            if (m["mpris:artUrl"]) return m["mpris:artUrl"];
            if (m["artUrl"]) return m["artUrl"];
            if (m["xesam:url"] && typeof m["xesam:url"] === "string" && (m["xesam:url"].startsWith("http") || m["xesam:url"].startsWith("file://"))) {
                if (m["xesam:url"].match(/\.(jpg|jpeg|png|webp)$/i)) return m["xesam:url"];
            }
        }
        return "";
    }
    // the page the song plays on (xesam:url), from its own player or from another one playing the same title
    // (a browser's own MPRIS entry has none while plasma-browser-integration's has the YouTube page): art_fetch.sh
    // uses it for a full-size cover
    function pageUrlOf(p) {
        const u = p && p.metadata ? p.metadata["xesam:url"] : "";
        return typeof u === "string" && u.startsWith("http") && !u.match(/\.(jpg|jpeg|png|webp)$/i) ? u : "";
    }
    function plainTitle(t) { return String(t || "").replace(/^\(\d+\)\s*/, "").replace(/\s+-\s+YouTube$/, "").trim(); }
    readonly property string pageUrl: {
        if (!activePlayer) return "";
        const own = pageUrlOf(activePlayer);
        if (own) return own;
        const title = plainTitle(activePlayer.trackTitle);
        const list = Mpris.players ? Mpris.players.values : [];
        for (let i = 0; i < list.length; i++) {
            const u = pageUrlOf(list[i]);
            if (u && title !== "" && plainTitle(list[i].trackTitle) === title) return u;
        }
        return "";
    }
    property real livePosition: activePlayer ? activePlayer.position : 0

    readonly property string trackKey: JSON.stringify([activePlayerId, trackTitle, trackArtist])
    readonly property string artKey: JSON.stringify([activePlayerId, trackTitle, trackArtist, currentArtUrl])
    property string cachedTrackKey: ""
    property string cachedArtUrl: ""
    property string cachedArtPlayerId: ""
    property string lastArtPlayerId: ""
    property string lastArtUrl: ""
    onCurrentArtUrlChanged: {
        if (currentArtUrl) {
            lastArtPlayerId = activePlayerId;
            lastArtUrl = currentArtUrl;
        }
    }
    readonly property string artUrl: {
        if (cachedArtPlayerId === activePlayerId && cachedArtUrl && (cachedTrackKey === trackKey || !currentArtUrl)) return cachedArtUrl;
        return currentArtUrl || (lastArtPlayerId === activePlayerId ? lastArtUrl : "");
    }
    property string blur: ""
    property string grad: ""
    property string textColor: "#cdd6f4"
    property string deviceIcon: "󰓃"
    property string deviceName: "Speaker"
    property bool fetchPending: false
    property int artRetries: 0

    function togglePlaying(player) {
        if (!player || !player.canTogglePlaying) return;
        root.controlledPlayerId = player.dbusName;
        player.togglePlaying();
    }

    onArtKeyChanged: {
        artRetries = 0;
        artRetryTimer.stop();
        queueFetch();
    }

    onActivePlayerChanged: {
        if (root.activePlayer) {
            Qt.callLater(() => root.preferredPlayerId = root.activePlayerId);
            root.livePosition = root.activePlayer.position;
        }
        root.queueFetch();
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.hasActivePlayer && root.isPlaying
        onTriggered: {
            if (root.activePlayer) {
                root.activePlayer.positionChanged();
                root.livePosition = root.activePlayer.position;
            }
        }
    }

    Timer {
        id: fetchDebounceTimer
        interval: 60
        repeat: false
        onTriggered: root.fetchArt()
    }

    Timer {
        id: artRetryTimer
        interval: 2000
        onTriggered: if (root.hasActivePlayer && root.isPlaying) root.fetchArt()
    }

    function queueFetch() {
        fetchDebounceTimer.restart();
    }

    Connections {
        target: root.activePlayer
        function onPositionChanged() {
            if (root.activePlayer) root.livePosition = root.activePlayer.position;
        }
        function onPostTrackChanged() {
            if (root.activePlayer) root.livePosition = root.activePlayer.position;
            root.queueFetch();
        }
        function onTrackArtUrlChanged() {
            root.queueFetch();
        }
        function onTrackTitleChanged() {
            root.queueFetch();
        }
        function onMetadataChanged() {
            root.queueFetch();
        }
        function onPlaybackStateChanged() {
            root.queueFetch();
        }
    }

    Process {
        id: artFetchProc
        command: [
            "bash",
            Caching.qsDir + "/media/art_fetch.sh",
            root.activePlayerId,
            root.currentArtUrl,
            root.trackTitle,
            root.trackArtist,
            root.pageUrl
        ]
        onExited: {
            if (root.fetchPending) {
                root.fetchPending = false;
                Qt.callLater(root.fetchArt);
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim();
                if (txt !== "") {
                    try {
                        let d = JSON.parse(txt);
                        root.deviceIcon = d.deviceIcon || "󰓃";
                        root.deviceName = d.deviceName || "Speaker";

                        if (d.playerId !== root.activePlayerId || d.title !== root.trackTitle || d.artist !== root.trackArtist || d.rawUrl !== root.currentArtUrl) {
                            return;
                        }

                        if (d.isPlaceholder === false && d.artUrl) {
                            root.cachedTrackKey = root.trackKey;
                            root.cachedArtPlayerId = root.activePlayerId;
                            root.cachedArtUrl = d.artUrl;
                            root.blur = d.blur || "";
                            root.grad = d.grad || "";
                            root.textColor = d.textColor || "#cdd6f4";
                        } else {
                            root.grad = d.grad || "";
                            root.textColor = d.textColor || "#cdd6f4";
                            if (root.currentArtUrl && root.isPlaying && root.artRetries < 2) {
                                root.artRetries++;
                                artRetryTimer.restart();
                            }
                        }
                    } catch(e) {}
                }
            }
        }
    }

    function fetchArt() {
        if (!root.hasActivePlayer) {
            root.cachedArtUrl = "";
            artRetryTimer.stop();
            root.blur = "";
            root.grad = "";
            root.textColor = "#cdd6f4";
            return;
        }
        if (artFetchProc.running) {
            root.fetchPending = true;
            return;
        }
        root.fetchPending = false;
        artFetchProc.running = true;
    }

    function forceArtRefresh() {
        root.fetchArt();
    }
}
