import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../../"
import "../../../guide/theme"
import "../../../reusables"

// 4A. THEME -> GENERAL (List view with real ThemeLogic, ThemePresetGrid, FontPicker, ThemeEditor)
// Note: When Theme layout === Orbit and not inside General, SmartControl hosts the real Orbit (ThemeTab.qml) directly.
Column {
    id: page
    property var app: null
    spacing: 11

    ThemeLogic { id: tl; rootObj: page.app ? page.app.shim : null; onFontInstalled: fontPicker.close() }
    Item {
        width: 0; height: 0; visible: false
        FontPicker {
            id: fontPicker
            rootObj: page.app ? page.app.shim : null
            onOpened: if (page.app) page.app.modalOpened()
            onClosed: if (page.app) page.app.modalClosed()
            onFontSelected: function(filePath, fileName) {
                if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") tl.installFont(filePath, fileName);
            }
        }
        ThemeEditor {
            id: themeEditor
            rootObj: page.app ? page.app.shim : null
            onOpened: if (page.app) page.app.modalOpened()
            onClosed: if (page.app) page.app.modalClosed()
            tileWidth: Math.max(80, ((page.app ? page.app.width : 500) - 48 - 20) / 3)
            onSaveRequested: function(themeObj) { tl.saveCustomTheme(themeObj); tl.applyPreset(themeObj); }
        }
    }
    Component.onCompleted: { tl.loadAvailableFonts(); tl.activateTab(); }
    Component.onDestruction: { tl.activateDebounceTimer.stop(); themeEditor.close(); fontPicker.close(); }

    readonly property var wpDirs: tl.availableWallpaperDirs.length ? tl.availableWallpaperDirs : [tl.currentWallpaperDir]
    readonly property var wpDirNames: wpDirs.map(d => String(d).replace(Quickshell.env("HOME") || "\u0000", "~"))
    property int wpDirIdx: Math.max(0, wpDirs.indexOf(tl.currentWallpaperDir))
    onWpDirIdxChanged: { const d = wpDirs[wpDirIdx]; if (d && d !== tl.currentWallpaperDir) { tl.currentWallpaperDir = d; tl.updateWallpaperDirSetting(); } }

    readonly property var fontChoices: ["Adwaita Mono", "Noto Sans", "Google Sans", "JetBrains Mono"]
    readonly property var fontNames: {
        const have = (tl.availableFonts || []).concat(tl.curatedFonts || []);
        const list = fontChoices.filter(f => have.length === 0 || have.indexOf(f) >= 0);
        if (tl.currentFontFamily && list.indexOf(tl.currentFontFamily) < 0) list.unshift(tl.currentFontFamily);
        return list;
    }
    property int fontIdx: Math.max(0, fontNames.indexOf(tl.currentFontFamily))
    onFontIdxChanged: { const f = fontNames[fontIdx]; if (f && f !== tl.currentFontFamily) { tl.currentFontFamily = f; tl.updateFontSetting(); } }

    readonly property real borderRadiusFrac: Math.max(0, Math.min(1, (tl.currentBorderRadius - 8) / 18))
    function setBorderRadius(frac) {
        const snapped = tl.getSnappedRadius(Math.round(8 + frac * 18));
        if (!isNaN(snapped) && snapped >= 0 && snapped <= 64 && tl.currentBorderRadius !== snapped) {
            tl.currentBorderRadius = snapped;
            tl.borderRadiusDebounceTimer.restart();
        }
    }

    readonly property bool colorModeAvailable: Matugen.matugenActive && !Matugen.isRunning
    readonly property var themedAppNames: AppTheming.installedApps.map(x => x.name)
    property var themedApps: AppTheming.installedApps.filter(x => AppTheming.enabledIds.indexOf(x.id) >= 0).map(x => x.name)
    onThemedAppsChanged: {
        const ids = AppTheming.installedApps.filter(x => themedApps.indexOf(x.name) >= 0).map(x => x.id);
        if (ids.slice().sort().join() !== AppTheming.enabledIds.slice().sort().join() && !AppTheming.busy) AppTheming.setApps(ids);
    }
    property string themeSearch: ""
    onThemeSearchChanged: tl.themeSearchText = themeSearch

    component SCard: SmartCard {
        cornerRadius: page.app.cornerRadius; darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cCard; accent: page.app.cAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SToggle: SmartGeoToggleTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
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
    component SAction: SmartActionTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SField: SmartFieldTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component TileGrid: GridLayout { width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8 }

    // Back pill when navigated into General from the real Orbit Hub
    Rectangle {
        visible: page.app.orbitLayout && page.app.orbitInGeneral
        height: 30; width: 84; radius: 15; color: page.app.cTile
        border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.36)
        Text { anchors.centerIn: parent; text: "← Orbit"; font.family: page.app.uiFont; font.pixelSize: 11; font.bold: true; color: page.app.cAccent }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.app.orbitInGeneral = false; page.app.sfx.playSwitch(); } }
    }

    SCard {
        title: "Wallpaper Directory"; icon: "󰸉"
        SChoice { width: parent.width; icon: "󰸉"; title: "Folder"; options: page.wpDirNames; currentIndex: page.wpDirIdx; onPicked: (i) => { page.wpDirIdx = i; page.app.sfx.playSwitch(); } }
        SAction { width: parent.width; icon: "󰉋"; title: "Open wallpaper folder"; actionText: "Open"; onTriggered: { page.app.sfx.playClick(); if (tl.currentWallpaperDir !== "") FileManager.openFolder(tl.currentWallpaperDir, true); } }
    }

    SCard {
        title: "Text and shape"; icon: "󰛖"
        SChoice { width: parent.width; icon: "󰛖"; title: "Font Family"; options: page.fontNames; currentIndex: page.fontIdx; onPicked: (i) => { page.fontIdx = i; page.app.sfx.playSwitch(); } }
        TileGrid {
            SAction { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰉋"; title: "Fonts folder"; actionText: "Open"; onTriggered: { page.app.sfx.playClick(); FileManager.openFolder(Caching.stateDir ? (Caching.stateDir + "/fonts") : (Caching.home + "/.local/state/anserin/fonts"), true); } }
            SAction { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰐕"; title: "Install font"; actionText: "Add"; onTriggered: { page.app.sfx.playClick(); fontPicker.openPicker(); } }
        }
        SSlider { icon: "󰞁"; title: "Border radius"; value: page.borderRadiusFrac; valueText: Math.round(tl.currentBorderRadius) + " px"; onMoved: (v) => page.setBorderRadius(v) }
    }

    SCard {
        title: "Theme style"; icon: "󰏘"
        TileGrid {
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰔎"; title: "Color mode"; options: ["Light", "Dark"]; currentIndex: page.app.themeDark ? 1 : 0; enabled: page.colorModeAvailable; opacity: enabled ? 1.0 : 0.45; onPicked: (i) => { if (page.colorModeAvailable) Matugen.setColorMode(i === 1 ? "dark" : "light"); page.app.sfx.playSwitch(); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰏘"; title: "Liquid Glass"; geoShape: "hexagon"; checked: page.app.liquidGlass; onToggled: (v) => { Config.setSetting("theme.material", v ? "liquid" : "default"); page.app.sfx.playToggle(v); } }
        }
        SChoice {
            width: parent.width; icon: "󰀻"; title: "Apps"; multi: true; options: page.themedAppNames; selectedList: page.themedApps
            onMultiToggled: (lab) => { const c = page.themedApps.slice(); const i = c.indexOf(lab); if (i >= 0) c.splice(i, 1); else c.push(lab); page.themedApps = c; page.app.sfx.playClick(); }
        }
    }

    SCard {
        title: "Color themes"; icon: "󰏘"; statusText: (tl.currentPreset || "THEME").toUpperCase()
        SField { icon: "󰍉"; title: "Search themes"; text: page.themeSearch; placeholder: "Filter palette..."; actionText: "+ New"; onEdited: (v) => page.themeSearch = v; onSubmitted: () => { page.app.sfx.playQuick(); themeEditor.openForNew(); } }
        ThemePresetGrid { width: parent.width; page: tl; rootObj: page.app.shim }
    }
}
