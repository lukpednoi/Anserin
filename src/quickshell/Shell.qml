import QtQuick
import Quickshell
import "widgets"
import "lock/redactor"
import "anserin"

ShellRoot {
    readonly property bool performanceMode: !!(Config.getSetting("general", {}).performance)
    readonly property bool dockEnabled: Config.getSetting("dock", {}).enabled !== false

    Connections {
        target: Quickshell
        function onReloadCompleted() { Quickshell.inhibitReloadPopup() }
        function onReloadFailed(errorString) { Quickshell.inhibitReloadPopup() }
    }

    ScreenshotOverlay {}
    Main { id: mainWindow }
    EdgeBatteryTrigger { onTriggered: function(screenName) { mainWindow.openFromEdge("controlcenter", screenName); } }
    // the left edge: the full panel, or in Workspace only the small workspace capsule first
    EdgeBatteryTrigger {
        edge: "left"
        onTriggered: function(screenName) {
            if (mainWindow.currentActive === "blankpanel") return;
            if (PanelLayout.workspaceOnly) PanelLayout.showCapsule(screenName);
            else mainWindow.openFromEdge("blankpanel", screenName);
        }
    }
    Loader {
        active: PanelLayout.capsuleScreen !== ""
        sourceComponent: WorkspaceCapsule { checkEdge: done => mainWindow.checkPointerOnEdge("left", done) }
    }
    ScreenBorder {}
    // inf desktop: the still cursor shown while the canvas pans (only while the mode is on somewhere)
    Loader {
        active: TerminalAppearance.infiniteActive
        sourceComponent: PanCursor {}
    }
    Lock { id: sessionLock }
    LockRedactor { id: nativeLockEditor; sessionLocked: sessionLock.isLocked }
    WidgetRedactor {
        lockEditor: nativeLockEditor
        sessionLocked: sessionLock.isLocked
    }

    // Edit panel for the left edge panel's sidebar, made only while it is open; the panel reopens after it.
    Loader {
        active: PanelLayout.editing
        sourceComponent: PanelEditor {}
    }
    Connections {
        target: PanelLayout
        function onEditFinished(screenName) { mainWindow.openFromEdge("blankpanel", screenName); }
        function onExpandRequested(screenName) { mainWindow.openFromEdge("blankpanel", screenName); }
    }

    Launcher {}
    Clipboard {}

    // the pet (Anserin interface): the duck on the desktop while Theme → Pet's Desktop pet is on, and its editor while
    // open; neither is made otherwise
    Loader {
        active: Config.dataReady && PetState.desktopOn
        sourceComponent: PetDesktop {}
    }
    Loader {
        active: PetState.editorShown
        sourceComponent: PetEditorWindow {}
    }

    Polkit {}
    PopoutManager {}

    Loader {
        active: dockEnabled
        sourceComponent: Dock {}
    }

    Loader {
        active: !performanceMode
        sourceComponent: Idle {}
    }
    Variants {
        model: performanceMode ? [] : Quickshell.screens
        delegate: WidgetLoader {
            required property var modelData
            screen: modelData
            monitorName: modelData.name
        }
    }
    Loader {
        active: !performanceMode
        sourceComponent: WallpaperEngine {}
    }

    Component.onCompleted: {
        Qt.application.organization = "anserin";
        Qt.application.domain = "anserin";
        Qt.application.name = "anserin";
        AudioProcessor.initialize();
        FirstLaunch.checkFirstLaunch();
        TerminalAppearance.initialize();
        SysNotif.checkBattery();
        // anyone still on the old Default interface moves to Anserin once (its settings are kept)
        AnserinMode.migrate();
        // weather warnings from the forecast, and official warnings for this location (Settings → Weather)
        WeatherAlerts.isQuietNow();
        GovAlerts.refresh();
        // update posts: checks GitHub a minute after start, then every 6 hours (Settings → Update)
        Updates.localVersion;
    }
}
