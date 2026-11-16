pragma Singleton
import QtQuick
import Quickshell
import "../../"

Item {
    id: controller

    property bool isVisible: false
    property bool fromBar: false
    property string activeItemId: ""
    property real targetX: 0
    property real targetY: 0
    property bool alignRight: false
    property bool alignBottom: false
    property bool isSideBar: false
    property var screen: null
    property bool menuHovered: false
    property int hoveredItems: 0
    readonly property bool itemHovered: hoveredItems > 0

    Timer {
        id: hideTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (!controller.menuHovered && controller.hoveredItems <= 0) {
                controller.isVisible = false;
            }
        }
    }

    function itemEntered(itemId, scr, posX, posY, isRight, isBottom, isSide, fromBar) {
        hoveredItems++;
        hideTimer.stop();
        show(itemId, scr, posX, posY, isRight, isBottom, isSide, fromBar);
    }

    function itemExited() {
        hoveredItems = Math.max(0, hoveredItems - 1);
        if (hoveredItems <= 0 && !menuHovered) {
            requestHide();
        }
    }

    function show(itemId, scr, posX, posY, isRight, isBottom, isSide, fromBar) {
        controller.fromBar = !!fromBar;
        hideTimer.stop();
        controller.screen = scr;
        // side and alignment first: a change there snaps the menu, a new target on the same side glides it
        controller.alignRight = isRight;
        controller.alignBottom = isBottom;
        controller.isSideBar = isSide;
        controller.targetX = posX;
        controller.targetY = posY;
        controller.activeItemId = itemId;
        controller.isVisible = true;
    }

    function hide() {
        hideTimer.stop();
        hoveredItems = 0;
        controller.activeItemId = "";
        controller.isVisible = false;
        controller.fromBar = false;
    }

    function requestHide() {
        if (!controller.menuHovered && controller.hoveredItems <= 0) {
            hideTimer.restart();
        }
    }

    function cancelHide() {
        hideTimer.stop();
    }

    function toggle(itemId, scr, posX, posY, isRight, isBottom, isSide, fromBar) {
        if (controller.isVisible && controller.activeItemId === itemId) {
            controller.hide();
        } else {
            controller.show(itemId, scr, posX, posY, isRight, isBottom, isSide, fromBar);
        }
    }
}
