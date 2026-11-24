import QtQuick
import "../../"

// Lazy-loaded host for BlankPanel's Calculator page.
Item {
    id: host
    property var panel: null
    property bool active: false

    function s(v) { return panel ? panel.s(v) : Scaler.s(v); }

    Loader {
        readonly property real factor: !item ? 1.3 : item.converter ? 1.1 : item.advanced ? 0.95 : 1.3
        property var scaleFunc: v => host.s(v) * factor
        property string activeEdge: "left"
        property bool isCurrentTarget: host.active
        anchors.centerIn: parent
        width: item ? item.baseW : host.s(380) * factor
        height: item && item.converter ? parent.height - host.s(28) : (item ? item.baseL : host.s(350) * factor)
        asynchronous: true
        source: Qt.resolvedUrl("../../quickactions/actions/Calculator.qml")
    }
}
