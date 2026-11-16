import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../reusables"
import "../"

Variants {
    model: Quickshell.screens

    delegate: Component {
        PanelWindow {
            id: barWindow
            visible: barConfigReady && !shouldHideForRedact && !(ScreenEdges.modern && ScreenEdges.fullscreen(modelData))
            readonly property int frameInset: ScreenEdges.inset(screen)
            property bool frameEdgeHovered: false
            readonly property bool frameTriggerActive: ScreenEdges.modern && visible && autohide && frameInset > 0
            readonly property rect frameTriggerRect: Qt.rect(
                isVertical ? (barPosition === "right" ? screen.width - frameInset : 0) : margins.left + currentBarMinX,
                isVertical ? margins.top + currentBarMinY : (barPosition === "bottom" ? screen.height - frameInset : 0),
                isVertical ? frameInset : currentBarMaxX - currentBarMinX,
                isVertical ? currentBarMaxY - currentBarMinY : frameInset)

            property bool pendingReload: false
            property bool startupFilesReady: false
            property bool isRedacting: false

            property bool hideBarInRedactor: {
                let dummy = configRevision;
                if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.widgets && Config.rawSettings.widgets.hideBarInRedactor !== undefined) {
                    return Config.rawSettings.widgets.hideBarInRedactor;
                }
                if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.hideBarInRedactor !== undefined) {
                    return Config.rawSettings.bar.hideBarInRedactor;
                }
                return true;
            }

            property bool shouldHideForRedact: isRedacting && hideBarInRedactor

            property var activeToplevel: ToplevelManager.activeToplevel
            property bool isFullscreenActive: {
                if (!activeToplevel || !activeToplevel.fullscreen) return false;
                if (activeToplevel.screens && activeToplevel.screens.length > 0) {
                    return activeToplevel.screens.indexOf(barWindow.screen) !== -1;
                }
                return true;
            }

            onIsFullscreenActiveChanged: {
                if (barWindow.isFullscreenActive) {
                    OsdController.isFullscreen = true;
                } else if (!OsdController.screen || OsdController.screen === barWindow.screen) {
                    OsdController.isFullscreen = false;
                }
            }

            WlrLayershell.keyboardFocus: (barWindow.isNotifOpen || barWindow.isSysOpen)
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None

            property int configRevision: 0

            Connections {
                target: (typeof Config !== "undefined") ? Config : null
                function onSettingsLoaded() {
                    barWindow.configRevision++;
                }
                function onDataReadyChanged() {
                    barWindow.configRevision++;
                }
                function onRawSettingsChanged() {
                    barWindow.configRevision++;
                }
            }

            Component.onCompleted: {
                LauncherController.registerBar(modelData.name, barWindow);
                if (typeof Config !== "undefined" && Config.dataReady) {
                    barWindow.configRevision++;
                }
            }

            Component.onDestruction: LauncherController.unregisterBar(modelData.name, barWindow)

            property string barStyle: {
                if (ScreenEdges.modern) return "edge";
                let dummy = configRevision;
                if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
                let s = Config.rawSettings.bar.style;
                if (typeof s === "string") return s;
                if (s && typeof s === "object") {
                    if (s.fill || s.mode === "fill") return "fill";
                    if (s.solid || s.mode === "solid") return "solid";
                }
                return "modular";
            }
            property bool isEdge: barStyle === "edge"
            property bool isFill: barStyle === "fill"
            property bool isSolid: barStyle === "solid" || barStyle === "fill" || isEdge
            property bool distinctPills: {
                let dummy = configRevision;
                return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.distinctPills !== undefined) ? Config.rawSettings.bar.distinctPills : false;
            }

            property bool barConfigReady: {
                let dummy = configRevision;
                if (typeof Config === "undefined") return true;
                if (Config.dataReady !== undefined) return Config.dataReady;
                return true;
            }

            property bool autohide: {
                let dummy = configRevision;
                return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.autohide !== undefined) ? Config.rawSettings.bar.autohide : false;
            }
            property int autohideTimeout: {
                let dummy = configRevision;
                return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.autohideTimeout !== undefined) ? Config.rawSettings.bar.autohideTimeout : 1000;
            }
            property real barOpacity: {
                let dummy = configRevision;
                return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.opacity !== undefined) ? (Config.rawSettings.bar.opacity / 100.0) : 1.0;
            }

            HoverHandler {
                id: barHover
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            }

            Item {
                anchors.fill: parent
                z: 1
                PointHandler {
                    id: barPress
                    enabled: barWindow.autohide
                    acceptedButtons: Qt.AllButtons
                    grabPermissions: PointerHandler.TakeOverForbidden
                    target: null
                }
            }

            function popupOnThisScreen(controller) {
                return controller.fromBar && controller.isVisible && controller.screen && controller.screen.name === modelData.name;
            }

            function togglePopup(name, arg) {
                Quickshell.execDetached(["quickshell", "-p", Caching.mainQml, "ipc", "call", "main", "toggleFromBar",
                    name === "applauncher" ? "launcher" : name, arg || "", modelData.name]);
            }

            readonly property bool autoHideHeld: barPress.active || mainPopupFromBar
                || popupOnThisScreen(LauncherController)
                || popupOnThisScreen(TrayMenuController)
                || FloatingController.panels.some(panel => panel && panel.screen && panel.screen.name === modelData.name
                    && panel.fromBar && panel.isSidebarVisible && panel.isExpanded && panel.tabModules[panel.activeIndex] !== "timer")
            onAutoHideHeldChanged: checkHideTimer()
            onAutohideChanged: checkHideTimer()

            Timer {
                id: hideTimer
                interval: barWindow.autohideTimeout
            }

            function checkHideTimer() {
                if (!barHover.hovered && !frameEdgeHovered && !autoHideHeld && barWindow.autohide) {
                    hideTimer.restart();
                } else {
                    hideTimer.stop();
                }
            }

            Connections {
                target: barHover
                function onHoveredChanged() { barWindow.checkHideTimer(); }
            }

            property bool isRevealed: {
                if (shouldHideForRedact) return false;
                if (!autohide) return true;
                if (autoHideHeld) return true;
                if (frameEdgeHovered) return true;
                if (barHover.hovered) return true;
                if (hideTimer.running) return true;
                return false;
            }

            Timer {
                interval: 50
                running: true
                onTriggered: barWindow.startupFilesReady = true
            }

            IpcHandler {
                target: "topbar"
                function setRedactMode(active: string): void {
                    barWindow.isRedacting = (active === "true" || active === "1");
                }
                function forceReload() {
                    Config.requestShellReload()
                }
                function queueReload() {
                    if (!barWindow.isNotifOpen && !barWindow.isSysOpen) {
                        Config.requestShellReload()
                    } else {
                        barWindow.pendingReload = true
                    }
                }
                function getWidgetGeometry(widgetName: string): void {
                    let target = null;
                    if (barWindow.isVertical) target = verticalWrapper.getWidget(widgetName);
                    else target = contentWrapper.getWidget(widgetName);

                    if (target && target.width > 0) {
                        let pos = target.mapToItem(null, 0, 0);

                        let absoluteX = pos.x + barWindow.margins.left;
                        let absoluteY = pos.y + barWindow.margins.top;

                        let geo = {
                            startX: Math.round(absoluteX),
                            startY: Math.round(absoluteY),
                            endX: Math.round(absoluteX + target.width),
                            endY: Math.round(absoluteY + target.height)
                        };
                        Quickshell.execDetached(["bash", "-c", "echo '" + JSON.stringify(geo) + "' > " + Caching.runDir + "/tutorial_target.json"]);
                    }
                }
            }

            required property var modelData
            screen: modelData

            property string barPosition: {
                let dummy = configRevision;
                return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.position !== undefined) ? Config.rawSettings.bar.position : "top";
            }
            property bool positionChanging: false

            property real barWidthPercent: {
                let dummy = configRevision;
                return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.width !== undefined) ? Config.rawSettings.bar.width : 100;
            }
            property real edgePadding: (autohide && !isFill && !isEdge) ? s(4) : 0
            property string barAlignment: {
                let dummy = configRevision;
                return Config.getSetting("bar", {}).alignment || "center";
            }
            property real alignmentFactor: barAlignment === "start" ? (isVertical ? 1 : 0) : (barAlignment === "end" ? (isVertical ? 0 : 1) : 0.5)
            property real effectiveBarWidth: Math.round(isVertical ? barWindow.width : ((barWindow.width - edgePadding * 2) * (barWidthPercent / 100.0)))
            property real horizontalOffset: isVertical ? 0 : Math.round(edgePadding + (barWindow.width - edgePadding * 2 - effectiveBarWidth) * alignmentFactor)

            property real effectiveBarHeight: Math.round(!isVertical ? barWindow.height : ((barWindow.height - edgePadding * 2) * (barWidthPercent / 100.0)))
            property real verticalOffset: !isVertical ? 0 : Math.round(edgePadding + (barWindow.height - edgePadding * 2 - effectiveBarHeight) * alignmentFactor)

            function getAlignmentOffset(minimum, maximum, screenLength) {
                let freeSpace = Math.max(0, screenLength - (maximum - minimum));
                let start = edgePadding + (freeSpace - edgePadding * 2) * alignmentFactor;
                return Math.round(Math.max(0, Math.min(freeSpace, start)) - minimum);
            }

            property real horizontalAlignmentOffset: !isVertical && contentWrapper && contentWrapper.layoutState === "default" ? getAlignmentOffset(contentWrapper.dynamicMinX, contentWrapper.dynamicMaxX, barWindow.width) : 0
            property real verticalAlignmentOffset: isVertical && verticalWrapper ? getAlignmentOffset(verticalWrapper.dynamicMinY, verticalWrapper.dynamicMaxY, barWindow.height) : 0

            property real currentBarMinX: ((contentWrapper && contentWrapper.dynamicMaxX > contentWrapper.dynamicMinX) ? contentWrapper.dynamicMinX : horizontalOffset) + horizontalAlignmentOffset
            property real currentBarMaxX: ((contentWrapper && contentWrapper.dynamicMaxX > contentWrapper.dynamicMinX) ? contentWrapper.dynamicMaxX : (horizontalOffset + effectiveBarWidth)) + horizontalAlignmentOffset

            property real currentBarMinY: ((verticalWrapper && verticalWrapper.dynamicMaxY > verticalWrapper.dynamicMinY) ? verticalWrapper.dynamicMinY : verticalOffset) + verticalAlignmentOffset
            property real currentBarMaxY: ((verticalWrapper && verticalWrapper.dynamicMaxY > verticalWrapper.dynamicMinY) ? verticalWrapper.dynamicMaxY : (verticalOffset + effectiveBarHeight)) + verticalAlignmentOffset

            Timer {
                id: positionChangeTimer
                interval: 200
                onTriggered: barWindow.positionChanging = false
            }

            onBarPositionChanged: {
                barWindow.positionChanging = true;
                positionChangeTimer.restart();
            }

            property bool isVertical: barPosition === "left" || barPosition === "right"

            property real baseScale: Scaler.baseScale

            function s(val) {
                return Math.round(Scaler.s(val));
            }

            property int barHeight: s(40)
            property real cornerRadius: s(12)
            readonly property real edgeRadius: Math.max(0, Math.min(barHeight / 2, ThemeBackend.borderRadius))

            property real baseOffsetY: {
                if (barPosition === "bottom") {
                    return isFill ? (barWindow.height - barWindow.barHeight) : (barWindow.height - barWindow.barHeight - edgePadding);
                } else {
                    return isFill ? 0 : edgePadding;
                }
            }

            anchors {
                top: barPosition === "top" || barWindow.isVertical
                bottom: barPosition === "bottom" || barWindow.isVertical
                left: barPosition === "left" || !barWindow.isVertical
                right: barPosition === "right" || !barWindow.isVertical
            }

            implicitHeight: barWindow.isVertical ? 0 : (barHeight + (isFill ? cornerRadius : edgePadding))
            implicitWidth: barWindow.isVertical ? (barHeight + (isFill ? cornerRadius : edgePadding)) : 0

            margins {
                top: ScreenEdges.modern ? frameInset : ((isFill || isEdge) ? 0 : (barPosition === "bottom" ? 0 : (autohide ? 0 : s(4))))
                bottom: ScreenEdges.modern ? frameInset : ((isFill || isEdge) ? 0 : (barPosition === "top" ? 0 : (autohide ? 0 : s(4))))
                left: ScreenEdges.modern ? frameInset : ((isFill || isEdge) ? 0 : (barPosition === "right" ? 0 : (autohide ? 0 : s(4))))
                right: ScreenEdges.modern ? frameInset : ((isFill || isEdge) ? 0 : (barPosition === "left" ? 0 : (autohide ? 0 : s(4))))
            }

            exclusiveZone: ScreenEdges.modern ? -1 : ((!barConfigReady || autohide || shouldHideForRedact) ? 0 : barHeight)
            exclusionMode: ScreenEdges.modern ? ExclusionMode.Ignore : ExclusionMode.Normal
            color: "transparent"

            property real activeMaskHeight: shouldHideForRedact ? 0 : ((autohide && !isRevealed) ? s(4) : (isVertical ? (isFill ? barWindow.height : (effectiveBarHeight + edgePadding * 2)) : (isFill ? (barHeight + cornerRadius) : (barHeight + edgePadding))))
            property real activeMaskWidth: shouldHideForRedact ? 0 : ((autohide && !isRevealed) ? s(4) : (isVertical ? (isFill ? (barHeight + cornerRadius) : (barHeight + edgePadding)) : (isFill ? barWindow.width : (effectiveBarWidth + edgePadding * 2))))

            readonly property bool edgeMaskVisible: isEdge && !shouldHideForRedact && (!autohide || isRevealed)

            mask: Region {
                Region {
                    x: barWindow.isVertical ? (barWindow.barPosition === "right" ? (barWindow.width - barWindow.activeMaskWidth) : 0) : barWindow.currentBarMinX
                    y: barWindow.isVertical ? barWindow.currentBarMinY : (barWindow.barPosition === "bottom" ? barWindow.baseOffsetY : 0)
                    width: barWindow.isVertical ? barWindow.activeMaskWidth : (barWindow.currentBarMaxX - barWindow.currentBarMinX)
                    height: barWindow.isVertical ? (barWindow.currentBarMaxY - barWindow.currentBarMinY) : (isFill ? barWindow.barHeight : barWindow.activeMaskHeight)
                    radius: barWindow.edgeMaskVisible ? barWindow.edgeRadius : 0
                    topLeftRadius: barWindow.barPosition === "top" || barWindow.barPosition === "left" ? 0 : radius
                    topRightRadius: barWindow.barPosition === "top" || barWindow.barPosition === "right" ? 0 : radius
                    bottomLeftRadius: barWindow.barPosition === "bottom" || barWindow.barPosition === "left" ? 0 : radius
                    bottomRightRadius: barWindow.barPosition === "bottom" || barWindow.barPosition === "right" ? 0 : radius
                }
                Region {
                    x: barWindow.isVertical ? (barWindow.barPosition === "right" ? (barWindow.width - barWindow.barHeight - barWindow.cornerRadius) : barWindow.barHeight) : barWindow.currentBarMinX
                    y: barWindow.isVertical ? barWindow.currentBarMinY : (barWindow.barPosition === "bottom" ? (barWindow.baseOffsetY - barWindow.cornerRadius) : (barWindow.baseOffsetY + barWindow.barHeight))
                    width: (!barWindow.isVertical && barWindow.isFill) ? barWindow.cornerRadius : (barWindow.isVertical && barWindow.isFill ? barWindow.cornerRadius : 0)
                    height: (!barWindow.isVertical && barWindow.isFill) ? barWindow.cornerRadius : (barWindow.isVertical && barWindow.isFill ? barWindow.cornerRadius : 0)
                }
                Region {
                    x: barWindow.isVertical ? (barWindow.barPosition === "right" ? (barWindow.width - barWindow.barHeight - barWindow.cornerRadius) : barWindow.barHeight) : (barWindow.currentBarMaxX - barWindow.cornerRadius)
                    y: barWindow.isVertical ? (barWindow.currentBarMaxY - barWindow.cornerRadius) : (barWindow.barPosition === "bottom" ? (barWindow.baseOffsetY - barWindow.cornerRadius) : (barWindow.baseOffsetY + barWindow.barHeight))
                    width: (!barWindow.isVertical && barWindow.isFill) ? barWindow.cornerRadius : (barWindow.isVertical && barWindow.isFill ? barWindow.cornerRadius : 0)
                    height: (!barWindow.isVertical && barWindow.isFill) ? barWindow.cornerRadius : (barWindow.isVertical && barWindow.isFill ? barWindow.cornerRadius : 0)
                }
                Region {
                    id: edgeStartMask
                    x: barWindow.isVertical ? (barWindow.barPosition === "right" ? barWindow.width - barWindow.edgeRadius : 0) : barWindow.currentBarMinX - barWindow.edgeRadius
                    y: barWindow.isVertical ? barWindow.currentBarMinY - barWindow.edgeRadius : (barWindow.barPosition === "bottom" ? barWindow.baseOffsetY + barWindow.barHeight - barWindow.edgeRadius : barWindow.baseOffsetY)
                    width: barWindow.edgeMaskVisible ? barWindow.edgeRadius : 0
                    height: width
                    Region {
                        shape: RegionShape.Ellipse
                        intersection: Intersection.Subtract
                        x: edgeStartMask.x - (barWindow.isVertical && barWindow.barPosition === "left" ? 0 : barWindow.edgeRadius)
                        y: edgeStartMask.y - (barWindow.isVertical || barWindow.barPosition === "bottom" ? barWindow.edgeRadius : 0)
                        width: barWindow.edgeMaskVisible ? barWindow.edgeRadius * 2 : 0
                        height: width
                    }
                }
                Region {
                    id: edgeEndMask
                    x: barWindow.isVertical ? (barWindow.barPosition === "right" ? barWindow.width - barWindow.edgeRadius : 0) : barWindow.currentBarMaxX
                    y: barWindow.isVertical ? barWindow.currentBarMaxY : (barWindow.barPosition === "bottom" ? barWindow.baseOffsetY + barWindow.barHeight - barWindow.edgeRadius : barWindow.baseOffsetY)
                    width: barWindow.edgeMaskVisible ? barWindow.edgeRadius : 0
                    height: width
                    Region {
                        shape: RegionShape.Ellipse
                        intersection: Intersection.Subtract
                        x: edgeEndMask.x - (barWindow.isVertical && barWindow.barPosition === "right" ? barWindow.edgeRadius : 0)
                        y: edgeEndMask.y - (!barWindow.isVertical && barWindow.barPosition === "bottom" ? barWindow.edgeRadius : 0)
                        width: barWindow.edgeMaskVisible ? barWindow.edgeRadius * 2 : 0
                        height: width
                    }
                }
            }

            property string activeWidget: ""
            property bool mainPopupFromBar: false
            property bool isNotifOpen: activeWidget === "notifications"
            property bool isSysOpen: activeWidget === "system"

            onActiveWidgetChanged: {
                if (!barWindow.isNotifOpen && !barWindow.isSysOpen && barWindow.pendingReload) {
                    barWindow.pendingReload = false;
                    Config.requestShellReload();
                }
            }

            FileView {
                id: widgetWatcher
                path: (barWindow.startupFilesReady && Caching.runDir) ? (Caching.runDir + "/current_widget") : ""
                watchChanges: true
                onFileChanged: reload()
                onLoaded: {
                    let txt = text().trim();
                    let widget = "";
                    let targetScreen = "";
                    let barScreen = "";

                    try {
                        let parsed = JSON.parse(txt);
                        if (parsed && typeof parsed === "object") {
                            widget = parsed.widget || "";
                            targetScreen = parsed.screen || "";
                            barScreen = parsed.barScreen || "";
                        } else if (typeof parsed === "string") {
                            widget = parsed;
                        }
                    } catch (e) {
                        widget = txt;
                    }

                    let myScreenName = (barWindow.screen && barWindow.screen.name) ? barWindow.screen.name : "";
                    let effectiveWidget = "";
                    if (widget && widget !== "hidden") {
                        if (!targetScreen || targetScreen === myScreenName) {
                            effectiveWidget = widget;
                        }
                    }

                    if (barWindow.activeWidget !== effectiveWidget) {
                        barWindow.activeWidget = effectiveWidget;
                    }
                    barWindow.mainPopupFromBar = effectiveWidget !== "" && barScreen === myScreenName;
                }
            }

            property bool isStartupReady: false
            Timer { interval: 10; running: true; onTriggered: barWindow.isStartupReady = true }

            property bool startupCascadeFinished: false
            Timer { interval: 1050; running: true; onTriggered: barWindow.startupCascadeFinished = true }

            property bool fastPollerLoaded: false
            property bool isDataReady: fastPollerLoaded
            Timer { interval: 400; running: true; onTriggered: barWindow.isDataReady = true }

            SideBar {
                id: verticalWrapper
                barWindow: barWindow
                property real hideOffsetX: {
                    if (!barWindow || barWindow.isRevealed) return 0;
                    let offset = barWindow.barHeight + barWindow.edgePadding + barWindow.s(10);
                    return barWindow.barPosition === "right" ? offset : -offset;
                }
                transform: Translate {
                    x: verticalWrapper.hideOffsetX
                    y: barWindow.verticalAlignmentOffset
                    Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
                    Behavior on y {
                        enabled: verticalWrapper.layoutAnimationsEnabled
                        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                    }
                }
            }

            TopBar {
                id: contentWrapper
                barWindow: barWindow
            }
        }
    }
}
