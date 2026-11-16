import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"

// The desktop pet (the Anserin interface, the Duck chosen, Desktop pet on in Theme → Pet; Shell.qml makes it only
// then): the duck (DuckActor) lives on the screen that was focused when it started, in a click-through overlay that
// takes input only on the duck.
//
//   Floors: the screen's bottom edge, and the top edge of every window on the shown workspace that does not touch the
//   top of the screen (what is inside a window is never a floor). Window edges can also be pecked.
//   Living on a window: a duck standing on a window stays on that window's workspace. Leaving that workspace sends
//   one notification ("Call it back", if theme.petDuck.recall); calling it back brings it flapping down from the top
//   of the screen here. No new notice while that one is still there; once it is dismissed, leaving the duck again
//   sends a new one. It hides while a window is fullscreen. Every 1-3 min it may go for the mouse pointer (read with
//   `hyprctl cursorpos` only then, 5 times a second); every 2-5 min it quacks.
//   Right-click the duck, then its pencil: the duck editor (PetState.openEditor()).
Scope {
    id: pet
    readonly property int size: PetState.duckSettings.size === 200 ? 200 : 128
    readonly property bool recallOn: PetState.duckSettings.recall !== false

    // the screen focused when it started; it stays there
    property var screen: null
    readonly property int wsId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    readonly property bool fullscreen: !!(Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.hasFullscreen)
    property var floors: []
    property var spots: []
    property int homeWs: 0                 // 0: on the screen's floor (every workspace); else the workspace it lives on
    property bool noticeOpen: false

    function rnd(a, b) { return a + Math.random() * (b - a); }

    // ---------- the windows on the shown workspace become floors and things to peck ----------
    Process {
        id: clients
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try { list = JSON.parse(text); } catch (e) { return; }
                const W = win.width, H = win.height, ox = pet.screen.x, oy = pet.screen.y;
                const fl = [{ x1: 0, x2: W, y: H - 4, addr: "" }], sp = [];
                for (const c of list) {
                    if (!c.mapped || c.hidden || !c.workspace || c.workspace.id !== pet.wsId || c.fullscreen) continue;
                    const x = c.at[0] - ox, y = c.at[1] - oy, w = c.size[0], h = c.size[1];
                    const x1 = Math.max(0, x), x2 = Math.min(W, x + w);
                    if (x2 - x1 < 20 || y > H || y + h < 0) continue;              // off this screen
                    if (y > 40 && x2 - x1 > pet.size * 0.9) fl.push({ x1: x1, x2: x2, y: y, addr: c.address });
                    if (y > 40) sp.push({ x1: x1 + 10, y1: y, x2: x2 - 10, y2: y });
                    if (x > 0) sp.push({ x1: x, y1: Math.max(0, y) + 20, x2: x, y2: Math.min(H, y + h) - 10 });
                    if (x + w < W) sp.push({ x1: x + w, y1: Math.max(0, y) + 20, x2: x + w, y2: Math.min(H, y + h) - 10 });
                }
                pet.floors = fl;
                pet.spots = sp;
            }
        }
    }
    Timer { id: refresh; interval: 80; onTriggered: clients.running = true }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["openwindow", "closewindow", "movewindowv2", "changefloatingmode", "fullscreen", "workspacev2",
                 "activewindowv2", "focusedmonv2", "moveworkspacev2"].indexOf(event.name) >= 0) refresh.restart();
        }
    }
    // a window can be moved or resized without any event: look again now and then, only while the duck stands on one
    Timer { interval: 2000; repeat: true; running: duck.visible && pet.homeWs !== 0; onTriggered: clients.running = true }

    // ---------- which workspace the duck lives on ----------
    function updateHome() {
        const f = duck.floorUnder();
        if (duck.action === "held" || duck.action === "drop" || !f) return;
        pet.homeWs = f.addr ? pet.wsId : 0;
    }
    Timer { interval: 1000; repeat: true; running: duck.visible; onTriggered: pet.updateHome() }
    onWsIdChanged: {
        refresh.restart();
        if (pet.recallOn && pet.homeWs !== 0 && pet.wsId !== pet.homeWs && !pet.noticeOpen) {
            pet.noticeOpen = true;
            notice.command = ["notify-send", "-a", "Anserin", "-A", "recall=Call it back",
                              "Your duck is on workspace " + pet.homeWs, "It is waiting on a window there. Call it back here?"];
            notice.running = true;
        }
    }
    Process {
        id: notice
        stdout: StdioCollector { id: noticeOut }
        onExited: {
            pet.noticeOpen = false;
            if (noticeOut.text.trim() === "recall") pet.recall();
        }
    }
    // back to the shown workspace: it comes flapping down from the top of the screen
    function recall() {
        pet.homeWs = 0;
        duck.px = rnd(0.25, 0.75) * win.width;
        duck.py = -0.3 * pet.size;
        duck.play("drop");
    }

    // ---------- now and then: quack, go for the pointer ----------
    readonly property bool busy: ["held", "drop", "petted", "peckAt"].indexOf(duck.action) >= 0
    Timer {
        id: quackTimer
        interval: 1000 * pet.rnd(120, 300); running: duck.visible
        onTriggered: { if (!pet.busy) duck.play("quack"); interval = 1000 * pet.rnd(120, 300); restart(); }
    }
    Timer {
        id: mouseTimer
        interval: 1000 * pet.rnd(60, 180); running: duck.visible
        onTriggered: { if (!pet.busy) { cursor.start = true; cursor.running = true; } interval = 1000 * pet.rnd(60, 180); restart(); }
    }
    Process {
        id: cursor
        property bool start: false
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                let c;
                try { c = JSON.parse(text); } catch (e) { return; }
                const x = c.x - pet.screen.x, y = c.y - pet.screen.y;
                if (cursor.start) {
                    cursor.start = false;
                    if (x < 0 || x > win.width || Math.abs(x - duck.px) > win.width / 2) return;   // too far: not interested
                    duck.play("peckAt", { x: x, y: y, mouse: true });
                } else if (duck.action === "peckAt" && duck.act.o.mouse && (!duck.act.stage || duck.act.stage === "go")) {
                    duck.act.o.x = x; duck.act.o.y = y;                                            // it follows the pointer
                }
            }
        }
    }
    Timer { interval: 200; repeat: true; running: duck.action === "peckAt" && duck.act && duck.act.o.mouse; onTriggered: cursor.running = true }

    // ---------- the overlay ----------
    PanelWindow {
        id: win
        screen: pet.screen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "anserin-pet"
        // input only on the duck (head, body, the pencil while it shows); the whole screen while a button is held on
        // it; nothing at all while it is hidden. The boxes are placed by their screen position: a Region on an item
        // follows only that item's own x/y, not the duck moving under it
        mask: !duck.visible ? noRegion : duck.handled ? wholeRegion : duckRegion
        Region { id: noRegion }
        Region { id: wholeRegion; width: win.width; height: win.height }
        Region {
            id: duckRegion
            x: duck.x + duck.bodyBox.x; y: duck.y + duck.bodyBox.y
            width: duck.bodyBox.width; height: duck.bodyBox.height
            Region {
                x: duck.x + duck.headBox.x; y: duck.y + duck.headBox.y
                width: duck.headBox.width; height: duck.headBox.height
            }
            Region {
                x: duck.x + duck.pencilBox.x; y: duck.y + duck.pencilBox.y
                width: duck.pencilBox.width; height: duck.pencilBox.height
            }
        }

        DuckActor {
            id: duck
            size: pet.size
            random: true
            quackInRandom: false
            floors: pet.floors
            spots: pet.spots
            px: win.width * 0.5
            py: -0.3 * pet.size
            visible: !pet.fullscreen && (pet.homeWs === 0 || pet.homeWs === pet.wsId) && pet.floors.length > 0 && !PetState.duckInEditor
            colour: PetState.colour
            labelFont: ThemeBackend.fontFamily
            onQuacked: PetState.quack()
            // the editor takes this duck in from where it stands (frozen mid-move if it was busy) and brings it back
            onPencilClicked: PetState.openEditorFrom({ x: duck.px, y: duck.py, size: duck.size, snap: duck.snapshot(),
                                                       busy: !(duck.action === "idle" || duck.action === "sit") }, pet.screen ? pet.screen.name : "")
            Component.onCompleted: play("drop")
        }

    }

    // back from the editor: it carries on standing where it was
    Connections {
        target: PetState
        function onDuckInEditorChanged() { if (!PetState.duckInEditor) duck.play("idle"); }
    }

    Component.onCompleted: {
        const name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
        pet.screen = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0];
        clients.running = true;
    }
}
