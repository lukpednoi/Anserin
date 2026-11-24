import QtQuick
import QtQuick.Layouts
import ".."
import "../../../"
import "../../../bar"

// 5. PANEL — Edge panels, real bar module face previews for Workspaces, Music, Time & Date, Network
Column {
    id: page
    property var app: null
    spacing: 11

    readonly property var bs: Config.getSetting("bar", {})
    function writeBar(change, drop) {
        const cur = Object.assign({}, Config.getSetting("bar", {}));
        Object.assign(cur, change);
        for (const k of (drop || [])) if (cur[k] !== undefined) delete cur[k];
        Config.setSetting("bar", cur);
    }

    readonly property bool panelAutoHide: Config.getSetting("controlcenter.autohide", true)
    readonly property bool panelWsOnly: Config.getSetting("panel.workspaceOnly", true)
    property real panelDelayFrac: Math.max(0, Math.min(1, (Config.getSetting("controlcenter.autohideDelay", 1200) - 300) / 4700))
    onPanelDelayFracChanged: delaySave.restart()
    Timer { id: delaySave; interval: 400
            onTriggered: { const ms = Math.round((300 + page.panelDelayFrac * 4700) / 100) * 100;
                           if (ms !== Config.getSetting("controlcenter.autohideDelay", 1200)) Config.setSetting("controlcenter.autohideDelay", ms); } }

    readonly property real wsCount: bs.workspaceCount !== undefined ? bs.workspaceCount : 8
    readonly property bool wsHideEmpty: bs.hideEmptyWorkspaces !== undefined ? Boolean(bs.hideEmptyWorkspaces) : false
    readonly property real wsVisLimit: bs.workspaceVisibleLimit || 3
    readonly property var wsStyles: ["pills", "numbers", "pacman"]
    readonly property int wsStyleIdx: Math.max(0, wsStyles.indexOf(bs.workspacesStyle || "pills"))
    readonly property bool musicSpinRecord: Config.getSetting("bar.musicSpinningRecord", (bs.musicStyle || "full") === "record")
    readonly property bool musicBarEnabled: Config.getSetting("panel.musicBar.enabled", false) === true
    readonly property string musicBarPos: Config.getSetting("panel.musicBar.position", "top") === "bottom" ? "bottom" : "top"

    readonly property bool showDate: bs.timeShowDate !== undefined ? bs.timeShowDate : (bs.showDate !== undefined ? bs.showDate : true)
    readonly property string timeFormat: bs.time && bs.time.format !== undefined ? bs.time.format : "HH:mm:ss"
    function partsOf(fmt) {
        const out = [];
        if (/[Hh]/.test(fmt)) out.push("HH");
        if (/m/.test(fmt)) out.push("MM");
        if (/s/.test(fmt)) out.push("SS");
        if (/ap/i.test(fmt)) out.push("AP");
        return out.length ? out : ["HH", "MM"];
    }
    function formatOf(parts) {
        const ap = parts.indexOf("AP") >= 0;
        const segs = [];
        if (parts.indexOf("HH") >= 0) segs.push(ap ? "hh" : "HH");
        if (parts.indexOf("MM") >= 0) segs.push("mm");
        if (parts.indexOf("SS") >= 0) segs.push("ss");
        return (segs.join(":") || "HH:mm") + (ap ? " AP" : "");
    }
    readonly property var timeFmtParts: partsOf(timeFormat)
    function toggleTimePart(part) {
        const cur = timeFmtParts.slice();
        const idx = cur.indexOf(part);
        if (idx >= 0) {
            if ((part === "HH" || part === "MM") && cur.filter(x => x === "HH" || x === "MM").length <= 1) return;
            cur.splice(idx, 1);
        } else {
            cur.push(part);
        }
        const ord = ["HH", "MM", "SS", "AP"];
        cur.sort((a, b) => ord.indexOf(a) - ord.indexOf(b));
        const fmt = formatOf(cur);
        const bar = Object.assign({}, Config.getSetting("bar", {}));
        bar.time = Object.assign({}, bar.time || {}, { format: fmt });
        if (bar.sideTime !== undefined) delete bar.sideTime;
        Config.setSetting("bar", bar);
    }
    readonly property var timeStyles: ["classic", "material", "badge"]
    readonly property int timeStyleIdx: Math.max(0, timeStyles.indexOf(bs.timeStyle || "classic"))

    readonly property bool wifiShowIcon: bs.wifiShowIcon !== undefined ? Boolean(bs.wifiShowIcon) : true
    readonly property bool wifiShowName: bs.wifiShowName !== undefined ? Boolean(bs.wifiShowName) : true
    readonly property var netStyles: ["button", "text"]
    readonly property int netStyleIdx: Math.max(0, netStyles.indexOf(bs.wifiStyle || "button"))

    // Real module face preview stand-ins (as original PanelPage)
    readonly property var wsPreview: ({
        "s": function(v) { return Scaler.s(v); },
        "workspaceCount": 3, "shownIndices": [0, 1, 2],
        "isShown": function(idx) { return idx >= 0 && idx < 3; },
        "activeIndex": 1, "isCompact": false,
        "isOccupied": function(idx) { return idx === 0 || idx === 1 || idx === 2; },
        "focusWorkspace": function(idx) {},
        "barWindow": { "startupCascadeFinished": true },
        "moduleActive": page.visible
    })
    readonly property QtObject timePreview: QtObject {
        function s(v) { return Scaler.s(v); }
        property bool isCompact: false
        property bool showDate: page.showDate
        property string timeStr: DateTime.time || "14:28"
        property string hourStr: DateTime.hour || "14"
        property string minuteStr: DateTime.minute || "28"
        property string secondStr: DateTime.second || "00"
        property string dayStr: DateTime.day || "18"
        property string monthStr: DateTime.monthShort || "Sep"
        property string fullDateStr: DateTime.fullDate || "Fri, Sep 18"
        property string dateStr: DateTime.fullDate || "Fri, Sep 18"
        property var barWindow: ({ "startupCascadeFinished": true, "s": function(v) { return Scaler.s(v); } })
        property bool moduleActive: page.visible
    }
    Component {
        id: wifiMockComp
        QtObject {
            property string style: ""
            function s(v) { return Scaler.s(v); }
            property bool isCompact: false
            property string wifiStyle: style
            property bool wifiShowIcon: page.wifiShowIcon
            property bool wifiShowName: page.wifiShowName
            property bool isPreview: true
            property var barWindow: ({ "startupCascadeFinished": true, "isStartupReady": true, "isDataReady": true, "s": function(v) { return Scaler.s(v); } })
            property bool moduleActive: page.visible
        }
    }
    property var wifiMocks: ({})
    function wifiMock(id) {
        if (!wifiMocks[id]) { const o = Object.assign({}, wifiMocks); o[id] = wifiMockComp.createObject(page, { style: id }); wifiMocks = o; }
        return wifiMocks[id];
    }
    readonly property QtObject musicPreviewModule: QtObject {
        property bool moduleActive: page.visible
        property bool isCompact: false
        property bool isRightBar: false
        property var barWindow: ({ s: v => Scaler.s(v), visible: page.visible })
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
        title: "Edge panels"; icon: "󰕮"; statusText: page.panelAutoHide ? "AUTO-HIDE" : "PINNED"
        TileGrid {
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰘓"; title: "Auto-hide"; geoShape: "heptagon"; checked: page.panelAutoHide; onToggled: (v) => { Config.setSetting("controlcenter.autohide", v); page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰕰"; title: "Workspace only"; geoShape: "cookie4"; checked: page.panelWsOnly; onToggled: (v) => { Config.setSetting("panel.workspaceOnly", v); page.app.sfx.playToggle(v); } }
        }
        SSlider { icon: "󰔛"; title: "Hide delay"; value: page.panelDelayFrac; valueText: Math.round((300 + page.panelDelayFrac * 4700) / 100) * 100 + " ms"; onMoved: (v) => page.panelDelayFrac = v }
    }

    SCard {
        title: "Workspaces"; icon: "󰮯"
        ModuleStyleCards {
            width: parent.width
            styles: BarModuleRegistry.variantList("workspaces")
            current: page.wsStyles[page.wsStyleIdx]
            previewHeight: 160
            active: page.visible
            faceFor: function(id) { return BarModuleRegistry.variantFaceFile("workspaces", id, true); }
            widgetFor: function(id) { return page.wsPreview; }
            onPicked: (id) => { page.writeBar({ workspacesStyle: id }, ["sideWorkspacesStyle"]); page.app.sfx.playSwitch(); }
        }
        TileGrid {
            SStepper { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰮯"; title: "Workspace count"; value: page.wsCount; from: 2; to: 10; step: 1; onChanged: (v) => { page.writeBar({ workspaceCount: Math.round(v) }, ["sideWorkspaceCount"]); page.app.sfx.playStepper(); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰈈"; title: "Hide empty"; geoShape: "triangle"; checked: page.wsHideEmpty; onToggled: (v) => { page.writeBar({ hideEmptyWorkspaces: v }, ["sideHideEmptyWorkspaces"]); page.app.sfx.playToggle(v); } }
        }
        SStepper { visible: page.wsHideEmpty; width: parent.width; icon: "󰮯"; title: "Maximum visible workspaces"; value: page.wsVisLimit; from: 1; to: 10; step: 1; onChanged: (v) => { page.writeBar({ workspaceVisibleLimit: Math.round(v) }); page.app.sfx.playStepper(); } }
    }

    SCard {
        title: "Music"; icon: "󰎈"
        Rectangle {
            id: musicBox
            width: parent.width; height: 140; radius: 14; color: page.app.cTile; clip: true
            border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.22)
            Loader {
                anchors.centerIn: parent
                active: page.visible
                enabled: false
                scale: Math.min(1, (musicBox.width - 16) / Math.max(1, width), (musicBox.height - 16) / Math.max(1, height))
                source: Qt.resolvedUrl("../../../bar/faces/media/SideMediaFace.qml")
                onLoaded: if (item) item.module = page.musicPreviewModule
            }
        }
        SToggle { width: parent.width; icon: "󰀥"; title: "Spinning record"; geoShape: "clover4"; checked: page.musicSpinRecord; onToggled: (v) => { Config.setSetting("bar.musicSpinningRecord", v); page.app.sfx.playToggle(v); } }
        Rectangle {
            id: musicBarPreviewBox
            width: parent.width; height: 76; radius: 14; color: page.app.cTile; clip: true
            border.width: 1
            border.color: page.musicBarEnabled
                ? Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.35)
                : Qt.rgba(page.app.cText.r, page.app.cText.g, page.app.cText.b, 0.10)
            MusicBarCapsule {
                id: previewPill
                anchors.centerIn: parent
                preview: true
                liveActive: page.visible
                maxWidth: musicBarPreviewBox.width - 20
                waveHeight: 16
                scale: Math.min(1, (musicBarPreviewBox.width - 16) / Math.max(1, width))
                opacity: page.musicBarEnabled ? 1.0 : 0.65
            }
        }
        SToggle {
            width: parent.width; icon: "󰲸"; title: "Music bar"; geoShape: "pentagon"
            checked: page.musicBarEnabled
            onToggled: (v) => { Config.setSetting("panel.musicBar.enabled", v); page.app.sfx.playToggle(v); }
        }
        SChoice {
            visible: page.musicBarEnabled
            width: parent.width; icon: "󰆾"; title: "Music bar position"
            options: ["Top", "Bottom"]
            currentIndex: page.musicBarPos === "bottom" ? 1 : 0
            onPicked: (idx) => { Config.setSetting("panel.musicBar.position", idx === 1 ? "bottom" : "top"); page.app.sfx.playSwitch(); }
        }
    }

    SCard {
        title: "Time & Date"; icon: "󰥔"
        SToggle { width: parent.width; icon: "󰃭"; title: "Show Date"; geoShape: "star6"; checked: page.showDate; onToggled: (v) => { page.writeBar({ timeShowDate: v }, ["showDate", "sideTimeShowDate"]); page.app.sfx.playToggle(v); } }
        SChoice {
            width: parent.width; icon: "󰅐"; title: "Time Format"; multi: true
            options: ["HH", "MM", "SS", "AP"]; selectedList: page.timeFmtParts
            onMultiToggled: (lab) => { page.toggleTimePart(lab); page.app.sfx.playClick(); }
        }
        ModuleStyleCards {
            width: parent.width
            styles: BarModuleRegistry.variantList("timedate")
            current: page.timeStyles[page.timeStyleIdx]
            previewHeight: 72
            active: page.visible
            faceFor: function(id) { return BarModuleRegistry.variantFaceFile("timedate", id, false); }
            widgetFor: function(id) { return page.timePreview; }
            onPicked: (id) => { page.writeBar({ timeStyle: id }, ["sideTimeStyle"]); page.app.sfx.playSwitch(); }
        }
    }

    SCard {
        title: "Network"; icon: "󰤨"
        TileGrid {
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰤨"; title: "Show Icon"; geoShape: "octagon"; checked: page.wifiShowIcon; onToggled: (v) => { if (!v && !page.wifiShowName) return; page.writeBar({ wifiShowIcon: v }); page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰤥"; title: "Show Name"; geoShape: "teardrop"; checked: page.wifiShowName; onToggled: (v) => { if (!v && !page.wifiShowIcon) return; page.writeBar({ wifiShowName: v }); page.app.sfx.playToggle(v); } }
        }
        ModuleStyleCards {
            width: parent.width
            styles: BarModuleRegistry.variantList("wifi")
            current: page.netStyles[page.netStyleIdx]
            previewHeight: 140
            active: page.visible
            faceFor: function(id) { return Qt.resolvedUrl("../../../bar/faces/wifi/SideWifiFace.qml"); }
            widgetFor: function(id) { return page.wifiMock(id); }
            onPicked: (id) => { page.writeBar({ wifiStyle: id }); page.app.sfx.playSwitch(); }
        }
    }
}
