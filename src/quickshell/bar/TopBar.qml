import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import "../reusables"
import "../"
import "."
import "../WindowRegistry.js" as WindowRegistry

Item {
    id: contentWrapper
    property var barWindow
    readonly property Item glassBackdropItem: isEdge ? edgeBackground.glassBackdrop : (isSolid ? barGlass : null)

    property string barStyle: {
        if (barWindow && barWindow.barStyle !== undefined) return barWindow.barStyle;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.style) {
            let s = Config.rawSettings.bar.style;
            if (typeof s === "string") return s;
            if (typeof s === "object") {
                if (s.fill || s.mode === "fill") return "fill";
                if (s.solid || s.mode === "solid") return "solid";
            }
        }
        return "modular";
    }
    property bool isEdge: barStyle === "edge"
    property bool isFill: barStyle === "fill"
    property bool isSolid: barStyle === "solid" || barStyle === "fill" || isEdge
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property real cornerRadius: barWindow ? barWindow.cornerRadius : 12

    property bool suppressAnimation: false
    property bool layoutAnimationsEnabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging && !contentWrapper.suppressAnimation

    Timer {
        id: snapTimer
        interval: 200
        onTriggered: contentWrapper.suppressAnimation = false
    }

    Connections {
        target: contentWrapper.barWindow || null
        function onBarPositionChanged() {
            contentWrapper.suppressAnimation = true;
            snapTimer.restart();
        }
        function onPositionChangingChanged() {
            if (contentWrapper.barWindow && contentWrapper.barWindow.positionChanging) {
                contentWrapper.suppressAnimation = true;
            } else {
                snapTimer.restart();
            }
        }
        function onBaseOffsetYChanged() {
            contentWrapper.suppressAnimation = true;
            snapTimer.restart();
        }
        function onIsVerticalChanged() {
            contentWrapper.suppressAnimation = true;
            snapTimer.restart();
        }
    }

    property var defaultModuleSettings: {
        "left": ["workspaces", "focus"],
        "center": ["timedate", "info", "weather", "media", "vis"],
        "right": ["tray", "sysmon", "kb", "wifi", "bt", "vol", "bat"]
    }

    property var moduleSettings: (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.modules) ? BarModuleRegistry.parseModuleSettings(Config.rawSettings.bar.modules, defaultModuleSettings) : defaultModuleSettings

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            let ms = Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.modules ? Config.rawSettings.bar.modules : null;
            contentWrapper.moduleSettings = BarModuleRegistry.parseModuleSettings(ms, defaultModuleSettings);
        }
    }

    property string layoutState: {
        if (isFill) return "default";
        if (barWindow && barWindow.isNotifOpen) return "settings";
        if (barWindow && barWindow.isSysOpen) return "sys";
        return "default";
    }

    property var leftArr: {
        let items = contentWrapper.moduleSettings["left"] || [];
        return barStyle === "sections" && items.length ? [[].concat(...items)] : items;
    }
    property var centerArr: {
        let items = contentWrapper.moduleSettings["center"] || [];
        return barStyle === "sections" && items.length ? [[].concat(...items)] : items;
    }
    property var rightArr: {
        let items = contentWrapper.moduleSettings["right"] || [];
        return barStyle === "sections" && items.length ? [[].concat(...items)] : items;
    }

    property var flatLeftArr: { let r=[]; for(let i=0; i<leftArr.length; i++){ if(Array.isArray(leftArr[i])) r.push(...leftArr[i]); else r.push(leftArr[i]); } return r; }
    property var flatCenterArr: { let r=[]; for(let i=0; i<centerArr.length; i++){ if(Array.isArray(centerArr[i])) r.push(...centerArr[i]); else r.push(centerArr[i]); } return r; }
    property var flatRightArr: { let r=[]; for(let i=0; i<rightArr.length; i++){ if(Array.isArray(rightArr[i])) r.push(...rightArr[i]); else r.push(rightArr[i]); } return r; }

    property var groupDefs: {
        let defs = [];
        let all = [contentWrapper.leftArr, contentWrapper.centerArr, contentWrapper.rightArr];
        for (let i = 0; i < all.length; i++) {
            for (let j = 0; j < all[i].length; j++) {
                if (Array.isArray(all[i][j])) defs.push(all[i][j]);
            }
        }
        return defs;
    }

    property bool trayInLeft: flatLeftArr.indexOf("tray") !== -1
    property bool trayInCenter: flatCenterArr.indexOf("tray") !== -1
    property bool trayInRight: flatRightArr.indexOf("tray") !== -1

    property bool trayAlignRight: {
        if (trayInLeft) return false;
        if (trayInRight) return true;
        if (trayInCenter) return layoutState !== "sys";
        return true;
    }

    property var moduleInstances: ({})
    property int modulesRev: 0

    function registerModuleInstance(id, inst) {
        moduleInstances[id] = inst;
        modulesRev++;
    }

    function getModuleItem(id) {
        let dummy = modulesRev;
        let norm = BarModuleRegistry.normalizeId(id);
        return moduleInstances[norm] || null;
    }

    readonly property var leftWidget: getModuleItem("left")
    readonly property var workspacesWidget: getModuleItem("workspaces")
    readonly property var focusWidget: getModuleItem("focus")
    readonly property var mediaWidget: getModuleItem("media")
    readonly property var visWidget: getModuleItem("vis")
    readonly property var trayWidget: getModuleItem("tray")
    readonly property var timeDateWidget: getModuleItem("timedate")
    readonly property var infoWidget: getModuleItem("info")
    readonly property var weatherWidget: getModuleItem("weather")
    readonly property var sysMonWidget: getModuleItem("sysmon")
    readonly property var kbWidget: getModuleItem("kb")
    readonly property var wifiWidget: getModuleItem("wifi")
    readonly property var btWidget: getModuleItem("bt")
    readonly property var volWidget: getModuleItem("vol")
    readonly property var batWidget: getModuleItem("bat")

    function isModuleActive(moduleId) {
        let norm = BarModuleRegistry.normalizeId(moduleId);
        let checkFlat = arr => {
            for (let i = 0; i < arr.length; i++) {
                if (BarModuleRegistry.normalizeId(arr[i]) === norm) return true;
            }
            return false;
        };
        return checkFlat(flatLeftArr) || checkFlat(flatCenterArr) || checkFlat(flatRightArr);
    }

    function isModuleGrouped(id) {
        let norm = BarModuleRegistry.normalizeId(id);
        let allArrs = [leftArr, centerArr, rightArr];
        for (let a = 0; a < allArrs.length; a++) {
            for (let i = 0; i < allArrs[a].length; i++) {
                if (Array.isArray(allArrs[a][i])) {
                    for (let k = 0; k < allArrs[a][i].length; k++) {
                        if (BarModuleRegistry.normalizeId(allArrs[a][i][k]) === norm) return true;
                    }
                }
            }
        }
        return false;
    }

    property real wLeft: (isModuleActive("left") && leftWidget) ? (leftWidget.targetWidth !== undefined ? leftWidget.targetWidth : leftWidget.width) : 0
    property real wWorkspaces: (isModuleActive("workspaces") && workspacesWidget) ? (workspacesWidget.targetWidth !== undefined ? workspacesWidget.targetWidth : workspacesWidget.width) : 0
    property real wFocus: (isModuleActive("focus") && focusWidget) ? (focusWidget.targetWidth !== undefined ? focusWidget.targetWidth : focusWidget.width) : 0
    property real wMedia: (isModuleActive("media") && mediaWidget) ? (mediaWidget.targetWidth !== undefined ? mediaWidget.targetWidth : mediaWidget.width) : 0
    property real wVis: (isModuleActive("vis") && visWidget) ? (visWidget.targetWidth !== undefined ? visWidget.targetWidth : visWidget.width) : 0
    property real wTray: (isModuleActive("tray") && trayWidget) ? (trayWidget.targetWidth !== undefined ? trayWidget.targetWidth : trayWidget.width) : 0
    property real wSysmon: (isModuleActive("sysmon") && sysMonWidget) ? (sysMonWidget.targetWidth !== undefined ? sysMonWidget.targetWidth : sysMonWidget.width) : 0
    property real wKb: (isModuleActive("kb") && kbWidget) ? (kbWidget.targetWidth !== undefined ? kbWidget.targetWidth : kbWidget.width) : 0
    property real wWifi: (isModuleActive("wifi") && wifiWidget) ? (wifiWidget.targetWidth !== undefined ? wifiWidget.targetWidth : wifiWidget.width) : 0
    property real wBt: (isModuleActive("bt") && btWidget) ? (btWidget.targetWidth !== undefined ? btWidget.targetWidth : btWidget.width) : 0
    property real wVol: (isModuleActive("vol") && volWidget) ? (volWidget.targetWidth !== undefined ? volWidget.targetWidth : volWidget.width) : 0
    property real wBat: (isModuleActive("bat") && batWidget) ? (batWidget.targetWidth !== undefined ? batWidget.targetWidth : batWidget.width) : 0
    property real wTimedate: (isModuleActive("timedate") && timeDateWidget) ? (timeDateWidget.targetWidth !== undefined ? timeDateWidget.targetWidth : timeDateWidget.width) : 0
    property real wInfo: (isModuleActive("info") && infoWidget) ? (infoWidget.targetWidth !== undefined ? infoWidget.targetWidth : infoWidget.width) : 0
    property real wWeather: (isModuleActive("weather") && weatherWidget) ? (weatherWidget.targetWidth !== undefined ? weatherWidget.targetWidth : weatherWidget.width) : 0

    function getW(moduleId) {
        let norm = BarModuleRegistry.normalizeId(moduleId);
        if (norm === "settings") return wLeft;
        if (norm === "workspaces") return wWorkspaces;
        if (norm === "focus") return wFocus;
        if (norm === "media") return wMedia;
        if (norm === "vis") return wVis;
        if (norm === "tray") return wTray;
        if (norm === "sysmon") return wSysmon;
        if (norm === "kb") return wKb;
        if (norm === "wifi") return wWifi;
        if (norm === "bt") return wBt;
        if (norm === "vol") return wVol;
        if (norm === "bat") return wBat;
        if (norm === "timedate") return wTimedate;
        if (norm === "info") return wInfo;
        if (norm === "weather") return wWeather;
        let w = getModuleItem(norm);
        return (w && isModuleActive(norm)) ? (w.targetWidth !== undefined ? w.targetWidth : w.width) : 0;
    }

    property real gap: barWindow ? barWindow.s(2) : 2
    property real groupGap: barWindow ? -barWindow.s(4) : -4
    property real gap8: barWindow ? barWindow.s(10) : 10
    property real groupPad: (!isSolid || distinctPills) ? (barWindow ? barWindow.s(4) : 4) : 0

    function calcTargetWidth(arr) {
        let total = 0;
        let groupCount = 0;
        for (let i = 0; i < arr.length; i++) {
            if (Array.isArray(arr[i])) {
                let gw = 0;
                let gItems = 0;
                for (let j = 0; j < arr[i].length; j++) {
                    let w = getW(arr[i][j]);
                    if (w > 0) {
                        if (gItems > 0) gw += groupGap;
                        gw += w;
                        gItems++;
                    }
                }
                if (gItems > 0) {
                    total += gw + groupPad * 2;
                    groupCount++;
                }
            } else {
                let w = getW(arr[i]);
                if (w > 0) { total += w; groupCount++; }
            }
        }
        return total + (groupCount > 1 ? gap * (groupCount - 1) : 0);
    }

    property real lWidthTarget: calcTargetWidth(leftArr)
    property real cWidthTarget: calcTargetWidth(centerArr)
    property real rWidthTarget: calcTargetWidth(rightArr)

    property real lcGap: (lWidthTarget > 0 && cWidthTarget > 0) ? gap8 : 0
    property real crGap: (cWidthTarget > 0 && rWidthTarget > 0) ? gap8 : 0

    property real distinctEdgePadding: (isSolid && distinctPills) ? (barWindow ? barWindow.s(4) : 4) : 4
    property real fillInset: distinctEdgePadding

    property real baseMinLeft: (barWindow ? barWindow.horizontalOffset + (isFill ? 0 : barWindow.s(1)) : 0) + distinctEdgePadding
    property real baseMaxRight: (barWindow ? barWindow.horizontalOffset + barWindow.effectiveBarWidth - (isFill ? 0 : barWindow.s(1)) : contentWrapper.width) - distinctEdgePadding

    property real screenMinLeft: isFill ? fillInset : (barWindow ? (barWindow.s(1) + distinctEdgePadding) : distinctEdgePadding)
    property real screenMaxRight: isFill ? (contentWrapper.width - fillInset) : (barWindow ? (contentWrapper.width - barWindow.s(1) - distinctEdgePadding) : (contentWrapper.width - distinctEdgePadding))

    property real sysPanelWidth: {
        let fallback = (barWindow && typeof barWindow.s === "function") ? barWindow.s(500) : 500;
        if (typeof WindowRegistry !== "undefined" && typeof WindowRegistry.getLayout === "function") {
            let scrW = (barWindow && barWindow.screen) ? barWindow.screen.width : (contentWrapper.width || 1920);
            let scrH = (barWindow && barWindow.screen) ? barWindow.screen.height : 1080;
            let scale = (typeof Scaler !== "undefined" && Scaler.uiScale !== undefined) ? Scaler.uiScale : 1.0;
            let bp = (barWindow && barWindow.barPosition) ? barWindow.barPosition : "top";
            let layout = WindowRegistry.getLayout("system", 0, 0, scrW, scrH, scale, bp);
            if (layout && layout.w) return layout.w;
        }
        return fallback;
    }

    property real sysBoundary: Math.max(0, contentWrapper.width - sysPanelWidth)
    property real sysMaxRight: isFill ? (contentWrapper.width - fillInset) : Math.max(screenMinLeft, sysBoundary - (barWindow ? barWindow.s(1) : 0) - distinctEdgePadding)
    property real sysEffectiveMaxRight: Math.min(baseMaxRight, sysMaxRight)
    property real effectiveMaxRight: (layoutState === "sys") ? sysEffectiveMaxRight : screenMaxRight

    property real rawCNaturalX: {
        if (layoutState === "settings") return screenMaxRight - rWidthTarget - crGap - cWidthTarget;
        if (layoutState === "sys") return (sysBoundary - cWidthTarget) / 2;
        return (baseMinLeft + baseMaxRight - cWidthTarget) / 2;
    }

    property real absMinC: (lWidthTarget > 0) ? (screenMinLeft + lWidthTarget + lcGap) : screenMinLeft
    property real absMaxC: (rWidthTarget > 0) ? (effectiveMaxRight - rWidthTarget - crGap - cWidthTarget) : (effectiveMaxRight - cWidthTarget)

    property real cResolvedX: {
        if (absMinC <= absMaxC) {
            return Math.max(absMinC, Math.min(absMaxC, rawCNaturalX));
        }
        return absMinC;
    }

    property real cFinalX: cResolvedX

    property real lFinalX: {
        if (lWidthTarget <= 0) return baseMinLeft;
        if (layoutState === "settings") {
            return Math.max(screenMinLeft, cFinalX - lcGap - lWidthTarget);
        }
        let pushedX = Math.min(baseMinLeft, cFinalX - lcGap - lWidthTarget);
        return Math.max(screenMinLeft, pushedX);
    }

    property real rFinalX: {
        if (rWidthTarget <= 0) return (layoutState === "sys" ? sysEffectiveMaxRight : baseMaxRight);
        let naturalR = (layoutState === "sys") ? (sysEffectiveMaxRight - rWidthTarget) : (baseMaxRight - rWidthTarget);
        let minR = (cWidthTarget > 0) ? (cFinalX + cWidthTarget + crGap) : ((lWidthTarget > 0) ? (lFinalX + lWidthTarget + lcGap) : screenMinLeft);
        let pushedX = Math.max(naturalR, minR);
        return Math.min(screenMaxRight - rWidthTarget, pushedX);
    }
    property real rFinalClampedX: Math.max(screenMinLeft, Math.min(screenMaxRight - rWidthTarget, rFinalX))

    property real dynamicMinX: {
        let m = contentWrapper.width;
        let hasModules = (lWidthTarget > 0 || cWidthTarget > 0 || rWidthTarget > 0);
        if (lWidthTarget > 0) m = Math.min(m, lFinalX - (barWindow && !isFill ? barWindow.s(1) : 0) - distinctEdgePadding);
        if (cWidthTarget > 0) m = Math.min(m, cFinalX - (barWindow && !isFill ? barWindow.s(1) : 0) - distinctEdgePadding);
        if (rWidthTarget > 0) m = Math.min(m, rFinalClampedX - (barWindow && !isFill ? barWindow.s(1) : 0) - distinctEdgePadding);
        if (layoutState !== "default") {
            return hasModules ? Math.max(0, m) : contentWrapper.width / 2;
        }
        return Math.max(0, Math.min(m, barWindow ? barWindow.horizontalOffset : 0));
    }

    property real dynamicMaxX: {
        let m = 0;
        let hasModules = (lWidthTarget > 0 || cWidthTarget > 0 || rWidthTarget > 0);
        if (lWidthTarget > 0) m = Math.max(m, lFinalX + lWidthTarget + (barWindow && !isFill ? barWindow.s(1) : 0) + distinctEdgePadding);
        if (cWidthTarget > 0) m = Math.max(m, cFinalX + cWidthTarget + (barWindow && !isFill ? barWindow.s(1) : 0) + distinctEdgePadding);
        if (rWidthTarget > 0) m = Math.max(m, rFinalClampedX + rWidthTarget + (barWindow && !isFill ? barWindow.s(1) : 0) + distinctEdgePadding);
        if (layoutState !== "default") {
            return hasModules ? Math.min(contentWrapper.width, m) : contentWrapper.width / 2;
        }
        return Math.min(contentWrapper.width, Math.max(m, barWindow ? (barWindow.horizontalOffset + barWindow.effectiveBarWidth) : contentWrapper.width));
    }

    function matchId(item, id) {
        if (item === id) return true;
        if (id === "timedate" && (item === "time" || item === "clock")) return true;
        if (id === "info" && (item === "indicator" || item === "indicators" || item === "record")) return true;
        return false;
    }

    function getModuleX(id, state) {
        let arr = null, isLeft = false, isCenter = false, isRight = false;
        let checkFlat = (fArr) => {
            for (let i = 0; i < fArr.length; i++) {
                if (matchId(fArr[i], id)) return true;
            }
            return false;
        };

        if (checkFlat(flatLeftArr)) { arr = leftArr; isLeft = true; }
        else if (checkFlat(flatCenterArr)) { arr = centerArr; isCenter = true; }
        else if (checkFlat(flatRightArr)) { arr = rightArr; isRight = true; }

        if (!arr) return 0;

        let offset = 0;
        let baseX = isLeft ? lFinalX : (isCenter ? cFinalX : rFinalClampedX);

        for (let i = 0; i < arr.length; i++) {
            let item = arr[i];
            if (Array.isArray(item)) {
                let groupHasId = false;
                for (let k = 0; k < item.length; k++) {
                    if (matchId(item[k], id)) { groupHasId = true; break; }
                }
                let gItems = 0;
                let groupOffset = offset + groupPad;
                for (let j = 0; j < item.length; j++) {
                    let mId = item[j];
                    let w = getW(mId);
                    if (matchId(mId, id)) {
                        if (gItems > 0) groupOffset += groupGap;
                        return baseX + groupOffset;
                    }
                    if (w > 0) {
                        if (gItems > 0) groupOffset += groupGap;
                        groupOffset += w;
                        gItems++;
                    }
                }
                if (gItems > 0 && !groupHasId) {
                    offset = groupOffset + groupPad + gap;
                }
            } else {
                if (matchId(item, id)) {
                    return baseX + offset;
                }
                let w = getW(item);
                if (w > 0) {
                    offset += w + gap;
                }
            }
        }
        return 0;
    }

    function getPositionedWidget(id) {
        return getModuleItem(id);
    }

    function getWidget(widgetName) {
        let norm = BarModuleRegistry.normalizeId(widgetName);
        let w = getPositionedWidget(norm);
        if (widgetName === "left" || widgetName === "top") return w;
        if (widgetName === "help" || widgetName === "guide") {
            let lw = getPositionedWidget("left");
            return lw ? lw.helpButton : null;
        }
        if (widgetName === "record") {
            let iw = getPositionedWidget("info");
            return iw ? iw.recRow : null;
        }
        if (widgetName === "kb") return w ? (w.kbPill || w) : null;
        if (widgetName === "wifi") return w ? (w.wifiPill || w) : null;
        if (widgetName === "bt") return w ? (w.btPill || w) : null;
        if (widgetName === "volume" || widgetName === "vol") return w ? (w.volPill || w) : null;
        if (widgetName === "battery" || widgetName === "bat") return w ? (w.batPill || w) : null;
        if (widgetName === "system" || widgetName === "pills") return systemWidget;
        return w;
    }

    function getModuleY(widget) {
        if (!barWindow) return 0;
        let base = barWindow.baseOffsetY;
        let bHeight = barWindow.barHeight;
        let h = widget ? widget.height : 0;
        if (h > 0 && h < bHeight) {
            return base + Math.round((bHeight - h) / 2);
        }
        return base;
    }

    anchors.fill: parent
    visible: barWindow ? (!barWindow.isVertical && !barWindow.positionChanging) : true
    opacity: (visible && (!barWindow || !barWindow.positionChanging) && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0

    property real hideOffsetY: {
        if (!barWindow || barWindow.isRevealed) return 0;
        let offset = barWindow.barHeight + (barWindow.edgePadding !== undefined ? barWindow.edgePadding : 0) + barWindow.s(10);
        return barWindow.barPosition === "bottom" ? offset : -offset;
    }

    transform: Translate {
        id: wrapperShift
        x: barWindow ? barWindow.horizontalAlignmentOffset : 0
        y: contentWrapper.hideOffsetY
        Behavior on x {
            enabled: contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            enabled: barWindow ? !barWindow.positionChanging : true
            NumberAnimation { duration: 300; easing.type: Easing.OutQuint }
        }
    }

    Behavior on opacity {
        enabled: barWindow ? (!barWindow.positionChanging && barWindow.startupCascadeFinished) : true
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    EdgeBackground {
        id: edgeBackground
        objectName: "edge-background"
        x: contentWrapper.dynamicMinX
        y: barWindow ? barWindow.baseOffsetY : 0
        width: contentWrapper.dynamicMaxX - contentWrapper.dynamicMinX
        height: barWindow ? barWindow.barHeight : 40
        edge: barWindow ? barWindow.barPosition : "top"
        cornerRadius: barWindow ? barWindow.edgeRadius : ThemeBackend.borderRadius
        color: Qt.alpha(ThemeBackend.base, barWindow ? barWindow.barOpacity : 1)
        visible: contentWrapper.isEdge && (barWindow ? !barWindow.positionChanging : true)
    }

    Rectangle {
        id: solidBackground
        x: contentWrapper.dynamicMinX
        width: contentWrapper.dynamicMaxX - contentWrapper.dynamicMinX
        height: barWindow ? barWindow.barHeight : 0
        y: barWindow ? barWindow.baseOffsetY : 0
        color: (barGlass.active || barSurface.visible) ? "transparent" : Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
        WallpaperBlur { id: barGlass; anchors.fill: parent; radius: parent.radius; surfaceEnabled: !barSurface.visible }
        radius: isFill ? 0 : ThemeBackend.borderRadius
        border.width: (isSolid || isFill) ? 0 : 1
        border.color: (isSolid || isFill) ? "transparent" : Qt.alpha(ThemeBackend.surface0, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
        visible: !contentWrapper.isEdge && (isSolid || isFill) && (barWindow ? !barWindow.positionChanging : true)
        opacity: visible ? 1.0 : 0.0

        Behavior on x {
            enabled: contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Behavior on width {
            enabled: contentWrapper.layoutAnimationsEnabled
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    // Solid and Fill bars as one SurfaceField surface: popups attached to the bar (attachTo "bar") join it
    // with a smooth fillet, and a Fill bar's outer corners come from off-screen edge shapes.
    AttachedSurface {
        id: barSurface
        kind: "bar"
        publishShape: true
        visible: solidBackground.visible && !contentWrapper.isEdge && (contentWrapper.isFill || contentWrapper.isSolid)
        opacity: solidBackground.opacity
        filletRadius: contentWrapper.isFill ? contentWrapper.cornerRadius : solidBackground.radius
        color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
        rects: [{ x: solidBackground.x, y: solidBackground.y, w: solidBackground.width, h: solidBackground.height,
                  r: [solidBackground.radius, solidBackground.radius, solidBackground.radius, solidBackground.radius] }]
        offset: Qt.point(wrapperShift.x, wrapperShift.y)
        readonly property var scr: barWindow && barWindow.screen ? barWindow.screen : null
        readonly property bool atBottom: !!barWindow && barWindow.barPosition === "bottom"
        screenRects: contentWrapper.isFill && scr ? [
            { x: -10000, y: atBottom ? scr.height : -10000, w: scr.width + 20000, h: 10000 },
            { x: -10000, y: atBottom ? -10000 : 2 * contentWrapper.cornerRadius, w: 10000, h: scr.height + 10000 - 2 * contentWrapper.cornerRadius },
            { x: scr.width, y: atBottom ? -10000 : 2 * contentWrapper.cornerRadius, w: 10000, h: scr.height + 10000 - 2 * contentWrapper.cornerRadius }
        ] : []
    }

    ShaderEffect {
        id: leftOuterCorner
        x: contentWrapper.dynamicMinX
        y: barWindow ? (barWindow.barPosition === "bottom" ? (barWindow.baseOffsetY - height) : (barWindow.baseOffsetY + barWindow.barHeight)) : 0
        width: contentWrapper.cornerRadius
        height: contentWrapper.cornerRadius
        visible: contentWrapper.isFill && !barSurface.visible && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: (barWindow && barWindow.barPosition === "bottom") ? 2.0 : 0.0
        property color color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)

        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/ui/corner_cutout.frag.qsb"

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    ShaderEffect {
        id: rightOuterCorner
        x: contentWrapper.dynamicMaxX - width
        y: barWindow ? (barWindow.barPosition === "bottom" ? (barWindow.baseOffsetY - height) : (barWindow.baseOffsetY + barWindow.barHeight)) : 0
        width: contentWrapper.cornerRadius
        height: contentWrapper.cornerRadius
        visible: contentWrapper.isFill && !barSurface.visible && (barWindow ? !barWindow.positionChanging : true)
        opacity: (visible && (!barWindow || barWindow.isRevealed)) ? 1.0 : 0.0
        z: 0

        property vector2d itemSize: Qt.vector2d(width, height)
        property real cornerIndex: (barWindow && barWindow.barPosition === "bottom") ? 3.0 : 1.0
        property color color: Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)

        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/ui/corner_cutout.frag.qsb"

        Behavior on opacity {
            enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
    }

    Repeater {
        id: groupBgRepeater
        model: contentWrapper.groupDefs
        delegate: Rectangle {
            id: groupBgRect
            objectName: "bar-group-background"
            z: 0
            property var groupIds: modelData

            function getGroupMetrics() {
                let firstX = -1;
                let lastX = -1;
                let lastW = 0;
                let groupH = barWindow ? ((contentWrapper.isSolid && contentWrapper.distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight) : ((contentWrapper.isSolid && contentWrapper.distinctPills) ? 24 : 30);
                for (let i = 0; i < groupIds.length; i++) {
                    let id = groupIds[i];
                    let widget = contentWrapper.getPositionedWidget(id);
                    if (!widget || !widget.visible) continue;

                    let targetW = (widget.targetWidth !== undefined) ? widget.targetWidth : widget.width;
                    if (targetW <= 0) continue;

                    let mx = (widget.targetX !== undefined) ? widget.targetX : widget.x;
                    let mw = targetW;

                    if (firstX === -1) firstX = mx;
                    lastX = mx;
                    lastW = mw;
                }
                if (firstX === -1) return { x: 0, w: 0, h: groupH, v: false };
                return { x: firstX - contentWrapper.groupPad, w: (lastX + lastW - firstX) + contentWrapper.groupPad * 2, h: groupH, v: true };
            }

            property var metrics: getGroupMetrics()

            x: metrics.x
            height: metrics.h
            y: barWindow ? (barWindow.baseOffsetY + (barWindow.barHeight - height) / 2) : 0
            width: metrics.w
            visible: metrics.v && (barWindow ? !barWindow.positionChanging : true) && width > 0 && (!contentWrapper.isSolid || contentWrapper.distinctPills)
            opacity: visible ? 1.0 : 0.0

            WallpaperBlur { id: groupGlass; anchors.fill: parent; radius: parent.radius }
            color: groupGlass.active ? "transparent" : (contentWrapper.isSolid && contentWrapper.distinctPills)
                ? Qt.alpha(Qt.darker(ThemeBackend.surface0, 1.15), (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
                : Qt.alpha(ThemeBackend.base, (barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0)
            radius: ThemeBackend.borderRadius
            border.width: 0

            Behavior on x {
                enabled: contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Behavior on width {
                enabled: contentWrapper.layoutAnimationsEnabled
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                enabled: barWindow && !barWindow.positionChanging && barWindow.startupCascadeFinished && !contentWrapper.suppressAnimation
                NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
            }
        }
    }

    Repeater {
        id: moduleRepeater
        model: BarModuleRegistry.moduleIds()
        delegate: BarModule {
            id: barMod
            moduleId: modelData
            z: BarModuleRegistry.moduleZ(modelData)
            barWindow: contentWrapper.barWindow
            isSolid: contentWrapper.isSolid || contentWrapper.isFill
            distinctPills: contentWrapper.distinctPills
            moduleActive: contentWrapper.isModuleActive(modelData)
            isGrouped: contentWrapper.isModuleGrouped(modelData)
            targetX: contentWrapper.getModuleX(modelData, contentWrapper.layoutState)
            suppressAnimation: contentWrapper.suppressAnimation
            layoutAnimationsEnabled: contentWrapper.layoutAnimationsEnabled
            isRightAligned: (modelData === "tray") ? contentWrapper.trayAlignRight : false

            Component.onCompleted: {
                contentWrapper.registerModuleInstance(modelData, barMod);
            }
        }
    }

    Item {
        id: systemWidget
        readonly property var kbPill: kbWidget ? kbWidget.kbPill : null
        readonly property var wifiPill: wifiWidget ? wifiWidget.wifiPill : null
        readonly property var btPill: btWidget ? btWidget.btPill : null
        readonly property var volPill: volWidget ? volWidget.volPill : null
        readonly property var batPill: batWidget ? batWidget.batPill : null

        function getBounds() {
            let pills = [sysMonWidget, kbWidget, wifiWidget, btWidget, volWidget, batWidget];
            let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
            let found = false;
            for (let i = 0; i < pills.length; i++) {
                let p = pills[i];
                if (p && p.visible && p.width > 0) {
                    found = true;
                    minX = Math.min(minX, p.x);
                    minY = Math.min(minY, p.y);
                    maxX = Math.max(maxX, p.x + p.width);
                    maxY = Math.max(maxY, p.y + p.height);
                }
            }
            if (!found) return { x: 0, y: 0, width: 0, height: 0 };
            return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
        }

        x: getBounds().x
        y: getBounds().y
        width: getBounds().width
        height: getBounds().height
    }
}
