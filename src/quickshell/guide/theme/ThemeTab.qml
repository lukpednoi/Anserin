import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"
import "../../reusables/guide"
import "../../wallpaper" as WallpaperUi

Item {
    id: themeTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 0

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: themeTabRoot.slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    // the page's logic lives in ThemeLogic.qml (shared with the Control Center's board); the names below keep
    // the page reading it as before
    ThemeLogic {
        id: logic
        rootObj: themeTabRoot.rootObj
        onFontInstalled: fontPickerPopup.close()
    }
    property alias themeSettings: logic.themeSettings
    property alias currentFontFamily: logic.currentFontFamily
    property alias currentBorderRadius: logic.currentBorderRadius
    property alias currentPreset: logic.currentPreset
    property alias currentWallpaperDir: logic.currentWallpaperDir
    property alias availableWallpaperDirs: logic.availableWallpaperDirs
    property alias availableFonts: logic.availableFonts
    property alias themeSearchText: logic.themeSearchText
    property alias filteredUserPresets: logic.filteredUserPresets
    property alias filteredSystemPresets: logic.filteredSystemPresets
    property alias currentWallpaperPath: logic.currentWallpaperPath
    property alias wallpaperRevision: logic.wallpaperRevision
    readonly property alias orbitWallpaperPath: logic.orbitWallpaperPath
    property alias isWallpaperVideo: logic.isWallpaperVideo
    function loadAvailableFonts() { return logic.loadAvailableFonts(); }
    function getSnappedRadius(rawVal) { return logic.getSnappedRadius(rawVal); }
    function activateTab() { return logic.activateTab(); }
    function getCardBase(m) { return logic.getCardBase(m); }
    function getCardText(m) { return logic.getCardText(m); }
    function getCardDots(m) { return logic.getCardDots(m); }
    function saveCustomTheme(themeObj) { return logic.saveCustomTheme(themeObj); }
    function deleteCustomTheme(themeName) { return logic.deleteCustomTheme(themeName); }
    function updateWallpaperDirSetting() { return logic.updateWallpaperDirSetting(); }
    function updateFontSetting() { return logic.updateFontSetting(); }
    function updateBorderRadiusSetting() { return logic.updateBorderRadiusSetting(); }
    function applyPreset(modelData) { return logic.applyPreset(modelData); }
    function installFont(filePath, fileName) { return logic.installFont(filePath, fileName); }

    readonly property bool orbit: themeSettings.generalLayout === "orbit" || rootObj.orbitRequested === true
    readonly property string orbitConnectionStyle: themeSettings.orbitConnectionStyle === "wifi" ? "wifi" : "link"
    readonly property string orbitImageStyle: ["rectangle", "circle", "bordered"].indexOf(themeSettings.orbitImageStyle) >= 0 ? themeSettings.orbitImageStyle : "rectangle"
    readonly property color orbitActiveColor: Qt.lighter(ThemeBackend.sapphire, 1.15)
    readonly property color orbitBorderColor: themeSettings.orbitBorderColor === "white" ? "#ffffff" : orbitActiveColor
    property int orbitTool: -1
    property bool wallpaperApplyPending: false
    readonly property bool orbitOverview: orbit && orbitTool < 0
    property real orbitPageOpacity: 1
    property real orbitPageSlide: 0
    function playOrbitPageEnter() {
        if (orbit && visible && orbitPageEnter) orbitPageEnter.restart();
    }
    ParallelAnimation {
        id: orbitPageEnter
        objectName: "theme-orbit-page-enter"
        NumberAnimation { target: themeTabRoot; property: "orbitPageOpacity"; from: 0; to: 1; duration: 250 }
        NumberAnimation { target: themeTabRoot; property: "orbitPageSlide"; from: rootObj.s(10); to: 0; duration: 250; easing.type: Easing.OutQuart }
    }
    onOrbitChanged: {
        orbitTool = -1;
        if (themeFlick) themeFlick.contentY = 0;
        if (orbit) playOrbitPageEnter();
        else if (orbitPageEnter) orbitPageEnter.stop();
    }
    onOrbitToolChanged: {
        if (themeFlick) themeFlick.contentY = 0;
        if (fontDropdown && fontDropdown.isOpen) fontDropdown.closePopup();
        if (wpDirDropdown && wpDirDropdown.isOpen) wpDirDropdown.closePopup();
        playOrbitPageEnter();
    }
    function revealOrbitSetting() {
        let tools = {wallpaper: 0, wallpaper_preview: 0, wallpaper_dir: 1, font: 1, border_radius: 1, colors: 1};
        let tool = tools[themeTabRoot.rootObj.highlightedSettingId];
        if (orbit && tool !== undefined) orbitTool = tool;
    }
    Connections {
        target: themeTabRoot.rootObj
        function onHighlightedSettingIdChanged() { themeTabRoot.revealOrbitSetting(); }
    }









    property real gridAvailableWidth: Math.max(0, settingsCol.width - rootObj.s(24))
    property real tileWidth: Math.max(rootObj.s(80), (gridAvailableWidth - 2 * rootObj.s(10)) / 3)










    onVisibleChanged: {
        if (visible) {
            if (orbit) {
                orbitTool = -1;
                if (themeFlick) themeFlick.contentY = 0;
                revealOrbitSetting();
            }
            playOrbitPageEnter();
            activateTab();
        } else {
            orbitPageEnter.stop();
            logic.activateDebounceTimer.stop();
            if (fontDropdown.isOpen) fontDropdown.closePopup();
            if (wpDirDropdown.isOpen) wpDirDropdown.closePopup();
            themeEditorPopup.close();
        }
    }







    Component.onCompleted: {
        if (rootObj.isGuidePopup === true) rootObj.themeGeneralPage = themeTabRoot;
        themeTabRoot.loadAvailableFonts();
        if (visible) {
            playOrbitPageEnter();
            activateTab();
        }
    }

    Component.onDestruction: {
        if (rootObj && rootObj.themeGeneralPage === themeTabRoot) rootObj.themeGeneralPage = null;
    }








    ThemeEditor {
        id: themeEditorPopup
        objectName: "theme-preset-editor"
        rootObj: themeTabRoot.rootObj
        tileWidth: themeTabRoot.tileWidth
        onSaveRequested: function(themeObj) {
            themeTabRoot.saveCustomTheme(themeObj);
            themeTabRoot.applyPreset(themeObj);
        }
    }






    FontPicker {
        id: fontPickerPopup
        objectName: "theme-font-picker"
        rootObj: themeTabRoot.rootObj
        onFontSelected: function(filePath, fileName) {
            if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") {
                themeTabRoot.installFont(filePath, fileName);
            }
        }
    }

    Flickable {
        id: themeFlick
        objectName: "theme-general-scroll"
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: settingsCol.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            objectName: "theme-orbit-page-content"
            opacity: themeTabRoot.orbit ? themeTabRoot.orbitPageOpacity : 1
            transform: Translate { y: themeTabRoot.orbit ? themeTabRoot.orbitPageSlide : 0 }
            x: rootObj.s(6)
            width: parent.width - rootObj.s(12)
            spacing: rootObj.s(6)

            RowLayout {
                objectName: "theme-orbit-tool-header"
                visible: themeTabRoot.orbit && !themeTabRoot.orbitOverview
                Layout.fillWidth: true
                Layout.bottomMargin: rootObj.s(12)
                spacing: rootObj.s(12)
                ClickButton {
                    objectName: "theme-orbit-back"
                    buttonText: "Back"
                    buttonIcon: "󰁍"
                    textFontSize: rootObj.s(12)
                    cornerRadius: ThemeBackend.clampedBorderRadius
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: themeTabRoot.orbitTool = -1
                }
                Text {
                    Layout.fillWidth: true
                    // General opens without a heading; Wallpaper keeps its own
                    text: ["Wallpaper", ""][themeTabRoot.orbitTool] || ""
                    color: ThemeBackend.text
                    font { family: ThemeBackend.fontFamily; pixelSize: rootObj.s(16); bold: true }
                }
            }
            Item {
                id: wpPreviewContainer
                objectName: "theme-wallpaper-preview"
                // the theme picture only belongs to the Orbit overview; the Original layout has none
                visible: themeTabRoot.orbit && themeTabRoot.orbitOverview
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.preferredHeight: themeTabRoot.orbit ? Math.max(rootObj.s(340), themeFlick.height - rootObj.s(10)) : rootObj.s(220)
                Layout.topMargin: rootObj.s(6)
                Layout.bottomMargin: rootObj.s(4)

                property real highlightFlash: 0.0
                property int handledHighlightToken: -1
                readonly property real toolWidth: Math.min(rootObj.s(144), width * .24)
                readonly property real toolHeight: rootObj.s(41)
                readonly property real toolGap: rootObj.s(44)
                property real hoverScale: orbitMouse.containsMouse ? 1.04 : 1
                property real bumpScale: 1
                property real clickFlash: 0
                Behavior on hoverScale {
                    enabled: themeTabRoot.visible && themeTabRoot.orbitOverview
                    NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
                }
                SequentialAnimation {
                    id: wallpaperClick
                    objectName: "theme-orbit-wallpaper-click"
                    NumberAnimation { target: wpPreviewContainer; property: "bumpScale"; from: 1; to: 1.15; duration: 200; easing.type: Easing.OutBack }
                    ScriptAction { script: { if (themeTabRoot.visible && themeTabRoot.orbitOverview) themeTabRoot.orbitTool = 0; } }
                }
                NumberAnimation {
                    id: wallpaperFlash
                    target: wpPreviewContainer; property: "clickFlash"
                    from: .6; to: 0; duration: 500; easing.type: Easing.OutExpo
                }

                function resolveTabInfo() {
                    let p = wpPreviewContainer.parent;
                    let targetTabIdx = -1;
                    let targetSubTabIdx = -1;
                    while (p) {
                        if (targetSubTabIdx === -1 && p.subTabIndex !== undefined) targetSubTabIdx = p.subTabIndex;
                        if (targetTabIdx === -1 && p.tabIndex !== undefined) targetTabIdx = p.tabIndex;
                        p = p.parent;
                    }
                    let r = themeTabRoot.rootObj;
                    let tab = "";
                    let subtab = "";
                    if (r && r.tabsModel && targetTabIdx >= 0 && targetTabIdx < r.tabsModel.length) {
                        let tModel = r.tabsModel[targetTabIdx];
                        tab = tModel.key || tModel.id || "";
                        if (tModel.subtabs && targetSubTabIdx >= 0 && targetSubTabIdx < tModel.subtabs.length) {
                            subtab = tModel.subtabs[targetSubTabIdx].key || tModel.subtabs[targetSubTabIdx].id || "";
                        }
                    }
                    return { tab: tab, subtab: subtab };
                }

                function registerWithSearch() {
                    let r = themeTabRoot.rootObj;
                    if (!r || typeof r.registerSearchItem !== "function") return;
                    let info = resolveTabInfo();
                    r.registerSearchItem({
                        id: "wallpaper",
                        title: I18n.t("guide.theme.wallpaper.select") || "Wallpaper",
                        desc: I18n.t("guide.theme.wallpaper.desc") || "Select and preview current wallpaper",
                        description: I18n.t("guide.theme.wallpaper.desc") || "Select and preview current wallpaper",
                        tab: info.tab,
                        subtab: info.subtab,
                        icon: "󰸉",
                        keywords: "wallpaper background image video select screen current desktop",
                        target: wallpaperDirRow,
                        unavailable: false
                    });
                }

                function unregisterFromSearch() {
                    let r = themeTabRoot.rootObj;
                    if (!r || typeof r.unregisterSearchItem !== "function") return;
                    r.unregisterSearchItem("wallpaper");
                }

                function ensureVisibleInFlickable() {
                    let p = wpPreviewContainer.parent;
                    let flick = null;
                    while (p) {
                        if (p.contentY !== undefined && p.contentHeight !== undefined) {
                            flick = p;
                            break;
                        }
                        p = p.parent;
                    }
                    if (flick) {
                        let targetPos = wpPreviewContainer.mapToItem(flick.contentItem, 0, 0);
                        if (targetPos) {
                            let viewTop = flick.contentY;
                            let viewBottom = flick.contentY + flick.height;
                            if (targetPos.y < viewTop || targetPos.y + wpPreviewContainer.height > viewBottom) {
                                flick.contentY = Math.max(0, Math.min(targetPos.y - flick.height / 2 + wpPreviewContainer.height / 2, flick.contentHeight - flick.height));
                            }
                        }
                    }
                }

                function triggerHighlightAnimation() {
                    highlightAnimation.restart();
                    wpPreviewContainer.ensureVisibleInFlickable();
                    ensureVisibleTimer.restart();
                }

                function checkHighlight() {
                    let r = themeTabRoot.rootObj;
                    if (!r) return;
                    if (r.highlightToken === wpPreviewContainer.handledHighlightToken) return;
                    if (r.highlightedSettingId && (r.highlightedSettingId === "wallpaper" || r.highlightedSettingId === "wallpaper_preview")) {
                        wpPreviewContainer.handledHighlightToken = r.highlightToken;
                        r.highlightedSettingId = "";
                        if (themeTabRoot.orbit) {
                            themeTabRoot.orbitTool = 0;
                        } else highlightDelayTimer.restart();
                    }
                }

                Connections {
                    target: themeTabRoot.rootObj
                    ignoreUnknownSignals: true
                    function onHighlightTokenChanged() {
                        wpPreviewContainer.checkHighlight();
                    }
                }

                onVisibleChanged: {
                    searchRegTimer.restart();
                    if (visible) {
                        wpPreviewContainer.checkHighlight();
                    } else {
                        wallpaperClick.stop();
                        wallpaperFlash.stop();
                        bumpScale = 1;
                        clickFlash = 0;
                    }
                }

                Timer {
                    id: searchRegTimer
                    interval: 10
                    repeat: false
                    onTriggered: wpPreviewContainer.registerWithSearch()
                }

                Timer {
                    id: ensureVisibleTimer
                    interval: 320
                    repeat: false
                    onTriggered: wpPreviewContainer.ensureVisibleInFlickable()
                }

                Timer {
                    id: highlightDelayTimer
                    interval: 80
                    repeat: false
                    onTriggered: wpPreviewContainer.triggerHighlightAnimation()
                }

                SequentialAnimation {
                    id: highlightAnimation
                    PropertyAction { target: wpPreviewContainer; property: "highlightFlash"; value: 0.0 }
                    NumberAnimation { target: wpPreviewContainer; property: "highlightFlash"; from: 0.0; to: 1.0; duration: 400; easing.type: Easing.OutCubic }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation { target: wpPreviewContainer; property: "highlightFlash"; from: 1.0; to: 0.0; duration: 900; easing.type: Easing.InOutSine }
                }

                Component.onCompleted: {
                    searchRegTimer.restart();
                    checkHighlight();
                }

                Component.onDestruction: {
                    unregisterFromSearch();
                }

                OrbitSignals {
                    id: signals
                    objectName: "theme-orbit-signals"
                    visible: themeTabRoot.orbit
                    anchors.fill: parent
                    active: themeTabRoot.visible && themeTabRoot.orbitOverview
                    style: themeTabRoot.orbitConnectionStyle
                    networkStyle: themeTabRoot.themeSettings.orbitRingStyle === "wifi" ? "wifi" : "original"
                    signalColor: orbitMouse.containsMouse ? ThemeBackend.red : themeTabRoot.orbitActiveColor
                    circleX: orbitRing.x; circleY: orbitRing.y
                    diameter: orbitRing.width
                    targets: [Qt.rect(lockButton.x,lockButton.y,lockButton.width,lockButton.height),Qt.rect(musicButton.x,musicButton.y,musicButton.width,musicButton.height),Qt.rect(generalButton.x,generalButton.y,generalButton.width,generalButton.height),Qt.rect(themeButton.x,themeButton.y,themeButton.width,themeButton.height)]
                    unit: rootObj.s(1)
                }
                Rectangle {
                    objectName: "theme-orbit-wallpaper-glow"
                    visible: themeTabRoot.orbit && themeTabRoot.visible && themeTabRoot.orbitOverview
                    x: orbitRing.x - (width - orbitRing.width) / 2
                    y: orbitRing.y - (height - orbitRing.height) / 2
                    width: orbitRing.width + rootObj.s(30); height: width
                    radius: width / 2
                    color: orbitMouse.containsMouse ? ThemeBackend.red : themeTabRoot.orbitActiveColor
                    opacity: signals.coreProgress * (orbitMouse.containsMouse ? .45 : .15)
                    property real pulseScale: 1
                    scale: pulseScale * wpPreviewContainer.bumpScale * signals.coreScale
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                    SequentialAnimation on pulseScale {
                        objectName: "theme-orbit-wallpaper-glow-animation"
                        loops: Animation.Infinite
                        running: themeTabRoot.visible && themeTabRoot.orbitOverview
                        NumberAnimation { to: 1.1; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 2000; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    objectName: "theme-orbit-wallpaper-pulse"
                    visible: themeTabRoot.orbit && themeTabRoot.visible && themeTabRoot.orbitOverview
                    x: orbitRing.x - (width - orbitRing.width) / 2
                    y: orbitRing.y - (height - orbitRing.height) / 2
                    width: orbitRing.width + rootObj.s(12); height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: rootObj.s(2)
                    border.color: orbitMouse.containsMouse ? ThemeBackend.red : themeTabRoot.orbitActiveColor
                    opacity: signals.coreProgress * (.3 + Math.sin(signals.lightningTime * 2.5) * .15)
                    scale: signals.coreScale * (1.02 + Math.cos(signals.lightningTime * 3) * .02)
                }
                Rectangle {
                    id: orbitRing
                    z: 1
                    objectName: "theme-orbit-ring"
                    visible: themeTabRoot.orbit
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2
                    width: Math.max(rootObj.s(80), Math.min(rootObj.s(280), parent.width - 2 * (wpPreviewContainer.toolWidth + wpPreviewContainer.toolGap + rootObj.s(8)), parent.height - 2 * (wpPreviewContainer.toolHeight + wpPreviewContainer.toolGap + rootObj.s(8))))
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.width: 1
                    border.color: themeTabRoot.orbitBorderColor
                    opacity: signals.coreProgress
                    scale: wpPreviewContainer.hoverScale * wpPreviewContainer.bumpScale * signals.borderScale * signals.coreScale
                }
                ClickButton {
                    id: lockButton
                    objectName: "theme-orbit-lockscreen"
                    visible: themeTabRoot.orbit
                    opacity: signals.connectionOpacity
                    scale: signals.buttonScale
                    width: wpPreviewContainer.toolWidth; height: wpPreviewContainer.toolHeight
                    x: (wpPreviewContainer.width - width) / 2
                    y: orbitRing.y - wpPreviewContainer.toolGap - height
                    buttonText: "Lock screen"
                    readonly property rect movingRect: signals.movingTargets[0] || Qt.rect(x, y, width, height)
                    transform: Translate { x: lockButton.movingRect.x - lockButton.x; y: lockButton.movingRect.y - lockButton.y }
                    textFontSize: rootObj.s(14)
                    cornerRadius: ThemeBackend.clampedBorderRadius
                    accentColor: ThemeBackend.surface0; textColor: ThemeBackend.text
                    onClicked: themeTabRoot.rootObj.gotoTab("ThemeLockscreen")
                }
                ClickButton {
                    id: generalButton
                    objectName: "theme-orbit-general"
                    visible: themeTabRoot.orbit
                    opacity: signals.connectionOpacity
                    scale: signals.buttonScale
                    width: wpPreviewContainer.toolWidth; height: wpPreviewContainer.toolHeight
                    x: (wpPreviewContainer.width - width) / 2
                    y: orbitRing.y + orbitRing.height + wpPreviewContainer.toolGap
                    buttonText: "General"
                    readonly property rect movingRect: signals.movingTargets[2] || Qt.rect(x, y, width, height)
                    transform: Translate { x: generalButton.movingRect.x - generalButton.x; y: generalButton.movingRect.y - generalButton.y }
                    textFontSize: rootObj.s(14)
                    cornerRadius: ThemeBackend.clampedBorderRadius
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    // the Control tab's board opens its own General page; the Settings window shows it here
                    onClicked: { if (typeof rootObj.openGeneral === "function") rootObj.openGeneral(); else themeTabRoot.orbitTool = 1; }
                }
                ClickButton {
                    id: musicButton
                    objectName: "theme-orbit-music"
                    visible: themeTabRoot.orbit
                    opacity: signals.connectionOpacity
                    scale: signals.buttonScale
                    width: wpPreviewContainer.toolWidth; height: wpPreviewContainer.toolHeight
                    x: orbitRing.x + orbitRing.width + wpPreviewContainer.toolGap
                    y: orbitRing.y + (orbitRing.height-height)/2
                    // the Anserin interface's Music lives in Edit panel: this place is Pet's, a Control Center board page
                    buttonText: AnserinMode.active ? "Pet" : "Music"
                    readonly property rect movingRect: signals.movingTargets[1] || Qt.rect(x, y, width, height)
                    transform: Translate { x: musicButton.movingRect.x - musicButton.x; y: musicButton.movingRect.y - musicButton.y }
                    textFontSize: rootObj.s(14)
                    cornerRadius: ThemeBackend.clampedBorderRadius
                    accentColor: ThemeBackend.surface0; textColor: ThemeBackend.text
                    onClicked: themeTabRoot.rootObj.gotoTab(AnserinMode.active ? "ThemePet" : "ThemeMusic")
                }
                ClickButton {
                    id: themeButton
                    objectName: "theme-orbit-theme"
                    visible: themeTabRoot.orbit
                    opacity: signals.connectionOpacity
                    scale: signals.buttonScale
                    width: wpPreviewContainer.toolWidth; height: wpPreviewContainer.toolHeight
                    x: orbitRing.x - wpPreviewContainer.toolGap - width
                    y: orbitRing.y + (orbitRing.height-height)/2
                    buttonText: "Style"
                    readonly property rect movingRect: signals.movingTargets[3] || Qt.rect(x, y, width, height)
                    transform: Translate { x: themeButton.movingRect.x - themeButton.x; y: themeButton.movingRect.y - themeButton.y }
                    textFontSize: rootObj.s(14)
                    cornerRadius: ThemeBackend.clampedBorderRadius
                    accentColor: ThemeBackend.surface0; textColor: ThemeBackend.text
                    onClicked: themeTabRoot.rootObj.gotoTab("ThemeStyle")
                }
                Item {
                    id: wpCardShell
                    objectName: "theme-wallpaper-card"
                    readonly property bool roundImage: themeTabRoot.orbit && themeTabRoot.orbitImageStyle !== "rectangle"
                    readonly property real imageInset: themeTabRoot.orbitImageStyle === "bordered" ? orbitRing.border.width + rootObj.s(12) : 0
                    x: themeTabRoot.orbit ? (parent.width - width) / 2 : 0
                    y: themeTabRoot.orbit ? (parent.height - height) / 2 : 0
                    width: themeTabRoot.orbit ? (roundImage ? orbitRing.width - 2 * imageInset : Math.min(rootObj.s(240), orbitRing.width * .86)) : parent.width
                    height: themeTabRoot.orbit ? (roundImage ? width : width * 156 / 240) : parent.height
                    opacity: themeTabRoot.orbit ? signals.coreProgress : 1
                    scale: themeTabRoot.orbit ? wpPreviewContainer.hoverScale * wpPreviewContainer.bumpScale * signals.coreScale : 1
                    Rectangle {
                        id: wpCardMask
                        anchors.fill: parent
                        radius: wpCardShell.roundImage ? width / 2 : ThemeBackend.borderRadius
                        color: "black"
                        visible: false
                        layer.enabled: true
                    }
    
                    Item {
                        id: wpCardContent
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
    
                        Rectangle {
                            id: wpCardBg
                            anchors.fill: parent
                            radius: wpCardShell.roundImage ? width / 2 : ThemeBackend.borderRadius
                            color: ThemeBackend.surface0
                        }
    
                        Image {
                            id: wpCardImage
                            objectName: "theme-orbit-fallback-image"
                            z: themeTabRoot.orbit ? 1 : 0
                            anchors.fill: parent
                            source: {
                                if (themeTabRoot.orbit && !orbitMedia.failed) return "";
                                if (themeTabRoot.orbit || themeTabRoot.isWallpaperVideo) return "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png?rev=" + themeTabRoot.wallpaperRevision;
                                return themeTabRoot.currentWallpaperPath ? "file://" + themeTabRoot.currentWallpaperPath : "";
                            }
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            cache: false
                            visible: source !== "" && !orbitMedia.ready
                        }

                        Rectangle {
                            visible: !themeTabRoot.orbit
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: rootObj.s(64)
                            radius: ThemeBackend.borderRadius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0, 0.35) }
                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                            }
                        }
                    }
    
                    MultiEffect {
                        anchors.fill: parent
                        source: wpCardContent
                        maskEnabled: true
                        maskSource: wpCardMask
                    }
    
                    Item {
                        objectName: "theme-orbit-media-layer"
                        anchors.fill: parent
                        visible: orbitMedia.active && orbitMedia.ready
                        // DPI-triggered image reloads must not destroy the effect during Qt's item walk.
                        layer.enabled: orbitMedia.active
                        layer.effect: MultiEffect {
                            objectName: "theme-orbit-mask-effect"
                            maskEnabled: true
                            maskSource: wpCardMask
                        }
                        WallpaperMedia {
                            id: orbitMedia
                            objectName: "theme-orbit-media"
                            anchors.fill: parent
                            path: themeTabRoot.orbitWallpaperPath
                            active: themeTabRoot.visible && themeTabRoot.orbitOverview
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: wpCardShell.roundImage ? width / 2 : ThemeBackend.borderRadius
                        color: ThemeBackend.mauve
                        opacity: wpPreviewContainer.highlightFlash * 0.2
                        visible: opacity > 0.001
                        border.color: ThemeBackend.mauve
                        border.width: wpPreviewContainer.highlightFlash > 0.01 ? 2 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                    }
    
                    Rectangle {
                        anchors.fill: parent
                        radius: wpCardMask.radius
                        color: "#ffffff"
                        opacity: wpPreviewContainer.clickFlash
                        visible: opacity > 0
                    }
                    IconButton {
                        id: videoIndicator
                        visible: themeTabRoot.isWallpaperVideo && !orbitMedia.ready
                        anchors.centerIn: parent
                        size: rootObj.s(50)
                        cornerRadius: rootObj.s(16)
                        iconFontSize: rootObj.s(20)
                        buttonIcon: "󰐊"
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        opacity: 1.0
                        enabled: false
                    }
    
                    RowLayout {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: rootObj.s(12)
                        spacing: rootObj.s(12)
    
                        ClickButton {
                            id: wpSelectBtn
                            visible: !themeTabRoot.orbit
                            Layout.preferredHeight: rootObj.s(32)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: rootObj.s(14)
                            buttonIcon: "󰸉"
                            iconFontSize: rootObj.s(15)
                            buttonText: "Select wallpaper"
                            textFontSize: rootObj.s(11)
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.base
                            contentAlignment: Qt.AlignHCenter
                            onClicked: {
                                Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "toggle", "wallpaper"]);
                            }
                        }
    
                        Item { Layout.fillWidth: true }
    
                        MouseArea {
                            id: wpPathMa
                            visible: !themeTabRoot.orbit
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: wpPathCol.implicitWidth
                            implicitHeight: wpPathCol.implicitHeight
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (themeTabRoot.currentWallpaperPath && themeTabRoot.currentWallpaperPath !== "") {
                                    let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                                    FileManager.openFolder(String(themeTabRoot.currentWallpaperPath).replace(/\/[^\/]*$/, ""), false);
                                }
                            }
    
                            ColumnLayout {
                                id: wpPathCol
                                anchors.right: parent.right
                                spacing: rootObj.s(1)
    
                                Text {
                                    text: {
                                        if (!themeTabRoot.currentWallpaperPath) return "No Wallpaper Selected";
                                        let fn = themeTabRoot.currentWallpaperPath.split("/").pop();
                                        return fn || themeTabRoot.currentWallpaperPath;
                                    }
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(12)
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                    Layout.alignment: Qt.AlignRight
                                    elide: Text.ElideLeft
                                    Layout.maximumWidth: rootObj.s(320)
                                }
    
                                Text {
                                    text: themeTabRoot.currentWallpaperPath ? themeTabRoot.currentWallpaperPath.replace(Quickshell.env("HOME"), "~") : ""
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: rootObj.s(10)
                                    color: Qt.rgba(1, 1, 1, 0.75)
                                    Layout.alignment: Qt.AlignRight
                                    elide: Text.ElideLeft
                                    Layout.maximumWidth: rootObj.s(320)
                                    visible: text !== ""
                                }
                            }
                        }
                    }
                }
                MouseArea {
                    id: orbitMouse
                    objectName: "theme-orbit-wallpaper-open"
                    visible: themeTabRoot.orbit
                    x: orbitRing.x; y: orbitRing.y
                    width: orbitRing.width; height: orbitRing.height
                    hoverEnabled: themeTabRoot.visible && themeTabRoot.orbitOverview
                    enabled: !wallpaperClick.running
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                        wallpaperFlash.restart();
                        wallpaperClick.restart();
                    }
                }
            }

            SettingsRow {
                id: wallpaperDirRow
                rootObj: themeTabRoot.rootObj
                settingId: "wallpaper_dir"
                objectName: "theme-wallpaper_dir-row"
                visible: !themeTabRoot.orbit || themeTabRoot.orbitTool === 1
                icon: "󰸉"
                title: I18n.t("guide.theme.wallpaper.title") || "Wallpaper Directory"
                description: I18n.t("guide.theme.wallpaper.desc") || "Directory to search for wallpapers"
                searchKeywords: "wallpaper directory folder path pictures wallpapers"

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: rootObj.s(6)
                    buttonIcon: "󰉋"
                    iconOffsetX: -2
                    iconFontSize: rootObj.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    onClicked: {
                        if (themeTabRoot.currentWallpaperDir && themeTabRoot.currentWallpaperDir !== "") {
                            let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                            FileManager.openFolder(themeTabRoot.currentWallpaperDir, true);
                        }
                    }
                }

                Dropdown {
                    id: wpDirDropdown
                    objectName: "theme-wallpaper-directory"
                    Layout.preferredWidth: rootObj.s(260)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    options: themeTabRoot.availableWallpaperDirs
                    isPathSelector: true
                    fuzzySearch: true
                    currentIndex: options.indexOf(themeTabRoot.currentWallpaperDir) >= 0 ? options.indexOf(themeTabRoot.currentWallpaperDir) : 0
                    placeholderText: I18n.t("guide.theme.wallpaper.select_dir") || "Select directory..."
                    fontFamily: ThemeBackend.fontFamily
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        themeTabRoot.currentWallpaperDir = value;
                        themeTabRoot.updateWallpaperDirSetting();
                    }
                    onSelected: function(index, value) {
                        themeTabRoot.currentWallpaperDir = value;
                        themeTabRoot.updateWallpaperDirSetting();
                    }
                    onClicked: {
                        logic.wallpaperDirScanner.running = false;
                        logic.wallpaperDirScanner.running = true;
                    }
                }
            }

            Loader {
                id: orbitWallpaperLoader
                objectName: "theme-orbit-wallpaper-browser"
                Layout.fillWidth: true
                Layout.preferredHeight: Math.max(rootObj.s(240), themeFlick.height - rootObj.s(72))
                visible: themeTabRoot.orbit && themeTabRoot.visible && themeTabRoot.orbitTool === 0
                active: visible || themeTabRoot.wallpaperApplyPending
                onLoaded: themeTabRoot.wallpaperApplyPending = item.mediaApplyPending
                sourceComponent: WallpaperUi.WallpaperPicker {
                    anchors.fill: parent
                    embedded: true
                    visible: themeTabRoot.orbit && themeTabRoot.visible && themeTabRoot.orbitTool === 0
                }
            }
            Connections {
                id: wallpaperApplyLink
                target: orbitWallpaperLoader.item
                ignoreUnknownSignals: true
                function onMediaApplyPendingChanged() { themeTabRoot.wallpaperApplyPending = target.mediaApplyPending; }
            }

            SettingsRow {
                rootObj: themeTabRoot.rootObj
                settingId: "font"
                objectName: "theme-font-row"
                visible: !themeTabRoot.orbit || themeTabRoot.orbitTool === 1
                icon: "󰛖"
                title: I18n.t("guide.theme.font.title")
                description: I18n.t("guide.theme.font.desc")
                searchKeywords: "font typeface family typography text"

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: rootObj.s(6)
                    buttonIcon: "󰉋"
                    iconOffsetX: -2
                    iconFontSize: rootObj.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    onClicked: {
                        let userFontsPath = Caching.stateDir ? (Caching.stateDir + "/fonts") : (Caching.home + "/.local/state/anserin/fonts");
                        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                        FileManager.openFolder(userFontsPath, true);
                    }
                }

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: rootObj.s(6)
                    buttonIcon: "󰐕"
                    iconFontSize: rootObj.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    objectName: "theme-font-import"
                    onClicked: fontPickerPopup.openPicker()
                }

                Dropdown {
                    id: fontDropdown
                    objectName: "theme-font-selector"
                    Layout.preferredWidth: rootObj.s(220)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    options: themeTabRoot.availableFonts
                    currentIndex: options.indexOf(themeTabRoot.currentFontFamily) >= 0 ? options.indexOf(themeTabRoot.currentFontFamily) : 0
                    placeholderText: I18n.t("guide.theme.font.select")
                    fontFamily: ThemeBackend.fontFamily
                    useOptionAsFontFamily: true
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        themeTabRoot.currentFontFamily = value;
                        themeTabRoot.updateFontSetting();
                    }
                    onClicked: {
                        themeTabRoot.loadAvailableFonts();
                    }
                }
            }

            SettingsRow {
                rootObj: themeTabRoot.rootObj
                settingId: "border_radius"
                objectName: "theme-border_radius-row"
                visible: !themeTabRoot.orbit || themeTabRoot.orbitTool === 1
                icon: "󰞁"
                title: I18n.t("guide.theme.radius.title")
                description: I18n.t("guide.theme.radius.desc")
                searchKeywords: "border radius corner round curvature rounding px"

                NumberSelector {
                    id: radiusSelector
                    objectName: "theme-radius-selector"
                    implicitWidth: rootObj.s(150)
                    implicitHeight: rootObj.s(32)
                    from: 0
                    to: 64
                    stepSize: 1
                    decimals: 0
                    suffix: "px"
                    value: themeTabRoot.currentBorderRadius
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    buttonColor: ThemeBackend.surface1
                    buttonTextColor: ThemeBackend.text
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontFamily: ThemeBackend.fontFamily
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(val) {
                        let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                        let rounded = Math.round(num);
                        let snapped = themeTabRoot.getSnappedRadius(rounded);
                        if (!isNaN(snapped) && snapped >= 0 && snapped <= 64 && themeTabRoot.currentBorderRadius !== snapped) {
                            themeTabRoot.currentBorderRadius = snapped;
                            logic.borderRadiusDebounceTimer.restart();
                        }
                    }
                    onTriggered: {
                        let rounded = Math.round(radiusSelector.value);
                        let snapped = themeTabRoot.getSnappedRadius(rounded);
                        themeTabRoot.currentBorderRadius = snapped;
                        themeTabRoot.updateBorderRadiusSetting();
                    }
                }
            }

            GeneralExtras {
                rootObj: themeTabRoot.rootObj
                visible: !themeTabRoot.orbit || themeTabRoot.orbitTool === 1
            }

            Rectangle {
                objectName: "theme-colors-section"
                visible: !themeTabRoot.orbit || themeTabRoot.orbitTool === 1
                Layout.fillWidth: true
                implicitHeight: themesSectionCol.implicitHeight + rootObj.s(12)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                clip: true

                ColumnLayout {
                    id: themesSectionCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: 0

                    SettingsRow {
                        id: colorSchemesRow
                        rootObj: themeTabRoot.rootObj
                        settingId: "colors"
                        icon: "󰏘"
                        title: I18n.t("guide.theme.colors.title")
                        description: I18n.t("guide.theme.colors.desc")
                        searchKeywords: "colors theme presets scheme palette matugen catppuccin"
                        baseColor: "transparent"
                        hoverColor: "transparent"
                        borderWidth: 0
                        color: highlightFlash > 0.001 ? Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, highlightFlash * 0.18) : "transparent"

                        IconButton {
                            Layout.alignment: Qt.AlignVCenter
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            cornerRadius: rootObj.s(8)
                            buttonIcon: "󰐕"
                            iconFontSize: rootObj.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                            objectName: "theme-preset-new"
                            onClicked: {
                                if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/clickbutton/click.wav");
                                themeEditorPopup.openForNew();
                            }
                        }

                        Input {
                            id: themeSearchInput
                            objectName: "theme-preset-search"
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: rootObj.s(180)
                            placeholderText: I18n.t("guide.theme.colors.search")
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: rootObj.s(11)
                            charSpacing: 1
                            onTextEdited: newText => themeTabRoot.themeSearchText = newText
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.alpha(ThemeBackend.surface1, 0.3)
                    }

                    ThemePresetGrid {
                        id: themesGrid
                        page: themeTabRoot
                        rootObj: themeTabRoot.rootObj
                        Layout.fillWidth: true
                        Layout.leftMargin: rootObj.s(12)
                        Layout.rightMargin: rootObj.s(12)
                        Layout.topMargin: rootObj.s(12)
                        Layout.bottomMargin: rootObj.s(12)
                    }
                }
            }
        }
    }
}
