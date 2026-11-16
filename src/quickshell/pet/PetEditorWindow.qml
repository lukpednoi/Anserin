import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../"

// The duck editor's window: over everything on the focused screen, with the keyboard while it is open (Esc closes).
// Shell.qml makes it while PetState.editorShown (from the desktop pet's pencil or Theme → Pet's Customize).
PanelWindow {
    id: win
    // the desktop duck's screen when it comes from there, otherwise the focused screen; it stays there while open
    Component.onCompleted: {
        const name = PetState.editorScreen || (Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "");
        screen = Quickshell.screens.find(s => s.name === name) || Quickshell.screens[0];
    }
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "anserin-pet-editor"
    WlrLayershell.keyboardFocus: PetState.editorOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // while it fades out it takes no clicks, so nothing underneath is ever blocked
    mask: PetState.editorOpen ? null : noInput
    Region { id: noInput }

    DuckEditor {
        anchors.fill: parent
        open: PetState.editorOpen
        settings: PetState.duckSettings
        onSave: (key, value) => PetState.saveDuck(key, value)
        handoff: PetState.handoff
        onFinished: PetState.closeEditor()
        onClosed: PetState.finishClose()
        onTookDuck: PetState.duckInEditor = true
        onQuacked: PetState.quack()
    }
}
