import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Window
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../"
import "../bar"
import "."
import "../reusables"
import "../controlcenter/smart" as Smart

// Panel on the left screen edge, joined to the screen frame like the Control Center. Opened by hovering the
// middle of that edge, and hides again when the pointer leaves, using the Control Center's auto-hide settings.
// A topbar and a right sidebar form one L-shaped piece around the page. The sidebar holds the modules chosen in
// Edit panel (PanelLayout), one per page; a click on one, or a wheel click over the sidebar, changes page.
// The starred module opens first every time; without a star the panel reopens on the page used last.
Item {
    id: root
    // what the GlassFill tiles inside refract: the panel's own glass (EdgeBackground), as the bar does
    readonly property Item glassBackdropItem: body.glassBackdrop
    visible: false
    focus: true
    enabled: visible

    function s(v) { return Scaler.s(v); }

    // Style B (Kinetic Light-Rail) palette + spring trackers
    readonly property bool darkMode: (0.2126 * ThemeBackend.base.r + 0.7152 * ThemeBackend.base.g + 0.0722 * ThemeBackend.base.b) < 0.5
    readonly property color cAccent: ThemeBackend.mauve
    readonly property color cAccent2: ThemeBackend.peach
    readonly property color cOnAccent: {
        const lum = 0.2126 * cAccent.r + 0.7152 * cAccent.g + 0.0722 * cAccent.b;
        return lum > 0.52 ? "#0b0e14" : "#ffffff";
    }
    Smart.SpringVal { id: railPulse; target: 0.0; stiffness: 180; damping: 0.55; eps: 0.005 }
    readonly property real activeRailTargetY: {
        if (root.fileMode) {
            if (activePlaceHighlight.slot) return placeColumn.y + activePlaceHighlight.slot.y + activePlaceHighlight.slot.height * 0.5;
            return placeColumn.y + root.s(22);
        }
        if (activeModuleHighlight.slot) return moduleColumn.y + activeModuleHighlight.slot.y + activeModuleHighlight.slot.height * 0.5;
        return moduleColumn.y + root.s(22);
    }
    Smart.SpringVal { id: railY; target: root.activeRailTargetY; stiffness: 380; damping: 0.58; eps: 0.3 }
    // While the panel slides in/out, snap the rail directly instead of running CPU Canvas repaints mid-slide.
    onActiveRailTargetYChanged: if (!root.visible || root.introContent < 0.99) railY.snap(root.activeRailTargetY)

    readonly property var settings: Config.getSetting("controlcenter", null)
    readonly property bool autoHideEnabled: !settings || settings.autohide !== false
    readonly property int autoHideDelay: (settings && !isNaN(parseInt(settings.autohideDelay))) ? Math.max(300, parseInt(settings.autohideDelay)) : 1200
    property bool hoverSeen: false
    // a list dropped down from a choice (Dropdown's Popup) is drawn in the window's overlay, not in the panel, so the
    // pointer on it has left the panel as far as panelHover knows: auto-hide waits while one is open
    readonly property bool popupOpen: {
        const overlay = QQC.Overlay.overlay;
        if (!overlay) return false;
        for (let i = 0; i < overlay.children.length; i++) if (overlay.children[i].visible) return true;
        return false;
    }
    property real introContent: 0
    // Opened from the workspace capsule (which has unfolded into this shape): the content fades in.
    property real contentShown: 1
    // Opened from the workspace capsule: all but invisible for a moment (drawn, so the blurred wallpaper and the
    // rest are ready, while Hyprland's layer fade-in runs), then it takes the workspaces and slides out from under
    // them as it does when opened from the edge; the capsule goes once the slide is done.
    property bool awaitingUnfold: false
    property bool fromCapsule: false
    // where this panel starts on the screen: the main window begins inside the screen frame. The workspaces are
    // laid out from the screen edge, as the capsule (its own window at x 0) has them.
    readonly property real screenX: typeof masterWindow !== "undefined" ? masterWindow.frameInset : 0
    property var exitCallback: null

    // ---------- pages ----------
    readonly property var order: PanelLayout.order
    readonly property int pageCount: order.length
    function pageOf(id) { return order.indexOf(id); }
    // the open panel asked for a page (Main.qml gotoTab)
    function gotoTab(id) { const i = pageOf(id); if (i !== -1) setPage(i); }
    readonly property int launcherPageIndex: pageOf("launcher")
    readonly property int timerPageIndex: pageOf("timer")
    readonly property string screenName: typeof masterWindow !== "undefined" && masterWindow.screen ? masterWindow.screen.name : ""
    // the Launcher page's search field has focus: the panel stays open while the user types
    property bool launcherTyping: false

    // ---------- the File page (the folder button right of the pencil) ----------
    // On: the page shows FilePage at once, and the sidebar's modules slide down out while the places come down in
    // behind them; off: the places slide up out, the modules come back up, and the page in use shows again. The
    // panel always opens with it off (the starred module first, as ever). Where it is and the history live here, so
    // the topbar path and the places follow it; FilePage is loaded only while it is on (and its slide runs).
    readonly property string fileHome: Quickshell.env("HOME")
    readonly property string fileTrash: fileHome + "/.local/share/Trash/files"
    readonly property var filePlaces: [
        { glyph: "󱂵", path: fileHome },
        { glyph: "󰉍", path: fileHome + "/Downloads" },
        { glyph: "󰉏", path: fileHome + "/Pictures" },
        { glyph: "󱧺", path: fileHome + "/Videos" },
        { glyph: "󰩹", path: fileTrash }
    ]
    property bool fileMode: false
    property real fileT: 0
    property string filePath: fileHome
    property var fileHistory: []
    property var fileFuture: []
    property var fileClip: null            // cut or copied: { mode: "copy" | "move", paths: [...] }
    property bool fileTyping: false        // renaming: the panel stays open while the user types
    // the pages keep running while they fade out under the File page
    readonly property bool pagesShown: visible && fileT < 1
    NumberAnimation { id: fileSlide; target: root; property: "fileT"; duration: 320; easing.type: Easing.OutCubic }
    function toggleFile() {
        if (!visible) return;
        fileMode = !fileMode;
        cornerShape.change();
        railPulse.snapAndGo(1.0, 0.0);
        fileSlide.stop();
        fileSlide.to = fileMode ? 1 : 0;
        fileSlide.restart();
        if (fileMode) Qt.callLater(() => { if (fileLoader.item) fileLoader.item.forceActiveFocus(); });
    }
    ListModel { id: crumbModel }
    function syncCrumbs() {
        const next = fileMode || fileT > 0 ? crumbsFor(filePath) : [];
        let k = 0;
        while (k < next.length && k < crumbModel.count && crumbModel.get(k).path === next[k].path) k++;
        if (crumbModel.count > k) crumbModel.remove(k, crumbModel.count - k);
        for (let i = k; i < next.length; i++) crumbModel.append(next[i]);
    }
    onFilePathChanged: syncCrumbs()
    onFileModeChanged: syncCrumbs()
    onFileTChanged: if (fileT === 0) syncCrumbs()
    function fileGo(p) {
        if (p === filePath) return;
        fileHistory = fileHistory.concat([filePath]);
        fileFuture = [];
        filePath = p;
    }
    function fileBack() {
        if (!fileHistory.length) return;
        fileFuture = [filePath].concat(fileFuture);
        filePath = fileHistory[fileHistory.length - 1];
        fileHistory = fileHistory.slice(0, -1);
    }
    function fileForward() {
        if (!fileFuture.length) return;
        fileHistory = fileHistory.concat([filePath]);
        filePath = fileFuture[0];
        fileFuture = fileFuture.slice(1);
    }
    // ---------- drives under the places: the partition in use (/) and plugged-in drives ----------
    // Read by file_tool.py devices while the File page is on; `udisksctl monitor` says when a drive comes or goes (it
    // runs only then). A drive plugged in pops up from the sidebar's foot; one taken out drops back down and is gone.
    readonly property string fileTool: decodeURIComponent(Qt.resolvedUrl("file_tool.py").toString().replace(/^file:\/\//, ""))
    ListModel { id: devModel }      // { dev, mount, removable, fresh (pops up), leaving (drops down) }
    property bool devSynced: false   // the first read shows the drives already there without popping them up
    Process {
        id: devRead
        command: ["python3", root.fileTool, "devices"]
        stdout: StdioCollector { id: devOut }
        onExited: {
            let list = [];
            try { list = JSON.parse(devOut.text.trim()).devices || []; } catch (e) { return; }
            root.syncDevices(list);
        }
    }
    Process {
        id: devWatch
        running: root.visible && root.fileMode
        command: ["udisksctl", "monitor"]
        stdout: SplitParser { onRead: devRetry.restart() }
        onRunningChanged: if (running) devRetry.restart(); else root.devSynced = false
    }
    // a burst of udisks lines for one plug comes as one read
    Timer { id: devRetry; interval: 350; onTriggered: { devRead.running = false; devRead.running = true; } }
    function syncDevices(list) {
        const byDev = {};
        for (const d of list) byDev[d.dev] = d;
        for (let i = 0; i < devModel.count; i++) {
            const m = devModel.get(i), d = byDev[m.dev];
            if (d) { if (m.mount !== d.mount) devModel.setProperty(i, "mount", d.mount); if (m.leaving) devModel.setProperty(i, "leaving", false); }
            else if (!m.leaving) {
                devModel.setProperty(i, "leaving", true);
                if (m.mount !== "" && (filePath === m.mount || filePath.startsWith(m.mount + "/"))) fileGo(fileHome);
            }
            delete byDev[m.dev];
        }
        for (const dev in byDev) {
            const d = byDev[dev];
            devModel.append({ dev: d.dev, mount: d.mount, removable: d.removable, fresh: devSynced && d.removable, leaving: false });
        }
        devSynced = true;
    }
    // The wheel or a swipe over the sidebar steps through the places and the open drives, as it steps through the
    // modules (sideWheel, silent as there): one wheel click or one swipe is one place, stopping at either end. Inside a
    // folder the step starts from the place it is in.
    function stepPlace(dir) {
        const list = filePlaces.map(p => p.path);
        for (let i = 0; i < devModel.count; i++) {
            const d = devModel.get(i);
            if (!d.leaving && d.mount !== "") list.push(d.mount);
        }
        let at = -1, best = -1;
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            const inside = filePath === p || filePath.startsWith(p === "/" ? "/" : p + "/");
            if (inside && p.length > best) { at = i; best = p.length; }
        }
        const next = Math.max(0, Math.min(list.length - 1, at + dir));
        if (next !== at) fileGo(list[next]);
    }
    function devGone(dev) { for (let i = 0; i < devModel.count; i++) if (devModel.get(i).dev === dev && devModel.get(i).leaving) { devModel.remove(i); return; } }
    function devIndexOfMount(p) { for (let i = 0; i < devModel.count; i++) if (devModel.get(i).mount !== "" && devModel.get(i).mount === p) return i; return -1; }

    function closePanel() {
        if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) masterWindow.switchWidget("hidden", "");
    }
    // the topbar path: Home, the Trash or / first, then each folder down to this one
    function crumbsFor(p) {
        let base = "", first = "/";
        if (p === fileTrash || p.startsWith(fileTrash + "/")) { base = fileTrash; first = "Trash"; }
        else if (p === fileHome || p.startsWith(fileHome + "/")) { base = fileHome; first = "Home"; }
        const out = [{ label: first, path: base || "/" }];
        let cur = base;
        for (const part of p.slice(base.length).split("/").filter(x => x !== "")) {
            cur += "/" + part;
            out.push({ label: part, path: cur });
        }
        return out;
    }
    property int page: 0
    property real pagePos: 0
    // Built on demand per page: only the opening page loads on first open (no 9-page simultaneous freeze),
    // and each extra page loads the first time the user visits it and stays cached afterwards.
    property bool built: false
    property var visitedPages: ({})
    function markVisited(id) {
        if (!id || visitedPages[id]) return;
        const next = Object.assign({}, visitedPages);
        next[id] = true;
        visitedPages = next;
    }
    // quiet: wheel clicks and swipes change the page without the switch sound; clicks keep it.
    function setPage(next, quiet) {
        next = Math.max(0, Math.min(pageCount - 1, next));
        if (next === page) return;
        markVisited(order[next]);
        page = next;
        if (!quiet) Sounds.playSfx("reusables/iconbutton/click.wav");
        cornerShape.change();
        railPulse.snapAndGo(1.0, 0.0);
        pageSlide.stop();
        pageSlide.to = next;
        pageSlide.restart();
    }

    NumberAnimation { id: pageSlide; target: root; property: "pagePos"; duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.0 }

    // a changed sidebar keeps the page in range
    onOrderChanged: { pageSlide.stop(); page = Math.max(0, Math.min(page, pageCount - 1)); pagePos = page; }

    onVisibleChanged: {
        PanelLayout.panelShown = visible;
        if (!visible) PanelLayout.releaseStrip(workspaceSlot);
        if (visible) {
            fileSlide.stop();
            fileMode = false;
            fileT = 0;
            // a page asked for when opening (anserin msg open blankpanel network), else the starred module, without a slide
            const asked = typeof masterWindow !== "undefined" ? pageOf(masterWindow.activeArg) : -1;
            const starred = asked !== -1 ? asked : pageOf(PanelLayout.star);
            if (starred !== -1) { pageSlide.stop(); page = starred; pagePos = starred; }
            markVisited(order[page]);
            built = true;
            hoverSeen = panelHover.hovered;
            Qt.callLater(() => railY.snap(root.activeRailTargetY));
            closeSequence.stop();
            if (PanelLayout.expandFromCapsule) {
                PanelLayout.expandFromCapsule = false;
                intro.stop();
                awaitingUnfold = true;
                fromCapsule = true;
                introContent = 0.002;
                contentShown = 1;
                unfoldSafety.restart();
            } else {
                PanelLayout.expandFromCapsule = false;
                PanelLayout.hostStrip(workspaceSlot);
                PanelLayout.hideCapsule();
                awaitingUnfold = false;
                fromCapsule = false;
                contentShown = 1;
                introContent = 0;
                intro.restart();
            }
        } else {
            // closed: the File page goes off and is released (it opens again on the starred module)
            fileSlide.stop();
            fileMode = false;
            fileT = 0;
            intro.stop();
            closeSequence.stop();
            // closed before the capsule finished unfolding: the workspaces stay with the capsule
            awaitingUnfold = false;
            fromCapsule = false;
            unfoldSafety.stop();
            // Release off-screen visited pages immediately on hide so heavy pages (Wallpaper, System, etc.)
            // don't stay mounted; keep only the active page warm during Main's 30 s grace window.
            pageSlide.stop();
            pagePos = page;
            const keep = {};
            if (order[page]) keep[order[page]] = true;
            visitedPages = keep;
        }
    }

    function startExit(onFinished) {
        intro.stop();
        exitCallback = onFinished;
        closeSequence.restart();
    }

    NumberAnimation {
        id: intro; target: root; property: "introContent"; to: 1; duration: 320; easing.type: Easing.OutCubic
        onFinished: if (root.fromCapsule) PanelLayout.hideCapsule()
    }
    // the capsule has unfolded into this shape: show the panel over it as it is, take the workspaces, fade the
    // content in, and let the capsule go a moment later (once this frame is surely on screen)
    function reveal() {
        if (!awaitingUnfold || !visible) return;
        awaitingUnfold = false;
        PanelLayout.hostStrip(workspaceSlot);
        introContent = 0;
        intro.restart();
    }
    // Let the mapped surface paint 2-3 frames before taking over the workspace dots (no 220 ms frozen pause)
    Timer { id: unfoldSafety; interval: 45; onTriggered: root.reveal() }
    SequentialAnimation {
        id: closeSequence
        NumberAnimation { target: root; property: "introContent"; to: 0; duration: 260; easing.type: Easing.InCubic }
        ScriptAction {
            script: {
                const done = root.exitCallback;
                root.exitCallback = null;
                if (done) done();
            }
        }
    }

    HoverHandler {
        id: panelHover
        onHoveredChanged: if (hovered) root.hoverSeen = true
    }
    Timer {
        id: autoHideTimer
        // a little longer while the pointer has not reached the panel yet (it is still on the screen edge)
        interval: root.hoverSeen ? root.autoHideDelay : root.autoHideDelay + 2500
        // not while typing in the Launcher page's search field
        running: root.visible && root.autoHideEnabled && !panelHover.hovered && !closeSequence.running && !root.popupOpen && !PanelLayout.bubbleFull
                 && !root.fileTyping
                 && !(root.page === root.launcherPageIndex && root.launcherTyping)
        onTriggered: {
            if (typeof masterWindow === "undefined" || !masterWindow.switchWidget) return;
            masterWindow.checkPointerOnEdge("left", onEdge => {
                if (panelHover.hovered || root.popupOpen || !root.visible) return;
                if (onEdge) autoHideTimer.restart(); else masterWindow.switchWidget("hidden", "");
            });
        }
    }

    Item {
        id: panel
        anchors.fill: parent
        opacity: root.introContent
        // in place (not slid away) while waiting to slide out from the capsule, so it is drawn where it will show
        transform: Translate { x: root.awaitingUnfold ? 0 : -panel.width * (1 - root.introContent) }

        // Flat on the screen edge and rounded on the inside; the concave joins sit just above and below it.
        EdgeBackground {
            id: body
            y: (parent.height - height) / 2
            x: 0
            width: parent.width
            height: root.s(613)
            edge: "left"
            color: ScreenEdges.modern ? ThemeBackend.base : Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.97)
            cornerRadius: ScreenEdges.modern ? ScreenEdges.rounding : Math.min(ThemeBackend.borderRadius, root.s(28))
        }

        // Topbar and sidebar as one piece: rounded outside, with a concave inner corner like the frame joins.
        Shape {
            id: chrome
            objectName: "blank-panel-chrome"
            // the wider left strip, where the panel meets the screen frame, is kept free for a workspace module
            x: root.s(64)
            y: (parent.height - root.s(613)) / 2 + root.s(12)
            width: parent.width - x - root.s(12)
            height: root.s(613) - root.s(24)
            opacity: root.contentShown
            readonly property real topH: root.s(52)
            readonly property real sideW: root.s(64)
            readonly property real r: Math.min(ThemeBackend.clampedBorderRadius, topH / 2, sideW / 2)
            preferredRendererType: Shape.CurveRenderer
            // Liquid Glass: the topbar and the sidebar as one glass piece, an L joined by the same concave
            // corner as the outline (the union of the two bars, as SurfaceField draws attached surfaces)
            Item {
                id: chromeField
                visible: false
                readonly property real r: chrome.r
                readonly property vector2d origin: Qt.vector2d(0, 0)
                readonly property real smoothing: r
                readonly property real dpr: 1
                readonly property vector4d s0: Qt.vector4d(0, 0, chrome.width, chrome.topH)
                readonly property vector4d s1: Qt.vector4d(chrome.width - chrome.sideW, 0, chrome.sideW, chrome.height)
                readonly property vector4d s2: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d s3: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d s4: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d s5: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d r0: Qt.vector4d(r, r, 0, r)
                readonly property vector4d r1: Qt.vector4d(r, r, r, r)
                readonly property vector4d r2: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d r3: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d r4: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d r5: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d k0: Qt.vector4d(r, r, 0, 0)
                readonly property vector4d k1: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d o0: Qt.vector4d(0, 0, 0, 0)
                readonly property vector4d o1: Qt.vector4d(0, 0, 0, 0)
            }
            GlassFill { id: chromeGlass; anchors.fill: parent; field: chromeField; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }

            ShapePath {
                fillColor: chromeGlass.active ? "transparent" : (root.darkMode ? Qt.darker(ThemeBackend.surface0, 1.38) : Qt.lighter(ThemeBackend.surface0, 1.04))
                strokeWidth: -1
                startX: chrome.r; startY: 0
                PathLine { x: chrome.width - chrome.r; y: 0 }
                PathArc { x: chrome.width; y: chrome.r; radiusX: chrome.r; radiusY: chrome.r }
                PathLine { x: chrome.width; y: chrome.height - chrome.r }
                PathArc { x: chrome.width - chrome.r; y: chrome.height; radiusX: chrome.r; radiusY: chrome.r }
                PathLine { x: chrome.width - chrome.sideW + chrome.r; y: chrome.height }
                PathArc { x: chrome.width - chrome.sideW; y: chrome.height - chrome.r; radiusX: chrome.r; radiusY: chrome.r }
                PathLine { x: chrome.width - chrome.sideW; y: chrome.topH + chrome.r }
                PathArc { x: chrome.width - chrome.sideW - chrome.r; y: chrome.topH; radiusX: chrome.r; radiusY: chrome.r; direction: PathArc.Counterclockwise }
                PathLine { x: chrome.r; y: chrome.topH }
                PathArc { x: 0; y: chrome.topH - chrome.r; radiusX: chrome.r; radiusY: chrome.r }
                PathLine { x: 0; y: chrome.r }
                PathArc { x: chrome.r; y: 0; radiusX: chrome.r; radiusY: chrome.r }
            }
            // subtle darker recessed sidebar channel (Style B)
            ShapePath {
                fillColor: chromeGlass.active ? "transparent" : (root.darkMode ? Qt.rgba(0.0, 0.0, 0.0, 0.26) : Qt.rgba(0.0, 0.0, 0.0, 0.05))
                strokeWidth: -1
                startX: chrome.width - chrome.sideW; startY: chrome.topH
                PathLine { x: chrome.width; y: chrome.topH }
                PathLine { x: chrome.width; y: chrome.height - chrome.r }
                PathArc { x: chrome.width - chrome.r; y: chrome.height; radiusX: chrome.r; radiusY: chrome.r }
                PathLine { x: chrome.width - chrome.sideW + chrome.r; y: chrome.height }
                PathArc { x: chrome.width - chrome.sideW; y: chrome.height - chrome.r; radiusX: chrome.r; radiusY: chrome.r }
                PathLine { x: chrome.width - chrome.sideW; y: chrome.topH }
            }

            // Style B (Kinetic Light-Rail): glowing inner-L fiber-optic rail tracing Topbar -> concave fillet -> active sidebar slot + crisp outer hairline rim
            Canvas {
                id: railCanvas
                anchors.fill: parent
                visible: root.visible
                readonly property var _k: [
                    root.cAccent.toString(), root.cAccent2.toString(), root.darkMode,
                    railY.value, railPulse.value, width, height, chrome.r
                ]
                on_KChanged: if (root.visible) requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    if (width <= 12 || height <= 12) return;

                    const w = width, h = height;
                    const topH = chrome.topH, sideW = chrome.sideW, r = chrome.r;
                    const sx = w - sideW;

                    function traceL() {
                        ctx.beginPath();
                        ctx.moveTo(r, 0);
                        ctx.lineTo(w - r, 0);
                        ctx.arcTo(w, 0, w, r, r);
                        ctx.lineTo(w, h - r);
                        ctx.arcTo(w, h, w - r, h, r);
                        ctx.lineTo(sx + r, h);
                        ctx.arcTo(sx, h, sx, h - r, r);
                        ctx.lineTo(sx, topH + r);
                        ctx.arcTo(sx, topH, sx - r, topH, r);
                        ctx.lineTo(r, topH);
                        ctx.arcTo(0, topH, 0, topH - r, r);
                        ctx.lineTo(0, r);
                        ctx.arcTo(0, 0, r, 0, r);
                        ctx.closePath();
                    }

                    const acc = root.cAccent;
                    const acc2 = root.cAccent2;
                    const pulse = railPulse.value;

                    ctx.save();
                    traceL();
                    ctx.clip();

                    const slotMidY = Math.max(topH + r + root.s(8), railY.value - chrome.y);
                    const railGrad = ctx.createLinearGradient(w * 0.25, topH, sx, slotMidY + root.s(40));
                    railGrad.addColorStop(0.0, "transparent");
                    railGrad.addColorStop(0.45, Qt.rgba(acc2.r, acc2.g, acc2.b, 0.45 + pulse * 0.40));
                    railGrad.addColorStop(0.85, Qt.rgba(acc.r, acc.g, acc.b, 0.92));
                    railGrad.addColorStop(1.0, "transparent");

                    // Pass 1: soft outer luminous halo
                    ctx.beginPath();
                    ctx.moveTo(r + root.s(40), topH - 1.5);
                    ctx.lineTo(sx - r, topH - 1.5);
                    ctx.arcTo(sx + 1.5, topH - 1.5, sx + 1.5, topH + r, r + 1.5);
                    ctx.lineTo(sx + 1.5, Math.min(h - r, slotMidY + root.s(42)));
                    ctx.lineWidth = root.s(7);
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(acc.r, acc.g, acc.b, 0.18 + pulse * 0.22);
                    ctx.stroke();

                    // Pass 2: crisp inner fiber-optic gradient beam
                    ctx.beginPath();
                    ctx.moveTo(r + root.s(60), topH - 1.5);
                    ctx.lineTo(sx - r, topH - 1.5);
                    ctx.arcTo(sx + 1.5, topH - 1.5, sx + 1.5, topH + r, r + 1.5);
                    ctx.lineTo(sx + 1.5, Math.min(h - r, slotMidY + root.s(34)));
                    ctx.lineWidth = root.s(2.4);
                    ctx.strokeStyle = railGrad;
                    ctx.stroke();

                    ctx.restore();

                    // Crisp outer L-shape hairline rim
                    traceL();
                    ctx.lineWidth = 1.3;
                    ctx.strokeStyle = root.darkMode ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10);
                    ctx.stroke();
                }
            }
        }

        // In the topbar's rounded corner over the sidebar, with Style B halo pulse ring and clickable morph.
        Item {
            id: cornerHub
            opacity: root.contentShown
            x: chrome.x + chrome.width - chrome.sideW * 0.5 - width * 0.5
            y: chrome.y + chrome.topH * 0.5 - height * 0.5
            width: root.s(36)
            height: root.s(36)

            Rectangle {
                anchors.centerIn: parent
                width: root.s(34) + railPulse.value * root.s(10)
                height: width
                radius: width * 0.5
                color: "transparent"
                border.width: 1.4
                border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.35 + railPulse.value * 0.5)
            }

            MorphShape {
                id: cornerShape
                anchors.centerIn: parent
                width: root.s(26)
                height: root.s(26)
                color: root.cAccent
                color2: root.cAccent2
                active: root.visible && root.introContent > 0.95
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    cornerShape.change();
                    railPulse.snapAndGo(1.0, 0.0);
                    Sounds.playSfx("system/quick_click.wav");
                }
            }
        }

        // Edit panel, at the left end of the topbar (spring bounce + accent hover).
        Item {
            id: editButton
            opacity: root.contentShown
            x: chrome.x + (chrome.topH - width) / 2
            y: chrome.y + (chrome.topH - height) / 2
            width: root.s(32); height: width
            Smart.SpringVal { id: edSc; target: editMa.pressed ? 0.86 : (editMa.containsMouse ? 1.08 : 1.0); stiffness: 520; damping: 0.42; eps: 0.001 }
            scale: edSc.value
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: editMa.containsMouse
                    ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                    : (root.darkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.06))
                border.width: editMa.containsMouse ? 1 : 0
                border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.42)
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            Text {
                anchors.centerIn: parent
                text: "󰏫"
                font.family: ThemeBackend.iconFont
                font.pixelSize: root.s(15)
                color: editMa.containsMouse ? root.cAccent : ThemeBackend.subtext0
            }
            MouseArea {
                id: editMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    edSc.kick(1.2);
                    Sounds.playSfx("reusables/clickbutton/click.wav");
                    if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) masterWindow.switchWidget("hidden", "");
                    PanelLayout.startEdit(root.screenName);
                }
            }
        }

        // The File page toggle, right of the pencil: morphs circle <-> squircle with accent gradient when File mode is ON.
        Item {
            id: folderButton
            opacity: root.contentShown
            x: editButton.x + editButton.width + root.s(6)
            y: editButton.y
            width: root.s(32); height: width
            Smart.SpringVal { id: flSc; target: folderMa.pressed ? 0.86 : (folderMa.containsMouse ? 1.08 : 1.0); stiffness: 520; damping: 0.42; eps: 0.001 }
            Smart.SpringVal { id: flGeoM; target: root.fileMode ? 1.0 : 0.0; stiffness: 420; damping: 0.44; eps: 0.002 }
            scale: flSc.value
            Smart.SmartGeoShape {
                anchors.fill: parent
                fromShape: "circle"
                toShape: "squircle"
                morph: flGeoM.value
                fill: root.fileMode
                    ? root.cAccent
                    : (folderMa.containsMouse
                        ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.18)
                        : (root.darkMode ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.06)))
                fill2: root.fileMode ? root.cAccent2 : "transparent"
            }
            Text {
                anchors.centerIn: parent
                text: root.fileMode ? "󰝰" : "󰉋"
                font.family: ThemeBackend.iconFont
                font.pixelSize: root.s(15)
                color: root.fileMode ? root.cOnAccent : (folderMa.containsMouse ? root.cAccent : ThemeBackend.subtext0)
            }
            MouseArea {
                id: folderMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    flSc.kick(1.25);
                    Sounds.playSfx(root.fileMode ? "reusables/toggle/sfx.wav" : "reusables/switch/sfx.wav");
                    root.toggleFile();
                }
            }
        }

        QtObject {
            id: moduleHost
            property bool moduleActive: root.visible
            property bool isCompact: false
            property bool isRightBar: false
            property bool cloudOnly: true
            property var barWindow: ({ s: v => root.s(v), visible: root.visible, isStartupReady: true, isDataReady: true, startupCascadeFinished: true,
                                       screen: typeof masterWindow !== "undefined" ? masterWindow.screen : null })
        }

        // The bar's clock, styled by the Time & Date settings (Control Center → Panel), in the middle of the topbar; display only.
        Loader {
            x: chrome.x + (chrome.width - width) / 2
            y: chrome.y
            width: item ? item.implicitWidth : 0
            height: chrome.topH
            opacity: root.contentShown * (1 - root.fileT)
            active: root.built
            visible: root.fileT < 1
            enabled: false
            source: "../bar/faces/timedate/TimeDateFace.qml"
            onLoaded: item.module = moduleHost
        }

        // On the File page the clock gives way to the path: one button per folder, the last one in bold, centred like
        // the clock while it fits, else scrolled to its end (the wheel scrolls it back). A double click on one of them
        // (pathZone) slides the buttons away for the whole path as text.
        ListView {
            id: crumbs
            visible: root.fileT > 0
            enabled: root.fileMode && pathZone.fullT < 0.5
            opacity: root.contentShown * root.fileT * (1 - pathZone.fullT)
            transform: Translate { x: -crumbs.width * 0.3 * pathZone.fullT }
            x: folderButton.x + folderButton.width + root.s(10)
            y: chrome.y
            width: cornerHub.x - root.s(10) - x
            height: chrome.topH
            orientation: ListView.Horizontal
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            spacing: root.s(2)
            model: crumbModel
            leftMargin: Math.max(0, chrome.x + chrome.width / 2 - contentWidth / 2 - x)
            Behavior on leftMargin { enabled: root.fileT === 1; NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            onCountChanged: Qt.callLater(positionViewAtEnd)
            // a folder gone into slides in from the left; one left fades out
            add: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.85; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            }
            remove: Transition {
                NumberAnimation { property: "opacity"; to: 0; duration: 140; easing.type: Easing.InQuad }
            }
            displaced: Transition { NumberAnimation { property: "x"; duration: 260; easing.type: Easing.OutCubic } }
            delegate: Row {
                id: crumb
                required property string label
                required property string path
                required property int index
                height: crumbs.height
                spacing: root.s(2)
                Text {
                    visible: crumb.index > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "›"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(14)
                    color: ThemeBackend.subtext1
                }
                Rectangle {
                    readonly property bool last: crumb.index === crumbs.count - 1
                    anchors.verticalCenter: parent.verticalCenter
                    width: crumbLabel.implicitWidth + root.s(14)
                    height: root.s(28)
                    radius: height / 2
                    color: crumbMa.containsMouse ? ThemeBackend.surface1 : "transparent"
                    scale: crumbMa.pressed ? 0.92 : 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuart } }
                    Text {
                        id: crumbLabel
                        anchors.centerIn: parent
                        text: crumb.label
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(13)
                        font.bold: parent.last
                        color: parent.last || crumbMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                    }
                    // a click goes to the folder a moment later, unless a second one follows: a double click shows the
                    // whole path instead (pathZone)
                    MouseArea {
                        id: crumbMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (pathZone.clickWait.running && pathZone.clickPath === crumb.path) {
                                pathZone.clickWait.stop();
                                pathZone.full = true;
                                return;
                            }
                            Sounds.playSfx("reusables/clickbutton/click.wav");
                            pathZone.clickPath = crumb.path;
                            pathZone.clickWait.restart();
                        }
                    }
                }
            }
        }

        // The whole path in place of the folder buttons after a double click on one of them: the buttons slide away to
        // the left and the path slides in from the right, centred while it fits, else at its end (the wheel scrolls it
        // back); a click copies it (wl-copy) and says so. The pointer leaving puts the buttons back.
        Item {
            id: pathZone
            x: crumbs.x; y: crumbs.y
            width: crumbs.width; height: crumbs.height
            visible: crumbs.visible
            property bool full: false
            property real fullT: full ? 1 : 0
            Behavior on fullT { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            HoverHandler { id: pathHover; enabled: root.fileMode; onHoveredChanged: if (!hovered) pathZone.full = false }
            // a folder button's click waits this long for a second one before going to the folder
            property string clickPath: ""
            readonly property Timer clickWait: Timer { interval: 250; onTriggered: root.fileGo(pathZone.clickPath) }
            onFullChanged: if (full) Qt.callLater(() => pathFlick.contentX = Math.max(-pathFlick.leftMargin, pathFlick.contentWidth - pathFlick.width))
            property bool copied: false
            Timer { id: copiedTimer; interval: 1300; onTriggered: pathZone.copied = false }

            Flickable {
                id: pathFlick
                anchors.fill: parent
                visible: pathZone.fullT > 0
                enabled: pathZone.full
                opacity: root.contentShown * root.fileT * pathZone.fullT
                transform: Translate { x: pathFlick.width * 0.3 * (1 - pathZone.fullT) }
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick
                contentWidth: pathPill.width
                contentHeight: height
                leftMargin: Math.max(0, chrome.x + chrome.width / 2 - pathPill.width / 2 - pathZone.x)
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (e) => {
                        const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y;
                        pathFlick.contentX = Math.min(Math.max(-pathFlick.leftMargin, pathFlick.contentWidth - pathFlick.width),
                                                      Math.max(-pathFlick.leftMargin, pathFlick.contentX - d));
                    }
                }
                Rectangle {
                    id: pathPill
                    anchors.verticalCenter: parent.verticalCenter
                    width: pathText.implicitWidth + root.s(18)
                    height: root.s(28)
                    radius: height / 2
                    color: pathMa.containsMouse ? ThemeBackend.surface1 : "transparent"
                    scale: pathMa.pressed ? 0.96 : 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuart } }
                    Text {
                        id: pathText
                        anchors.centerIn: parent
                        text: pathZone.copied ? "Copied" : root.filePath
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(13)
                        font.bold: pathZone.copied
                        color: pathZone.copied ? ThemeBackend.mauve : ThemeBackend.text
                    }
                    MouseArea {
                        id: pathMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sounds.playSfx("reusables/clickbutton/click.wav");
                            Quickshell.execDetached(["wl-copy", "--", root.filePath]);
                            pathZone.copied = true;
                            copiedTimer.restart();
                        }
                    }
                }
            }
        }

        // The bar's vertical workspaces, centred in the left strip along the screen frame. Clicks and the wheel
        // switch workspace as they do on the bar, and the panel stays open.
        // The sidebar's two sets, cut at its top and foot: the modules, and on the File page the places.
        // The folder button slides the modules down out while the places come down in behind them, and back up.
        Item {
            id: sideClip
            y: chrome.y + chrome.topH
            width: panel.width
            height: chrome.height - chrome.topH
            clip: true
            Item {
                id: sideInner
                y: -sideClip.y
                width: panel.width
                height: panel.height
                Item {
                    id: moduleLayer
                    width: parent.width
                    height: parent.height
                    visible: root.fileT < 1
                    transform: Translate { y: root.fileT * sideClip.height }

        // Style B: Illuminated rounded-square capsule behind the active module
        Rectangle {
            id: activeModuleHighlight
            readonly property int cell: PanelLayout.cells.indexOf(root.order[root.page] || "-")
            readonly property Item slot: cell >= 0 && moduleRepeater.count > cell ? moduleRepeater.itemAt(cell) : null
            readonly property real slotY: slot ? moduleColumn.y + slot.y : 0
            visible: slot !== null
            opacity: root.contentShown
            x: moduleColumn.x + root.s(9)
            y: slotY - root.s(5)
            width: moduleColumn.width - root.s(17)
            height: slot ? slot.height + root.s(10) : 0
            radius: Math.min(ThemeBackend.clampedBorderRadius, root.s(14))
            color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.22)
            border.width: 1.4
            border.color: root.cAccent
            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        }

        // Liquid Glass: a lens slides to the module under the pointer (not the page already in use)
        GlassLens {
            id: moduleLens
            readonly property Item slot: moduleColumn.hoverSlot
            shown: root.contentShown > 0.5
            targetX: moduleColumn.x + root.s(6)
            targetY: slot ? moduleColumn.y + slot.y - root.s(6) : 0
            targetWidth: slot ? moduleColumn.width - root.s(12) : 0
            targetHeight: slot ? slot.height + root.s(12) : 0
            radius: ThemeBackend.clampedBorderRadius
            tintColor: ThemeBackend.surface1
            tintAmount: 0.25
            shadow: 0
            restPress: 0.2
            magnify: root.s(4)
            press: slot && slot.pressed ? 0.8 : 0
        }

        // The bar's modules, showing the same live data; here a click only changes the page.
        Column {
            id: moduleColumn
            property Item hoverSlot: null
            opacity: root.contentShown
            x: chrome.x + chrome.width - chrome.sideW
            y: chrome.y + chrome.topH + root.s(24)
            width: chrome.sideW
            spacing: root.s(8)
            // empty cells share what the modules leave, down to the foot of the sidebar (as in Edit panel)
            property var heights: ({})
            // module heights are noted after the layout settles (noting them while it is worked out loops)
            function noteHeight(id, h) {
                if (heights[id] === h) return;
                const next = Object.assign({}, heights); next[id] = h; heights = next;
            }
            readonly property var cellLayout: PanelLayout.cellLayout(chrome.height - chrome.topH - root.s(24) - root.s(12), spacing, heights, root.s(PanelLayout.emptyCell))
            readonly property real emptyH: cellLayout.emptyH
            Repeater {
                id: moduleRepeater
                // the cells chosen in Edit panel; an empty one keeps a gap
                model: moduleColumn.cellLayout.count
                Item {
                    id: moduleSlot
                    required property int index
                    readonly property string modelData: PanelLayout.cells[index] || ""
                    readonly property bool empty: modelData === ""
                    readonly property var info: empty ? ({}) : PanelLayout.modules[modelData]
                    readonly property bool starred: !empty && PanelLayout.star === modelData
                    width: parent.width
                    height: empty ? moduleColumn.emptyH : face.height
                    // the starred module: a soft ring and a small star
                    Rectangle {
                        visible: moduleSlot.starred
                        anchors.centerIn: parent
                        width: parent.width - root.s(12)
                        height: parent.height + root.s(12)
                        radius: ThemeBackend.clampedBorderRadius
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.alpha(ThemeBackend.mauve, 0.55)
                    }
                    Text {
                        visible: moduleSlot.starred
                        anchors.right: parent.right; anchors.rightMargin: root.s(8)
                        anchors.top: parent.top; anchors.topMargin: -root.s(4)
                        text: "󰓎"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: root.s(11)
                        color: ThemeBackend.mauve
                    }
                    // a bar module where there is one (the Launcher button is kept enabled so it is not dimmed;
                    // the click still lands on the area above it), else the module's icon
                    Loader {
                        id: face
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.s(40)
                        height: item ? item.implicitHeight : 0
                        asynchronous: true
                        active: root.built && !moduleSlot.empty
                        enabled: moduleSlot.info.live === true
                        source: moduleSlot.info.face || "SideIconFace.qml"
                        onLoaded: {
                            item.module = moduleHost;
                            if (!moduleSlot.info.face) item.glyph = moduleSlot.info.icon;
                        }
                        onHeightChanged: if (!moduleSlot.empty && height > 0) Qt.callLater(moduleColumn.noteHeight, moduleSlot.modelData, height)
                    }
                    readonly property bool pressed: slotMa.pressed
                    readonly property bool lensWanted: slotHover.hovered && !empty && root.order[root.page] !== modelData
                    onLensWantedChanged: {
                        if (lensWanted) moduleColumn.hoverSlot = moduleSlot;
                        else if (moduleColumn.hoverSlot === moduleSlot) moduleColumn.hoverSlot = null;
                    }
                    Component.onDestruction: if (moduleColumn.hoverSlot === moduleSlot) moduleColumn.hoverSlot = null
                    // a HoverHandler, so the bar module below still gets its own hover
                    HoverHandler { id: slotHover }
                    MouseArea {
                        id: slotMa
                        anchors.fill: parent
                        enabled: !moduleSlot.empty
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setPage(root.pageOf(moduleSlot.modelData))
                    }
                }
            }
        }

                }

                // the places, as the modules' icons; the place shown has the
                // page-in-use highlight (it slides from place to place), the one under the pointer the glass lens
                Item {
                    id: placeLayer
                    width: parent.width
                    height: parent.height
                    visible: root.fileT > 0
                    opacity: root.contentShown
                    transform: Translate { y: (root.fileT - 1) * sideClip.height }

                    Rectangle {
                        id: activePlaceHighlight
                        readonly property int cell: {
                            for (let i = 0; i < root.filePlaces.length; i++)
                                if (root.filePlaces[i].path === root.filePath) return i;
                            return -1;
                        }
                        readonly property int devCell: cell < 0 ? root.devIndexOfMount(root.filePath) : -1
                        readonly property Item slot: cell >= 0 && placeRepeater.count > cell ? placeRepeater.itemAt(cell)
                                                   : devCell >= 0 && devRepeater.count > devCell ? devRepeater.itemAt(devCell) : null
                        opacity: slot ? 1 : 0
                        x: placeColumn.x + root.s(9)
                        y: placeColumn.y + (slot ? slot.y : 0) - root.s(4)
                        width: placeColumn.width - root.s(17)
                        height: root.s(44) + root.s(8)
                        radius: Math.min(ThemeBackend.clampedBorderRadius, root.s(14))
                        color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.22)
                        border.width: 1.4
                        border.color: root.cAccent
                        Behavior on y { enabled: root.fileT === 1; NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    }
                    GlassLens {
                        readonly property Item slot: placeColumn.hoverSlot
                        shown: root.contentShown > 0.5 && root.fileT === 1
                        targetX: placeColumn.x + root.s(6)
                        targetY: slot ? placeColumn.y + slot.y - root.s(6) : 0
                        targetWidth: slot ? placeColumn.width - root.s(12) : 0
                        targetHeight: slot ? slot.height + root.s(12) : 0
                        radius: ThemeBackend.clampedBorderRadius
                        tintColor: ThemeBackend.surface1
                        tintAmount: 0.25
                        shadow: 0
                        restPress: 0.2
                        magnify: root.s(4)
                        press: slot && slot.pressed ? 0.8 : 0
                    }

                    Column {
                        id: placeColumn
                        property Item hoverSlot: null
                        x: chrome.x + chrome.width - chrome.sideW
                        y: chrome.y + chrome.topH + root.s(24)
                        width: chrome.sideW
                        spacing: root.s(8)
                        Repeater {
                            id: placeRepeater
                            model: root.filePlaces
                            Item {
                                id: placeSlot
                                required property var modelData
                                readonly property bool current: root.filePath === modelData.path
                                readonly property bool pressed: placeMa.pressed
                                readonly property bool lensWanted: placeMa.containsMouse && !current
                                onLensWantedChanged: {
                                    if (lensWanted) placeColumn.hoverSlot = placeSlot;
                                    else if (placeColumn.hoverSlot === placeSlot) placeColumn.hoverSlot = null;
                                }
                                Component.onDestruction: if (placeColumn.hoverSlot === placeSlot) placeColumn.hoverSlot = null
                                width: placeColumn.width
                                height: root.s(44)
                                Text {
                                    anchors.centerIn: parent
                                    text: placeSlot.modelData.glyph
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(17)
                                    color: placeSlot.current ? ThemeBackend.mauve
                                         : placeMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                    scale: placeMa.pressed ? 0.88 : 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuart } }
                                }
                                MouseArea {
                                    id: placeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        Sounds.playSfx("reusables/clickbutton/click.wav");
                                        root.fileGo(placeSlot.modelData.path);
                                    }
                                }
                            }
                        }
                        // a thin line, then the drives
                        Item {
                            width: placeColumn.width
                            height: root.s(1)
                            visible: devModel.count > 0
                            Rectangle { anchors.centerIn: parent; width: root.s(24); height: root.s(1); color: ThemeBackend.surface1 }
                        }
                        Repeater {
                            id: devRepeater
                            model: devModel
                            Item {
                                id: devSlot
                                required property string dev
                                required property string mount
                                required property bool removable
                                required property bool fresh
                                required property bool leaving
                                readonly property bool current: mount !== "" && root.filePath === mount
                                readonly property bool pressed: devMa.pressed
                                readonly property bool lensWanted: devMa.containsMouse && !current && !leaving
                                onLensWantedChanged: {
                                    if (lensWanted) placeColumn.hoverSlot = devSlot;
                                    else if (placeColumn.hoverSlot === devSlot) placeColumn.hoverSlot = null;
                                }
                                Component.onDestruction: if (placeColumn.hoverSlot === devSlot) placeColumn.hoverSlot = null
                                width: placeColumn.width
                                height: root.s(44)
                                // 0 in place, 1 just below the sidebar's foot: a drive plugged in comes up, one taken out goes down
                                property real drop: fresh ? 1 : 0
                                Component.onCompleted: if (fresh) popUp.start()
                                onLeavingChanged: if (leaving) { popUp.stop(); dropDown.start(); }
                                NumberAnimation { id: popUp; target: devSlot; property: "drop"; to: 0; duration: 460; easing.type: Easing.OutBack }
                                SequentialAnimation {
                                    id: dropDown
                                    NumberAnimation { target: devSlot; property: "drop"; to: 1; duration: 320; easing.type: Easing.InBack }
                                    ScriptAction { script: root.devGone(devSlot.dev) }
                                }
                                transform: Translate { y: devSlot.drop * Math.max(0, chrome.y + chrome.height - placeColumn.y - devSlot.y) }
                                Text {
                                    anchors.centerIn: parent
                                    text: devSlot.removable ? "󱊞" : "󰋊"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: root.s(17)
                                    color: devSlot.current ? ThemeBackend.mauve
                                         : devMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                    scale: devMa.pressed ? 0.88 : 1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuart } }
                                }
                                MouseArea {
                                    id: devMa
                                    anchors.fill: parent
                                    enabled: !devSlot.leaving
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (m) => {
                                        if (!fileLoader.item) return;
                                        if (m.button === Qt.RightButton) {
                                            if (!devSlot.removable) return;
                                            const p = devSlot.mapToItem(fileLoader.item, 0, devSlot.height / 2);
                                            fileLoader.item.driveMenu(devSlot.dev, devSlot.mount, p.y);
                                            return;
                                        }
                                        Sounds.playSfx("reusables/clickbutton/click.wav");
                                        fileLoader.item.openDrive(devSlot.dev, devSlot.mount);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            // Style B: Glowing spring vertical pill indicator hugging the left inner edge of the sidebar!
            Rectangle {
                id: lightRailPill
                visible: root.contentShown > 0.05 && (root.fileMode ? activePlaceHighlight.slot !== null : activeModuleHighlight.slot !== null)
                opacity: root.contentShown
                x: chrome.x + chrome.width - chrome.sideW + root.s(1.5)
                y: Math.max(root.s(8), Math.min(sideClip.height - height - root.s(8), railY.value - sideClip.y - height * 0.5))
                width: root.s(3)
                height: root.s(26)
                radius: width * 0.5
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: root.cAccent }
                    GradientStop { position: 1.0; color: root.cAccent2 }
                }
            }
        }

        // Wheel clicks and swipes over the whole sidebar, empty space included, change the page; over the
        // page itself they scroll its own content. A wheel click is one event of a whole multiple of 120;
        // a touchpad swipe counts once, however long it runs.
        Item {
            id: sideWheel
            // on the File page the same wheel and swipes step through the places instead of the pages
            x: chrome.x + chrome.width - chrome.sideW
            y: chrome.y + chrome.topH
            width: chrome.sideW
            height: chrome.height - chrome.topH

            property real wheelAcc: 0
            function step(dir) { if (root.fileMode) root.stepPlace(dir); else root.setPage(root.page + dir, true); }
            function scrolled(e, horizontal) {
                const x = e.angleDelta.x, y = e.angleDelta.y;
                if (horizontal !== (Math.abs(x) >= Math.abs(y))) return;
                const d = horizontal ? x : y;
                if (d === 0) return;
                if (!swipeIdle.running && Math.abs(d) % 120 === 0) { step(d < 0 ? 1 : -1); return; }
                if (Math.abs(d) >= 120) return;
                const locked = swipeIdle.locked;
                swipeIdle.restart();
                if (locked) return;
                wheelAcc += d;
                if (Math.abs(wheelAcc) < 120) return;
                step(wheelAcc < 0 ? 1 : -1);
                wheelAcc = 0;
                swipeIdle.locked = true;
            }
            Timer {
                id: swipeIdle
                property bool locked: false
                interval: 220
                onTriggered: { locked = false; sideWheel.wheelAcc = 0; }
            }
            WheelHandler {
                orientation: Qt.Vertical
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => sideWheel.scrolled(e, false)
            }
            WheelHandler {
                orientation: Qt.Horizontal
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => sideWheel.scrolled(e, true)
            }
        }

        // ---------- the pages ----------
        Item {
            id: host
            objectName: "blank-panel-page"
            opacity: root.contentShown
            x: chrome.x
            y: chrome.y + chrome.topH + root.s(12)
            width: chrome.width - chrome.sideW - root.s(12)
            height: chrome.height - chrome.topH - root.s(12)
            clip: true

            Item {
                id: holder
                width: parent.width
                height: parent.height
                // the File page and the pages cross-fade with the sidebar's slide, each drifting the sidebar's way
                visible: root.fileT < 1
                opacity: 1 - root.fileT
                transform: Translate { y: root.s(24) * root.fileT }
                Repeater {
                    model: root.order
                    Loader {
                        id: pageLoader
                        required property string modelData
                        required property int index
                        readonly property bool inView: root.pagesShown && Math.abs(index - root.pagePos) < 1
                        readonly property bool isCurrent: root.pagesShown && root.page === index
                        readonly property string pageUrl: ({
                            music: "pages/MusicHostPage.qml",
                            weather: "pages/WeatherHostPage.qml",
                            network: "pages/NetworkHostPage.qml",
                            launcher: "../launcher/LauncherContent.qml",
                            timer: "pages/TimerHostPage.qml",
                            system: "pages/SystemPage.qml",
                            user: "pages/UserPage.qml",
                            wallpaper: "pages/WallpaperPage.qml",
                            calculator: "pages/CalculatorHostPage.qml"
                        })[modelData] || ""
                        width: parent.width
                        height: parent.height
                        y: (index - root.pagePos) * parent.height
                        asynchronous: true
                        active: root.built && (Math.abs(index - root.pagePos) < 1 || !!root.visitedPages[modelData])
                        visible: Math.abs(index - root.pagePos) < 1
                        function loadNow() {
                            if (!active || pageUrl === "") return;
                            const props = modelData === "wallpaper" ? { panel: root } : {};
                            setSource(Qt.resolvedUrl(pageUrl), props);
                        }
                        Component.onCompleted: loadNow()
                        onActiveChanged: loadNow()
                        onLoaded: {
                            if (!item) return;
                            if ("panel" in item && modelData !== "wallpaper") item.panel = root;
                            if ("screenName" in item) item.screenName = Qt.binding(() => root.screenName);
                            if (modelData === "weather" || modelData === "network") {
                                item.active = Qt.binding(() => pageLoader.inView);
                            } else if ("active" in item) {
                                item.active = Qt.binding(() => pageLoader.isCurrent);
                            }
                            if (modelData === "launcher") {
                                item.autoFocus = false;
                                item.searchFocusedChanged.connect(() => { root.launcherTyping = item.searchFocused; });
                                item.closeRequested.connect(() => {
                                    if (typeof masterWindow !== "undefined" && masterWindow.switchWidget) masterWindow.switchWidget("hidden", "");
                                });
                            }
                        }
                    }
                }
            }

            // the File page, in place of the pages while the folder button is on (compiled only when opened)
            Loader {
                id: fileLoader
                anchors.fill: parent
                active: root.fileMode || root.fileT > 0
                visible: root.fileT > 0
                opacity: root.fileT
                asynchronous: true
                transform: Translate { y: -root.s(24) * (1 - root.fileT) }
                onActiveChanged: {
                    if (active) setSource(Qt.resolvedUrl("FilePage.qml"), { panel: root });
                }
                onLoaded: {
                    if (!item) return;
                    item.active = Qt.binding(() => root.visible && root.fileMode);
                    if (root.fileMode) item.forceActiveFocus();
                }
            }
        }
    }

    // The one set of workspaces (PanelLayout.strip), close to the frame, exactly where the capsule has them. Above
    // the panel and outside its slide: opened from the capsule they stay still while the panel slides out under
    // them; otherwise they slide and fade with the panel.
    Item {
        id: workspaceSlot
        x: PanelLayout.workspaceX - root.screenX
        y: body.y + (body.height - height) / 2
        width: root.s(40)
        height: PanelLayout.strip ? PanelLayout.strip.height : 0
        opacity: root.fromCapsule ? 1 : root.introContent
        transform: Translate { x: root.fromCapsule ? 0 : -panel.width * (1 - root.introContent) }
    }

}
