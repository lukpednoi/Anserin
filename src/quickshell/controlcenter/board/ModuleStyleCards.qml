import QtQuick
import QtQuick.Layouts
import "../../"

// A panel module's styles as the Settings page draws them (guide/bar/BarModulesTab.qml): one card per style with
// the real module face in it, the one in use lighter and outlined; a click pops, flashes, clicks and picks it.
// `faceFor(style)` gives a face's file, `widgetFor(style)` the stand-in widget the face reads (a preview).
Item {
    id: mc
    property var styles: []                // BarModuleRegistry.variantList(...)
    property string current: ""
    property real previewHeight: 72
    property var faceFor: function(id) { return ""; }
    property var widgetFor: function(id) { return null; }
    property bool active: true
    signal picked(string id)
    readonly property int columns: Math.max(1, Math.min(3, styles.length))
    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid
        width: mc.width
        columns: mc.columns
        rowSpacing: 10
        columnSpacing: 10
        Repeater {
            model: mc.styles
            Rectangle {
                id: card
                required property var modelData
                readonly property bool isSelected: mc.current === modelData.id
                property real popScale: 1.0
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: inner.implicitHeight + 16
                radius: ThemeBackend.borderRadius
                clip: true
                color: cardMouse.pressed ? Qt.darker(ThemeBackend.surface0, 1.15)
                     : (isSelected ? (cardHover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.30) : Qt.lighter(ThemeBackend.surface0, 1.24))
                                   : (cardHover.hovered ? Qt.lighter(ThemeBackend.surface0, 1.10) : ThemeBackend.surface0))
                border.width: 1
                border.color: isSelected ? Qt.alpha(ThemeBackend.surface2, 0.75) : (cardHover.hovered ? Qt.alpha(ThemeBackend.surface2, 0.5) : Qt.alpha(ThemeBackend.surface1, 0.4))
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 180 } }
                scale: (cardMouse.pressed ? 0.985 : (cardHover.hovered ? 1.015 : 1.0)) * popScale
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
                HoverHandler { id: cardHover }
                Rectangle { id: flash; anchors.fill: parent; radius: parent.radius; color: "#ffffff"; opacity: 0
                    PropertyAnimation on opacity { id: flashAnim; running: false; to: 0; duration: 350; easing.type: Easing.OutExpo } }
                SequentialAnimation { id: popAnim
                    NumberAnimation { target: card; property: "popScale"; to: 1.02; duration: 100; easing.type: Easing.OutQuad }
                    NumberAnimation { target: card; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint } }
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        popAnim.start(); flash.opacity = 0.15; flashAnim.start();
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                        mc.picked(card.modelData.id);
                    }
                }
                ColumnLayout {
                    id: inner
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                    spacing: 8
                    Rectangle {
                        id: box
                        Layout.fillWidth: true
                        implicitHeight: mc.previewHeight
                        radius: ThemeBackend.borderRadius
                        color: Qt.darker(ThemeBackend.mantle, 1.1)
                        clip: true
                        Item {
                            anchors.fill: parent
                            enabled: false
                            Loader {
                                anchors.centerIn: parent
                                width: item ? item.implicitWidth : 0
                                height: item ? item.implicitHeight : 0
                                scale: Math.min(1.0, Math.min((box.width - 16) / Math.max(1, width), (box.height - 16) / Math.max(1, height)))
                                asynchronous: false
                                active: mc.active
                                source: mc.faceFor(card.modelData.id)
                                onLoaded: if (item) {
                                    item.width = Qt.binding(() => item.implicitWidth);
                                    item.height = Qt.binding(() => item.implicitHeight);
                                    item.widget = mc.widgetFor(card.modelData.id);
                                }
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.name
                        elide: Text.ElideRight
                        font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true
                        color: card.isSelected ? ThemeBackend.text : ThemeBackend.subtext0
                    }
                }
            }
        }
    }
}
