import QtQuick
import Quickshell
import "../"

Item {
    id: root

    // Load each popout PanelWindow only while open (plus a short grace period for its close animation and
    // rapid re-triggers like volume keys), then destroy it and return freed heap pages to the OS.
    component LazyPopout: Item {
        id: host
        property bool wantOpen: false
        property string sourceUrl: ""
        property int graceMs: 1500
        property bool keepAlive: wantOpen

        onWantOpenChanged: {
            if (wantOpen) {
                unloadTimer.stop();
                keepAlive = true;
            } else if (keepAlive) {
                unloadTimer.restart();
            }
        }

        Timer {
            id: unloadTimer
            interval: host.graceMs
            repeat: false
            onTriggered: {
                if (!host.wantOpen) {
                    host.keepAlive = false;
                    Qt.callLater(function() {
                        gc();
                        if (typeof Sounds !== "undefined") Sounds.trimMemory();
                    });
                }
            }
        }

        Loader {
            active: host.wantOpen || host.keepAlive
            source: active ? host.sourceUrl : ""
        }
    }

    LazyPopout { wantOpen: OsdController.isVisible; sourceUrl: Qt.resolvedUrl("Osd.qml"); graceMs: 2500 }
    LazyPopout { wantOpen: TrayMenuController.isVisible; sourceUrl: Qt.resolvedUrl("TrayBase.qml"); graceMs: 1200 }
    LazyPopout { wantOpen: SideMusicController.isVisible; sourceUrl: Qt.resolvedUrl("SideMusicPopout.qml"); graceMs: 1200 }
    LazyPopout { wantOpen: DesktopMenuController.isVisible; sourceUrl: Qt.resolvedUrl("DesktopMenu.qml"); graceMs: 1200 }
}
