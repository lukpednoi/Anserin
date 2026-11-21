pragma Singleton
import QtQuick
import Quickshell
import "../../"

Item {
    id: controller

    signal menuTriggered()

    property bool isVisible: false
    property real targetX: 0
    property real targetY: 0
    property var screen: null
    property string mode: "desktop"
    property string targetWidgetId: ""
    property real menuOriginX: 0.5
    property real menuOriginY: 0.5
    property bool isMenuShuffle: false

    function openAt(scr, posX, posY, menuMode, widgetId) {
        controller.screen = scr;
        controller.targetX = posX;
        controller.targetY = posY;
        controller.mode = menuMode !== undefined ? menuMode : "desktop";
        controller.targetWidgetId = widgetId !== undefined ? String(widgetId) : "";
        controller.isVisible = true;
        controller.menuTriggered();
    }

    function show(scr, posX, posY, menuMode, widgetId) {
        openAt(scr, posX, posY, menuMode, widgetId);
    }

    function hide() {
        controller.isVisible = false;
    }

    function toggle(scr, posX, posY, menuMode, widgetId) {
        let m = menuMode !== undefined ? menuMode : "desktop";
        let wId = widgetId !== undefined ? String(widgetId) : "";

        // a second right-click on the desktop while its menu is open closes it (widgets have no menu of their own)
        if (controller.isVisible && m === "desktop" && controller.mode === "desktop") {
            controller.hide();
            return;
        }

        openAt(scr, posX, posY, m, wId);
    }
}
