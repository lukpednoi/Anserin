import QtQuick
import QtQuick.Layouts
import ".."
import "../../../"

// 7. TERMINAL — Desktop & Appearance, Scrollable Tiling, Infinite Desktop (SmartShortcutTile), Infinite Controls, Fastfetch
Column {
    id: page
    property var app: null
    spacing: 11

    Component.onCompleted: { if (typeof TerminalAppearance.refreshDragPrograms === "function") TerminalAppearance.refreshDragPrograms(); }

    readonly property var ta: TerminalAppearance.settings
    readonly property var inf: TerminalAppearance.infiniteSettings
    readonly property var ff: TerminalAppearance.fastfetchSettings
    function optIdx(list, value, fallback) { const i = list.indexOf(value); return i >= 0 ? i : fallback; }

    readonly property var termBgs: ["default", "blur", "clear"]
    readonly property int termBgIdx: optIdx(termBgs, ta.background, 0)
    property real termBlurFrac: Math.max(0, Math.min(1, ((ta.blurSize || TerminalAppearance.defaults.blurSize) - 1) / 19))
    onTermBlurFracChanged: termSave.restart()
    readonly property var termPrompts: ["default", "hex"]
    readonly property int termPromptIdx: optIdx(termPrompts, ta.prompt, 0)
    readonly property var termBorders: ["white", "default", "theme", "none"]
    readonly property int termBorderIdx: optIdx(termBorders, ta.border, 1)
    readonly property var termWss: ["vertical", "horizontal"]
    readonly property int termWsIdx: optIdx(termWss, ta.workspace, 0)

    readonly property var scrollLayouts: ["hyprland", "niri", "hybrid"]
    readonly property int scrollLayoutIdx: optIdx(scrollLayouts, TerminalAppearance.scrollableSettings.windowLayout || "hyprland", 0)
    readonly property bool scrollApps: !!TerminalAppearance.scrollableSettings.appsScrollable

    property real infCellFrac: Math.max(0, Math.min(1, ((inf.cellScale || 100) - 50) / 100))
    onInfCellFracChanged: termSave.restart()
    readonly property var cliToyNames: TerminalAppearance.availableDragPrograms.map(x => x.name)
    property var cliToys: TerminalAppearance.availableDragPrograms.filter(x => TerminalAppearance.cliToys.indexOf(x.id) >= 0).map(x => x.name)
    onCliToysChanged: {
        const ids = TerminalAppearance.availableDragPrograms.filter(x => cliToys.indexOf(x.name) >= 0).map(x => x.id);
        if (ids.slice().sort().join() !== TerminalAppearance.cliToys.slice().sort().join()) TerminalAppearance.setCliToys(ids);
    }

    readonly property var keyModes: ["anserin", "custom"]
    readonly property int panModeIdx: optIdx(keyModes, inf.panMode, 0)
    readonly property int navModeIdx: optIdx(keyModes, inf.navigateMode, 0)
    readonly property int moveModeIdx: optIdx(keyModes, inf.moveMode, 0)
    readonly property int resizeModeIdx: optIdx(keyModes, inf.resizeMode, 0)

    readonly property bool autoFastfetch: !!ff.auto
    readonly property bool ffHideLogo: !!ff.hideLogo
    readonly property var ffModes: ["default", "ascii", "pic"]
    readonly property int ffModeIdx: optIdx(ffModes, ff.mode, 0)
    readonly property bool ffRandom: !!ff.random
    readonly property var ffRandomSrcs: ["ascii", "pic", "both"]
    readonly property int ffRandomSrcIdx: optIdx(ffRandomSrcs, ff.randomMode, 2)

    Timer {
        id: termSave; interval: 400
        onTriggered: {
            const blur = Math.round(1 + page.termBlurFrac * 19);
            if (blur !== (page.ta.blurSize || TerminalAppearance.defaults.blurSize)) TerminalAppearance.setOption("blurSize", blur);
            const cell = Math.round((50 + page.infCellFrac * 100) / 10) * 10;
            if (cell !== (page.inf.cellScale || 100)) TerminalAppearance.setInfiniteOption("cellScale", cell);
        }
    }

    Connections {
        target: TerminalAppearance
        ignoreUnknownSignals: true
        function onShortcutErrorChanged() { if (TerminalAppearance.shortcutError && page.app) page.app.showToast(TerminalAppearance.shortcutError); }
        function onKeysErrorChanged() {
            const e = TerminalAppearance.keysError || {};
            for (const k in e) if (e[k] && page.app) { page.app.showToast(e[k]); break; }
        }
    }

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
    component SShortcut: SmartShortcutTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
        onListeningChanged: if (page.app) page.app.shortcutListening = listening
    }
    component TileGrid: GridLayout { width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8 }

    SCard {
        title: "Desktop & Appearance"; icon: "󰆍"
        Rectangle {
            width: parent.width; height: 90; radius: 14
            color: page.termBgIdx === 0 ? "#11141c" : Qt.rgba(0.07, 0.09, 0.13, page.termBgIdx === 2 ? 0.35 : (0.55 + page.termBlurFrac * 0.35))
            border.width: page.termBorderIdx === 3 ? 0 : 1.6
            border.color: page.termBorderIdx === 0 ? "#ffffff" : (page.termBorderIdx === 2 ? page.app.cAccent : Qt.rgba(1, 1, 1, 0.22))
            Column {
                anchors.fill: parent; anchors.margins: 12; spacing: 4
                Row { spacing: 6
                    Text { text: page.termPromptIdx === 1 ? "⬢" : "❯"; font.pixelSize: 12; color: page.app.cAccent }
                    Text { text: (page.app.profileName || "user") + "@" + (SystemInfo.hostname || "linux"); font.family: "monospace"; font.pixelSize: 11; font.bold: true; color: page.app.cAccent }
                    Text { text: "~/Anserin"; font.family: "monospace"; font.pixelSize: 11; color: page.app.cAccent2 } }
                Text { visible: page.autoFastfetch && !page.ffHideLogo; text: "OS: " + (SystemInfo.osName || "") + " · " + (SystemInfo.kernelVersion || ""); font.family: "monospace"; font.pixelSize: 10; color: page.app.cSub }
                Text { text: "Shell: " + (SystemInfo.shell || "") + " · Desktop: " + (SystemInfo.desktopEnv || ""); font.family: "monospace"; font.pixelSize: 10; color: page.app.cText }
            }
        }
        SChoice { width: parent.width; icon: "󰆍"; title: "Background"; options: ["Default", "Blur", "Clear"]; currentIndex: page.termBgIdx; onPicked: (i) => { TerminalAppearance.setOption("background", page.termBgs[i]); page.app.sfx.playSwitch(); } }
        SSlider { visible: page.termBgIdx === 1; icon: "󰂚"; title: "Blur size"; value: page.termBlurFrac; valueText: String(Math.round(1 + page.termBlurFrac * 19)); onMoved: (v) => page.termBlurFrac = v }
        TileGrid {
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰘳"; title: "Prompt"; options: ["Default", "Hex"]; currentIndex: page.termPromptIdx; onPicked: (i) => { TerminalAppearance.setOption("prompt", page.termPrompts[i]); page.app.sfx.playSwitch(); } }
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰹑"; title: "Workspace"; options: ["Vertical", "Horizontal"]; currentIndex: page.termWsIdx; onPicked: (i) => { TerminalAppearance.setOption("workspace", page.termWss[i]); page.app.sfx.playSwitch(); } }
        }
        SChoice { width: parent.width; icon: "󰖯"; title: "Border"; options: ["White", "Default", "Theme", "None"]; currentIndex: page.termBorderIdx; onPicked: (i) => { TerminalAppearance.setOption("border", page.termBorders[i]); page.app.sfx.playSwitch(); } }
    }

    SCard {
        title: "Scrollable Tiling"; icon: "󰖯"
        SChoice { width: parent.width; icon: "󰆍"; title: "Window layout"; options: ["Hyprland", "niri", "Hybrid"]; currentIndex: page.scrollLayoutIdx; onPicked: (i) => { TerminalAppearance.setScrollableOption("windowLayout", page.scrollLayouts[i]); page.app.sfx.playSwitch(); } }
        SToggle { width: parent.width; icon: "󰀻"; title: "Scrollable apps"; geoShape: "arch"; checked: page.scrollApps; onToggled: (v) => { TerminalAppearance.setScrollableOption("appsScrollable", v); page.app.sfx.playToggle(v); } }
    }

    SCard {
        title: "Infinite Desktop"; icon: "󰍹"; statusText: "HOLD & RELEASE"
        SShortcut {
            width: parent.width; icon: "󰌌"; title: "Toggle shortcut"
            shortcut: page.inf.toggleShortcut || ""
            onRecorded: (c) => { TerminalAppearance.saveToggleShortcut(c); page.app.sfx.playLock(); page.app.showToast("Saved: " + c); }
        }
        SSlider { icon: "󰙖"; title: "Window size (one cell of 2×2)"; value: page.infCellFrac; valueText: Math.round((50 + page.infCellFrac * 100) / 10) * 10 + "%"; onMoved: (v) => page.infCellFrac = v }
        SChoice {
            width: parent.width; icon: "󰆍"; title: "CLI toy"; multi: true; options: page.cliToyNames; selectedList: page.cliToys
            onMultiToggled: (lab) => { const c = page.cliToys.slice(); const i = c.indexOf(lab); if (i >= 0) c.splice(i, 1); else c.push(lab); page.cliToys = c; page.app.sfx.playClick(); }
        }
    }

    SCard {
        title: "Infinite Controls"; icon: "󰆾"
        TileGrid {
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰆾"; title: "Pan"; options: ["Anserin", "Custom"]; currentIndex: page.panModeIdx; onPicked: (i) => { TerminalAppearance.setInfiniteOption("panMode", page.keyModes[i]); page.app.sfx.playSwitch(); } }
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰁔"; title: "Go to window"; options: ["Anserin", "Custom"]; currentIndex: page.navModeIdx; onPicked: (i) => { TerminalAppearance.setInfiniteOption("navigateMode", page.keyModes[i]); page.app.sfx.playSwitch(); } }
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰁁"; title: "Move window"; options: ["Anserin", "Custom"]; currentIndex: page.moveModeIdx; onPicked: (i) => { TerminalAppearance.setInfiniteOption("moveMode", page.keyModes[i]); page.app.sfx.playSwitch(); } }
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰩨"; title: "Resize"; options: ["Anserin", "Custom"]; currentIndex: page.resizeModeIdx; onPicked: (i) => { TerminalAppearance.setInfiniteOption("resizeMode", page.keyModes[i]); page.app.sfx.playSwitch(); } }
        }
        SShortcut { visible: page.panModeIdx === 1; width: parent.width; icon: "󰌌"; title: "Pan keys"; shortcut: page.inf.panKeys || ""; onRecorded: (c) => { TerminalAppearance.saveInfiniteKeys("panKeys", c); page.app.sfx.playLock(); } }
        SShortcut { visible: page.navModeIdx === 1; width: parent.width; icon: "󰌌"; title: "Go to window keys"; shortcut: page.inf.navigateKeys || ""; onRecorded: (c) => { TerminalAppearance.saveInfiniteKeys("navigateKeys", c); page.app.sfx.playLock(); } }
        SShortcut { visible: page.moveModeIdx === 1; width: parent.width; icon: "󰌌"; title: "Move window keys"; shortcut: page.inf.moveKeys || ""; onRecorded: (c) => { TerminalAppearance.saveInfiniteKeys("moveKeys", c); page.app.sfx.playLock(); } }
        SShortcut { visible: page.resizeModeIdx === 1; width: parent.width; icon: "󰌌"; title: "Resize keys"; shortcut: page.inf.resizeKeys || ""; onRecorded: (c) => { TerminalAppearance.saveInfiniteKeys("resizeKeys", c); page.app.sfx.playLock(); } }
    }

    SCard {
        title: "Fastfetch"; icon: "󰒓"
        TileGrid {
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰆍"; title: "Auto Fastfetch"; geoShape: "star5"; checked: page.autoFastfetch; onToggled: (v) => { TerminalAppearance.setFastfetchOption("auto", v); page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰈉"; title: "Hide ASCII / Pic"; geoShape: "cookie6"; checked: page.ffHideLogo; onToggled: (v) => { TerminalAppearance.setFastfetchOption("hideLogo", v); page.app.sfx.playToggle(v); } }
        }
        TileGrid {
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰆍"; title: "Fastfetch logo"; options: ["Default", "ASCII", "Pic"]; currentIndex: page.ffModeIdx; enabled: !page.ffRandom; opacity: enabled ? 1.0 : 0.45; onPicked: (i) => { TerminalAppearance.setFastfetchOption("mode", page.ffModes[i]); page.app.sfx.playSwitch(); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰒟"; title: "Random"; geoShape: "softburst"; checked: page.ffRandom; onToggled: (v) => { TerminalAppearance.setFastfetchOption("random", v); page.app.sfx.playToggle(v); } }
        }
        SChoice { visible: page.ffRandom; width: parent.width; icon: "󰒟"; title: "Random source"; options: ["ASCII", "Pic", "Both"]; currentIndex: page.ffRandomSrcIdx; onPicked: (i) => { TerminalAppearance.setFastfetchOption("randomMode", page.ffRandomSrcs[i]); page.app.sfx.playSwitch(); } }
        SAction {
            visible: page.ffRandom || page.ffModeIdx > 0; width: parent.width; icon: "󰐕"; title: "Add ASCII / Pic"; actionText: "Open folder"
            onTriggered: {
                page.app.sfx.playClick();
                const pics = page.ffRandom ? page.ff.randomMode === "pic" : page.ff.mode === "pic";
                FileManager.openFolder(TerminalAppearance.fastfetchDir + (pics ? "/pngs" : "/ascii"), false);
            }
        }
    }
}
