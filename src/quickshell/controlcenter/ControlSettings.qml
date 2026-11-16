import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../guide/GuideTabs.js" as GuideTabs
import "./settings"
import "../reusables"

// The Settings window's pages inside the Control Center's Control tab. Categories and sub-categories
// come from the same list the Settings window uses (guide/GuideTabs.js), in the same order, and each
// page is the real Settings page (previews and options unchanged), hosted here at the panel's width.
// Navigation is two rows of chips: categories, then sub-categories when a category has them.
// Bar is replaced by Panel here (the Anserin interface has no Bar or Quick Actions): one page with the edge
// panels' auto-hide and the left edge panel's Workspace, Music, Time & Date and Network modules.
Item {
    id: root
    property bool active: true
    property int cat: 0
    property int sub: 0
    signal closeRequested()

    readonly property color ink: ThemeBackend.crust
    function s(v) { return Scaler.s(v); }

    // the Anserin interface: Panel in Bar's place, and no Theme → Music (its Music is set in Edit panel)
    readonly property var cats: GuideTabs.tabs.map(t => !AnserinMode.active ? t
        : t.id === "Bar" ? { id: "Panel", key: "panel", name: "Panel", icon: "󰕮", file: "bar/BarModulesTab.qml", panelPage: true }
        : t.id === "Theme" ? Object.assign({}, t, { subtabs: t.subtabs.filter(st => st.id !== "ThemeMusic") })
        : t)
    readonly property var curCat: cats[Math.min(cat, cats.length - 1)]
    readonly property bool hasSubs: !!curCat.subtabs && curCat.subtabs.length > 0
    readonly property var curSub: hasSubs ? curCat.subtabs[Math.min(sub, curCat.subtabs.length - 1)] : null
    // Theme set to the Orbit style: no sub-category tabs; sub pages get a "← Orbit" way back instead
    readonly property bool orbitMode: curCat.id === "Theme" && Config.getSetting("theme.generalLayout", "original") === "orbit"
    readonly property string pageId: curCat.id + (hasSubs ? "/" + curSub.id : "")
    onCatChanged: sub = 0

    // Lets a Settings page jump to another page by id (e.g. "ThemeStyle").
    function goto(name, subName) {
        for (let i = 0; i < cats.length; i++) {
            if (cats[i].id === name) { cat = i; sub = 0; return; }
            const subs = cats[i].subtabs || [];
            for (let j = 0; j < subs.length; j++) if (subs[j].id === name) { cat = i; sub = j; return; }
        }
    }

    // What the Settings pages expect from the Settings window they live in.
    Item {
        id: shim
        visible: root.active
        width: host.width
        height: host.height
        readonly property bool isGuidePopup: false
        readonly property bool compactSettings: true
        readonly property bool embedded: true
        readonly property bool anserinInterface: true   // Anserin interface only (not the Settings window / Quick Actions)
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
        function s(v) { return Scaler.s(v); }
        function gotoTab(name, subName) { root.goto(name, subName); }
        function closePopup() { root.closeRequested(); }
    }

    // Opens the category or sub-page named by a Settings window id/key ("Display", "theme_lockscreen", "bar"…)
    function gotoKey(k) {
        const want = String(k || "").toLowerCase().replace(/^guide\.tabs\./, "");
        if (want === "") return;
        const same = (t) => String(t.id).toLowerCase() === want || String(t.key).toLowerCase() === want;
        for (let i = 0; i < cats.length; i++) {
            const c = cats[i];
            if (same(c) || (c.panelPage && want === "bar")) { root.cat = i; root.sub = 0; return; }
            const subs = c.subtabs || [];
            for (let j = 0; j < subs.length; j++) if (same(subs[j])) { root.cat = i; root.sub = j; return; }
        }
    }

    function loadPage() {
        const file = hasSubs ? curSub.file : curCat.file;
        shim.currentTab = cat;
        shim.currentSubTab = hasSubs ? sub : 0;
        shim.expandedTab = hasSubs ? cat : -1;
        pageLoader.sourceComponent = null;
        const props = hasSubs ? { rootObj: shim, tabIndex: cat, subTabIndex: sub } : { rootObj: shim, tabIndex: cat };
        if (curCat.panelPage) Object.assign(props, {
            subTabIndex: 0,
            onlyModules: ["workspaces", "music", "timedate", "wifi"],
            sideOverride: { workspaces: true, music: true, timedate: false, wifi: true },
            headerSource: Qt.resolvedUrl("../guide/panel/PanelAutoHide.qml")
        });
        pageLoader.setSource(Qt.resolvedUrl("../guide/" + file), props);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.s(8)

        // ---------- category chips: four at a time, one scroll step turns the page ----------
        Item {
            id: chipBar
            objectName: "chip-bar"
            z: 5
            Layout.fillWidth: true
            Layout.preferredHeight: root.s(40)
            readonly property int perPage: 4
            readonly property real chipGap: root.s(4)
            readonly property real chipW: Math.max(1, (width - (perPage - 1) * chipGap) / perPage)
            readonly property real pageW: width + chipGap
            readonly property int pageCount: Math.max(1, Math.ceil(root.cats.length / perPage))
            readonly property real swipeGain: 1.5
            property int swipeDir: 0
            function scrolled(e, horizontal) {
                const x = e.angleDelta.x;
                const y = e.angleDelta.y;
                // an event with both axes reaches both handlers: only the stronger axis counts
                if (horizontal !== (Math.abs(x) >= Math.abs(y))) return;
                const d = horizontal ? x : y;
                if (d === 0) return;
                if (!swipeIdle.running && Math.abs(d) % 120 === 0) {
                    goPage((chipScroll.running ? Math.round(chipScroll.to / pageW) : shownPage) - Math.round(d / 120));
                    return;
                }
                if (Math.abs(d) >= 120) return;
                chipScroll.stop();
                swipeDir = d < 0 ? 1 : -1;
                chips.contentX = Math.max(0, Math.min((pageCount - 1) * pageW, chips.contentX - d / 8 * swipeGain));
                swipeIdle.restart();
            }
            function goPage(p) {
                p = Math.max(0, Math.min(pageCount - 1, p));
                chipScroll.stop();
                chipScroll.to = p * pageW;
                chipScroll.restart();
            }
            readonly property int shownPage: Math.max(0, Math.min(pageCount - 1, Math.round((chipScroll.running ? chipScroll.to : chips.contentX) / Math.max(1, pageW))))
            onWidthChanged: if (width > 0) chips.contentX = Math.floor(root.cat / perPage) * pageW
            NumberAnimation { id: chipScroll; target: chips; property: "contentX"; duration: 320; easing.type: Easing.OutCubic }
            Timer { id: swipeIdle; interval: 120; onTriggered: chipBar.goPage(Math.round(chips.contentX / chipBar.pageW + 0.4 * chipBar.swipeDir)) }
            ListView {
                id: chips
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: chipBar.chipGap
                clip: true
                interactive: false
                model: root.cats
                currentIndex: root.cat
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 320
                highlightMoveVelocity: -1
                highlight: Rectangle { radius: height / 2; color: ThemeBackend.mauve; width: chipBar.chipW }
                // the page holding the chosen category comes into view (e.g. when another page asks to jump to it)
                onCurrentIndexChanged: Qt.callLater(chipBar.goPage, Math.floor(currentIndex / chipBar.perPage))
                // Liquid Glass: a lens slides to the category under the pointer
                property Item hoverItem: null
                GlassLens {
                    id: chipLens
                    z: -0.5
                    follow: chips.hoverItem
                    radius: height / 2
                    tintColor: ThemeBackend.surface1
                    tintAmount: 0.25
                    shadow: 0
                    restPress: 0.2
                    magnify: root.s(3)
                    press: chips.hoverItem && chips.hoverItem.pressed ? 0.8 : 0
                }
                delegate: Item {
                    id: chipItem
                    required property var modelData
                    required property int index
                    readonly property bool cur: index === root.cat
                    readonly property bool pressed: chipMa.pressed
                    readonly property bool lensWanted: chipHover.hovered && !cur
                    onLensWantedChanged: {
                        if (lensWanted) chips.hoverItem = chipItem;
                        else if (chips.hoverItem === chipItem) chips.hoverItem = null;
                    }
                    Component.onDestruction: if (chips.hoverItem === chipItem) chips.hoverItem = null
                    height: ListView.view.height
                    width: chipBar.chipW
                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: root.s(7)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.icon
                            font.family: ThemeBackend.iconFont; font.pixelSize: root.s(16)
                            color: cur ? root.ink : (chipHover.hovered ? ThemeBackend.text : ThemeBackend.subtext0)
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, chipBar.chipW - root.s(16) - root.s(16) - root.s(7))
                            elide: Text.ElideRight
                            text: modelData.name
                            font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12)
                            font.weight: cur ? Font.Bold : Font.Medium
                            color: cur ? root.ink : (chipHover.hovered ? ThemeBackend.text : ThemeBackend.subtext0)
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                    }
                    HoverHandler { id: chipHover }
                    MouseArea { id: chipMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.cat !== index) Sounds.playSfx("reusables/switch/sfx.wav"); root.cat = index; } }
                }
            }
            // Touchpad: the chips follow the swipe and settle on a page when the fingers stop.
            // Mouse wheel: each click of the wheel turns one page of four at once.
            // Here both report a touchpad device with pixel deltas, so only angleDelta tells them apart:
            // a wheel click is one event of a whole multiple of 120, a swipe is a stream of small values.
            // Anything else that large is not a real movement (one arrives when a swipe ends) and is ignored.
            // A handler only starts on events along its own axis, so each axis has one.
            WheelHandler {
                orientation: Qt.Horizontal
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => chipBar.scrolled(e, true)
            }
            WheelHandler {
                orientation: Qt.Vertical
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => chipBar.scrolled(e, false)
            }
        }

        // ---------- sub-category tabs: open only when the category has any ----------
        Item {
            id: subRow
            Layout.fillWidth: true
            readonly property bool showTabs: root.hasSubs && !root.orbitMode
            readonly property bool showBack: root.hasSubs && root.orbitMode && root.sub !== 0
            Layout.preferredHeight: (showTabs || showBack) ? root.s(34) : 0
            clip: true
            opacity: (showTabs || showBack) ? 1 : 0
            Behavior on Layout.preferredHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.alpha(ThemeBackend.surface2, 0.5) }
            Rectangle {
                visible: subRow.showBack
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: backText.implicitWidth + root.s(24); height: root.s(26); radius: height / 2
                color: (tileGlass1.active ? "transparent" : backMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
                GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
                Behavior on color { ColorAnimation { duration: 150 } }
                Text { id: backText; anchors.centerIn: parent; text: "← Orbit"; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); font.weight: Font.Bold; color: ThemeBackend.text }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Sounds.playSfx("reusables/switch/sfx.wav"); root.sub = 0; } }
            }
            ListView {
                id: subTabs
                visible: subRow.showTabs
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: root.s(4)
                model: root.hasSubs ? root.curCat.subtabs : []
                currentIndex: root.sub
                interactive: false
                highlightMoveDuration: 280
                highlight: Item { Rectangle { anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width - root.s(20); height: root.s(3); radius: height / 2; color: ThemeBackend.mauve } }
                // Liquid Glass: a lens slides to the sub-tab under the pointer
                property Item hoverItem: null
                GlassLens {
                    id: subLens
                    z: -0.5
                    follow: subTabs.hoverItem
                    radius: ThemeBackend.clampedBorderRadius
                    tintColor: ThemeBackend.surface1
                    tintAmount: 0.25
                    shadow: 0
                    restPress: 0.2
                    magnify: root.s(3)
                    press: subTabs.hoverItem && subTabs.hoverItem.pressed ? 0.8 : 0
                }
                delegate: Item {
                    id: subItem
                    required property var modelData
                    required property int index
                    readonly property bool pressed: subMa.pressed
                    readonly property bool lensWanted: subHover.hovered && index !== root.sub
                    onLensWantedChanged: {
                        if (lensWanted) subTabs.hoverItem = subItem;
                        else if (subTabs.hoverItem === subItem) subTabs.hoverItem = null;
                    }
                    Component.onDestruction: if (subTabs.hoverItem === subItem) subTabs.hoverItem = null
                    HoverHandler { id: subHover }
                    height: ListView.view.height
                    width: sl.implicitWidth + root.s(24)
                    Text { id: sl; anchors.centerIn: parent; text: modelData.id === "ThemeGeneral" && Config.getSetting("theme.generalLayout", "original") !== "orbit" ? "General" : modelData.name; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(13)
                        font.weight: index === root.sub ? Font.Bold : Font.Medium; color: index === root.sub ? ThemeBackend.text : ThemeBackend.overlay1 }
                    MouseArea { id: subMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.sub !== index) Sounds.playSfx("reusables/switch/sfx.wav"); root.sub = index; } }
                }
            }
        }

        // ---------- the page ----------
        Item {
            id: host
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Item {
                id: holder
                readonly property bool ctlControls: true   // Settings controls inside use the Control tab's look
                anchors.fill: parent
                Loader { id: pageLoader; anchors.fill: parent; asynchronous: true }
            }
            SequentialAnimation {
                id: swap
                NumberAnimation { target: holder; property: "opacity"; to: 0; duration: 100 }
                ScriptAction { script: { root.loadPage(); holder.y = root.s(14); } }
                ParallelAnimation {
                    NumberAnimation { target: holder; property: "opacity"; to: 1; duration: 180 }
                    NumberAnimation { target: holder; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
                }
            }
            Connections { target: root; function onPageIdChanged() { swap.restart(); } }
            Component.onCompleted: root.loadPage()
        }
    }
}
