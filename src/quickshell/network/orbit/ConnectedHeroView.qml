import QtQuick
import "../../"
import QtQuick.Layouts
import QtQuick.Shapes
import "."

/**
 * Connected foreground UI modeled after 4.png (fixed 72px height in BOTH states!):
 *   - Top-left circular Host button ONLY (click enters Scan view with original Host SFX)
 *   - Bottom bar with two comparison variants (fixed 72px tall, no vertical growth):
 *       1) "compactBox": Rounded frosted bar (`72px` height) with 4 subtle waves inside
 *       2) "underline": Frameless bottom bar (`72px` height) keeping the 4 waves above a crisp underline
 *   - Left Hub-matching icon toggle button: swaps center [icon + name] (no arrow, no "Connected")
 *     for 4 horizontal inline tiles (`row4`) while smoothly pushing the 2 right buttons out!
 */
Item {
    id: hero

    required property NetworkStore store
    property color accentColor: ThemeBackend.mauve
    property string layoutVariant: "bottomBar"
    property string barStyle: "compactBox" // "compactBox" | "underline"
    property bool showPanelWaves: true
    property real hubXRatio: 0.50
    property real hubYRatio: 0.37
    property bool active: true
    property bool winVisible: true
    property bool showHostButton: true

    property bool showDetails: false
    property real introState: 1.0

    readonly property var conn: store.activeConnection
    readonly property bool isBottomBar: layoutVariant === "bottomBar"
    readonly property bool isUnderline: barStyle === "underline"
    readonly property bool detailsOpen: showDetails
    readonly property real targetBarHeight: 72
    readonly property real barBottomMargin: 24
    readonly property real barHeight: bottomCard.height

    function animWin(t, a, b) {
        if (t <= a) return 0.0;
        if (t >= b) return 1.0;
        return (t - a) / (b - a);
    }
    function easeOut(t) {
        const c = Math.max(0.0, Math.min(1.0, t));
        return 1.0 - Math.pow(1.0 - c, 3);
    }
    function easeBack(t) {
        const c = Math.max(0.0, Math.min(1.0, t));
        return 1.0 + 2.7 * Math.pow(c - 1.0, 3) + 1.7 * Math.pow(c - 1.0, 2);
    }

    function playIntro() {
        introPlayTimer.stop();
        introAnim.stop();
        hero.introState = 0.0;
        introPlayTimer.restart();
    }

    onActiveChanged: {
        if (active && winVisible) playIntro();
    }
    Component.onCompleted: {
        if (active && winVisible) playIntro();
    }

    Timer {
        id: introPlayTimer
        interval: 16
        onTriggered: introAnim.restart()
    }

    NumberAnimation {
        id: introAnim
        target: hero
        property: "introState"
        from: 0.0
        to: 1.0
        duration: 780
        easing.type: Easing.Linear
    }

    // Anserin introPing ring centered on the open NetworkBackdrop hub
    Rectangle {
        x: hero.width * hero.hubXRatio - width / 2
        y: hero.height * hero.hubYRatio - height / 2
        width: 340
        height: 340
        radius: 170
        color: "transparent"
        border.color: hero.accentColor
        border.width: 2
        readonly property real pingProg: hero.animWin(hero.introState, 0.02, 0.38)
        opacity: (1.0 - pingProg) * 0.44
        scale: 0.2 + 0.9 * pingProg
        visible: hero.active && hero.winVisible && pingProg > 0.001 && pingProg < 0.999
    }

    // Top-left circular Host button (opens Scan view)
    HostScanButton {
        id: hostBtn
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 18
        anchors.topMargin: 18
        accentColor: hero.accentColor
        active: hero.active
        winVisible: hero.winVisible
        buttonSize: 44

        readonly property real wProg: hero.animWin(hero.introState, 0.04, 0.36)
        readonly property real eOut: hero.easeOut(wProg)
        opacity: hero.showHostButton ? eOut : 0.0
        visible: hero.showHostButton && opacity > 0.01
        enabled: hero.showHostButton && hero.active
        scale: 0.8 + 0.2 * hero.easeBack(wProg)

        onClicked: hero.store.openSearch()
    }

    // Edge-to-edge full-width Bottom Bar Container (0..565px)
    Rectangle {
        id: bottomCard
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: hero.barBottomMargin
        height: hero.targetBarHeight
        radius: 0
        color: hero.isUnderline
            ? "transparent"
            : Qt.rgba(ThemeBackend.mantle.r, ThemeBackend.mantle.g, ThemeBackend.mantle.b, 0.82)
        border.width: 0
        clip: true

        readonly property real wProg: hero.animWin(hero.introState, 0.08, 0.46)
        readonly property real eOut: hero.easeOut(wProg)
        opacity: eOut
        transform: Translate { y: (1.0 - bottomCard.eOut) * 18 }

        // Tapered full-span underline (x: 18..547 = 1st icon left edge to last icon right edge):
        //   - Thick glowing under Left/Right icons, smoothly thinning at dividers into a clean theme line
        //   - Both outer ends taper & alpha-fade smoothly to zero (never a blunt cut end!)
        Canvas {
            id: underlineCanvas
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.bottom: parent.bottom
            height: 16
            z: 2
            visible: hero.isUnderline

            property real rightWeight: hero.showDetails ? 0.0 : 1.0
            Behavior on rightWeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            onRightWeightChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()

            Connections {
                target: hero
                function onAccentColorChanged() { underlineCanvas.requestPaint(); }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (width <= 0 || height <= 0) return;

                const c = hero.accentColor;
                const w = width;
                const cy = height - 3.0;
                const rw = rightWeight;

                function smoothstep(t) {
                    const v = Math.max(0.0, Math.min(1.0, t));
                    return v * v * (3.0 - 2.0 * v);
                }

                function halfThickness(x) {
                    const leftEnd = 12.0;
                    const rightEnd = w - 12.0;
                    const leftThickEnd = 42.0;
                    const leftThinStart = 64.0;
                    const rightThinEnd = w - 64.0;
                    const rightThickStart = w - 42.0;

                    let h = 0.50; // Base crisp thin theme stroke across center
                    if (x < leftThickEnd) {
                        h = 1.48;
                    } else if (x < leftThinStart) {
                        h = 1.48 - 0.98 * smoothstep((x - leftThickEnd) / (leftThinStart - leftThickEnd));
                    } else if (x > rightThinEnd && x < rightThickStart) {
                        h = 0.50 + rw * 0.98 * smoothstep((x - rightThinEnd) / (rightThickStart - rightThinEnd));
                    } else if (x >= rightThickStart) {
                        h = 0.50 + rw * 0.98;
                    }

                    // Smooth zero-width taper at outer tips so ends are never cut blunt
                    if (x < leftEnd) h *= smoothstep(x / leftEnd);
                    else if (x > rightEnd) h *= smoothstep((w - x) / 12.0);
                    return h;
                }

                // Feathered multi-step ambient aura strongest under icon bases, fading softly to 0 at tips
                function fillGlowRibbon(scaleY, peakA, midA) {
                    const g = ctx.createLinearGradient(0, 0, w, 0);
                    g.addColorStop(0.00, Qt.rgba(c.r, c.g, c.b, 0.0));
                    g.addColorStop(0.04, Qt.rgba(c.r, c.g, c.b, peakA));
                    g.addColorStop(0.13, Qt.rgba(c.r, c.g, c.b, midA));
                    g.addColorStop(0.87, Qt.rgba(c.r, c.g, c.b, midA));
                    g.addColorStop(0.96, Qt.rgba(c.r, c.g, c.b, midA + rw * (peakA - midA)));
                    g.addColorStop(1.00, Qt.rgba(c.r, c.g, c.b, 0.0));

                    ctx.beginPath();
                    ctx.moveTo(0, cy);
                    for (let x = 0; x <= w; x += 3) {
                        ctx.lineTo(x, cy - halfThickness(x) * scaleY);
                    }
                    ctx.lineTo(w, cy);
                    ctx.closePath();
                    ctx.fillStyle = g;
                    ctx.fill();
                }

                fillGlowRibbon(4.8, 0.08, 0.02);
                fillGlowRibbon(2.6, 0.16, 0.05);

                // Main variable-width underline polygon with seamless gradient opacity
                const lineGrad = ctx.createLinearGradient(0, 0, w, 0);
                lineGrad.addColorStop(0.00, Qt.rgba(c.r, c.g, c.b, 0.0));
                lineGrad.addColorStop(0.025, Qt.rgba(c.r, c.g, c.b, 0.92));
                lineGrad.addColorStop(0.082, Qt.rgba(c.r, c.g, c.b, 0.90));
                lineGrad.addColorStop(0.135, Qt.rgba(c.r, c.g, c.b, 0.56));
                lineGrad.addColorStop(0.865, Qt.rgba(c.r, c.g, c.b, 0.56));
                lineGrad.addColorStop(0.918, Qt.rgba(c.r, c.g, c.b, 0.56 + rw * 0.34));
                lineGrad.addColorStop(0.975, Qt.rgba(c.r, c.g, c.b, 0.56 + rw * 0.36));
                lineGrad.addColorStop(1.00, Qt.rgba(c.r, c.g, c.b, 0.0));

                ctx.beginPath();
                for (let x = 0; x <= w; x += 2) {
                    const h = halfThickness(x);
                    if (x === 0) ctx.moveTo(x, cy - h);
                    else ctx.lineTo(x, cy - h);
                }
                for (let x = w; x >= 0; x -= 2) {
                    const h = halfThickness(x);
                    ctx.lineTo(x, cy + h);
                }
                ctx.closePath();
                ctx.fillStyle = lineGrad;
                ctx.fill();
            }
        }

        // 4 subtle thin wave strokes spanning strictly 1st icon to last icon (x=18..547) with soft end fades
        Canvas {
            id: bottomWaveCanvas
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            z: 0
            clip: true
            visible: hero.showPanelWaves && hero.visible && hero.active
            opacity: 0.9

            property real wavePhase: 0
            NumberAnimation on wavePhase {
                running: bottomWaveCanvas.visible && hero.winVisible
                from: 0
                to: Math.PI * 2
                duration: 7600
                loops: Animation.Infinite
            }

            onWavePhaseChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onVisibleChanged: if (visible) requestPaint()

            Connections {
                target: hero
                function onAccentColorChanged() { bottomWaveCanvas.requestPaint(); }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                if (width <= 0 || height <= 0) return;

                const c = hero.accentColor;
                const cy = height * 0.50;
                const ph = wavePhase;
                const ampScale = Math.max(0.45, Math.min(1.0, height / 118.0));
                const waves = [
                    { amp: 13.0, freq: 0.014, speed:  1.0, phase: 0.0, yOff: -15 * ampScale, alpha: 0.30, lw: 1.35 },
                    { amp: 9.5,  freq: 0.020, speed: -1.0, phase: 1.5, yOff:  -5 * ampScale, alpha: 0.24, lw: 1.15 },
                    { amp: 14.0, freq: 0.011, speed:  1.0, phase: 2.8, yOff:   5 * ampScale, alpha: 0.22, lw: 1.25 },
                    { amp: 8.5,  freq: 0.025, speed: -1.0, phase: 4.2, yOff:  15 * ampScale, alpha: 0.18, lw: 1.00 }
                ];

                ctx.lineCap = "round";
                for (let w = 0; w < waves.length; w++) {
                    const cfg = waves[w];
                    const wGrad = ctx.createLinearGradient(0, 0, width, 0);
                    wGrad.addColorStop(0.00, Qt.rgba(c.r, c.g, c.b, 0.0));
                    wGrad.addColorStop(0.07, Qt.rgba(c.r, c.g, c.b, cfg.alpha));
                    wGrad.addColorStop(0.93, Qt.rgba(c.r, c.g, c.b, cfg.alpha));
                    wGrad.addColorStop(1.00, Qt.rgba(c.r, c.g, c.b, 0.0));

                    ctx.beginPath();
                    for (let x = 0; x <= width; x += 6) {
                        const y = cy + cfg.yOff + Math.sin(x * cfg.freq + ph * cfg.speed + cfg.phase) * (cfg.amp * ampScale);
                        if (x === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }
                    ctx.lineWidth = cfg.lw;
                    ctx.strokeStyle = wGrad;
                    ctx.stroke();
                }
            }
        }

        // Section 1 (Left, x=18): Hub-matching icon toggle button
        Rectangle {
            id: hubToggleBtn
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            height: 44
            radius: 22
            z: 2
            scale: hubBtnMa.pressed ? 0.93 : (hubBtnMa.containsMouse ? 1.06 : 1.0)
            color: hero.showDetails
                ? Qt.alpha(hero.accentColor, 0.24)
                : (hubBtnMa.containsMouse ? Qt.alpha(hero.accentColor, 0.18) : Qt.alpha(ThemeBackend.base, 0.65))
            border.width: hero.showDetails ? 1.5 : 1.0
            border.color: hero.showDetails
                ? hero.accentColor
                : (hubBtnMa.containsMouse ? Qt.alpha(hero.accentColor, 0.72) : Qt.alpha(hero.accentColor, 0.42))

            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 160 } }
            Behavior on border.color { ColorAnimation { duration: 160 } }

            readonly property string hubKind: {
                if (hero.store.activeMode === "bt") return "bt";
                return (hero.conn && hero.conn.sourceType === "phone") ? "phone" : "router";
            }

            Shape {
                visible: hubToggleBtn.hubKind === "router"
                anchors.centerIn: parent
                width: 22
                height: 22
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: hero.accentColor
                    strokeWidth: 1.9
                    capStyle: ShapePath.RoundCap
                    startX: 7; startY: 11
                    PathLine { x: 7; y: 4 }
                    PathMove { x: 15; y: 11 }
                    PathLine { x: 15; y: 4 }
                }
                ShapePath {
                    fillColor: Qt.alpha(hero.accentColor, 0.16)
                    strokeColor: hero.accentColor
                    strokeWidth: 1.9
                    joinStyle: ShapePath.RoundJoin
                    startX: 5; startY: 11
                    PathLine { x: 17; y: 11 }
                    PathArc { x: 19.5; y: 13.5; radiusX: 2.5; radiusY: 2.5 }
                    PathLine { x: 19.5; y: 16.5 }
                    PathArc { x: 17; y: 19; radiusX: 2.5; radiusY: 2.5 }
                    PathLine { x: 5; y: 19 }
                    PathArc { x: 2.5; y: 16.5; radiusX: 2.5; radiusY: 2.5 }
                    PathLine { x: 2.5; y: 13.5 }
                    PathArc { x: 5; y: 11; radiusX: 2.5; radiusY: 2.5 }
                }
                Rectangle { x: 12.2; y: 14; width: 2.0; height: 2.0; radius: 1.0; color: hero.accentColor }
                Rectangle { x: 15.4; y: 14; width: 2.0; height: 2.0; radius: 1.0; color: hero.accentColor }
            }

            Text {
                visible: hubToggleBtn.hubKind !== "router"
                anchors.centerIn: parent
                text: hubToggleBtn.hubKind === "phone" ? "󰄜" : "󰂯"
                font.family: ThemeBackend.iconFont
                font.pixelSize: 19
                color: hero.accentColor
            }

            MouseArea {
                id: hubBtnMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    hero.showDetails = !hero.showDetails;
                    Sounds.playSfx("reusables/clickbutton/click.wav", 0.42);
                }
            }
        }

        // Divider 1
        Rectangle {
            id: leftDiv
            anchors.left: hubToggleBtn.right
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 16
            anchors.bottomMargin: 16
            width: 1
            z: 2
            color: Qt.alpha(hero.accentColor, hero.isUnderline ? 0.14 : 0.20)
        }

        // Section 2 (Symmetrically centered inside its own frame!):
        // Collapsed: [icon + SSID (+ BT dots)] sits strictly centered between leftDiv (87) & rightDiv (478).
        // Expanded: centerSlot widens cleanly to rightMargin 18 so 1x4 tiles sit centered inside [87..547].
        Item {
            id: centerSlot
            anchors.left: leftDiv.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: hero.showDetails ? 18 : 87
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            z: 2

            Behavior on anchors.rightMargin {
                enabled: hero.winVisible
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            // State A: Compact name view centered inside centerSlot (plus BT wheel scroll & >=2 dot indicators)
            Item {
                id: compactNameLayer
                anchors.fill: parent
                opacity: hero.showDetails ? 0.0 : 1.0
                scale: hero.showDetails ? 0.90 : 1.0
                x: hero.showDetails ? -16 : 0
                visible: opacity > 0.01
                enabled: !hero.showDetails

                property int btScrollDir: 1
                property real swapShift: 0
                property real swapAlpha: 1.0
                property string _prevConnId: ""

                Connections {
                    target: hero
                    function onConnChanged() {
                        const cid = hero.conn ? hero.conn.id : "";
                        if (compactNameLayer._prevConnId !== "" && cid !== "" && cid !== compactNameLayer._prevConnId
                            && hero.store.activeMode === "bt" && hero.active && !hero.showDetails) {
                            swapAnim.stop();
                            compactNameLayer.swapShift = compactNameLayer.btScrollDir * 14;
                            compactNameLayer.swapAlpha = 0.2;
                            swapAnim.start();
                        }
                        compactNameLayer._prevConnId = cid;
                    }
                }

                ParallelAnimation {
                    id: swapAnim
                    NumberAnimation { target: compactNameLayer; property: "swapShift"; to: 0; duration: 200; easing.type: Easing.OutCubic }
                    NumberAnimation { target: compactNameLayer; property: "swapAlpha"; to: 1.0; duration: 200; easing.type: Easing.OutCubic }
                }

                Timer {
                    id: wheelCooldown
                    interval: 110
                }

                WheelHandler {
                    enabled: hero.active && !hero.showDetails && hero.store.activeMode === "bt" && hero.store.connectedBtList.length >= 2
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (wheelCooldown.running) return;
                        const delta = Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x) ? event.angleDelta.y : event.angleDelta.x;
                        if (delta === 0) return;
                        wheelCooldown.restart();
                        const step = delta < 0 ? 1 : -1;
                        compactNameLayer.btScrollDir = step;
                        hero.store.cycleFocusedBt(step);
                        event.accepted = true;
                    }
                }

                Behavior on opacity { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Column {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 8)
                    spacing: (hero.store.activeMode === "bt" && hero.store.connectedBtList.length >= 2) ? 5 : 0
                    opacity: compactNameLayer.swapAlpha
                    transform: Translate { x: compactNameLayer.swapShift }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 9

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: {
                                if (!hero.conn) return "󰤨";
                                if (hero.store.activeMode === "bt") return hero.conn.icon || "󰂯";
                                return hero.conn.sourceType === "phone" ? "󰄜" : "󰤨";
                            }
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: 18
                            color: hero.accentColor
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, centerSlot.width - 40)
                            text: hero.conn ? (hero.conn.name || "") : ""
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: ThemeBackend.text
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Small page dots under Bluetooth device name (shown only when >= 2 BT devices are connected)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5
                        visible: hero.store.activeMode === "bt" && hero.store.connectedBtList.length >= 2

                        Repeater {
                            model: hero.store.connectedBtList
                            Rectangle {
                                required property var modelData
                                readonly property bool isFocused: hero.conn && hero.conn.mac === modelData.mac
                                width: isFocused ? 12 : 5
                                height: 4
                                radius: 2
                                color: isFocused ? hero.accentColor : Qt.alpha(ThemeBackend.subtext0, 0.48)

                                Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 180 } }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (hero.store.focusedBtMac !== modelData.mac) {
                                            hero.store.focusedBtMac = modelData.mac;
                                            hero.store.selectedId = modelData.id;
                                            hero.store.playProfileSfx("hover");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // State B: 4 inline boxes (1x4 single row) centered inside its expanded centerSlot frame
            Item {
                id: expandedTilesLayer
                anchors.fill: parent
                opacity: hero.showDetails ? 1.0 : 0.0
                scale: hero.showDetails ? 1.0 : 0.92
                x: hero.showDetails ? 0 : 28
                visible: opacity > 0.01
                enabled: hero.showDetails

                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.65 } }
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                MinimalInfoTiles {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    store: hero.store
                    accentColor: hero.accentColor
                    layoutMode: "row4"
                    introState: hero.introState
                }
            }
        }

        // Section 3 (Right, Trash removed! Contains divider + 44x44 On/Off slot, pushed out right on 1x4 expand)
        Item {
            id: rightActionsGroup
            property real pushX: hero.showDetails ? 72 : 0
            Behavior on pushX { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            x: parent.width - 18 - width + pushX
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 57 // 1px divider + 12px gap + 44px reserved On/Off (symmetric with left 18+44+12+1!)
            z: 2

            opacity: hero.showDetails ? 0.0 : 1.0
            visible: opacity > 0.01
            enabled: !hero.showDetails
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                width: 1
                color: Qt.alpha(hero.accentColor, hero.isUnderline ? 0.14 : 0.20)
            }

            // Right 44×44 slot holds NetworkPreviewShell's persistent pwrMorph On/Off button
        }
    }
}
