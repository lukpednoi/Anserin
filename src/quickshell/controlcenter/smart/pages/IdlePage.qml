import QtQuick
import QtQuick.Layouts
import ".."
import "../../../"
import "../../../guide/shared"

// 9. IDLE — IdleLogic + Caffeine + 4 timeout wave sliders
Column {
    id: page
    property var app: null
    spacing: 11

    IdleLogic { id: il; rootObj: page.app ? page.app.shim : null }

    readonly property var idleRanges: ({ dim: [10, 600], lock: [60, 1200], dpms: [120, 1800], suspend: [300, 3300] })
    function idleFrac(id) { const r = idleRanges[id]; const t = il.getActionTimeout(il.getActionData(id)); return Math.max(0, Math.min(1, (t - r[0]) / r[1])); }
    function idleSecs(id, frac) { const r = idleRanges[id]; return Math.round((r[0] + frac * r[1]) / 10) * 10; }
    property real dimFrac: idleFrac("dim")
    property real lockFrac: idleFrac("lock")
    property real dpmsFrac: idleFrac("dpms")
    property real sleepFrac: idleFrac("suspend")
    onDimFracChanged: idleSave.restart()
    onLockFracChanged: idleSave.restart()
    onDpmsFracChanged: idleSave.restart()
    onSleepFracChanged: idleSave.restart()

    Timer {
        id: idleSave; interval: 400
        onTriggered: {
            const pairs = [["dim", page.dimFrac], ["lock", page.lockFrac], ["dpms", page.dpmsFrac], ["suspend", page.sleepFrac]];
            for (const p of pairs) {
                const secs = page.idleSecs(p[0], p[1]);
                if (secs !== il.getActionTimeout(il.getActionData(p[0]))) il.updateActionProp(p[0], false, "timeout", secs);
            }
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
    component SStepper: SmartStepperTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent
        textColor: page.app.cText; subColor: page.app.cSub; uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component TileGrid: GridLayout { width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8 }

    SCard {
        title: "Idle"; icon: "󰒲"; statusText: Caffeine.enabled ? "AWAKE" : "AUTO"
        TileGrid {
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰒲"; title: "Enable Idle System"; geoShape: "cookie12"; checked: il.idleEnabled; onToggled: (v) => { il.updateRootSetting("enabled", v); page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰅶"; title: "Keep Awake"; geoShape: "star6"; available: il.idleEnabled; checked: Caffeine.enabled; onToggled: (v) => { if (v) Caffeine.start(); else Caffeine.stop(); page.app.sfx.playToggle(v); } }
        }
        SChoice {
            visible: il.idleEnabled; width: parent.width
            icon: "󰅶"; title: "Keep Awake for"; options: ["Timer", "Forever"]
            currentIndex: Caffeine.foreverMode ? 1 : 0
            onPicked: (i) => { il.updateRootSetting("keepAwakeMode", i === 1 ? "forever" : "timer"); page.app.sfx.playSwitch(); }
        }
        SStepper {
            visible: il.idleEnabled && !Caffeine.foreverMode; width: parent.width
            icon: "󰔛"; title: "Keep Awake Timer"
            value: Caffeine.timerMinutes; from: 5; to: 480; step: 5; suffix: " min"
            onChanged: (v) => { il.updateRootSetting("keepAwakeMinutes", Math.round(v)); page.app.sfx.playStepper(); }
        }
    }

    SCard {
        visible: il.idleEnabled
        title: "Timeout"; icon: "󰔛"; statusText: "LOW ↔ 100% STRAIGHT"
        SSlider { icon: "󰃛"; title: "Dim Screen"; value: page.dimFrac; valueText: page.idleSecs("dim", page.dimFrac) + " s"; onMoved: (v) => page.dimFrac = v }
        SSlider { icon: "󰌾"; title: "Lock Screen"; value: page.lockFrac; valueText: page.idleSecs("lock", page.lockFrac) + " s"; onMoved: (v) => page.lockFrac = v }
        SSlider { icon: "󰍹"; title: "Display Off"; value: page.dpmsFrac; valueText: page.idleSecs("dpms", page.dpmsFrac) + " s"; onMoved: (v) => page.dpmsFrac = v }
        SSlider { icon: "󰒲"; title: "Suspend"; value: page.sleepFrac; valueText: page.idleSecs("suspend", page.sleepFrac) + " s"; onMoved: (v) => page.sleepFrac = v }
    }
}
