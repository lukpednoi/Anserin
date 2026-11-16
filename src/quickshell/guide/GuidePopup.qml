import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "GuideTabs.js" as GuideTabs

Item {
    id: root
    visible: false
    focus: true

    readonly property bool isGuidePopup: true
    property bool orbitRequested: false
    property var themeGeneralPage: null
    readonly property bool orbitLanding: !!(themeGeneralPage && themeGeneralPage.visible && themeGeneralPage.orbitOverview)
    readonly property bool orbitTheme: tabsModel[currentTab].id === "Theme" && (orbitRequested || Config.getSetting("theme.generalLayout", "original") === "orbit")
    readonly property bool orbitOnly: orbitRequested && currentSubTab === 0 && (!themeGeneralPage || themeGeneralPage.orbitTool <= 0)
    readonly property string orbitBackground: Config.getSetting("theme.orbitBackground", "panel") === "transparent" ? "transparent" : "wifi"
    readonly property bool orbitPanel: (orbitOnly || orbitLanding) && orbitBackground === "wifi" && (!themeGeneralPage || themeGeneralPage.orbitOverview)

    signal closeRequested()
    // Settings stays closed for 10 minutes: every tab but the current one lets go of its page (loaded again on demand)
    signal releaseTabs()
    Timer {
        id: tabReleaseTimer
        interval: 600000
        onTriggered: if (!root.visible) root.releaseTabs()
    }
    property bool embedded: false
    readonly property bool compactSettings: true
    readonly property string lastTabPath: Caching.getCacheDir("guide") + (embedded ? "/quick-actions-last-tab.txt" : "/last_tab.txt")

    property int activationCounter: 0
    property var appPaths: Caching
    property int currentTab: 0
    property int currentSubTab: 0
    property int expandedTab: -1
    property real colorBlend: 0.0
    property color ambientPurple: Qt.tint(ThemeBackend.mauve, Qt.rgba(ThemeBackend.pink.r, ThemeBackend.pink.g, ThemeBackend.pink.b, colorBlend))
    property color ambientBlue: Qt.tint(ThemeBackend.blue, Qt.rgba(ThemeBackend.sapphire.r, ThemeBackend.sapphire.g, ThemeBackend.sapphire.b, colorBlend))
    property int chargingSoundHandle: -1

    property real introBase: 0.0
    property real introContent: 0.0
    property var tutorialSections: []

    property string highlightedSettingId: ""
    property int highlightToken: 0

    property var tabsModel: GuideTabs.tabs

    StackView.onStatusChanged: {
        if (StackView.status === StackView.Active) {
            activationCounter++;
        }
    }

    property var exitCallback: null

    function startExit(onFinished) {
        exitCallback = onFinished;
        closePopup();
    }

    function closePopup() {
        startupSequence.stop();
        closeSequence.restart();
    }

    function s(val) {
        return Scaler.s(val);
    }

    function gotoTab(tabName, subTabName) {
        if (tabName === undefined || tabName === null || tabName === "") return;
        if (["displaylockscreen", "display_lockscreen"].indexOf(String(tabName).toLowerCase()) >= 0 || (String(tabName) === "2" && String(subTabName) === "1")) {
            tabName = "ThemeLockscreen";
            subTabName = undefined;
        }
        if (String(tabName).toLowerCase() === "themeorbit") {
            root.gotoTab("ThemeGeneral");
            root.orbitRequested = true;
            if (themeGeneralPage) themeGeneralPage.orbitTool = -1;
            return;
        }
        let num = parseInt(tabName);
        if (["themegeneral", "theme"].indexOf(String(tabName).toLowerCase()) >= 0) root.orbitRequested = false;
        if (!isNaN(num) && num >= 0 && num < tabsModel.length) {
            currentTab = num;
            expandedTab = (tabsModel[num].subtabs && tabsModel[num].subtabs.length > 0) ? num : -1;
            if (subTabName !== undefined && subTabName !== null && subTabName !== "") {
                let sNum = parseInt(subTabName);
                currentSubTab = !isNaN(sNum) && tabsModel[num].subtabs && sNum >= 0 && sNum < tabsModel[num].subtabs.length ? sNum : 0;
            } else {
                currentSubTab = 0;
            }
            return;
        }
        let lower = String(tabName).toLowerCase().replace(/^guide\.tabs\./, "");
        for (let i = 0; i < tabsModel.length; i++) {
            let t = tabsModel[i];
            if ((t.id && t.id.toLowerCase() === lower) || 
                (t.name && t.name.toLowerCase() === lower) || 
                (t.key && t.key.toLowerCase() === lower)) {
                currentTab = i;
                expandedTab = (t.subtabs && t.subtabs.length > 0) ? i : -1;
                if (subTabName !== undefined && subTabName !== null && subTabName !== "") {
                    let sLower = String(subTabName).toLowerCase().replace(/^guide\.tabs\./, "");
                    let sNum = parseInt(subTabName);
                    if (!isNaN(sNum) && t.subtabs && sNum >= 0 && sNum < t.subtabs.length) {
                        currentSubTab = sNum;
                    } else if (t.subtabs) {
                        let sIdx = t.subtabs.findIndex(st => 
                            (st.id && st.id.toLowerCase() === sLower) || 
                            (st.name && st.name.toLowerCase() === sLower) || 
                            (st.key && st.key.toLowerCase() === sLower)
                        );
                        currentSubTab = sIdx !== -1 ? sIdx : 0;
                    } else {
                        currentSubTab = 0;
                    }
                } else {
                    currentSubTab = 0;
                }
                return;
            }

            if (t.subtabs && Array.isArray(t.subtabs)) {
                let sIdx = t.subtabs.findIndex(st => 
                    (st.id && st.id.toLowerCase() === lower) || 
                    (st.name && st.name.toLowerCase() === lower) || 
                    (st.key && st.key.toLowerCase() === lower)
                );
                if (sIdx !== -1) {
                    currentTab = i;
                    expandedTab = i;
                    currentSubTab = sIdx;
                    return;
                }
            }
        }
    }

    function showOrbitOverview() {
        currentSubTab = 0;
        if (themeGeneralPage) themeGeneralPage.orbitTool = -1;
    }

    function resetAndPlayIntro() {
        introBase = 0.0;
        introContent = 0.0;
        startupSequence.restart();
    }

    function nextTab() {
        let parentTab = tabsModel[currentTab];
        if (parentTab && parentTab.subtabs && parentTab.subtabs.length > 0 && expandedTab === currentTab) {
            if (currentSubTab < parentTab.subtabs.length - 1) {
                currentSubTab++;
                return;
            }
        }
        currentTab = (currentTab + 1) % tabsModel.length;
        let nextParent = tabsModel[currentTab];
        if (nextParent && nextParent.subtabs && nextParent.subtabs.length > 0) {
            expandedTab = currentTab;
            currentSubTab = 0;
        } else {
            expandedTab = -1;
            currentSubTab = 0;
        }
    }

    function prevTab() {
        let parentTab = tabsModel[currentTab];
        if (parentTab && parentTab.subtabs && parentTab.subtabs.length > 0 && expandedTab === currentTab) {
            if (currentSubTab > 0) {
                currentSubTab--;
                return;
            }
        }
        currentTab = (currentTab - 1 + tabsModel.length) % tabsModel.length;
        let prevParent = tabsModel[currentTab];
        if (prevParent && prevParent.subtabs && prevParent.subtabs.length > 0) {
            expandedTab = currentTab;
            currentSubTab = prevParent.subtabs.length - 1;
        } else {
            expandedTab = -1;
            currentSubTab = 0;
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: root.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) tabReleaseTimer.stop();
        else tabReleaseTimer.restart();
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        } else {
            orbitRequested = false;
            startupSequence.stop();
            closeSequence.stop();
            focusTimer.stop();
            introBase = 0.0;
            introContent = 0.0;
            if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                Sounds.stopSfx(root.chargingSoundHandle);
                root.chargingSoundHandle = -1;
            }
        }
    }

    Component.onCompleted: {
        if (visible) {
            forceActiveFocus();
            focusTimer.restart();
            resetAndPlayIntro();
        }
    }

    Keys.onEscapePressed: (event) => {
        if (!root.embedded && typeof masterWindow !== "undefined" && masterWindow.switchWidget) {
            masterWindow.switchWidget("hidden", "");
        } else {
            closePopup();
        }
        event.accepted = true;
    }
    Keys.onDownPressed: (event) => { nextTab(); event.accepted = true; }
    Keys.onUpPressed: (event) => { prevTab(); event.accepted = true; }
    Keys.onLeftPressed: (event) => { prevTab(); event.accepted = true; }
    Keys.onRightPressed: (event) => { nextTab(); event.accepted = true; }
    Keys.onTabPressed: (event) => { nextTab(); event.accepted = true; }
    Keys.onBacktabPressed: (event) => { prevTab(); event.accepted = true; }

    SequentialAnimation on colorBlend {
        loops: Animation.Infinite
        running: root.visible
        NumberAnimation { to: 1.0; duration: 15000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0.0; duration: 15000; easing.type: Easing.InOutSine }
    }

    Timer {
        id: saveTabDebounceTimer
        interval: 350
        repeat: false
        onTriggered: {
            const tab = root.tabsModel[root.currentTab];
            const subtab = tab && tab.subtabs ? tab.subtabs[root.currentSubTab] : null;
            const savedTab = subtab && subtab.id === "DisplayPresets" ? "Display:DisplayPresets" : root.currentTab + ":" + root.currentSubTab;
            Quickshell.execDetached(["bash", "-c", 'printf "%s\\n" "$1" > "$2"', "_", savedTab, root.lastTabPath]);
        }
    }

    function saveLastTab() {
        saveTabDebounceTimer.restart();
    }

    onCurrentTabChanged: {
        if (!tabsModel[currentTab] || tabsModel[currentTab].id !== "Theme") orbitRequested = false;
        saveLastTab();
    }
    onCurrentSubTabChanged: {
        if (!tabsModel[currentTab] || tabsModel[currentTab].id !== "Theme") orbitRequested = false;
        saveLastTab();
    }

    FileView {
        id: lastTabWatcher
        path: root.lastTabPath
        watchChanges: !root.embedded
        onFileChanged: reload()
        onLoaded: {
            try {
                let val = text().trim();
                if (val !== "") {
                    if (val.indexOf(":") !== -1) {
                        let parts = val.split(":");
                        root.gotoTab(parts[0], parts[1]);
                    } else {
                        root.gotoTab(val);
                    }
                }
            } catch(e) {}
        }
    }

    FileView {
        id: tutorialWatcher
        path: Caching.anserinDir ? (Caching.anserinDir + "/assets/tutorial.json") : ""
        onLoaded: {
            try {
                let data = JSON.parse(text().trim());
                if (Array.isArray(data)) {
                    root.tutorialSections = data;
                }
            } catch(e) {}
        }
    }

    ParallelAnimation {
        id: startupSequence
        running: false
        NumberAnimation {
            target: root
            property: "introBase"
            from: 0.0
            to: 1.0
            duration: 650
            easing.type: Easing.OutExpo
        }
        SequentialAnimation {
            PauseAnimation { duration: 180 }
            NumberAnimation {
                target: root
                property: "introContent"
                from: 0.0
                to: 1.0
                duration: 650
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: closeSequence
        ScriptAction {
            script: {
                if (root.chargingSoundHandle !== -1 && typeof Sounds !== "undefined") {
                    Sounds.stopSfx(root.chargingSoundHandle);
                    root.chargingSoundHandle = -1;
                }
            }
        }
        NumberAnimation {
            target: root
            property: "introContent"
            to: 0.0
            duration: 150
            easing.type: Easing.InExpo
        }
        NumberAnimation {
            target: root
            property: "introBase"
            to: 0.0
            duration: 200
            easing.type: Easing.InQuart
        }
        ScriptAction {
            script: {
                if (root.embedded) {
                    root.closeRequested();
                } else if (root.exitCallback) {
                    let cb = root.exitCallback;
                    root.exitCallback = null;
                    cb();
                } else {
                    Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "close"]);
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        opacity: introBase
        scale: 0.95 + (0.05 * introBase)

        Rectangle {
            objectName: "settings-page-background"
            anchors.fill: parent
            radius: ThemeBackend.clampedBorderRadius
            color: materialGlass.active ? "transparent" : root.orbitOnly && !root.orbitPanel ? "transparent" : ThemeBackend.base
            WallpaperBlur {
                id: materialGlass
                anchors.fill: parent
                radius: parent.radius
                allowed: !root.orbitOnly || root.orbitPanel
            }


            property real time: 0
            NumberAnimation on time {
                from: 0
                to: Math.PI * 2
                duration: 20000
                loops: Animation.Infinite
                running: root.visible
            }

            Loader {
                objectName: "orbit-wifi-background"
                anchors.fill: parent
                active: root.visible && root.orbitPanel
                sourceComponent: OrbitBackdrop {
                    active: true
                    unit: root.s(1)
                }
            }

            Loader {
                objectName: "settings-compact-navigation"
                anchors.fill: parent
                active: !root.orbitOnly
                sourceComponent: CompactNavigation { rootObj: root }
            }

            Item {
                id: contentArea
                objectName: "settings-content-area"
                x: root.orbitOnly ? 0 : root.s(84)
                y: root.orbitOnly ? 0 : root.s(root.orbitTheme ? 52 : 88)
                width: root.orbitOnly ? parent.width : Math.max(0, parent.width - root.s(96))
                height: root.orbitOnly ? parent.height : Math.max(0, parent.height - root.s(root.orbitTheme ? 64 : 100))

                opacity: root.orbitLanding ? 1 : introContent
                scale: root.orbitLanding ? 1 : 0.95 + (0.05 * introContent)
                transform: Translate { y: root.orbitLanding ? 0 : root.s(20) * (1.0 - introContent) }

                ClickButton {
                    id: orbitBack
                    objectName: "theme-subpage-back"
                    visible: root.orbitTheme && root.currentSubTab !== 0
                    x: root.s(8); y: root.s(4)
                    height: root.s(30)
                    // back to the Theme's first page: the Orbit, or General with the List page layout
                    buttonText: Config.getSetting("theme.generalLayout", "original") === "orbit" ? "← Orbit" : "← General"
                    textFontSize: root.s(12)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: root.showOrbitOverview()
                }

                Repeater {
                    id: contentRepeater
                    model: root.tabsModel
                    delegate: Item {
                        id: tabContentWrapper
                        anchors.fill: parent
                        anchors.topMargin: orbitBack.visible ? root.s(44) : 0

                        property int parentTabIndex: index
                        property int tabIndex: parentTabIndex
                        property var tabData: modelData
                        property bool hasSubtabs: Boolean(tabData.subtabs && tabData.subtabs.length > 0)
                        property alias singleLoader: singleTabLoader
                        property alias subLoadersRepeater: subRepeat

                        property bool isCurrent: root.currentTab === parentTabIndex
                        visible: isCurrent || opacity > 0.001
                        opacity: isCurrent ? 1.0 : 0.0
                        property real animY: isCurrent ? 0 : root.s(10)
                        transform: Translate { y: tabContentWrapper.animY }

                        Behavior on opacity {
                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                        }
                        Behavior on animY {
                            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                        }

                        Loader {
                            id: singleTabLoader
                            anchors.fill: parent
                            asynchronous: true
                            active: !tabContentWrapper.hasSubtabs
                            visible: !tabContentWrapper.hasSubtabs && tabContentWrapper.visible
                            property int tabIndex: tabContentWrapper.parentTabIndex
                            property int subTabIndex: -1

                            function ensureLoaded() {
                                if (!tabContentWrapper.hasSubtabs && root.currentTab === tabContentWrapper.parentTabIndex && status === Loader.Null && tabData.file) {
                                    setSource(tabData.file, {
                                        "rootObj": root,
                                        "tabIndex": tabContentWrapper.parentTabIndex
                                    });
                                }
                            }

                            onStatusChanged: {
                                if (status === Loader.Error) {
                                    console.warn("Guide tab failed to load:", source);
                                }
                            }


                            Component.onCompleted: ensureLoaded()

                            Connections {
                                target: root
                                function onCurrentTabChanged() {
                                    if (root.currentTab === tabContentWrapper.parentTabIndex && !tabContentWrapper.hasSubtabs) singleTabLoader.ensureLoaded();
                                }
                                function onReleaseTabs() {
                                    if (root.currentTab !== tabContentWrapper.parentTabIndex && singleTabLoader.status !== Loader.Null) singleTabLoader.source = "";
                                }
                            }

                        }

                        Repeater {
                            id: subRepeat
                            model: tabContentWrapper.hasSubtabs ? tabData.subtabs : []

                            delegate: Loader {
                                id: subTabLoader
                                anchors.fill: parent
                                asynchronous: true
                                property int subIndex: index
                                property int tabIndex: tabContentWrapper.parentTabIndex
                                property int subTabIndex: subIndex
                                property var subData: modelData

                                property bool isSubCurrent: root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex
                                visible: isSubCurrent || opacity > 0.001
                                opacity: isSubCurrent ? 1.0 : 0.0
                                property real subAnimY: isSubCurrent ? 0 : root.s(10)
                                transform: Translate { y: subTabLoader.subAnimY }

                                Behavior on opacity {
                                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                }
                                Behavior on subAnimY {
                                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                                }

                                function ensureLoaded() {
                                    if ((root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex) && status === Loader.Null && subData.file) {
                                        setSource(subData.file, {
                                            "rootObj": root,
                                            "tabIndex": tabContentWrapper.parentTabIndex,
                                            "subTabIndex": subIndex
                                        });
                                    }
                                }

                                onStatusChanged: {
                                    if (status === Loader.Error) {
                                        console.warn("Guide tab failed to load:", source);
                                    }
                                }


                                Component.onCompleted: ensureLoaded()

                                Connections {
                                    target: root
                                    function onCurrentTabChanged() {
                                        if (root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                                    }
                                    function onCurrentSubTabChanged() {
                                        if (root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex) subTabLoader.ensureLoaded();
                                    }
                                    function onReleaseTabs() {
                                        if (!(root.currentTab === tabContentWrapper.parentTabIndex && root.currentSubTab === subIndex) && subTabLoader.status !== Loader.Null) subTabLoader.source = "";
                                    }
                                }

                            }
                        }
                    }
                }
            }

        }
    }
}
