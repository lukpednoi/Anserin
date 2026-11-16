import QtQuick
import "../../../"
import "../../../bar"
import ".."

// Panel as a board: the edge panels (guide/panel/PanelAutoHide.qml) and the left edge panel's Workspaces, Music,
// Time & Date and Network modules (guide/bar/BarModulesTab.qml, as the Control tab shows it: workspaces, music
// and network drawn as on the side panel, the clock across). Each setting is written as that page writes it;
// the style cards and previews show the real module faces.
BoardPage {
    id: page
    readonly property var bs: Config.getSetting("bar", {})
    readonly property string wsStyle: bs.workspacesStyle || "pills"
    readonly property int wsCount: bs.workspaceCount !== undefined ? bs.workspaceCount : 8
    readonly property bool hideEmpty: bs.hideEmptyWorkspaces !== undefined ? Boolean(bs.hideEmptyWorkspaces) : false
    readonly property string timeStyle: bs.timeStyle || "classic"
    readonly property bool showDate: bs.timeShowDate !== undefined ? bs.timeShowDate : (bs.showDate !== undefined ? bs.showDate : true)
    readonly property string timeFormat: bs.time && bs.time.format !== undefined ? bs.time.format : "HH:mm:ss"
    readonly property string wifiStyle: bs.wifiStyle || "button"
    readonly property bool wifiIcon: bs.wifiShowIcon !== undefined ? Boolean(bs.wifiShowIcon) : true
    readonly property bool wifiName: bs.wifiShowName !== undefined ? Boolean(bs.wifiShowName) : true
    readonly property string musicStyle: bs.musicStyle || "full"

    // BarModulesTab's setters: write the bar object, dropping the old side-bar copies of the same setting
    function writeBar(change, drop) {
        const cur = Config.getSetting("bar", {});
        Object.assign(cur, change);
        for (const k of (drop || [])) if (cur[k] !== undefined) delete cur[k];
        Config.setSetting("bar", cur);
    }

    // stand-ins the module faces read (as BarModulesTab's preview objects)
    readonly property var wsPreview: ({
        "s": function(v) { return page.rootObj ? page.rootObj.s(v) : v; },
        "workspaceCount": 3, "shownIndices": [0, 1, 2],
        "isShown": function(idx) { return idx >= 0 && idx < 3; },
        "activeIndex": 1, "isCompact": false,
        "isOccupied": function(idx) { return idx === 0 || idx === 1 || idx === 2; },
        "focusWorkspace": function(idx) {},
        "barWindow": { "startupCascadeFinished": true },
        "moduleActive": true
    })
    QtObject {
        id: timePreview
        function s(v) { return page.rootObj ? page.rootObj.s(v) : v; }
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
        property var barWindow: ({ "startupCascadeFinished": true, "s": function(v) { return page.rootObj ? page.rootObj.s(v) : v; } })
        property bool moduleActive: page.visible
    }
    Component {
        id: wifiMockComp
        QtObject {
            property string style: ""
            function s(v) { return page.rootObj ? page.rootObj.s(v) : v; }
            property bool isCompact: false
            property string wifiStyle: style
            property bool wifiShowIcon: page.wifiIcon
            property bool wifiShowName: page.wifiName
            property bool isPreview: true
            property var barWindow: ({ "startupCascadeFinished": true, "isStartupReady": true, "isDataReady": true, "s": function(v) { return page.rootObj ? page.rootObj.s(v) : v; } })
            property bool moduleActive: page.visible
        }
    }
    QtObject {
        id: musicPreviewModule
        property bool moduleActive: page.visible
        property bool isCompact: false
        property bool isRightBar: false
        property var barWindow: ({ s: v => page.rootObj.s(v), visible: page.visible })
    }
    property var wifiMocks: ({})
    function wifiMock(id) {
        if (!wifiMocks[id]) { const o = Object.assign({}, wifiMocks); o[id] = wifiMockComp.createObject(page, { style: id }); wifiMocks = o; }
        return wifiMocks[id];
    }

    // ---------- edge panels ----------
    BoardCard {
        title: "Edge panels"; icon: "󰕮"; accent: page.accent
        BoardCell { kind: "toggle"; icon: "󰘓"; title: "Auto-hide"; value: Config.getSetting("controlcenter.autohide", true)
                    onPicked: (v) => Config.setSetting("controlcenter.autohide", v) }
        BoardCell { kind: "toggle"; icon: "󰕰"; title: "Workspace only"; value: Config.getSetting("panel.workspaceOnly", true)
                    onPicked: (v) => Config.setSetting("panel.workspaceOnly", v) }
        BoardCell {
            id: delay
            kind: "slider"; icon: "󰔛"; title: "Hide delay"; from: 300; to: 5000; step: 100; suffix: " ms"
            property real live: NaN
            value: isNaN(live) ? Config.getSetting("controlcenter.autohideDelay", 1200) : live
            onMoving: (v) => live = v
            onReleased: { if (!isNaN(live)) Config.setSetting("controlcenter.autohideDelay", live); live = NaN; }
        }
    }

    // ---------- workspaces ----------
    BoardCard {
        title: I18n.t("guide.bar.modules.workspaces.name", "Workspaces"); icon: "󰮯"; accent: page.accent
        BoardCell { kind: "stepper"; icon: "󰮯"; title: I18n.t("guide.bar.workspaces.title"); from: 2; to: 10; step: 1
                    value: page.wsCount; onPicked: (v) => page.writeBar({ workspaceCount: Math.round(v) }, ["sideWorkspaceCount"]) }
        BoardCell { kind: "toggle"; icon: "󰈈"; title: I18n.t("guide.bar.workspaces.hide_empty.title", "Hide empty workspaces")
                    value: page.hideEmpty; onPicked: (v) => page.writeBar({ hideEmptyWorkspaces: v }, ["sideHideEmptyWorkspaces"]) }
        BoardCell { kind: "stepper"; icon: "󰮯"; title: "Maximum visible workspaces"; hidden: !page.hideEmpty; from: 1; to: 10; step: 1
                    value: page.bs.workspaceVisibleLimit || 3; onPicked: (v) => page.writeBar({ workspaceVisibleLimit: Math.round(v) }) }
        ModuleStyleCards {
            styles: BarModuleRegistry.variantList("workspaces")
            current: page.wsStyle
            previewHeight: 160
            active: page.visible
            faceFor: function(id) { return BarModuleRegistry.variantFaceFile("workspaces", id, true); }
            widgetFor: function(id) { return page.wsPreview; }
            onPicked: (id) => page.writeBar({ workspacesStyle: id }, ["sideWorkspacesStyle"])
        }
    }

    // ---------- music ----------
    BoardCard {
        title: I18n.t("guide.bar.modules.music.name", "Music"); icon: "󰎈"; accent: page.accent
        Rectangle {
            id: musicBox
            implicitHeight: 140
            radius: ThemeBackend.borderRadius
            color: Qt.darker(ThemeBackend.mantle, 1.1)
            clip: true
            Loader {
                anchors.centerIn: parent
                active: page.visible
                enabled: false
                scale: Math.min(1, (musicBox.width - 16) / Math.max(1, width), (musicBox.height - 16) / Math.max(1, height))
                source: Qt.resolvedUrl("../../../bar/faces/media/SideMediaFace.qml")
                onLoaded: item.module = musicPreviewModule
            }
        }
        Repeater {
            model: [
                { key: "musicShowInfo", title: "Track details", icon: "󰎈", fallback: page.musicStyle === "full" },
                { key: "musicShowControls", title: "Playback controls", icon: "󰐊", fallback: ["full", "controls"].indexOf(page.musicStyle) >= 0 },
                { key: "musicSpinningRecord", title: "Spinning record", icon: "󰀥", fallback: page.musicStyle === "record" }
            ]
            BoardCell { required property var modelData
                        kind: "toggle"; icon: modelData.icon; title: modelData.title
                        value: Config.getSetting("bar." + modelData.key, modelData.fallback)
                        onPicked: (v) => Config.setSetting("bar." + modelData.key, v) }
        }
    }

    // ---------- time & date ----------
    BoardCard {
        title: I18n.t("guide.bar.modules.timedate.name", "Time & Date"); icon: "󰥔"; accent: page.accent
        BoardCell { kind: "toggle"; icon: "󰃭"; title: I18n.t("guide.bar.timedate.show_date.title", "Show Date")
                    value: page.showDate; onPicked: (v) => page.writeBar({ timeShowDate: v }, ["showDate", "sideTimeShowDate"]) }
        BoardCell { kind: "field"; icon: "󰅐"; title: I18n.t("guide.bar.time.title", "Time Format")
                    value: page.timeFormat
                    onPicked: (v) => { const cur = Config.getSetting("bar", {}); if (!cur.time) cur.time = {}; cur.time.format = v;
                                       if (cur.sideTime !== undefined) delete cur.sideTime; Config.setSetting("bar", cur); } }
        ModuleStyleCards {
            styles: BarModuleRegistry.variantList("timedate")
            current: page.timeStyle
            previewHeight: 72
            active: page.visible
            faceFor: function(id) { return BarModuleRegistry.variantFaceFile("timedate", id, false); }
            widgetFor: function(id) { return timePreview; }
            onPicked: (id) => page.writeBar({ timeStyle: id }, ["sideTimeStyle"])
        }
    }

    // ---------- network ----------
    BoardCard {
        title: I18n.t("guide.bar.modules.network", "Network"); icon: "󰤨"; accent: page.accent
        // at least one of icon and name stays on (as BarModulesTab)
        BoardCell { kind: "toggle"; icon: "󰤨"; title: I18n.t("guide.bar.wifi.show_icon.title", "Show Icon")
                    value: page.wifiIcon; onPicked: (v) => { if (!v && !page.wifiName) return; page.writeBar({ wifiShowIcon: v }); } }
        BoardCell { kind: "toggle"; icon: "󰤥"; title: I18n.t("guide.bar.wifi.show_name.title", "Show Name")
                    value: page.wifiName; onPicked: (v) => { if (!v && !page.wifiIcon) return; page.writeBar({ wifiShowName: v }); } }
        ModuleStyleCards {
            styles: BarModuleRegistry.variantList("wifi")
            current: page.wifiStyle
            previewHeight: 140
            active: page.visible
            faceFor: function(id) { return Qt.resolvedUrl("../../../bar/faces/wifi/SideWifiFace.qml"); }
            widgetFor: function(id) { return page.wifiMock(id); }
            onPicked: (id) => page.writeBar({ wifiStyle: id })
        }
    }
}
