import QtQuick
import QtQuick.Layouts
import "../../"

// A titled card that holds a group of settings, the same look as a monitor card (eDP-1) in Display:
// bold heading on top (with optional text or a small control on the right), the settings below.
// Drop-in for SettingsGroup: `subSettings` takes the rows, the default children go to the right of the heading.
Rectangle {
    id: root
    Layout.fillWidth: true
    property var rootObj: null
    property string title: ""
    property string description: ""
    property string icon: ""            // accepted so it can replace SettingsGroup; the heading carries the name
    property bool wrapText: true
    property string info: ""            // small grey text on the right of the heading
    default property alias headerContent: headerRight.data
    property alias subSettings: body.data

    function s(v) { return (rootObj && typeof rootObj.s === "function") ? rootObj.s(v) : v; }

    radius: ThemeBackend.borderRadius
    color: Qt.alpha(ThemeBackend.surface0, 0.4)
    border.width: 1
    border.color: Qt.alpha(ThemeBackend.surface1, 0.4)
    implicitHeight: column.implicitHeight + s(24)

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.s(12) }
        spacing: root.s(6)

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: root.s(4)
            Layout.rightMargin: root.s(4)
            Layout.bottomMargin: root.description !== "" ? 0 : root.s(6)
            spacing: root.s(8)
            Text {
                text: root.title
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(16)
                font.bold: true
                color: ThemeBackend.text
            }
            Item { Layout.fillWidth: true }
            Text {
                visible: root.info !== ""
                text: root.info
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(12)
                color: ThemeBackend.subtext0
            }
            RowLayout { id: headerRight; spacing: root.s(8) }
        }
        Text {
            visible: root.description !== ""
            Layout.fillWidth: true
            Layout.leftMargin: root.s(4)
            Layout.rightMargin: root.s(4)
            Layout.bottomMargin: root.s(6)
            text: root.description
            wrapMode: Text.WordWrap
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(11)
            color: ThemeBackend.subtext0
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            spacing: root.s(6)
        }
    }
}
