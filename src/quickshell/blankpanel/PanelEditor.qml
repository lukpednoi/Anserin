import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "pages" as Pages
import "smartweather" as SmartWeather
import "../network" as Network
import "../network/orbit" as Orbit
import "../widgets"
import "../reusables"
import "../media" as Media
import "../reusables/warning"

// Edit panel: a full-screen editor for the left edge panel's sidebar, built like the widget editor (same dim and
// the same bottom toolbar, WidgetPicker, with its own sections). The sidebar stands in the middle at its real
// size, drawing the panel's own modules, each in a white frame; the space left below is a white frame too.
// Modules are picked up and dropped like the old Bar settings' Available list: the module follows the pointer,
// a gap opens where it will land, and it plays the same out / in sounds. Drag from Modules into the sidebar,
// within it to reorder, or out of it to put a module away (the last one stays; at most ten fit). The Star
// button puts a star on the pointer: click a sidebar module to star it (again to unstar). Style shows a large live
// preview of the chosen module's style in the middle of the right edge, the styles before and after it half showing
// above and below, smaller and faint; the wheel or a swipe over it brings the next one forward (one a click or swipe,
// stopping at either end, as the sidebar steps). With Dashboard or Smart chosen for Weather, or Gargantua for
// Network, the pencil beside its preview opens the style editor: the sidebar slides away to the left, the preview
// rises to the middle of the screen and its Smart bar comes down above it (SceneEditor: Adjust saves
// panel.weatherScene.*, Test only changes the big preview; SmartWeatherEditor; GargantuaEditor); its Done or Esc puts
// everything back. Each of Music's three styles (Classic, Split, Ambient, panel.music) has a pencil opening its own
// bar (MusicStyleEditor) in the same way. Every change is saved at once; Done or Esc closes the editor and reopens
// the panel.
PanelWindow {
    id: win
    color: "transparent"
    screen: Quickshell.screens.find(s => s.name === PanelLayout.editScreen) || Quickshell.screens[0]

    WlrLayershell.namespace: "qs-panel-editor"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true; right: true; bottom: true }

    function s(v) { return Scaler.s(v); }

    // ---------- picking a style, with a warning for the heavy ones (reusables/warning/WarningDialog) ----------
    // Bubble (System): a plain warning. Gargantua (Network): Before → After (the two style cards), Cancel goes back.
    property var styleWarn: null        // { module, prev } while a change warning is open
    property var styleShots: []         // the two card pictures, kept while the warning shows them
    Timer { id: shotWait; interval: 50; property var go: null; onTriggered: { const f = go; go = null; if (f) f(); } }
    function pickStyle(moduleId, styleId) {
        const prev = PanelLayout.style(moduleId);
        if (prev === styleId) return;
        if (moduleId === "system" && styleId === "bubble") {
            PanelLayout.setStyle(moduleId, styleId);
            styleWarning.show({ text: "Bubble draws a live view of everything running, so it uses more of your computer than Graphs: extra RAM and some CPU while the System page is open. Nothing runs once the page is closed." });
        } else if (moduleId === "network" && styleId === "gargantua") {
            const text = "Gargantua draws a live black hole, so it uses more of your computer than Classic: extra RAM and some GPU while the Network page is open. Nothing runs once the page is closed.";
            const item = id => { for (let i = 0; i < previewRep.count; i++) { const it = previewRep.itemAt(i); if (it && it.modelData.id === id) return it; } return null; };
            const pa = item(prev), pb = item(styleId);
            const done = (before, after) => {
                if (pa) pa.holdDrawn = false;
                PanelLayout.setStyle(moduleId, styleId);
                win.styleWarn = { module: moduleId, prev: prev };
                styleWarning.show({ text: text, before: before, after: after });
            };
            // the two cards as pictures; if either cannot be taken, the warning shows without them
            const shoot = () => {
                if (!pa || !pb || !pa.card.grabToImage(ra => { if (!pb.card.grabToImage(rb => { win.styleShots = [ra, rb]; done(ra.url, rb.url); })) done("", ""); })) done("", "");
            };
            // a card far from the front is hidden and comes out blank: draw it (unseen) for a few frames first
            if (pa && !pa.visible) { pa.holdDrawn = true; shotWait.go = shoot; shotWait.restart(); }
            else shoot();
        } else {
            PanelLayout.setStyle(moduleId, styleId);
        }
    }

    property string styleModule: ""       // the module whose styles are shown at the right ("" = none)
    property bool starMode: false         // the pointer carries a star

    // ---------- the style editor: the Weather scene, or a Music style ----------
    property bool sceneEdit: false        // the big preview and its card are out
    property real sceneT: 0               // 0: the preview in its place at the right, 1: in the middle
    property rect sceneFrom: Qt.rect(0, 0, 1, 1)
    property string sceneKind: "weather"  // weather (Dashboard), smart (Smart Weather), gargantua (Network), or a Music style: original, m3, m5
    readonly property bool sceneMusic: ["original", "m3", "m5"].indexOf(sceneKind) >= 0
    // the design size of what is previewed: the panel's pages, or the Music window
    function designOf(moduleId) { return moduleId === "music" ? Qt.size(625, 565) : Qt.size(565, 525); }
    readonly property size sceneDesign: designOf(sceneMusic ? "music" : "weather")
    function openScene(frame, kind) {
        if (sceneEdit) return;
        const p = frame.mapToItem(root, 0, 0);
        sceneFrom = Qt.rect(p.x, p.y, frame.width, frame.height);
        sceneKind = kind || "weather";
        if (sceneKind === "weather") sceneCard.mode = "adjust";
        if (sceneKind === "smart") smartCard.reset();
        sceneEdit = true;
        sceneClose.stop();
        sceneOpen.restart();
    }
    function closeScene() { if (sceneEdit && !sceneClose.running) { sceneOpen.stop(); sceneClose.restart(); } }
    NumberAnimation { id: sceneOpen; target: win; property: "sceneT"; to: 1; duration: 560; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: sceneClose
        NumberAnimation { target: win; property: "sceneT"; to: 0; duration: 420; easing.type: Easing.InOutCubic }
        ScriptAction { script: win.sceneEdit = false }
    }
    property real shown: 0
    Component.onCompleted: fadeIn.restart()
    NumberAnimation { id: fadeIn; target: win; property: "shown"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
    SequentialAnimation {
        id: fadeOut
        NumberAnimation { target: win; property: "shown"; to: 0; duration: 200; easing.type: Easing.InCubic }
        ScriptAction { script: PanelLayout.endEdit() }
    }
    function done() { if (!fadeOut.running) fadeOut.restart(); }

    // ---------- dragging ----------
    property string dragId: ""            // the module being carried
    property bool dragFromSidebar: false
    property int hoverCell: -1            // the cell the carried module is over (-1: none)
    property real faceSize: s(40)
    // the sidebar's real measures (BlankPanel: sidebar 64 wide, modules from 24 down, 8 apart)
    readonly property real sideW: s(64)
    readonly property real sideH: s(589 - 52)
    readonly property real listTop: s(24)
    readonly property real listGap: s(8)
    // empty cells share what the modules leave, down to the foot of the sidebar (the panel does the same)
    readonly property var cellLayout: PanelLayout.cellLayout(sideH - listTop - s(12), listGap, heights, s(PanelLayout.emptyCell))
    readonly property real gapH: cellLayout.emptyH
    // heights of the drawn modules
    property var heights: ({})
    // noted after the layout settles (noting them while it is worked out loops)
    function noteHeight(id, h) {
        if (heights[id] === h) return;
        const next = Object.assign({}, heights); next[id] = h; heights = next;
    }
    function heightOf(id) { return id ? (heights[id] || s(44)) : gapH; }
    readonly property int cellCount: cellLayout.count
    readonly property bool overSidebar: dragId !== "" && ghost.cx > sidebar.x - s(40) && ghost.cx < sidebar.x + sidebar.width + s(40)
                                        && ghost.cy > sidebar.y - s(20) && ghost.cy < sidebar.y + sidebar.height + s(20)

    function pickUp(id, fromSidebar) {
        dragId = id;
        dragFromSidebar = fromSidebar;
    }
    function drop() {
        if (dragId === "") return;
        const id = dragId;
        Sounds.playSfx("guide/barconfig/in.wav");
        if (overSidebar && hoverCell >= 0) {
            if (!PanelLayout.placeAt(id, hoverCell)) warn.show("The sidebar holds " + PanelLayout.slotCount + " modules");
        } else if (dragFromSidebar && !overSidebar && !PanelLayout.remove(id)) {
            warn.show("The sidebar keeps at least one module");
        }
        dragId = "";
        hoverCell = -1;
    }

    Item {
        id: root
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (win.sceneEdit) { win.closeScene(); return; }
            if (win.starMode) { win.starMode = false; return; }
            if (!toolbar.dismiss()) win.done();
        }

        // pointer position, for the star the pointer carries
        HoverHandler { id: pointer }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.55)
            opacity: win.shown
            // a click on the background puts the star down
            MouseArea { anchors.fill: parent; enabled: win.starMode; onClicked: win.starMode = false }
        }

        Item {
            id: stage
            anchors.fill: parent
            opacity: win.shown
            transform: Translate { y: (1 - win.shown) * win.s(16) }

            // ---------- the sidebar, at its real size ----------
            Rectangle {
                id: sidebar
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(win.s(24), (toolbar.y - height) / 2)
                // slides away to the left while the scene editor is out
                opacity: 1 - win.sceneT
                enabled: !win.sceneEdit
                transform: Translate { x: -(sidebar.x + sidebar.width + win.s(40)) * win.sceneT }
                width: win.sideW
                height: win.sideH
                radius: ThemeBackend.clampedBorderRadius
                color: Qt.darker(ThemeBackend.surface0, 1.22)

                Column {
                    id: list
                    y: win.listTop
                    width: parent.width
                    spacing: win.listGap
                    Repeater {
                        // a fixed number of cells while dragging, so the module being held keeps its pointer grab
                        model: win.cellCount
                        Item {
                            id: cell
                            required property int index
                            readonly property string moduleId: PanelLayout.cells[index] || ""
                            readonly property bool held: moduleId !== "" && win.dragId === moduleId && win.dragFromSidebar
                            readonly property bool empty: moduleId === "" || held
                            readonly property var info: moduleId !== "" ? PanelLayout.modules[moduleId] : null
                            readonly property bool picked: moduleId !== "" && moduleId === win.styleModule
                            // the carried module is over this cell
                            readonly property bool over: win.overSidebar && ghost.cy - sidebar.y >= list.y + y - win.listGap / 2
                                                         && ghost.cy - sidebar.y < list.y + y + height + win.listGap / 2
                            onOverChanged: {
                                if (over) win.hoverCell = index;
                                else if (win.hoverCell === index) win.hoverCell = -1;
                            }
                            width: list.width
                            height: moduleId !== "" ? win.heightOf(moduleId) : win.gapH

                            // the white frame: around a module where the panel draws its highlight, or an empty cell
                            Rectangle {
                                x: win.s(6); y: -win.s(3)
                                width: parent.width - win.s(12); height: parent.height + win.s(6)
                                radius: ThemeBackend.clampedBorderRadius
                                color: cell.over && cell.empty ? Qt.alpha(ThemeBackend.subtext0, 0.2)
                                     : cell.picked ? Qt.alpha(ThemeBackend.mauve, 0.22)
                                     : (cellMa.containsMouse && !cell.empty ? Qt.alpha(ThemeBackend.text, win.starMode ? 0.12 : 0.05) : "transparent")
                                border.width: 1.5
                                border.color: "#ffffff"
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            // dropped on a module, the carried one goes in above it
                            Rectangle {
                                visible: cell.over && !cell.empty
                                x: win.s(10); y: -win.s(3) - win.listGap / 2 - height / 2
                                width: parent.width - win.s(20); height: win.s(3); radius: height / 2
                                color: ThemeBackend.mauve
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: cell.moduleId === "" && cell.index === PanelLayout.cells.indexOf("") && PanelLayout.order.length < PanelLayout.slotCount
                                text: "󰐕"
                                font.family: ThemeBackend.iconFont; font.pixelSize: win.s(16)
                                color: Qt.alpha("#ffffff", 0.6)
                            }
                            Loader {
                                id: face
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: win.faceSize
                                height: item ? item.implicitHeight : 0
                                enabled: false
                                active: cell.moduleId !== ""
                                opacity: cell.held ? 0 : 1
                                source: cell.info ? (cell.info.face || "SideIconFace.qml") : ""
                                onLoaded: {
                                    item.module = moduleHost;
                                    if (!cell.info.face) item.glyph = cell.info.icon;
                                }
                                onHeightChanged: if (cell.moduleId !== "" && height > 0) Qt.callLater(win.noteHeight, cell.moduleId, height)
                            }
                            Text {
                                visible: !cell.held && cell.moduleId !== "" && PanelLayout.star === cell.moduleId
                                anchors.right: parent.right; anchors.rightMargin: win.s(8)
                                anchors.top: parent.top; anchors.topMargin: -win.s(4)
                                text: "󰓎"; font.family: ThemeBackend.iconFont; font.pixelSize: win.s(11); color: ThemeBackend.mauve
                            }
                            MouseArea {
                                id: cellMa
                                anchors.fill: parent
                                anchors.margins: -win.s(3)
                                enabled: cell.moduleId !== ""
                                hoverEnabled: true
                                cursorShape: win.starMode ? Qt.PointingHandCursor : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                                property point pressAt
                                onPressed: mouse => {
                                    if (win.starMode) return;
                                    pressAt = Qt.point(mouse.x, mouse.y);
                                    Sounds.playSfx("guide/barconfig/out.wav");
                                }
                                onPositionChanged: mouse => {
                                    if (win.starMode || !pressed) return;
                                    if (win.dragId === "" && Math.hypot(mouse.x - pressAt.x, mouse.y - pressAt.y) < win.s(6)) return;
                                    ghost.follow(cellMa, mouse.x, mouse.y);
                                    if (win.dragId === "") win.pickUp(cell.moduleId, true);
                                }
                                onReleased: {
                                    if (win.starMode) return;
                                    if (win.dragId !== "") win.drop(); else Sounds.playSfx("guide/barconfig/in.wav");
                                }
                                onCanceled: { win.dragId = ""; win.hoverCell = -1; }
                                onClicked: {
                                    if (!win.starMode) return;
                                    Sounds.playSfx("reusables/clickbutton/click.wav");
                                    PanelLayout.toggleStar(cell.moduleId);
                                    win.starMode = false;
                                }
                            }
                        }
                    }
                }
            }

            // Style: a large live preview of one of the chosen module's styles in the middle of the right edge, the size two
            // of them would share the column at; the styles before and after it half show above and below it, smaller
            // and faint, and the wheel or a swipe over it brings the next one forward (as the sidebar steps)
            Item {
                id: previews
                visible: win.styleModule !== ""
                opacity: 1 - win.sceneT
                enabled: !win.sceneEdit
                // Weather's and Music's previews leave room for their pencils at the right
                anchors.right: parent.right
                anchors.rightMargin: ["weather", "music", "network"].indexOf(win.styleModule) >= 0 ? win.s(76) : win.s(40)
                anchors.top: parent.top; anchors.topMargin: win.s(28)
                width: win.s(win.designOf(win.styleModule).width) * k
                height: toolbar.y - win.s(28) - win.s(20)   // the toolbar is outside this item: no anchor
                readonly property var styles: win.styleModule !== "" ? PanelLayout.modules[win.styleModule].styles : []
                readonly property int count: 2
                // the one in front (it starts on the style in use), and where the stack is on its way to it
                property int at: 0
                property real pos: at
                property bool jump: false                         // a module just picked: no slide to its style
                Behavior on pos { enabled: !previews.jump; NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                readonly property real shrink: 0.22               // how much smaller the half-showing neighbours are
                Connections {
                    target: win
                    function onStyleModuleChanged() {
                        const i = previews.styles.findIndex(x => x.id === PanelLayout.style(win.styleModule));
                        previews.jump = true;
                        previews.at = Math.max(0, i);
                        previews.jump = false;
                    }
                }
                function step(dir) {
                    const next = Math.max(0, Math.min(styles.length - 1, at + dir));
                    if (next === at) return;
                    at = next;
                    Sounds.playSfx("guide/barconfig/out.wav", 0.4);
                }
                // the sidebar's way (BlankPanel's sideWheel): a wheel click is one step; a touchpad swipe counts once,
                // however long it runs
                property real wheelAcc: 0
                Timer { id: swipeIdle; property bool locked: false; interval: 220; onTriggered: { locked = false; previews.wheelAcc = 0; } }
                WheelHandler {
                    orientation: Qt.Vertical
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (e) => {
                        const d = e.angleDelta.y;
                        if (d === 0) return;
                        if (!swipeIdle.running && Math.abs(d) % 120 === 0) { previews.step(d < 0 ? 1 : -1); return; }
                        if (Math.abs(d) >= 120) return;
                        const locked = swipeIdle.locked;
                        swipeIdle.restart();
                        if (locked) return;
                        previews.wheelAcc += d;
                        if (Math.abs(previews.wheelAcc) < 120) return;
                        previews.step(previews.wheelAcc < 0 ? 1 : -1);
                        previews.wheelAcc = 0;
                        swipeIdle.locked = true;
                    }
                }
                readonly property real spacing: win.s(14)
                readonly property real label: win.s(26)
                readonly property size design: win.designOf(win.styleModule)
                // the previews' scale: all of them fit the column
                readonly property real k: (height - (count - 1) * spacing - label * count) / count / win.s(design.height)
                readonly property real cardH: win.s(design.height) * k + label

            Repeater {
                id: previewRep
                model: previews.styles
                Item {
                    id: preview
                    required property var modelData
                    required property int index
                    property alias card: frame
                    property bool holdDrawn: false     // kept drawn (still unseen) while the warning takes its picture
                    readonly property bool chosen: PanelLayout.style(win.styleModule) === modelData.id
                    readonly property real k: previews.k
                    // where it is: 0 in front, -1 just before it (half showing above), 1 just after (half showing below);
                    // further ones fade away
                    readonly property real rel: index - previews.pos
                    readonly property real near: Math.min(1, Math.abs(rel))
                    readonly property bool front: Math.abs(rel) < 0.5
                    readonly property real frameH: win.s(previews.design.height) * k
                    // a neighbour's middle sits on the front card's edge (below it, past the front's name)
                    readonly property real reach: rel > 0 ? frameH / 2 + previews.label : frameH / 2 + win.s(10)
                    z: -Math.abs(rel)
                    y: (previews.height - frameH) / 2 + Math.sign(rel) * (reach * near + win.s(40) * Math.max(0, Math.abs(rel) - 1))
                    width: win.s(previews.design.width) * k
                    height: previews.cardH
                    // slides in from the right edge, one after the other, each time a module is picked
                    property real enter: 0
                    opacity: enter * (1 - 0.65 * near) * Math.max(0, Math.min(1, 2 - Math.abs(rel)))
                    visible: opacity > 0.01 || holdDrawn
                    enabled: front
                    property real hoverK: pvMa.containsMouse ? 1.015 : 1
                    Behavior on hoverK { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: [
                        Scale { origin.x: preview.width / 2; origin.y: preview.frameH / 2
                                xScale: (1 - previews.shrink * preview.near) * preview.hoverK; yScale: xScale },
                        Translate { x: (1 - preview.enter) * win.s(60) }
                    ]
                    SequentialAnimation {
                        running: true
                        PauseAnimation { duration: 60 + preview.index * 90 }
                        NumberAnimation { target: preview; property: "enter"; to: 1; duration: 460; easing.type: Easing.OutCubic }
                    }
                    // a soft glow round the style in use
                    Rectangle {
                        anchors.fill: frame; anchors.margins: -win.s(6)
                        radius: ThemeBackend.clampedBorderRadius + win.s(6)
                        color: Qt.alpha(ThemeBackend.mauve, 0.14)
                        opacity: preview.chosen ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                    }
                    Rectangle {
                        id: frame
                        width: parent.width; height: win.s(previews.design.height) * preview.k
                        radius: ThemeBackend.clampedBorderRadius
                        color: ThemeBackend.base
                        border.width: preview.chosen ? 2 : (pvMa.containsMouse ? 1 : 0)
                        border.color: preview.chosen ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, 0.3)
                        clip: true
                        Loader {
                            width: win.s(previews.design.width); height: win.s(previews.design.height)
                            scale: preview.k
                            transformOrigin: Item.TopLeft
                            enabled: false
                            active: win.styleModule !== ""
                            readonly property Component style: ({ graphs: graphsPreview, rings: ringsPreview, hero: heroPreview, slide: slidePreview,
                                               classic: win.styleModule === "network" ? networkClassicPreview : weatherClassicPreview,
                                               dashboard: weatherDashboardPreview, smart: weatherSmartPreview,
                                               radar: networkRadarPreview, gargantua: networkGargantuaPreview,
                                               original: musicOriginalPreview, m3: musicM3Preview, m5: musicM5Preview,
                                               bubble: bubblePreview })[preview.modelData.id]
                            // every card is the style itself, moving; all of it goes when Edit panel closes
                            sourceComponent: style
                        }
                    }
                    // its name, under it while it is in front
                    Row {
                        anchors.top: frame.bottom; anchors.topMargin: win.s(6)
                        spacing: win.s(6)
                        opacity: preview.front ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Text { visible: preview.chosen; text: "󰄬"; font.family: ThemeBackend.iconFont; font.pixelSize: win.s(13); color: ThemeBackend.mauve }
                        Text { text: preview.modelData.name; font.family: ThemeBackend.fontFamily; font.pixelSize: win.s(12); font.bold: true
                               color: preview.chosen ? ThemeBackend.mauve : ThemeBackend.text }
                    }
                    // a click picks the style
                    MouseArea { id: pvMa; anchors.fill: frame; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Sounds.playSfx("reusables/clickbutton/click.wav");
                            win.pickStyle(win.styleModule, preview.modelData.id);
                        } }
                    // the pencil, right of the preview: the chosen Dashboard's opens the scene editor, each Music style's
                    // its own card
                    IconButton {
                        visible: preview.front && ((["dashboard", "smart", "gargantua"].indexOf(preview.modelData.id) >= 0 && preview.chosen)
                                                   || win.styleModule === "music")
                        x: frame.width + win.s(8)
                        y: 0
                        size: win.s(28)
                        cornerRadius: win.s(14)
                        buttonIcon: "\u{F03EB}"
                        iconFontSize: win.s(14)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        onClicked: win.openScene(frame, win.styleModule === "music" || preview.modelData.id !== "dashboard"
                                                       ? preview.modelData.id : "weather")
                    }
                }
            }
            }
        }

        // ---------- the style editor: its Smart bar at the top, the big preview in the middle below it ----------
        Item {
            id: sceneStage
            anchors.fill: parent
            visible: win.sceneEdit
            opacity: win.shown
            readonly property real barTop: win.s(28)
            readonly property real gap: win.s(22)
            readonly property real barH: sceneCard.visible ? sceneCard.implicitHeight : smartCard.visible ? smartCard.implicitHeight
                                       : gargantuaCard.visible ? gargantuaCard.implicitHeight : musicCard.implicitHeight
            readonly property real areaTop: barTop + barH + gap
            readonly property real k: Math.min(1.25, (width - win.s(96)) / win.s(win.sceneDesign.width), (height - areaTop - win.s(40)) / win.s(win.sceneDesign.height))
            readonly property real toW: win.s(win.sceneDesign.width) * k
            readonly property real toH: win.s(win.sceneDesign.height) * k
            readonly property real toX: (width - toW) / 2
            readonly property real toY: areaTop + Math.max(0, (height - areaTop - win.s(40) - toH) / 2)
            readonly property real cardIn: Math.max(0, Math.min(1, (win.sceneT - 0.45) / 0.55))

            // a click beside the preview and the card closes the editor
            MouseArea { anchors.fill: parent; onClicked: win.closeScene() }

            Rectangle {
                id: bigFrame
                x: win.sceneFrom.x + (sceneStage.toX - win.sceneFrom.x) * win.sceneT
                y: win.sceneFrom.y + (sceneStage.toY - win.sceneFrom.y) * win.sceneT
                width: win.sceneFrom.width + (sceneStage.toW - win.sceneFrom.width) * win.sceneT
                height: win.sceneFrom.height + (sceneStage.toH - win.sceneFrom.height) * win.sceneT
                radius: ThemeBackend.clampedBorderRadius
                color: ThemeBackend.base
                clip: true
                MouseArea { anchors.fill: parent }        // clicks on the preview stay in it
                Loader {
                    id: bigPage
                    width: win.s(win.sceneDesign.width); height: win.s(win.sceneDesign.height)
                    scale: bigFrame.width / win.s(win.sceneDesign.width)
                    transformOrigin: Item.TopLeft
                    active: win.sceneEdit
                    sourceComponent: win.sceneMusic ? bigMusic : win.sceneKind === "smart" ? bigSmart
                                   : win.sceneKind === "gargantua" ? bigGargantua : bigWeather
                }
                Component {
                    id: bigGargantua
                    Item {
                        Orbit.NetworkStyleShell {
                            style: "gargantua"
                            preview: true
                            width: 565; height: 525
                            scale: parent.width / 565
                            transformOrigin: Item.TopLeft
                        }
                    }
                }
                Component { id: bigWeather; WeatherPage { active: false; animate: true; dashboard: true; sceneTest: sceneCard.test } }
                Component {
                    id: bigSmart
                    SmartWeather.SmartWeatherPage {
                        running: true
                        cornerRadius: 0
                        hour: smartCard.testHour
                        liveTime: smartCard.liveTime
                        conditionOverride: smartCard.condition
                        windOverride: smartCard.wind
                        showArc: smartCard.arcOn
                        onActiveHourChanged: smartCard.liveHour = activeHour
                        onHourScrubbed: (h) => smartCard.setHour(h)
                        Connections { target: smartCard; function onConditionPicked() { bigPage.item.animateWeatherTransition(); } }
                    }
                }
                Component {
                    id: bigMusic
                    Media.MusicStylePreview { appearance: win.sceneKind; cover: PanelLayout.music[win.sceneKind + "Cover"] || "" }
                }
                // the border over the page, so its tiles do not hide it
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 2
                    border.color: ThemeBackend.mauve
                }
            }
            // its soft glow, as round the style in use
            Rectangle {
                anchors.fill: bigFrame; anchors.margins: -win.s(6)
                z: -1
                radius: ThemeBackend.clampedBorderRadius + win.s(6)
                color: Qt.alpha(ThemeBackend.mauve, 0.14)
            }

            // the bars come down from above once the preview is nearly in place
            SceneEditor {
                id: sceneCard
                visible: win.sceneKind === "weather"
                anchors.horizontalCenter: parent.horizontalCenter
                y: sceneStage.barTop - (1 - sceneStage.cardIn) * win.s(24)
                width: implicitWidth
                height: implicitHeight
                maxWidth: parent.width - win.s(48)
                opacity: sceneStage.cardIn
                enabled: win.sceneEdit && !sceneClose.running
                readonly property Item liveBox: bigPage.item && win.sceneKind === "weather" ? bigPage.item.box : null
                live: liveBox ? { hour: DateTime.now.getHours() + DateTime.now.getMinutes() / 60, dayOffset: liveBox.day,
                                  condition: liveBox.liveCondition, wind: Math.round(liveBox.liveWind) } : null
                onFinished: win.closeScene()
            }
            SmartWeatherEditor {
                id: smartCard
                visible: win.sceneKind === "smart"
                open: win.sceneEdit && visible
                anchors.horizontalCenter: parent.horizontalCenter
                y: sceneStage.barTop - (1 - sceneStage.cardIn) * win.s(24)
                width: implicitWidth
                height: implicitHeight
                maxWidth: parent.width - win.s(48)
                opacity: sceneStage.cardIn
                enabled: win.sceneEdit && !sceneClose.running
                onFinished: win.closeScene()
            }
            GargantuaEditor {
                id: gargantuaCard
                visible: win.sceneKind === "gargantua"
                anchors.horizontalCenter: parent.horizontalCenter
                y: sceneStage.barTop - (1 - sceneStage.cardIn) * win.s(24)
                width: implicitWidth
                height: implicitHeight
                maxWidth: parent.width - win.s(48)
                opacity: sceneStage.cardIn
                enabled: win.sceneEdit && !sceneClose.running
                onFinished: win.closeScene()
            }
            MusicStyleEditor {
                id: musicCard
                visible: win.sceneMusic
                styleId: win.sceneMusic ? win.sceneKind : "original"
                anchors.horizontalCenter: parent.horizontalCenter
                y: sceneStage.barTop - (1 - sceneStage.cardIn) * win.s(24)
                width: implicitWidth
                height: implicitHeight
                maxWidth: parent.width - win.s(48)
                opacity: sceneStage.cardIn
                enabled: win.sceneEdit && !sceneClose.running
                onFinished: win.closeScene()
            }
        }

        Text {
            id: warn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: toolbar.top; anchors.bottomMargin: win.s(14)
            opacity: warnTimer.running ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            font.family: ThemeBackend.fontFamily; font.pixelSize: win.s(13); font.bold: true
            color: ThemeBackend.red
            function show(msg) { text = msg; warnTimer.restart(); }
            Timer { id: warnTimer; interval: 1800 }
        }

        // The widget editor's toolbar, with Edit panel's own sections and the Star button.
        WidgetPicker {
            id: toolbar
            anchors.bottom: parent.bottom
            anchors.bottomMargin: win.s(24)
            anchors.horizontalCenter: parent.horizontalCenter
            maxWidth: parent.width - win.s(48)
            includeWidgets: false
            opacity: win.shown * (1 - win.sceneT)
            enabled: !win.sceneEdit
            leadingSections: [
                { id: "modules", name: "Modules", icon: "󰕰", keepEmpty: true, emptyText: "Every module is in the sidebar",
                  items: PanelLayout.stored.map(id => ({ id: id, name: PanelLayout.modules[id].name, icon: PanelLayout.modules[id].icon, draggable: true })) },
                { id: "style", name: "Style", icon: "󰏘",
                  items: Object.keys(PanelLayout.modules).filter(id => !!PanelLayout.modules[id].styles)
                             .map(id => ({ id: "style:" + id, name: id === "system" ? "System monitor" : PanelLayout.modules[id].name, icon: PanelLayout.modules[id].icon })) }
            ]
            onLeadingItemActivated: id => {
                const [what, moduleId] = id.split(":");
                if (what === "style") win.styleModule = win.styleModule === moduleId ? "" : moduleId;
            }
            // Modules tiles are picked up like the Available list's modules
            property point pressAt
            onLeadingItemPressed: (id, area, x, y) => { pressAt = Qt.point(x, y); Sounds.playSfx("guide/barconfig/out.wav"); }
            onLeadingItemMoved: (id, area, x, y) => {
                if (win.dragId === "" && Math.hypot(x - pressAt.x, y - pressAt.y) < win.s(6)) return;
                ghost.follow(area, x, y);
                if (win.dragId === "") win.pickUp(id, false);
            }
            onLeadingItemReleased: id => { if (win.dragId !== "") win.drop(); else if (id !== "") Sounds.playSfx("guide/barconfig/in.wav"); }

            IconButton {
                size: toolbar.controlHeight
                cornerRadius: ThemeBackend.borderRadius
                buttonIcon: "󰓎"
                iconFontSize: win.s(16)
                accentColor: win.starMode ? ThemeBackend.mauve : ThemeBackend.surface0
                textColor: win.starMode ? ThemeBackend.crust : ThemeBackend.text
                Layout.alignment: Qt.AlignVCenter
                onClicked: { toolbar.close(); win.starMode = !win.starMode; }
            }

            ClickButton {
                Layout.alignment: Qt.AlignVCenter
                maxWidth: win.s(100)
                implicitHeight: toolbar.controlHeight
                horizontalPadding: win.s(14)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: I18n.t("widgets.redactor.done")
                textFontSize: win.s(12)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: win.done()
            }
        }

        // The module being carried, drawn as the panel draws it, slightly lifted (like the Available list).
        Item {
            id: ghost
            visible: win.dragId !== ""
            width: win.sideW; height: ghostFace.height
            readonly property real cx: x + width / 2
            readonly property real cy: y + height / 2
            scale: 1.05
            opacity: 0.9
            function follow(area, mx, my) {
                const p = area.mapToItem(root, mx, my);
                x = p.x - width / 2; y = p.y - height / 2;
            }
            Rectangle {
                x: win.s(6); y: -win.s(6)
                width: parent.width - win.s(12); height: parent.height + win.s(12)
                radius: ThemeBackend.clampedBorderRadius
                color: Qt.darker(ThemeBackend.surface0, 1.22)
                border.width: 1.5; border.color: ThemeBackend.mauve
            }
            Loader {
                id: ghostFace
                anchors.horizontalCenter: parent.horizontalCenter
                width: win.faceSize
                height: item ? item.implicitHeight : 0
                enabled: false
                active: win.dragId !== ""
                readonly property var info: win.dragId !== "" ? PanelLayout.modules[win.dragId] : null
                source: info ? (info.face || "SideIconFace.qml") : ""
                onLoaded: {
                    item.module = moduleHost;
                    if (!info.face) item.glyph = info.icon;
                }
            }
        }

        // The star the pointer carries after Star is pressed.
        Text {
            visible: win.starMode && pointer.hovered
            x: pointer.point.position.x + win.s(10)
            y: pointer.point.position.y + win.s(8)
            text: "󰓎"
            font.family: ThemeBackend.iconFont; font.pixelSize: win.s(20)
            color: ThemeBackend.mauve
        }
    }

    QtObject {
        id: moduleHost
        property bool moduleActive: win.visible
        property bool isCompact: false
        property bool isRightBar: false
        property bool cloudOnly: true
        property var barWindow: ({ s: v => win.s(v), visible: win.visible, isStartupReady: true, isDataReady: true, startupCascadeFinished: true, screen: win.screen })
    }

    // ---------- live previews for Style (they never take input) ----------
    Pages.SystemFeed { id: previewFeed; active: win.styleModule === "system" }
    Pages.PowerActions { id: previewPower }
    Component { id: graphsPreview; Pages.SystemGraphs { feed: previewFeed } }
    Component { id: ringsPreview; Pages.SystemRings { feed: previewFeed } }
    Component { id: bubblePreview; Pages.BubbleMonitor { preview: true } }
    Component { id: heroPreview; Pages.UserHero { power: previewPower; screenName: PanelLayout.editScreen; uptimeText: win.uptimeText } }
    Component { id: weatherClassicPreview; WeatherPage { active: false } }
    Component { id: weatherDashboardPreview; WeatherPage { active: false; dashboard: true } }
    // the Network styles: Classic drawn still with made-up data, filling the card (it runs nothing, so the Gargantua
    // warning can take its picture at once); Radar and Gargantua as previews (they move, but do not scan and take no
    // input)
    Component {
        id: networkClassicPreview
        Item { Network.NetworkClassicPreview { scale: parent.width / 565; transformOrigin: Item.TopLeft } }
    }
    Component {
        id: networkRadarPreview
        Item { Orbit.NetworkStyleShell { style: "radar"; preview: true; width: 565; height: 525; scale: parent.width / 565; transformOrigin: Item.TopLeft } }
    }
    Component {
        id: networkGargantuaPreview
        Item { Orbit.NetworkStyleShell { style: "gargantua"; preview: true; width: 565; height: 525; scale: parent.width / 565; transformOrigin: Item.TopLeft } }
    }
    // Smart drawn still (its sky stopped), as the Dashboard preview is
    Component { id: weatherSmartPreview; SmartWeather.SmartWeatherPage { running: false; liveTime: true; cornerRadius: 0
                                                                          showArc: Config.getSetting("panel.smartWeather.arc", true) !== false } }
    // the Music styles drawn as Control's Theme → Music cards draw them, with the Anserin interface's covers
    Component { id: musicOriginalPreview; Media.MusicStylePreview { appearance: "original"; cover: PanelLayout.music.originalCover || "" } }
    Component { id: musicM3Preview; Media.MusicStylePreview { appearance: "m3"; cover: PanelLayout.music.m3Cover || "" } }
    Component { id: musicM5Preview; Media.MusicStylePreview { appearance: "m5" } }
    Component { id: slidePreview; Pages.UserSlide { power: previewPower; screenName: PanelLayout.editScreen; uptimeText: win.uptimeText } }
    property string uptimeText: ""
    FileView {
        path: "/proc/uptime"
        onLoaded: {
            const sec = Math.round(parseFloat(text().split(" ")[0]) || 0);
            const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
            win.uptimeText = d > 0 ? d + "d " + h + "h" : (h > 0 ? h + "h " + m + "m" : m + "m");
        }
    }

    WarningDialog {
        id: styleWarning
        anchors.fill: parent
        z: 1000
        behind: root
        onCancelled: if (win.styleWarn) PanelLayout.setStyle(win.styleWarn.module, win.styleWarn.prev)
        onClosed: { win.styleWarn = null; win.styleShots = []; root.forceActiveFocus(); }
    }
}
