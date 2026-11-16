import QtQuick

Item {
    objectName: "update-page"
    required property var rootObj
    required property int tabIndex
    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
}
