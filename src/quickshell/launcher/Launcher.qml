import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
import "../reusables"

PanelWindow {
    id: launcherWindow
    readonly property int frameInset: ScreenEdges.inset(screen)
    margins { top: frameInset; bottom: frameInset; left: frameInset; right: frameInset }

    screen: LauncherController.screen

    WlrLayershell.namespace: "qs-applauncher"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: launcherWindow.isVisible
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    function closeLauncher() {
        LauncherController.hide();
    }

    property bool isVisible: LauncherController.isVisible
    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            LauncherController.hide();
            launcherWindow.configRevision++;
        }
    }

    readonly property string launcherPosition: content.launcherPosition
    readonly property real customWidth: content.customWidth

    property var rawBarSettings: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
    }

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

    property string barPosition: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "top";
        return Config.rawSettings.bar.position || "top";
    }

    property real barOpacity: {
        let dummy = configRevision;
        if (!rawBarSettings || rawBarSettings.opacity === undefined) return 1.0;
        let op = Number(rawBarSettings.opacity);
        return op > 1.0 ? (op / 100.0) : op;
    }

    // the Anserin interface has no Bar: nothing keeps room for it
    property bool barAutohide: AnserinMode.active || ((rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false)

    readonly property bool isOsdFullscreen: (typeof OsdController !== "undefined") ? Boolean(OsdController.isFullscreen) : false

    readonly property bool isToplevelFullscreen: {
        try {
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen) {
                let atl = ToplevelManager.activeToplevel;
                if (atl.screens && atl.screens.length > 0) {
                    return atl.screens.indexOf(launcherWindow.screen) !== -1;
                }
                return true;
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isHyprlandFullscreen: {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isFullscreenActive: ScreenEdges.modern ? ScreenEdges.fullscreen(screen) : (isOsdFullscreen || isToplevelFullscreen || isHyprlandFullscreen)

    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive

    property real barHeight: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height) ? s(Config.rawSettings.bar.height) : s(40);
    }

    property bool isBarSolid: (barStyle === "solid" || barStyle === "fill" || barStyle === "edge") && Math.round(barOpacity * 100) >= 100
    property bool barMatchesLauncher: isBarSolid && (attachEdge === barPosition) && !isBarEffectivelyHidden

    property string attachEdge: launcherPosition === "bar" ? barPosition : launcherPosition
    readonly property var attachedBar: screen ? LauncherController.bars[screen.name] || null : null
    readonly property real barAttachmentOffset: {
        if (launcherPosition !== "bar") return barMatchesLauncher ? barHeight : 0;
        if (!attachedBar) return isBarEffectivelyHidden ? 0 : barHeight;
        if (!attachedBar.visible || !attachedBar.isRevealed) return 0;
        // Overlap the painted edge to cover the antialiased seam between layer surfaces.
        return Math.max(0, attachedBar.barHeight + (isSideAttached ? 0 : attachedBar.edgePadding) + attachedBar.margins[attachEdge] - frameInset - 1);
    }
    readonly property real barAnchorCenter: {
        if (!attachedBar) return (isSideAttached ? height : width) / 2;
        return isSideAttached
            ? attachedBar.margins.top - frameInset + (attachedBar.currentBarMinY + attachedBar.currentBarMaxY) / 2
            : attachedBar.margins.left - frameInset + (attachedBar.currentBarMinX + attachedBar.currentBarMaxX) / 2;
    }
    property bool isSideAttached: attachEdge === "left" || attachEdge === "right"
    property bool isCentered: attachEdge === "center"

    onAttachEdgeChanged: {
        LauncherController.hide();
    }

    onBarStyleChanged: {
        LauncherController.hide();
    }

    onBarPositionChanged: {
        LauncherController.hide();
    }

    property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 2 : Math.min(32, 32 - 16 * Math.exp(-(ThemeBackend.borderRadius - 16) / 12))
    property real outerCornerRadius: cornerRadius

    property real baseLauncherWidth: Math.min(s(customWidth), Math.max(0, width - s(32)))
    property real collapsedCenterHeight: Math.min(s(110), Math.max(0, height - s(32)))

    property real targetLauncherHeight: content.targetHeight

    property real animatedLauncherHeight: Math.min(isCentered ? Math.max(s(420), targetLauncherHeight) : targetLauncherHeight, Math.max(0, height - s(32)))
    Behavior on animatedLauncherHeight {
        NumberAnimation {
            duration: 300
            easing.type: Easing.OutCubic
        }
    }

    visible: isVisible || container.animProgress > 0.001

    Item {
        id: topBarHole

        property int barThickness: launcherWindow.barHeight
        property string bp: launcherWindow.barPosition
        property bool activeBar: !launcherWindow.isBarEffectivelyHidden

        x: {
            if (!activeBar) return 0;
            if (bp === "left") return 0;
            if (bp === "right") return launcherWindow.width - barThickness;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "top") return 0;
            if (bp === "bottom") return launcherWindow.height - barThickness;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return barThickness;
            return launcherWindow.width;
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return barThickness;
            return launcherWindow.height;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: launcherWindow.isVisible
        onClicked: closeLauncher()
    }

    // Attached to a Solid or Fill bar on the same edge: drawn as a SurfaceField surface joined to the bar
    // (the Edge style and a centred launcher keep their own card and fillets)
    readonly property bool useField: !isCentered && (barStyle === "solid" || barStyle === "fill") && attachEdge === barPosition
    AttachedSurface {
        id: launcherSurface
        kind: "launcher"
        attachTo: ["bar"]
        publishShape: hostWindow ? hostWindow.visible : true
        visible: launcherWindow.useField && container.width > 0.5 && container.height > 0.5
        opacity: container.opacity
        filletRadius: container.dynamicCornerRadius
        readonly property real cr: container.dynamicCornerRadius
        readonly property string e: launcherWindow.attachEdge
        rects: [{ x: container.x, y: container.y, w: container.width, h: container.height,
                  r: [(e === "top" || e === "left") ? 0 : cr, (e === "top" || e === "right") ? 0 : cr,
                      (e === "bottom" || e === "right") ? 0 : cr, (e === "bottom" || e === "left") ? 0 : cr] }]
    }

    Item {
        id: container
        objectName: "launcher-content"

        MouseArea {
            anchors.fill: parent
        }

        property real animProgress: launcherWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: launcherWindow.isVisible ? (launcherWindow.isCentered ? 420 : 340) : (launcherWindow.isCentered ? 200 : 150)
                easing.type: launcherWindow.isVisible ? Easing.OutBack : Easing.InQuad
                easing.overshoot: launcherWindow.isVisible ? 1.28 : 1.0
            }
        }

        property real dynamicCornerRadius: Math.max(0, Math.min(launcherWindow.outerCornerRadius, (launcherWindow.isSideAttached ? width : height) * 0.5))

        x: {
            if (launcherWindow.attachEdge === "left") {
                return launcherWindow.barAttachmentOffset;
            }
            if (launcherWindow.attachEdge === "right") {
                let offset = launcherWindow.barAttachmentOffset;
                return (launcherWindow.width - offset) - width;
            }
            if (launcherWindow.launcherPosition === "bar") return Math.round(Math.max(0, Math.min(launcherWindow.width - width, launcherWindow.barAnchorCenter - width / 2)));
            return Math.floor((launcherWindow.width - width) / 2);
        }

        y: {
            if (launcherWindow.attachEdge === "top") {
                return launcherWindow.barAttachmentOffset;
            }
            if (launcherWindow.attachEdge === "bottom") {
                let offset = launcherWindow.barAttachmentOffset;
                return (launcherWindow.height - offset) - height;
            }
            if (launcherWindow.launcherPosition === "bar") return Math.round(Math.max(0, Math.min(launcherWindow.height - height, launcherWindow.barAnchorCenter - height / 2)));
            return Math.floor((launcherWindow.height - height) / 2);
        }

        width: launcherWindow.isSideAttached
               ? (launcherWindow.baseLauncherWidth * animProgress)
               : launcherWindow.baseLauncherWidth

        height: {
            if (launcherWindow.isCentered) {
                let baseH = launcherWindow.collapsedCenterHeight;
                let targetH = Math.max(baseH, launcherWindow.animatedLauncherHeight);
                return baseH + (targetH - baseH) * animProgress;
            }
            if (!launcherWindow.isSideAttached) {
                return launcherWindow.animatedLauncherHeight * animProgress;
            }
            return launcherWindow.animatedLauncherHeight;
        }

        opacity: launcherWindow.isCentered
                 ? Math.max(0.0, Math.min(1.0, animProgress * 1.5))
                 : ((launcherWindow.isVisible || animProgress > 0.001) ? 1.0 : 0.0)

        transformOrigin: Item.Center

        ShaderEffect {
            visible: !materialGlass.active && !launcherWindow.isCentered && !launcherWindow.useField && container.dynamicCornerRadius > 0.5
            x: {
                if (launcherWindow.attachEdge === "left") return 0;
                if (launcherWindow.attachEdge === "right") return parent.width - container.dynamicCornerRadius;
                return -container.dynamicCornerRadius;
            }
            y: {
                if (launcherWindow.attachEdge === "bottom") return parent.height - container.dynamicCornerRadius;
                if (launcherWindow.attachEdge === "left" || launcherWindow.attachEdge === "right") return -container.dynamicCornerRadius;
                return 0;
            }
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (launcherWindow.attachEdge === "bottom") return 3.0;
                if (launcherWindow.attachEdge === "left") return 2.0;
                if (launcherWindow.attachEdge === "right") return 3.0;
                return 1.0;
            }
            property color color: ThemeBackend.base
            fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        ShaderEffect {
            visible: !materialGlass.active && !launcherWindow.isCentered && !launcherWindow.useField && container.dynamicCornerRadius > 0.5
            x: {
                if (launcherWindow.attachEdge === "left") return 0;
                if (launcherWindow.attachEdge === "right") return parent.width - container.dynamicCornerRadius;
                return parent.width;
            }
            y: {
                if (launcherWindow.attachEdge === "bottom") return parent.height - container.dynamicCornerRadius;
                if (launcherWindow.attachEdge === "left" || launcherWindow.attachEdge === "right") return parent.height;
                return 0;
            }
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (launcherWindow.attachEdge === "bottom") return 2.0;
                if (launcherWindow.attachEdge === "left") return 0.0;
                if (launcherWindow.attachEdge === "right") return 1.0;
                return 0.0;
            }
            property color color: ThemeBackend.base
            fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        GlassFillets {
            card: bgCard
            surfaceEnabled: !launcherWindow.isCentered && !launcherWindow.useField
            filletRadius: container.dynamicCornerRadius
            filletDir: Qt.vector2d(launcherWindow.attachEdge === "left" ? -1 : (launcherWindow.attachEdge === "right" ? 1 : 0), launcherWindow.attachEdge === "top" ? -1 : (launcherWindow.attachEdge === "bottom" ? 1 : 0))
        }

        Rectangle {
            id: bgCard
            anchors.fill: parent
            radius: container.dynamicCornerRadius
            color: (materialGlass.active || launcherWindow.useField) ? "transparent" : ThemeBackend.base
            WallpaperBlur {
                id: materialGlass
                surfaceEnabled: !launcherWindow.useField
                anchors.fill: parent
                radius: parent.radius
                topLeftRadius: (launcherWindow.attachEdge === "top" || launcherWindow.attachEdge === "left") && !launcherWindow.isCentered ? 0 : parent.radius
                topRightRadius: (launcherWindow.attachEdge === "top" || launcherWindow.attachEdge === "right") && !launcherWindow.isCentered ? 0 : parent.radius
                bottomLeftRadius: (launcherWindow.attachEdge === "bottom" || launcherWindow.attachEdge === "left") && !launcherWindow.isCentered ? 0 : parent.radius
                bottomRightRadius: (launcherWindow.attachEdge === "bottom" || launcherWindow.attachEdge === "right") && !launcherWindow.isCentered ? 0 : parent.radius
            }
            border.width: 0
            border.color: launcherWindow.isCentered ? Qt.alpha(ThemeBackend.surface2, 0.6) : "transparent"
            clip: true

            Rectangle {
                visible: launcherWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: (materialGlass.active || launcherWindow.useField) ? "transparent" : ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "top" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: (materialGlass.active || launcherWindow.useField) ? "transparent" : ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: (materialGlass.active || launcherWindow.useField) ? "transparent" : ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "bottom" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: (materialGlass.active || launcherWindow.useField) ? "transparent" : ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: (materialGlass.active || launcherWindow.useField) ? "transparent" : ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "left" && container.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: (materialGlass.active || launcherWindow.useField) ? "transparent" : ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: 0
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: (materialGlass.active || launcherWindow.useField) ? "transparent" : ThemeBackend.base
            }

            Rectangle {
                visible: launcherWindow.attachEdge === "right" && container.dynamicCornerRadius > 0.5
                x: parent.width - container.dynamicCornerRadius
                y: parent.height - container.dynamicCornerRadius
                width: container.dynamicCornerRadius
                height: container.dynamicCornerRadius
                color: (materialGlass.active || launcherWindow.useField) ? "transparent" : ThemeBackend.base
            }

            LauncherContent {
                id: content
                anchors.fill: parent
                active: launcherWindow.isVisible
                searchAtBottom: launcherWindow.attachEdge === "bottom"
                listOpacity: launcherWindow.isCentered
                             ? Math.max(0.0, Math.min(1.0, (container.animProgress - 0.2) / 0.8))
                             : 1.0
                onCloseRequested: launcherWindow.closeLauncher()
            }
        }
    }
}
