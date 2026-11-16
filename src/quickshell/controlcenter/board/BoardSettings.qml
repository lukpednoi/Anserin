import QtQuick
import Quickshell
import "../../"
import "../../guide/GuideTabs.js" as GuideTabs
import "../../reusables"

// The Control Center's Control tab.
// Across the top a dial of the Settings categories (wheel, drag or click; the one in the middle is chosen), the
// category's sub-pages as chips under it, and the page below, scrolling on its own. Pages ported to the board
// (pages/) draw their options as cards of cells; every other page (Wellbeing, Update) is its Settings page. Categories come from guide/GuideTabs.js.
Item {
    id: root
    property bool active: true
    signal closeRequested()
    function s(v) { return Scaler.s(v); }

    readonly property var cats: GuideTabs.tabs
    // pages drawn as boards; the rest are the real Settings pages
    readonly property var boardPages: ({ Welcome: "pages/WelcomePage.qml", General: "pages/GeneralPage.qml",
                                         ThemePet: "pages/PetPage.qml",
                                         ThemeStyle: "pages/StylePage.qml",
                                         ThemeLockscreen: "pages/LockscreenPage.qml",
                                         DisplayGeneral: "pages/DisplayPage.qml", DisplayPresets: "pages/PresetsPage.qml",
                                         ThemeGeneral: "pages/ThemePage.qml", Panel: "pages/PanelPage.qml",
                                         Apps: "pages/AppsPage.qml", Terminal: "pages/TerminalPage.qml",
                                         Alerts: "pages/AlertsPage.qml", Idle: "pages/IdlePage.qml" })
    // Theme's first page is the Orbit itself with the Orbit layout: shown as it is (a preview), not as a board
    // With the Orbit layout, the Orbit's General button opens the board's General page (orbitGeneral).
    function boardFor(id) {
        if (id === "ThemeGeneral" && orbitLayout && !orbitGeneral) return "";
        return boardPages[id] || "";
    }

    property int cat: 0
    property int sub: 0
    readonly property var curCat: cats[Math.min(cat, cats.length - 1)]
    readonly property bool hasSubs: !!curCat.subtabs && curCat.subtabs.length > 0
    readonly property var curSub: hasSubs ? curCat.subtabs[Math.min(sub, curCat.subtabs.length - 1)] : null
    readonly property string pageId: hasSubs ? curSub.id : curCat.id
    // Theme with the Orbit layout is navigated from the Orbit itself: no sub-page chips on the Orbit, and only a
    // "← Orbit" chip on the pages it opens (as in the Settings window).
    readonly property bool orbitLayout: Config.getSetting("theme.generalLayout", "original") === "orbit"
    readonly property bool orbitNav: curCat.id === "Theme" && orbitLayout
    property bool orbitGeneral: false
    onCatChanged: orbitGeneral = false
    onSubChanged: orbitGeneral = false
    readonly property string pageKey: pageId + (orbitGeneral ? "#general" : "")
    readonly property bool chipsShown: hasSubs && !(orbitNav && sub === 0 && !orbitGeneral)
    // one accent for every category, the theme's main colour (as the classic Control tab and the Settings rail),
    // so the board follows Matugen and the theme presets; Matugen's other slots are not the same colour family
    readonly property color accent: ThemeBackend.mauve

    // Lets a Settings page jump to another page by id (e.g. "ThemeStyle").
    function goto(name, subName) {
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === name) { open(i, 0); return; }
            const subs = cats[i].subtabs || [];
            for (let j = 0; j < subs.length; j++) if (subs[j].id === name) { open(i, j); return; }
        }
    }
    // Opens the category or sub-page named by a Settings window id/key ("Display", "theme_lockscreen", "bar"…)
    function gotoKey(k) {
        const want = String(k || "").toLowerCase().replace(/^guide\.tabs\./, "");
        if (want === "") return;
        const same = (t) => String(t.id).toLowerCase() === want || String(t.key).toLowerCase() === want;
        for (let i = 0; i < cats.length; i++) {
            const c = cats[i];
            if (same(c) || (c.panelPage && want === "bar")) { open(i, 0); return; }
            const subs = c.subtabs || [];
            for (let j = 0; j < subs.length; j++) if (same(subs[j])) { open(i, j); return; }
        }
    }
    property int dir: 0
    function open(c, s) {
        dir = c === cat ? (s > sub ? 1 : -1) : (c > cat ? 1 : -1);
        sub = s; cat = c;
        if (dial.currentIndex !== c) dial.currentIndex = c;
    }

    // What the Settings pages expect from the window they live in.
    Item {
        id: shim
        visible: root.active
        width: host.width
        height: host.height
        readonly property bool isGuidePopup: false
        readonly property bool compactSettings: true
        readonly property bool embedded: true
        readonly property bool anserinInterface: true
        readonly property bool carouselPreviews: true
        readonly property var appPaths: Caching
        readonly property var tabsModel: root.cats
        property int currentTab: 0
        property int currentSubTab: 0
        property int expandedTab: -1
        property var themeGeneralPage: null
        property bool orbitRequested: false
        readonly property bool orbitTheme: false
        property string highlightedSettingId: ""
        property int highlightToken: 0
        property int activationCounter: 0      // Welcome replays its logo when this changes (GuidePopup.qml)
        function s(v) { return Scaler.s(v); }
        function gotoTab(name, subName) { root.goto(name, subName); }
        function openGeneral() { root.dir = 1; root.orbitGeneral = true; }
        function closePopup() { root.closeRequested(); }
    }

    function loadPage() {
        shim.currentTab = cat;
        shim.currentSubTab = hasSubs ? sub : 0;
        shim.expandedTab = hasSubs ? cat : -1;
        pageLoader.sourceComponent = null;
        shim.activationCounter++;
        const board = boardFor(pageId);
        if (board) {
            pageLoader.setSource(Qt.resolvedUrl(board), { rootObj: shim, tabIndex: cat, accent: accent });
            return;
        }
        const file = hasSubs ? curSub.file : curCat.file;
        const props = hasSubs ? { rootObj: shim, tabIndex: cat, subTabIndex: sub } : { rootObj: shim, tabIndex: cat };
        if (curCat.panelPage) Object.assign(props, {
            subTabIndex: 0,
            onlyModules: ["workspaces", "music", "timedate", "wifi"],
            sideOverride: { workspaces: true, music: true, timedate: false, wifi: true },
            headerSource: Qt.resolvedUrl("../../guide/panel/PanelAutoHide.qml")
        });
        pageLoader.setSource(Qt.resolvedUrl("../../guide/" + file), props);
    }

    // ---------- dial ----------
    PathView {
        id: dial
        width: parent.width; height: 84
        model: root.cats
        pathItemCount: 7
        preferredHighlightBegin: 0.5; preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange
        snapMode: PathView.SnapToItem
        highlightMoveDuration: 380
        currentIndex: root.cat
        // Turning the dial with the wheel, a swipe or a drag is silent; clicking a category keeps the switch sound.
        onCurrentIndexChanged: if (currentIndex !== root.cat) {
            root.dir = currentIndex > root.cat ? 1 : -1; root.sub = 0; root.cat = currentIndex;
        }
        path: Path {
            startX: -20; startY: 58
            PathAttribute { name: "s"; value: 0.62 }
            PathAttribute { name: "o"; value: 0.25 }
            PathQuad { x: dial.width / 2; y: 28; controlX: dial.width / 4; controlY: 32 }
            PathAttribute { name: "s"; value: 1.0 }
            PathAttribute { name: "o"; value: 1.0 }
            PathQuad { x: dial.width + 20; y: 58; controlX: dial.width * 3 / 4; controlY: 32 }
            PathAttribute { name: "s"; value: 0.62 }
            PathAttribute { name: "o"; value: 0.25 }
        }
        delegate: Item {
            id: dItem
            required property var modelData
            required property int index
            readonly property bool on: PathView.isCurrentItem
            width: 56; height: 56
            scale: PathView.s ?? 1
            opacity: PathView.o ?? 1
            z: on ? 2 : 1
            Rectangle {
                anchors.centerIn: parent
                width: 46; height: 46; radius: 23
                color: dItem.on ? root.accent : (tileGlass1.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
                GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
                border.width: dItem.on ? 0 : 1; border.color: Qt.alpha(ThemeBackend.text, 0.08)
                Behavior on color { ColorAnimation { duration: 240 } }
                Text { anchors.centerIn: parent; text: dItem.modelData.icon; font.family: ThemeBackend.iconFont; font.pixelSize: 18
                       color: dItem.on ? ThemeBackend.crust : ThemeBackend.text }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (dItem.index !== dial.currentIndex) { Sounds.playSfx("reusables/switch/sfx.wav"); dial.currentIndex = dItem.index; } }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 66
            text: root.curCat.name; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; font.bold: true; color: root.accent
        }
        // Mouse wheel: one category per notch. Touchpad: swipes add up to a notch.
        property real acc: 0
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (e) => {
                const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y;
                dial.acc += d;
                if (Math.abs(dial.acc) >= 120) { if (dial.acc < 0) dial.incrementCurrentIndex(); else dial.decrementCurrentIndex(); dial.acc = 0; }
            }
        }
    }

    // ---------- sub-page chips ----------
    Item {
        id: chips
        y: dial.height + 2
        width: parent.width; height: root.chipsShown ? 36 : 0
        visible: root.chipsShown
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Rectangle {
            visible: root.orbitNav
            anchors.horizontalCenter: parent.horizontalCenter
            width: backLabel.implicitWidth + 30; height: 34; radius: 17
            color: backMa.containsMouse ? (tileGlass2.active ? "transparent" : ThemeBackend.surface0) : (tileGlass2.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
            GlassFill { id: tileGlass2; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
            Behavior on color { ColorAnimation { duration: 160 } }
            Text { id: backLabel; anchors.centerIn: parent; text: "← Orbit"; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.text }
            MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { Sounds.playSfx("reusables/switch/sfx.wav"); if (root.orbitGeneral) { root.dir = -1; root.orbitGeneral = false; } else root.open(root.cat, 0); } }
        }
        Rectangle {
            id: subRow
            visible: !root.orbitNav
            anchors.horizontalCenter: parent.horizontalCenter
            width: chipRow.implicitWidth + 8; height: 34; radius: 17
            color: (tileGlass3.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
            GlassFill { id: tileGlass3; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
            Rectangle {
                readonly property Item it: chipRep.count > root.sub ? chipRep.itemAt(root.sub) : null
                x: it ? chipRow.x + it.x : 0; width: it ? it.width : 0; y: 4; height: 26; radius: 13
                color: root.accent
                Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 240 } }
            }
            // Liquid Glass: a lens slides to the sub-category under the pointer
            property Item hoverItem: null
            GlassLens {
                id: chipLens
                follow: subRow.hoverItem
                radius: 13
                tintColor: ThemeBackend.surface1
                tintAmount: 0.25
                shadow: 0
                restPress: 0.2
                magnify: 3
                press: subRow.hoverItem && subRow.hoverItem.pressed ? 0.8 : 0
            }
            Row { id: chipRow; x: 4; anchors.verticalCenter: parent.verticalCenter
                Repeater { id: chipRep; model: root.hasSubs ? root.curCat.subtabs : []
                    Item { id: chipItem; required property var modelData; required property int index
                        readonly property bool pressed: chipMa.pressed
                        readonly property bool lensWanted: chipHover.hovered && index !== root.sub
                        onLensWantedChanged: {
                            if (lensWanted) subRow.hoverItem = chipItem;
                            else if (subRow.hoverItem === chipItem) subRow.hoverItem = null;
                        }
                        Component.onDestruction: if (subRow.hoverItem === chipItem) subRow.hoverItem = null
                        HoverHandler { id: chipHover }
                        width: cl.implicitWidth + 22; height: 26
                        Text { id: cl; anchors.centerIn: parent; text: modelData.id === "ThemeGeneral" && !root.orbitLayout ? "General" : modelData.name; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true
                               color: index === root.sub ? ThemeBackend.crust : ThemeBackend.text; Behavior on color { ColorAnimation { duration: 200 } } }
                        MouseArea { id: chipMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: if (index !== root.sub) { Sounds.playSfx("reusables/switch/sfx.wav"); root.open(root.cat, index); } } } } }
        }
    }

    // ---------- the page ----------
    Item {
        id: host
        y: chips.y + chips.height + (root.chipsShown ? 6 : 0)
        width: parent.width; height: parent.height - y
        clip: true
        Item {
            id: holder
            readonly property bool ctlControls: true   // Settings controls inside use the Control tab's look
            width: parent.width; height: parent.height
            Loader { id: pageLoader; anchors.fill: parent; asynchronous: true }
        }
        SequentialAnimation {
            id: swap
            ParallelAnimation {
                NumberAnimation { target: holder; property: "opacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
                NumberAnimation { target: holder; property: "x"; to: -24 * root.dir; duration: 100; easing.type: Easing.InQuad }
            }
            ScriptAction { script: { root.loadPage(); holder.x = 24 * root.dir; } }
            ParallelAnimation {
                NumberAnimation { target: holder; property: "opacity"; to: 1; duration: 220 }
                NumberAnimation { target: holder; property: "x"; to: 0; duration: 300; easing.type: Easing.OutCubic }
            }
        }
        Connections { target: root; function onPageKeyChanged() { swap.restart(); } }
        Component.onCompleted: root.loadPage()
    }
}
