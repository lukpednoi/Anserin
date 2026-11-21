import QtQuick
import "../../"
import QtQuick.Layouts
import "."
import "RadarMath.js" as RadarMath

/**
 * Interactive Radar View (565×525) used on both comparison windows [1/2] & [2/2]:
 *   - World-anchored Host button at (40, 40): moves with world when scrolling horizontally,
 *     hides temporarily during password zoom, and returns to Connected UI on click
 *   - 4 concentric radar rings centered on Host (r = 135, 245, 355, 465)
 *   - Non-connected networks constrained strictly to Ring 3+ (dist >= 374px); active connected
 *     network parks smoothly between Ring 1 and Ring 2 with a glowing solid tether line
 *   - Switching/connecting a new network pulls the new one into Ring 1-2, releases the old one
 *     back out to Ring 3+, plays connect SFX, and enters Connected UI
 *   - Smooth 60FPS potential-field + Laplacian obstacle-avoiding curves (no sharp kinks)
 *   - Sound profile "A" vs "B" driven through store.playProfileSfx()
 */
Item {
    id: view

    required property NetworkStore store
    property color accentColor: ThemeBackend.mauve
    property bool active: true
    property bool winVisible: true

    focus: active && phase === "zoomIn"
    Keys.onEscapePressed: {
        if (view.phase === "zoomIn") {
            view.cancelZoomPrompt();
        }
    }

    // "idle" | "panToHost" | "dwellAtHost" | "slither" | "holdingImpact" | "zoomIn" | "zoomOutError" | "retractError" | "zoomOutSuccess" | "pullToRing2"
    property string phase: "idle"
    property string hoveredId: ""
    property string actionTargetId: ""
    property string pwdTargetId: ""
    property bool pwdExpanded: false
    property string unlockedId: ""
    property string failedRedId: ""
    property bool retractIsCancel: false
    property string impactPulseId: ""
    property real impactPulseProg: 0.0

    // Hide Host & TopRightModeSwitcher temporarily while locked password drawer is open / zooming
    readonly property bool hideTopChrome: phase === "zoomIn"
        || (phase === "zoomOutError" && Math.abs(camZ - 1.0) > 0.05)
        || (phase === "zoomOutSuccess" && Math.abs(camZ - 1.0) > 0.05)

    // BubbleMonitor-style camera transform & world horizontal scroll
    property real scrollX: 0.0
    property real scrollTargetX: 0.0
    property real camX: 282.5
    property real camY: 262.5
    property real camZ: 1.0
    property real zoomFocusX: 282.5
    property real zoomFocusY: 262.5
    property real zoomTargetZ: 1.0

    property real dashOffsetTime: 0.0
    property real slitherProg: 0.0
    property real retractProg: 1.0
    property real introProg: 1.0
    property real openTetherProg: 1.0

    property var _nodes: []
    property var _cachedBeam: null
    property var _pinnedActiveCoords: ({ wifi: ({}), bt: ({}) })
    property string _lastMode: ""
    property real _floatClock: 0.0

    // Host lives inside worldLayer centered at (40, 40)
    readonly property real hostWorldX: 40.0
    readonly property real hostWorldY: 40.0
    readonly property var ringRadii: [135, 245, 355, 465, 575]
    readonly property real minOuterRadius: 596.0

    signal focusPwdRequested(string uid)
    signal clearPwdRequested(string uid)

    function smoothK(dt, tau) {
        return tau > 0.0001 ? (1.0 - Math.exp(-dt / tau)) : 1.0;
    }

    function easeOutCubic(t) {
        const c = Math.max(0.0, Math.min(1.0, t));
        return 1.0 - Math.pow(1.0 - c, 3);
    }

    function easeOutBack(t) {
        const c = Math.max(0.0, Math.min(1.0, t));
        const c1 = 1.70158;
        const c3 = c1 + 1;
        return 1 + c3 * Math.pow(c - 1, 3) + c1 * Math.pow(c - 1, 2);
    }

    function easeInCubic(t) {
        const c = Math.max(0.0, Math.min(1.0, t));
        return c * c * c;
    }

    function findNodeIdx(uid) {
        for (let i = 0; i < _nodes.length; i++) {
            if (_nodes[i].uid === uid) return i;
        }
        return -1;
    }

    function findModelIdx(uid) {
        for (let i = 0; i < nodeModel.count; i++) {
            if (nodeModel.get(i).uid === uid) return i;
        }
        return -1;
    }

    function isItemConnected(item) {
        if (!item) return false;
        if (phase === "pullToRing2" && item.id === actionTargetId) return true;
        if (store.activeMode === "wifi") {
            if (phase === "pullToRing2" && actionTargetId !== "") return false;
            return !!item.connected;
        }
        return !!item.connected;
    }

    function estimateWidth(item) {
        const txtLen = (item.name || "").length;
        const hasGlyph = (store.activeMode === "bt") || !!item.locked;
        return Math.round(58 + txtLen * 7.6 + (hasGlyph ? 18 : 0));
    }

    function computeOuterSlot(outerIdx) {
        // Every non-connected slot starts strictly outside Ring 5 (r = 575 + clearance >= 596px from Host)
        const presets = [
            { x: 642, y: 146 }, // dist ≈ 611 (Ring 5+)
            { x: 668, y: 268 }, // dist ≈ 668
            { x: 622, y: 394 }, // dist ≈ 680
            { x: 794, y: 186 }  // dist ≈ 768
        ];
        if (outerIdx < presets.length) {
            return { x: presets[outerIdx].x, y: presets[outerIdx].y };
        }
        const extraIdx = outerIdx - presets.length;
        const col = Math.floor(extraIdx / 2);
        const row = extraIdx % 2;
        return {
            x: 842 + col * 195 + row * 52,
            y: row === 0 ? 156 : 346
        };
    }

    function activeRingSpot(uid, connSlotIdx) {
        const mode = store.activeMode;
        const savedMap = _pinnedActiveCoords[mode] || {};
        if (savedMap[uid]) {
            return { x: savedMap[uid].x, y: savedMap[uid].y };
        }
        if (mode === "wifi") {
            const angle = 0.68;
            return {
                x: hostWorldX + Math.cos(angle) * 190.0,
                y: hostWorldY + Math.sin(angle) * 190.0
            };
        }
        // Bluetooth supports multiple simultaneous connected devices cleanly spread between Ring 1 (135) & Ring 2 (245)
        const btSlots = [
            { x: 224, y: 118 }, // dist ≈ 200
            { x: 142, y: 210 }, // dist ≈ 198
            { x: 220, y: 184 }, // dist ≈ 230
            { x: 102, y: 216 }  // dist ≈ 187
        ];
        if (connSlotIdx < btSlots.length) {
            return { x: btSlots[connSlotIdx].x, y: btSlots[connSlotIdx].y };
        }
        const ang = 0.25 + ((connSlotIdx % 6) / 5.0) * 1.05;
        const r = 175.0 + (connSlotIdx % 2) * 32.0;
        return {
            x: hostWorldX + Math.cos(ang) * r,
            y: hostWorldY + Math.sin(ang) * r
        };
    }

    function computeLockState(item) {
        if (store.activeMode !== "wifi") return "none";
        if (view.failedRedId === item.id) return "error";
        if (view.unlockedId === item.id) return "unlocked";
        if (!item.locked) return "none";
        if (item.saved) return "saved";
        return "locked";
    }

    function updateNodeSize(uid, measuredW, measuredH) {
        const idx = findNodeIdx(uid);
        if (idx >= 0 && measuredW > 40) {
            _nodes[idx].w = measuredW;
            if (measuredH > 20 && view.pwdTargetId !== uid) {
                _nodes[idx].baseH = measuredH;
            }
        }
    }

    function syncNodesWithStore(forceReset) {
        const list = store.currentList || [];
        const modeChanged = (_lastMode !== store.activeMode);
        if (forceReset || modeChanged) {
            _lastMode = store.activeMode;
            _nodes = [];
            nodeModel.clear();
            scrollX = 0.0;
            scrollTargetX = 0.0;
            camX = (width > 0 ? width : 565) * 0.5;
            camY = (height > 0 ? height : 525) * 0.5;
            camZ = 1.0;
        }

        const existingMap = {};
        for (let i = 0; i < _nodes.length; i++) {
            existingMap[_nodes[i].uid] = _nodes[i];
        }
        const initialBatch = forceReset || modeChanged || _nodes.length === 0;
        const mode = store.activeMode;
        if (!_pinnedActiveCoords[mode]) _pinnedActiveCoords[mode] = {};

        const presentSet = {};
        let connCounter = 0;
        let outerCounter = 0;
        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            presentSet[item.id] = true;
            const isLinkedNow = isItemConnected(item);
            const lState = computeLockState(item);
            const existing = existingMap[item.id];
            if (existing) {
                existing.removing = false;
                existing.sig = item.sig;
                existing.connected = isLinkedNow;
                existing.locked = !!item.locked;
                existing.saved = !!item.saved;
                existing.name = item.name;
                existing.lockState = lState;
                if (isLinkedNow) {
                    if (Math.hypot(existing.homeX - hostWorldX, existing.homeY - hostWorldY) > 245.0) {
                        const slot = activeRingSpot(item.id, connCounter);
                        existing.homeX = slot.x;
                        existing.homeY = slot.y;
                    }
                    connCounter++;
                } else {
                    delete _pinnedActiveCoords[mode][item.id];
                    if (Math.hypot(existing.homeX - hostWorldX, existing.homeY - hostWorldY) < minOuterRadius) {
                        const outSlot = computeOuterSlot(outerCounter);
                        existing.homeX = outSlot.x;
                        existing.homeY = outSlot.y;
                    }
                    outerCounter++;
                }

                const mi = findModelIdx(item.id);
                if (mi >= 0) {
                    nodeModel.setProperty(mi, "sig", item.sig);
                    nodeModel.setProperty(mi, "connected", isLinkedNow);
                    nodeModel.setProperty(mi, "locked", !!item.locked);
                    nodeModel.setProperty(mi, "saved", !!item.saved);
                    nodeModel.setProperty(mi, "lockState", lState);
                }
            } else {
                const pos = isLinkedNow ? activeRingSpot(item.id, connCounter++) : computeOuterSlot(outerCounter++);
                const estW = estimateWidth(item);
                const stagger = isLinkedNow ? 0.0 : Math.min(i * 0.055, 0.32);
                const n = {
                    uid: item.id,
                    name: item.name,
                    sig: item.sig,
                    icon: item.icon || "",
                    locked: !!item.locked,
                    saved: !!item.saved,
                    connected: isLinkedNow,
                    lockState: lState,
                    homeX: pos.x,
                    homeY: pos.y,
                    x: pos.x,
                    y: pos.y,
                    w: estW,
                    baseH: 38,
                    phaseOffset: (i * 1.47) % (Math.PI * 2),
                    appear: 0.0,
                    appearDelay: initialBatch ? stagger : 0.0,
                    appearWait: 0.0,
                    removing: false
                };
                _nodes.push(n);
                nodeModel.append({
                    uid: n.uid,
                    name: n.name,
                    sig: n.sig,
                    icon: n.icon,
                    locked: n.locked,
                    saved: n.saved,
                    connected: n.connected,
                    lockState: n.lockState,
                    isBt: store.activeMode === "bt",
                    nx: n.x,
                    ny: n.y,
                    nScale: 0.2,
                    nOpacity: 0.0
                });
            }
        }

        for (let i = 0; i < _nodes.length; i++) {
            const n = _nodes[i];
            if (!presentSet[n.uid]) {
                n.removing = true;
            }
        }
    }

    function resetTransientState() {
        phase = "idle";
        actionTargetId = "";
        pwdTargetId = "";
        pwdExpanded = false;
        unlockedId = "";
        failedRedId = "";
        retractIsCancel = false;
        _cachedBeam = null;
        slitherProg = 0.0;
        retractProg = 1.0;
        hostDwellTimer.stop();
        slitherAnim.stop();
        connectHoldTimer.stop();
        retractAnim.stop();
        unlockPauseTimer.stop();
        pullConnectTimer.stop();
    }

    function playOpenEntrance() {
        introProg = 0.0;
        openTetherProg = 0.0;
        introAnim.restart();
        openTetherSeq.restart();
        resetTransientState();
        syncNodesWithStore(true);
    }

    function cancelZoomPrompt() {
        if (phase !== "zoomIn") return;
        // a password still being tried is dropped (and its half-made profile forgotten)
        if (checkingPwdId !== "") { checkingPwdId = ""; store.cancelPsk(); }
        Sounds.playSfx("reusables/clickbutton/click.wav", 0.35);
        retractIsCancel = true;
        failedRedId = "";
        syncNodesWithStore(false);
        if (pwdTargetId !== "") view.clearPwdRequested(pwdTargetId);
        pwdExpanded = false;
        retractProg = 1.0;
        phase = "zoomOutError";
    }

    function triggerPillClick(uid) {
        if (!active || phase !== "idle") return;
        const item = store.firstMatch(store.currentList, d => d.id === uid);
        if (!item) return;

        if (isItemConnected(item)) {
            // Clicking an already-connected node focuses it (including specific BT device) and returns to UI
            store.selectItem(uid);
            store.closeSearch();
            return;
        }

        store.selectedId = uid;
        actionTargetId = uid;
        pwdTargetId = "";
        pwdExpanded = false;
        failedRedId = "";
        unlockedId = "";
        _cachedBeam = null;
        slitherProg = 0.0;
        retractProg = 1.0;
        scrollTargetX = 0.0;
        const vw = view.width > 0 ? view.width : 565;
        const vh = view.height > 0 ? view.height : 525;
        if (Math.hypot(camX - vw * 0.5, camY - vh * 0.5) < 3.0 && Math.abs(scrollX) < 3.0 && Math.abs(camZ - 1.0) < 0.02) {
            camX = vw * 0.5;
            camY = vh * 0.5;
            camZ = 1.0;
            scrollX = 0.0;
            phase = "dwellAtHost";
            hostDwellTimer.restart();
        } else {
            phase = "panToHost";
        }
    }

    // the password is tried for real (NetworkStore connects with it); passwordResult() goes on with the answer
    property string checkingPwdId: ""
    function submitInlinePassword(uid, password) {
        if (phase !== "zoomIn" || uid !== actionTargetId || checkingPwdId !== "") return;
        checkingPwdId = uid;
        store.submitPassword(uid, password);
    }
    Connections {
        target: view.store
        function onPasswordChecked(id, ok) {
            if (id !== view.checkingPwdId) return;
            view.checkingPwdId = "";
            view.passwordResult(id, ok);
        }
    }
    function passwordResult(uid, ok) {
        if (phase !== "zoomIn" || uid !== actionTargetId) return;
        if (ok) {
            store.playProfileSfx("unlock");
            retractIsCancel = false;
            failedRedId = "";
            unlockedId = uid;
            store.markWifiSaved(uid);
            syncNodesWithStore(false);
            pwdExpanded = false;
            unlockPauseTimer.restart();
        } else {
            store.playProfileSfx("wrong");
            retractIsCancel = false;
            failedRedId = uid;
            syncNodesWithStore(false);
            view.clearPwdRequested(uid);
            pwdExpanded = false;
            retractProg = 1.0;
            phase = "zoomOutError";
        }
    }

    function enterPullToRing2Phase() {
        const mode = store.activeMode;
        const isMultiBt = (mode === "bt");
        if (!_pinnedActiveCoords[mode]) _pinnedActiveCoords[mode] = {};

        // In Wi-Fi: move previously connected network back to Ring 3+; in Bluetooth: keep existing connected devices!
        let outerIdx = 0;
        for (let i = 0; i < _nodes.length; i++) {
            const n = _nodes[i];
            if (n.removing) continue;
            if (n.uid === actionTargetId) {
                n.connected = true;
                let ang = Math.atan2(n.homeY - hostWorldY, n.homeX - hostWorldX);
                ang = Math.max(0.28, Math.min(1.22, ang));
                const pullR = isMultiBt ? 194.0 : 188.0; // Strictly between Ring 1 (135) & Ring 2 (245)
                let tx = hostWorldX + Math.cos(ang) * pullR;
                let ty = Math.max(96.0, Math.min((view.height || 525) - 52.0, hostWorldY + Math.sin(ang) * pullR));

                if (isMultiBt) {
                    // Pick an uncrowded angle between Ring 1-2 if nearby connected BT sits close
                    const keys = Object.keys(_pinnedActiveCoords[mode]);
                    for (let attempt = 0; attempt < 5; attempt++) {
                        let clash = false;
                        for (let k = 0; k < keys.length; k++) {
                            const other = _pinnedActiveCoords[mode][keys[k]];
                            if (other && Math.abs(other.x - tx) < 130 && Math.abs(other.y - ty) < 48) {
                                clash = true;
                                break;
                            }
                        }
                        if (!clash) break;
                        ang = 0.28 + ((attempt + 1) * 0.23) % 0.96;
                        tx = hostWorldX + Math.cos(ang) * (attempt % 2 === 0 ? 176.0 : 212.0);
                        ty = Math.max(96.0, Math.min((view.height || 525) - 52.0, hostWorldY + Math.sin(ang) * (attempt % 2 === 0 ? 176.0 : 212.0)));
                    }
                } else {
                    _pinnedActiveCoords[mode] = {};
                }

                n.homeX = tx;
                n.homeY = ty;
                _pinnedActiveCoords[mode][n.uid] = { x: tx, y: ty };

                const mi = findModelIdx(n.uid);
                if (mi >= 0) nodeModel.setProperty(mi, "connected", true);
            } else if (!isMultiBt) {
                const wasConn = n.connected;
                n.connected = false;
                delete _pinnedActiveCoords[mode][n.uid];
                if (wasConn || Math.hypot(n.homeX - hostWorldX, n.homeY - hostWorldY) < minOuterRadius) {
                    const slot = computeOuterSlot(outerIdx);
                    n.homeX = slot.x;
                    n.homeY = slot.y;
                }
                outerIdx++;
                const mi = findModelIdx(n.uid);
                if (mi >= 0) nodeModel.setProperty(mi, "connected", false);
            } else if (n.connected) {
                // Keep existing connected Bluetooth device pinned in Ring 1-2
                _pinnedActiveCoords[mode][n.uid] = { x: n.homeX, y: n.homeY };
            }
        }

        scrollTargetX = 0.0;
        store.playProfileSfx("pull");
        phase = "pullToRing2";
        pullConnectTimer.restart();
    }

    // ---- Smooth 60FPS Potential-Field + Laplacian Obstacle Avoidance Spline ----
    function buildSmoothAvoidancePath(x0, y0, x1, y1, targetUid) {
        return RadarMath.buildSmoothAvoidancePath(x0, y0, x1, y1, _nodes, targetUid, {
            hostR: 22.0,
            minY: 24.0,
            maxY: (view.height || 525) - 20.0,
            circleMode: false
        });
    }

    onActiveChanged: {
        if (active && winVisible) playOpenEntrance();
        else {
            openTetherSeq.stop();
            resetTransientState();
        }
    }
    onWinVisibleChanged: {
        if (active && winVisible) playOpenEntrance();
    }
    Component.onCompleted: {
        syncNodesWithStore(true);
        if (active && winVisible) playOpenEntrance();
    }

    Connections {
        target: view.store
        function onCurrentListChanged() {
            view.syncNodesWithStore(false);
        }
        function onActiveModeChanged() {
            view.resetTransientState();
            view.syncNodesWithStore(true);
        }
    }

    Timer {
        id: autoScanTimer
        interval: 10000
        repeat: true
        running: view.active && view.winVisible && view.visible && view.phase === "idle"
        onTriggered: view.store.runAutoScanTick()
    }
    // Wi-Fi switched back on: its 10 s scan cycle starts again from zero
    Connections {
        target: view.store
        function onRadioReturned(mode) { if (mode === view.store.activeMode) autoScanTimer.restart(); }
    }

    NumberAnimation {
        id: introAnim
        target: view
        property: "introProg"
        from: 0.0
        to: 1.0
        duration: 650
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: openTetherSeq
        PauseAnimation { duration: 110 }
        NumberAnimation {
            target: view
            property: "openTetherProg"
            from: 0.0
            to: 1.0
            duration: 420
            easing.type: Easing.InOutCubic
        }
    }

    Timer {
        id: hostDwellTimer
        interval: 500
        onTriggered: {
            if (view.phase !== "dwellAtHost" || view.actionTargetId === "") return;
            view.slitherProg = 0.0;
            view.phase = "slither";
            view.store.playProfileSfx("slither");
            slitherAnim.restart();
        }
    }

    NumberAnimation {
        id: slitherAnim
        target: view
        property: "slitherProg"
        from: 0.0
        to: 1.0
        duration: 840
        easing.type: Easing.InOutCubic
        onFinished: {
            if (view.phase !== "slither") return;
            view.store.playProfileSfx("impact");
            view.impactPulseId = view.actionTargetId;
            view.impactPulseProg = 0.0;
            impactAnim.restart();

            const item = view.store.firstMatch(view.store.currentList, d => d.id === view.actionTargetId);
            if (!item) {
                view.resetTransientState();
                return;
            }
            const tIdx = view.findNodeIdx(item.id);
            if (tIdx >= 0) {
                const tn = view._nodes[tIdx];
                const vw = view.width > 0 ? view.width : 565;
                view.scrollTargetX = Math.max(0.0, tn.x - vw * 0.5);
                if (view.store.activeMode === "wifi" && item.locked && !item.saved) {
                    view.zoomFocusX = tn.x;
                    view.zoomFocusY = tn.y + 18;
                    view.zoomTargetZ = (vw - 20.0) / Math.max(120.0, tn.w);
                }
            }
            if (view.store.activeMode === "wifi" && item.locked && !item.saved) {
                view.pwdTargetId = item.id;
                view.pwdExpanded = true;
                view.phase = "zoomIn";
                focusDelayTimer.restart();
            } else {
                // the real connection starts now, while the pull animation plays
                view.store.beginConnect(item.id);
                view.phase = "holdingImpact";
                connectHoldTimer.restart();
            }
        }
    }

    Timer {
        id: connectHoldTimer
        interval: 500
        onTriggered: {
            if (view.phase === "holdingImpact" && view.actionTargetId !== "") {
                view.enterPullToRing2Phase();
            }
        }
    }

    NumberAnimation {
        id: impactAnim
        target: view
        property: "impactPulseProg"
        from: 0.0
        to: 1.0
        duration: 360
        easing.type: Easing.OutCubic
        onFinished: view.impactPulseId = ""
    }

    NumberAnimation {
        id: retractAnim
        target: view
        property: "retractProg"
        from: 1.0
        to: 0.0
        duration: 520
        easing.type: Easing.InOutCubic
        onFinished: {
            view.retractIsCancel = false;
            view.phase = "idle";
            view.actionTargetId = "";
            view.pwdTargetId = "";
            view._cachedBeam = null;
            clearRedDelayTimer.restart();
        }
    }

    Timer {
        id: focusDelayTimer
        interval: 220
        onTriggered: {
            if (view.phase === "zoomIn" && view.pwdTargetId !== "") {
                view.focusPwdRequested(view.pwdTargetId);
            }
        }
    }

    Timer {
        id: unlockPauseTimer
        interval: 500
        onTriggered: {
            if (view.phase === "zoomIn") {
                view.phase = "zoomOutSuccess";
                view.pwdTargetId = "";
            }
        }
    }

    Timer {
        id: pullConnectTimer
        interval: 680
        onTriggered: {
            if (view.phase === "pullToRing2" && view.actionTargetId !== "") {
                const tid = view.actionTargetId;
                view.resetTransientState();
                view.store.finalizeConnection(tid);
            }
        }
    }

    Timer {
        id: clearRedDelayTimer
        interval: 1400
        onTriggered: {
            view.failedRedId = "";
            view.syncNodesWithStore(false);
        }
    }

    // 60FPS Simulation Loop: appear/disappear, float, Ring 3+ outer clamping, collision-free repulsion, camera
    FrameAnimation {
        running: view.active && view.winVisible && view.visible
        onTriggered: {
            const dt = Math.min(0.05, Math.max(0.001, frameTime));
            view._floatClock += dt;
            view.dashOffsetTime += dt;

            const vw = view.width > 0 ? view.width : 565;
            const vh = view.height > 0 ? view.height : 525;

            const freezeWorld = (view.phase === "zoomIn");
            const removeQueue = [];
            for (let i = 0; i < view._nodes.length; i++) {
                const n = view._nodes[i];
                if (n.removing) {
                    n.appear = Math.max(0.0, n.appear - dt / 0.28);
                    if (n.appear <= 0.001) {
                        removeQueue.push(n.uid);
                        continue;
                    }
                } else {
                    if (n.appearWait < n.appearDelay) {
                        n.appearWait += dt;
                    } else if (n.appear < 1.0) {
                        n.appear = Math.min(1.0, n.appear + dt / 0.36);
                    }
                }

                if (!freezeWorld && !n.removing) {
                    const floatX = Math.sin(view._floatClock * 1.15 + n.phaseOffset) * 7.0;
                    const floatY = Math.cos(view._floatClock * 0.92 + n.phaseOffset * 1.3) * 6.0;
                    const pullRate = (view.phase === "pullToRing2" && n.uid === view.actionTargetId) ? 0.11 : 0.32;
                    const pk = view.smoothK(dt, pullRate);
                    n.x += (n.homeX + floatX - n.x) * pk;
                    n.y += (n.homeY + floatY - n.y) * pk;
                }
            }

            if (removeQueue.length > 0) {
                for (let r = 0; r < removeQueue.length; r++) {
                    const rUid = removeQueue[r];
                    const ri = view.findNodeIdx(rUid);
                    if (ri >= 0) view._nodes.splice(ri, 1);
                    const mi = view.findModelIdx(rUid);
                    if (mi >= 0) nodeModel.remove(mi);
                }
            }

            if (!freezeWorld) {
                for (let iter = 0; iter < 3; iter++) {
                    for (let i = 0; i < view._nodes.length; i++) {
                        const a = view._nodes[i];
                        if (a.removing) continue;
                        for (let j = i + 1; j < view._nodes.length; j++) {
                            const b = view._nodes[j];
                            if (b.removing) continue;

                            const reqX = (a.w + b.w) * 0.5 + 16.0;
                            const reqY = (a.baseH + b.baseH) * 0.5 + 14.0;
                            const dx = b.x - a.x;
                            const dy = b.y - a.y;

                            if (Math.abs(dx) < reqX && Math.abs(dy) < reqY) {
                                const penX = reqX - Math.abs(dx);
                                const penY = reqY - Math.abs(dy);
                                const aPriority = a.connected || (view.phase === "pullToRing2" && a.uid === view.actionTargetId);
                                const bPriority = b.connected || (view.phase === "pullToRing2" && b.uid === view.actionTargetId);
                                const wa = aPriority && !bPriority ? 0.14 : (bPriority && !aPriority ? 0.86 : 0.5);
                                const wb = 1.0 - wa;

                                if (penX < penY) {
                                    const dirX = dx >= 0 ? 1.0 : -1.0;
                                    a.x -= dirX * penX * wa;
                                    b.x += dirX * penX * wb;
                                } else {
                                    const dirY = dy >= 0 ? 1.0 : -1.0;
                                    a.y -= dirY * penY * wa;
                                    b.y += dirY * penY * wb;
                                }
                            }
                        }

                        // Enforce radial zone rules:
                        //  - Non-connected nodes NEVER enter closer than Ring 3 (minOuterRadius = 374px)
                        //  - Active connected node stays gracefully between Ring 1 (135) & Ring 2 (245)
                        const rx = a.x - view.hostWorldX;
                        const ry = a.y - view.hostWorldY;
                        const dist = Math.max(0.001, Math.hypot(rx, ry));
                        if (a.connected) {
                            if (dist < 162.0) {
                                a.x = view.hostWorldX + (rx / dist) * 162.0;
                                a.y = view.hostWorldY + (ry / dist) * 162.0;
                            } else if (dist > 226.0 && view.phase !== "pullToRing2") {
                                a.x = view.hostWorldX + (rx / dist) * 226.0;
                                a.y = view.hostWorldY + (ry / dist) * 226.0;
                            }
                        } else if (!(view.phase === "pullToRing2" && a.uid === view.actionTargetId)) {
                            if (dist < view.minOuterRadius) {
                                a.x = view.hostWorldX + (rx / dist) * view.minOuterRadius;
                                a.y = view.hostWorldY + (ry / dist) * view.minOuterRadius;
                            }
                        }

                        // Vertical frame padding & top-right Mode Switcher clearance
                        a.y = Math.max(46.0, Math.min(vh - 34.0, a.y));
                        a.x = Math.max(a.w * 0.5 + 18.0, a.x);

                        const screenRelX = a.x - view.scrollX;
                        if (screenRelX + a.w * 0.5 > vw - 122.0 && a.y < 78.0) {
                            a.y = 78.0;
                        }
                    }
                }
            }

            // Build & cache active beam polyline once per frame after node positions settle
            let beamCache = null;
            if (view.phase !== "idle" && view.phase !== "panToHost" && view.phase !== "dwellAtHost" && view.actionTargetId !== "") {
                const bIdx = view.findNodeIdx(view.actionTargetId);
                if (bIdx >= 0) {
                    const tn = view._nodes[bIdx];
                    const path = view.buildSmoothAvoidancePath(view.hostWorldX, view.hostWorldY, tn.x, tn.y, tn.uid);
                    const frac = (view.phase === "slither") ? view.slitherProg : (view.phase === "retractError" ? view.retractProg : 1.0);
                    const drawLen = path.totalLen * Math.max(0.0, Math.min(1.0, frac));
                    const segPts = drawLen > 1.0 ? RadarMath.slicePolylineByLen(path, drawLen) : [];
                    const tip = segPts.length > 0 ? segPts[segPts.length - 1] : { x: view.hostWorldX, y: view.hostWorldY };
                    beamCache = { uid: tn.uid, frac: frac, segPts: segPts, tip: tip };
                }
            }
            view._cachedBeam = beamCache;

            // Single-stage smooth camera follow (no cascaded scrollX + camX lag!)
            if (view.phase === "panToHost") {
                const pk = view.smoothK(dt, 0.085);
                view.camX += (vw * 0.5 - view.camX) * pk;
                view.camY += (vh * 0.5 - view.camY) * pk;
                view.camZ += (1.0 - view.camZ) * pk;
                view.scrollX = Math.max(0.0, view.camX - vw * 0.5);
                view.scrollTargetX = 0.0;
                if (Math.hypot(view.camX - vw * 0.5, view.camY - vh * 0.5) < 2.2) {
                    view.camX = vw * 0.5;
                    view.camY = vh * 0.5;
                    view.camZ = 1.0;
                    view.scrollX = 0.0;
                    view.phase = "dwellAtHost";
                    hostDwellTimer.restart();
                }
            } else if (view.phase === "dwellAtHost") {
                view.camX = vw * 0.5;
                view.camY = vh * 0.5;
                view.camZ = 1.0;
                view.scrollX = 0.0;
                view.scrollTargetX = 0.0;
            } else if ((view.phase === "slither" || view.phase === "retractError") && beamCache) {
                const tip = beamCache.tip;
                const excess = tip.x - (vw * 0.5 - 24.0);
                const softExcess = excess > 0.0 ? (excess * excess) / (excess + 36.0) : 0.0;
                const desiredCamX = Math.max(vw * 0.5, vw * 0.5 + softExcess);
                const fk = view.smoothK(dt, 0.025);
                view.camX += (desiredCamX - view.camX) * fk;
                view.camY += (vh * 0.5 - view.camY) * fk;
                view.camZ += (1.0 - view.camZ) * fk;
                view.scrollX = Math.max(0.0, view.camX - vw * 0.5);
                view.scrollTargetX = view.scrollX;
            } else if (view.phase === "holdingImpact") {
                const hIdx = view.findNodeIdx(view.actionTargetId);
                let holdCamX = view.camX;
                if (hIdx >= 0) {
                    const hex = view._nodes[hIdx].x - (vw * 0.5 - 24.0);
                    const hsoft = hex > 0.0 ? (hex * hex) / (hex + 36.0) : 0.0;
                    holdCamX = Math.max(vw * 0.5, vw * 0.5 + hsoft);
                }
                const hk = view.smoothK(dt, 0.06);
                view.camX += (holdCamX - view.camX) * hk;
                view.camY += (vh * 0.5 - view.camY) * hk;
                view.camZ += (1.0 - view.camZ) * hk;
                view.scrollX = Math.max(0.0, view.camX - vw * 0.5);
                view.scrollTargetX = view.scrollX;
            } else if (view.phase === "zoomIn") {
                const zk = view.smoothK(dt, 0.12);
                view.camX += (view.zoomFocusX - view.camX) * zk;
                view.camY += (view.zoomFocusY - view.camY) * zk;
                view.camZ += (view.zoomTargetZ - view.camZ) * zk;
                view.scrollTargetX = Math.max(0.0, view.zoomFocusX - vw * 0.5);
                view.scrollX = Math.max(0.0, view.camX - vw * 0.5);
            } else if (view.phase === "pullToRing2") {
                view.scrollTargetX = 0.0;
                const pk = view.smoothK(dt, 0.095);
                view.camX += (vw * 0.5 - view.camX) * pk;
                view.camY += (vh * 0.5 - view.camY) * pk;
                view.camZ += (1.0 - view.camZ) * pk;
                view.scrollX = Math.max(0.0, view.camX - vw * 0.5);
            } else {
                const sk = view.smoothK(dt, 0.09);
                view.scrollX += (view.scrollTargetX - view.scrollX) * sk;
                const targetCamX = vw * 0.5 + view.scrollX;
                const targetCamY = vh * 0.5;
                const ok = view.smoothK(dt, 0.09);
                view.camX += (targetCamX - view.camX) * ok;
                view.camY += (targetCamY - view.camY) * ok;
                view.camZ += (1.0 - view.camZ) * ok;

                if (view.phase === "zoomOutError" && Math.abs(view.camZ - 1.0) < 0.04) {
                    view.camZ = 1.0;
                    if ((view.failedRedId !== "" || view.retractIsCancel) && view.actionTargetId !== "") {
                        view.phase = "retractError";
                        view.retractProg = 1.0;
                        view.store.playProfileSfx("retract");
                        retractAnim.restart();
                    } else {
                        view.retractIsCancel = false;
                        view.phase = "idle";
                        view.pwdTargetId = "";
                    }
                } else if (view.phase === "zoomOutSuccess" && Math.abs(view.camZ - 1.0) < 0.04) {
                    view.camZ = 1.0;
                    view.enterPullToRing2Phase();
                }
            }

            for (let i = 0; i < view._nodes.length; i++) {
                const n = view._nodes[i];
                const mi = view.findModelIdx(n.uid);
                if (mi >= 0) {
                    const s = n.removing
                        ? (0.65 + 0.35 * (1.0 - view.easeInCubic(1.0 - n.appear)))
                        : (0.45 + 0.55 * view.easeOutBack(n.appear));
                    const op = n.removing
                        ? (1.0 - view.easeInCubic(1.0 - n.appear))
                        : Math.min(1.0, n.appear * 1.35);
                    nodeModel.setProperty(mi, "nx", n.x);
                    nodeModel.setProperty(mi, "ny", n.y);
                    nodeModel.setProperty(mi, "nScale", s);
                    nodeModel.setProperty(mi, "nOpacity", op);
                }
            }

            radarCanvas.requestPaint();
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: {
            if (view.phase === "zoomIn") {
                view.cancelZoomPrompt();
            }
        }
    }

    WheelHandler {
        id: wheelNav
        enabled: view.active && view.phase === "idle"
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (event) => {
            const raw = Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x)
                ? -event.angleDelta.y
                : -event.angleDelta.x;
            view.scrollTargetX = Math.max(0.0, view.scrollTargetX + raw * 0.9);
        }
    }

    // Layer 1: Vector canvas for 4 rings (r=135,245,355,465), connected tether, smooth hover dashes, & click beam
    Canvas {
        id: radarCanvas
        anchors.fill: parent
        z: 1

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (width <= 0 || height <= 0) return;

            const vw = width;
            const vh = height;
            const cz = view.camZ;
            const tx = vw * 0.5 - view.camX * cz;
            const ty = vh * 0.5 - view.camY * cz;
            const hx = view.hostWorldX;
            const hy = view.hostWorldY;
            const c = view.accentColor;

            function strokeSmoothCurve(pts) {
                RadarMath.strokeSmoothCurve(ctx, pts);
            }

            ctx.save();
            ctx.translate(tx, ty);
            ctx.scale(cz, cz);

            // 1. 4 Concentric Radar Rings anchored at world Host (40, 40)
            const radii = view.ringRadii;
            const intro = view.introProg;
            for (let i = 0; i < radii.length; i++) {
                const r = radii[i] * (0.35 + 0.65 * intro);
                ctx.beginPath();
                ctx.arc(hx, hy, r, -0.22, Math.PI * 0.72);
                ctx.lineWidth = (i === 1 || i === 2) ? (1.35 / cz) : (1.0 / cz);
                if (i % 2 === 1) ctx.setLineDash([5, 6]);
                else ctx.setLineDash([]);
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, ((i === 2) ? 0.26 : (i === 1 ? 0.22 : 0.15)) * intro);
                ctx.stroke();
            }
            ctx.setLineDash([]);

            // Subtle extension arcs beyond Ring 5 when scrolled far right
            const farReach = view.scrollX + vw + 180;
            for (let r = 685; r < farReach; r += 110) {
                ctx.beginPath();
                ctx.arc(hx, hy, r, -0.18, Math.PI * 0.56);
                ctx.lineWidth = 0.85 / cz;
                ctx.setLineDash([3, 8]);
                ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.09 * intro);
                ctx.stroke();
            }
            ctx.setLineDash([]);

            // 2. Persistent curved tether lines from Host rim to ALL active connected nodes
            //    Plays smooth slither reveal animation (`openTetherProg`) on entering Scan so lines never snap/jitter!
            const tetherReveal = Math.max(0.0, Math.min(1.0, view.openTetherProg));
            if (tetherReveal > 0.005) {
                for (let i = 0; i < view._nodes.length; i++) {
                    const cn = view._nodes[i];
                    if (!cn.connected || cn.removing || cn.appear < 0.05) continue;
                    if (view.phase === "pullToRing2" && view.actionTargetId === cn.uid) continue;

                    const connPath = view.buildSmoothAvoidancePath(hx, hy, cn.x, cn.y, cn.uid);
                    if (connPath.pts.length >= 2 && connPath.totalLen > 1.0) {
                        const drawPts = (tetherReveal < 0.999)
                            ? RadarMath.slicePolylineByLen(connPath, connPath.totalLen * tetherReveal)
                            : connPath.pts;

                        if (drawPts.length >= 2) {
                            const dimFactor = view.phase === "zoomIn" ? 0.22 : (view.phase !== "idle" ? 0.45 : 1.0);
                            strokeSmoothCurve(drawPts);
                            ctx.lineWidth = 5.5 / cz;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.16 * dimFactor);
                            ctx.stroke();

                            strokeSmoothCurve(drawPts);
                            ctx.lineWidth = 2.0 / cz;
                            ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.78 * dimFactor);
                            ctx.stroke();

                            if (tetherReveal < 0.995) {
                                const tip = drawPts[drawPts.length - 1];
                                ctx.beginPath();
                                ctx.arc(tip.x, tip.y, 3.2 / cz, 0, Math.PI * 2);
                                ctx.fillStyle = Qt.rgba(1.0, 1.0, 0.94, 0.85 * dimFactor);
                                ctx.fill();
                            }
                        }
                    }
                }
            }

            // 3. Smooth 60FPS Marching Dashed Hover Curve avoiding all pills
            if (view.phase === "idle" && view.hoveredId !== "") {
                const hIdx = view.findNodeIdx(view.hoveredId);
                if (hIdx >= 0 && !view._nodes[hIdx].connected) {
                    const target = view._nodes[hIdx];
                    const hoverPath = view.buildSmoothAvoidancePath(hx, hy, target.x, target.y, target.uid);
                    if (hoverPath.pts.length >= 2) {
                        strokeSmoothCurve(hoverPath.pts);
                        ctx.lineWidth = 3.2;
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.13);
                        ctx.stroke();

                        strokeSmoothCurve(hoverPath.pts);
                        ctx.setLineDash([7, 6]);
                        ctx.lineDashOffset = -view.dashOffsetTime * 44.0;
                        ctx.lineWidth = 1.65;
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.76);
                        ctx.stroke();
                        ctx.setLineDash([]);
                    }
                }
            }

            // 4. Active Click Slither Beam / Zoomed Link / Wrong-Pwd Red Retract
            if (view.phase !== "idle" && view.phase !== "panToHost" && view.phase !== "dwellAtHost" && view.actionTargetId !== "") {
                let segPts = [];
                if (view._cachedBeam && view._cachedBeam.uid === view.actionTargetId) {
                    segPts = view._cachedBeam.segPts;
                } else {
                    const aIdx = view.findNodeIdx(view.actionTargetId);
                    if (aIdx >= 0) {
                        const target = view._nodes[aIdx];
                        const path = view.buildSmoothAvoidancePath(hx, hy, target.x, target.y, target.uid);
                        if (path.pts.length >= 2 && path.totalLen > 1.0) {
                            let frac = 1.0;
                            if (view.phase === "slither") frac = view.slitherProg;
                            else if (view.phase === "retractError") frac = view.retractProg;
                            const drawLen = path.totalLen * Math.max(0.0, Math.min(1.0, frac));
                            if (drawLen > 1.0) segPts = RadarMath.slicePolylineByLen(path, drawLen);
                        }
                    }
                }
                if (segPts.length >= 2) {
                    const isErr = (view.failedRedId !== "" && view.failedRedId === view.actionTargetId);
                    const beamCol = isErr ? ThemeBackend.red : c;

                    strokeSmoothCurve(segPts);
                    ctx.lineWidth = 6.0 / cz;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.rgba(beamCol.r, beamCol.g, beamCol.b, 0.22);
                    ctx.stroke();

                    strokeSmoothCurve(segPts);
                    ctx.lineWidth = 2.4 / cz;
                    ctx.strokeStyle = Qt.rgba(beamCol.r, beamCol.g, beamCol.b, 0.94);
                    ctx.stroke();

                    const tip = segPts[segPts.length - 1];
                    ctx.beginPath();
                    ctx.arc(tip.x, tip.y, 4.4 / cz, 0, Math.PI * 2);
                    ctx.fillStyle = isErr ? ThemeBackend.red : Qt.rgba(1.0, 1.0, 0.94, 0.95);
                    ctx.fill();
                }
            }

            // 5. Impact Halo when slither hits pill
            if (view.impactPulseId !== "") {
                const iIdx = view.findNodeIdx(view.impactPulseId);
                if (iIdx >= 0) {
                    const n = view._nodes[iIdx];
                    const p = view.impactPulseProg;
                    ctx.beginPath();
                    ctx.arc(n.x, n.y, (18 + p * 38), 0, Math.PI * 2);
                    ctx.lineWidth = 2.2 / cz;
                    ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, (1.0 - p) * 0.72);
                    ctx.stroke();
                }
            }

            ctx.restore();
        }
    }

    // Layer 2: World-transformed floating pills + World-anchored Host button (moves with scroll, hides in pwd zoom)
    Item {
        id: worldLayer
        anchors.fill: parent
        z: 3
        transform: [
            Scale {
                origin.x: 0; origin.y: 0
                xScale: view.camZ
                yScale: view.camZ
            },
            Translate {
                x: view.width * 0.5 - view.camX * view.camZ
                y: view.height * 0.5 - view.camY * view.camZ
            }
        ]

        // Faint waves sent out of the Host: a thin ring in the theme colour grows to the outermost ring and fades,
        // one every 3 s (each lives 4.2 s, so at most two at once); only while the Scan radar is shown
        Item {
            id: hostWaves
            property real clock: 0          // 0..6000 ms, one cycle of both waves
            z: 1
            NumberAnimation on clock {
                running: view.active && view.winVisible && view.visible
                from: 0; to: 6000; duration: 6000
                loops: Animation.Infinite
            }
            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    readonly property real age: ((hostWaves.clock - index * 3000) % 6000 + 6000) % 6000
                    readonly property real t: age / 4200
                    readonly property real eased: Math.sin(Math.min(1, t) * Math.PI / 2)
                    readonly property real r: 22 + (view.ringRadii[view.ringRadii.length - 1] - 22) * eased
                    x: view.hostWorldX - r
                    y: view.hostWorldY - r
                    width: r * 2
                    height: width
                    radius: r
                    color: "transparent"
                    border.width: 1.2 / Math.max(0.2, view.camZ)
                    border.color: view.accentColor
                    opacity: 0.32 * (1 - eased) * Math.min(1, t * 8) * view.introProg
                    visible: t < 1 && !view.hideTopChrome && hostWaves.clock > 0
                    antialiasing: true
                }
            }
        }

        // World-space Host button at (40, 40): no longer locked to viewport when scrolling,
        // and fades away while password prompt zoom is active
        HostScanButton {
            id: worldHostBtn
            x: view.hostWorldX - width / 2
            y: view.hostWorldY - height / 2
            buttonSize: 44
            accentColor: view.accentColor
            active: view.active && !view.hideTopChrome
            winVisible: view.winVisible
            z: 25

            opacity: view.hideTopChrome ? 0.0 : 1.0
            visible: opacity > 0.01
            enabled: !view.hideTopChrome
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            onClicked: {
                view.resetTransientState();
                view.store.closeSearch();
            }
        }

        ListModel { id: nodeModel }

        Repeater {
            model: nodeModel

            delegate: Item {
                id: pillWrap
                required property int index
                required property string uid
                required property string name
                required property int sig
                required property string icon
                required property bool locked
                required property bool saved
                required property bool connected
                required property string lockState
                required property bool isBt
                required property real nx
                required property real ny
                required property real nScale
                required property real nOpacity

                readonly property bool isHovered: view.hoveredId === uid && view.phase === "idle"
                readonly property bool isTarget: view.actionTargetId === uid
                readonly property bool showPwdBox: view.pwdExpanded && view.pwdTargetId === uid
                readonly property color sigCol: NetLook.signalColor(sig)

                x: nx - width / 2
                y: ny - (headerBox.height / 2)
                width: Math.max(96, headerRow.implicitWidth + 24)
                height: pillCard.height
                scale: nScale
                opacity: nOpacity
                z: showPwdBox || isTarget ? 20 : (isHovered ? 12 : (connected ? 8 : 2))

                onWidthChanged: view.updateNodeSize(uid, width, headerBox.height)
                Component.onCompleted: view.updateNodeSize(uid, width, headerBox.height)

                Connections {
                    target: view
                    function onFocusPwdRequested(focusUid) {
                        if (focusUid === pillWrap.uid && pwdDrawer.visible) {
                            inlinePwdInput.forceActiveFocus();
                        }
                    }
                    function onClearPwdRequested(clearUid) {
                        if (clearUid === pillWrap.uid) {
                            inlinePwdInput.text = "";
                        }
                    }
                }

                Rectangle {
                    id: pillCard
                    width: parent.width
                    height: cardCol.implicitHeight
                    radius: Math.min(ThemeBackend.clampedBorderRadius, 12)
                    scale: pillWrap.isHovered ? 1.05 : 1.0
                    opacity: (view.phase === "zoomIn" && !pillWrap.isTarget) ? 0.18 : 1.0
                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    color: {
                        if (pillWrap.lockState === "error") return Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.18);
                        if (pillWrap.connected) return Qt.rgba(view.accentColor.r, view.accentColor.g, view.accentColor.b, 0.22);
                        if (pillWrap.isHovered || pillWrap.isTarget) return ThemeBackend.surface1;
                        return Qt.rgba(ThemeBackend.surface0.r, ThemeBackend.surface0.g, ThemeBackend.surface0.b, 0.90);
                    }
                    border.width: Math.max(0.55, (pillWrap.connected || pillWrap.isHovered || pillWrap.isTarget ? 1.5 : 1.0) / Math.max(1.0, Math.sqrt(view.camZ)))
                    border.color: {
                        if (pillWrap.lockState === "error") return ThemeBackend.red;
                        if (pillWrap.lockState === "unlocked") return ThemeBackend.green;
                        if (pillWrap.isHovered || pillWrap.isTarget) return view.accentColor;
                        if (pillWrap.connected) return Qt.alpha(view.accentColor, 0.72);
                        return ThemeBackend.surface2;
                    }

                    Behavior on color { ColorAnimation { duration: 180 } }
                    Behavior on border.color { ColorAnimation { duration: 180 } }

                    ColumnLayout {
                        id: cardCol
                        width: parent.width
                        spacing: 0

                        Item {
                            id: headerBox
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38

                            RowLayout {
                                id: headerRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    visible: pillWrap.isBt || pillWrap.lockState !== "none"
                                    text: {
                                        if (pillWrap.isBt) return pillWrap.icon !== "" ? pillWrap.icon : "󰂯";
                                        if (pillWrap.lockState === "unlocked" || pillWrap.lockState === "saved") return "󰌿";
                                        return "󰌾";
                                    }
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: 12
                                    color: {
                                        if (pillWrap.isBt) return pillWrap.connected ? view.accentColor : ThemeBackend.subtext0;
                                        if (pillWrap.lockState === "error") return ThemeBackend.red;
                                        if (pillWrap.lockState === "unlocked") return ThemeBackend.green;
                                        if (pillWrap.lockState === "saved") return Qt.alpha(ThemeBackend.teal, 0.85);
                                        return ThemeBackend.peach;
                                    }
                                    Behavior on color { ColorAnimation { duration: 180 } }
                                }

                                Text {
                                    text: pillWrap.name
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 12
                                    font.weight: pillWrap.connected ? Font.DemiBold : Font.Medium
                                    color: ThemeBackend.text
                                }

                                Text {
                                    visible: view.store.activeMode !== "bt"      // Bluetooth gives no signal strength
                                    text: pillWrap.sig + "%"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                    color: pillWrap.sigCol
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: view.phase === "idle"
                                enabled: view.active && (view.phase === "idle")
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    if (view.phase === "idle") {
                                        view.hoveredId = pillWrap.uid;
                                        view.store.playHoverProfile();
                                    }
                                }
                                onExited: {
                                    if (view.hoveredId === pillWrap.uid) view.hoveredId = "";
                                }
                                onClicked: view.triggerPillClick(pillWrap.uid)
                            }
                        }

                        Item {
                            id: pwdDrawer
                            Layout.fillWidth: true
                            Layout.preferredHeight: pillWrap.showPwdBox ? 34 : 0
                            visible: Layout.preferredHeight > 1
                            clip: true

                            Behavior on Layout.preferredHeight {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                anchors.bottomMargin: 6
                                radius: 7
                                color: ThemeBackend.crust
                                border.width: Math.max(0.45, 0.9 / Math.max(1.0, Math.sqrt(view.camZ)))
                                border.color: inlinePwdInput.activeFocus ? view.accentColor : ThemeBackend.surface2

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 7
                                    anchors.rightMargin: 4
                                    spacing: 4

                                    TextInput {
                                        id: inlinePwdInput
                                        Layout.fillWidth: true
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: 10
                                        color: ThemeBackend.text
                                        selectionColor: Qt.alpha(view.accentColor, 0.35)
                                        echoMode: TextInput.Password
                                        verticalAlignment: TextInput.AlignVCenter
                                        clip: true
                                        onTextEdited: Sounds.playSfx("reusables/input/type.wav", 0.25)
                                        onAccepted: view.submitInlinePassword(pillWrap.uid, text)
                                        Keys.onEscapePressed: view.cancelZoomPrompt()

                                        Text {
                                            anchors.fill: parent
                                            verticalAlignment: Text.AlignVCenter
                                            visible: inlinePwdInput.text.length === 0
                                            text: "Password..."
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: 10
                                            color: ThemeBackend.overlay1
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 18
                                        Layout.preferredHeight: 18
                                        radius: 5
                                        color: joinMa.containsMouse ? view.accentColor : Qt.alpha(view.accentColor, 0.82)

                                        Text {
                                            anchors.centerIn: parent
                                            text: view.checkingPwdId !== "" ? "󰑮" : "󰁔"
                                            font.family: ThemeBackend.iconFont
                                            font.pixelSize: 10
                                            color: ThemeBackend.crust
                                            RotationAnimation on rotation {
                                                running: view.checkingPwdId !== ""
                                                from: 0; to: 360; duration: 800; loops: Animation.Infinite
                                                onRunningChanged: if (!running) parent.rotation = 0
                                            }
                                        }

                                        MouseArea {
                                            id: joinMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: view.submitInlinePassword(pillWrap.uid, inlinePwdInput.text)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
