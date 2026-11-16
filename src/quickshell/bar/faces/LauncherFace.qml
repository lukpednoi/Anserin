import QtQuick
import "../../"
import "../../reusables"

Item {
    id: root
    property var module: null
    property var widget: module
    readonly property var barWindow: module ? module.barWindow : null
    property real targetWidth: module && !module.moduleActive ? 0 : Scaler.s(40)
    property real targetHeight: targetWidth
    implicitWidth: targetWidth
    implicitHeight: targetHeight
    IconButton {
        objectName: "launcher-toggle"
        anchors.centerIn: parent
        size: Scaler.s(30)
        buttonIcon: "󰵆"
        iconFontSize: Scaler.s(16)
        accentColor: ThemeBackend.surface0
        textColor: ThemeBackend.text
        Accessible.name: "Launcher"
        onClicked: {
            ClipboardController.hide();
            LauncherController.toggle(root.barWindow ? root.barWindow.screen : null, !!root.barWindow);
        }
    }
}
