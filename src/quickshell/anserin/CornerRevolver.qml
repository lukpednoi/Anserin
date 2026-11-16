import QtQuick
import Quickshell
import Quickshell.Wayland
import QtQuick.Shapes
import "../"
import "../reusables"

// Anserin interface only: the pointer at a screen's bottom-left corner opens a revolver's cylinder out of that corner,
// a quarter of it showing, with three chambers holding the desktop's quick actions (they were the desktop's right-click
// menu): Open Redactor, Restart desktop and Night mode, and a quarter turn on Lock screen, Select Wallpaper and Shuffle
// wallpaper. The wheel or a swipe over it turns it a quarter, down clockwise and up back (its four quarters hold the two
// sets in turn); the icons stay upright. It is the Modern frame's own colour, as dark (its glass when that is on), and
// it grows out of the frame with rounded joins where it meets
// the frame's left and bottom sides, as the edge panels do. The pointer leaving it closes it; an action closes it too,
// except Night mode, whose chamber glows while night light is on. Lock screen fires its chamber like a bullet to the
// screen's top-right corner and asks for the lock on the way (lockRequested; AnserinMode.lockShotAt tells the Simple
// lock screen's Bullet animation to sweep in from that corner). The window covers the screen for the bullet's flight;
// only the corner, or the open cylinder, takes the pointer.
Variants {
    id: root
    signal lockRequested()
    model: Quickshell.screens

    PanelWindow {
        id: win
        required property var modelData
        screen: modelData

        function s(v) { return Scaler.s(v); }
        readonly property real radius: s(185)            // the cylinder
        readonly property real ringR: s(113)             // where the chambers sit
        readonly property real holeR: s(25)
        // the Modern frame along the screen's edges (0 without it), and the joins' size where the cylinder meets it
        readonly property real inset: ScreenEdges.inset(modelData)
        readonly property real joinR: Math.min(ScreenEdges.rounding, s(16))

        WlrLayershell.namespace: "anserin-corner-revolver"
        WlrLayershell.layer: WlrLayer.Overlay
        exclusionMode: ExclusionMode.Ignore
        anchors { left: true; bottom: true; top: true; right: true }
        color: "transparent"

        // closed, only the corner's few pixels take the pointer; open, the quarter circle
        mask: Region {
            x: win.open ? -win.radius : 0
            y: win.open ? win.height - win.radius : win.height - 3
            width: win.open ? 2 * win.radius : 3
            height: win.open ? 2 * win.radius : 3
            shape: win.open ? RegionShape.Ellipse : RegionShape.Rect
        }

        property bool open: false
        property real shown: open ? 1 : 0
        Behavior on shown { NumberAnimation { duration: win.open ? 420 : 220; easing.type: win.open ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.15 } }

        HoverHandler { id: hover }
        Timer { interval: 90; running: hover.hovered && !win.open; onTriggered: win.open = true }
        Timer { interval: 320; running: !hover.hovered && win.open; onTriggered: win.open = false }

        // which quarter is in view (each a quarter turn on), eased toward
        property int turns: 0
        property real turn: turns * 90
        Behavior on turn { NumberAnimation { duration: 440; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        function rotate(dir) {
            turns += dir;
            Sounds.playSfx("guide/barconfig/in.wav", 0.5);
        }
        // the sidebar's way (BlankPanel's sideWheel): a wheel click is one turn; a touchpad swipe counts once
        property real wheelAcc: 0
        Timer { id: swipeIdle; property bool locked: false; interval: 220; onTriggered: { locked = false; win.wheelAcc = 0; } }
        WheelHandler {
            orientation: Qt.Vertical
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            enabled: win.open
            onWheel: (e) => {
                const d = e.angleDelta.y;
                if (d === 0) return;
                if (!swipeIdle.running && Math.abs(d) % 120 === 0) { win.rotate(d < 0 ? 1 : -1); return; }
                if (Math.abs(d) >= 120) return;
                const locked = swipeIdle.locked;
                swipeIdle.restart();
                if (locked) return;
                win.wheelAcc += d;
                if (Math.abs(win.wheelAcc) < 120) return;
                win.rotate(win.wheelAcc < 0 ? 1 : -1);
                win.wheelAcc = 0;
                swipeIdle.locked = true;
            }
        }

        readonly property bool nightOn: BlueLight.isAnyEnabled()
        readonly property var pages: [
            [{ icon: "󰕰", act: "redactor" }, { icon: "󰑐", act: "restart" }, { icon: "󰖔", act: "night" }],
            [{ icon: "󰌾", act: "lock" }, { icon: "󰸉", act: "select" }, { icon: "󰒝", act: "shuffle" }]
        ]
        function run(act) {
            const dir = Caching.anserinDir;
            if (act === "night") { Sounds.playSfx("system/quick_click.wav"); BlueLight.toggleAll(); return; }
            Sounds.playSfx("reusables/clickbutton/click.wav");
            open = false;
            if (act === "redactor") Quickshell.execDetached(["bash", dir + "/scripts/redactor.sh", modelData.name, ""]);
            else if (act === "restart") Quickshell.execDetached(["bash", dir + "/scripts/reload.sh"]);
            else if (act === "lock") fire();
            else if (act === "select") Quickshell.execDetached(["bash", dir + "/scripts/qs_manager.sh", "toggle", "wallpaper"]);
            else if (act === "shuffle") Wallpaper.shuffle(modelData);
        }

        // ---------- the bullet: out of the Lock chamber (top of the view) to past the top-right corner ----------
        property real shot: 0
        property bool lockAsked: false
        readonly property point shotFrom: Qt.point(Math.cos(75 * Math.PI / 180) * ringR, height - Math.sin(75 * Math.PI / 180) * ringR)
        readonly property point shotTo: Qt.point(width + 3 * holeR, -3 * holeR)
        function fire() {
            lockAsked = false;
            shotAnim.restart();
        }
        NumberAnimation { id: shotAnim; target: win; property: "shot"; from: 0; to: 1; duration: 260; easing.type: Easing.InQuad }
        // the lock comes a moment before the bullet is gone: its picture of the desktop takes that long
        onShotChanged: if (shot >= 0.7 && !lockAsked && shotAnim.running) {
            lockAsked = true;
            AnserinMode.lockShotAt = Date.now();
            root.lockRequested();
        }
        Repeater {
            model: 4                                   // the bullet and three fading echoes behind it
            Rectangle {
                required property int index
                readonly property real t: Math.max(0, win.shot - index * 0.06)
                z: 50
                visible: shotAnim.running && t > 0
                width: 2 * win.holeR * (1 - index * 0.15); height: width; radius: width / 2
                x: win.shotFrom.x + (win.shotTo.x - win.shotFrom.x) * t - width / 2
                y: win.shotFrom.y + (win.shotTo.y - win.shotFrom.y) * t - height / 2
                color: index === 0 ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.mauve, 0.35 - index * 0.09)
                Text {
                    visible: parent.index === 0
                    anchors.centerIn: parent
                    text: "󰌾"; font.family: ThemeBackend.iconFont; font.pixelSize: win.s(18); color: ThemeBackend.crust
                }
            }
        }

        // where the cylinder's rim crosses the frame's inner sides, for the joins (its size as it grows)
        readonly property real rimR: radius * Math.max(0, shown)
        readonly property real cross: Math.sqrt(Math.max(0, rimR * rimR - inset * inset))
        readonly property real joinS: inset > 0 && rimR > inset + joinR ? joinR * Math.min(1, shown) : 0

        // the ground, centred on the corner, growing out of it: the frame's colour (or glass)
        Item {
            id: ground
            x: -win.radius; y: win.height - win.radius
            width: 2 * win.radius; height: width
            visible: win.shown > 0.01
            transform: Scale { origin.x: win.radius; origin.y: win.radius; xScale: Math.max(0, win.shown); yScale: xScale }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: groundGlass.active ? "transparent" : ThemeBackend.base
                WallpaperBlur {
                    id: groundGlass
                    anchors.fill: parent
                    topLeftRadius: width / 2; topRightRadius: width / 2; bottomLeftRadius: width / 2; bottomRightRadius: width / 2
                }
            }
        }
        // the rounded joins into the frame: above the cylinder on the frame's left side, and right of it on the bottom
        // (in the frame's colour; with its glass the cylinder simply meets it)
        Shape {
            anchors.fill: parent
            visible: win.joinS > 0.5 && !groundGlass.active
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"; fillColor: ThemeBackend.base
                startX: win.inset; startY: win.height - win.cross - win.joinS
                PathLine { x: win.inset; y: win.height - win.cross + 1 }
                PathLine { x: win.inset + win.joinS; y: win.height - win.cross + 1 }
                PathArc { x: win.inset; y: win.height - win.cross - win.joinS; radiusX: win.joinS; radiusY: win.joinS; direction: PathArc.Clockwise }
            }
            ShapePath {
                strokeColor: "transparent"; fillColor: ThemeBackend.base
                startX: win.cross + win.joinS; startY: win.height - win.inset
                PathLine { x: win.cross - 1; y: win.height - win.inset }
                PathLine { x: win.cross - 1; y: win.height - win.inset - win.joinS }
                PathArc { x: win.cross + win.joinS; y: win.height - win.inset; radiusX: win.joinS; radiusY: win.joinS; direction: PathArc.Counterclockwise }
            }
        }

        // the chambers, turning over the ground
        Item {
            id: cylinder
            x: -win.radius; y: win.height - win.radius
            width: 2 * win.radius; height: width
            visible: win.shown > 0.01
            opacity: Math.min(1, win.shown * 1.4)
            transform: Scale { origin.x: win.radius; origin.y: win.radius; xScale: Math.max(0, win.shown); yScale: xScale }
            rotation: win.turn - 40 * (1 - win.shown)      // it spins in as it opens

            // twelve chambers: three to a quarter, the quarters holding the two sets in turn
            Repeater {
                model: 12
                Item {
                    id: chamber
                    required property int index
                    readonly property int quarter: Math.floor(index / 3)
                    readonly property var item: win.pages[quarter % 2][index % 3]
                    // from the top of its quarter down: 75°, 45°, 15° above that quarter's start
                    readonly property real angle: (quarter * 90 + 75 - (index % 3) * 30) * Math.PI / 180
                    readonly property bool glow: item.act === "night" && win.nightOn
                    x: win.radius + Math.cos(angle) * win.ringR - win.holeR
                    y: win.radius - Math.sin(angle) * win.ringR - win.holeR
                    width: 2 * win.holeR; height: width
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: chamber.glow ? ThemeBackend.peach : (holeMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.crust)
                        border.width: 1; border.color: Qt.alpha(ThemeBackend.text, chamber.glow ? 0 : 0.12)
                        scale: holeMa.pressed ? 0.9 : (holeMa.containsMouse ? 1.08 : 1)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
                        Text {
                            anchors.centerIn: parent
                            rotation: -cylinder.rotation          // upright however the cylinder has turned
                            text: chamber.item.icon
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: win.s(18)
                            color: chamber.glow ? ThemeBackend.crust : ThemeBackend.text
                        }
                    }
                    MouseArea {
                        id: holeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: win.run(chamber.item.act)
                    }
                }
            }
        }
    }
}
