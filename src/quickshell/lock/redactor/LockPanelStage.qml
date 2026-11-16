import QtQuick
import "../../"

Item {
    id: stage
    required property var store
    property real k: 0.5
    property bool active: false
    property bool gridEnabled: true
    property alias scene: scene

    MouseArea {
        anchors.fill: parent
        onClicked: scene.selectedId = ""
    }

    Rectangle {
        width: stage.store.panelW
        height: stage.store.panelH
        anchors.centerIn: parent
        radius: ThemeBackend.borderRadius * 1.5
        color: ThemeBackend.surface0
        border.width: 1.5
        border.color: ThemeBackend.surface1
        clip: true

        LockScene {
            id: scene
            store: stage.store
            anchors.fill: parent
            scope: "panel"
            k: stage.k
            active: stage.active
            gridEnabled: stage.gridEnabled
        }
    }
}
