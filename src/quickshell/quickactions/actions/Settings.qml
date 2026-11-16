import QtQuick
import QtQuick.Window
import QtQuick.Controls
import "../../"

Item {
    id: root
    signal closeRequested()

    readonly property bool horizontal: activeEdge === "bottom" || activeEdge === "top"
    readonly property real panelWidth: Math.min(scaleFunc(880), availableWidth)
    readonly property real panelHeight: Math.min(scaleFunc(580), availableHeight)
    readonly property real preferredWidth: horizontal ? panelHeight : panelWidth
    readonly property real preferredExtraLength: Math.max(0, (horizontal ? panelWidth : panelHeight) - sidebarLength)
    readonly property bool hasInputFocus: visible && (!!(Overlay.overlay && Overlay.overlay.visible) || !!(Window.window && Window.window.activeFocusItem && Window.window.activeFocusItem.cursorRectangle !== undefined))
    readonly property bool needsPopupInput: visible && !!(Overlay.overlay && Overlay.overlay.visible)
    readonly property var interceptedShortcuts: visible ? ["Tab", "Backtab", "Shift+Tab", "Return", "Enter", "Left", "Right", "Up", "Down", "Escape"] : []

    function unfocusInputs() {
        guide.forceActiveFocus();
    }

    GuidePopup {
        id: guide
        anchors.centerIn: parent
        width: root.panelWidth
        height: root.panelHeight
        rotation: activeEdge === "right" ? 180 : (activeEdge === "bottom" ? 90 : (activeEdge === "top" ? -90 : 0))
        visible: true
        embedded: true
        onCloseRequested: root.closeRequested()
    }
}
