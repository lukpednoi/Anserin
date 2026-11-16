import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../"

// Notifications & On-Screen Display: two Settings pages on one scrolling page, each under its own heading.
Item {
    id: root
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 0

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)
    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + root.rootObj.s(8)
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: col
            width: parent.width
            spacing: root.rootObj.s(4)

            Text {
                Layout.leftMargin: root.rootObj.s(14)
                Layout.topMargin: root.rootObj.s(8)
                text: "Notifications"
                color: ThemeBackend.text
                font { family: ThemeBackend.fontFamily; pixelSize: root.rootObj.s(16); bold: true }
            }
            Loader {
                Layout.fillWidth: true
                Component.onCompleted: setSource("notifications/NotificationsTab.qml", { rootObj: root.rootObj, tabIndex: root.tabIndex, sectionMode: true })
            }
            Text {
                Layout.leftMargin: root.rootObj.s(14)
                Layout.topMargin: root.rootObj.s(12)
                text: "On-Screen Display"
                color: ThemeBackend.text
                font { family: ThemeBackend.fontFamily; pixelSize: root.rootObj.s(16); bold: true }
            }
            Loader {
                Layout.fillWidth: true
                Component.onCompleted: setSource("OnScreenDisplayTab.qml", { rootObj: root.rootObj, tabIndex: root.tabIndex, sectionMode: true })
            }
        }
    }
}
