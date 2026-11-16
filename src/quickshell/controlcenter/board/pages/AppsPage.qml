import QtQuick
import Quickshell
import "../../../"
import ".."

// Apps as a board: the launcher (guide/LauncherTab.qml) and the dock (guide/DockTab.qml), each setting written
// as those pages write it (the whole "launcher" / "dock" object), the dock's options shown only while it is on,
// as there, and its applications with edit mode and removal.
BoardPage {
    id: page
    // ---------- launcher ----------
    readonly property var ldef: ({ position: "center", width: 755, itemCount: 6, terminalCommand: "kitty -e", smartRanking: true })
    readonly property var ls: Config.getSetting("launcher", ldef)
    function l(k) { return ls[k] !== undefined ? ls[k] : ldef[k]; }
    function setLauncher(key, value) {
        const cur = JSON.parse(JSON.stringify(Config.getSetting("launcher", ldef) || ldef));
        cur[key] = value;
        Config.setSetting("launcher", cur);
    }
    // ---------- dock ----------
    readonly property var ddef: ({ enabled: true, position: "bottom", onTop: true, elementSize: 44, floating: false, opacity: 100, exclusive: false,
                                   autohide: false, smartAutohide: true, autohideTimeout: 1000, editing: false, apps: [], overrideBoundsCorrection: false,
                                   enableScrolling: false, visibleElements: 7, hoverScale: 120, cascadeScale: false })
    readonly property var ds: Config.getSetting("dock", ddef)
    function d(k) { return ds[k] !== undefined ? ds[k] : ddef[k]; }
    function int(k) { const v = parseInt(ds[k]); return isNaN(v) ? ddef[k] : v; }
    readonly property bool dockOn: d("enabled")
    readonly property real dockOpacity: ds.opacity !== undefined ? Number(ds.opacity) : (ds.transparency !== undefined ? Math.max(0, 100 - Number(ds.transparency)) : 100)
    readonly property var apps: Array.isArray(ds.apps) ? ds.apps : []
    function setDock(key, value) {
        const cur = JSON.parse(JSON.stringify(Config.getSetting("dock", ddef) || ddef));
        cur[key] = value;
        Config.setSetting("dock", cur);
    }
    function removeApp(idx) {
        const list = apps.slice();
        if (idx >= 0 && idx < list.length) { list.splice(idx, 1); setDock("apps", list); }
    }

    BoardCard {
        title: "Launcher"; icon: "󰵆"; accent: page.accent
        BoardCell {
            kind: "select"; icon: "󰍹"; title: I18n.t("guide.launcher.position.title", "Screen Position")
            options: [I18n.t("guide.launcher.position.top", "Top"), I18n.t("guide.launcher.position.bottom", "Bottom"), I18n.t("guide.launcher.position.left", "Left"),
                      I18n.t("guide.launcher.position.right", "Right"), I18n.t("guide.launcher.position.center", "Center"), I18n.t("guide.launcher.position.bar", "Bar")]
            values: ["top", "bottom", "left", "right", "center", "bar"]
            value: page.l("position"); onPicked: (v) => page.setLauncher("position", v)
        }
        BoardCell { kind: "stepper"; icon: "󰘖"; title: I18n.t("guide.launcher.width.title", "Launcher Width"); from: 320; to: 1400; step: 10; suffix: "px"
                    value: page.l("width"); onPicked: (v) => page.setLauncher("width", Math.round(v)) }
        BoardCell { kind: "stepper"; icon: "󰅫"; title: I18n.t("guide.launcher.items.title", "Visible Items"); from: 3; to: 15; step: 1
                    value: page.l("itemCount"); onPicked: (v) => page.setLauncher("itemCount", Math.round(v)) }
        BoardCell { kind: "toggle"; icon: "󰓥"; title: I18n.t("guide.launcher.smart_ranking.title", "Smart Rank by Usage")
                    value: page.l("smartRanking"); onPicked: (v) => page.setLauncher("smartRanking", v) }
        BoardCell { kind: "field"; icon: "󰆍"; title: I18n.t("guide.launcher.terminal.title", "Terminal Command"); placeholder: "kitty -e"
                    value: page.l("terminalCommand"); onPicked: (v) => page.setLauncher("terminalCommand", v) }
        BoardCell { kind: "action"; icon: "󰵆"; title: I18n.t("guide.launcher.test", "Open Launcher"); actionText: "Open"
                    onActivated: if (typeof LauncherController !== "undefined") LauncherController.toggle() }
    }

    BoardCard {
        title: "Dock"; icon: "󰅀"; accent: page.accent
        BoardCell { kind: "toggle"; icon: "󰅀"; title: I18n.t("guide.dock.enabled.title", "Enable dock"); value: page.dockOn; onPicked: (v) => page.setDock("enabled", v) }
        BoardCell {
            kind: "select"; icon: "󰍹"; title: I18n.t("guide.dock.position.title", "Dock position"); hidden: !page.dockOn
            options: [I18n.t("guide.dock.position.bottom", "Bottom"), I18n.t("guide.dock.position.top", "Top"), I18n.t("guide.dock.position.left", "Left"), I18n.t("guide.dock.position.right", "Right")]
            values: ["bottom", "top", "left", "right"]
            value: page.d("position"); onPicked: (v) => page.setDock("position", v)
        }
        BoardCell { kind: "toggle"; icon: "󰹤"; title: I18n.t("guide.dock.on_top.title", "Place dock on top of windows"); hidden: !page.dockOn
                    value: Boolean(page.d("onTop")); onPicked: (v) => page.setDock("onTop", v) }
        BoardCell { kind: "toggle"; icon: "󰉈"; title: I18n.t("guide.dock.floating.title", "Floating dock"); hidden: !page.dockOn
                    value: page.d("floating"); onPicked: (v) => page.setDock("floating", v) }
        BoardCell { kind: "toggle"; icon: "󰖲"; title: I18n.t("guide.dock.exclusive.title", "Exclusive mode"); hidden: !page.dockOn
                    value: page.ds.exclusive !== undefined ? page.ds.exclusive : (page.ds.exclusiveMode !== undefined ? page.ds.exclusiveMode : false)
                    onPicked: (v) => page.setDock("exclusive", v) }
        BoardCell {
            id: dockOpacity
            kind: "slider"; icon: "󰂵"; title: I18n.t("guide.dock.opacity.title", "Dock opacity"); hidden: !page.dockOn; from: 0; to: 100; step: 1; suffix: "%"
            property real live: NaN
            value: isNaN(live) ? page.dockOpacity : live
            onMoving: (v) => live = Math.round(v)
            onReleased: { if (!isNaN(live)) page.setDock("opacity", live); live = NaN; }
        }
        BoardCell {
            kind: "slider"; icon: "󰘖"; title: I18n.t("guide.dock.size.title", "Element size"); hidden: !page.dockOn; from: 32; to: 72; step: 2; suffix: " px"
            property real live: NaN
            value: isNaN(live) ? page.int("elementSize") : live
            onMoving: (v) => live = Math.round(v)
            onReleased: { if (!isNaN(live)) page.setDock("elementSize", live); live = NaN; }
        }
        BoardCell { kind: "toggle"; icon: "󰜤"; title: I18n.t("guide.dock.override_bounds.title", "Override out-of-screen-bounds size correction"); hidden: !page.dockOn
                    value: page.d("overrideBoundsCorrection"); onPicked: (v) => page.setDock("overrideBoundsCorrection", v) }
        BoardCell {
            kind: "slider"; icon: "󰍔"; title: I18n.t("guide.dock.hover_scale.title", "Hover scale effect"); hidden: !page.dockOn; from: 100; to: 160; step: 2; suffix: "%"
            property real live: NaN
            value: isNaN(live) ? page.int("hoverScale") : live
            onMoving: (v) => live = Math.round(v)
            onReleased: { if (!isNaN(live)) page.setDock("hoverScale", live); live = NaN; }
        }
        BoardCell { kind: "toggle"; icon: "󰘚"; title: I18n.t("guide.dock.cascade_scale.title", "Scale nearest elements"); hidden: !page.dockOn
                    value: Boolean(page.d("cascadeScale")); onPicked: (v) => page.setDock("cascadeScale", v) }
        BoardCell { kind: "toggle"; icon: "󰒥"; title: I18n.t("guide.dock.scrolling.title", "Enable element scrolling"); hidden: !page.dockOn
                    value: page.d("enableScrolling"); onPicked: (v) => page.setDock("enableScrolling", v) }
        BoardCell { kind: "stepper"; icon: "󰅫"; title: I18n.t("guide.dock.visible_elements.title", "Visible elements"); hidden: !page.dockOn || !page.d("enableScrolling")
                    from: 1; to: 20; step: 1; value: page.int("visibleElements") > 0 ? page.int("visibleElements") : 7
                    onPicked: (v) => page.setDock("visibleElements", Math.round(v)) }
        BoardCell { kind: "toggle"; icon: "󱂬"; title: I18n.t("guide.dock.smart_autohide.title", "Smart auto-hide"); hidden: !page.dockOn
                    value: page.d("smartAutohide"); onPicked: (v) => page.setDock("smartAutohide", v) }
        BoardCell { kind: "toggle"; icon: "󰘓"; title: I18n.t("guide.dock.autohide.title", "Auto-hide"); hidden: !page.dockOn
                    value: page.d("autohide"); onPicked: (v) => page.setDock("autohide", v) }
        BoardCell {
            kind: "slider"; icon: "󰔛"; title: I18n.t("guide.dock.timeout.title", "Auto-hide delay"); hidden: !page.dockOn || !(page.d("autohide") || page.d("smartAutohide"))
            from: 250; to: 5000; step: 50; suffix: " ms"
            property real live: NaN
            value: isNaN(live) ? page.int("autohideTimeout") : live
            onMoving: (v) => live = Math.round(v)
            onReleased: { if (!isNaN(live)) page.setDock("autohideTimeout", live); live = NaN; }
        }
    }

    BoardCard {
        title: I18n.t("guide.dock.apps.title", "Dock Applications") + "  ·  " + page.apps.length + " " + (page.apps.length === 1 ? I18n.t("guide.dock.apps.singular", "app") : I18n.t("guide.dock.apps.plural", "apps"))
        icon: "󰀻"; accent: page.accent
        visible: page.dockOn
        BoardCell {
            kind: "action"; icon: page.d("editing") ? "󰅖" : "󰏫"
            title: page.d("editing") ? I18n.t("guide.dock.apps.exit_edit", "Exit edit mode") : I18n.t("guide.dock.apps.enter_edit", "Edit")
            actionText: page.d("editing") ? "Exit" : "Edit"
            onActivated: {
                const next = !page.d("editing");
                page.setDock("editing", next);
                Sounds.playSfx(next ? "guide/barconfig/out.wav" : "guide/barconfig/in.wav");
                Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "close"]);
            }
        }
        BoardCell { kind: "info"; icon: "󰀻"; title: I18n.t("guide.dock.apps.title", "Dock Applications"); hidden: page.apps.length > 0
                    info: I18n.t("guide.dock.apps.empty", "No applications configured for the dock") }
        Repeater {
            model: page.apps
            BoardCell {
                id: appCell
                required property var modelData
                required property int index
                kind: "custom"; customHeight: 30
                icon: ""; title: modelData.name || modelData.desktop_id || "App"
                Row {
                    width: parent.width; spacing: 8
                    Image {
                        width: 30; height: 30; anchors.verticalCenter: parent.verticalCenter
                        fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
                        source: {
                            const ic = appCell.modelData.icon || "";
                            if (!ic) return "";
                            if (/^(file|image|https?):\/\//.test(ic)) return ic;
                            return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
                        }
                    }
                    Item { width: parent.width - 30 - 30 - 16; height: 1 }
                    Rectangle {
                        width: 30; height: 30; radius: 15; anchors.verticalCenter: parent.verticalCenter
                        color: rMa.pressed ? Qt.darker(ThemeBackend.red, 1.2) : (rMa.containsMouse ? Qt.alpha(ThemeBackend.red, 0.3) : Qt.alpha(ThemeBackend.red, 0.14))
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Text { anchors.centerIn: parent; text: "󰆴"; font.family: ThemeBackend.iconFont; font.pixelSize: 14; color: ThemeBackend.red }
                        MouseArea { id: rMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); page.removeApp(appCell.index); } }
                    }
                }
            }
        }
    }
}
