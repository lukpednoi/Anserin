import QtQuick
import Quickshell
import "../../"
import "../../guide/GuideTabs.js" as GuideTabs

// Lightweight Smart Home Control tab shell: shared palette, SFX, category bar, toast, and lazy per-page hosting.
// Heavy page logic, pickers and previews live inside smart/pages/*.qml and are created only while that page is open.
Item {
    id: win
    property bool active: true
    signal closeRequested()

    // ---------- theme palette (live Matugen / presets) ----------
    readonly property string iconFont: ThemeBackend.iconFont
    readonly property string uiFont: ThemeBackend.fontFamily
    readonly property bool themeDark: (0.2126 * ThemeBackend.base.r + 0.7152 * ThemeBackend.base.g + 0.0722 * ThemeBackend.base.b) < 0.5
    readonly property bool darkMode: themeDark
    readonly property bool liquidGlass: ThemeBackend.liquidGlass
    readonly property real cornerRadius: Math.max(12, Math.min(24, ThemeBackend.borderRadius + 8))
    readonly property color cBase: ThemeBackend.base
    readonly property color cCard: ThemeBackend.mantle
    readonly property color cTile: ThemeBackend.surface0
    readonly property color cTileHov: ThemeBackend.surface1
    readonly property color cAccent: ThemeBackend.mauve
    readonly property color cAccent2: ThemeBackend.peach
    readonly property color cText: ThemeBackend.text
    readonly property color cSub: ThemeBackend.subtext0
    readonly property color cOnAccent: {
        const lum = 0.2126 * cAccent.r + 0.7152 * cAccent.g + 0.0722 * cAccent.b;
        return lum > 0.52 ? "#0b0e14" : "#ffffff";
    }
    readonly property string repoUrl: "file://" + (Quickshell.env("ANSERIN_DIR") || "").replace(/\/src\/?$/, "")
    readonly property string profileName: SystemInfo.username || ""
    readonly property bool orbitLayout: Config.getSetting("theme.generalLayout", "original") === "orbit"

    // ---------- sounds through Anserin's native Sounds engine ----------
    readonly property QtObject sfx: QtObject {
        property double lastTick: 0
        function playToggle(on) { Sounds.playSfx(on ? "reusables/switch/sfx.wav" : "reusables/toggle/sfx.wav"); }
        function playSwitch()   { Sounds.playSfx("reusables/iconbutton/click.wav"); }
        function playClick()    { Sounds.playSfx("reusables/clickbutton/click.wav"); }
        function playQuick()    { Sounds.playSfx("system/quick_click.wav"); }
        function playStepper()  { Sounds.playSfx("network/tick-1.wav"); }
        function playLock()     { Sounds.playSfx("reusables/draggable/lock.wav"); }
        function playTick() {
            const now = Date.now();
            if (now - lastTick < 44) return;
            lastTick = now;
            Sounds.playSfx("reusables/draggable/tick.wav");
        }
    }

    // ---------- categories (guide/GuideTabs.js; Wellbeing removed) ----------
    readonly property var categories: GuideTabs.tabs.map(t => ({
        id: t.id, name: t.name, icon: t.icon, iconOffsetX: t.iconOffsetX || 0,
        subtabs: (t.subtabs || []).map(st => ({
            id: st.id,
            name: st.id === "ThemeGeneral" ? (win.orbitLayout ? "Orbit" : "General") : st.name,
            icon: st.icon
        }))
    }))
    property int catIdx: 0
    property int subIdx: 0
    property int pageDir: 1
    property bool orbitInGeneral: false
    property bool shortcutListening: false

    readonly property var curCat: categories[Math.max(0, Math.min(catIdx, categories.length - 1))]
    readonly property string activePageId: (curCat.subtabs && curCat.subtabs.length > 0)
        ? curCat.subtabs[Math.max(0, Math.min(subIdx, curCat.subtabs.length - 1))].id
        : curCat.id
    readonly property bool showingRealOrbit: win.active && win.activePageId === "ThemeGeneral" && win.orbitLayout && !win.orbitInGeneral

    property int _modalsOpen: 0
    function modalOpened() {
        _modalsOpen++;
        if (typeof masterWindow !== "undefined" && masterWindow && masterWindow.openModalCount !== undefined) masterWindow.openModalCount++;
    }
    function modalClosed() {
        if (_modalsOpen <= 0) return;
        _modalsOpen--;
        if (typeof masterWindow !== "undefined" && masterWindow && masterWindow.openModalCount !== undefined) masterWindow.openModalCount = Math.max(0, masterWindow.openModalCount - 1);
    }
    Component.onDestruction: {
        if (_modalsOpen > 0 && typeof masterWindow !== "undefined" && masterWindow && masterWindow.openModalCount !== undefined) {
            masterWindow.openModalCount = Math.max(0, masterWindow.openModalCount - _modalsOpen);
        }
        _modalsOpen = 0;
    }

    // What Settings pages, pickers and Orbit expect from their host window
    readonly property Item shim: shimItem
    Item {
        id: shimItem
        visible: win.active
        width: win.width; height: win.height
        readonly property Item contentItem: (typeof masterWindow !== "undefined" && masterWindow && masterWindow.contentItem) ? masterWindow.contentItem : null
        readonly property bool isGuidePopup: false
        readonly property bool compactSettings: true
        readonly property bool embedded: true
        readonly property bool anserinInterface: true
        readonly property bool carouselPreviews: true
        readonly property var appPaths: Caching
        readonly property var tabsModel: win.categories
        property int currentTab: win.catIdx
        property int currentSubTab: win.subIdx
        property int expandedTab: -1
        property var themeGeneralPage: null
        property bool orbitRequested: false
        readonly property bool orbitTheme: false
        property string highlightedSettingId: ""
        property int highlightToken: 0
        property int activationCounter: 0
        function s(v) { return Scaler.s(v); }
        function gotoTab(name, subName) { win.gotoById(name); }
        function openGeneral() { win.pageDir = 1; win.orbitInGeneral = true; win.sfx.playSwitch(); }
        function closePopup() { win.closeRequested(); }
    }

    function gotoById(name) {
        for (let i = 0; i < categories.length; i++) {
            if (categories[i].id === name) { openPage(i, 0); return; }
            const subs = categories[i].subtabs || [];
            for (let j = 0; j < subs.length; j++) if (subs[j].id === name) { openPage(i, j); return; }
        }
    }

    function gotoKey(k) {
        let want = String(k || "").toLowerCase().replace(/^guide\.tabs\./, "");
        if (want === "") return;
        const aliases = { notifications: "alerts", osd: "alerts", lockscreen: "theme_lockscreen", dock: "apps", launcher: "apps", presets: "display_presets" };
        if (aliases[want]) want = aliases[want];
        const tabs = GuideTabs.tabs;
        const same = (t) => String(t.id).toLowerCase() === want || String(t.key).toLowerCase() === want;
        for (let i = 0; i < tabs.length; i++) {
            const c = tabs[i];
            if (same(c) || (c.panelPage && want === "bar")) { openPage(i, 0); return; }
            const subs = c.subtabs || [];
            for (let j = 0; j < subs.length; j++) if (same(subs[j])) { openPage(i, j); return; }
        }
    }

    function openPage(c, s) {
        if (c === catIdx && s === subIdx) return;
        pageDir = (c === catIdx ? s > subIdx : c > catIdx) ? 1 : -1;
        catIdx = c; subIdx = s; orbitInGeneral = false;
        pageFlick.jumpTop();
        pageSlideSp.snapAndGo(24 * pageDir, 0.0);
        pageOpSp.snapAndGo(0.0, 1.0);
    }

    function selectCategory(idx, fromClick) {
        if (idx === win.catIdx) return;
        win.pageDir = idx > win.catIdx ? 1 : -1;
        if (fromClick) win.sfx.playSwitch();
        else win.sfx.playTick();
        win.catIdx = idx;
        win.subIdx = 0;
        win.orbitInGeneral = false;
        pageFlick.jumpTop();
        pageSlideSp.snapAndGo(26 * win.pageDir, 0.0);
        pageOpSp.snapAndGo(0.0, 1.0);
    }

    function selectSub(idx) {
        if (idx === win.subIdx) {
            if (win.orbitLayout && idx === 0 && win.orbitInGeneral) {
                win.pageDir = -1;
                win.orbitInGeneral = false;
                win.sfx.playSwitch();
                pageFlick.jumpTop();
                pageSlideSp.snapAndGo(-20, 0.0);
                pageOpSp.snapAndGo(0.0, 1.0);
            }
            return;
        }
        win.pageDir = idx > win.subIdx ? 1 : -1;
        win.sfx.playSwitch();
        win.subIdx = idx;
        win.orbitInGeneral = false;
        pageFlick.jumpTop();
        pageSlideSp.snapAndGo(20 * win.pageDir, 0.0);
        pageOpSp.snapAndGo(0.0, 1.0);
    }

    function scrollToTop() { pageFlick.jumpTop(); }

    // Toast feedback
    property string toastText: ""
    function showToast(msg) {
        toastText = msg;
        toastSp.target = 1.0;
        toastTimer.restart();
    }
    Timer { id: toastTimer; interval: 2200; onTriggered: toastSp.target = 0.0 }
    SpringVal { id: toastSp; target: 0.0; stiffness: 360; damping: 0.62; eps: 0.005 }

    // Page swap animation springs
    SpringVal { id: pageSlideSp; target: 0.0; stiffness: 300; damping: 0.64; eps: 0.2 }
    SpringVal { id: pageOpSp; target: 1.0; stiffness: 360; damping: 0.85; eps: 0.005 }

    // Soft ambient accent wash behind the page (pure GPU, zero Canvas FBO, zero hard circle edges)
    Rectangle {
        anchors.fill: parent
        opacity: win.darkMode ? (win.liquidGlass ? 0.10 : 0.07) : 0.06
        gradient: Gradient {
            GradientStop { position: 0.0; color: win.cAccent }
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1.0; color: win.cAccent2 }
        }
    }

    // ---- 1. Category Bar (top-most, no header above it) ----
    SmartCategoryBar {
        id: catBar
        anchors.top: parent.top; anchors.topMargin: 14
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: 14; anchors.rightMargin: 14
        categories: win.categories
        currentIndex: win.catIdx
        subIndex: win.subIdx
        darkMode: win.darkMode
        liquidGlass: win.liquidGlass
        surface: win.cCard
        surfaceHover: win.cTileHov
        accent: win.cAccent
        accent2: win.cAccent2
        inkAccent: win.cOnAccent
        textColor: win.cText
        subColor: win.cSub
        uiFont: win.uiFont
        iconFont: win.iconFont
        onCategoryPicked: (i, fromClick) => win.selectCategory(i, fromClick)
        onSubPicked: (i) => win.selectSub(i)
    }

    // ---- 2A. Real Orbit Hub (loaded directly when Theme layout === Orbit) ----
    Item {
        id: orbitHost
        visible: win.showingRealOrbit
        anchors.top: catBar.bottom; anchors.topMargin: 8
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.bottomMargin: 10
        clip: true
        opacity: Math.max(0, Math.min(1, pageOpSp.value))
        transform: Translate { x: pageSlideSp.value }

        function syncOrbit() {
            if (!win.showingRealOrbit) {
                orbitLoader.source = "";
                return;
            }
            orbitLoader.setSource(Qt.resolvedUrl("../../guide/theme/ThemeTab.qml"), {
                rootObj: win.shim,
                tabIndex: win.catIdx,
                subTabIndex: 0
            });
        }
        Connections {
            target: win
            function onShowingRealOrbitChanged() { orbitHost.syncOrbit(); }
        }
        Component.onCompleted: syncOrbit()

        Loader {
            id: orbitLoader
            anchors.fill: parent
            asynchronous: true
        }
    }

    // ---- 2B. Scrollable page body (lazy-loads ONLY the active page) ----
    BouncyFlickable {
        id: pageFlick
        visible: !win.showingRealOrbit
        anchors.top: catBar.bottom; anchors.topMargin: 10
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.bottomMargin: 14
        contentWidth: width
        contentHeight: pagesHost.implicitHeight + 18

        SmartPages {
            id: pagesHost
            app: win
            active: win.active && !win.showingRealOrbit
            pageId: win.activePageId
            width: pageFlick.width
            opacity: Math.max(0, Math.min(1, pageOpSp.value))
            transform: Translate { x: pageSlideSp.value }
        }
    }

    // Floating toast pill
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        height: 32; width: toastLabel.implicitWidth + 26; radius: 16
        visible: toastSp.value > 0.02
        opacity: Math.max(0, Math.min(1, toastSp.value))
        transform: Translate { y: (1.0 - toastSp.value) * 16 }
        color: win.cAccent
        Text { id: toastLabel; anchors.centerIn: parent; text: win.toastText; font.family: win.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold; color: win.cOnAccent }
    }

    Shortcut { enabled: win.active && !win.shortcutListening; sequence: "Right"; onActivated: win.selectCategory((win.catIdx + 1) % win.categories.length, true) }
    Shortcut { enabled: win.active && !win.shortcutListening; sequence: "Left";  onActivated: win.selectCategory((win.catIdx - 1 + win.categories.length) % win.categories.length, true) }
}
