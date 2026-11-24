import QtQuick
import "../../"
import "../../media" as Media

// Lazy-loaded host for BlankPanel's Music page so BlankPanel.qml does not eagerly compile media/* on first open.
Item {
    id: host
    property var panel: null
    property bool active: false

    function s(v) { return panel ? panel.s(v) : Scaler.s(v); }

    Media.MusicPopup {
        readonly property real factor: 0.9
        anchors.centerIn: parent
        width: host.s(625) * factor
        height: host.s(565) * factor
        sizeFactor: factor
        playIntro: false
        visible: true
    }
}
