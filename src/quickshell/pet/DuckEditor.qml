import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"
import "../blankpanel"
import "DuckColours.js" as DuckColours

// The duck editor. Over a dimmed screen: three small scenes to pick from (River, Grass, Waterfall), the duck large in
// the picked scene doing its things on the spot, and a frosted card (Edit panel's rows and buttons): Adjust saves at
// once (breed, colour, size, quack sound, call-back notice; the scene too), Test plays any action on the big duck.
// Done or Esc closes it.
// Opened from the desktop pet, it carries that duck in from where it stood (`handoff`: { x, y, size, snap, busy }):
// the duck rises and grows into the box while the rest gathers round it; a duck that was busy stays frozen mid-move
// until it lands, then finishes what it was doing. Closing plays the same in reverse (the editor comes apart piece by
// piece, then the duck, held still, flies back and shrinks onto its spot), then emits closed().
// The host gives it `settings` ({ breed, colour, size, sound, recall, scene }) and saves what `save(key, value)` asks.
// Sizes follow the shell's UI scale.
Item {
    id: editor
    property var settings: ({})
    property bool open: false
    property var handoff: null
    property string mode: "adjust"            // adjust, test
    signal save(string key, var value)
    signal finished()
    signal closed()
    signal quacked()
    signal tookDuck()

    readonly property string colour: settings.colour || "white"
    readonly property var variety: DuckColours.list.find(v => v.id === colour) || DuckColours.list[0]
    readonly property int duckSize: settings.size === 200 ? 200 : 128
    readonly property bool soundOn: settings.sound !== false
    readonly property bool recallOn: settings.recall !== false
    readonly property string scene: ["river", "grass", "falls"].indexOf(settings.scene) >= 0 ? settings.scene : "grass"
    readonly property real bigSize: Scaler.s(230)

    function clamp(v) { return Math.max(0, Math.min(1, v)); }
    function eased(v) { v = clamp(v); return 1 - Math.pow(1 - v, 3); }

    focus: open
    Keys.onEscapePressed: editor.finished()

    // ---------- the choreography ----------
    // appear: 0 → 1 builds the editor round the duck (and back to 0 to take it down); fly: 0 → 1 carries the duck
    property real appear: 0
    property real fly: 0
    property point from: Qt.point(0, 0)
    property real fromSize: 128
    property point to: Qt.point(0, 0)
    property bool landed: false

    // where the duck stands in the big scene, in this item
    function standPoint() {
        const p = stageScene.pos(stageScene.spot, stageScene.floor);
        return stageScene.mapToItem(editor, p.x, p.y);
    }
    property bool flyingIn: false
    function place() {
        // flying in, aim at the box where it is now: the layout can still be settling on the first frames
        if (flyingIn) to = standPoint();
        // the arc: up a little and over, growing on the way
        big.px = from.x + (to.x - from.x) * fly;
        big.py = from.y + (to.y - from.y) * fly - Math.sin(Math.PI * fly) * Scaler.s(70);
        big.size = fromSize + (bigSize - fromSize) * fly;
    }
    onFlyChanged: if (!landed) place()

    onOpenChanged: {
        if (open) {
            flyBack.stop();
            mode = "adjust";
            forceActiveFocus();
            Qt.callLater(start);
        } else {
            leave();
        }
    }
    Component.onCompleted: if (open) Qt.callLater(start)

    function start() {
        to = standPoint();
        flyingIn = true;
        landed = false;
        big.swimming = false;
        if (handoff) {
            from = Qt.point(handoff.x, handoff.y);
            fromSize = handoff.size;
            big.restore(handoff.snap);
            big.frozen = !!handoff.busy;
        } else {
            from = Qt.point(to.x, to.y + Scaler.s(40));
            fromSize = bigSize * 0.7;
        }
        fly = 0;
        place();
        big.visible = true;
        tookDuck();
        appearAnim.stop(); appearAnim.from = appear; appearAnim.to = 1; appearAnim.duration = 900; appearAnim.start();
        flyAnim.stop(); flyAnim.from = 0; flyAnim.to = 1; flyAnim.duration = handoff ? 700 : 420; flyAnim.easing.type = Easing.OutCubic; flyAnim.start();
    }
    function stageFloors(y) {
        return [{ x1: stageBox.mapToItem(editor, 0, 0).x, x2: stageBox.mapToItem(editor, stageBox.width, 0).x, y: y }];
    }
    function land() {
        flyingIn = false;
        to = standPoint();
        big.px = to.x;
        big.py = to.y;
        landed = true;
        big.frozen = false;
        big.floors = stageFloors(to.y);
        big.swimming = stageScene.water;
        // things that go somewhere make no sense in the box: those stop; the rest carry on to their end
        if (["walk", "peckAt", "peckAround", "drop", "held"].indexOf(big.action) >= 0) big.play("idle");
    }
    function leave() {
        // the opening backwards, with the same timing: the editor comes apart first (900 ms), and the duck, held
        // still, flies back for the last 700 ms, so both end together
        flyingIn = false;
        landed = false;
        big.frozen = true;
        to = Qt.point(big.px, big.py);
        if (handoff) { from = Qt.point(handoff.x, handoff.y); fromSize = handoff.size; }
        else { from = Qt.point(big.px, big.py + Scaler.s(40)); fromSize = bigSize * 0.7; }
        appearAnim.stop(); appearAnim.from = appear; appearAnim.to = 0; appearAnim.duration = 900; appearAnim.start();
        flyAnim.stop();
        flyAnim.from = 1; flyAnim.to = 0; flyAnim.duration = handoff ? 700 : 420; flyAnim.easing.type = Easing.InCubic;
        flyBack.interval = 900 - flyAnim.duration;
        flyBack.restart();
    }
    Timer { id: flyBack; onTriggered: { big.swimming = false; flyAnim.start(); } }
    NumberAnimation { id: appearAnim; target: editor; property: "appear" }
    NumberAnimation {
        id: flyAnim; target: editor; property: "fly"
        onFinished: {
            if (editor.open) editor.land();
            else { big.visible = false; editor.closed(); }
        }
    }
    // a new scene: the duck moves to its spot there (into the water or out of it) and drops in
    onSceneChanged: if (landed) Qt.callLater(moveToScene)
    function moveToScene() {
        to = standPoint();
        big.floors = stageFloors(to.y);
        big.swimming = stageScene.water;
        big.px = to.x;
        big.py = to.y - Scaler.s(30);
        big.play("drop");
    }

    // one reveal per piece: 0 → 1 as `appear` passes its turn
    function revealAt(turn, span) { return eased((appear - turn) / (span || 0.3)); }

    // ---------- the dim ----------
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.45 * editor.clamp(editor.appear * 3)
        MouseArea { anchors.fill: parent; enabled: editor.open }       // keeps clicks off what is underneath
    }

    Row {
        id: body
        anchors.centerIn: parent
        spacing: Scaler.s(18)

        // ---------- the scenes to choose from ----------
        Column {
            id: thumbs
            spacing: Scaler.s(12)
            anchors.verticalCenter: parent.verticalCenter
            Repeater {
                model: [{ id: "river", name: "River" }, { id: "grass", name: "Grass" }, { id: "falls", name: "Waterfall" }]
                Column {
                    id: thumb
                    required property var modelData
                    required property int index
                    readonly property bool picked: editor.scene === modelData.id
                    readonly property real shown: editor.revealAt(0.3 + index * 0.07)
                    spacing: Scaler.s(6)
                    opacity: shown
                    transform: Translate { x: -Scaler.s(24) * (1 - thumb.shown) }
                    Rectangle {
                        width: Scaler.s(150); height: Scaler.s(112)
                        radius: ThemeBackend.clampedBorderRadius
                        color: ThemeBackend.surface0
                        border.width: thumb.picked ? Scaler.s(2) : 1
                        border.color: thumb.picked ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, 0.12)
                        scale: thumbMouse.pressed ? 0.96 : thumbMouse.containsMouse ? 1.03 : 1
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Item {
                            anchors.fill: parent
                            anchors.margins: Scaler.s(3)
                            clip: true
                            DuckScene { id: thumbScene; anchors.fill: parent; kind: thumb.modelData.id; radius: Math.max(0, ThemeBackend.clampedBorderRadius - Scaler.s(3)); running: editor.open && editor.appear > 0.5 }
                            DuckActor {
                                readonly property point at: thumbScene.pos(thumbScene.spot, thumbScene.floor)
                                size: parent.height * 0.5
                                inPlace: true
                                random: true
                                quackInRandom: false
                                swimming: thumbScene.water
                                colour: editor.colour
                                visible: editor.open && editor.appear > 0.5
                                px: at.x; py: at.y
                                floors: [{ x1: 0, x2: parent.width, y: at.y }]
                            }
                        }
                        MouseArea {
                            id: thumbMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!thumb.picked) { Sounds.playSfx("reusables/clickbutton/click.wav"); editor.save("scene", thumb.modelData.id); }
                        }
                    }
                    Text {
                        text: thumb.modelData.name
                        color: thumb.picked ? ThemeBackend.mauve : ThemeBackend.subtext0
                        font { family: ThemeBackend.fontFamily; pixelSize: Scaler.s(11); bold: thumb.picked }
                    }
                }
            }
        }

        // ---------- the big scene; the duck stands in it (drawn above, so it can fly in) ----------
        Item {
            id: stageBox
            width: Scaler.s(560)
            height: card.height
            readonly property real shown: editor.revealAt(0.18, 0.4)
            opacity: shown
            scale: 0.9 + 0.1 * shown
            Rectangle {
                id: stage
                anchors.fill: parent
                radius: ThemeBackend.clampedBorderRadius
                color: ThemeBackend.surface0
                clip: true
                DuckScene { id: stageScene; anchors.fill: parent; kind: editor.scene; radius: ThemeBackend.clampedBorderRadius; running: editor.open && editor.appear > 0.2 }
                // a fine edge so the scene sits inside its frame
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: Scaler.s(1)
                    border.color: Qt.alpha(ThemeBackend.text, 0.12)
                }
            }
            Rectangle {
                visible: editor.mode === "test" && big.action !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Scaler.s(14)
                width: nowText.implicitWidth + Scaler.s(20); height: Scaler.s(24); radius: height / 2
                color: Qt.alpha(ThemeBackend.base, 0.7)
                Text { id: nowText; anchors.centerIn: parent; text: big.action; color: ThemeBackend.text; font { family: ThemeBackend.fontFamily; pixelSize: Scaler.s(11) } }
            }
        }

        // ---------- the card ----------
        Item {
            id: card
            width: Scaler.s(360)
            height: Math.max(Scaler.s(520), content.implicitHeight + Scaler.s(40))
            readonly property real shown: editor.revealAt(0.3, 0.35)
            opacity: shown
            transform: Translate { x: Scaler.s(30) * (1 - card.shown) }

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.clampedBorderRadius
                color: glass.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.22)
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.text, 0.08)
                WallpaperBlur { id: glass; anchors.fill: parent; radius: parent.radius; tintColor: Qt.darker(ThemeBackend.surface0, 1.22) }
            }

            ColumnLayout {
                id: content
                x: Scaler.s(20); y: Scaler.s(20)
                width: card.width - Scaler.s(40)
                spacing: Scaler.s(16)

                // the header: who it is
                RowLayout {
                    id: header
                    spacing: Scaler.s(12)
                    readonly property real shown: editor.revealAt(0.4)
                    opacity: shown
                    transform: Translate { y: Scaler.s(10) * (1 - header.shown) }
                    Rectangle {
                        Layout.preferredWidth: Scaler.s(40); Layout.preferredHeight: Scaler.s(40)
                        radius: ThemeBackend.clampedBorderRadius
                        color: Qt.alpha(ThemeBackend.mauve, 0.18)
                        Text { anchors.centerIn: parent; text: "\u{F03E9}"; color: ThemeBackend.mauve; font { family: ThemeBackend.iconFont; pixelSize: Scaler.s(20) } }
                    }
                    Text { text: "Duck"; color: ThemeBackend.text; font { family: ThemeBackend.fontFamily; pixelSize: Scaler.s(17); bold: true } }
                }

                // Adjust / Test: a pill slides between them
                Rectangle {
                    id: modes
                    Layout.fillWidth: true
                    Layout.preferredHeight: Scaler.s(36)
                    radius: height / 2
                    color: ThemeBackend.surface0
                    readonly property real shown: editor.revealAt(0.45)
                    opacity: shown
                    transform: Translate { y: Scaler.s(10) * (1 - modes.shown) }
                    Rectangle {
                        width: (parent.width - Scaler.s(6)) / 2; height: parent.height - Scaler.s(6)
                        y: Scaler.s(3)
                        x: Scaler.s(3) + (editor.mode === "test" ? width : 0)
                        radius: height / 2
                        color: ThemeBackend.mauve
                        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    }
                    Row {
                        anchors.fill: parent
                        Repeater {
                            model: [{ id: "adjust", name: "Adjust" }, { id: "test", name: "Test" }]
                            Item {
                                required property var modelData
                                width: modes.width / 2; height: modes.height
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: editor.mode === modelData.id ? ThemeBackend.crust : ThemeBackend.text
                                    font { family: ThemeBackend.fontFamily; pixelSize: Scaler.s(12); bold: true }
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (editor.mode !== modelData.id) {
                                        Sounds.playSfx("reusables/switch/sfx.wav");
                                        editor.mode = modelData.id;
                                        big.randomTest = false;
                                        big.play("idle");
                                    }
                                }
                            }
                        }
                    }
                }

                // ---------- Adjust: saved at once ----------
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: editor.mode === "adjust"
                    spacing: Scaler.s(16)
                    EditorChoices {
                        id: breedRow
                        Layout.fillWidth: true
                        name: "Breed"
                        current: "call"
                        options: [{ id: "call", name: "Call duck" }]
                        readonly property real shown: editor.revealAt(0.5)
                        opacity: shown
                        transform: Translate { y: Scaler.s(10) * (1 - breedRow.shown) }
                    }
                    Column {
                        id: colourRow
                        Layout.fillWidth: true
                        spacing: Scaler.s(8)
                        property string hovered: ""
                        readonly property real shown: editor.revealAt(0.55)
                        opacity: shown
                        transform: Translate { y: Scaler.s(10) * (1 - colourRow.shown) }
                        Text {
                            text: "Colour · " + (colourRow.hovered || editor.variety.name)
                            color: ThemeBackend.subtext0
                            font { family: ThemeBackend.fontFamily; pixelSize: Scaler.s(12); bold: true }
                        }
                        Flow {
                            width: parent.width; spacing: Scaler.s(7)
                            Repeater {
                                model: DuckColours.list
                                Rectangle {
                                    id: sw
                                    required property var modelData
                                    required property int index
                                    readonly property bool picked: modelData.id === editor.colour
                                    readonly property real pop: editor.revealAt(0.55 + index * 0.025, 0.2)
                                    width: Scaler.s(32); height: width; radius: width / 2
                                    color: modelData.swatch
                                    border.width: picked ? Scaler.s(3) : 1
                                    border.color: picked ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, 0.25)
                                    scale: (swMouse.pressed ? 0.9 : swMouse.containsMouse ? 1.1 : 1) * (0.6 + 0.4 * pop)
                                    Behavior on border.width { NumberAnimation { duration: 140 } }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: sw.picked
                                        text: "\u{F012C}"
                                        color: ["magpie", "bibbed", "mallard", "blueMallard"].indexOf(sw.modelData.id) >= 0 ? "#ffffff" : "#2a2a2a"
                                        font { family: ThemeBackend.iconFont; pixelSize: Scaler.s(14) }
                                    }
                                    MouseArea {
                                        id: swMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onContainsMouseChanged: colourRow.hovered = containsMouse ? sw.modelData.name : (colourRow.hovered === sw.modelData.name ? "" : colourRow.hovered)
                                        onClicked: if (!sw.picked) { Sounds.playSfx("reusables/clickbutton/click.wav"); editor.save("colour", sw.modelData.id); }
                                    }
                                }
                            }
                        }
                    }
                    EditorChoices {
                        id: sizeRow
                        Layout.fillWidth: true
                        name: "Size"
                        current: String(editor.duckSize)
                        options: [{ id: "128", name: "Real · 128" }, { id: "200", name: "Big · 200" }]
                        onChosen: (id) => editor.save("size", Number(id))
                        readonly property real shown: editor.revealAt(0.62)
                        opacity: shown
                        transform: Translate { y: Scaler.s(10) * (1 - sizeRow.shown) }
                    }
                    EditorChoices {
                        id: soundRow
                        Layout.fillWidth: true
                        name: "Quack sound"
                        current: editor.soundOn ? "on" : "off"
                        options: [{ id: "off", name: "Off" }, { id: "on", name: "On" }]
                        onChosen: (id) => editor.save("sound", id === "on")
                        readonly property real shown: editor.revealAt(0.67)
                        opacity: shown
                        transform: Translate { y: Scaler.s(10) * (1 - soundRow.shown) }
                    }
                    EditorChoices {
                        id: recallRow
                        Layout.fillWidth: true
                        name: "Call-back notice"
                        current: editor.recallOn ? "on" : "off"
                        options: [{ id: "off", name: "Off" }, { id: "on", name: "On" }]
                        onChosen: (id) => editor.save("recall", id === "on")
                        readonly property real shown: editor.revealAt(0.72)
                        opacity: shown
                        transform: Translate { y: Scaler.s(10) * (1 - recallRow.shown) }
                    }
                }

                // ---------- Test: the big duck only ----------
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: editor.mode === "test"
                    spacing: Scaler.s(16)
                    Column {
                        Layout.fillWidth: true
                        spacing: Scaler.s(8)
                        Text { text: "Actions"; color: ThemeBackend.subtext0; font { family: ThemeBackend.fontFamily; pixelSize: Scaler.s(12); bold: true } }
                        Flow {
                            width: parent.width; spacing: Scaler.s(6)
                            Repeater {
                                model: [
                                    { name: "Walk", act: "walk", o: { dur: 2.5 } }, { name: "Sit", act: "sit", o: { dur: 5 } },
                                    { name: "Preen breast", act: "preenBreast" }, { name: "Preen wing", act: "preenWing" },
                                    { name: "Peck", act: "peck" }, { name: "Peck around", act: "peckAround" },
                                    { name: "Peck ahead", act: "peckAt", rise: 0.55 }, { name: "Jump-peck", act: "peckAt", rise: 1.5 },
                                    { name: "Too high", act: "peckAt", rise: 2.6 }, { name: "Pet", act: "petted", o: { dur: 2.5 } },
                                    { name: "Held", act: "held" }, { name: "Drop", act: "drop" },
                                    { name: "Stretch", act: "stretch" }, { name: "Dive", act: "dive", water: true }, { name: "Quack", act: "quack" }
                                ]
                                ClickButton {
                                    required property var modelData
                                    readonly property bool picked: big.action === modelData.act && (modelData.rise === undefined || (big.act && big.act.o.rise === modelData.rise))
                                    visible: !modelData.water || big.swimming
                                    implicitHeight: Scaler.s(30)
                                    horizontalPadding: Scaler.s(12)
                                    cornerRadius: Scaler.s(15)
                                    buttonText: modelData.name
                                    textFontSize: Scaler.s(11.5)
                                    accentColor: picked ? ThemeBackend.mauve : ThemeBackend.surface0
                                    textColor: picked ? ThemeBackend.crust : ThemeBackend.text
                                    onClicked: {
                                        big.randomTest = false;
                                        const m = modelData;
                                        if (m.rise !== undefined) big.play(m.act, { x: big.px + big.facing * 0.62 * big.size, y: big.py - m.rise * big.size, rise: m.rise });
                                        else if (m.act === "held") { big.py = editor.to.y - 0.3 * big.size; big.play("held"); heldDrop.restart(); }
                                        else if (m.act === "drop") { big.py = editor.to.y - 0.9 * big.size; big.play("drop"); }
                                        else big.play(m.act, m.o ? Object.assign({}, m.o) : {});
                                    }
                                }
                            }
                        }
                    }
                    EditorChoices {
                        Layout.fillWidth: true
                        name: "Random"
                        current: big.randomTest ? "on" : "off"
                        options: [{ id: "off", name: "Off" }, { id: "on", name: "On" }]
                        onChosen: (id) => { big.randomTest = id === "on"; if (big.randomTest) big.next(); }
                    }
                    Timer { id: heldDrop; interval: 1600; onTriggered: if (big.action === "held") big.play("drop") }
                }

                Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }

                ClickButton {
                    Layout.alignment: Qt.AlignRight
                    implicitHeight: Scaler.s(34)
                    horizontalPadding: Scaler.s(18)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonText: I18n.t("widgets.redactor.done")
                    textFontSize: Scaler.s(12)
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.crust
                    opacity: editor.revealAt(0.75)
                    onClicked: editor.finished()
                }
            }
        }
    }

    // ---------- the duck: flies in from the desktop, then stays in the big scene ----------
    DuckActor {
        id: big
        visible: false
        inPlace: true
        random: editor.landed && (editor.mode === "adjust" || randomTest)
        property bool randomTest: false
        quackInRandom: true
        colour: editor.colour
        labelFont: ThemeBackend.fontFamily
        size: editor.bigSize
        onQuacked: editor.quacked()
    }
}
