import QtQuick
import QtQuick.Layouts
import ".."
import "../../../"
import "../../../guide/theme"

// 4C. THEME -> STYLE (real ThemeLayoutPreview, WallpaperLayoutCards, TransitionPreview + Replay button & Duration wave)
Column {
    id: page
    property var app: null
    spacing: 11

    readonly property var ts: Config.getSetting("theme", {})
    readonly property int pageLayoutIdx: ts.generalLayout === "orbit" ? 1 : 0
    readonly property var orbitImageStyles: ["rectangle", "circle", "bordered"]
    readonly property int orbitImgIdx: Math.max(0, orbitImageStyles.indexOf(ts.orbitImageStyle))
    readonly property int orbitRingColorIdx: ts.orbitBorderColor === "white" ? 0 : 1
    readonly property int orbitLinkIdx: ts.orbitConnectionStyle === "wifi" ? 1 : 0
    readonly property int orbitBgIdx: ts.orbitBackground === "transparent" ? 1 : 0
    readonly property int orbitRingsIdx: ts.orbitRingStyle === "wifi" ? 1 : 0
    readonly property int wpLayoutIdx: Config.getSetting("theme.wallpaperStyle", "original") === "grid" ? 1 : 0

    readonly property var transition: Wallpaper.transitionSettings()
    readonly property int wpFxIdx: Math.max(0, Wallpaper.transitionIds.indexOf(transition.pool[0]))
    readonly property var fxSettings: transition.effects[Wallpaper.transitionIds[wpFxIdx]] || ({})
    function setEffect(i) {
        if (Wallpaper.transitionIds[i] === transition.pool[0]) return;
        const next = Wallpaper.transitionSettings();
        next.mode = "custom";
        next.pool = [Wallpaper.transitionIds[i]];
        Config.setSetting("wallpaperTransition", next);
    }
    function updateFx(key, value) {
        const next = Wallpaper.transitionSettings();
        const id = Wallpaper.transitionIds[wpFxIdx];
        next.effects[id] = Object.assign({}, next.effects[id] || {}, ({ [key]: value }));
        Config.setSetting("wallpaperTransition", next);
    }
    property real wpDurFrac: Math.max(0, Math.min(1, ((fxSettings.duration || 1000) - 100) / 2900))
    readonly property int durMs: Math.round(100 + wpDurFrac * 2900)
    onWpFxIdxChanged: {
        durSave.stop();
        wpDurFrac = Math.max(0, Math.min(1, ((fxSettings.duration || 1000) - 100) / 2900));
    }
    Timer { id: durSave; interval: 400
            onTriggered: { const ms = Math.round(100 + page.wpDurFrac * 2900); if (ms !== page.fxSettings.duration) page.updateFx("duration", ms); } }
    readonly property string fxDirKey: wpFxIdx === 1 ? "orientation" : wpFxIdx === 2 ? "origin" : "direction"
    readonly property var fxDirValues: wpFxIdx === 1 ? ["random", "horizontal", "vertical"] : wpFxIdx === 2 ? ["random", "center"] : ["random"].concat(Wallpaper.swipeDirections)
    readonly property int wpDirIdxOpt: Math.max(0, fxDirValues.indexOf(fxSettings[fxDirKey]))
    function replayTransition() { Qt.callLater(transitionPreview.play); }

    component SCard: SmartCard {
        cornerRadius: page.app.cornerRadius; darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cCard; accent: page.app.cAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SSlider: SmartSliderTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; accent: page.app.cAccent; accent2: page.app.cAccent2
        textColor: page.app.cText; subColor: page.app.cSub; uiFont: page.app.uiFont; iconFont: page.app.iconFont
        active: visible; onStepped: page.app.sfx.playTick(); onLockedFull: page.app.sfx.playLock()
    }
    component SChoice: SmartChoiceTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component TileGrid: GridLayout { width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8 }

    SCard {
        title: "Page layout"; icon: "󰏘"; statusText: page.pageLayoutIdx === 1 ? "ORBIT" : "LIST"
        BoardStyles {
            width: parent.width
            model: [{ key: "original", name: "List" }, { key: "orbit", name: "Orbit" }]
            current: page.pageLayoutIdx === 1 ? "orbit" : "original"
            ratio: 560 / 880
            accent: page.app.cAccent
            preview: Component {
                ThemeLayoutPreview {
                    appearance: parent.styleKey
                    imageStyle: page.orbitImageStyles[page.orbitImgIdx]
                    borderStyle: page.orbitRingColorIdx === 0 ? "white" : "theme"
                    connectionStyle: page.orbitLinkIdx === 1 ? "wifi" : "link"
                    ringStyle: page.orbitRingsIdx === 1 ? "wifi" : "original"
                }
            }
            onPicked: (key) => { Config.setSetting("theme.generalLayout", key); page.app.orbitInGeneral = false; page.app.sfx.playSwitch(); }
        }
    }

    SCard {
        visible: page.pageLayoutIdx === 1
        title: "Orbit"; icon: "󰖩"
        SChoice { width: parent.width; icon: "󰸉"; title: "Center image"; options: ["Square", "Round", "Round + ring"]; currentIndex: page.orbitImgIdx; onPicked: (i) => { Config.setSetting("theme.orbitImageStyle", page.orbitImageStyles[i]); page.app.sfx.playSwitch(); } }
        TileGrid {
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰏘"; title: "Ring color"; options: ["White", "Theme"]; currentIndex: page.orbitRingColorIdx; onPicked: (i) => { Config.setSetting("theme.orbitBorderColor", i === 0 ? "white" : "theme"); page.app.sfx.playSwitch(); } }
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰖩"; title: "Links"; options: ["Flow", "Lightning"]; currentIndex: page.orbitLinkIdx; onPicked: (i) => { Config.setSetting("theme.orbitConnectionStyle", i === 1 ? "wifi" : "link"); page.app.sfx.playSwitch(); } }
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰖩"; title: "Background"; options: ["Panel", "Transparent"]; currentIndex: page.orbitBgIdx; onPicked: (i) => { Config.setSetting("theme.orbitBackground", i === 1 ? "transparent" : "wifi"); page.app.sfx.playSwitch(); } }
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰖩"; title: "Rings"; options: ["Pulse", "Lightning"]; currentIndex: page.orbitRingsIdx; onPicked: (i) => { Config.setSetting("theme.orbitRingStyle", i === 1 ? "wifi" : "original"); page.app.sfx.playSwitch(); } }
        }
    }

    SCard {
        title: "Wallpaper"; icon: "󰸉"; statusText: page.wpLayoutIdx === 0 ? "CAROUSEL" : "GRID"
        WallpaperLayoutCards { width: parent.width; rootObj: page.app.shim }
    }

    SCard {
        title: "Transition"; icon: "󰐊"; statusText: ["FADE", "WIPE", "CIRCLE", "SWIPE", "PAINT"][page.wpFxIdx]
        Rectangle {
            width: parent.width; height: transitionPreview.implicitHeight
            radius: Math.min(ThemeBackend.borderRadius, 14); color: ThemeBackend.mantle; clip: true
            border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.22)
            TransitionPreview { id: transitionPreview; anchors.fill: parent; rootObj: page.app.shim }
            // Replay pill in bottom-right corner inside the preview box
            Rectangle {
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10
                height: 28; width: repRow.implicitWidth + 20; radius: 14
                color: repMa.containsMouse ? Qt.rgba(0, 0, 0, 0.78) : Qt.rgba(0, 0, 0, 0.62)
                border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22)
                Row {
                    id: repRow; anchors.centerIn: parent; spacing: 5
                    Text { text: "󰐊"; font.family: page.app.iconFont; font.pixelSize: 12; color: page.app.cAccent; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Replay"; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea {
                    id: repMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { page.app.sfx.playClick(); transitionPreview.play(); }
                }
            }
        }
        SChoice { width: parent.width; icon: "󰸉"; title: "Effect"; options: ["Fade", "Wipe", "Circle", "Swipe", "Paint"]; currentIndex: page.wpFxIdx; onPicked: (i) => { page.setEffect(i); page.replayTransition(); page.app.sfx.playSwitch(); } }
        SSlider { icon: "󰔛"; title: "Duration"; value: page.wpDurFrac; valueText: page.durMs + " ms"; onMoved: (v) => { page.wpDurFrac = v; durSave.restart(); } }
        SChoice {
            visible: page.wpFxIdx !== 0 && page.wpFxIdx !== 4; width: parent.width
            icon: "󰁔"; title: "Direction"
            options: page.wpFxIdx === 1 ? ["Random", "Horizontal", "Vertical"]
                   : page.wpFxIdx === 2 ? ["Random", "Center"]
                   : ["Random", "Left", "Right", "Top", "Bottom"]
            currentIndex: Math.min(page.wpDirIdxOpt, options.length - 1)
            onPicked: (i) => { const v = page.fxDirValues[i]; if (v) page.updateFx(page.fxDirKey, v); page.replayTransition(); page.app.sfx.playSwitch(); }
        }
    }
}
