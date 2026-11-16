import QtQuick
import "../../../"
import "../../../guide/theme"
import ".."

// Theme → Style as a board, doing what guide/theme/ThemeStyleTab.qml does: the Settings layout (real previews),
// the Orbit look (only with Orbit), the window border (hidden in the Anserin interface, as there), and the
// wallpaper picker's layout and transitions (their real previews, the choices as cells).
BoardPage {
    id: page
    readonly property var ts: Config.getSetting("theme", {})
    readonly property string layout: ts.generalLayout === "orbit" ? "orbit" : "original"
    readonly property var imageStyles: ["rectangle", "circle", "bordered"]
    readonly property string imageStyle: imageStyles.indexOf(ts.orbitImageStyle) >= 0 ? ts.orbitImageStyle : "rectangle"
    readonly property bool orbit: layout === "orbit"

    BoardCard {
        title: "Page layout"; icon: "󰏘"; accent: page.accent
        BoardStyles {
            model: [{ key: "original", name: "List" }, { key: "orbit", name: "Orbit" }]
            current: page.layout
            ratio: 560 / 880
            accent: page.accent
            preview: Component {
                ThemeLayoutPreview {
                    appearance: parent.styleKey
                    imageStyle: page.imageStyle
                    borderStyle: page.ts.orbitBorderColor === "white" ? "white" : "theme"
                    connectionStyle: page.ts.orbitConnectionStyle === "wifi" ? "wifi" : "link"
                    ringStyle: page.ts.orbitRingStyle === "wifi" ? "wifi" : "original"
                }
            }
            onPicked: (key) => Config.setSetting("theme.generalLayout", key)
        }
    }
    BoardCard {
        title: "Orbit"; icon: "󰖩"; accent: page.accent
        visible: page.orbit
        BoardCell { kind: "seg"; icon: "󰸉"; title: "Center image"; options: ["Square", "Round", "Round + ring"]; values: page.imageStyles
                    value: page.imageStyle; onPicked: (v) => Config.setSetting("theme.orbitImageStyle", v) }
        BoardCell { kind: "seg"; icon: "󰏘"; title: "Ring color"; options: ["White", "Theme"]; values: ["white", "theme"]
                    value: page.ts.orbitBorderColor === "white" ? "white" : "theme"; onPicked: (v) => Config.setSetting("theme.orbitBorderColor", v) }
        BoardCell { kind: "seg"; icon: "󰖩"; title: "Links"; options: ["Flow", "Lightning"]; values: ["link", "wifi"]
                    value: page.ts.orbitConnectionStyle === "wifi" ? "wifi" : "link"; onPicked: (v) => Config.setSetting("theme.orbitConnectionStyle", v) }
        BoardCell { kind: "seg"; icon: "󰖩"; title: "Background"; options: ["Panel", "Transparent"]; values: ["wifi", "transparent"]
                    value: page.ts.orbitBackground === "transparent" ? "transparent" : "wifi"; onPicked: (v) => Config.setSetting("theme.orbitBackground", v) }
        BoardCell { kind: "seg"; icon: "󰖩"; title: "Rings"; options: ["Pulse", "Lightning"]; values: ["original", "wifi"]
                    value: page.ts.orbitRingStyle === "wifi" ? "wifi" : "original"; onPicked: (v) => Config.setSetting("theme.orbitRingStyle", v) }
    }
    BoardCard {
        title: "Window border"; icon: "󰕰"; accent: page.accent
        visible: !AnserinMode.active
        BoardCell { kind: "seg"; icon: "󰕰"; title: "Style"; options: ["Classic", "Modern"]; values: ["classic", "modern"]
                    value: ScreenEdges.modern ? "modern" : "classic"; onPicked: (v) => Config.setSetting("theme.windowBorder", v) }
        BoardCell { kind: "stepper"; icon: "󰝤"; title: "Border thickness"; hidden: !ScreenEdges.modern
                    from: 2; to: 32; step: 1; suffix: " px"; value: ScreenEdges.thickness
                    onPicked: (v) => Config.setSetting("theme.windowBorderThickness", v) }
    }
    // the wallpaper picker's layout and the transition (guide/theme/WallpaperTransitions.qml): the previews are
    // the real ones, the choices are cells
    readonly property var transition: Wallpaper.transitionSettings()
    readonly property int effect: Math.max(0, Wallpaper.transitionIds.indexOf(transition.pool[0]))
    readonly property string effectId: Wallpaper.transitionIds[effect]
    readonly property var effectSettings: transition.effects[effectId]
    readonly property string dirSetting: effect === 1 ? "orientation" : effect === 2 ? "origin" : "direction"
    readonly property var dirValues: effect === 1 ? ["random", "horizontal", "vertical"] : effect === 2 ? ["random", "center"] : ["random"].concat(Wallpaper.swipeDirections)
    readonly property var dirNames: effect === 1 ? ["Random", "Horizontal", "Vertical"] : effect === 2 ? ["Random", "Center"]
                                  : ["Random", "Left", "Right", "Top", "Bottom", "Top left", "Top right", "Bottom left", "Bottom right"]
    function selectEffect(index) {
        const next = Wallpaper.transitionSettings();
        next.mode = "custom";
        next.pool = [Wallpaper.transitionIds[index]];
        Config.setSetting("wallpaperTransition", next);
        Qt.callLater(transitionPreview.play);
    }
    function updateEffect(key, value) {
        const next = Wallpaper.transitionSettings();
        next.effects[effectId][key] = value;
        Config.setSetting("wallpaperTransition", next);
        Qt.callLater(transitionPreview.play);
    }
    BoardCard {
        title: "Wallpaper"; icon: "󰸉"; accent: page.accent
        WallpaperLayoutCards { rootObj: page.rootObj }
    }
    BoardCard {
        title: "Transition"; icon: "󰐊"; accent: page.accent
        TransitionPreview { id: transitionPreview; rootObj: page.rootObj }
        BoardCell { kind: "select"; icon: "󰸉"; title: "Effect"; options: ["Fade", "Wipe", "Circle", "Swipe", "Paint"]; values: [0, 1, 2, 3, 4]
                    value: page.effect; onPicked: (v) => page.selectEffect(v) }
        BoardCell { kind: "stepper"; icon: "󰔛"; title: "Duration"; from: 100; to: 10000; step: 100; suffix: " ms"
                    value: page.effectSettings.duration; onPicked: (v) => page.updateEffect("duration", v) }
        BoardCell { kind: "select"; icon: "󰁔"; title: "Direction"; hidden: page.effect === 0 || page.effect === 4
                    options: page.dirNames; values: page.dirValues
                    value: page.dirValues.indexOf(page.effectSettings[page.dirSetting]) >= 0 ? page.effectSettings[page.dirSetting] : "random"
                    onPicked: (v) => page.updateEffect(page.dirSetting, v) }
        BoardCell { kind: "action"; icon: "󰐊"; title: "Preview"; actionText: "Preview"; onActivated: transitionPreview.play() }
    }
}
