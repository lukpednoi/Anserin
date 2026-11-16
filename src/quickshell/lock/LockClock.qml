import QtQuick
import "../"
import "redactor"

Item {
    id: clockModule
    required property var screenRoot
    required property var store

    property var currentTime: new Date()
    // Simple keeps the clock with its password
    readonly property bool concealed: !screenRoot.simple && (screenRoot.inputActive || screenRoot.centerReveal > 0.02)
    readonly property real fit: Math.min(width / clockModule.store.refW, height / clockModule.store.refH)

    anchors.fill: parent
    opacity: clockModule.concealed ? 0.0 : 1.0
    scale: clockModule.concealed ? 0.92 : 1.0
    visible: opacity > 0.01

    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Item {
        width: clockModule.store.refW
        height: clockModule.store.refH
        anchors.centerIn: parent
        scale: clockModule.fit

        Loader {
            anchors.fill: parent
            active: clockModule.visible && clockModule.screenRoot.sceneActive
            sourceComponent: LockLayoutView {
                store: clockModule.store
                scope: "screen"
                ctx: clockModule.screenRoot
            }
        }
    }
}
