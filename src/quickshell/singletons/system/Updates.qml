pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Anserin's update posts (Settings / Control → Update). Each release on GitHub is a version with posts (Feature,
// Fix bug, Improved, Removed), written to updates/updates.json in the repo. The installed copy is read from this
// checkout; the newest copy is fetched from GitHub a minute after start and then every 6 hours (one small request),
// kept in the cache so the page works offline. A version newer than version.txt is "not installed": once per
// version a notification offers to update (anserin -up in Kitty) or to open the page.
// Features and improvements that have a switch arrive off; Turn on / Turn off only shows or hides them
// (updates.on in settings), so nothing is lost either way. A post can need another one on first (requires).
Item {
    id: root

    readonly property string repo: "lukpednoi/Anserin"
    readonly property string rawBase: "https://raw.githubusercontent.com/" + repo + "/main/"
    readonly property string rootDir: Caching.anserinDir ? Caching.anserinDir.replace(/\/src\/?$/, "") : ""
    readonly property string cacheFile: Caching.getCacheDir("updates") + "/remote.json"
    readonly property string notifiedFile: Caching.getStateDir("updates") + "/notified"

    property string localVersion: ""
    property var localFeed: []
    property var remoteFeed: []
    property string notified: ""
    property bool notifiedRead: false   // no notification before we know which version was last shown
    property bool checking: false

    // every version both copies know of, newest first; a version only GitHub has is not installed yet
    readonly property var versions: {
        const byVer = {};
        for (const v of localFeed) byVer[v.version] = Object.assign({}, v, { installed: true, remote: false });
        for (const v of remoteFeed) {
            if (!byVer[v.version]) byVer[v.version] = Object.assign({}, v, { installed: !newer(v.version, localVersion), remote: true });
        }
        return Object.values(byVer).sort((a, b) => newer(a.version, b.version) ? -1 : newer(b.version, a.version) ? 1 : 0);
    }
    readonly property var latest: versions.length > 0 ? versions[0] : null
    readonly property var pending: versions.filter(v => !v.installed)
    readonly property var on: Config.getSetting("updates.on", {}) || {}

    // bright, fixed tag colours (dark text on them): the theme's own yellow, green and blue can share one hue, and
    // the four tags must always look different
    readonly property var tags: ({
        feature: { name: "Feature", color: "#ffd43b" },
        fixbug: { name: "Fix bug", color: "#51cf66" },
        improved: { name: "Improved", color: "#4dabf7" },
        removed: { name: "Removed", color: "#ff6b6b" }
    })
    function tag(t) { return tags[t] || tags.feature; }

    function parts(v) { return String(v || "0").split(/[^0-9]+/).filter(s => s !== "").map(n => parseInt(n, 10)); }
    function newer(a, b) {
        const x = parts(a), y = parts(b);
        for (let i = 0; i < Math.max(x.length, y.length); i++) {
            const p = x[i] || 0, q = y[i] || 0;
            if (p !== q) return p > q;
        }
        return false;
    }

    // ---------- switches ----------
    function hasSwitch(post) { return !!post && post.switch === true && (post.tag === "feature" || post.tag === "improved"); }
    function isOn(id) { return on[id] === true; }
    function findPost(id) {
        for (const v of versions) for (const p of (v.posts || [])) if (p.id === id) return p;
        return null;
    }
    // what must be on first ("" when nothing): the title of the post it needs
    function blockedBy(post) {
        if (!post || !post.requires || isOn(post.requires)) return "";
        const need = findPost(post.requires);
        return need ? need.title : post.requires;
    }
    function setOn(id, value) {
        const next = Object.assign({}, on);
        if (value) next[id] = true;
        else {
            delete next[id];
            // whatever needed it goes off with it
            for (const v of versions) for (const p of (v.posts || [])) if (p.requires === id) delete next[p.id];
        }
        Config.setSetting("updates.on", next);
    }

    // a post's picture: from this checkout once installed, from GitHub before
    function imageUrl(version, post) {
        if (!post || !post.image) return "";
        return version && version.installed && rootDir !== "" ? "file://" + rootDir + "/" + post.image : rawBase + post.image;
    }

    // ---------- actions ----------
    function update() {
        Quickshell.execDetached(["kitty", "--hold", "-e", rootDir + "/bin/anserin", "-up"]);
    }
    function check() {
        if (fetch.running || rootDir === "") return;
        checking = true;
        fetch.running = true;
    }

    function parse(text) {
        try {
            const data = JSON.parse(text);
            return Array.isArray(data.versions) ? data.versions.filter(v => v && v.version && Array.isArray(v.posts)) : [];
        } catch (e) { return []; }
    }

    FileView {
        path: root.rootDir !== "" ? root.rootDir + "/version.txt" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.localVersion = text().trim()
    }
    FileView {
        path: root.rootDir !== "" ? root.rootDir + "/updates/updates.json" : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.localFeed = root.parse(text())
    }
    FileView {
        id: cached
        path: root.cacheFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { root.remoteFeed = root.parse(text()); root.maybeNotify(); }
    }
    FileView {
        id: notifiedView
        path: root.notifiedFile
        printErrors: false
        onLoaded: { root.notified = text().trim(); root.notifiedRead = true; root.maybeNotify(); }
        onLoadFailed: { root.notifiedRead = true; root.maybeNotify(); }
    }

    // one request, written beside the cache and moved over it only when it is complete
    Process {
        id: fetch
        command: ["bash", "-c", 'mkdir -p "$(dirname "$2")" && curl -fsL --max-time 15 "$1" -o "$2.part" && mv -f "$2.part" "$2"; rm -f "$2.part"',
                  "_", root.rawBase + "updates/updates.json", root.cacheFile]
        onExited: root.checking = false
    }
    Timer { interval: 60 * 1000; running: root.rootDir !== ""; onTriggered: root.check() }
    Timer { interval: 6 * 60 * 60 * 1000; repeat: true; running: root.rootDir !== ""; onTriggered: root.check() }

    // ---------- the notification, once per version ----------
    function maybeNotify() {
        const top = pending.length > 0 ? pending[0] : null;
        if (!notifiedRead || !top || top.version === notified || notice.running) return;
        notified = top.version;
        Quickshell.execDetached(["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s" "$2" > "$1"', "_", notifiedFile, top.version]);
        const count = (top.posts || []).length;
        notice.command = ["notify-send", "-a", "Anserin", "-i", "software-update-available",
                          "-A", "update=Update", "-A", "default=See what's new",
                          "Anserin " + top.version + " is out",
                          count + (count === 1 ? " change" : " changes") + ". Open Update to see them."];
        notice.running = true;
    }
    Process {
        id: notice
        stdout: StdioCollector { id: noticeOut }
        onExited: {
            const act = noticeOut.text.trim();
            if (act === "update") root.update();
            else if (act === "default") Quickshell.execDetached([root.rootDir + "/bin/anserin", "msg", "open", "guide", "update"]);
        }
    }
}
