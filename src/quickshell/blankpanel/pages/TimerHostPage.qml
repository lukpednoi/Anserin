import QtQuick
import "../../"

// Lazy-loaded host for BlankPanel's Timer page.
Item {
    id: host
    property var panel: null
    property bool active: false

    function s(v) { return panel ? panel.s(v) : Scaler.s(v); }

    Loader {
        readonly property real factor: 1.3
        property var scaleFunc: v => host.s(v) * factor
        property string activeEdge: "left"
        property bool isCurrentTarget: host.active
        anchors.centerIn: parent
        width: host.s(380) * factor
        height: host.s(330) * factor
        asynchronous: true
        source: Qt.resolvedUrl("../../quickactions/actions/Timer.qml")
    }
}
