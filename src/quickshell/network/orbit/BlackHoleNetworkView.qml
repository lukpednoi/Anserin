import QtQuick
import "../../"
import QtQuick.Layouts
import QtQuick.Shapes
import "."
import "RadarMath.js" as RadarMath

/**
 * 60FPS Zero-Leak 2x-Expanded Flat 2D Infinite-Pan Gargantua Orbit Network View ([2/2]):
 *   - Performance Architecture (100% effects preserved, ZERO progressive lag over time):
 *       * Static 680-edge constellation web lives in its own dedicated `Shape` (constant strokeWidth,
 *         baked ONCE per mode -> NEVER re-tessellated by CurveRenderer on subsequent frames!).
 *       * 5 sweeping outer comet arcs are each static-baked ONCE and spun via pure GPU `rotation`
 *         (ZERO per-frame PathSvg string allocations!).
 *       * Connected, hover & active beams render as lightweight GPU `Rectangle` beams (ZERO per-frame
 *         CurveRenderer tessellation!).
 *       * All pooled Repeater delegates (420 stars, 96 packets, 48 streaks, 36 flashes, 6 cloud-flashes,
 *         5 comet arcs, 6 connected beams) are cached in plain JS arrays (ZERO `.itemAt()` bridge calls/frame!).
 *       * Unloaded completely when on Connected UI (`NetworkPreviewShell` Loader); pauses during Fullscreen
 *         wave and plays a smooth 3-stage bloom entrance ONLY after opening finishes!
 *   - Features:
 *       * Photorealistic IMAX-grade Gargantua Black Hole (`500×500` fixed quad -> `860×860` world units)
 *         locked at (0, 0) with naked `HubSourceGlyph` centered inside the event horizon.
 *       * Closer golden connected orbit (`r = 255`) with 3-stage connection: `suckToCore` (old Wi-Fi stays
 *         until new hits core!) -> `coreCharge` (old Wi-Fi immediately ejects outward + golden flare &
 *         shockwave!) -> `releaseToOrbit` (new Wi-Fi slingshots out into continuous clockwise orbit!).
 *       * Smooth clockwise rotation (`+2.4°/s`) continues even while dragging (`inf` unclamped pan!).
 *       * Complete interaction lock (no pan/zoom, zero hover on other nodes) while waiting/connecting.
 *       * Rock-steady zoom-compensated text scale (no `Behavior` lag / self-enlarging bug!).
 *       * Auto-scaling Fibonacci spiral supporting 30-50+ real-world Wi-Fi networks + smooth appear/disappear.
 */
