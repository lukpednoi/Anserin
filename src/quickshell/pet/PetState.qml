pragma Singleton
import QtQuick
import Quickshell
import "../"

// The pet (the Anserin interface only): which one (theme.pet, "cat" or "duck"), the duck's settings
// (theme.petDuck: breed, colour, size, sound, recall, scene: the editor's River, Grass or Waterfall), whether it lives on the desktop (theme.petMode), its quack,
// and the duck editor's open state. Theme → Pet, the desktop pet (PetDesktop) and the editor (PetEditorWindow) share it.
Singleton {
    id: root

    readonly property var theme: Config.getSetting("theme", {}) || {}
    readonly property bool duck: theme.pet === "duck"
    readonly property bool desktopOn: duck && theme.petMode === true

    readonly property var duckDefaults: ({ breed: "call", colour: "white", size: 128, sound: true, recall: true, scene: "grass" })
    readonly property var duckSettings: Object.assign({}, duckDefaults, theme.petDuck || {})
    readonly property string colour: duckSettings.colour || "white"

    function saveDuck(key, value) { Config.setSetting("theme.petDuck." + key, value); }
    function setDesktop(on) { Config.setSetting("theme.petMode", on); }

    // the quack (CC BY-SA, see assets/sounds/pet/CREDITS.txt), at the shell's effect volume; off with the duck's sound
    function quack() {
        if (duckSettings.sound === false) return;
        Sounds.play(Caching.anserinDir + "/assets/sounds/pet/quack.ogg");
    }

    // the duck editor: `editorShown` keeps its window for the closing animation after `editorOpen` turns off.
    // Opened from the desktop pet (openEditorFrom), the editor carries that duck in from where it stood (`handoff`:
    // { x, y, size, snap }, on screen `editorScreen`) and back out when it closes; meanwhile `duckInEditor` hides the
    // desktop one. The editor calls finishClose() once it is done.
    property bool editorOpen: false
    property bool editorShown: false
    property var handoff: null
    property string editorScreen: ""
    property bool duckInEditor: false
    function openEditor() { editorShown = true; editorOpen = true; }
    function openEditorFrom(h, screenName) { handoff = h; editorScreen = screenName || ""; openEditor(); }
    function closeEditor() { editorOpen = false; hideEditor.restart(); }
    function finishClose() { hideEditor.stop(); duckInEditor = false; handoff = null; editorShown = false; }
    // a safety net in case the editor never reports back
    property Timer hideEditor: Timer { interval: 2000; onTriggered: if (!root.editorOpen) root.finishClose() }
}
