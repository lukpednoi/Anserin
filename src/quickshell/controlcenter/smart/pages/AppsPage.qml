import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../../"

// 6. APPS — Launcher automatic strip + Dock preview, Dock Applications, clean 4-slot Dock position grid (2x2), Dock settings
Column {
    id: page
    property var app: null
    spacing: 11

    readonly property var ddef: ({
        enabled: true, position: "bottom", onTop: true, elementSize: 44, floating: false, opacity: 100, exclusive: false,
        autohide: false, smartAutohide: true, autohideTimeout: 1000, editing: false, apps: [], overrideBoundsCorrection: false,
        enableScrolling: false, visibleElements: 7, hoverScale: 120, cascadeScale: false
    })
    readonly property var ds: Config.getSetting("dock", ddef)
    function d(k) { return ds[k] !== undefined ? ds[k] : ddef[k]; }
    function setDock(key, value) {
        const cur = JSON.parse(JSON.stringify(Config.getSetting("dock", ddef) || ddef));
        cur[key] = value;
        Config.setSetting("dock", cur);
    }
    function iconUrlOf(ic) {
        ic = ic || "";
        if (!ic) return "";
        if (/^(file|image|https?):\/\//.test(ic)) return ic;
        return ic.startsWith("/") ? "file://" + ic : "image://icon/" + ic;
    }

    readonly property var dockApps: (Array.isArray(ds.apps) ? ds.apps : []).map(x => ({ name: x.name || x.desktop_id || "App", icon: "󰀻", iconUrl: iconUrlOf(x.icon) }))
    function removeDockApp(i) {
        const list = (Array.isArray(ds.apps) ? ds.apps : []).slice();
        if (i >= 0 && i < list.length) { list.splice(i, 1); setDock("apps", list); }
    }

    readonly property bool dockEnabled: d("enabled")
    readonly property bool dockEditing: d("editing")
    // 4 clean slots (2x2): Top, Bottom, Left, Right
    readonly property var dockPositions: ["top", "bottom", "left", "right"]
    readonly property var dockPositionNames: ["Top", "Bottom", "Left", "Right"]
    readonly property var dockPositionIcons: ["󰁝", "󰁅", "󰁍", "󰁔"]
    readonly property int dockPosIdx: Math.max(0, dockPositions.indexOf(d("position")))
    readonly property real dockOpacityNow: ds.opacity !== undefined ? Number(ds.opacity) : (ds.transparency !== undefined ? Math.max(0, 100 - Number(ds.transparency)) : 100)

    property real dockOpacityFrac: dockOpacityNow / 100
    property real dockSizeFrac: Math.max(0, Math.min(1, (Number(d("elementSize")) - 32) / 40))
    property real dockHoverScaleFrac: Math.max(0, Math.min(1, (Number(d("hoverScale")) - 100) / 60))
    property real dockTimeoutFrac: Math.max(0, Math.min(1, (Number(d("autohideTimeout")) - 250) / 4750))
    onDockOpacityFracChanged: dockSave.restart()
    onDockSizeFracChanged: dockSave.restart()
    onDockHoverScaleFracChanged: dockSave.restart()
    onDockTimeoutFracChanged: dockSave.restart()

    Timer {
        id: dockSave; interval: 400
        onTriggered: {
            const cur = JSON.parse(JSON.stringify(Config.getSetting("dock", page.ddef) || page.ddef));
            const next = {
                opacity: Math.round(page.dockOpacityFrac * 100),
                elementSize: Math.round(32 + page.dockSizeFrac * 40),
                hoverScale: Math.round(100 + page.dockHoverScaleFrac * 60),
                autohideTimeout: Math.round((250 + page.dockTimeoutFrac * 4750) / 50) * 50
            };
            if (next.opacity === Math.round(page.dockOpacityNow) && next.elementSize === Number(cur.elementSize)
                && next.hoverScale === Number(cur.hoverScale) && next.autohideTimeout === Number(cur.autohideTimeout)) return;
            Config.setSetting("dock", Object.assign(cur, next));
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
    component SStepper: SmartStepperTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent
        textColor: page.app.cText; subColor: page.app.cSub; uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component TileGrid: GridLayout { width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8 }

    // Clean 4-slot (2x2) interactive Dock position picker matching PositionGrid6's exact visual language (zero blank holes!)
    component PositionGrid4: Rectangle {
        id: pg4
        property int currentIndex: 1
        property var labels: ["Top", "Bottom", "Left", "Right"]
        property var icons: ["󰁝", "󰁅", "󰁍", "󰁔"]
        property string badgeIcon: "󰅀"
        property string badgeText: "Dock"
        signal picked(int idx)

        width: parent.width; height: 108; radius: 14
        color: page.app.cTile
        border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.24)

        readonly property int colIdx: currentIndex % 2
        readonly property int rowIdx: Math.floor(currentIndex / 2)
        readonly property real cellW: width > 22 ? (width - 22) / 2 : 100
        readonly property real cellH: (height - 22) / 2
        readonly property real badgeW: Math.min(116, Math.max(82, cellW - 16))
        readonly property real targetBx: 8 + colIdx * (cellW + 6) + (cellW - badgeW) * 0.5
        readonly property real targetBy: 8 + rowIdx * (cellH + 6) + (cellH - 30) * 0.5

        SpringVal { id: bx4; target: pg4.targetBx; stiffness: 320; damping: 0.58; eps: 0.4 }
        SpringVal { id: by4; target: pg4.targetBy; stiffness: 320; damping: 0.58; eps: 0.4 }
        onWidthChanged: if (width > 22 && !bx4.moving) bx4.snap(targetBx)
        onHeightChanged: if (height > 22 && !by4.moving) by4.snap(targetBy)
        Component.onCompleted: Qt.callLater(() => { if (width > 22) bx4.snap(targetBx); if (height > 22) by4.snap(targetBy); })

        GridLayout {
            anchors.fill: parent; anchors.margins: 8; columns: 2; rows: 2; columnSpacing: 6; rowSpacing: 6
            Repeater {
                model: 4
                Rectangle {
                    id: slotCell
                    required property int index
                    readonly property bool selected: index === pg4.currentIndex
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 10
                    color: selected ? "transparent" : (slotHov.hovered ? page.app.cTileHov : (page.app.darkMode ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(0, 0, 0, 0.035)))
                    border.width: 1; border.color: selected ? "transparent" : (page.app.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.07))
                    Row {
                        visible: !slotCell.selected
                        anchors.centerIn: parent; spacing: 5
                        Text { text: pg4.icons[slotCell.index]; font.family: page.app.iconFont; font.pixelSize: 11; color: page.app.cSub; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: pg4.labels[slotCell.index]; font.family: page.app.uiFont; font.pixelSize: 10; font.weight: Font.Medium; color: page.app.cSub; anchors.verticalCenter: parent.verticalCenter }
                    }
                    HoverHandler { id: slotHov }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg4.picked(slotCell.index) }
                }
            }
        }
        Rectangle {
            x: bx4.value; y: by4.value; width: pg4.badgeW; height: 30; radius: 11
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: page.app.cAccent } GradientStop { position: 1.0; color: page.app.cAccent2 } }
            Row { anchors.centerIn: parent; spacing: 5
                Text { text: pg4.badgeIcon; font.family: page.app.iconFont; font.pixelSize: 11; color: page.app.cOnAccent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: pg4.labels[pg4.currentIndex]; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: page.app.cOnAccent; anchors.verticalCenter: parent.verticalCenter } }
        }
    }

    // Compact Auto-Managed Launcher Status Strip
    Rectangle {
        width: parent.width; height: 50; radius: Math.max(12, page.app.cornerRadius - 2)
        color: page.app.cCard
        border.width: 1; border.color: page.app.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
        Row {
            anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 9
            Text { text: "󰵆"; font.family: page.app.iconFont; font.pixelSize: 15; color: page.app.cAccent; anchors.verticalCenter: parent.verticalCenter }
            Column {
                spacing: 1
                Text { text: "Launcher · Automatic"; font.family: page.app.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold; color: page.app.cText }
                Text { text: "Smart Rank enabled by default · Terminal auto-detected"; font.family: page.app.uiFont; font.pixelSize: 9; color: page.app.cSub }
            }
        }
    }

    SCard {
        title: "Dock"; icon: "󰅀"; statusText: page.dockEnabled ? "ENABLED" : "OFF"

        // Live Hover-Magnifying Dock Preview
        Item {
            width: parent.width; height: 70
            Rectangle {
                anchors.centerIn: parent
                height: 36 + page.dockSizeFrac * 20
                width: dRow.implicitWidth + 24; radius: height * 0.45
                color: page.app.cTile; opacity: page.dockEnabled ? (0.3 + 0.7 * page.dockOpacityFrac) : 0.28
                border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.28)
                Row {
                    id: dRow; anchors.centerIn: parent; spacing: 10
                    Repeater {
                        model: page.dockApps
                        Item {
                            id: di; required property var modelData
                            readonly property real sz: 24 + page.dockSizeFrac * 16
                            readonly property real hScale: 1.0 + page.dockHoverScaleFrac * 0.6
                            SpringVal { id: diSc; target: diH.hovered ? di.hScale : 1.0; stiffness: 460; damping: 0.42; eps: 0.002 }
                            width: sz; height: sz; scale: diSc.value
                            Rectangle {
                                anchors.fill: parent; radius: sz * 0.34
                                color: diH.hovered ? page.app.cAccent : Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.20)
                                Text { visible: !di.modelData.iconUrl; anchors.centerIn: parent; text: di.modelData.icon; font.family: page.app.iconFont; font.pixelSize: di.sz * 0.52; color: diH.hovered ? page.app.cOnAccent : page.app.cAccent }
                                Image { visible: !!di.modelData.iconUrl; anchors.centerIn: parent; width: di.sz * 0.66; height: width; source: di.modelData.iconUrl || ""; sourceSize: Qt.size(64, 64); fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true }
                            }
                            HoverHandler { id: diH }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { diSc.kick(1.3); page.app.sfx.playClick(); } }
                        }
                    }
                }
            }
        }

        // Dock Applications directly below preview
        Column {
            visible: page.dockEnabled; width: parent.width; spacing: 7
            Item {
                width: parent.width; height: 22
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "DOCK APPLICATIONS  ·  " + page.dockApps.length; font.family: page.app.uiFont; font.pixelSize: 9; font.letterSpacing: 1.0; color: page.app.cSub }
                Rectangle {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 22; width: 48; radius: 11
                    color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.16)
                    Text { anchors.centerIn: parent; text: page.dockEditing ? "Done" : "Edit"; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: page.app.cAccent }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const next = !page.dockEditing;
                            page.setDock("editing", next);
                            Sounds.playSfx(next ? "guide/barconfig/out.wav" : "guide/barconfig/in.wav");
                            Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "close"]);
                        }
                    }
                }
            }
            TileGrid {
                Repeater {
                    model: page.dockApps
                    Rectangle {
                        id: da; required property var modelData; required property int index
                        Layout.fillWidth: true; Layout.preferredWidth: 1; height: 44; radius: 12; color: page.app.cTile
                        border.width: 1; border.color: page.app.darkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
                        Row { anchors.left: parent.left; anchors.leftMargin: 11; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                            Text { visible: !da.modelData.iconUrl; text: da.modelData.icon; font.family: page.app.iconFont; font.pixelSize: 14; color: page.app.cAccent }
                            Image { visible: !!da.modelData.iconUrl; width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter; source: da.modelData.iconUrl || ""; sourceSize: Qt.size(36, 36); fillMode: Image.PreserveAspectFit; smooth: true }
                            Text { text: da.modelData.name; font.family: page.app.uiFont; font.pixelSize: 11; color: page.app.cText } }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24; radius: 12; color: Qt.rgba(1, 0.45, 0.45, 0.16)
                            Text { anchors.centerIn: parent; text: "󰆴"; font.family: page.app.iconFont; font.pixelSize: 11; color: "#ffb4ab" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.removeDockApp(da.index); page.app.sfx.playToggle(false); } }
                        }
                    }
                }
            }
        }

        SToggle { width: parent.width; icon: "󰅀"; title: "Enable dock"; geoShape: "clover4"; checked: page.dockEnabled; onToggled: (v) => { page.setDock("enabled", v); page.app.sfx.playToggle(v); } }

        Column {
            visible: page.dockEnabled; width: parent.width; spacing: 9
            Item {
                width: parent.width; height: 18
                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: "DOCK POSITION"; font.family: page.app.uiFont; font.pixelSize: 9; font.letterSpacing: 1.0; color: page.app.cSub }
                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: page.dockPositionNames[page.dockPosIdx]; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: page.app.cAccent }
            }
            PositionGrid4 {
                currentIndex: page.dockPosIdx
                labels: page.dockPositionNames
                icons: page.dockPositionIcons
                onPicked: (idx) => { page.setDock("position", page.dockPositions[idx]); page.app.sfx.playSwitch(); }
            }
            TileGrid {
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰹤"; title: "On top of windows"; geoShape: "pentagon"; checked: page.d("onTop"); onToggled: (v) => { page.setDock("onTop", v); page.app.sfx.playToggle(v); } }
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰉈"; title: "Floating dock"; geoShape: "diamond"; checked: page.d("floating"); onToggled: (v) => { page.setDock("floating", v); page.app.sfx.playToggle(v); } }
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰖲"; title: "Exclusive mode"; geoShape: "arch"; checked: page.d("exclusive"); onToggled: (v) => { page.setDock("exclusive", v); page.app.sfx.playToggle(v); } }
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰜤"; title: "Override bounds"; geoShape: "shield"; checked: page.d("overrideBoundsCorrection"); onToggled: (v) => { page.setDock("overrideBoundsCorrection", v); page.app.sfx.playToggle(v); } }
            }
            SSlider { icon: "󰂵"; title: "Dock opacity"; value: page.dockOpacityFrac; valueText: Math.round(page.dockOpacityFrac * 100) + "%"; onMoved: (v) => page.dockOpacityFrac = v }
            SSlider { icon: "󰘖"; title: "Element size"; value: page.dockSizeFrac; valueText: Math.round(32 + page.dockSizeFrac * 40) + " px"; onMoved: (v) => page.dockSizeFrac = v }
            SSlider { icon: "󰍔"; title: "Hover scale effect"; value: page.dockHoverScaleFrac; valueText: Math.round(100 + page.dockHoverScaleFrac * 60) + "%"; onMoved: (v) => page.dockHoverScaleFrac = v }
            TileGrid {
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰘚"; title: "Scale nearest"; geoShape: "flower5"; checked: page.d("cascadeScale"); onToggled: (v) => { page.setDock("cascadeScale", v); page.app.sfx.playToggle(v); } }
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰒥"; title: "Element scrolling"; geoShape: "hexagon"; checked: page.d("enableScrolling"); onToggled: (v) => { page.setDock("enableScrolling", v); page.app.sfx.playToggle(v); } }
            }
            SStepper { visible: page.d("enableScrolling"); width: parent.width; icon: "󰅫"; title: "Visible elements"; value: page.d("visibleElements"); from: 1; to: 20; step: 1; onChanged: (v) => { page.setDock("visibleElements", Math.round(v)); page.app.sfx.playStepper(); } }
            TileGrid {
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󱂬"; title: "Smart auto-hide"; geoShape: "cookie12"; checked: page.d("smartAutohide"); onToggled: (v) => { page.setDock("smartAutohide", v); page.app.sfx.playToggle(v); } }
                SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰘓"; title: "Auto-hide"; geoShape: "star5"; checked: page.d("autohide"); onToggled: (v) => { page.setDock("autohide", v); page.app.sfx.playToggle(v); } }
            }
            SSlider { visible: page.d("autohide") || page.d("smartAutohide"); icon: "󰔛"; title: "Auto-hide delay"; value: page.dockTimeoutFrac; valueText: Math.round((250 + page.dockTimeoutFrac * 4750) / 50) * 50 + " ms"; onMoved: (v) => page.dockTimeoutFrac = v }
        }
    }
}
