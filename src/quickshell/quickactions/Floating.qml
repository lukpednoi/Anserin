import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../reusables"
import "QuickActions.js" as QuickActions

Variants {
    id: floatingRoot
    readonly property string groupsJson: JSON.stringify(QuickActions.groups(Config.getSetting("quickactions", {}), Config.getSetting("bar", {}).modules))
    property var groups: JSON.parse(groupsJson)
    // Four slots match the chosen Top strip; larger groups must still fit.
    readonly property int stripSlotCount: Math.max(4, ...QuickActions.positions.map(edge => groups[edge].length))
    model: {
        let panels = [];
        for (let screen of Quickshell.screens) {
            for (let edge of QuickActions.positions) panels.push({ screen: screen, edge: edge });
        }
        return panels;
    }

    delegate: Component {
        PanelWindow {
            id: floatingWidget
            objectName: "quick-actions-" + modelData.edge
            required property var modelData
            screen: modelData.screen
            readonly property int frameInset: ScreenEdges.inset(screen)
            readonly property var attachedBar: screen ? LauncherController.bars[screen.name] || null : null
            Component.onCompleted: FloatingController.registerPanel(floatingWidget)
            Component.onDestruction: FloatingController.unregisterPanel(floatingWidget)
            property bool fromBar: false
            Connections {
                target: ScreenEdges
                function onModernChanged() {
                    floatingWidget.isPeekVisible = false;
                    peekShowTimer.stop();
                    peekHideTimer.stop();
                }
            }
            visible: tabModules.length > 0

            WlrLayershell.namespace: "qs-floating-overlay"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: shouldHaveKeyboardFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"

            readonly property bool shouldHaveKeyboardFocus: isSidebarVisible && (isExpanded || hasInputFocus)

            readonly property var activeModule: {
                if (typeof moduleRepeater === "undefined") return null;
                let loader = moduleRepeater.itemAt(Object.keys(QuickActions.types).indexOf(tabModules[activeIndex]));
                return loader && loader.status === Loader.Ready ? loader.item : null;
            }
            readonly property bool hasInputFocus: activeModule && activeModule.hasInputFocus !== undefined ? Boolean(activeModule.hasInputFocus) : false
            readonly property bool needsPopupInput: activeModule && activeModule.needsPopupInput !== undefined ? Boolean(activeModule.needsPopupInput) : false

            onHasInputFocusChanged: {
                if (hasInputFocus) {
                    hideTimer.stop();
                    floatingWidget.useGraceTimer = false;
                } else {
                    floatingWidget.kickTimer();
                }
            }

            function grabKeyboardFocus() {
                if (!shouldHaveKeyboardFocus) return;
                if (typeof floatingWidget.requestActivate === "function") {
                    floatingWidget.requestActivate();
                }
                if (!hasInputFocus) {
                    focusTracker.forceActiveFocus();
                }
            }

            anchors {
                top: true; bottom: true; left: true; right: true
            }

            onShouldHaveKeyboardFocusChanged: {
                if (shouldHaveKeyboardFocus) {
                    grabKeyboardFocus();
                    Qt.callLater(grabKeyboardFocus);
                }
            }

            onIsSidebarVisibleChanged: {
                if (!isSidebarVisible) fromBar = false;
                if (isSidebarVisible) {
                    SysData.prewarm();
                    grabKeyboardFocus();
                    Qt.callLater(grabKeyboardFocus);
                }
            }

            property int configRevision: 0

            property string barPosition: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.position !== undefined) ? Config.rawSettings.bar.position : "top"
            property bool barAutohide: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.autohide !== undefined) ? Config.rawSettings.bar.autohide : false

            property real barInset: ScreenEdges.modern ? (attachedBar && attachedBar.visible && !attachedBar.autohide ? attachedBar.barHeight : 0) : (barAutohide ? 0 : s(48))
            property real topBound: frameInset + (barPosition === "top" ? barInset : 0)
            property real bottomBound: floatingWidget.height - frameInset - (barPosition === "bottom" ? barInset : 0)
            property real leftBound: frameInset + (barPosition === "left" ? barInset : 0)
            property real rightBound: floatingWidget.width - frameInset - (barPosition === "right" ? barInset : 0)

            property real edgeHitSize: Math.max(2, Math.round(s(3)), frameInset)

            property var defaultDockSettings: ({
                "enabled": true,
                "position": "bottom",
                "elementSize": 44,
                "floating": false,
                "editing": false,
                "apps": []
            })

            property var rawDockSettings: {
                let dummy = configRevision;
                if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.dock) {
                    return Config.rawSettings.dock;
                }
                if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
                    return Config.getSetting("dock", defaultDockSettings);
                }
                return defaultDockSettings;
            }

            property bool dockEnabled: (rawDockSettings && rawDockSettings.enabled !== undefined) ? rawDockSettings.enabled : true
            property string dockPosition: (rawDockSettings && rawDockSettings.position !== undefined) ? rawDockSettings.position : "bottom"
            property int dockElementSize: (rawDockSettings && rawDockSettings.elementSize !== undefined) ? rawDockSettings.elementSize : 44
            property bool dockEditMode: (rawDockSettings && rawDockSettings.editing !== undefined) ? rawDockSettings.editing : false

            property bool enableScrolling: (rawDockSettings && rawDockSettings.enableScrolling !== undefined) ? Boolean(rawDockSettings.enableScrolling) : false
            property int dockVisibleElements: (rawDockSettings && rawDockSettings.visibleElements !== undefined && !isNaN(rawDockSettings.visibleElements) && rawDockSettings.visibleElements > 0) ? rawDockSettings.visibleElements : 7

            property var dockAppsList: (rawDockSettings && rawDockSettings.apps && Array.isArray(rawDockSettings.apps)) ? rawDockSettings.apps : []
            property int dockItemCount: {
                if (dockAppsList.length > 0) return dockAppsList.length;
                if (dockEditMode) return 6;
                return 0;
            }
            property int effectiveDockItemCount: {
                if (enableScrolling && dockItemCount > 0) {
                    return Math.min(dockItemCount, Math.max(1, dockVisibleElements));
                }
                return dockItemCount;
            }
            property bool isDockActive: dockEnabled && (dockItemCount > 0 || dockEditMode)

            property real dockOuterCornerRadius: {
                let br = (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined) ? ThemeBackend.borderRadius : 8;
                return br <= 16 ? br * 2 : Math.min(32, 32 - 16 * Math.exp(-(br - 16) / 12));
            }

            property real dockLength: {
                if (!isDockActive) return 0;
                let spacing = dockEditMode ? s(10) : s(8);
                let count = effectiveDockItemCount;
                let contentLen = count * s(dockElementSize) + Math.max(0, count - 1) * spacing;
                let baseLen = contentLen + s(20) + (dockOuterCornerRadius * 2) + s(12);
                return baseLen * 1.2;
            }

            property real dockHStart: Math.max(leftBound, Math.round((floatingWidget.width - dockLength) / 2))
            property real dockHEnd: Math.min(rightBound, Math.round((floatingWidget.width + dockLength) / 2))

            property real dockVStart: Math.max(topBound, Math.round((floatingWidget.height - dockLength) / 2))
            property real dockVEnd: Math.min(bottomBound, Math.round((floatingWidget.height + dockLength) / 2))

            readonly property bool horizontalEdge: activeEdge === "top" || activeEdge === "bottom"
            readonly property real iconEdgeStart: (horizontalEdge ? Math.round(clampedCenterX - sidebarW / 2) + sidebarW / 2 : Math.round(clampedCenterY - baseSidebarH / 2) + baseSidebarH / 2)
                - tabGroupHeight / 2 + (activeEdge === "top" || activeEdge === "right" ? s(12) : 0)
            readonly property real edgeStartBound: Math.max(horizontalEdge ? leftBound : topBound, iconEdgeStart)
            readonly property real edgeEndBound: Math.min(horizontalEdge ? rightBound : bottomBound, iconEdgeStart + Math.max(0, tabGroupHeight - s(12)))

            readonly property bool isDockOnBottom: isDockActive && dockPosition === "bottom"
            readonly property real bottomEdgeA_x: edgeStartBound
            readonly property real bottomEdgeA_w: activeEdge !== "bottom" ? 0 : Math.max(0, (isDockOnBottom ? Math.min(dockHStart, edgeEndBound) : edgeEndBound) - bottomEdgeA_x)
            readonly property real bottomEdgeB_x: isDockOnBottom ? Math.max(dockHEnd, edgeStartBound) : edgeEndBound
            readonly property real bottomEdgeB_w: (activeEdge !== "bottom" || !isDockOnBottom) ? 0 : Math.max(0, edgeEndBound - bottomEdgeB_x)

            readonly property bool isDockOnTop: isDockActive && dockPosition === "top"
            readonly property real topEdgeA_x: edgeStartBound
            readonly property real topEdgeA_w: activeEdge !== "top" ? 0 : Math.max(0, (isDockOnTop ? Math.min(dockHStart, edgeEndBound) : edgeEndBound) - topEdgeA_x)
            readonly property real topEdgeB_x: isDockOnTop ? Math.max(dockHEnd, edgeStartBound) : edgeEndBound
            readonly property real topEdgeB_w: (activeEdge !== "top" || !isDockOnTop) ? 0 : Math.max(0, edgeEndBound - topEdgeB_x)

            readonly property bool isDockOnLeft: isDockActive && dockPosition === "left"
            readonly property real leftEdgeA_y: edgeStartBound
            readonly property real leftEdgeA_h: activeEdge !== "left" ? 0 : Math.max(0, (isDockOnLeft ? Math.min(dockVStart, edgeEndBound) : edgeEndBound) - leftEdgeA_y)
            readonly property real leftEdgeB_y: isDockOnLeft ? Math.max(dockVEnd, edgeStartBound) : edgeEndBound
            readonly property real leftEdgeB_h: (activeEdge !== "left" || !isDockOnLeft) ? 0 : Math.max(0, edgeEndBound - leftEdgeB_y)

            readonly property bool isDockOnRight: isDockActive && dockPosition === "right"
            readonly property real rightEdgeA_y: edgeStartBound
            readonly property real rightEdgeA_h: activeEdge !== "right" ? 0 : Math.max(0, (isDockOnRight ? Math.min(dockVStart, edgeEndBound) : edgeEndBound) - rightEdgeA_y)
            readonly property real rightEdgeB_y: isDockOnRight ? Math.max(dockVEnd, edgeStartBound) : edgeEndBound
            readonly property real rightEdgeB_h: (activeEdge !== "right" || !isDockOnRight) ? 0 : Math.max(0, edgeEndBound - rightEdgeB_y)

            readonly property bool isAnyEdgeHovered: topEdgeA.containsMouse || topEdgeB.containsMouse ||
                                                     bottomEdgeA.containsMouse || bottomEdgeB.containsMouse ||
                                                     leftEdgeA.containsMouse || leftEdgeB.containsMouse ||
                                                     rightEdgeA.containsMouse || rightEdgeB.containsMouse

            function handleEdgeEntered(edge) {
                floatingWidget.fromBar = false;
                SysData.prewarm();
                peekHideTimer.stop();
                if (ScreenEdges.modern) {
                    peekShowTimer.stop();
                    showSidebar(edge, false);
                    return;
                }
                if (floatingWidget.isSidebarVisible) {
                    floatingWidget.showSidebar(edge);
                } else if (floatingWidget.isPeekVisible) {
                    floatingWidget.showPeek(edge);
                } else {
                    peekShowTimer.restart();
                }
            }

            function handleEdgeExited() {
                peekShowTimer.stop();
                peekHideTimer.restart();
                if (ScreenEdges.modern) kickTimer();
            }

            Connections {
                target: (typeof Config !== "undefined") ? Config : null
                function onSettingsLoaded() {
                    floatingWidget.configRevision++;
                    if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
                        if (Config.rawSettings.bar.position !== undefined && Config.rawSettings.bar.position !== floatingWidget.barPosition) {
                            floatingWidget.disableAnim = true;
                            floatingWidget.barPosition = Config.rawSettings.bar.position;
                            positionChangeAnimTimer.restart();
                        }
                        if (Config.rawSettings.bar.autohide !== undefined) {
                            floatingWidget.barAutohide = Config.rawSettings.bar.autohide;
                        }
                    }
                }
                function onDataReadyChanged() { floatingWidget.configRevision++; }
                function onRawSettingsChanged() { floatingWidget.configRevision++; }
            }

            Timer {
                id: initAnimTimer
                interval: 500
                running: true
                onTriggered: floatingWidget.disableAnim = false
            }

            Timer {
                id: positionChangeAnimTimer
                interval: 350
                onTriggered: {
                    floatingWidget.disableAnim = false;
                }
            }

            onBarPositionChanged: {
                floatingWidget.disableAnim = true;
                positionChangeAnimTimer.restart();
            }

            onActiveEdgeChanged: {
                floatingWidget.disableAnim = true;
                isExpanded = false;
                isSidebarVisible = false;
                isPeekVisible = false;
                peekShowTimer.stop();
                hideTimer.stop();
                peekHideTimer.stop();
                positionChangeAnimTimer.restart();
            }

            Item {
                id: focusTracker
                focus: true
                Keys.onTabPressed: event => {
                    if (!floatingWidget.hasInputFocus && !floatingWidget.childIntercepts("Tab")) {
                        floatingWidget.activeIndex = (floatingWidget.activeIndex + 1) % floatingWidget.tabCount;
                        floatingWidget.kickTimer();
                        event.accepted = true;
                    }
                }
                Keys.onBacktabPressed: event => {
                    if (!floatingWidget.hasInputFocus && !floatingWidget.childIntercepts("Backtab")) {
                        floatingWidget.activeIndex = (floatingWidget.activeIndex + (floatingWidget.tabCount - 1)) % floatingWidget.tabCount;
                        floatingWidget.kickTimer();
                        event.accepted = true;
                    }
                }
                Keys.onPressed: event => {
                    if (event.accepted) return;
                    if (event.key === Qt.Key_Tab) {
                        if (!floatingWidget.hasInputFocus && !floatingWidget.childIntercepts("Tab")) {
                            floatingWidget.activeIndex = (floatingWidget.activeIndex + 1) % floatingWidget.tabCount;
                            floatingWidget.kickTimer();
                            event.accepted = true;
                        }
                    } else if (event.key === Qt.Key_Backtab) {
                        if (!floatingWidget.hasInputFocus && !floatingWidget.childIntercepts("Backtab")) {
                            floatingWidget.activeIndex = (floatingWidget.activeIndex + (floatingWidget.tabCount - 1)) % floatingWidget.tabCount;
                            floatingWidget.kickTimer();
                            event.accepted = true;
                        }
                    }
                }
            }

            property bool useGraceTimer: false
            property int hoveredBars: 0

            property var tabModules: floatingRoot.groups[activeEdge]
            onTabModulesChanged: {
                let previousIndex = tabModules.indexOf(selectedAction);
                activeIndex = previousIndex >= 0 ? previousIndex : Math.max(0, Math.min(activeIndex, tabModules.length - 1));
                selectedAction = tabModules[activeIndex] || "";
                if (tabModules.length === 0) {
                    isExpanded = false;
                    isSidebarVisible = false;
                    isPeekVisible = false;
                    peekShowTimer.stop();
                    peekHideTimer.stop();
                    hideTimer.stop();
                }
            }

            property int tabCount: Math.max(1, tabModules.length)

            function getTabInfo(index) {
                let mod = (index >= 0 && index < tabModules.length) ? tabModules[index] : "";
                let info = QuickActions.types[mod];
                if (info) return { name: I18n.t(info.label), icon: info.icon };
                return { name: I18n.t("quickactions.tabs.tab"), icon: "󰍜" };
            }

            function runAction(index) {
                let action = tabModules[index];
                if (action !== "launcher" && action !== "screenshot") return false;
                isExpanded = false;
                isSidebarVisible = false;
                isPeekVisible = false;
                hideTimer.stop();
                Qt.callLater(function() {
                    if (action === "launcher") {
                        ClipboardController.hide();
                        LauncherController.show();
                    } else {
                        Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/screenshot.sh"]);
                    }
                });
                return true;
            }

            function getTabName(index) {
                return getTabInfo(index).name;
            }

            function activateTab(index) {
                if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/clickbutton/click.wav");
                if (runAction(index)) return;
                if (activeIndex !== index) activeIndex = index;
                else isExpanded = !isExpanded;
            }

            function getTabIcon(index) {
                return getTabInfo(index).icon;
            }

            TextMetrics {
                id: settingsTabMetrics
                font.family: ThemeBackend.fontFamily
                font.pixelSize: floatingWidget.s(10)
                font.weight: Font.Bold
                text: I18n.t(QuickActions.types.settings.label)
            }

            Connections {
                target: FloatingController

                function onSetIndexRequested(screen, index) {
                    if (floatingWidget.matchesScreen(screen)) {
                        floatingWidget.setIndex(index);
                    }
                }

                function onShowSystemUsageRequested(screen, fromBar) {
                    if (floatingWidget.matchesScreen(screen)) {
                        floatingWidget.showSystemUsage(fromBar);
                    }
                }
            }

            function matchesScreen(targetScreen) {
                return targetScreen && floatingWidget.screen
                    && (targetScreen === floatingWidget.screen || targetScreen.name === floatingWidget.screen.name);
            }

            function setIndex(index) {
                let ids = QuickActions.positions.reduce((all, edge) => all.concat(floatingRoot.groups[edge]), []);
                let newIndex = tabModules.indexOf(ids[parseInt(index)]);
                if (newIndex >= 0) {
                    floatingWidget.activeIndex = newIndex;
                }
            }

            function showSystemUsage(fromBar) {
                floatingWidget.fromBar = !!fromBar;
                let sysIndex = floatingWidget.tabModules.indexOf("system");
                if (sysIndex < 0) return;
                floatingWidget.activeIndex = sysIndex;
                floatingWidget.useGraceTimer = true;
                floatingWidget.showSidebar(floatingWidget.activeEdge, true);
                hideTimer.restart();
            }

            function childIntercepts(sequenceStr) {
                if (!isExpanded) return false;
                if (activeModule && activeModule.interceptedShortcuts !== undefined) {
                    if (activeModule.interceptedShortcuts.includes(sequenceStr)) return true;
                    if ((sequenceStr === "Backtab" || sequenceStr === "Shift+Tab") &&
                        (activeModule.interceptedShortcuts.includes("Backtab") || activeModule.interceptedShortcuts.includes("Shift+Tab"))) {
                        return true;
                    }
                }
                return false;
            }

            function kickTimer() {
                if (!floatingWidget.hasInputFocus) {
                    if ((typeof mainHoverTracker !== "undefined" && mainHoverTracker.hovered) ||
                        (typeof sidebarDragArea !== "undefined" && (sidebarDragArea.containsMouse || sidebarDragArea.pressed)) ||
                        (typeof gridMouseArea !== "undefined" && (gridMouseArea.containsMouse || gridMouseArea.pressed)) ||
                        (typeof peekMouse !== "undefined" && (peekMouse.containsMouse || peekMouse.pressed)) ||
                        floatingWidget.hoveredBars > 0) {
                        return;
                    }
                    hideTimer.restart();
                }
            }

            Shortcut { enabled: floatingWidget.isSidebarVisible && !floatingWidget.hasInputFocus && !floatingWidget.childIntercepts("Tab"); sequence: "Tab"; onActivated: { floatingWidget.activeIndex = (floatingWidget.activeIndex + 1) % floatingWidget.tabCount; floatingWidget.kickTimer(); } }
            Shortcut { enabled: floatingWidget.isSidebarVisible && !floatingWidget.hasInputFocus && !floatingWidget.childIntercepts("Backtab"); sequences: ["Backtab", "Shift+Tab"]; onActivated: { floatingWidget.activeIndex = (floatingWidget.activeIndex + (floatingWidget.tabCount - 1)) % floatingWidget.tabCount; floatingWidget.kickTimer(); } }
            Shortcut { enabled: floatingWidget.isSidebarVisible && !floatingWidget.hasInputFocus && !floatingWidget.childIntercepts("Return"); sequence: "Return"; onActivated: { floatingWidget.isExpanded = !floatingWidget.isExpanded; floatingWidget.kickTimer(); } }
            Shortcut { enabled: floatingWidget.isSidebarVisible && !floatingWidget.hasInputFocus && !floatingWidget.childIntercepts("Enter"); sequence: "Enter"; onActivated: { floatingWidget.isExpanded = !floatingWidget.isExpanded; floatingWidget.kickTimer(); } }

            Shortcut {
                enabled: floatingWidget.isSidebarVisible && !floatingWidget.hasInputFocus && (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top") && !floatingWidget.childIntercepts("Left")
                sequence: "Left"
                onActivated: { floatingWidget.activeIndex = Math.max(0, floatingWidget.activeIndex - 1); floatingWidget.kickTimer(); }
            }
            Shortcut {
                enabled: floatingWidget.isSidebarVisible && !floatingWidget.hasInputFocus && (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top") && !floatingWidget.childIntercepts("Right")
                sequence: "Right"
                onActivated: { floatingWidget.activeIndex = Math.min(floatingWidget.tabCount - 1, floatingWidget.activeIndex + 1); floatingWidget.kickTimer(); }
            }
            Shortcut {
                enabled: floatingWidget.isSidebarVisible && !floatingWidget.hasInputFocus && (floatingWidget.activeEdge === "left" || floatingWidget.activeEdge === "right") && !floatingWidget.childIntercepts("Up")
                sequence: "Up"
                onActivated: {
                    let step = floatingWidget.activeEdge === "right" ? 1 : -1;
                    floatingWidget.activeIndex = Math.max(0, Math.min(floatingWidget.tabCount - 1, floatingWidget.activeIndex + step));
                    floatingWidget.kickTimer();
                }
            }
            Shortcut {
                enabled: floatingWidget.isSidebarVisible && !floatingWidget.hasInputFocus && (floatingWidget.activeEdge === "left" || floatingWidget.activeEdge === "right") && !floatingWidget.childIntercepts("Down")
                sequence: "Down"
                onActivated: {
                    let step = floatingWidget.activeEdge === "right" ? -1 : 1;
                    floatingWidget.activeIndex = Math.max(0, Math.min(floatingWidget.tabCount - 1, floatingWidget.activeIndex + step));
                    floatingWidget.kickTimer();
                }
            }

            Shortcut {
                enabled: floatingWidget.isSidebarVisible && !floatingWidget.childIntercepts("Escape")
                sequence: "Escape"
                onActivated: {
                    if (floatingWidget.hasInputFocus) {
                        floatingWidget.unfocusAllInputs();
                        return;
                    }
                    if (floatingWidget.isExpanded) {
                        floatingWidget.isExpanded = false;
                        floatingWidget.kickTimer();
                    } else {
                        floatingWidget.isSidebarVisible = false;
                        floatingWidget.isPeekVisible = true;
                        peekHideTimer.restart();
                    }
                }
            }

            function unfocusAllInputs() {
                if (typeof moduleRepeater !== "undefined") {
                    for (let i = 0; i < moduleRepeater.count; i++) {
                        let ldr = moduleRepeater.itemAt(i);
                        if (ldr && ldr.item && typeof ldr.item.unfocusInputs === "function") {
                            ldr.item.unfocusInputs();
                        }
                    }
                }
                if (isExpanded) {
                    focusTracker.forceActiveFocus();
                }
            }

            property real baseScale: Scaler.baseScale
            function s(val) {
                let res = Scaler.s(val);
                return isNaN(res) ? val : res;
            }

            property string selectedAction: ""
            property int activeIndex: Math.max(0, tabModules.indexOf("system"))
            onActiveIndexChanged: {
                selectedAction = tabModules[activeIndex] || "";
                unfocusAllInputs();
                let info = QuickActions.types[tabModules[activeIndex]];
                if (info && !info.file) isExpanded = false;
            }
            property bool isExpanded: false
            onIsExpandedChanged: {
                if (isExpanded) {
                    if (runAction(activeIndex)) return;
                    grabKeyboardFocus();
                    Qt.callLater(grabKeyboardFocus);
                }
            }

            property var currentLayoutTemplate: [{x: 0, y: 0, w: 1, h: 1}]

            function evaluateDrag(gpStartX, gpStartY, gpMouseX, gpMouseY) {
                let delta = 0;
                if (activeEdge === "left") delta = gpMouseX - gpStartX;
                else if (activeEdge === "right") delta = gpStartX - gpMouseX;
                else if (activeEdge === "bottom") delta = gpStartY - gpMouseY;
                else if (activeEdge === "top") delta = gpMouseY - gpStartY;

                if (delta > s(30) && !isExpanded) {
                    isExpanded = true;
                } else if (delta < -s(30) && (isExpanded || isSidebarVisible)) {
                    isExpanded = false;
                    isSidebarVisible = false;
                    isPeekVisible = true;
                    peekHideTimer.restart();
                }
            }

            property real containerRadius: s(16)
            property real outerCornerRadius: s(24)
            property real edgeBleed: Math.max(2, Math.ceil(s(2)))

            property real tabLength: Math.max(Math.round(s(54)), Math.round(settingsTabMetrics.width + s(20)))
            property real itemSpacing: s(7)

            function getTargetY(idx) {
                return (baseSidebarH - tabGroupHeight) / 2 + idx * (tabLength + itemSpacing);
            }

            property real baseExpandedWidth: s(340)
            property real baseExpandedExtraLength: s(200)
            property real expandedPadding: s(4)

            property real targetExpandedExtraLength: baseExpandedExtraLength

            property real expandedWidth: baseExpandedWidth
            property real expandedExtraLength: baseExpandedExtraLength

            Behavior on expandedWidth { enabled: !floatingWidget.disableAnim; NumberAnimation { duration: 450; easing.type: Easing.OutQuart } }
            Behavior on expandedExtraLength { enabled: !floatingWidget.disableAnim; NumberAnimation { duration: 450; easing.type: Easing.OutQuart } }

            property real expandProgress: isExpanded ? 1.0 : 0.0
            Behavior on expandProgress {
                enabled: !floatingWidget.disableAnim
                NumberAnimation { duration: 450; easing.type: Easing.OutQuart }
            }

            property real visibleProgress: isSidebarVisible ? 1.0 : 0.0
            Behavior on visibleProgress {
                enabled: !floatingWidget.disableAnim
                NumberAnimation { duration: 380; easing.type: Easing.OutQuart }
            }

            property real currentExtraWidth: (expandedWidth + expandedPadding) * expandProgress
            property real currentExtraLength: expandedExtraLength * expandProgress

            property real totalSidebarWidth: sidebarW + currentExtraWidth

            property var activeMaskAABB: {
                if (!floatingWidget.isSidebarVisible && floatingWidget.visibleProgress <= 0.001) return Qt.rect(0, 0, 0, 0);
                let cw = sidebarContainer.width;
                let ch = sidebarContainer.height;
                let cx = sidebarContainer.x + cw / 2;
                let cy = sidebarContainer.y + ch / 2;

                let innerW = floatingWidget.sidebarW + floatingWidget.currentExtraWidth;
                let innerH = floatingWidget.baseSidebarH + floatingWidget.currentExtraLength;

                let outerR = floatingWidget.outerCornerRadius;
                let buffer = floatingWidget.s(6);

                let relMinX = -cw / 2 - buffer;
                let relMaxX = -cw / 2 + innerW + buffer;
                let relMinY = -innerH / 2 - outerR - buffer;
                let relMaxY = innerH / 2 + outerR + buffer;

                let rot = floatingWidget.targetRotation;
                let aabbX = 0, aabbY = 0, aabbW = 0, aabbH = 0;

                if (rot === 0) {
                    aabbX = cx + relMinX;
                    aabbY = cy + relMinY;
                    aabbW = relMaxX - relMinX;
                    aabbH = relMaxY - relMinY;
                } else if (rot === 180) {
                    aabbX = cx - relMaxX;
                    aabbY = cy - relMaxY;
                    aabbW = relMaxX - relMinX;
                    aabbH = relMaxY - relMinY;
                } else if (rot === -90) {
                    aabbX = cx + relMinY;
                    aabbY = cy - relMaxX;
                    aabbW = relMaxY - relMinY;
                    aabbH = relMaxX - relMinX;
                } else if (rot === 90) {
                    aabbX = cx - relMaxY;
                    aabbY = cy + relMinX;
                    aabbW = relMaxY - relMinY;
                    aabbH = relMaxX - relMinX;
                } else {
                    aabbW = innerW + buffer * 2;
                    aabbH = innerH + outerR * 2 + buffer * 2;
                    aabbX = cx - aabbW / 2;
                    aabbY = cy - aabbH / 2;
                }

                return Qt.rect(aabbX, aabbY, aabbW, aabbH);
            }

            mask: Region {
                item: floatingWidget.needsPopupInput ? floatingWidget.contentItem : null
                Region {
                    x: floatingWidget.topEdgeA_x
                    y: 0
                    width: floatingWidget.topEdgeA_w
                    height: floatingWidget.topEdgeA_w > 0 ? floatingWidget.edgeHitSize : 0
                }
                Region {
                    x: floatingWidget.topEdgeB_x
                    y: 0
                    width: floatingWidget.topEdgeB_w
                    height: floatingWidget.topEdgeB_w > 0 ? floatingWidget.edgeHitSize : 0
                }
                Region {
                    x: floatingWidget.bottomEdgeA_x
                    y: floatingWidget.height - floatingWidget.edgeHitSize
                    width: floatingWidget.bottomEdgeA_w
                    height: floatingWidget.bottomEdgeA_w > 0 ? floatingWidget.edgeHitSize : 0
                }
                Region {
                    x: floatingWidget.bottomEdgeB_x
                    y: floatingWidget.height - floatingWidget.edgeHitSize
                    width: floatingWidget.bottomEdgeB_w
                    height: floatingWidget.bottomEdgeB_w > 0 ? floatingWidget.edgeHitSize : 0
                }
                Region {
                    x: 0
                    y: floatingWidget.leftEdgeA_y
                    width: floatingWidget.edgeHitSize
                    height: floatingWidget.leftEdgeA_h
                }
                Region {
                    x: 0
                    y: floatingWidget.leftEdgeB_y
                    width: floatingWidget.edgeHitSize
                    height: floatingWidget.leftEdgeB_h
                }
                Region {
                    x: floatingWidget.width - floatingWidget.edgeHitSize
                    y: floatingWidget.rightEdgeA_y
                    width: floatingWidget.edgeHitSize
                    height: floatingWidget.rightEdgeA_h
                }
                Region {
                    x: floatingWidget.width - floatingWidget.edgeHitSize
                    y: floatingWidget.rightEdgeB_y
                    width: floatingWidget.edgeHitSize
                    height: floatingWidget.rightEdgeB_h
                }

                Region {
                    x: floatingWidget.isPeekVisible ? peekBar.x - floatingWidget.s(8) : 0
                    y: floatingWidget.isPeekVisible ? peekBar.y - floatingWidget.s(8) : 0
                    width: floatingWidget.isPeekVisible ? peekBar.width + floatingWidget.s(16) : 0
                    height: floatingWidget.isPeekVisible ? peekBar.height + floatingWidget.s(16) : 0
                }

                Region {
                    x: (floatingWidget.isSidebarVisible || floatingWidget.visibleProgress > 0.001) ? floatingWidget.activeMaskAABB.x : 0
                    y: (floatingWidget.isSidebarVisible || floatingWidget.visibleProgress > 0.001) ? floatingWidget.activeMaskAABB.y : 0
                    width: (floatingWidget.isSidebarVisible || floatingWidget.visibleProgress > 0.001) ? floatingWidget.activeMaskAABB.width : 0
                    height: (floatingWidget.isSidebarVisible || floatingWidget.visibleProgress > 0.001) ? floatingWidget.activeMaskAABB.height : 0
                }
                Region {
                    intersection: Intersection.Subtract
                    x: floatingWidget.attachedBar ? floatingWidget.attachedBar.frameTriggerRect.x : 0
                    y: floatingWidget.attachedBar ? floatingWidget.attachedBar.frameTriggerRect.y : 0
                    width: floatingWidget.attachedBar && floatingWidget.attachedBar.frameTriggerActive ? floatingWidget.attachedBar.frameTriggerRect.width : 0
                    height: floatingWidget.attachedBar && floatingWidget.attachedBar.frameTriggerActive ? floatingWidget.attachedBar.frameTriggerRect.height : 0
                }
            }

            function safeClampX(pos, margin) {
                let minCenter = leftBound + margin;
                let maxCenter = rightBound - margin;
                if (minCenter <= maxCenter) {
                    return Math.max(minCenter, Math.min(maxCenter, pos));
                } else {
                    return (leftBound + rightBound) / 2;
                }
            }

            function safeClampY(pos, margin) {
                let minCenter = topBound + margin;
                let maxCenter = bottomBound - margin;
                if (minCenter <= maxCenter) {
                    return Math.max(minCenter, Math.min(maxCenter, pos));
                } else {
                    return (topBound + bottomBound) / 2;
                }
            }

            property real targetEdgeMargin: {
                let length = baseSidebarH;
                if (isExpanded) {
                    length += targetExpandedExtraLength;
                }
                return (length / 2) + outerCornerRadius + s(5);
            }

            property real clampedCenterX: safeClampX(floatingWidget.width / 2, targetEdgeMargin)
            property real clampedCenterY: safeClampY(floatingWidget.height / 2, targetEdgeMargin)

            property bool isSidebarVisible: false
            property bool isPeekVisible: false
            property bool disableAnim: true

            readonly property string activeEdge: modelData.edge

            property real tabGroupHeight: tabModules.length * tabLength + Math.max(0, tabModules.length - 1) * itemSpacing + s(12)
            property real baseSidebarH: floatingRoot.stripSlotCount * tabLength + (floatingRoot.stripSlotCount - 1) * itemSpacing + s(12)

            property real sidebarW: Math.round(s(35))

            property real sidebarTargetX: {
                if (activeEdge === "left") {
                    let hiddenX = leftBound - sidebarW - s(20);
                    let shownX = Math.round(leftBound);
                    return hiddenX + (shownX - hiddenX) * visibleProgress;
                }
                if (activeEdge === "right") {
                    let hiddenX = rightBound + s(20);
                    let shownX = Math.round(rightBound - sidebarW);
                    return hiddenX + (shownX - hiddenX) * visibleProgress;
                }
                if (activeEdge === "bottom" || activeEdge === "top") return Math.round(clampedCenterX - sidebarW / 2);
                return 0;
            }

            property real sidebarTargetY: {
                if (activeEdge === "left" || activeEdge === "right") return Math.round(clampedCenterY - baseSidebarH / 2);
                if (activeEdge === "bottom") {
                    let hiddenY = bottomBound + s(10) - baseSidebarH / 2 + sidebarW / 2;
                    let shownY = Math.round(bottomBound - sidebarW / 2 - baseSidebarH / 2);
                    return hiddenY + (shownY - hiddenY) * visibleProgress;
                }
                if (activeEdge === "top") {
                    let hiddenY = topBound - baseSidebarH - s(20);
                    let shownY = Math.round(topBound + sidebarW / 2 - baseSidebarH / 2);
                    return hiddenY + (shownY - hiddenY) * visibleProgress;
                }
                return 0;
            }

            property real targetRotation: {
                if (activeEdge === "left") return 0;
                if (activeEdge === "right") return 180;
                if (activeEdge === "bottom") return -90;
                if (activeEdge === "top") return 90;
                return 0;
            }

            function showPeek(edge) {
                SysData.prewarm();
                if (isSidebarVisible || edge !== activeEdge) return;
                isPeekVisible = true;
                peekHideTimer.stop();
            }

            function showSidebar(edge, expand) {
                SysData.prewarm();
                if (edge !== activeEdge) return;
                isSidebarVisible = true;
                if (typeof expand === "boolean") {
                    isExpanded = expand;
                }
                isPeekVisible = false;
                hideTimer.restart();
                floatingWidget.grabKeyboardFocus();
                Qt.callLater(floatingWidget.grabKeyboardFocus);
            }

            Timer {
                id: peekHideTimer
                interval: 50
                onTriggered: {
                    if (typeof peekMouse !== "undefined" && peekMouse.pressed) {
                        peekHideTimer.restart();
                        return;
                    }
                    if (!peekMouse.containsMouse && !floatingWidget.isAnyEdgeHovered) {
                        floatingWidget.isPeekVisible = false;
                    }
                }
            }

            Timer {
                id: hideTimer
                interval: floatingWidget.useGraceTimer ? 3000 : 800
                onTriggered: {
                    if (floatingWidget.hasInputFocus) return;
                    if (ScreenEdges.modern && floatingWidget.isAnyEdgeHovered) return;

                    if ((typeof sidebarDragArea !== "undefined" && sidebarDragArea.pressed) ||
                        (typeof peekMouse !== "undefined" && peekMouse.pressed) ||
                        (typeof gridMouseArea !== "undefined" && gridMouseArea.pressed)) {
                        hideTimer.restart();
                        return;
                    }

                    floatingWidget.isExpanded = false;
                    floatingWidget.isSidebarVisible = false;
                    floatingWidget.useGraceTimer = false;
                }
            }

            Timer {
                id: peekShowTimer
                interval: 300
                onTriggered: {
                    if (floatingWidget.isSidebarVisible) {
                        floatingWidget.showSidebar(floatingWidget.activeEdge);
                    } else {
                        floatingWidget.showPeek(floatingWidget.activeEdge);
                    }
                }
            }

            Item {
                id: mainHitArea
                anchors.fill: parent
                z: 1

                MouseArea {
                    id: topEdgeA
                    x: floatingWidget.topEdgeA_x
                    y: 0
                    width: floatingWidget.topEdgeA_w
                    height: floatingWidget.edgeHitSize
                    hoverEnabled: true
                    enabled: width > 0
                    onEntered: floatingWidget.handleEdgeEntered("top")
                    onExited: floatingWidget.handleEdgeExited()
                }

                MouseArea {
                    id: topEdgeB
                    x: floatingWidget.topEdgeB_x
                    y: 0
                    width: floatingWidget.topEdgeB_w
                    height: floatingWidget.edgeHitSize
                    hoverEnabled: true
                    enabled: width > 0
                    onEntered: floatingWidget.handleEdgeEntered("top")
                    onExited: floatingWidget.handleEdgeExited()
                }

                MouseArea {
                    id: bottomEdgeA
                    x: floatingWidget.bottomEdgeA_x
                    y: floatingWidget.height - floatingWidget.edgeHitSize
                    width: floatingWidget.bottomEdgeA_w
                    height: floatingWidget.edgeHitSize
                    hoverEnabled: true
                    enabled: width > 0
                    onEntered: floatingWidget.handleEdgeEntered("bottom")
                    onExited: floatingWidget.handleEdgeExited()
                }

                MouseArea {
                    id: bottomEdgeB
                    x: floatingWidget.bottomEdgeB_x
                    y: floatingWidget.height - floatingWidget.edgeHitSize
                    width: floatingWidget.bottomEdgeB_w
                    height: floatingWidget.edgeHitSize
                    hoverEnabled: true
                    enabled: width > 0
                    onEntered: floatingWidget.handleEdgeEntered("bottom")
                    onExited: floatingWidget.handleEdgeExited()
                }

                MouseArea {
                    id: leftEdgeA
                    x: 0
                    y: floatingWidget.leftEdgeA_y
                    width: floatingWidget.edgeHitSize
                    height: floatingWidget.leftEdgeA_h
                    hoverEnabled: true
                    enabled: height > 0
                    onEntered: floatingWidget.handleEdgeEntered("left")
                    onExited: floatingWidget.handleEdgeExited()
                }

                MouseArea {
                    id: leftEdgeB
                    x: 0
                    y: floatingWidget.leftEdgeB_y
                    width: floatingWidget.edgeHitSize
                    height: floatingWidget.leftEdgeB_h
                    hoverEnabled: true
                    enabled: height > 0
                    onEntered: floatingWidget.handleEdgeEntered("left")
                    onExited: floatingWidget.handleEdgeExited()
                }

                MouseArea {
                    id: rightEdgeA
                    x: floatingWidget.width - floatingWidget.edgeHitSize
                    y: floatingWidget.rightEdgeA_y
                    width: floatingWidget.edgeHitSize
                    height: floatingWidget.rightEdgeA_h
                    hoverEnabled: true
                    enabled: height > 0
                    onEntered: floatingWidget.handleEdgeEntered("right")
                    onExited: floatingWidget.handleEdgeExited()
                }

                MouseArea {
                    id: rightEdgeB
                    x: floatingWidget.width - floatingWidget.edgeHitSize
                    y: floatingWidget.rightEdgeB_y
                    width: floatingWidget.edgeHitSize
                    height: floatingWidget.rightEdgeB_h
                    hoverEnabled: true
                    enabled: height > 0
                    onEntered: floatingWidget.handleEdgeEntered("right")
                    onExited: floatingWidget.handleEdgeExited()
                }
            }

            property real peekBarLength: Math.max(floatingWidget.s(20), (floatingWidget.baseSidebarH - floatingWidget.s(20)) * 0.75)

            Rectangle {
                id: peekBar
                visible: !ScreenEdges.modern
                width: (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top") ? peekBarLength : floatingWidget.s(11)
                height: (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top") ? floatingWidget.s(11) : peekBarLength
                radius: Math.min(floatingWidget.containerRadius, Math.min(width, height) / 2)

                color: Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 1.0)
                border.width: 0

                opacity: 1.0
                scale: floatingWidget.isPeekVisible ? 1.0 : 0.6

                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }

                x: {
                    let offscreen = 0, visibleX = 0;
                    if (floatingWidget.activeEdge === "left") {
                        offscreen = leftBound - width - floatingWidget.s(10);
                        visibleX = leftBound + floatingWidget.s(4);
                        return floatingWidget.isPeekVisible ? visibleX : offscreen;
                    }
                    if (floatingWidget.activeEdge === "right") {
                        offscreen = rightBound + floatingWidget.s(10);
                        visibleX = rightBound - width - floatingWidget.s(4);
                        return floatingWidget.isPeekVisible ? visibleX : offscreen;
                    }
                    if (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top") return floatingWidget.width / 2 - width / 2;
                    return 0;
                }

                y: {
                    let offscreen = 0, visibleY = 0;
                    if (floatingWidget.activeEdge === "bottom") {
                        offscreen = bottomBound + floatingWidget.s(10);
                        visibleY = bottomBound - height - floatingWidget.s(4);
                        return floatingWidget.isPeekVisible ? visibleY : offscreen;
                    }
                    if (floatingWidget.activeEdge === "top") {
                        offscreen = topBound - height - floatingWidget.s(10);
                        visibleY = topBound + floatingWidget.s(4);
                        return floatingWidget.isPeekVisible ? visibleY : offscreen;
                    }
                    if (floatingWidget.activeEdge === "left" || floatingWidget.activeEdge === "right") return floatingWidget.height / 2 - height / 2;
                    return 0;
                }

                Behavior on x { enabled: !floatingWidget.disableAnim && !peekMouse.pressed && floatingWidget.isPeekVisible; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }
                Behavior on y { enabled: !floatingWidget.disableAnim && !peekMouse.pressed && floatingWidget.isPeekVisible; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

                Rectangle {
                    anchors.centerIn: parent
                    width: (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top") ? floatingWidget.s(20) : floatingWidget.s(3.5)
                    height: (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top") ? floatingWidget.s(3.5) : floatingWidget.s(20)
                    radius: Math.min(ThemeBackend.borderRadius, Math.min(width, height) / 2)
                    color: Qt.darker(ThemeBackend.mauve, 1.8)
                }

                MouseArea {
                    id: peekMouse
                    anchors.fill: parent
                    anchors.margins: -floatingWidget.s(15)
                    hoverEnabled: true
                    enabled: floatingWidget.isPeekVisible || pressed

                    property real startGlobalX: 0
                    property real startGlobalY: 0
                    property real currentDragDelta: 0

                    onEntered: { floatingWidget.isPeekVisible = true; peekHideTimer.stop(); }
                    onExited: { if (!pressed) peekHideTimer.restart(); }

                    onPressed: mouse => {
                        let gp = mapToItem(mainHitArea, mouse.x, mouse.y);
                        startGlobalX = gp.x;
                        startGlobalY = gp.y;
                        currentDragDelta = 0;
                        floatingWidget.useGraceTimer = true;
                    }

                    onPositionChanged: mouse => {
                        if (!pressed) return;

                        let gp = mapToItem(mainHitArea, mouse.x, mouse.y);
                        let delta = 0;

                        if (floatingWidget.activeEdge === "left") delta = gp.x - startGlobalX;
                        else if (floatingWidget.activeEdge === "right") delta = startGlobalX - gp.x;
                        else if (floatingWidget.activeEdge === "bottom") delta = startGlobalY - gp.y;
                        else if (floatingWidget.activeEdge === "top") delta = gp.y - startGlobalY;

                        currentDragDelta = delta;

                        if (delta > floatingWidget.s(15) && !floatingWidget.isExpanded) {
                            floatingWidget.showSidebar(floatingWidget.activeEdge);
                            floatingWidget.isExpanded = true;
                        } else if (delta < -floatingWidget.s(10) && floatingWidget.isPeekVisible) {
                            floatingWidget.isPeekVisible = false;
                        }
                    }

                    onReleased: {
                        currentDragDelta = 0;
                        peekHideTimer.restart();
                    }

                    onClicked: {
                        if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/clickbutton/click.wav");
                        floatingWidget.showSidebar(floatingWidget.activeEdge);
                    }
                }
            }

            Item {
                id: sidebarContainer

                width: floatingWidget.sidebarW
                height: floatingWidget.baseSidebarH

                visible: floatingWidget.isSidebarVisible || floatingWidget.visibleProgress > 0.001

                transformOrigin: Item.Center
                rotation: floatingWidget.targetRotation
                Behavior on rotation { enabled: !floatingWidget.disableAnim && floatingWidget.isSidebarVisible; NumberAnimation { duration: 250; easing.type: Easing.OutExpo } }

                x: floatingWidget.sidebarTargetX
                y: floatingWidget.sidebarTargetY

                Behavior on x {
                    enabled: !floatingWidget.disableAnim && floatingWidget.isSidebarVisible && (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top")
                    NumberAnimation { duration: 350; easing.type: Easing.OutExpo }
                }

                Behavior on y {
                    enabled: !floatingWidget.disableAnim && floatingWidget.isSidebarVisible && (floatingWidget.activeEdge === "left" || floatingWidget.activeEdge === "right")
                    NumberAnimation { duration: 350; easing.type: Easing.OutExpo }
                }

                Item {
                    id: morphOrigin
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    width: floatingWidget.sidebarW + floatingWidget.currentExtraWidth
                    height: floatingWidget.baseSidebarH + floatingWidget.currentExtraLength

                    HoverHandler {
                        id: mainHoverTracker
                        onHoveredChanged: {
                            if (hovered) {
                                floatingWidget.useGraceTimer = false;
                                hideTimer.stop();
                            } else {
                                floatingWidget.kickTimer();
                            }
                        }
                    }

                    GlassFillets {
                        card: morphingBackground
                        filletRadius: floatingWidget.outerCornerRadius
                        filletInset: floatingWidget.edgeBleed
                        filletDir: Qt.vector2d(-1, 0)
                    }

                    ShaderEffect {
                        visible: !actionGlass.active && floatingWidget.outerCornerRadius > 0.5
                        x: 0
                        y: -floatingWidget.outerCornerRadius
                        width: floatingWidget.outerCornerRadius
                        height: floatingWidget.outerCornerRadius
                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real cornerIndex: 2.0
                        property color color: Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.95)
                        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
                    }

                    ShaderEffect {
                        visible: !actionGlass.active && floatingWidget.outerCornerRadius > 0.5
                        x: 0
                        y: parent.height
                        width: floatingWidget.outerCornerRadius
                        height: floatingWidget.outerCornerRadius
                        property vector2d itemSize: Qt.vector2d(width, height)
                        property real cornerIndex: 0.0
                        property color color: Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.95)
                        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
                    }
                    Rectangle {
                        id: morphingBackground
                        x: -floatingWidget.edgeBleed
                        y: 0
                        width: parent.width + floatingWidget.edgeBleed
                        height: parent.height
                        radius: floatingWidget.containerRadius
                        topLeftRadius: 0
                        bottomLeftRadius: 0
                        topRightRadius: floatingWidget.containerRadius
                        bottomRightRadius: floatingWidget.containerRadius
                        color: actionGlass.active ? "transparent" : Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 1.0)
                        WallpaperBlur {
                            id: actionGlass
                            anchors.fill: parent
                            topLeftRadius: parent.topLeftRadius
                            topRightRadius: parent.topRightRadius
                            bottomLeftRadius: parent.bottomLeftRadius
                            bottomRightRadius: parent.bottomRightRadius
                        }
                        border.width: 0

                        MouseArea {
                            id: sidebarDragArea
                            anchors.fill: parent
                            anchors.margins: floatingWidget.isExpanded ? -floatingWidget.s(20) : -floatingWidget.s(4)
                            hoverEnabled: true
                            enabled: floatingWidget.isSidebarVisible

                            property real startGlobalX: 0
                            property real startGlobalY: 0

                            onEntered: hideTimer.stop()
                            onExited: { if (!pressed && !gridMouseArea.containsMouse) floatingWidget.kickTimer(); }
                            onPressed: mouse => {
                                let gp = mapToItem(mainHitArea, mouse.x, mouse.y);
                                startGlobalX = gp.x;
                                startGlobalY = gp.y;
                                floatingWidget.useGraceTimer = true;
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return;
                                let gp = mapToItem(mainHitArea, mouse.x, mouse.y);
                                floatingWidget.evaluateDrag(startGlobalX, startGlobalY, gp.x, gp.y);
                            }
                            onReleased: { if (!containsMouse) floatingWidget.kickTimer(); }
                        }
                    }

                    Item {
                        id: expandedContainer
                        x: floatingWidget.sidebarW
                        y: 0
                        height: parent.height
                        width: floatingWidget.currentExtraWidth
                        opacity: floatingWidget.expandProgress
                        clip: true

                        component EmptyBlock : Rectangle {
                            radius: Math.min(floatingWidget.s(10), Math.min(width, height) / 2)
                            color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.05)
                            border.width: 0
                            border.color: Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.08)
                            clip: true
                        }

                        Item {
                            anchors.fill: parent
                            anchors.topMargin: floatingWidget.s(4)
                            anchors.bottomMargin: floatingWidget.s(4)
                            anchors.leftMargin: floatingWidget.s(4)
                            anchors.rightMargin: floatingWidget.s(4)
                            visible: floatingWidget.expandProgress > 0.01

                            Item {
                                anchors.centerIn: parent
                                width: (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top") ? parent.height : parent.width
                                height: (floatingWidget.activeEdge === "bottom" || floatingWidget.activeEdge === "top") ? parent.width : parent.height
                                rotation: floatingWidget.activeEdge === "right" ? 180 : (floatingWidget.activeEdge === "bottom" ? 90 : (floatingWidget.activeEdge === "top" ? -90 : 0))

                                property real sp: floatingWidget.s(6)
                                property real cw: Math.max(0, width)
                                property real ch: Math.max(0, height)

                                Repeater {
                                    model: floatingWidget.currentLayoutTemplate
                                    delegate: EmptyBlock {
                                        x: (modelData.x * parent.cw) + (modelData.x > 0 ? parent.sp / 2 : 0)
                                        y: (modelData.y * parent.ch) + (modelData.y > 0 ? parent.sp / 2 : 0)
                                        width: (modelData.w * parent.cw) - ((modelData.x > 0 ? parent.sp / 2 : 0) + ((modelData.x + modelData.w) < 0.99 ? parent.sp / 2 : 0))
                                        height: (modelData.h * parent.ch) - ((modelData.y > 0 ? parent.sp / 2 : 0) + ((modelData.y + modelData.h) < 0.99 ? parent.sp / 2 : 0))
                                    }
                                }
                            }
                        }

                        Repeater {
                            id: moduleRepeater
                            model: Object.keys(QuickActions.types)

                            delegate: Loader {
                                id: contentLoader
                                z: 10
                                anchors.fill: parent
                                anchors.margins: modelData === "settings" ? 0 : floatingWidget.s(4)

                                visible: isCurrentTarget && floatingWidget.expandProgress > 0.01
                                source: QuickActions.types[modelData].file
                                active: floatingWidget.tabModules.indexOf(modelData) >= 0 && (modelData !== "settings" || settingsOpened || (isCurrentTarget && floatingWidget.isExpanded))
                                asynchronous: modelData === "settings"

                                property var scaleFunc: floatingWidget.s
                                property var mochaColors: ThemeBackend
                                property string activeEdge: floatingWidget.activeEdge
                                property real availableWidth: Math.max(0, floatingWidget.rightBound - floatingWidget.leftBound - floatingWidget.sidebarW - floatingWidget.outerCornerRadius * 2 - floatingWidget.s(16))
                                property real availableHeight: Math.max(0, floatingWidget.bottomBound - floatingWidget.topBound - floatingWidget.sidebarW - floatingWidget.outerCornerRadius * 2 - floatingWidget.s(16))
                                property real sidebarLength: floatingWidget.baseSidebarH

                                property bool isCurrentTarget: modelData === floatingWidget.tabModules[floatingWidget.activeIndex]
                                property bool settingsOpened: false
                                property real modWidth: (status === Loader.Ready && item && item.preferredWidth !== undefined) ? item.preferredWidth : floatingWidget.baseExpandedWidth
                                property real modExt: {
                                    let extra = (status === Loader.Ready && item && item.preferredExtraLength !== undefined) ? item.preferredExtraLength : floatingWidget.baseExpandedExtraLength;
                                    if (modelData === "settings") return extra;
                                    return Math.max(0, extra - (floatingWidget.baseSidebarH - floatingWidget.tabGroupHeight));
                                }

                                property var modLayout: {
                                    if (status === Loader.Ready && item && item.requestedLayoutTemplate !== undefined) {
                                        let req = item.requestedLayoutTemplate;
                                        if (typeof req === "number") {
                                            if (req === 0) return [ {x:0, y:0, w:0.5, h:0.5}, {x:0.5, y:0, w:0.5, h:0.5}, {x:0, y:0.5, w:0.5, h:0.5}, {x:0.5, y:0.5, w:0.5, h:0.5} ];
                                            else return [ {x:0, y:0, w:1, h:1} ];
                                        }
                                        return req;
                                    }
                                    return [ {x:0, y:0, w:1, h:1} ];
                                }

                                function updateSizes() {
                                    if (isCurrentTarget) {
                                        floatingWidget.targetExpandedExtraLength = modExt;
                                        floatingWidget.expandedWidth = modWidth;
                                        floatingWidget.expandedExtraLength = modExt;
                                        floatingWidget.currentLayoutTemplate = modLayout;
                                    }
                                }

                                onLoaded: {
                                    if (modelData === "settings") settingsOpened = true;
                                    updateSizes();
                                }
                                onActiveChanged: {
                                    if (!active) settingsOpened = false;
                                }
                                onIsCurrentTargetChanged: updateSizes()
                                onModWidthChanged: updateSizes()
                                onModExtChanged: updateSizes()
                                onModLayoutChanged: updateSizes()
                                Component.onCompleted: updateSizes()

                                Connections {
                                    target: contentLoader.item
                                    ignoreUnknownSignals: true
                                    function onCloseRequested() {
                                        floatingWidget.isExpanded = false;
                                        floatingWidget.kickTimer();
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: gridMouseArea
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true

                            onEntered: hideTimer.stop()
                            onExited: { if (!sidebarDragArea.containsMouse) floatingWidget.kickTimer(); }
                            onWheel: wheel => {
                                let step = 0;
                                if (wheel.angleDelta.y > 0) step = (floatingWidget.activeEdge === "right" || floatingWidget.activeEdge === "top") ? 1 : -1;
                                else if (wheel.angleDelta.y < 0) step = (floatingWidget.activeEdge === "right" || floatingWidget.activeEdge === "top") ? -1 : 1;

                                if (step !== 0) {
                                    floatingWidget.activeIndex = Math.max(0, Math.min(floatingWidget.tabCount - 1, floatingWidget.activeIndex + step));
                                }
                            }
                        }
                    }

                    Item {
                        id: staticContentWrapper
                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: floatingWidget.sidebarW
                        height: floatingWidget.baseSidebarH

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: floatingWidget.s(4)
                            anchors.rightMargin: floatingWidget.s(4)
                            anchors.topMargin: floatingWidget.s(6)
                            anchors.bottomMargin: floatingWidget.s(6)

                            Rectangle {
                                id: activeHighlight
                                x: 0
                                width: parent.width
                                z: 0
                                radius: width / 2
                                color: ThemeBackend.mauve

                                property int prevIdx: 0
                                property int curIdx: floatingWidget.activeIndex

                                onCurIdxChanged: {
                                    if (curIdx > prevIdx) { bottomAnim.duration = 200; topAnim.duration = 350; }
                                    else if (curIdx < prevIdx) { topAnim.duration = 200; bottomAnim.duration = 350; }
                                    prevIdx = curIdx;
                                }

                                property real targetTop: floatingWidget.getTargetY(curIdx)
                                property real targetBottom: targetTop + floatingWidget.tabLength

                                property real actualTop: targetTop
                                property real actualBottom: targetBottom

                                Behavior on actualTop { enabled: !floatingWidget.disableAnim; NumberAnimation { id: topAnim; duration: 250; easing.type: Easing.OutExpo } }
                                Behavior on actualBottom { enabled: !floatingWidget.disableAnim; NumberAnimation { id: bottomAnim; duration: 250; easing.type: Easing.OutExpo } }

                                y: actualTop
                                height: actualBottom - actualTop
                            }

                            Repeater {
                                model: floatingWidget.tabCount
                                delegate: Rectangle {
                                    id: barPill
                                    objectName: "quick-action-" + floatingWidget.tabModules[index]
                                    Accessible.role: Accessible.Button
                                    Accessible.name: floatingWidget.getTabName(index)
                                    Accessible.onPressAction: floatingWidget.activateTab(index)
                                    property bool isActive: floatingWidget.activeIndex === index
                                    property bool isHovered: barMouse.containsMouse
                                    property bool isPressed: barMouse.pressed

                                    x: 0
                                    width: parent.width
                                    radius: width / 2
                                    z: 1

                                    y: floatingWidget.getTargetY(index)
                                    Behavior on y { enabled: !floatingWidget.disableAnim; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

                                    height: floatingWidget.tabLength
                                    Behavior on height { enabled: !floatingWidget.disableAnim; NumberAnimation { duration: 350; easing.type: Easing.OutExpo } }

                                    color: isActive ? "transparent" : (isPressed ? Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.4) : (isHovered ? Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.25) : Qt.rgba(ThemeBackend.text.r, ThemeBackend.text.g, ThemeBackend.text.b, 0.15)))
                                    Behavior on color { ColorAnimation { duration: 250 } }

                                    scale: isActive ? 1.0 : (isPressed ? 0.95 : (isHovered ? 1.05 : 1.0))
                                    Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }

                                    Item {
                                        id: tabIconItem
                                        anchors.centerIn: parent
                                        width: parent.width
                                        height: parent.width

                                        Text {
                                            anchors.centerIn: parent
                                            font.family: ThemeBackend.iconFont
                                            font.pixelSize: floatingWidget.s(14)
                                            font.bold: true
                                            color: barPill.isActive ? ThemeBackend.crust : (barPill.isHovered ? ThemeBackend.text : ThemeBackend.subtext0)
                                            text: floatingWidget.getTabIcon(index)
                                            rotation: floatingWidget.activeEdge === "right" ? 180 : (floatingWidget.activeEdge === "bottom" ? 90 : (floatingWidget.activeEdge === "top" ? -90 : 0))
                                        }
                                    }

                                    MouseArea {
                                        id: barMouse
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        property real startGlobalX: 0
                                        property real startGlobalY: 0
                                        property bool isDragging: false

                                        onEntered: { floatingWidget.hoveredBars++; hideTimer.stop(); }
                                        onExited: { floatingWidget.hoveredBars = Math.max(0, floatingWidget.hoveredBars - 1); floatingWidget.kickTimer(); }

                                        onPressed: mouse => {
                                            let gp = mapToItem(mainHitArea, mouse.x, mouse.y);
                                            startGlobalX = gp.x;
                                            startGlobalY = gp.y;
                                            isDragging = false;
                                        }
                                        onPositionChanged: mouse => {
                                            if (!pressed) return;
                                            let gp = mapToItem(mainHitArea, mouse.x, mouse.y);
                                            let deltaX = Math.abs(gp.x - startGlobalX);
                                            let deltaY = Math.abs(gp.y - startGlobalY);
                                            if (deltaX > 5 || deltaY > 5) isDragging = true;
                                            floatingWidget.evaluateDrag(startGlobalX, startGlobalY, gp.x, gp.y);
                                        }
                                        onClicked: {
                                            if (!isDragging) floatingWidget.activateTab(index);
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
}
