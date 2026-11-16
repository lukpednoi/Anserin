import QtQuick
import Quickshell
import "../../../"
import "../../../guide/shared"
import "../../../guide/notifications"
import ".."

// Alerts as a board: notifications (guide/notifications/NotificationsTab.qml) and the on-screen display
// (guide/OnScreenDisplayTab.qml), each through its page's own logic (NotificationsLogic / OsdLogic) with the real
// position pickers (drag on a small screen, a preview). Sounds can be added, chosen (heard as chosen) and tested.
BoardPage {
    id: page
    function esc(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); }
    property bool notifPicking: false
    property bool osdPicking: false
    extras: [
        NotificationsLogic { id: nl; selector: npicker.selector; onSoundInstalled: soundPicker.close() },
        OsdLogic { id: ol; selector: opicker.selector },
        SoundPicker {
            id: soundPicker
            rootObj: page.rootObj
            onSoundSelected: function(filePath, fileName) {
                if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") nl.installSound(filePath, fileName);
            }
        }
    ]
    Component.onCompleted: { nl.syncSettings(); ol.syncSettings(); nl.reloadSoundsDebounceTimer.restart(); }
    onVisibleChanged: {
        if (visible) { nl.syncSettings(); ol.syncSettings(); nl.reloadSoundsDebounceTimer.restart(); }
        else { nl.reloadSoundsDebounceTimer.stop(); notifPicking = false; osdPicking = false; soundPicker.close(); }
    }

    // a picker that opens and shuts under its card's buttons (kept alive: its logic reads the screen from it)
    component PickerSlot: Item {
        id: slot
        property bool open: false
        default property alias content: holder.data
        readonly property Item picker: holder.children.length ? holder.children[0] : null
        property bool hidden: !open && height < 1
        implicitHeight: open && picker ? picker.implicitHeight : 0
        height: implicitHeight
        Behavior on implicitHeight { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        clip: true
        opacity: open ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        Item { id: holder; width: slot.width; height: slot.picker ? slot.picker.implicitHeight : 0 }
    }

    // ---------- notifications ----------
    BoardCard {
        title: "Notifications"; icon: "󰂚"; accent: page.accent
        BoardCell {
            kind: "select"; icon: "󰍹"; title: I18n.t("guide.notifications.position.title", "Screen position")
            options: [I18n.t("guide.notifications.position.top_right", "Top Right"), I18n.t("guide.notifications.position.top_center", "Top Center"),
                      I18n.t("guide.notifications.position.top_left", "Top Left"), I18n.t("guide.notifications.position.bottom_right", "Bottom Right"),
                      I18n.t("guide.notifications.position.bottom_center", "Bottom Center"), I18n.t("guide.notifications.position.bottom_left", "Bottom Left")]
            values: [0, 1, 2, 3, 4, 5]
            value: nl.isCustomPos ? -1 : (["top right", "top center", "top left", "bottom right", "bottom center", "bottom left"].indexOf(nl.position) >= 0
                   ? ["top right", "top center", "top left", "bottom right", "bottom center", "bottom left"].indexOf(nl.position) : nl.getPresetIndex(nl.horizontalPosition, nl.verticalPosition))
            valueText: nl.isCustomPos ? I18n.t("guide.position.custom", "Custom") + " (" + nl.horizontalPosition + "%, " + nl.verticalPosition + "%)" : ""
            onPicked: (v) => nl.setPosFromIndex(v)
        }
        BoardCell {
            kind: "action"; icon: page.notifPicking ? "󰅖" : "󰍹"
            title: page.notifPicking ? I18n.t("guide.notifications.position.close_selector", "Close the selector") : I18n.t("guide.notifications.position.select_on_screen", "Select on screen...")
            actionText: page.notifPicking ? "Close" : "Open"
            onActivated: page.notifPicking = !page.notifPicking
        }
        PickerSlot {
            open: page.notifPicking
            NotificationPositionPicker { id: npicker; logic: nl; rootObj: page.rootObj }
        }
        BoardCell { kind: "toggle"; icon: "󰂛"; title: I18n.t("guide.notifications.dnd.title"); value: nl.dnd
                    onPicked: (v) => { nl.dnd = v; nl.updateNotifSetting("dnd", v); } }
        BoardCell { kind: "toggle"; icon: "󰋑"; title: I18n.t("guide.notifications.empty_graphic.title"); value: nl.showEmptyGraphic
                    onPicked: (v) => { nl.showEmptyGraphic = v; nl.updateNotifSetting("showEmptyGraphic", v); } }
        BoardCell { kind: "toggle"; icon: "󰂚"; title: I18n.t("guide.notifications.sound.title"); value: nl.soundEnabled
                    onPicked: (v) => { nl.soundEnabled = v; nl.updateNotifSetting("sound", v); } }
        BoardCell {
            kind: "select"; icon: "󰎆"; title: I18n.t("guide.notifications.sound_file.title"); hidden: !nl.soundEnabled
            options: nl.availableSounds; values: nl.soundList.map(x => x.path)
            value: nl.selectedSound
            onPicked: (v) => {
                nl.selectedSound = v;
                nl.updateNotifSetting("soundFile", v);
                if (typeof Sounds !== "undefined" && typeof Sounds.play === "function") Sounds.play(v);
            }
        }
        BoardCell { kind: "action"; icon: "󰐕"; title: "Add sound"; actionText: "Add"; hidden: !nl.soundEnabled; onActivated: soundPicker.openPicker() }
        BoardCell {
            kind: "action"; icon: "󰉋"; title: "Sounds folder"; actionText: "Open"; hidden: !nl.soundEnabled
            onActivated: {
                const p = Caching.stateDir ? (Caching.stateDir + "/sounds/notifications") : (Caching.home + "/.local/state/anserin/sounds/notifications");
                FileManager.openFolder(p, true);
            }
        }
        BoardCell {
            kind: "action"; icon: "󰂚"; title: I18n.t("guide.notifications.test", "Test notification"); actionText: "Send"
            onActivated: Quickshell.execDetached(["notify-send", "-u", "critical", I18n.t("guide.notifications.test", "Test notification"),
                                                  I18n.t("guide.notifications.test_desc", "This is a test notification")])
        }
    }

    // ---------- on-screen display ----------
    BoardCard {
        title: "On-Screen Display"; icon: "󰕾"; accent: page.accent
        BoardCell {
            kind: "select"; icon: "󰍹"; title: I18n.t("guide.osd.position.title", "Screen position")
            options: [I18n.t("guide.osd.position.bottom_center", "Bottom Center"), I18n.t("guide.osd.position.bottom_left", "Bottom Left"),
                      I18n.t("guide.osd.position.bottom_right", "Bottom Right"), I18n.t("guide.osd.position.top_center", "Top Center"),
                      I18n.t("guide.osd.position.top_left", "Top Left"), I18n.t("guide.osd.position.top_right", "Top Right")]
            values: [0, 1, 2, 3, 4, 5]
            value: {
                if (ol.isCustomPos) return -1;
                const v = ol.verticalPosition, h = ol.horizontalPosition;
                if (v === 90 && h === 50) return 0; if (v === 90 && h === 10) return 1; if (v === 90 && h === 90) return 2;
                if (v === 10 && h === 50) return 3; if (v === 10 && h === 10) return 4; if (v === 10 && h === 90) return 5;
                return -1;
            }
            valueText: ol.isCustomPos ? I18n.t("guide.position.custom", "Custom") + " (" + ol.horizontalPosition + "%, " + ol.verticalPosition + "%)" : ""
            onPicked: (v) => ol.setPosFromIndex(v)
        }
        BoardCell {
            kind: "action"; icon: page.osdPicking ? "󰅖" : "󰍹"
            title: page.osdPicking ? I18n.t("guide.osd.position.close_selector", "Close the selector") : I18n.t("guide.osd.position.select_on_screen", "Select on screen...")
            actionText: page.osdPicking ? "Close" : "Open"
            onActivated: page.osdPicking = !page.osdPicking
        }
        PickerSlot {
            open: page.osdPicking
            OsdPositionPicker { id: opicker; logic: ol; rootObj: page.rootObj }
        }
        Repeater {
            model: [{ icon: "󰘲", title: "Caps Lock", key: "showCapsLock" }, { icon: "󰎤", title: "Num Lock", key: "showNumLock" }, { icon: "󰀝", title: "Airplane Mode", key: "showAirplane" }]
            BoardCell {
                required property var modelData
                kind: "toggle"; icon: modelData.icon; title: modelData.title
                available: !ol.isVertical
                value: modelData.key === "showCapsLock" ? ol.showCapsLock : (modelData.key === "showNumLock" ? ol.showNumLock : ol.showAirplane)
                onPicked: (v) => {
                    if (modelData.key === "showCapsLock") ol.showCapsLock = v;
                    else if (modelData.key === "showNumLock") ol.showNumLock = v;
                    else ol.showAirplane = v;
                    ol.updateOsdSetting(modelData.key, v);
                }
            }
        }
        BoardCell { kind: "toggle"; icon: "󱂬"; title: I18n.t("guide.osd.attach_bar.title", "Attach to the bar in solid/fill style"); value: ol.attachToBar
                    onPicked: (v) => { ol.attachToBar = v; ol.updateOsdSetting("attachToBar", v); } }
        BoardCell { kind: "action"; icon: "󰕾"; title: I18n.t("guide.osd.test", "Test OSD"); actionText: "Show"
                    onActivated: if (typeof OsdController !== "undefined") OsdController.show("volume") }
    }
}
