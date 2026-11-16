import QtQuick

Item {
    id: trigger
    property var target: null
    readonly property rect hitRect: target ? target.frameTriggerRect : Qt.rect(0, 0, 0, 0)
    visible: !!target && target.frameTriggerActive
    x: hitRect.x; y: hitRect.y
    width: hitRect.width; height: hitRect.height
    HoverHandler {
        onHoveredChanged: {
            if (!trigger.target) return;
            trigger.target.frameEdgeHovered = hovered;
            trigger.target.checkHideTimer();
        }
    }
    Component.onDestruction: {
        if (!target) return;
        target.frameEdgeHovered = false;
        target.checkHideTimer();
    }
}

