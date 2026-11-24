import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../../"
import "../../../guide/shared"
import "../../../guide/notifications"
import "../../../reusables"

// 8. ALERTS — Notifications & On-Screen Display (both with 6-zone PositionGrid6)
Column {
    id: page
    property var app: null
    spacing: 11

    NotificationsLogic { id: nl; onSoundInstalled: soundPicker.close() }
    OsdLogic { id: ol }
    Item {
        width: 0; height: 0; visible: false
        SoundPicker {
            id: soundPicker
            rootObj: page.app ? page.app.shim : null
            onOpened: if (page.app) page.app.modalOpened()
            onClosed: if (page.app) page.app.modalClosed()
            onSoundSelected: function(filePath, fileName) {
                if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") nl.installSound(filePath, fileName);
            }
        }
    }
    Component.onCompleted: { nl.syncSettings(); ol.syncSettings(); nl.reloadSoundsDebounceTimer.restart(); }
    Component.onDestruction: { nl.reloadSoundsDebounceTimer.stop(); soundPicker.close(); }

    readonly property var notifPositions: ["top right", "top center", "top left", "bottom right", "bottom center", "bottom left"]
    readonly property var notifGridToReal: [2, 1, 0, 5, 4, 3]
    readonly property int notifPosIdx: { const r = notifPositions.indexOf(nl.position); return r >= 0 ? notifGridToReal[r] : 2; }
    readonly property var notifSoundNames: nl.availableSounds || []
    readonly property int notifSoundIdx: Math.max(0, (nl.soundList || []).map(x => x.path).indexOf(nl.selectedSound))

    readonly property var osdRealToGrid: [4, 3, 5, 1, 0, 2]
    readonly property int osdReal: {
        const v = ol.verticalPosition, h = ol.horizontalPosition;
        if (v === 90 && h === 50) return 0; if (v === 90 && h === 10) return 1; if (v === 90 && h === 90) return 2;
        if (v === 10 && h === 50) return 3; if (v === 10 && h === 10) return 4; if (v === 10 && h === 90) return 5;
        return 0;
    }
    readonly property int osdPosIdx: osdRealToGrid[osdReal]

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
    component TileGrid: GridLayout { width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8 }

    component PositionGrid6: Rectangle {
        id: pg
        property int currentIndex: 2
        property string badgeIcon: "󰂚"
        property string badgeText: "Toast"
        property real badgeWidth: 102
        signal picked(int idx)

        width: parent.width; height: 108; radius: 14
        color: page.app.cTile
        border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.24)

        readonly property int colIdx: currentIndex % 3
        readonly property int rowIdx: Math.floor(currentIndex / 3)
        readonly property real targetBx: width > 20 ? (colIdx === 0 ? 10 : (colIdx === 1 ? (width - badgeWidth) * 0.5 : width - badgeWidth - 10)) : 10
        readonly property real targetBy: height > 20 ? (rowIdx === 0 ? 10 : height - 40) : 10
        SpringVal { id: bx; target: pg.targetBx; stiffness: 320; damping: 0.54; eps: 0.4 }
        SpringVal { id: by; target: pg.targetBy; stiffness: 320; damping: 0.54; eps: 0.4 }
        onWidthChanged: if (width > 20 && !bx.moving) bx.snap(targetBx)
        onHeightChanged: if (height > 20 && !by.moving) by.snap(targetBy)
        Component.onCompleted: Qt.callLater(() => { if (width > 20) bx.snap(targetBx); if (height > 20) by.snap(targetBy); })

        GridLayout {
            anchors.fill: parent; anchors.margins: 8; columns: 3; rows: 2; columnSpacing: 6; rowSpacing: 6
            Repeater {
                model: 6
                Rectangle {
                    required property int index
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 9
                    color: index === pg.currentIndex ? "transparent" : (page.app.darkMode ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(0, 0, 0, 0.035))
                    border.width: 1; border.color: page.app.darkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pg.picked(index) }
                }
            }
        }
        Rectangle {
            x: bx.value; y: by.value; width: pg.badgeWidth; height: 30; radius: 11
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: page.app.cAccent } GradientStop { position: 1.0; color: page.app.cAccent2 } }
            Row { anchors.centerIn: parent; spacing: 5
                Text { text: pg.badgeIcon; font.family: page.app.iconFont; font.pixelSize: 11; color: page.app.cOnAccent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: pg.badgeText; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: page.app.cOnAccent; anchors.verticalCenter: parent.verticalCenter } }
        }
    }

    SCard {
        title: "Notifications"; icon: "󰂚"; statusText: ["TOP LEFT", "TOP CENTER", "TOP RIGHT", "BOTTOM LEFT", "BOTTOM CENTER", "BOTTOM RIGHT"][page.notifPosIdx]
        PositionGrid6 {
            currentIndex: page.notifPosIdx
            badgeIcon: "󰂚"; badgeText: "Alert Toast"; badgeWidth: 106
            onPicked: (idx) => { const r = page.notifGridToReal[idx]; if (page.notifPositions[r] !== nl.position) nl.setPosFromIndex(r); page.app.sfx.playSwitch(); }
        }
        TileGrid {
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰂛"; title: "Do Not Disturb"; geoShape: "shield"; checked: nl.dnd; onToggled: (v) => { nl.dnd = v; nl.updateNotifSetting("dnd", v); page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰋑"; title: "Show empty graphic"; geoShape: "flower5"; checked: nl.showEmptyGraphic; onToggled: (v) => { nl.showEmptyGraphic = v; nl.updateNotifSetting("showEmptyGraphic", v); page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰂚"; title: "Notification sound"; geoShape: "teardrop"; checked: nl.soundEnabled; onToggled: (v) => { nl.soundEnabled = v; nl.updateNotifSetting("sound", v); page.app.sfx.playToggle(v); } }
            SAction {
                Layout.fillWidth: true; Layout.preferredWidth: 1; implicitHeight: 84; icon: "󰂚"; title: "Test notification"; actionText: "Send"
                onTriggered: {
                    page.app.sfx.playQuick();
                    Quickshell.execDetached(["notify-send", "-u", "critical", I18n.t("guide.notifications.test", "Test notification"),
                                             I18n.t("guide.notifications.test_desc", "This is a test notification")]);
                }
            }
        }
        SChoice {
            visible: nl.soundEnabled; width: parent.width; icon: "󰎆"; title: "Sound file"
            options: page.notifSoundNames; currentIndex: page.notifSoundIdx
            onPicked: (i) => {
                const sp = (nl.soundList || [])[i];
                if (!sp) return;
                nl.selectedSound = sp.path;
                nl.updateNotifSetting("soundFile", sp.path);
                if (typeof Sounds.play === "function") Sounds.play(sp.path);
            }
        }
        TileGrid {
            visible: nl.soundEnabled
            SAction { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰐕"; title: "Add sound"; actionText: "Add"; onTriggered: { page.app.sfx.playClick(); soundPicker.openPicker(); } }
            SAction { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰉋"; title: "Sounds folder"; actionText: "Open"; onTriggered: { page.app.sfx.playClick(); FileManager.openFolder(Caching.stateDir ? (Caching.stateDir + "/sounds/notifications") : (Caching.home + "/.local/state/anserin/sounds/notifications"), true); } }
        }
    }

    SCard {
        title: "On-Screen Display"; icon: "󰕾"; statusText: ["TOP LEFT", "TOP CENTER", "TOP RIGHT", "BOTTOM LEFT", "BOTTOM CENTER", "BOTTOM RIGHT"][page.osdPosIdx]
        PositionGrid6 {
            currentIndex: page.osdPosIdx
            badgeIcon: "󰕾"; badgeText: "OSD 75%"; badgeWidth: 96
            onPicked: (idx) => { const r = page.osdRealToGrid.indexOf(idx); if (r >= 0 && r !== page.osdReal) ol.setPosFromIndex(r); page.app.sfx.playSwitch(); }
        }
        TileGrid {
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰘲"; title: "Caps Lock"; geoShape: "cookie6"; checked: ol.showCapsLock; onToggled: (v) => { ol.showCapsLock = v; ol.updateOsdSetting("showCapsLock", v); page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰎤"; title: "Num Lock"; geoShape: "octagon"; checked: ol.showNumLock; onToggled: (v) => { ol.showNumLock = v; ol.updateOsdSetting("showNumLock", v); page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰀝"; title: "Airplane Mode"; geoShape: "triangle"; checked: ol.showAirplane; onToggled: (v) => { ol.showAirplane = v; ol.updateOsdSetting("showAirplane", v); page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󱂬"; title: "Attach to bar"; geoShape: "squircle"; checked: ol.attachToBar; onToggled: (v) => { ol.attachToBar = v; ol.updateOsdSetting("attachToBar", v); page.app.sfx.playToggle(v); } }
        }
        SAction { width: parent.width; icon: "󰕾"; title: "Test OSD"; actionText: "Show"; onTriggered: { page.app.sfx.playQuick(); if (typeof OsdController !== "undefined") OsdController.show("volume"); } }
    }
}