Item {
    id: view

    required property NetworkStore store
    property color accentColor: ThemeBackend.mauve
    property bool active: true
    property bool winVisible: true
    property bool isFullscreen: false
    property bool stormGasMode: true
    property bool showBlackHole: true
    property bool blackHoleCenterMode: true
    // Selectable Black Hole style options (kept for future Settings wiring):
    //   useUnifiedBlackHole: true = Unified back hole.png lensing, false = Legacy Gargantua shader
    //   bhColorMode: 1.0 = Copper (Mo's default), 0.0 = Champagne
    //   bhTilted: false = 0° Flat (Mo's default), true = 6.6° Tilt
    property bool useUnifiedBlackHole: true
    property real bhColorMode: 1.0
    property bool bhTilted: false
    property real bhTiltRad: bhTilted ? 0.115 : 0.0
    property bool entranceReady: true
    property bool _initialIntroDone: false
    property string sourceKind: "router"
    property string btIconGlyph: "󰂯"

    Behavior on bhColorMode { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }
    Behavior on bhTiltRad { NumberAnimation { duration: 360; easing.type: Easing.InOutCubic } }

    signal exitFullscreenRequested()

    readonly property color goldAccent: "#f0c57c"
    readonly property color goldBright: "#fff0d2"
    readonly property color starWhite: "#f6f7fb"

    // True whenever a connection sequence is in flight, inspector drawer is open, or power animation/off state is active
    readonly property bool interactionLocked: (phase !== "idle") || drawerOpen || (powerAnimState !== "on")

    // Cinematic Black Hole Power OFF (Implosion -> Bouncy Wi-Fi Orb) & Power ON (Charge -> Thunderclap Big-Bang!)
    property string powerAnimState: store.currentPower ? "on" : "off" // "on" | "turningOff" | "off" | "turningOn"
    property real bhPowerScale: store.currentPower ? 1.0 : 0.0
    property real bhPowerVortex: 0.0
    property real bhPowerPulse: 0.0
    property real bhSpinBoost: 1.0
    property real galaxySuckScale: store.currentPower ? 1.0 : 0.0
    property real galaxySuckOpacity: store.currentPower ? 1.0 : 0.0
    property real galaxySpinBoost: 0.0
    property real nodeRadialMult: store.currentPower ? 1.0 : 0.0
    property real nodePowerOpacity: store.currentPower ? 1.0 : 0.0
    property real burstFlashProg: 0.0
    property bool burstFlashVisible: false
    property real offOrbScale: store.currentPower ? 0.0 : 1.0
    property real offOrbOpacity: store.currentPower ? 0.0 : 1.0

    function playLocalSfx(fileName, vol) {
        Sounds.playSfx("network/" + fileName, vol);
    }

    onInteractionLockedChanged: {
        if (interactionLocked) hoveredId = "";
    }

    focus: active && entranceReady && !drawerOpen
    Keys.onEscapePressed: {
        if (drawerOpen) {
            cancelDrawerAndRetract();
        } else if (isFullscreen) {
            exitFullscreenRequested();
        } else {
            exitToConnectedUi();
        }
    }

    // "idle" | "panToHost" | "dwellAtHost" | "slither" | "holdingBeam" | "holdingConnect"
    // | "retractError" | "pullToOrbit" | "suckToCore" | "coreCharge" | "releaseToOrbit"
    property string phase: "idle"
    property string hoveredId: ""
    property string actionTargetId: ""
    property string unlockedId: ""
    property string failedRedId: ""
    property bool pendingConnectAfterSlither: false

    property bool drawerOpen: false
    property string drawerNodeId: ""

    // Infinite 2D Camera (UNCLAMPED camX / camY for true `inf` panning!)
    property real camX: 0.0
    property real camY: 0.0
    property real camZ: isFullscreen ? 0.60 : 0.38
    property real targetCamX: 0.0
    property real targetCamY: 0.0
    property real targetCamZ: isFullscreen ? 0.60 : 0.38
    property real _panelCamX: 0.0
    property real _panelCamY: 0.0
    property real _panelCamZ: 0.38
    readonly property real zoomMin: 0.22
    readonly property real zoomMax: 1.85
    readonly property real zoomT: RadarMath.clamp((camZ - zoomMin) / Math.max(0.001, zoomMax - zoomMin), 0.0, 1.0)
    // Clean, non-fighting zoom compensation for upright node labels (crisp in BOTH Panel 565x525 & Fullscreen!)
    readonly property real nodeZoomComp: RadarMath.clamp(0.88 / Math.max(0.32, camZ), 0.78, 2.25)

    // Smooth clockwise galaxy rotation (keeps rotating smoothly even while dragging!)
    property real galaxyAngle: 0.0
    property real isolateProg: 0.0

    // Staged entrance reveal channels (wait until Fullscreen wave finishes before blooming!)
    property real bhReveal: 0.0
    property real webReveal: 0.0
    property real nodesReveal: 0.0

    // Live animation clocks & sequence progress
    property real bhTime: 0.0
    property real bhFlareProg: 0.0
    property real bhShockProg: 0.0
    property bool bhShockVisible: false
    property real slitherProg: 0.0
    property real retractProg: 1.0
    property real pullProg: 1.0
    property real suckProg: 0.0
    property real releaseProg: 0.0
    property real ejectProg: 1.0
    property real openTetherProg: 0.0
    property real impactPulseProg: 0.0
    property bool impactPulseVisible: false
    property real impactPulseX: 0.0
    property real impactPulseY: 0.0
    property real _simClock: 0.0
    property real _lightningCooldown: 0.55

    // Expanded 2x coordinate origin & closer connected orbit around Gargantua (r = 255!)
    readonly property real svgOrigin: 1500.0
    readonly property real innerOrbitRadius: blackHoleCenterMode ? 255.0 : 280.0
    readonly property real minOuterRadius: 515.0

    // Static-baked SVG strings (NEVER mutated per frame -> zero CurveRenderer lag!)
    property string bgConstellationSvg: ""
    property string hlConstellationSvg: ""
    readonly property string bhOrbitRingSvg: blackHoleCenterMode
        ? RadarMath.circleSvg(svgOrigin, svgOrigin, innerOrbitRadius)
        : "M0,0"

    // Static comet arc descriptors (each arc is baked ONCE and spun via pure GPU rotation!)
    readonly property var cometSpecs: [
        { rx: 940,  ry: 810,  tilt: 8.0,   startDeg: 22,  speedDeg: 4.9, arcRad: 1.15 },
        { rx: 1020, ry: 885,  tilt: -13.0, startDeg: 120, speedDeg: 3.9, arcRad: 1.32 },
        { rx: 1095, ry: 945,  tilt: 19.5,  startDeg: 224, speedDeg: 3.2, arcRad: 1.05 },
        { rx: 1170, ry: 1010, tilt: -22.0, startDeg: 68,  speedDeg: 2.7, arcRad: 1.25 },
        { rx: 875,  ry: 755,  tilt: 28.5,  startDeg: 286, speedDeg: 5.4, arcRad: 0.94 }
    ]

    // Internal simulation arrays & cached QML delegate references (ZERO `.itemAt()` calls in hot loop!)
    property var _nodes: []
    property var _stars: []
    property var _edges: []
    property var _packets: []
    property var _streaks: []
    property var _flashes: []
    property var _lightnings: []
    property var _cometAngles: [22.0, 120.0, 224.0, 68.0, 286.0]
    property var _pinnedActiveCoords: ({ wifi: ({}), bt: ({}) })
    property bool _galaxyBuilt: false

    property var _starItems: []
    property var _packetItems: []
    property var _streakItems: []
    property var _flashItems: []
    property var _lightningItems: []
    property var _cometItems: []
    property var _connBeamItems: []

    readonly property int starPoolCount: 420
    readonly property int packetPoolCount: 96
    readonly property int streakPoolCount: 48
    readonly property int flashPoolCount: 36
    readonly property int lightningPoolCount: 6
    readonly property int connBeamPoolCount: 6

    onIsFullscreenChanged: {
        if (isFullscreen) {
            _panelCamX = targetCamX;
            _panelCamY = targetCamY;
            _panelCamZ = targetCamZ;
            targetCamX = 0.0;
            targetCamY = 0.0;
            targetCamZ = 0.60;
        } else {
            targetCamX = _panelCamX;
            targetCamY = _panelCamY;
            targetCamZ = _panelCamZ;
        }
        // Snap immediately on Panel <-> Fullscreen reparent so Signal Wave shows crisp framing with zero jump/reload!
        camX = targetCamX;
        camY = targetCamY;
        camZ = targetCamZ;
    }

    onEntranceReadyChanged: {
        if (entranceReady && active && winVisible && !_initialIntroDone) {
            playStagedEntrance();
        } else if (!entranceReady) {
            stagedIntroAnim.stop();
            openTetherSeq.stop();
        }
    }

    onHoveredIdChanged: rebuildHighlightWebSvg()
    onDrawerNodeIdChanged: rebuildHighlightWebSvg()
    onDrawerOpenChanged: rebuildHighlightWebSvg()

    readonly property var drawerItemData: {
        if (drawerNodeId === "") return null;
        return store.firstMatch(store.currentList, d => d.id === drawerNodeId);
    }
    readonly property bool drawerItemConnected: drawerItemData ? isItemConnected(drawerItemData) : false
    readonly property string drawerLockState: {
        if (!drawerItemData || store.activeMode === "bt") return "none";
        if (failedRedId === drawerNodeId) return "error";
        if (unlockedId === drawerNodeId) return "unlocked";
        if (drawerItemData.saved) return "saved";
        return drawerItemData.locked ? "locked" : "none";
    }

    function exitToConnectedUi() {
        resetTransientState();
        store.closeSearch();
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
        const pullingPhase = (phase === "pullToOrbit" || phase === "suckToCore" || phase === "coreCharge" || phase === "releaseToOrbit");
        if (pullingPhase && item.id === actionTargetId) return true;
        if (store.activeMode === "wifi") {
            if (pullingPhase && actionTargetId !== "") return false;
            return !!item.connected;
        }
        return !!item.connected;
    }

    function computeLockState(item) {
        if (store.activeMode === "bt") return "none";
        if (failedRedId === item.id) return "error";
        if (unlockedId === item.id) return "unlocked";
        if (item.saved) return "saved";
        return item.locked ? "locked" : "none";
    }

    function seededRand(seed) {
        const s = Math.sin(seed * 12.9898 + 78.233) * 43758.5453;
        return s - Math.floor(s);
    }

    // Build ONE static elliptical arc SVG string for a comet (baked once, rotated by GPU transform!)
    function buildCometArcSvg(rx, ry, arcRad) {
        const ox = view.svgOrigin;
        const steps = 18;
        let path = "";
        for (let k = 0; k <= steps; k++) {
            const ang = -arcRad + (k / steps) * arcRad; // ends right at ang = 0 -> (rx, 0)
            const px = Math.cos(ang) * rx + ox;
            const py = Math.sin(ang) * ry + ox;
            path += (k === 0 ? "M" : "L") + px.toFixed(1) + "," + py.toFixed(1);
        }
        return path;
    }

    // Position a pooled GPU beam Rectangle from (x0, y0) to (x1, y1) (ZERO CurveRenderer cost!)
    function placeBeamItem(beamItem, x0, y0, x1, y1, thickness, isErr, op) {
        if (!beamItem) return;
        const dx = x1 - x0;
        const dy = y1 - y0;
        const len = Math.hypot(dx, dy);
        if (len < 2.0 || op <= 0.01) {
            if (beamItem.visible) beamItem.visible = false;
            return;
        }
        beamItem.x = x0;
        beamItem.y = y0 - beamItem.height * 0.5;
        beamItem.width = len;
        beamItem.rotation = Math.atan2(dy, dx) * 180.0 / Math.PI;
        beamItem.coreThickness = thickness;
        beamItem.isError = isErr;
        beamItem.opacity = op;
        if (!beamItem.visible) beamItem.visible = true;
    }

    // Infinite 2D cursor-anchored zoom (blocked when interactionLocked!)
    function zoomByAt(sx, sy, factor) {
        if (interactionLocked || !entranceReady) return;
        const vw = view.width > 0 ? view.width : 565;
        const vh = view.height > 0 ? view.height : 525;
        const oldZ = targetCamZ;
        const newZ = RadarMath.clamp(oldZ * factor, zoomMin, zoomMax);
        if (Math.abs(newZ - oldZ) < 0.0005) return;

        const wx = targetCamX + (sx - vw * 0.5) / oldZ;
        const wy = targetCamY + (sy - vh * 0.5) / oldZ;
        targetCamZ = newZ;
        targetCamX = wx - (sx - vw * 0.5) / newZ;
        targetCamY = wy - (sy - vh * 0.5) / newZ;
    }

    // Closer inner connected orbit around Gargantua's glowing golden rim (r = 255!)
    function activeRingSpot(uid, activeIndex) {
        const mode = store.activeMode;
        const cache = _pinnedActiveCoords[mode];
        if (cache && cache[uid]) return cache[uid];
        const ang = -0.38 + activeIndex * 2.18;
        const r = innerOrbitRadius + (activeIndex % 2) * 28.0;
        const spot = { x: Math.cos(ang) * r, y: Math.sin(ang) * r };
        if (!_pinnedActiveCoords[mode]) _pinnedActiveCoords[mode] = {};
        _pinnedActiveCoords[mode][uid] = spot;
        return spot;
    }

    // Auto-scaling Fibonacci spiral supporting 14 to 50+ real-world Wi-Fi networks with zero crowding!
    function computeOuterSlot(idx, sig, totalOuter) {
        const count = Math.max(12, totalOuter || 14);
        const golden = idx * 2.39996323 + 0.65;
        const rankNorm = (idx + 0.5) / count;
        const sigNorm = 1.0 - RadarMath.clamp((sig || 50) / 100.0, 0.12, 0.96);
        const radialSpan = 355.0 + Math.max(0, count - 14) * 14.5;
        const r = 530.0 + (Math.sqrt(rankNorm) * 0.58 + sigNorm * 0.42) * radialSpan;
        return {
            x: Math.cos(golden) * r,
            y: Math.sin(golden) * r * 0.88
        };
    }

    function cachePoolItems() {
        const sArr = [];
        for (let i = 0; i < starPoolCount; i++) sArr.push(starPoolRepeater.itemAt(i));
        _starItems = sArr;

        const pArr = [];
        for (let i = 0; i < packetPoolCount; i++) pArr.push(packetPoolRepeater.itemAt(i));
        _packetItems = pArr;

        const stArr = [];
        for (let i = 0; i < streakPoolCount; i++) stArr.push(streakPoolRepeater.itemAt(i));
        _streakItems = stArr;

        const flArr = [];
        for (let i = 0; i < flashPoolCount; i++) flArr.push(flashPoolRepeater.itemAt(i));
        _flashItems = flArr;

        const ltArr = [];
        for (let i = 0; i < lightningPoolCount; i++) ltArr.push(lightningFlashRepeater.itemAt(i));
        _lightningItems = ltArr;

        const cmArr = [];
        for (let i = 0; i < cometSpecs.length; i++) cmArr.push(cometArcRepeater.itemAt(i));
        _cometItems = cmArr;

        const cbArr = [];
        for (let i = 0; i < connBeamPoolCount; i++) cbArr.push(connectedBeamRepeater.itemAt(i));
        _connBeamItems = cbArr;
    }

    // Build the massive 2x constellation ONCE per mode (ZERO auto-scan cuts!)
    function rebuildFlatConstellation() {
        _clusterKey = "";
        const stars = [];
        const nodes = _nodes;
        const nodeCount = Math.max(1, nodes.length);

        stars.push({
            x: 0.0, y: 0.0,
            clusterId: "__hub__",
            size: 2.0, alpha: 0.0,
            twPhase: 0.0, twSpeed: 1.0
        });

        for (let i = 1; i < starPoolCount; i++) {
            const r1 = seededRand(i * 3.17 + 1.1);
            const r2 = seededRand(i * 5.73 + 2.3);
            const r3 = seededRand(i * 7.41 + 4.7);
            const r4 = seededRand(i * 11.13 + 8.9);

            let sx, sy, cId;
            if (i <= 165) {
                const golden = i * 2.39996323 + (r1 - 0.5) * 0.34;
                const rad = 138.0 + Math.sqrt(i / 165.0) * 540.0 + (r2 - 0.5) * 38.0;
                sx = Math.cos(golden) * rad;
                sy = Math.sin(golden) * rad * 0.90;
                cId = nearestClusterId(sx, sy);
            } else if (nodes.length > 0 && i <= 165 + nodeCount * 10) {
                const anchor = nodes[(i - 166) % nodeCount];
                cId = anchor.uid;
                const ang = r1 * Math.PI * 2.0;
                const spread = 36.0 + Math.pow(r2, 0.72) * 190.0;
                sx = anchor.homeX + Math.cos(ang) * spread;
                sy = anchor.homeY + Math.sin(ang) * spread * 0.90;
            } else {
                const arm = (i % 4) * (Math.PI * 0.5);
                const rad = 560.0 + Math.pow(r2, 0.78) * 560.0;
                const ang = arm + rad * 0.0026 + (r1 - 0.5) * 1.95;
                sx = Math.cos(ang) * rad;
                sy = Math.sin(ang) * rad * 0.88;
                cId = nearestClusterId(sx, sy);
            }

            const minCoreR = blackHoleCenterMode ? 132.0 : 78.0;
            const dCore = Math.hypot(sx, sy);
            if (dCore < minCoreR) {
                const ang = Math.atan2(sy || 0.4, sx || 0.7);
                sx = Math.cos(ang) * (minCoreR + 10.0 + r3 * 42.0);
                sy = Math.sin(ang) * (minCoreR + 10.0 + r3 * 42.0);
            }

            stars.push({
                x: sx, y: sy,
                clusterId: cId,
                size: 1.7 + Math.pow(r4, 2.2) * 3.1,
                alpha: 0.42 + r3 * 0.56,
                twPhase: r1 * Math.PI * 2.0,
                twSpeed: 0.75 + r2 * 1.45
            });
        }
        _stars = stars;

        // Build ~680 space-filling 2D constellation web edges ONCE
        const edges = [];
        const innerCandidates = [];
        for (let i = 1; i < stars.length; i++) {
            const d = Math.hypot(stars[i].x, stars[i].y);
            if (d < 300.0) innerCandidates.push({ idx: i, d: d });
        }
        innerCandidates.sort((a, b) => a.d - b.d);
        for (let k = 0; k < Math.min(20, innerCandidates.length); k++) {
            const sb = stars[innerCandidates[k].idx];
            edges.push({
                ai: -1, bi: innerCandidates[k].idx,
                ax: 0, ay: 0, bx: sb.x, by: sb.y,
                len: Math.max(1.0, Math.hypot(sb.x, sb.y)),
                angDeg: Math.atan2(sb.y, sb.x) * 180.0 / Math.PI,
                clusterId: sb.clusterId,
                fromHub: true
            });
        }

        for (let i = 1; i < stars.length && edges.length < 680; i++) {
            const a = stars[i];
            let links = 0;
            for (let j = i + 1; j < stars.length && links < 3 && edges.length < 680; j++) {
                const b = stars[j];
                const sameCluster = (a.clusterId !== "" && a.clusterId === b.clusterId);
                const maxD = sameCluster ? 186.0 : 172.0;
                const dx = b.x - a.x;
                const dy = b.y - a.y;
                const d = Math.hypot(dx, dy);
                if (d > 34.0 && d < maxD) {
                    edges.push({
                        ai: i, bi: j,
                        ax: a.x, ay: a.y, bx: b.x, by: b.y,
                        len: d,
                        angDeg: Math.atan2(dy, dx) * 180.0 / Math.PI,
                        clusterId: sameCluster ? a.clusterId : "",
                        fromHub: false
                    });
                    links++;
                }
            }
        }
        _edges = edges;

        // Bake STATIC background constellation web ONCE into its own dedicated Shape!
        const ox = view.svgOrigin;
        const bgParts = [];
        for (let e = 0; e < edges.length; e++) {
            const ed = edges[e];
            bgParts.push(
                "M" + (ed.ax + ox).toFixed(1) + "," + (ed.ay + ox).toFixed(1)
                + "L" + (ed.bx + ox).toFixed(1) + "," + (ed.by + ox).toFixed(1)
            );
        }
        view.bgConstellationSvg = bgParts.join(" ");
        rebuildHighlightWebSvg();

        // Populate 96 lively glowing light-packets
        const packets = [];
        const edgeCount = Math.max(1, edges.length);
        for (let p = 0; p < packetPoolCount; p++) {
            const r1 = seededRand(p * 4.31 + 1.9);
            const r2 = seededRand(p * 6.73 + 5.1);
            const r3 = seededRand(p * 9.17 + 2.7);
            packets.push({
                edgeIdx: Math.floor(r1 * edgeCount) % edgeCount,
                t: r2,
                dir: (p % 2 === 0) ? 1 : -1,
                speed: 0.36 + r3 * 0.82,
                isGold: (p % 3 === 0),
                size: (p % 5 === 0) ? 5.2 : (3.0 + r3 * 1.6)
            });
        }
        _packets = packets;

        // Populate 48 kinetic light-streaks
        const streaks = [];
        for (let s = 0; s < streakPoolCount; s++) {
            const r1 = seededRand(s * 5.13 + 3.3);
            const r2 = seededRand(s * 8.41 + 1.7);
            const r3 = seededRand(s * 12.19 + 4.9);
            streaks.push({
                edgeIdx: Math.floor(r1 * edgeCount) % edgeCount,
                t: r2,
                dir: (s % 2 === 0) ? 1 : -1,
                speed: 0.46 + r3 * 0.78,
                isGold: (s % 3 === 0)
            });
        }
        _streaks = streaks;

        // Populate 36 arrival star-flashes
        const flashes = [];
        for (let f = 0; f < flashPoolCount; f++) {
            flashes.push({ x: 0, y: 0, life: 0.0, maxLife: 0.48, isGold: false, active: false });
        }
        _flashes = flashes;

        // Populate 6 cosmic cloudy sheet-lightning slots
        const bolts = [];
        for (let l = 0; l < lightningPoolCount; l++) {
            bolts.push({
                active: false,
                x: 0, y: 0,
                life: 0.0, maxLife: 0.42,
                big: false,
                radius: 260.0,
                angle: 0.0,
                flicker: 0.0
            });
        }
        _lightnings = bolts;

        _galaxyBuilt = true;
        cachePoolItems();
        applyStaticStarPositions();
    }

    // The networks come and go after the galaxy is built (a real scan answers a moment after opening), so each
    // time the set changes, every star joins the cluster of the network nearest to it again: stars and lines stay
    // where they are, only which lines light up when a network is pointed at follows the current networks.
    property string _clusterKey: ""
    function refreshClusters() {
        const key = _nodes.filter(n => !n.removing).map(n => n.uid).sort().join("|");
        if (key === _clusterKey || _stars.length === 0) return;
        _clusterKey = key;
        const stars = _stars;
        for (let i = 1; i < stars.length; i++) stars[i].clusterId = nearestClusterId(stars[i].x, stars[i].y);
        for (let e = 0; e < _edges.length; e++) {
            const ed = _edges[e];
            const b = stars[ed.bi];
            if (!b) continue;
            if (ed.ai < 0) { ed.clusterId = b.clusterId; continue; }
            const a = stars[ed.ai];
            ed.clusterId = a && a.clusterId !== "" && a.clusterId === b.clusterId ? a.clusterId : "";
        }
        rebuildHighlightWebSvg();
    }

    function nearestClusterId(sx, sy) {
        let bestId = "";
        let bestD = 1e9;
        for (let k = 0; k < _nodes.length; k++) {
            const nd = _nodes[k];
            if (nd.removing) continue;
            const d = Math.hypot(sx - nd.homeX, sy - nd.homeY);
            if (d < bestD) { bestD = d; bestId = nd.uid; }
        }
        return bestId;
    }

    function applyStaticStarPositions() {
        const stars = _stars;
        for (let i = 0; i < stars.length && i < _starItems.length; i++) {
            const dot = _starItems[i];
            if (!dot) continue;
            if (i === 0) { dot.visible = false; continue; }
            const s = stars[i];
            dot.visible = true;
            dot.width = s.size;
            dot.height = s.size;
            dot.x = s.x - s.size * 0.5;
            dot.y = s.y - s.size * 0.5;
            view.setDotAlpha(dot, 1, 1, 1, s.alpha * view.webReveal);
        }
    }

    function rebuildHighlightWebSvg() {
        const focusId = drawerOpen ? drawerNodeId : (interactionLocked ? "" : hoveredId);
        if (focusId === "" || _edges.length === 0) {
            hlConstellationSvg = "";
            return;
        }
        const ox = view.svgOrigin;
        const parts = [];
        for (let e = 0; e < _edges.length; e++) {
            const ed = _edges[e];
            if (ed.clusterId === focusId) {
                parts.push(
                    "M" + (ed.ax + ox).toFixed(1) + "," + (ed.ay + ox).toFixed(1)
                    + "L" + (ed.bx + ox).toFixed(1) + "," + (ed.by + ox).toFixed(1)
                );
            }
        }
        hlConstellationSvg = parts.join(" ");
    }

    // A dot's brightness as its colour's alpha. Only written when the 8-bit alpha (all the GPU draws) or the tint
    // (`tag`) changed, so a slow twinkle costs nothing on most frames.
    readonly property color _white: "#ffffff"
    property var _tints: ({})           // tag -> the 256 alphas of that tint, made once
    function setDotAlpha(item, r, g, b, alpha, tag) {
        const t = tag || 0;
        const a8 = Math.round(Math.max(0, Math.min(1, alpha)) * 255);
        const key = a8 + t * 256;
        if (item.a8 === key) return;
        item.a8 = key;
        let pal = _tints[t];
        if (!pal) {
            pal = [];
            for (let i = 0; i < 256; i++) pal.push(Qt.rgba(r, g, b, i / 255));
            _tints[t] = pal;
        }
        item.color = pal[a8];
    }

    function triggerArrivalFlash(lx, ly, isGold) {
        for (let f = 0; f < _flashes.length; f++) {
            const fl = _flashes[f];
            if (!fl.active) {
                fl.x = lx; fl.y = ly;
                fl.life = 0.0; fl.maxLife = 0.45;
                fl.isGold = isGold;
                fl.active = true;
                return;
            }
        }
    }

    function spawnLightningAt(lx, ly, isMajor) {
        if (!view.stormGasMode || _lightnings.length === 0) return;
        let slot = null;
        for (let i = 0; i < _lightnings.length; i++) {
            if (!_lightnings[i].active) { slot = _lightnings[i]; break; }
        }
        if (!slot && isMajor) slot = _lightnings[0];
        if (!slot) return;

        slot.active = true;
        slot.x = lx;
        slot.y = ly;
        slot.life = 0.0;
        slot.maxLife = isMajor ? 0.56 : 0.42;
        slot.big = isMajor;
        slot.radius = isMajor ? 520.0 : (270.0 + Math.random() * 130.0);
        slot.angle = Math.random() * 360.0;
        slot.flicker = 0.0;
    }

    function syncNodesWithStore(initialBatch) {
        const list = store.currentList || [];
        const presentSet = {};
        let totalOuter = 0;
        for (let i = 0; i < list.length; i++) {
            if (!isItemConnected(list[i])) totalOuter++;
        }

        let connCounter = 0;
        let outerCounter = 0;
        const rad = view.galaxyAngle * Math.PI / 180.0;
        const cosA = Math.cos(rad);
        const sinA = Math.sin(rad);

        for (let i = 0; i < list.length; i++) {
            const item = list[i];
            const isLinkedNow = isItemConnected(item);
            presentSet[item.id] = true;
            const lState = computeLockState(item);
            const idx = findNodeIdx(item.id);
            const subtitle = store.activeMode === "bt"
                ? (isLinkedNow ? "Connected" : (item.kind || "Device"))
                : (isLinkedNow ? ("Connected" + (item.band ? " · " + item.band : "")) : (item.band ? item.band + " · " : "") + item.sig + "%");

            if (idx >= 0) {
                const existing = _nodes[idx];
                const wasConnected = existing.connected;
                existing.name = item.name;
                existing.sig = item.sig;
                existing.subtitle = subtitle;
                existing.icon = item.icon || "";
                existing.locked = !!item.locked;
                existing.saved = !!item.saved;
                // Preserve transit state during black hole suck / coreCharge / release / eject!
                const inBhAnim = existing.pullingIn || existing.pendingEject || existing.ejectingOut;
                if (!inBhAnim) {
                    existing.connected = isLinkedNow;
                }
                existing.lockState = lState;
                existing.removing = false;

                if (inBhAnim) {
                    if (existing.connected) connCounter++;
                    else outerCounter++;
                } else if (existing.connected && !wasConnected) {
                    const spot = activeRingSpot(item.id, connCounter++);
                    existing.homeX = spot.x;
                    existing.homeY = spot.y;
                    // connected on its own (Wi-Fi back on, a reconnect): it comes out of the black hole
                    view.emergeFromCore(existing);
                } else if (!existing.connected && wasConnected && !existing.ejectingOut) {
                    if (_pinnedActiveCoords[store.activeMode]) {
                        delete _pinnedActiveCoords[store.activeMode][item.id];
                    }
                    const slot = computeOuterSlot(outerCounter++, item.sig, totalOuter);
                    existing.homeX = slot.x;
                    existing.homeY = slot.y;
                    existing.releasingOut = true;
                } else if (existing.connected) {
                    connCounter++;
                } else {
                    if (Math.hypot(existing.homeX, existing.homeY) < minOuterRadius) {
                        const slot = computeOuterSlot(outerCounter, item.sig, totalOuter);
                        existing.homeX = slot.x;
                        existing.homeY = slot.y;
                    }
                    outerCounter++;
                }

                const mi = findModelIdx(item.id);
                if (mi >= 0) {
                    const dispSub = existing.connected
                        ? (store.activeMode === "bt" ? "Connected" : ("Connected" + (item.band ? " · " + item.band : "")))
                        : (store.activeMode === "bt" ? (item.kind || "Device") : ((item.band ? item.band + " · " : "") + item.sig + "%"));
                    nodeModel.setProperty(mi, "sig", item.sig);
                    nodeModel.setProperty(mi, "subtitle", dispSub);
                    nodeModel.setProperty(mi, "connected", existing.connected);
                    nodeModel.setProperty(mi, "locked", !!item.locked);
                    nodeModel.setProperty(mi, "saved", !!item.saved);
                    nodeModel.setProperty(mi, "lockState", lState);
                }
            } else {
                const pos = isLinkedNow
                    ? activeRingSpot(item.id, connCounter++)
                    : computeOuterSlot(outerCounter++, item.sig, totalOuter);
                const wx = pos.x * cosA - pos.y * sinA;
                const wy = pos.x * sinA + pos.y * cosA;
                const n = {
                    uid: item.id,
                    name: item.name,
                    subtitle: subtitle,
                    sig: item.sig,
                    icon: item.icon || "",
                    locked: !!item.locked,
                    saved: !!item.saved,
                    connected: isLinkedNow,
                    lockState: lState,
                    homeX: pos.x, homeY: pos.y,
                    lx: pos.x, ly: pos.y,
                    wx: wx, wy: wy,
                    pullStartX: pos.x, pullStartY: pos.y,
                    ejectStartX: pos.x, ejectStartY: pos.y,
                    pullingIn: false,
                    spitting: false,
                    releasingOut: false,
                    pendingEject: false,
                    ejectingOut: false,
                    phaseOffset: (i * 1.47) % (Math.PI * 2),
                    appear: initialBatch ? 0.0 : 0.15,
                    removing: false
                };
                _nodes.push(n);
                if (isLinkedNow && !initialBatch) emergeFromCore(n);
                nodeModel.append({
                    uid: n.uid,
                    name: n.name,
                    subtitle: n.subtitle,
                    sig: n.sig,
                    icon: n.icon,
                    locked: n.locked,
                    saved: n.saved,
                    connected: n.connected,
                    lockState: n.lockState,
                    isBt: store.activeMode === "bt",
                    nx: wx,
                    ny: wy,
                    nScale: 0.4,
                    nOpacity: 0.0
                });
            }
        }

        for (let i = 0; i < _nodes.length; i++) {
            if (!presentSet[_nodes[i].uid]) _nodes[i].removing = true;
        }

        if (!_galaxyBuilt || _stars.length === 0) {
            rebuildFlatConstellation();
        }
        Qt.callLater(refreshClusters);
    }

    function resetTransientState() {
        phase = "idle";
        hoveredId = "";
        actionTargetId = "";
        drawerOpen = false;
        drawerNodeId = "";
        unlockedId = "";
        failedRedId = "";
        pendingConnectAfterSlither = false;
        slitherProg = 0.0;
        retractProg = 1.0;
        pullProg = 1.0;
        suckProg = 0.0;
        releaseProg = 0.0;
        ejectProg = 1.0;
        activeBeamItem.visible = false;
        hoverBeamItem.visible = false;
        activeBeamTip.visible = false;
        for (let i = 0; i < _nodes.length; i++) {
            _nodes[i].pullingIn = false;
            _nodes[i].releasingOut = false;
            _nodes[i].pendingEject = false;
            _nodes[i].ejectingOut = false;
        }
        hostDwellTimer.stop();
        slitherAnim.stop();
        retractAnim.stop();
        pullAnim.stop();
        suckAnim.stop();
        coreChargeTimer.stop();
        releaseAnim.stop();
        ejectAnim.stop();
        unlockPauseTimer.stop();
        connectHoldTimer.stop();
    }

    function syncPowerVisualsImmediate() {
        powerOffSeq.stop();
        powerOnSeq.stop();
        powerBurstSeq.stop();
        charging = false;
        burstFlashVisible = false;
        burstFlashProg = 0.0;
        bhPowerVortex = 0.0;
        bhPowerPulse = 0.0;
        bhSpinBoost = 1.0;
        galaxySpinBoost = 0.0;
        if (store.currentPower) {
            powerAnimState = "on";
            bhPowerScale = 1.0;
            galaxySuckScale = 1.0;
            galaxySuckOpacity = 1.0;
            nodeRadialMult = 1.0;
            nodePowerOpacity = 1.0;
            offOrbScale = 0.0;
            offOrbOpacity = 0.0;
        } else {
            powerAnimState = "off";
            bhPowerScale = 0.0;
            galaxySuckScale = 0.0;
            galaxySuckOpacity = 0.0;
            nodeRadialMult = 0.0;
            nodePowerOpacity = 0.0;
            offOrbScale = 1.0;
            offOrbOpacity = 1.0;
            bhReveal = 1.0;
            webReveal = 0.0;
            nodesReveal = 0.0;
            openTetherProg = 0.0;
        }
    }

    // The radio switched on or off by anything else (NetworkManager starting up, another page, a key): the black hole
    // follows with its own power animation when shown, or settles at once when not; its own toggle is left alone
    Connections {
        target: view.store
        function onCurrentPowerChanged() { Qt.callLater(view.followPower); }
    }
    function followPower() {
        if (powerAnimState === "turningOff" || powerAnimState === "turningOn") return;
        if (powerAnimState === (store.currentPower ? "on" : "off")) return;
        if (active && winVisible && entranceReady && view.visible) requestPowerToggle();
        else syncPowerVisualsImmediate();
    }

    function requestPowerToggle() {
        if (!active || !entranceReady) return;
        if (powerAnimState === "turningOff" || powerAnimState === "turningOn") return;

        const baseZ = isFullscreen ? 0.60 : 0.38;
        if (powerAnimState === "on") {
            resetTransientState();
            stagedIntroAnim.stop();
            openTetherSeq.stop();
            powerOnSeq.stop();
            bhReveal = 1.0;
            webReveal = 1.0;
            nodesReveal = 1.0;
            bhPowerScale = 1.0;
            bhPowerVortex = 0.0;
            bhPowerPulse = 0.0;
            bhSpinBoost = 1.0;
            galaxySuckScale = 1.0;
            galaxySuckOpacity = 1.0;
            galaxySpinBoost = 0.0;
            nodeRadialMult = 1.0;
            nodePowerOpacity = 1.0;
            offOrbScale = 0.0;
            offOrbOpacity = 0.0;
            burstFlashVisible = false;
            targetCamX = 0.0;
            targetCamY = 0.0;
            targetCamZ = baseZ;
            powerAnimState = "turningOff";
            playLocalSfx("bh_power_off_implode.wav", 0.84);
            powerOffSeq.restart();
        } else {
            resetTransientState();
            stagedIntroAnim.stop();
            openTetherSeq.stop();
            powerOffSeq.stop();
            powerBurstSeq.stop();
            charging = false;
            camX = 0.0;
            camY = 0.0;
            camZ = baseZ;
            targetCamX = 0.0;
            targetCamY = 0.0;
            targetCamZ = baseZ;
            bhReveal = 1.0;
            webReveal = 1.0;
            nodesReveal = 1.0;
            openTetherProg = 0.0;
            bhPowerScale = 0.0;
            bhPowerVortex = 0.0;
            bhPowerPulse = 0.0;
            bhSpinBoost = 1.0;
            galaxySuckScale = 0.04;
            galaxySuckOpacity = 0.0;
            galaxySpinBoost = 0.0;
            nodeRadialMult = 0.0;
            nodePowerOpacity = 0.0;
            burstFlashVisible = false;
            burstFlashProg = 0.0;
            // every network comes out fresh with the burst (old nodes would keep their old connected state)
            _nodes = [];
            nodeModel.clear();
            powerAnimState = "turningOn";
            // the radio goes on as the charge starts, so the scan can finish before the burst
            store.setPowerImmediate(true);
            syncNodesWithStore(false);
            cachePoolItems();
            powerOnSeq.restart();
        }
    }

    // Smooth 3-stage bloom entrance triggered ONCE on initial open (never wipes/reloads on Panel <-> Fullscreen!)
    function playStagedEntrance() {
        _initialIntroDone = true;
        stagedIntroAnim.stop();
        openTetherSeq.stop();
        camX = 0.0;
        camY = 0.0;
        camZ = isFullscreen ? 0.68 : 0.44;
        targetCamX = 0.0;
        targetCamY = 0.0;
        targetCamZ = isFullscreen ? 0.60 : 0.38;
        resetTransientState();
        syncNodesWithStore(true);
        cachePoolItems();
        syncPowerVisualsImmediate();
        if (!store.currentPower) {
            camZ = targetCamZ;
            return;
        }
        bhReveal = 0.0;
        webReveal = 0.0;
        nodesReveal = 0.0;
        openTetherProg = 0.0;
        stagedIntroAnim.restart();
        openTetherSeq.restart();
    }

    function desiredLeftDrawerFocusX(nodeWorldX) {
        const drawerShiftWorld = (view.width * (isFullscreen ? 0.12 : 0.205)) / Math.max(0.32, targetCamZ);
        return nodeWorldX - drawerShiftWorld;
    }

    function startBeamRetract(isError) {
        const curFrac = (phase === "slither") ? slitherProg : (phase === "holdingBeam" ? 1.0 : 0.0);
        hostDwellTimer.stop();
        slitherAnim.stop();
        if (curFrac <= 0.02 || actionTargetId === "") {
            phase = "idle";
            actionTargetId = "";
            activeBeamItem.visible = false;
            activeBeamTip.visible = false;
            return;
        }
        pendingConnectAfterSlither = false;
        retractProg = curFrac;
        phase = "retractError";
        store.playProfileSfx("retract");
        retractAnim.from = curFrac;
        retractAnim.to = 0.0;
        retractAnim.duration = Math.max(240, Math.round(780 * curFrac));
        retractAnim.restart();
    }

    function cancelDrawerAndRetract() {
        if (!drawerOpen) return;
        // a password still being tried is dropped (and its half-made profile forgotten)
        if (checkingPwdId !== "") { checkingPwdId = ""; store.cancelPsk(); }
        Sounds.playSfx("reusables/clickbutton/click.wav", 0.35);
        infoDrawer.clearInput();
        drawerOpen = false;
        drawerNodeId = "";
        failedRedId = "";
        syncNodesWithStore(false);
        if (phase === "slither" || phase === "holdingBeam") {
            startBeamRetract(false);
        } else {
            actionTargetId = "";
            phase = "idle";
        }
        view.forceActiveFocus();
    }

    function triggerNodeClick(uid) {
        if (!active || !entranceReady || interactionLocked) return;
        const item = store.firstMatch(store.currentList, d => d.id === uid);
        if (!item) return;

        hostDwellTimer.stop();
        slitherAnim.stop();
        retractAnim.stop();
        unlockPauseTimer.stop();
        connectHoldTimer.stop();
        clearRedDelayTimer.stop();

        hoveredId = "";
        store.selectedId = uid;
        failedRedId = "";
        unlockedId = "";
        pendingConnectAfterSlither = false;

        if (isItemConnected(item)) {
            actionTargetId = uid;
            drawerNodeId = uid;
            drawerOpen = true;
            phase = "idle";
            const idx = findNodeIdx(uid);
            if (idx >= 0) {
                targetCamX = desiredLeftDrawerFocusX(_nodes[idx].wx);
                targetCamY = _nodes[idx].wy;
            }
            Sounds.playSfx("reusables/clickbutton/click.wav", 0.38);
            syncNodesWithStore(false);
            return;
        }

        // Unconnected node -> exact [1/2] panToHost -> dwellAtHost (500ms) -> slither beam tracking!
        drawerOpen = false;
        drawerNodeId = "";
        actionTargetId = uid;
        slitherProg = 0.0;
        retractProg = 1.0;
        activeBeamItem.visible = false;
        activeBeamTip.visible = false;
        syncNodesWithStore(false);

        const trackZoom = isFullscreen ? 0.72 : 0.46;
        targetCamX = 0.0;
        targetCamY = 0.0;
        targetCamZ = trackZoom;

        if (Math.hypot(camX, camY) < 3.0 && Math.abs(camZ - trackZoom) < 0.03) {
            camX = 0.0;
            camY = 0.0;
            camZ = trackZoom;
            phase = "dwellAtHost";
            hostDwellTimer.restart();
        } else {
            phase = "panToHost";
        }
    }

    // the password is tried for real (NetworkStore connects with it); passwordResult() goes on with the answer
    property string checkingPwdId: ""
    function handleSubmitPassword(uid, password) {
        if (uid === "" || uid !== drawerNodeId || checkingPwdId !== "") return;
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
        if (uid === "" || uid !== drawerNodeId) return;
        if (ok) {
            slitherAnim.stop();
            store.playProfileSfx("unlock");
            failedRedId = "";
            unlockedId = uid;
            actionTargetId = uid;
            store.markWifiSaved(uid);
            syncNodesWithStore(false);
            drawerOpen = false;
            drawerNodeId = "";
            slitherProg = 1.0;
            phase = "holdingConnect";
            unlockPauseTimer.restart();
        } else {
            store.playProfileSfx("wrong");
            infoDrawer.clearInput();
            drawerOpen = false;
            drawerNodeId = "";
            failedRedId = uid;
            actionTargetId = uid;
            syncNodesWithStore(false);
            view.forceActiveFocus();
            startBeamRetract(true);
        }
    }

    function beginConnectHold() {
        if (actionTargetId === "") return;
        connectHoldTimer.stop();
        slitherProg = 1.0;
        phase = "holdingConnect";
        Sounds.playSfx("reusables/clickbutton/click.wav", 0.32);
        connectHoldTimer.restart();
    }

    function handleDirectConnect(uid) {
        if (uid === "" || uid !== drawerNodeId) return;
        // the real connection starts now, while the slither and orbit animation play
        store.beginConnect(uid);
        actionTargetId = uid;
        failedRedId = "";
        drawerOpen = false;
        drawerNodeId = "";
        if (phase === "slither") {
            pendingConnectAfterSlither = true;
            return;
        }
        beginConnectHold();
    }

    function handleDisconnect(uid) {
        if (uid === "") return;
        drawerOpen = false;
        drawerNodeId = "";
        actionTargetId = "";
        phase = "idle";
        activeBeamItem.visible = false;
        activeBeamTip.visible = false;
        if (_pinnedActiveCoords[store.activeMode]) {
            delete _pinnedActiveCoords[store.activeMode][uid];
        }
        store.disconnectItem(uid, true);
        syncNodesWithStore(false);
        view.forceActiveFocus();
    }

    // A network that connected by itself (not through the connect animation) appears from the core and flies out
    // to its orbit, with a small golden flash, instead of drifting in from outside.
    // connected on its own (Wi-Fi back on, a reconnect): it waits in the core and is spat out to its connected
    // place, at the burst while the power comes on, or at once
    function emergeFromCore(n) {
        if (!blackHoleCenterMode || phase !== "idle") return;
        n.lx = 0.0;
        n.ly = 0.0;
        n.spitting = true;
        if (powerAnimState === "turningOn") return;
        spitProg = 0.0;
        triggerArrivalFlash(0.0, 0.0, true);
        spitOut();
    }

    // Item #2: In blackHoleCenterMode, previously connected Wi-Fi stays orbiting UNTIL the new Wi-Fi
    // actually enters the black hole core (suckAnim.onFinished), THEN immediately ejects outward!
    function enterPullToOrbitPhase() {
        const mode = store.activeMode;
        const isMultiBt = (mode === "bt");
        if (!_pinnedActiveCoords[mode]) _pinnedActiveCoords[mode] = {};

        for (let i = 0; i < _nodes.length; i++) {
            _nodes[i].pullStartX = _nodes[i].lx;
            _nodes[i].pullStartY = _nodes[i].ly;
            _nodes[i].pullingIn = false;
            _nodes[i].releasingOut = false;
            _nodes[i].pendingEject = false;
            _nodes[i].ejectingOut = false;
        }

        let outerIdx = 0;
        const totalOuter = Math.max(12, _nodes.length);
        for (let i = 0; i < _nodes.length; i++) {
            const n = _nodes[i];
            if (n.removing) continue;
            if (n.uid === actionTargetId) {
                n.connected = true;
                n.pullingIn = true;
                const ang = Math.atan2(n.ly, n.lx);
                const pullR = blackHoleCenterMode ? innerOrbitRadius : (isMultiBt ? 295.0 : 280.0);
                // Launch straight out in a random direction onto close orbit around Gargantua!
                const relAng = blackHoleCenterMode ? (Math.random() * Math.PI * 2.0) : ang;
                const tx = Math.cos(relAng) * pullR;
                const ty = Math.sin(relAng) * pullR;
                if (!isMultiBt) _pinnedActiveCoords[mode] = {};
                _pinnedActiveCoords[mode][n.uid] = { x: tx, y: ty };
                n.homeX = tx;
                n.homeY = ty;
            } else if (!isMultiBt && n.connected) {
                if (blackHoleCenterMode) {
                    // Keep old Wi-Fi orbiting around Gargantua until new Wi-Fi hits the core!
                    n.pendingEject = true;
                } else {
                    n.connected = false;
                    n.releasingOut = true;
                    const slot = computeOuterSlot(outerIdx++, n.sig, totalOuter);
                    n.homeX = slot.x;
                    n.homeY = slot.y;
                }
            }
        }

        targetCamX = 0.0;
        targetCamY = 0.0;
        targetCamZ = isFullscreen ? 0.60 : 0.38;
        store.playProfileSfx("pull");
        syncNodesWithStore(false);

        if (blackHoleCenterMode) {
            suckProg = 0.0;
            releaseProg = 0.0;
            ejectProg = 1.0;
            phase = "suckToCore";
            suckAnim.restart();
        } else {
            pullProg = 0.0;
            phase = "pullToOrbit";
            pullAnim.restart();
        }
    }

    // Triggered the exact instant the newly connecting Wi-Fi hits Gargantua's core (0, 0)!
    function ejectPreviousConnectedFromCore() {
        const totalOuter = Math.max(12, _nodes.length);
        let outerIdx = 0;
        let anyEjected = false;
        for (let i = 0; i < _nodes.length; i++) {
            const n = _nodes[i];
            if (!n.pendingEject) continue;
            n.pendingEject = false;
            n.connected = false;
            n.ejectingOut = true;
            n.ejectStartX = n.lx;
            n.ejectStartY = n.ly;
            // Fling outward along its current radial direction to a clean outer slot!
            const curAng = Math.atan2(n.ly, n.lx);
            const targetR = 620.0 + (outerIdx % 3) * 95.0;
            n.homeX = Math.cos(curAng) * targetR;
            n.homeY = Math.sin(curAng) * targetR * 0.88;
            outerIdx++;
            anyEjected = true;

            const mi = findModelIdx(n.uid);
            if (mi >= 0) {
                const srcItem = store.firstMatch(store.currentList, d => d.id === n.uid);
                const ejSub = srcItem
                    ? (store.activeMode === "bt"
                        ? (srcItem.kind || "Device")
                        : ((srcItem.band ? srcItem.band + " · " : "") + srcItem.sig + "%"))
                    : n.subtitle;
                nodeModel.setProperty(mi, "connected", false);
                nodeModel.setProperty(mi, "subtitle", ejSub);
            }
        }
        if (anyEjected) {
            ejectProg = 0.0;
            ejectAnim.restart();
        }
    }

    onActiveChanged: {
        if (active && winVisible && entranceReady && !_initialIntroDone) {
            playStagedEntrance();
        } else if (!active) {
            stagedIntroAnim.stop();
            openTetherSeq.stop();
            resetTransientState();
        }
    }
    onWinVisibleChanged: {
        if (!winVisible) stopChargeSound();      // the charge goes on silently while the panel is closed
        if (active && winVisible && entranceReady && !_initialIntroDone) playStagedEntrance();
    }
    Component.onCompleted: {
        syncNodesWithStore(true);
        Qt.callLater(cachePoolItems);
        if (active && winVisible && entranceReady && !_initialIntroDone) playStagedEntrance();
    }

    NumberAnimation {
        id: modeSwapNodesAnim
        target: view
        property: "nodesReveal"
        duration: 240
        easing.type: Easing.OutCubic
    }

    Connections {
        target: view.store
        function onCurrentListChanged() {
            view.listChangedAt = Date.now();
            view.syncNodesWithStore(false);
        }
        function onModeSwitchingChanged() {
            if (view.store.modeSwitching && view.powerAnimState === "on") {
                modeSwapNodesAnim.stop();
                modeSwapNodesAnim.from = view.nodesReveal;
                modeSwapNodesAnim.to = 0.0;
                modeSwapNodesAnim.duration = 150;
                modeSwapNodesAnim.restart();
            }
        }
        function onActiveModeChanged() {
            view.resetTransientState();
            view._nodes = [];
            view._galaxyBuilt = false;
            nodeModel.clear();
            view.syncNodesWithStore(true);
            view.syncPowerVisualsImmediate();
            view.openTetherProg = 0.0;
            if (view.entranceReady && view.store.currentPower) {
                // Keep Gargantua & cosmic backdrop 100% unbroken; smoothly reveal the new mode's nodes & tether!
                view.bhReveal = 1.0;
                view.webReveal = 1.0;
                modeSwapNodesAnim.stop();
                modeSwapNodesAnim.from = 0.0;
                modeSwapNodesAnim.to = 1.0;
                modeSwapNodesAnim.duration = 280;
                modeSwapNodesAnim.restart();
                openTetherSeq.restart();
            }
        }
    }

    Timer {
        id: autoScanTimer
        interval: 10000
        repeat: true
        running: view.active && view.winVisible && view.visible && view.entranceReady && !view.interactionLocked
        onTriggered: view.store.runAutoScanTick()
    }
    // Wi-Fi switched back on: its 10 s scan cycle starts again from zero
    Connections {
        target: view.store
        function onRadioReturned(mode) { if (mode === view.store.activeMode) autoScanTimer.restart(); }
    }

    // 3-Stage Smooth Bloom Entrance (runs ONLY AFTER Fullscreen wave finishes!)
    ParallelAnimation {
        id: stagedIntroAnim
        NumberAnimation {
            target: view; property: "bhReveal"
            from: 0.0; to: 1.0; duration: 480; easing.type: Easing.OutCubic
        }
        SequentialAnimation {
            PauseAnimation { duration: 140 }
            NumberAnimation {
                target: view; property: "webReveal"
                from: 0.0; to: 1.0; duration: 560; easing.type: Easing.OutCubic
            }
        }
        SequentialAnimation {
            PauseAnimation { duration: 280 }
            NumberAnimation {
                target: view; property: "nodesReveal"
                from: 0.0; to: 1.0; duration: 520; easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: openTetherSeq
        PauseAnimation { duration: 440 }
        NumberAnimation {
            target: view
            property: "openTetherProg"
            from: 0.0; to: 1.0
            duration: 760
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
        from: 0.0; to: 1.0
        duration: 840
        easing.type: Easing.InOutCubic
        onFinished: {
            if (view.phase !== "slither") return;
            view.store.playProfileSfx("impact");
            const iIdx = view.findNodeIdx(view.actionTargetId);
            if (iIdx >= 0) {
                const tn = view._nodes[iIdx];
                view.impactPulseX = tn.wx;
                view.impactPulseY = tn.wy;
                view.impactPulseVisible = true;
                view.impactPulseProg = 0.0;
                impactAnim.restart();
                if (view.stormGasMode) {
                    view.spawnLightningAt(tn.lx, tn.ly, true);
                }
                view.targetCamX = view.desiredLeftDrawerFocusX(tn.wx);
                view.targetCamY = tn.wy;
            }
            if (view.pendingConnectAfterSlither) {
                view.pendingConnectAfterSlither = false;
                view.beginConnectHold();
            } else {
                view.drawerNodeId = view.actionTargetId;
                view.drawerOpen = true;
                view.phase = "holdingBeam";
            }
        }
    }

    NumberAnimation {
        id: impactAnim
        target: view
        property: "impactPulseProg"
        from: 0.0; to: 1.0
        duration: 420
        easing.type: Easing.OutCubic
        onFinished: view.impactPulseVisible = false
    }

    NumberAnimation {
        id: retractAnim
        target: view
        property: "retractProg"
        from: 1.0; to: 0.0
        duration: 780
        easing.type: Easing.InOutCubic
        onFinished: {
            view.phase = "idle";
            view.actionTargetId = "";
            activeBeamItem.visible = false;
            activeBeamTip.visible = false;
            clearRedDelayTimer.restart();
        }
    }

    Timer {
        id: unlockPauseTimer
        interval: 500
        onTriggered: {
            if (view.actionTargetId !== "") view.enterPullToOrbitPhase();
        }
    }

    Timer {
        id: connectHoldTimer
        interval: 500
        onTriggered: {
            if (view.phase === "holdingConnect" && view.actionTargetId !== "") {
                view.enterPullToOrbitPhase();
            }
        }
    }

    NumberAnimation {
        id: pullAnim
        target: view
        property: "pullProg"
        from: 0.0; to: 1.0
        duration: 780
        easing.type: Easing.InOutCubic
        onFinished: {
            if (view.phase === "pullToOrbit" && view.actionTargetId !== "") {
                const tid = view.actionTargetId;
                const stayOpen = view.isFullscreen;
                view.resetTransientState();
                view.store.finalizeConnection(tid, stayOpen);
            }
        }
    }

    // Stage 1: Gravitational spiral pull into Gargantua core (old Wi-Fi stays orbiting until impact!)
    NumberAnimation {
        id: suckAnim
        target: view
        property: "suckProg"
        from: 0.0; to: 1.0
        duration: 660
        easing.type: Easing.InCubic
        onFinished: {
            if (view.phase !== "suckToCore" || view.actionTargetId === "") return;
            view.phase = "coreCharge";
            view.bhShockVisible = true;
            view.bhShockProg = 0.0;
            bhFlareSeq.restart();
            bhShockAnim.restart();
            if (view.stormGasMode) {
                view.spawnLightningAt(0.0, 0.0, true);
            }
            // Item #2: Old connected Wi-Fi immediately detaches & ejects outward RIGHT NOW!
            view.ejectPreviousConnectedFromCore();
            coreChargeTimer.restart();
        }
    }

    // Smooth outward ejection of previously connected Wi-Fi triggered on black hole core impact
    NumberAnimation {
        id: ejectAnim
        target: view
        property: "ejectProg"
        from: 0.0; to: 1.0
        duration: 760
        easing.type: Easing.OutCubic
        onFinished: {
            for (let i = 0; i < view._nodes.length; i++) {
                view._nodes[i].ejectingOut = false;
            }
        }
    }

    // Stage 2: Golden charge inside Gargantua core before launching the new Wi-Fi
    Timer {
        id: coreChargeTimer
        interval: 220
        onTriggered: {
            if (view.phase !== "coreCharge" || view.actionTargetId === "") return;
            view.releaseProg = 0.0;
            view.phase = "releaseToOrbit";
            view.store.playProfileSfx("impact");
            releaseAnim.restart();
        }
    }

    // Stage 3: Smooth slingshot release out from core into close golden orbit around Gargantua (r = 255!)
    NumberAnimation {
        id: releaseAnim
        target: view
        property: "releaseProg"
        from: 0.0; to: 1.0
        duration: 740
        easing.type: Easing.OutBack
        easing.overshoot: 0.50
        onFinished: {
            if (view.phase === "releaseToOrbit" && view.actionTargetId !== "") {
                const tid = view.actionTargetId;
                const stayOpen = view.isFullscreen || view.blackHoleCenterMode;
                // Lock final orbit position before finalizing so node transitions seamlessly with zero snap!
                const tIdx = view.findNodeIdx(tid);
                if (tIdx >= 0) {
                    const tn = view._nodes[tIdx];
                    tn.lx = tn.homeX;
                    tn.ly = tn.homeY;
                    const mode = view.store.activeMode;
                    if (!view._pinnedActiveCoords[mode]) view._pinnedActiveCoords[mode] = {};
                    if (mode !== "bt") view._pinnedActiveCoords[mode] = {};
                    view._pinnedActiveCoords[mode][tid] = { x: tn.homeX, y: tn.homeY };
                }
                view.resetTransientState();
                view.store.finalizeConnection(tid, stayOpen);
            }
        }
    }

    SequentialAnimation {
        id: bhFlareSeq
        NumberAnimation { target: view; property: "bhFlareProg"; from: 0.0; to: 1.0; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: view; property: "bhFlareProg"; from: 1.0; to: 0.0; duration: 520; easing.type: Easing.OutCubic }
    }

    NumberAnimation {
        id: bhShockAnim
        target: view
        property: "bhShockProg"
        from: 0.0; to: 1.0
        duration: 640
        easing.type: Easing.OutCubic
        onFinished: view.bhShockVisible = false
    }

    Timer {
        id: clearRedDelayTimer
        interval: 1400
        onTriggered: {
            view.failedRedId = "";
            view.syncNodesWithStore(false);
        }
    }

    // ------------------------------------------------------------------
    // Power OFF Sequence (~1.22s): Swell -> Vacuum Implosion -> Cave-In to Zero -> Bouncy Wi-Fi Orb!
    // ------------------------------------------------------------------
    SequentialAnimation {
        id: powerOffSeq

        // Stage 1 + 2: Black hole swells hungry (0..220ms) & sucks entire galaxy + all nodes into (0,0) (170..660ms)
        ParallelAnimation {
            NumberAnimation { target: view; property: "bhPowerScale"; from: 1.0; to: 1.48; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: view; property: "bhPowerVortex"; from: 0.0; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: view; property: "bhSpinBoost"; from: 1.0; to: 3.6; duration: 480; easing.type: Easing.InQuad }

            SequentialAnimation {
                PauseAnimation { duration: 150 }
                ParallelAnimation {
                    NumberAnimation { target: view; property: "galaxySuckScale"; from: 1.0; to: 0.025; duration: 510; easing.type: Easing.InCubic }
                    NumberAnimation { target: view; property: "galaxySuckOpacity"; from: 1.0; to: 0.0; duration: 490; easing.type: Easing.InQuad }
                    NumberAnimation { target: view; property: "galaxySpinBoost"; from: 0.0; to: 215.0; duration: 510; easing.type: Easing.InCubic }
                    NumberAnimation { target: view; property: "nodeRadialMult"; from: 1.0; to: 0.0; duration: 490; easing.type: Easing.InCubic }
                    NumberAnimation { target: view; property: "nodePowerOpacity"; from: 1.0; to: 0.0; duration: 460; easing.type: Easing.InQuad }
                    NumberAnimation { target: view; property: "openTetherProg"; from: 1.0; to: 0.0; duration: 320; easing.type: Easing.InQuad }
                }
            }
        }

        // Stage 3: Black hole caves in & implodes completely into nothingness (660..860ms)
        ParallelAnimation {
            NumberAnimation {
                target: view; property: "bhPowerScale"
                from: 1.48; to: 0.0
                duration: 200
                easing.type: Easing.InBack
                easing.overshoot: 1.15
            }
            SequentialAnimation {
                NumberAnimation { target: view; property: "bhPowerPulse"; from: 0.0; to: 1.25; duration: 80; easing.type: Easing.OutQuad }
                NumberAnimation { target: view; property: "bhPowerPulse"; from: 1.25; to: 0.0; duration: 120; easing.type: Easing.InQuad }
            }
        }

        ScriptAction {
            script: {
                view.store.setPowerImmediate(false);
                view.bhPowerVortex = 0.0;
                view.bhSpinBoost = 1.0;
                view.galaxySpinBoost = 0.0;
                if (view.winVisible) view.playLocalSfx("bh_orb_pop.wav", 0.78);
            }
        }

        // Stage 4: Juicy Bouncy Wi-Fi / BT Orb pops out at center (860..1220ms)
        ParallelAnimation {
            NumberAnimation {
                target: view; property: "offOrbScale"
                from: 0.0; to: 1.0
                duration: 360
                easing.type: Easing.OutBack
                easing.overshoot: 2.05
            }
            NumberAnimation {
                target: view; property: "offOrbOpacity"
                from: 0.0; to: 1.0
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        onFinished: {
            view.powerAnimState = "off";
        }
    }

    // ------------------------------------------------------------------
    // Power ON Sequence (~0.82s): Orb -> Hyper-Spin Charge -> LOUD Thunderclap Big-Bang Scatter!
    // ------------------------------------------------------------------
    SequentialAnimation {
        id: powerOnSeq

        // Stage 1: the orb gives way; the black hole then grows from nothing as it charges
        ParallelAnimation {
            NumberAnimation { target: view; property: "offOrbScale"; from: 1.0; to: 0.0; duration: 130; easing.type: Easing.InBack; easing.overshoot: 1.2 }
            NumberAnimation { target: view; property: "offOrbOpacity"; from: 1.0; to: 0.0; duration: 110; easing.type: Easing.InQuad }
            SequentialAnimation {
                PauseAnimation { duration: 40 }
                NumberAnimation { target: view; property: "bhPowerScale"; from: 0.0; to: view.chargeFrom; duration: 300; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            }
        }
        // Stage 2: the charge (chargeTick), for as long as the connection takes
        ScriptAction { script: view.startCharging() }
    }

    // ---------- the charge: grows towards 70 % without reaching it, sparks and field lines build up ----------
    // It ends when Wi-Fi is connected (NetworkManager reconnects a saved network), or once the scan has settled
    // with no saved network in range to wait for; never longer than 20 s. Bluetooth bursts after a short charge.
    readonly property real chargeFrom: 0.0
    readonly property real chargeTo: 0.7
    property bool charging: false
    property real chargeLevel: 0.0          // 0..1, how built-up the charge is (sparks, field lines, sound)
    property real chargeStartedAt: 0
    property real chargeTime: 0.0           // seconds since the charge began (the light's flow)
    property real listChangedAt: 0
    function startCharging() {
        chargeStartedAt = Date.now();
        chargeLevel = 0.0;
        spitProg = 0.0;
        charging = true;
    }
    function scanSettled() { return (store.currentList || []).length > 0 && Date.now() - listChangedAt >= 450; }
    function readyToBurst(elapsed) {
        // Bluetooth comes on quickly: still charge at least 1.5 s
        if (store.activeMode !== "wifi") return (elapsed >= 1500 && store.currentPower) || elapsed >= 20000;
        if (store.nets_realConnected() !== "") return true;
        if (elapsed >= 1500 && scanSettled() && !store.currentList.some(n => n.saved)) return true;
        return elapsed >= 20000;
    }
    function chargeTick() {
        const elapsed = Date.now() - chargeStartedAt;
        const t = elapsed / 1000.0;
        chargeLevel = 1.0 - Math.exp(-t / 3.0);
        bhPowerScale = chargeFrom + (chargeTo - chargeFrom) * chargeLevel;
        // spinning ever faster, the energy pulsing harder and quicker
        bhSpinBoost = 1.0 + 14.0 * Math.pow(chargeLevel, 1.4);
        bhPowerPulse = (0.4 + 2.0 * chargeLevel) * (0.85 + 0.15 * Math.sin(t * (8.0 + 14.0 * chargeLevel)));
        chargeTime = t;
        if (readyToBurst(elapsed)) {
            charging = false;
            powerBurstSeq.restart();
        }
    }
    FrameAnimation { running: view.charging; onTriggered: view.chargeTick() }
    // the charge sound: one 20 s charge-up (its hum rises on the same curve as the hole), cut by the burst
    property int chargeSoundId: -1
    // silent while the panel is closed (the charge goes on unseen until the radio is done)
    onChargingChanged: {
        if (charging && winVisible) chargeSoundId = Sounds.playUntilStopped("network/bh_charge_up.wav", 0.55, false);
        else if (!charging) stopChargeSound();
    }
    function stopChargeSound() { if (chargeSoundId >= 0) { Sounds.stopSfx(chargeSoundId); chargeSoundId = -1; } }
    // the page is kept alive while the radio is being switched (BlankPanel's network loader)
    onPowerAnimStateChanged: PanelLayout.networkPowerBusy = powerAnimState === "turningOn" || powerAnimState === "turningOff"
    Component.onDestruction: { stopChargeSound(); PanelLayout.networkPowerBusy = false; }

    // ---------- a network spat out of the core (after the burst, or reconnecting later) ----------
    // the same slingshot as a new connection's release from the core (releaseAnim)
    property real spitProg: 1.0
    NumberAnimation {
        id: spitAnim
        target: view; property: "spitProg"
        from: 0.0; to: 1.0
        duration: 740
        easing.type: Easing.OutBack
        easing.overshoot: 0.50
        onFinished: {
            for (let i = 0; i < view._nodes.length; i++) {
                const n = view._nodes[i];
                if (!n.spitting) continue;
                n.spitting = false;
                n.lx = n.homeX;
                n.ly = n.homeY;
            }
        }
    }
    function spitOut() {
        if (!view._nodes.some(n => n.spitting)) return;
        if (view.winVisible) view.store.playProfileSfx("impact");
        spitAnim.restart();
    }
    SequentialAnimation {
        id: powerBurstSeq

        // DETONATION: Thunderclap lightning crack + supernova flash + cloud sheet-lightning!
        ScriptAction {
            script: {
                if (view.winVisible) view.playLocalSfx("bh_power_on_burst.wav", 0.95);
                view.chargeLevel = 0.0;
                view.spitOut();
                view.burstFlashVisible = true;
                view.burstFlashProg = 0.0;
                view.bhShockVisible = true;
                view.bhShockProg = 0.0;
                bhShockAnim.restart();
                if (view.stormGasMode) {
                    view.spawnLightningAt(0.0, 0.0, true);
                    view.spawnLightningAt(440.0, -260.0, false);
                    view.spawnLightningAt(-420.0, 290.0, false);
                    view.spawnLightningAt(190.0, 450.0, false);
                }
            }
        }

        // Stage 2: Snappy OutExpo Big-Bang explosion scattering galaxy & all Wi-Fi nodes outward! (350..810ms)
        ParallelAnimation {
            NumberAnimation {
                target: view; property: "bhPowerScale"
                to: 1.0
                duration: 340
                easing.type: Easing.OutBack
                easing.overshoot: 1.35
            }
            NumberAnimation { target: view; property: "bhPowerPulse"; to: 0.0; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: view; property: "bhSpinBoost"; to: 1.0; duration: 420; easing.type: Easing.OutExpo }
            NumberAnimation { target: view; property: "galaxySuckScale"; from: 0.04; to: 1.0; duration: 440; easing.type: Easing.OutExpo }
            NumberAnimation { target: view; property: "galaxySuckOpacity"; from: 0.0; to: 1.0; duration: 130; easing.type: Easing.OutCubic }
            NumberAnimation { target: view; property: "nodeRadialMult"; from: 0.0; to: 1.0; duration: 460; easing.type: Easing.OutExpo }
            NumberAnimation { target: view; property: "nodePowerOpacity"; from: 0.0; to: 1.0; duration: 110; easing.type: Easing.OutCubic }
            NumberAnimation { target: view; property: "burstFlashProg"; from: 0.0; to: 1.0; duration: 430; easing.type: Easing.OutCubic }
            SequentialAnimation {
                PauseAnimation { duration: 130 }
                NumberAnimation { target: view; property: "openTetherProg"; from: 0.0; to: 1.0; duration: 310; easing.type: Easing.OutCubic }
            }
        }

        onFinished: {
            view.burstFlashVisible = false;
            view.powerAnimState = "on";
            // a network that connected during the burst itself is spat out now
            if (!spitAnim.running && view._nodes.some(n => n.spitting)) { view.spitProg = 0.0; view.spitOut(); }
        }
    }

    // ------------------------------------------------------------------
    // 60FPS Zero-Leak Simulation & GPU Scene Dispatcher
    //   * ZERO PathSvg string rebuilds per frame!
    //   * ZERO `.itemAt()` C++ bridge lookups (uses cached JS arrays)!
    //   * Pauses completely when powered OFF, hidden, or during Fullscreen entrance wave!
    // ------------------------------------------------------------------
    FrameAnimation {
        running: view.active && view.winVisible && view.visible && view.entranceReady && view.powerAnimState !== "off"
        onTriggered: {
            if (view._starItems.length === 0) view.cachePoolItems();
            const dt = Math.min(0.05, Math.max(0.001, frameTime));
            view._simClock += dt;
            view.bhTime += dt * view.bhSpinBoost;

            // Always keep galaxy rotating smoothly clockwise (and accelerate into whirlpool on Power OFF!)
            view.galaxyAngle = (view.galaxyAngle + dt * (2.4 + view.galaxySpinBoost)) % 360.0;

            // Keep full normal brightness & background effects running when inspecting a Wi-Fi (Mo 2A)
            view.isolateProg = 0.0;
            const iso = 0.0;
            const activeFocusId = view.drawerOpen ? view.drawerNodeId : (view.interactionLocked ? "" : view.hoveredId);
            const wRev = view.webReveal;
            const nRev = view.nodesReveal;

            // 1. Update local galaxy coords (lx, ly) + black hole pull/eject/release + 2D repulsion
            const removeQueue = [];
            for (let i = 0; i < view._nodes.length; i++) {
                const n = view._nodes[i];
                if (n.removing) {
                    n.appear = Math.max(0.0, n.appear - dt / 0.28);
                    if (n.appear <= 0.001) {
                        removeQueue.push(n.uid);
                        continue;
                    }
                } else if (n.appear < 1.0) {
                    n.appear = Math.min(1.0, n.appear + dt / 0.36);
                }

                if (!n.removing) {
                    if (n.spitting) {
                        // spat out of the core onto its connected place (waits at the core while charging)
                        const p = Math.max(0.0, view.spitProg);
                        n.lx = n.homeX * p;
                        n.ly = n.homeY * p;
                    } else if (view.phase === "suckToCore" && n.pullingIn) {
                        // Straight radial gravitational pull directly into Gargantua core (0, 0)
                        const p = view.suckProg;
                        n.lx = n.pullStartX * (1.0 - p);
                        n.ly = n.pullStartY * (1.0 - p);
                    } else if (view.phase === "coreCharge" && n.pullingIn) {
                        n.lx = 0.0;
                        n.ly = 0.0;
                    } else if (view.phase === "releaseToOrbit" && n.pullingIn) {
                        // Straight radial slingshot out in the random target direction onto r = 255 orbit
                        const p = Math.max(0.0, view.releaseProg);
                        n.lx = n.homeX * p;
                        n.ly = n.homeY * p;
                    } else if (n.ejectingOut) {
                        // Old connected Wi-Fi smoothly flings outward the moment new Wi-Fi hits the core!
                        const p = view.ejectProg;
                        n.lx = n.ejectStartX + (n.homeX - n.ejectStartX) * p;
                        n.ly = n.ejectStartY + (n.homeY - n.ejectStartY) * p;
                    } else if (view.phase === "pullToOrbit" && (n.pullingIn || n.releasingOut)) {
                        const p = view.pullProg;
                        n.lx = n.pullStartX + (n.homeX - n.pullStartX) * p;
                        n.ly = n.pullStartY + (n.homeY - n.pullStartY) * p;
                    } else {
                        // Continuous smooth clockwise orbit around Gargantua's rim (also while dragging or drawer open!)
                        if (view.blackHoleCenterMode && n.connected && !n.pullingIn && !n.ejectingOut) {
                            const orbR = Math.max(view.innerOrbitRadius - 6.0, Math.hypot(n.homeX, n.homeY));
                            const orbA = Math.atan2(n.homeY, n.homeX) + dt * 0.16;
                            n.homeX = Math.cos(orbA) * orbR;
                            n.homeY = Math.sin(orbA) * orbR;
                        }
                        const fx = Math.sin(view._simClock * 0.85 + n.phaseOffset) * 5.0;
                        const fy = Math.cos(view._simClock * 0.72 + n.phaseOffset * 1.3) * 4.5;
                        const ak = RadarMath.smoothK(dt, n.connected ? 0.16 : 0.32);
                        n.lx += ((n.homeX + fx) - n.lx) * ak;
                        n.ly += ((n.homeY + fy) - n.ly) * ak;
                    }
                }
            }

            for (let r = 0; r < removeQueue.length; r++) {
                const rUid = removeQueue[r];
                const ni = view.findNodeIdx(rUid);
                if (ni >= 0) view._nodes.splice(ni, 1);
                const mi = view.findModelIdx(rUid);
                if (mi >= 0) nodeModel.remove(mi);
            }

            // 2D non-overlapping label repulsion (skips nodes currently in black-hole transit!)
            for (let pass = 0; pass < 2; pass++) {
                for (let i = 0; i < view._nodes.length; i++) {
                    const a = view._nodes[i];
                    const aInBhTransit = a.spitting || (a.pullingIn && (view.phase === "pullToOrbit" || view.phase === "suckToCore" || view.phase === "coreCharge" || view.phase === "releaseToOrbit"));
                    if (a.removing || aInBhTransit || a.ejectingOut) continue;
                    for (let j = i + 1; j < view._nodes.length; j++) {
                        const b = view._nodes[j];
                        const bInBhTransit = b.spitting || (b.pullingIn && (view.phase === "pullToOrbit" || view.phase === "suckToCore" || view.phase === "coreCharge" || view.phase === "releaseToOrbit"));
                        if (b.removing || bInBhTransit || b.ejectingOut) continue;
                        const dx = b.lx - a.lx;
                        const dy = b.ly - a.ly;
                        const ex = dx / 185.0;
                        const ey = dy / 96.0;
                        const ell = Math.hypot(ex, ey);
                        if (ell < 1.0 && ell > 0.0001) {
                            const push = (1.0 - ell) * 32.0;
                            const ux = ex / ell;
                            const uy = ey / ell;
                            a.lx -= ux * push * 0.5;
                            a.ly -= uy * push * 0.35;
                            b.lx += ux * push * 0.5;
                            b.ly += uy * push * 0.35;
                        }
                    }
                    const dHub = Math.hypot(a.lx, a.ly);
                    if (!a.connected && !a.releasingOut && !a.ejectingOut && !aInBhTransit && dHub < view.minOuterRadius) {
                        const ang = dHub > 1.0 ? Math.atan2(a.ly, a.lx) : (a.phaseOffset || 0.7);
                        a.lx = Math.cos(ang) * view.minOuterRadius;
                        a.ly = Math.sin(ang) * view.minOuterRadius;
                    } else if (a.connected && !aInBhTransit) {
                        const minInner = view.innerOrbitRadius - 18.0;
                        const maxInner = view.innerOrbitRadius + 46.0;
                        if (dHub < minInner || dHub > maxInner) {
                            const ang = dHub > 1.0 ? Math.atan2(a.ly, a.lx) : -0.4;
                            const clamped = RadarMath.clamp(dHub, minInner, maxInner);
                            a.lx = Math.cos(ang) * clamped;
                            a.ly = Math.sin(ang) * clamped;
                        }
                    }
                }
            }

            // Project rotated world coords (wx, wy) to nodeModel (applies radial Power OFF suction / Power ON Big-Bang scatter!)
            const rad = view.galaxyAngle * Math.PI / 180.0;
            const cosA = Math.cos(rad);
            const sinA = Math.sin(rad);
            const baseRMult = view.nodeRadialMult;
            const pwrOp = view.nodePowerOpacity;
            const isBurstingOut = (view.powerAnimState === "turningOn" && baseRMult < 0.999);
            for (let i = 0; i < view._nodes.length; i++) {
                const n = view._nodes[i];
                let rMult = n.spitting ? 1.0 : baseRMult;
                if (isBurstingOut && rMult > 0.0001) {
                    const spread = 0.84 + ((i * 37) % 11) * 0.036;
                    rMult = Math.min(1.0, Math.pow(rMult, 1.0 / spread));
                }
                n.wx = (n.lx * cosA - n.ly * sinA) * rMult;
                n.wy = (n.lx * sinA + n.ly * cosA) * rMult;
                const mi = view.findModelIdx(n.uid);
                if (mi >= 0) {
                    nodeModel.setProperty(mi, "nx", n.wx);
                    nodeModel.setProperty(mi, "ny", n.wy);
                    const isFocused = (n.uid === view.drawerNodeId || n.uid === view.actionTargetId);
                    const isoMult = (iso > 0.01 && !isFocused) ? (1.0 - iso * 0.84) : 1.0;
                    let s = n.removing
                        ? (0.65 + 0.35 * (1.0 - RadarMath.easeInCubic(1.0 - n.appear)))
                        : (0.45 + 0.55 * RadarMath.easeOutBack(n.appear));
                    let op = (n.removing ? (1.0 - RadarMath.easeInCubic(1.0 - n.appear)) : Math.min(1.0, n.appear * 1.35)) * isoMult * nRev;
                    if (view.powerAnimState !== "on") {
                        s *= (0.16 + 0.84 * rMult);
                        op *= pwrOp;
                    }
                    if (n.pullingIn && view.phase === "suckToCore") {
                        s *= (1.0 - 0.82 * view.suckProg);
                        op *= (1.0 - RadarMath.clamp((view.suckProg - 0.65) / 0.35, 0.0, 1.0));
                    } else if (n.pullingIn && view.phase === "coreCharge") {
                        s = 0.15;
                        op = 0.0;
                    } else if (n.pullingIn && view.phase === "releaseToOrbit") {
                        const rp = RadarMath.clamp(view.releaseProg, 0.0, 1.0);
                        s *= (0.22 + 0.78 * rp);
                        op *= RadarMath.clamp(rp * 2.2, 0.0, 1.0);
                    } else if (n.spitting) {
                        const rp = RadarMath.clamp(view.spitProg, 0.0, 1.0);
                        s *= (0.22 + 0.78 * rp);
                        op *= RadarMath.clamp(rp * 2.2, 0.0, 1.0);
                    }
                    nodeModel.setProperty(mi, "nScale", s);
                    nodeModel.setProperty(mi, "nOpacity", op);
                }
            }

            // 2. Update Pooled GPU Rectangle Beams (Connected, Hover & Active -> ZERO CurveRenderer tessellation!)
            const reveal = RadarMath.clamp(view.openTetherProg, 0.0, 1.0);
            let connBeamIdx = 0;
            const beamThick = Math.max(1.4, 2.0 / Math.max(0.50, Math.sqrt(view.camZ)));
            if (reveal > 0.01 && nRev > 0.02 && pwrOp > 0.02) {
                for (let i = 0; i < view._nodes.length && connBeamIdx < view.connBeamPoolCount; i++) {
                    const cn = view._nodes[i];
                    if (!cn.connected || cn.removing || cn.appear < 0.05) continue;
                    const inPull = (view.phase === "pullToOrbit" || view.phase === "suckToCore" || view.phase === "coreCharge" || view.phase === "releaseToOrbit")
                        && view.actionTargetId === cn.uid;
                    if (inPull) continue;
                    const len = Math.max(1.0, Math.hypot(cn.wx, cn.wy));
                    const startR = Math.min(len * 0.35, 24.0);
                    const x0 = (cn.wx / len) * startR;
                    const y0 = (cn.wy / len) * startR;
                    const x1 = x0 + (cn.wx - x0) * reveal;
                    const y1 = y0 + (cn.wy - y0) * reveal;
                    view.placeBeamItem(view._connBeamItems[connBeamIdx], x0, y0, x1, y1, beamThick, false, (1.0 - iso * 0.42) * nRev * pwrOp);
                    connBeamIdx++;
                }
            }
            for (let b = connBeamIdx; b < view._connBeamItems.length; b++) {
                if (view._connBeamItems[b] && view._connBeamItems[b].visible) {
                    view._connBeamItems[b].visible = false;
                }
            }

            // Hover beam (ONLY when unlocked & hovering an unconnected node!)
            if (!view.interactionLocked && view.hoveredId !== "" && view.hoveredId !== view.actionTargetId) {
                const hIdx = view.findNodeIdx(view.hoveredId);
                if (hIdx >= 0 && !view._nodes[hIdx].connected) {
                    const hn = view._nodes[hIdx];
                    const len = Math.max(1.0, Math.hypot(hn.wx, hn.wy));
                    const startR = Math.min(len * 0.35, 24.0);
                    view.placeBeamItem(hoverBeamItem, (hn.wx / len) * startR, (hn.wy / len) * startR, hn.wx, hn.wy, beamThick * 0.72, false, 0.56);
                } else if (hoverBeamItem.visible) {
                    hoverBeamItem.visible = false;
                }
            } else if (hoverBeamItem.visible) {
                hoverBeamItem.visible = false;
            }

            // Active beam (slither / holdingBeam / holdingConnect / retractError / suckToCore / releaseToOrbit)
            let tipX = 0.0;
            let tipY = 0.0;
            let showActiveTip = false;
            let isErr = false;
            if (view.phase !== "idle" && view.phase !== "panToHost" && view.phase !== "dwellAtHost" && view.phase !== "coreCharge" && view.actionTargetId !== "") {
                const aIdx = view.findNodeIdx(view.actionTargetId);
                if (aIdx >= 0) {
                    const an = view._nodes[aIdx];
                    isErr = (view.failedRedId !== "" && view.failedRedId === view.actionTargetId);
                    let frac = 1.0;
                    if (view.phase === "slither") frac = view.slitherProg;
                    else if (view.phase === "retractError") frac = view.retractProg;
                    const len = Math.max(1.0, Math.hypot(an.wx, an.wy));
                    const startR = Math.min(len * 0.35, 24.0);
                    const x0 = (an.wx / len) * startR;
                    const y0 = (an.wy / len) * startR;
                    const fClamped = RadarMath.clamp(frac, 0.0, 1.0);
                    tipX = x0 + (an.wx - x0) * fClamped;
                    tipY = y0 + (an.wy - y0) * fClamped;
                    if (fClamped > 0.02 && len > 28.0) {
                        view.placeBeamItem(activeBeamItem, x0, y0, tipX, tipY, beamThick * 1.18, isErr, 0.96);
                        showActiveTip = true;
                    } else {
                        activeBeamItem.visible = false;
                    }
                } else {
                    activeBeamItem.visible = false;
                }
            } else if (activeBeamItem.visible) {
                activeBeamItem.visible = false;
            }
            activeBeamTip.visible = showActiveTip;
            if (showActiveTip) {
                activeBeamTip.x = tipX - activeBeamTip.width * 0.5;
                activeBeamTip.y = tipY - activeBeamTip.height * 0.5;
                activeBeamTip.color = isErr ? ThemeBackend.red : "#fffdf8";
            }

            // 3. Exact [1/2] Single-Stage Camera Controller
            if (view.phase === "panToHost") {
                const pk = RadarMath.smoothK(dt, 0.085);
                view.camX += (0.0 - view.camX) * pk;
                view.camY += (0.0 - view.camY) * pk;
                view.camZ += (view.targetCamZ - view.camZ) * pk;
                if (Math.hypot(view.camX, view.camY) < 2.5 && Math.abs(view.camZ - view.targetCamZ) < 0.015) {
                    view.camX = 0.0;
                    view.camY = 0.0;
                    view.camZ = view.targetCamZ;
                    view.phase = "dwellAtHost";
                    hostDwellTimer.restart();
                }
            } else if (view.phase === "dwellAtHost") {
                view.camX = 0.0;
                view.camY = 0.0;
                view.camZ = view.targetCamZ;
            } else if (view.phase === "slither" || view.phase === "retractError") {
                const fk = RadarMath.smoothK(dt, 0.032);
                view.camX += (tipX - view.camX) * fk;
                view.camY += (tipY - view.camY) * fk;
                view.camZ += (view.targetCamZ - view.camZ) * fk;
                view.targetCamX = view.camX;
                view.targetCamY = view.camY;
            } else if (view.phase === "pullToOrbit" || view.phase === "suckToCore" || view.phase === "coreCharge" || view.phase === "releaseToOrbit") {
                const pk = RadarMath.smoothK(dt, 0.095);
                view.camX += (0.0 - view.camX) * pk;
                view.camY += (0.0 - view.camY) * pk;
                view.camZ += (view.targetCamZ - view.camZ) * pk;
            } else if (!panArea.dragging) {
                // Gently track the inspected Wi-Fi node as the galaxy keeps spinning smoothly!
                if (view.drawerOpen && view.drawerNodeId !== "" && (view.phase === "idle" || view.phase === "holdingBeam" || view.phase === "holdingConnect")) {
                    const dIdx = view.findNodeIdx(view.drawerNodeId);
                    if (dIdx >= 0) {
                        view.targetCamX = view.desiredLeftDrawerFocusX(view._nodes[dIdx].wx);
                        view.targetCamY = view._nodes[dIdx].wy;
                    }
                }
                const ck = RadarMath.smoothK(dt, 0.10);
                view.camX += (view.targetCamX - view.camX) * ck;
                view.camY += (view.targetCamY - view.camY) * ck;
                view.camZ += (view.targetCamZ - view.camZ) * ck;
            } else {
                const zk = RadarMath.smoothK(dt, 0.09);
                view.camZ += (view.targetCamZ - view.camZ) * zk;
            }

            // 4. Animate double-flicker cloudy sheet-lightning flashes (using cached _lightningItems!)
            let anyFlashActive = false;
            if (view.stormGasMode) {
                for (let l = 0; l < view._lightnings.length; l++) {
                    const lt = view._lightnings[l];
                    const flashItem = view._lightningItems[l];
                    if (!lt.active) {
                        lt.flicker = 0.0;
                        if (flashItem && flashItem.visible) flashItem.visible = false;
                        continue;
                    }
                    lt.life += dt;
                    if (lt.life >= lt.maxLife) {
                        lt.active = false;
                        lt.flicker = 0.0;
                        if (flashItem) flashItem.visible = false;
                        continue;
                    }
                    const u = lt.life / lt.maxLife;
                    const peak1 = 0.90 * Math.exp(-Math.pow((u - 0.13) / 0.10, 2.0));
                    const peak2 = 0.68 * Math.exp(-Math.pow((u - 0.45) / 0.16, 2.0));
                    const afterglow = 0.24 * Math.pow(1.0 - u, 2.2);
                    const flicker = RadarMath.clamp(peak1 + peak2 + afterglow, 0.0, 1.0);
                    lt.flicker = flicker;
                    if (flicker > 0.05) anyFlashActive = true;

                    if (flashItem) {
                        const radSz = lt.radius * (0.86 + 0.26 * u);
                        flashItem.x = lt.x - radSz * 0.5;
                        flashItem.y = lt.y - radSz * 0.5;
                        flashItem.width = radSz;
                        flashItem.height = radSz;
                        flashItem.rotation = lt.angle || 0.0;
                        flashItem.isBig = lt.big;
                        flashItem.opacity = flicker * (lt.big ? 0.88 : 0.62) * wRev;
                        flashItem.visible = flashItem.opacity > 0.02;
                    }
                }
            }

            // 5. Twinkle 420 constellation stars + illuminate stars inside active sheet-lightning (cached _starItems!)
            const stars = view._stars;
            const starLen = Math.min(stars.length, view._starItems.length);
            for (let i = 1; i < starLen; i++) {
                const dot = view._starItems[i];
                if (!dot) continue;
                const s = stars[i];
                const inCluster = (activeFocusId !== "" && s.clusterId === activeFocusId);
                let isoMult = 1.0;
                if (iso > 0.01) isoMult = inCluster ? (1.0 + iso * 0.45) : (1.0 - iso * 0.88);
                else if (inCluster) isoMult = 1.32;
                const tw = 0.76 + 0.24 * Math.sin(view._simClock * s.twSpeed + s.twPhase);
                let flashBoost = 0.0;
                if (anyFlashActive) {
                    for (let l = 0; l < view._lightnings.length; l++) {
                        const lt = view._lightnings[l];
                        if (!lt.active || lt.flicker < 0.05) continue;
                        const dx = s.x - lt.x;
                        const dy = s.y - lt.y;
                        const reach = lt.radius * 0.68;
                        const d2 = dx * dx + dy * dy;
                        if (d2 < reach * reach) {
                            flashBoost += (1.0 - Math.sqrt(d2) / reach) * lt.flicker * 0.65;
                        }
                    }
                }
                view.setDotAlpha(dot, 1, 1, 1, (s.alpha * tw * isoMult + flashBoost) * wRev);
            }

            // 6. Animate 96 moving light-packets + 48 streaks + 36 arrival flashes (cached arrays!)
            if (view.stormGasMode) {
                view._lightningCooldown = Math.max(0.0, view._lightningCooldown - dt);
            }
            const edges = view._edges;
            const eLen = edges.length;
            if (eLen > 0) {
                for (let p = 0; p < view._packets.length; p++) {
                    const pk = view._packets[p];
                    pk.t += pk.speed * dt * pk.dir;
                    if (pk.t > 1.0 || pk.t < 0.0) {
                        const finishedEdge = edges[pk.edgeIdx];
                        if (finishedEdge && iso < 0.5 && nRev > 0.4) {
                            const ax = pk.t > 1.0 ? finishedEdge.bx : finishedEdge.ax;
                            const ay = pk.t > 1.0 ? finishedEdge.by : finishedEdge.ay;
                            view.triggerArrivalFlash(ax, ay, pk.isGold);
                            if (view.stormGasMode && view._lightningCooldown <= 0.0 && Math.hypot(ax, ay) > 160.0) {
                                view.spawnLightningAt(ax, ay, false);
                                view._lightningCooldown = 0.36 + Math.random() * 0.46;
                            }
                        }
                        pk.edgeIdx = (pk.edgeIdx + 23 + (p * 7)) % eLen;
                        pk.dir = (pk.t > 1.0) ? ((p % 3 === 0) ? -1 : 1) : 1;
                        pk.t = pk.dir > 0 ? 0.0 : 1.0;
                    }

                    const ed = edges[pk.edgeIdx];
                    const item = view._packetItems[p];
                    if (item && ed) {
                        const u = RadarMath.clamp(pk.t, 0.0, 1.0);
                        const px = ed.ax + (ed.bx - ed.ax) * u;
                        const py = ed.ay + (ed.by - ed.ay) * u;
                        const env = Math.sin(u * Math.PI);
                        const inCluster = (activeFocusId !== "" && ed.clusterId === activeFocusId);
                        const isoFade = iso > 0.01 ? (inCluster ? 1.15 : (1.0 - iso * 0.90)) : 1.0;
                        item.x = px - pk.size * 0.5;
                        item.y = py - pk.size * 0.5;
                        item.width = pk.size;
                        item.height = pk.size;
                        item.isGold = pk.isGold;
                        const pa = RadarMath.clamp(env * 0.95 * isoFade * nRev, 0.0, 1.0);
                        const pc = pk.isGold ? view.goldBright : view._white;
                        view.setDotAlpha(item, pc.r, pc.g, pc.b, pa, pk.isGold ? 1 : 0);
                        item.visible = pa > 0.03;
                    }
                }

                for (let s = 0; s < view._streaks.length; s++) {
                    const st = view._streaks[s];
                    st.t += st.speed * dt * st.dir;
                    if (st.t > 1.28 || st.t < -0.28) {
                        st.edgeIdx = (st.edgeIdx + 29 + (s * 5)) % eLen;
                        st.dir = (s % 2 === 0) ? 1 : -1;
                        st.t = st.dir > 0 ? 0.0 : 1.0;
                    }
                    const ed = edges[st.edgeIdx];
                    const item = view._streakItems[s];
                    if (item && ed) {
                        const headU = RadarMath.clamp(st.t, 0.0, 1.0);
                        const tailU = RadarMath.clamp(st.t - st.dir * 0.34, 0.0, 1.0);
                        const u0 = Math.min(headU, tailU);
                        const u1 = Math.max(headU, tailU);
                        const span = u1 - u0;
                        if (span <= 0.02 || nRev < 0.03) {
                            if (item.visible) item.visible = false;
                        } else {
                            const sx = ed.ax + (ed.bx - ed.ax) * u0;
                            const sy = ed.ay + (ed.by - ed.ay) * u0;
                            const inCluster = (activeFocusId !== "" && ed.clusterId === activeFocusId);
                            const isoFade = iso > 0.01 ? (inCluster ? 1.1 : (1.0 - iso * 0.90)) : 1.0;
                            item.x = sx;
                            item.y = sy - item.height * 0.5;
                            item.width = Math.max(4.0, ed.len * span);
                            item.rotation = ed.angDeg;
                            item.isGold = st.isGold;
                            item.reverseGrad = (st.dir < 0);
                            item.opacity = RadarMath.clamp(0.68 * isoFade * nRev, 0.0, 0.85);
                            if (!item.visible) item.visible = true;
                        }
                    }
                }
            }

            // 7. Animate 36 arrival star-flashes (cached _flashItems!)
            for (let f = 0; f < view._flashes.length; f++) {
                const fl = view._flashes[f];
                const item = view._flashItems[f];
                if (!item) continue;
                if (!fl.active) {
                    if (item.visible) item.visible = false;
                    continue;
                }
                fl.life += dt;
                if (fl.life >= fl.maxLife) {
                    fl.active = false;
                    item.visible = false;
                    continue;
                }
                const prog = fl.life / fl.maxLife;
                const glow = Math.sin(prog * Math.PI);
                const sz = 6.0 + prog * 14.0;
                item.x = fl.x - sz * 0.5;
                item.y = fl.y - sz * 0.5;
                item.width = sz;
                item.height = sz;
                item.isGold = fl.isGold;
                const fa = Math.max(0.0, Math.min(1.0, glow * 0.58 * nRev * (1.0 - iso * 0.85)));
                if (fl.isGold) view.setDotAlpha(item, 1.0, 0.90, 0.68, 0.55 * fa, 2);
                else view.setDotAlpha(item, 1.0, 1.0, 1.0, 0.48 * fa, 3);
                item.visible = fa > 0.02;
            }

            // 8. Spin 5 static-baked outer orbital comet arcs via pure GPU rotation (ZERO PathSvg rebuild!)
            for (let c = 0; c < view.cometSpecs.length; c++) {
                view._cometAngles[c] = (view._cometAngles[c] + view.cometSpecs[c].speedDeg * dt) % 360.0;
                const cItem = view._cometItems[c];
                if (cItem) {
                    cItem.arcSpin = view._cometAngles[c];
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Layer 0: Deep-Space Pinpoint Starfield Wallpaper (Seamless `inf` 3-tap!)
    // ------------------------------------------------------------------
    Item {
        id: spaceWallpaper
        anchors.fill: parent
        clip: true
        z: 0

        function rebakeTiles() {
            farStarSource.scheduleUpdate();
            nearStarSource.scheduleUpdate();
            smokeTex.scheduleUpdate();
        }
        Component.onCompleted: Qt.callLater(rebakeTiles)

        Connections {
            target: view
            function onIsFullscreenChanged() { Qt.callLater(spaceWallpaper.rebakeTiles); }
            function onActiveChanged() { if (view.active) Qt.callLater(spaceWallpaper.rebakeTiles); }
            function onEntranceReadyChanged() { if (view.entranceReady) Qt.callLater(spaceWallpaper.rebakeTiles); }
        }

        Rectangle {
            anchors.fill: parent
            color: "#020204"
        }

        ShaderEffect {
            id: farStarBake
            width: 512; height: 512
            property real layerMode: 0.0
            property color accentColor: view.goldAccent
            fragmentShader: Qt.resolvedUrl("shaders/star_tile_bake.frag.qsb")
        }
        ShaderEffect {
            id: nearStarBake
            width: 768; height: 768
            property real layerMode: 1.0
            property color accentColor: view.goldAccent
            fragmentShader: Qt.resolvedUrl("shaders/star_tile_bake.frag.qsb")
        }
        ShaderEffect {
            id: smokeBake
            width: 960; height: 540
            property vector2d res: Qt.vector2d(width, height)
            fragmentShader: Qt.resolvedUrl("shaders/dark_cosmos_smoke.frag.qsb")
        }

        ShaderEffectSource {
            id: farStarSource
            sourceItem: farStarBake
            textureSize: Qt.size(512, 512)
            hideSource: true
            live: false
            smooth: true
            visible: false
        }
        ShaderEffectSource {
            id: nearStarSource
            sourceItem: nearStarBake
            textureSize: Qt.size(768, 768)
            hideSource: true
            live: false
            smooth: true
            visible: false
        }

        ShaderEffect {
            anchors.fill: parent
            z: 0
            opacity: view.bhReveal
            visible: view.bhReveal > 0.01
            property real zoom: view.camZ
            property vector2d res: Qt.vector2d(width, height)
            property vector2d camPos: Qt.vector2d(view.camX / 960.0, view.camY / 960.0)
            property vector2d hoverOffset: Qt.vector2d(0.0, 0.0)
            property var farStarTex: farStarSource
            property var nearStarTex: farStarSource
            fragmentShader: Qt.resolvedUrl("shaders/nebula_stars.frag.qsb")
        }

        ShaderEffectSource {
            id: smokeTex
            anchors.fill: parent
            z: 0.5
            sourceItem: smokeBake
            textureSize: Qt.size(960, 540)
            hideSource: true
            live: false
            smooth: true
            opacity: 0.32 * view.bhReveal
            visible: view.bhReveal > 0.01
        }

        ShaderEffect {
            anchors.fill: parent
            z: 2
            opacity: view.bhReveal
            visible: view.bhReveal > 0.01
            property real zoom: view.camZ
            property vector2d res: Qt.vector2d(width, height)
            property vector2d camPos: Qt.vector2d(view.camX / 960.0, view.camY / 960.0)
            property var nearStarTex: nearStarSource
            fragmentShader: Qt.resolvedUrl("shaders/star_near_layer.frag.qsb")
        }
    }

    // ------------------------------------------------------------------
    // Layer 1: Infinite Unclamped 2D Drag-Pan & Wheel Zoom (LOCKED while waiting/connecting!)
    // ------------------------------------------------------------------
    MouseArea {
        id: panArea
        anchors.fill: parent
        z: 3
        acceptedButtons: Qt.LeftButton
        hoverEnabled: !view.interactionLocked
        enabled: view.active && view.entranceReady

        property bool dragging: false
        property real pressMouseX: 0
        property real pressMouseY: 0
        property real pressCamX: 0
        property real pressCamY: 0

        cursorShape: view.interactionLocked ? Qt.ArrowCursor : (dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)

        onPressed: (m) => {
            dragging = false;
            if (view.interactionLocked) return;
            pressMouseX = m.x;
            pressMouseY = m.y;
            pressCamX = view.camX;
            pressCamY = view.camY;
            view.forceActiveFocus();
        }

        onPositionChanged: (m) => {
            if (!pressed || view.interactionLocked) return;
            const dx = m.x - pressMouseX;
            const dy = m.y - pressMouseY;
            if (!dragging && Math.hypot(dx, dy) > 4.0) {
                dragging = true;
            }
            if (dragging) {
                const nx = pressCamX - dx / view.camZ;
                const ny = pressCamY - dy / view.camZ;
                view.camX = nx;
                view.camY = ny;
                view.targetCamX = nx;
                view.targetCamY = ny;
            }
        }

        onReleased: {
            // Only allow clicking empty canvas to cancel drawer when settled in holdingBeam or inspecting connected node
            if (!dragging && view.drawerOpen && (view.phase === "holdingBeam" || view.phase === "idle")) {
                view.cancelDrawerAndRetract();
            }
            dragging = false;
        }
        onCanceled: dragging = false
    }

    WheelHandler {
        enabled: view.active && view.entranceReady && !view.interactionLocked
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        property real wheelAcc: 0
        onWheel: (e) => {
            const pt = point.position;
            const d = Math.abs(e.angleDelta.y) >= Math.abs(e.angleDelta.x) ? e.angleDelta.y : e.angleDelta.x;
            if (d === 0) return;
            if (Math.abs(d) < 120) {
                view.zoomByAt(pt.x, pt.y, Math.exp(d * 0.0014));
            } else {
                wheelAcc += d;
                while (Math.abs(wheelAcc) >= 120) {
                    view.zoomByAt(pt.x, pt.y, wheelAcc > 0 ? 1.11 : (1.0 / 1.11));
                    wheelAcc -= wheelAcc > 0 ? 120 : -120;
                }
            }
            e.accepted = true;
        }
    }

    // ------------------------------------------------------------------
    // Layer 2: World-Transformed 2x Flat 2D Constellation, Gargantua, Storm Gas & Wi-Fi Nodes
    // ------------------------------------------------------------------
    Item {
        id: worldLayer
        anchors.fill: parent
        z: 5
        visible: view.bhReveal > 0.01
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

        // World-Locked Photorealistic Enlarged (~1.7x) Gargantua Black Hole at (0, 0) + Closer Golden Orbit (r = 255)!
        Item {
            id: worldGargantuaHost
            visible: view.showBlackHole && view.blackHoleCenterMode && view.bhReveal > 0.01 && (view.bhPowerScale > 0.004 || view.bhShockVisible || view.burstFlashVisible)
            x: 0; y: 0
            width: 1; height: 1
            z: 0.5

            // Power-on charge: the black hole feeds itself. Two thick streams of light, from the top left and the
            // bottom right, spiral in, drawn in from outside at first, and melt into the glow round its rim; thicker
            // and brighter the longer the charge lasts. Drawn on the GPU (bh_charge_streams.frag), only while
            // charging and shown.
            ShaderEffect {
                id: chargeFx
                width: 1400; height: 1400
                x: -width * 0.5; y: -height * 0.5
                z: 3
                visible: view.charging && view.winVisible && view.chargeLevel > 0.001
                property vector2d itemSize: Qt.vector2d(width, height)
                property real rimR: 150.0 * view.bhPowerScale
                property real farR: 150.0 * view.chargeTo * 4.2
                property real level: view.chargeLevel
                property real time: view.chargeTime
                property real head: Math.min(1.0, view.chargeTime / 1.6)
                fragmentShader: Qt.resolvedUrl("shaders/bh_charge_streams.frag.qsb")
            }

            // Legacy Gargantua Shader ([2/3] comparison baseline)
            ShaderEffect {
                visible: worldGargantuaHost.visible && !view.useUnifiedBlackHole && view.bhPowerScale > 0.004
                width: 500
                height: 500
                x: -width * 0.5
                y: -height * 0.5
                scale: (860.0 / 500.0) * (0.55 + 0.45 * view.bhReveal) * (1.0 + view.bhFlareProg * 0.09) * view.bhPowerScale
                opacity: 0.90 * view.bhReveal * RadarMath.clamp(view.bhPowerScale * 2.4, 0.0, 1.0)
                smooth: true
                property real time: view.bhTime
                property real pulse: view.bhFlareProg * 1.65 + view.bhPowerPulse + (view.phase === "suckToCore" ? view.suckProg * 0.9 : 0.0)
                property real vortex: view.bhPowerVortex
                fragmentShader: Qt.resolvedUrl("shaders/gargantua_blackhole.frag.qsb")
            }

            // NEW Unified Gravitational-Lensing Shader ([3/3] Reference: back hole.png — Champagne/Copper + 6° Tilt/0° Flat!)
            ShaderEffect {
                visible: worldGargantuaHost.visible && view.useUnifiedBlackHole && view.bhPowerScale > 0.004
                width: 600
                height: 420
                x: -width * 0.5
                y: -height * 0.5
                scale: (1060.0 / 600.0) * (0.55 + 0.45 * view.bhReveal) * (1.0 + view.bhFlareProg * 0.09) * view.bhPowerScale
                opacity: 0.96 * view.bhReveal * RadarMath.clamp(view.bhPowerScale * 2.4, 0.0, 1.0)
                smooth: true
                property real time: view.bhTime
                property real pulse: view.bhFlareProg * 1.65 + view.bhPowerPulse + (view.phase === "suckToCore" ? view.suckProg * 0.9 : 0.0)
                property real vortex: view.bhPowerVortex
                property real colorMode: view.bhColorMode
                property real tiltRad: view.bhTiltRad
                fragmentShader: Qt.resolvedUrl("shaders/gargantua_unified.frag.qsb")
            }

            // Static-baked close golden orbit track ring (r = 255, constant strokeWidth -> zero re-tessellation!)
            Shape {
                visible: worldGargantuaHost.visible && view.webReveal > 0.01 && view.galaxySuckOpacity > 0.01
                x: -view.svgOrigin; y: -view.svgOrigin
                width: view.svgOrigin * 2; height: view.svgOrigin * 2
                scale: view.galaxySuckScale
                opacity: view.webReveal * view.galaxySuckOpacity * (1.0 - view.isolateProg * 0.65)
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: 1.45
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [5, 7]
                    strokeColor: Qt.rgba(1.0, 0.90, 0.68, 0.24 + view.bhFlareProg * 0.26)
                    fillColor: "transparent"
                    PathSvg { path: view.bhOrbitRingSvg }
                }
            }

            // Golden accretion shockwave ring expanding outward when a Wi-Fi node enters Gargantua's core!
            Rectangle {
                visible: view.bhShockVisible
                x: -width * 0.5; y: -height * 0.5
                width: (88 + view.bhShockProg * 330) * 2
                height: width; radius: width * 0.5
                color: "transparent"
                border.width: Math.max(1.2, 4.2 - view.bhShockProg * 2.4)
                border.color: Qt.rgba(1.0, 0.92, 0.72, (1.0 - view.bhShockProg) * 0.80)
            }

            // Supernova Big-Bang Detonation Core Flash + Expanding Thunderclap Shockwaves (Power ON!)
            Rectangle {
                visible: view.burstFlashVisible
                x: -width * 0.5; y: -height * 0.5
                width: 180 + view.burstFlashProg * 1350
                height: width; radius: width * 0.5
                opacity: Math.pow(1.0 - view.burstFlashProg, 2.2) * 0.92
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#ffffff" }
                    GradientStop { position: 0.28; color: Qt.rgba(1.0, 0.95, 0.80, 0.85) }
                    GradientStop { position: 0.62; color: Qt.rgba(0.96, 0.74, 0.36, 0.28) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            Rectangle {
                visible: view.burstFlashVisible
                x: -width * 0.5; y: -height * 0.5
                width: (110 + view.burstFlashProg * 880) * 2
                height: width; radius: width * 0.5
                color: "transparent"
                border.width: Math.max(1.4, 7.5 * (1.0 - view.burstFlashProg))
                border.color: Qt.rgba(1.0, 0.96, 0.84, Math.pow(1.0 - view.burstFlashProg, 1.35) * 0.95)
            }
        }

        // Pure GPU Clockwise Rotating Galaxy Container (whirlpools into (0,0) on Power OFF & Big-Bangs out on Power ON!)
        Item {
            id: rotatingGalaxy
            x: 0; y: 0
            width: 1; height: 1
            z: 2
            rotation: view.galaxyAngle
            scale: (0.72 + 0.28 * view.webReveal) * view.galaxySuckScale
            opacity: view.galaxySuckOpacity
            visible: view.webReveal > 0.01 && view.galaxySuckOpacity > 0.01

            // Baked Volumetric Storm Gas & Smoke Clouds (Back/Mid layer + 160×160 Sheet-Lightning sprite baker)
            Loader {
                id: stormGasBackLoader
                active: view.stormGasMode
                visible: view.stormGasMode
                z: 1
                sourceComponent: Item {
                    id: gasBackRoot
                    readonly property alias sheetFlashSource: sheetFlashTex
                    function rebake() {
                        gasBackTex.scheduleUpdate();
                        sheetFlashTex.scheduleUpdate();
                    }
                    Component.onCompleted: Qt.callLater(rebake)
                    Connections {
                        target: view
                        function onIsFullscreenChanged() { Qt.callLater(gasBackRoot.rebake); }
                        function onActiveChanged() { if (view.active) Qt.callLater(gasBackRoot.rebake); }
                        function onEntranceReadyChanged() { if (view.entranceReady) Qt.callLater(gasBackRoot.rebake); }
                    }
                    ShaderEffect {
                        id: gasBackBake
                        width: 1024; height: 1024
                        property real layerMode: 0.0
                        property vector2d res: Qt.vector2d(width, height)
                        fragmentShader: Qt.resolvedUrl("shaders/storm_gas_cloud.frag.qsb")
                    }
                    ShaderEffect {
                        id: sheetFlashBake
                        width: 160; height: 160
                        fragmentShader: Qt.resolvedUrl("shaders/sheet_lightning_bake.frag.qsb")
                    }
                    ShaderEffectSource {
                        id: sheetFlashTex
                        sourceItem: sheetFlashBake
                        textureSize: Qt.size(160, 160)
                        hideSource: true
                        live: false
                        smooth: true
                        visible: false
                    }
                    ShaderEffectSource {
                        id: gasBackTex
                        sourceItem: gasBackBake
                        textureSize: Qt.size(1024, 1024)
                        hideSource: true
                        live: false
                        smooth: true
                        width: 2460; height: 2460
                        x: -width * 0.5; y: -height * 0.5
                        opacity: view.webReveal * (1.0 - view.isolateProg * 0.45)
                    }
                }
            }

            // DEDICATED Static Background Constellation Web (680 edges baked ONCE -> ZERO per-frame CurveRenderer rebuild!)
            Shape {
                id: bgConstellationShape
                x: -view.svgOrigin; y: -view.svgOrigin
                width: view.svgOrigin * 2; height: view.svgOrigin * 2
                z: 2
                opacity: (1.0 - view.isolateProg * 0.86) * view.webReveal
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 1.35
                    strokeColor: Qt.rgba(1.0, 1.0, 1.0, 0.14)
                    fillColor: "transparent"
                    PathSvg { path: view.bgConstellationSvg || "M0,0" }
                }
            }

            // DEDICATED Highlighted Cluster Web (updates ONLY on hover/select change!)
            Shape {
                visible: view.hlConstellationSvg !== ""
                x: -view.svgOrigin; y: -view.svgOrigin
                width: view.svgOrigin * 2; height: view.svgOrigin * 2
                z: 2.2
                opacity: view.webReveal
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: 1.75
                    strokeColor: Qt.rgba(1.0, 0.92, 0.76, view.drawerOpen ? 0.42 : 0.34)
                    fillColor: "transparent"
                    PathSvg { path: view.hlConstellationSvg || "M0,0" }
                }
            }

            // 5 Static-Baked Rotating Outer Comet Arcs (baked ONCE, spun by pure GPU rotation -> ZERO PathSvg rebuild!)
            Repeater {
                id: cometArcRepeater
                model: view.cometSpecs
                delegate: Item {
                    id: cometItem
                    required property var modelData
                    required property int index
                    property real arcSpin: modelData.startDeg
                    x: 0; y: 0
                    width: 1; height: 1
                    z: 2.5
                    rotation: modelData.tilt
                    opacity: (1.0 - view.isolateProg * 0.86) * view.webReveal

                    Item {
                        width: 1; height: 1
                        rotation: cometItem.arcSpin

                        Shape {
                            x: -view.svgOrigin; y: -view.svgOrigin
                            width: view.svgOrigin * 2; height: view.svgOrigin * 2
                            preferredRendererType: Shape.CurveRenderer
                            ShapePath {
                                strokeWidth: 1.55
                                capStyle: ShapePath.RoundCap
                                strokeColor: Qt.rgba(1.0, 1.0, 1.0, 0.26)
                                fillColor: "transparent"
                                PathSvg { path: view.buildCometArcSvg(cometItem.modelData.rx, cometItem.modelData.ry, cometItem.modelData.arcRad) }
                            }
                        }

                        // Glowing comet head pinned right at leading end of static arc (rx, 0)
                        Rectangle {
                            x: cometItem.modelData.rx - width * 0.5
                            y: -height * 0.5
                            width: 6.0; height: 6.0; radius: 3.0
                            color: "#ffffff"
                        }
                    }
                }
            }

            // Photographic Cloudy Sheet-Lightning Flashes behind front smoke wisps (`live: false` sprite!)
            Repeater {
                id: lightningFlashRepeater
                model: view.stormGasMode ? view.lightningPoolCount : 0
                delegate: ShaderEffect {
                    id: lFlashItem
                    property bool isBig: false
                    visible: false
                    smooth: true
                    z: 3.5

                    property var spriteTex: stormGasBackLoader.item ? stormGasBackLoader.item.sheetFlashSource : null
                    property color tintColor: lFlashItem.isBig
                        ? Qt.rgba(1.0, 0.96, 0.88, 0.72)
                        : Qt.rgba(0.95, 0.96, 1.0, 0.58)
                    fragmentShader: Qt.resolvedUrl("shaders/sprite_tint.frag.qsb")
                }
            }

            // 420 GPU-Batched 2D Constellation Stars
            Repeater {
                id: starPoolRepeater
                model: view.starPoolCount
                // brightness goes through the colour's alpha (view.setDotAlpha), not item opacity: dots of different
                // opacity each need a draw call of their own, dots of different colour merge into one (same look)
                delegate: Rectangle {
                    property int a8: -1
                    width: 2; height: 2; radius: width * 0.5
                    color: "transparent"
                    z: 4
                }
            }

            // Front Airy Smoke Wisps weaving subtly OVER constellation web & stars (`live: false`!)
            Loader {
                id: stormGasFrontLoader
                active: view.stormGasMode
                visible: view.stormGasMode
                z: 4.5
                sourceComponent: Item {
                    id: gasFrontRoot
                    function rebake() { gasFrontTex.scheduleUpdate(); }
                    Component.onCompleted: Qt.callLater(rebake)
                    Connections {
                        target: view
                        function onIsFullscreenChanged() { Qt.callLater(gasFrontRoot.rebake); }
                        function onActiveChanged() { if (view.active) Qt.callLater(gasFrontRoot.rebake); }
                        function onEntranceReadyChanged() { if (view.entranceReady) Qt.callLater(gasFrontRoot.rebake); }
                    }
                    ShaderEffect {
                        id: gasFrontBake
                        width: 960; height: 960
                        property real layerMode: 1.0
                        property vector2d res: Qt.vector2d(width, height)
                        fragmentShader: Qt.resolvedUrl("shaders/storm_gas_cloud.frag.qsb")
                    }
                    ShaderEffectSource {
                        id: gasFrontTex
                        sourceItem: gasFrontBake
                        textureSize: Qt.size(960, 960)
                        hideSource: true
                        live: false
                        smooth: true
                        width: 2460; height: 2460
                        x: -width * 0.5; y: -height * 0.5
                        opacity: view.webReveal * (1.0 - view.isolateProg * 0.55)
                    }
                }
            }

            // 48 Kinetic Light-Streaks zipping across the 2x web
            Repeater {
                id: streakPoolRepeater
                model: view.streakPoolCount
                delegate: Rectangle {
                    id: streakRect
                    property bool isGold: false
                    property bool reverseGrad: false
                    visible: false
                    height: 2.1
                    radius: height * 0.5
                    transformOrigin: Item.Left
                    z: 5
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: streakRect.reverseGrad
                                ? (streakRect.isGold ? Qt.rgba(1.0, 0.94, 0.78, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.82))
                                : "transparent"
                        }
                        GradientStop {
                            position: 0.50
                            color: streakRect.isGold ? Qt.rgba(0.95, 0.78, 0.48, 0.42) : Qt.rgba(0.90, 0.94, 1.0, 0.36)
                        }
                        GradientStop {
                            position: 1.0
                            color: streakRect.reverseGrad
                                ? "transparent"
                                : (streakRect.isGold ? Qt.rgba(1.0, 0.94, 0.78, 0.85) : Qt.rgba(1.0, 1.0, 1.0, 0.82))
                        }
                    }
                }
            }

            // 96 Lively Glowing Network Light-Packets zipping back & forth
            Repeater {
                id: packetPoolRepeater
                model: view.packetPoolCount
                delegate: Rectangle {
                    property bool isGold: false
                    property int a8: -1           // brightness through the colour's alpha (see the stars)
                    visible: false
                    width: 3.6; height: 3.6; radius: width * 0.5
                    color: "transparent"
                    z: 6
                }
            }

            // 36 Arrival Star-Flashes
            Repeater {
                id: flashPoolRepeater
                model: view.flashPoolCount
                delegate: Rectangle {
                    property bool isGold: false
                    property int a8: -1           // brightness through the colour's alpha (see the stars)
                    visible: false
                    width: 8; height: 8; radius: width * 0.5
                    color: "transparent"
                    z: 6
                }
            }
        }

        // ------------------------------------------------------------------
        // Pooled GPU Rectangle Beams (Connected, Hover & Active -> ZERO CurveRenderer per frame!)
        // ------------------------------------------------------------------
        component CosmicBeamItem: Item {
            id: beamRoot
            property real coreThickness: 2.2
            property bool isError: false
            visible: false
            height: coreThickness * 3.8
            transformOrigin: Item.Left

            // Wide soft outer bloom
            Rectangle {
                anchors.fill: parent
                radius: height * 0.5
                color: beamRoot.isError
                    ? Qt.alpha(ThemeBackend.red, 0.28)
                    : Qt.rgba(0.96, 0.79, 0.49, 0.24)
            }
            // Crisp incandescent inner laser core
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: beamRoot.coreThickness
                radius: height * 0.5
                color: beamRoot.isError ? ThemeBackend.red : Qt.rgba(1.0, 0.96, 0.88, 0.94)
            }
        }

        Repeater {
            id: connectedBeamRepeater
            model: view.connBeamPoolCount
            delegate: CosmicBeamItem { z: 8 }
        }

        CosmicBeamItem {
            id: hoverBeamItem
            z: 8
        }

        CosmicBeamItem {
            id: activeBeamItem
            z: 8.5
        }

        // Advancing Beam Tip Spark
        Rectangle {
            id: activeBeamTip
            visible: false
            width: 9.0
            height: width; radius: width * 0.5
            z: 9
            color: "#fffdf8"
        }

        // Impact Pulse Ring on target node strike
        Rectangle {
            visible: view.impactPulseVisible
            x: view.impactPulseX - width * 0.5
            y: view.impactPulseY - height * 0.5
            width: (22 + view.impactPulseProg * 68) * 2
            height: width; radius: width * 0.5
            z: 9
            color: "transparent"
            border.width: 2.8
            border.color: Qt.rgba(1.0, 0.94, 0.80, (1.0 - view.impactPulseProg) * 0.78)
        }

        // Naked Center Icon at world (0, 0) — NO circle ring, NO Host pill!
        Item {
            id: centerHostAnchor
            x: 0; y: 0
            width: 1; height: 1
            z: 22

            property real hoverBoost: hostMa.pressed ? 0.90 : (hostMa.containsMouse ? 1.14 : 1.0)
            Behavior on hoverBoost { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

            HubSourceGlyph {
                x: -width * 0.5
                y: -height * 0.5
                sourceKind: view.sourceKind
                btIconGlyph: view.btIconGlyph
                accentColor: hostMa.containsMouse ? "#ffffff" : view.goldBright
                glyphSize: 38
                scale: view.nodeZoomComp * 0.92 * centerHostAnchor.hoverBoost * (0.65 + 0.35 * view.bhReveal) * view.galaxySuckScale
                opacity: view.bhReveal * view.galaxySuckOpacity
            }

            MouseArea {
                id: hostMa
                x: -28; y: -28
                width: 56; height: 56
                hoverEnabled: !view.interactionLocked
                enabled: view.active && view.entranceReady && view.powerAnimState === "on" && (view.phase === "idle" || view.phase === "holdingBeam")
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (view.drawerOpen) {
                        view.cancelDrawerAndRetract();
                    } else if (view.isFullscreen) {
                        view.exitFullscreenRequested();
                    } else if (view.blackHoleCenterMode) {
                        // In Panel Gargantua mode, smoothly recenter camera on Gargantua!
                        Sounds.playSfx("reusables/clickbutton/click.wav", 0.32);
                        view.targetCamX = 0.0;
                        view.targetCamY = 0.0;
                        view.targetCamZ = 0.38;
                    } else {
                        view.exitToConnectedUi();
                    }
                }
            }
        }

        // Upright Flat 2D Wi-Fi / BT Constellation Nodes (Rock-steady scale, ZERO self-enlarging bug!)
        ListModel { id: nodeModel }

        Repeater {
            model: nodeModel

            delegate: Item {
                id: nodeItem
                required property int index
                required property string uid
                required property string name
                required property string subtitle
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

                readonly property bool isHovered: !view.interactionLocked && view.hoveredId === uid
                readonly property bool isSelected: view.drawerNodeId === uid || view.actionTargetId === uid
                readonly property bool showGlassPill: isHovered || isSelected

                property real hoverBoost: (isHovered || isSelected) ? 1.07 : 1.0
                Behavior on hoverBoost { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                x: nx
                y: ny
                width: 1; height: 1
                z: showGlassPill ? 32 : (connected ? 20 : 14)
                // Clean rock-steady scale (NO Behavior fighting camZ -> ZERO self-enlarging text bug!)
                scale: nScale * view.nodeZoomComp * hoverBoost
                opacity: nOpacity
                visible: nOpacity > 0.02

                // Soft atmospheric star glow behind node anchor
                Rectangle {
                    x: -width * 0.5; y: -height * 0.5
                    width: (nodeItem.connected || nodeItem.showGlassPill) ? 28 : 18
                    height: width; radius: width * 0.5
                    color: {
                        if (nodeItem.lockState === "error") return Qt.alpha(ThemeBackend.red, 0.32);
                        if (nodeItem.lockState === "unlocked") return Qt.alpha(ThemeBackend.green, 0.32);
                        if (nodeItem.connected) return Qt.rgba(0.96, 0.78, 0.48, 0.32);
                        if (nodeItem.showGlassPill) return Qt.rgba(1.0, 0.94, 0.80, 0.26);
                        return Qt.rgba(1.0, 1.0, 1.0, 0.14);
                    }
                }

                // Crisp luminous star core dot
                Rectangle {
                    x: -width * 0.5; y: -height * 0.5
                    width: (nodeItem.connected || nodeItem.showGlassPill) ? 9.5 : 7.0
                    height: width; radius: width * 0.5
                    color: {
                        if (nodeItem.lockState === "error") return ThemeBackend.red;
                        if (nodeItem.lockState === "unlocked") return ThemeBackend.green;
                        if (nodeItem.connected) return view.goldBright;
                        return "#ffffff";
                    }
                    border.width: nodeItem.connected ? 1.2 : 0
                    border.color: view.goldAccent
                }

                // Clean upright minimal label + translucent obsidian glass pill on hover/focus
                Rectangle {
                    id: labelPill
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 9
                    width: labelCol.implicitWidth + (nodeItem.showGlassPill ? 18 : 10)
                    height: labelCol.implicitHeight + (nodeItem.showGlassPill ? 10 : 4)
                    radius: 8
                    color: nodeItem.showGlassPill ? Qt.rgba(0.05, 0.05, 0.07, 0.88) : "transparent"
                    border.width: nodeItem.showGlassPill ? 1 : 0
                    border.color: {
                        if (nodeItem.lockState === "error") return ThemeBackend.red;
                        if (nodeItem.lockState === "unlocked") return ThemeBackend.green;
                        if (nodeItem.connected || nodeItem.isSelected) return Qt.rgba(0.96, 0.82, 0.56, 0.65);
                        return Qt.rgba(1.0, 1.0, 1.0, 0.30);
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    Column {
                        id: labelCol
                        anchors.centerIn: parent
                        spacing: 1

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 4

                            Text {
                                visible: nodeItem.isBt || nodeItem.lockState !== "none"
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    if (nodeItem.isBt) return nodeItem.icon !== "" ? nodeItem.icon : "󰂯";
                                    if (nodeItem.lockState === "unlocked" || nodeItem.lockState === "saved") return "󰌿";
                                    return "󰌾";
                                }
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: 10
                                color: {
                                    if (nodeItem.lockState === "error") return ThemeBackend.red;
                                    if (nodeItem.lockState === "unlocked") return ThemeBackend.green;
                                    if (nodeItem.connected) return view.goldAccent;
                                    return Qt.rgba(0.88, 0.90, 0.95, 0.82);
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: nodeItem.name
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: 13
                                font.weight: (nodeItem.connected || nodeItem.showGlassPill) ? Font.DemiBold : Font.Medium
                                color: nodeItem.connected ? view.goldBright : "#f5f6fa"
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: nodeItem.subtitle
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 10
                            color: nodeItem.connected
                                ? Qt.rgba(0.95, 0.82, 0.58, 0.86)
                                : Qt.rgba(0.76, 0.78, 0.84, 0.72)
                        }
                    }
                }

                // Item #3: Completely disabled & zero hover effect while waiting/connecting!
                MouseArea {
                    x: -Math.max(26, labelPill.width * 0.5)
                    y: -15
                    width: Math.max(52, labelPill.width)
                    height: labelPill.height + 26
                    hoverEnabled: !view.interactionLocked
                    enabled: view.active && view.entranceReady && !view.interactionLocked && nodeItem.nOpacity > 0.14
                    cursorShape: view.interactionLocked ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onEntered: {
                        if (view.interactionLocked) return;
                        view.hoveredId = nodeItem.uid;
                        view.store.playHoverProfile();
                    }
                    onExited: {
                        if (view.hoveredId === nodeItem.uid) view.hoveredId = "";
                    }
                    onClicked: view.triggerNodeClick(nodeItem.uid)
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Layer 2.5: Powered-OFF Bouncy Obsidian-Gold Wi-Fi / BT Center Orb (0% GPU while idle!)
    // ------------------------------------------------------------------
    Item {
        id: offOrbHost
        anchors.centerIn: parent
        z: 18
        width: view.isFullscreen ? 148 : 118
        height: width
        visible: view.offOrbOpacity > 0.01
        opacity: view.offOrbOpacity
        scale: view.offOrbScale * offOrbInteractiveScale

        property real offOrbInteractiveScale: offOrbMa.pressed ? 0.89 : (offOrbMa.containsMouse ? 1.09 : 1.0)
        Behavior on offOrbInteractiveScale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
        }

        // Soft golden-champagne cosmic aura halo around the bouncy orb
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.38
            height: width
            radius: width * 0.5
            opacity: offOrbMa.containsMouse ? 0.58 : 0.34
            Behavior on opacity { NumberAnimation { duration: 180 } }
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.96, 0.78, 0.46, 0.42) }
                GradientStop { position: 0.52; color: Qt.rgba(0.96, 0.78, 0.46, 0.14) }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }

        // Delicate outer orbital ring
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.14
            height: width
            radius: width * 0.5
            color: "transparent"
            border.width: 1
            border.color: offOrbMa.containsMouse
                ? Qt.rgba(1.0, 0.90, 0.68, 0.52)
                : Qt.rgba(0.96, 0.80, 0.52, 0.24)
            Behavior on border.color { ColorAnimation { duration: 180 } }
        }

        // Glossy Obsidian-Gold Bouncy Sphere
        Rectangle {
            id: offOrbSphere
            anchors.centerIn: parent
            width: view.isFullscreen ? 116 : 92
            height: width
            radius: width * 0.5
            border.width: offOrbMa.containsMouse ? 1.8 : 1.3
            border.color: offOrbMa.containsMouse
                ? Qt.rgba(1.0, 0.92, 0.74, 0.92)
                : Qt.rgba(0.96, 0.80, 0.52, 0.58)
            Behavior on border.color { ColorAnimation { duration: 180 } }

            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#1c1814" }
                GradientStop { position: 0.55; color: "#0b0a0e" }
                GradientStop { position: 1.0; color: "#050508" }
            }

            // Subtle upper-left specular glass sheen
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 6
                width: parent.width * 0.62
                height: parent.height * 0.28
                radius: height * 0.5
                opacity: 0.16
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#fff5df" }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // Clean glowing Wi-Fi (󰤨) / Bluetooth (󰂯) glyph (no slash per Mo 1A!)
            Text {
                anchors.centerIn: parent
                text: view.store.activeMode === "bt" ? "󰂯" : "󰤨"
                font.family: ThemeBackend.iconFont
                font.pixelSize: view.isFullscreen ? 46 : 36
                color: offOrbMa.containsMouse ? "#ffffff" : view.goldBright
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }

        MouseArea {
            id: offOrbMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: view.active && view.entranceReady && view.powerAnimState === "off"
            cursorShape: Qt.PointingHandCursor
            onClicked: view.requestPowerToggle()
        }
    }

    // ------------------------------------------------------------------
    // Layer 3: Left-Side Obsidian Inspector / Password / Connect Drawer
    // ------------------------------------------------------------------
    NetworkInfoDrawer {
        id: infoDrawer
        z: 50
        side: "left"
        cosmosDarkStyle: true
        open: view.drawerOpen
        isFullscreen: view.isFullscreen
        itemData: view.drawerItemData
        activeMode: view.store.activeMode
        accentColor: view.goldAccent
        lockState: view.drawerLockState
        isConnected: view.drawerItemConnected
        storeRef: view.store
        checking: view.checkingPwdId !== ""

        onSubmitPassword: (uid, password) => view.handleSubmitPassword(uid, password)
        onConnectRequested: (uid) => view.handleDirectConnect(uid)
        onDisconnectRequested: (uid) => view.handleDisconnect(uid)
        onCloseRequested: view.cancelDrawerAndRetract()
    }
}
