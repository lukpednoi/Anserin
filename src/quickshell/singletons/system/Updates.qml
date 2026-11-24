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
        // installed means not newer than version.txt (the local feed can list a version before it is installed)
        const here = v => localVersion === "" || !newer(v.version, localVersion);
        for (const v of localFeed) byVer[v.version] = Object.assign({}, v, { installed: here(v), remote: false });
        for (const v of remoteFeed) {
            if (!byVer[v.version]) byVer[v.version] = Object.assign({}, v, { installed: here(v), remote: true });
        }
        return Object.values(byVer).sort((a, b) => newer(a.version, b.version) ? -1 : newer(b.version, a.version) ? 1 : 0);
    }
    readonly property var latest: versions.length > 0 ? versions[0] : null
    // nothing is "not installed" until this copy's version is known (the GitHub copy can be read first)
    readonly property var pending: localVersion === "" ? [] : versions.filter(v => !v.installed)

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

    // a post's picture: from this checkout when local or installed, from GitHub only for remote-only versions
    function resolveImageUrl(version, relPath) {
        if (!relPath) return "";
        const s = String(relPath);
        if (s.startsWith("http://") || s.startsWith("https://") || s.startsWith("file://")) return s;
        const useLocal = version && (version.installed || version.remote === false) && rootDir !== "";
        return useLocal ? ("file://" + rootDir + "/" + s) : (rawBase + s);
    }
    function imageUrl(version, post) {
        if (!post || !post.image) return "";
        return resolveImageUrl(version, post.image);
    }
    function postImages(version, post) {
        if (!post) return [];
        const list = post.images;
        if (list && list.length > 0) {
            const out = [];
            for (let i = 0; i < list.length; i++) {
                const it = list[i];
                const rel = typeof it === "string" ? it : (it && it.src ? it.src : "");
                const url = resolveImageUrl(version, rel);
                if (url) out.push({ label: (it && it.label) ? String(it.label) : "", url: url });
            }
            if (out.length > 0) return out;
        }
        const single = imageUrl(version, post);
        return single ? [{ label: "", url: single }] : [];
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
        onLoaded: { root.localVersion = text().trim(); root.maybeNotify(); }
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
