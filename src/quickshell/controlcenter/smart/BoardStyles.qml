import QtQuick
import "../../"

// A style choice on a board card: one card per style showing the real page's preview (`preview`, a Component that
// reads `parent.styleKey`), the one in use ringed. Two styles sit side by side; more scroll sideways. A click gives
// the real pages' press (pop, flash, click sound) and reports the style through picked.
Item {
    id: bs
    property var model: []                 // [{ key, name }]
    property string current: ""
    property Component preview: null
    property real ratio: 0.6               // preview height / width
    property color accent: ThemeBackend.mauve
    signal picked(string key)
    readonly property real cardW: model.length <= 2 ? (width - 8) / 2 : Math.min(width * 0.62, 300)
    implicitHeight: cardW * ratio + 16 + 38

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: row.width
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentWidth > width
        clip: true
        Row {
            id: row
            spacing: 8
            Repeater {
                model: bs.model
                Rectangle {
                    id: card
                    required property var modelData
                    readonly property bool on: bs.current === modelData.key
                    width: bs.cardW; height: bs.height
                    radius: Math.min(ThemeBackend.borderRadius, 14)
                    color: Qt.alpha(ThemeBackend.text, cardMa.containsMouse ? 0.07 : 0.04)
                    border.width: on ? 2 : 0; border.color: bs.accent
                    Behavior on color { ColorAnimation { duration: 160 } }
                    property real pop: 1
                    scale: pop
                    SequentialAnimation { id: popAnim
                        NumberAnimation { target: card; property: "pop"; to: 0.97; duration: 100; easing.type: Easing.OutQuad }
                        NumberAnimation { target: card; property: "pop"; to: 1; duration: 250; easing.type: Easing.OutBack } }
                    Rectangle {
                        x: 8; y: 8; width: parent.width - 16; height: width * bs.ratio
                        radius: Math.min(ThemeBackend.borderRadius, 12); color: ThemeBackend.mantle; clip: true
                        Loader {
                            anchors.fill: parent
                            property string styleKey: card.modelData.key
                            enabled: false
                            active: bs.visible
                            sourceComponent: bs.preview
                        }
                    }
                    Rectangle { id: flash; anchors.fill: parent; radius: parent.radius; color: "#ffffff"; opacity: 0
                        NumberAnimation on opacity { id: flashAnim; running: false; to: 0; duration: 350; easing.type: Easing.OutExpo } }
                    Row {
                        x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 11; spacing: 6
                        Rectangle { visible: card.on; width: 16; height: 16; radius: 8; color: bs.accent; anchors.verticalCenter: parent.verticalCenter
                            Text { anchors.centerIn: parent; text: "󰄬"; font.family: ThemeBackend.iconFont; font.pixelSize: 10; color: ThemeBackend.crust } }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: card.modelData.name; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true
                               color: card.on ? bs.accent : ThemeBackend.text }
                    }
                    MouseArea {
                        id: cardMa
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popAnim.restart(); flash.opacity = 0.15; flashAnim.restart();
                            Sounds.playSfx("reusables/clickbutton/click.wav");
                            if (!card.on) bs.picked(card.modelData.key);
                        }
                    }
                }
            }
        }
    }
    WheelHandler {
        enabled: flick.interactive
        acceptedDevices: PointerDevice.Mouse
        onWheel: (e) => flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX - e.angleDelta.y))
    }
}
