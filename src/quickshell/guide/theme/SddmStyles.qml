import "../../" as Real
import "../../reusables" as Controls
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    required property var rootObj
    property bool showHeader: true
    readonly property string selectedStyle: Real.SddmTheming.appliedStyle

    objectName: "sddm-styles"
    Layout.fillWidth: true
    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column

        width: parent.width
        spacing: root.rootObj.s(12)

        Text {
            visible: root.showHeader
            text: "SDDM"
            color: Real.ThemeBackend.text
            font.family: Real.ThemeBackend.fontFamily
            font.pixelSize: root.rootObj.s(16)
            font.bold: true
        }

        Text {
            objectName: "sddm-status"
            Layout.fillWidth: true
            visible: text !== ""
            text: Real.SddmTheming.error || (Real.SddmTheming.busy ? "Applying SDDM theme…" : "")
            color: Real.SddmTheming.error ? Real.ThemeBackend.red : Real.ThemeBackend.subtext0
            font.family: Real.ThemeBackend.fontFamily
            font.pixelSize: root.rootObj.s(11)
            wrapMode: Text.Wrap
        }

        Controls.PreviewStrip {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: root.rootObj.s(12)
            carousel: false   // only two cards: both are shown side by side

            Repeater {
                model: [{
                    "key": "old",
                    "name": "Original"
                }, {
                    "key": "new",
                    "name": "New"
                }]

                Rectangle {
                    id: card

                    required property var modelData
                    property real popScale: 1

                    objectName: "sddm-card-" + modelData.key
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: previewBox.height + root.rootObj.s(48)
                    radius: Real.ThemeBackend.clampedBorderRadius
                    color: cardGlass.active ? "transparent" : (cardMouse.containsMouse ? Real.ThemeBackend.surface1 : Real.ThemeBackend.surface0)
                    Controls.GlassFill {
                        id: cardGlass
                        objectName: "sddm-card-glass-" + card.modelData.key
                        anchors.fill: parent
                        radius: card.radius
                        allowed: !!root.rootObj.compactSettings
                        tintColor: cardMouse.containsMouse ? Real.ThemeBackend.surface1 : Real.ThemeBackend.surface0
                    }
                    border.width: root.selectedStyle === modelData.key ? root.rootObj.s(2) : 1
                    border.color: root.selectedStyle === modelData.key ? Real.ThemeBackend.mauve : Real.ThemeBackend.surface1
                    scale: popScale

                    SequentialAnimation {
                        id: pop

                        NumberAnimation {
                            target: card
                            property: "popScale"
                            to: 0.97
                            duration: 100
                            easing.type: Easing.OutQuad
                        }

                        NumberAnimation {
                            target: card
                            property: "popScale"
                            to: 1
                            duration: 250
                            easing.type: Easing.OutBack
                        }

                    }

                    Rectangle {
                        id: previewBox

                        x: root.rootObj.s(8)
                        y: root.rootObj.s(8)
                        width: parent.width - root.rootObj.s(16)
                        height: width * 720 / 1280
                        color: Real.ThemeBackend.mantle
                        radius: Real.ThemeBackend.clampedBorderRadius
                        clip: true

                        SddmPreview {
                            objectName: "sddm-preview-" + card.modelData.key
                            width: 1280
                            height: 720
                            transformOrigin: Item.TopLeft
                            scale: previewBox.width / 1280
                            active: root.visible
                            enabled: false
                            style: card.modelData.key
                        }

                    }

                    Text {
                        x: root.rootObj.s(12)
                        y: previewBox.y + previewBox.height + root.rootObj.s(10)
                        text: card.modelData.name
                        color: root.selectedStyle === card.modelData.key ? Real.ThemeBackend.mauve : Real.ThemeBackend.text
                        font.family: Real.ThemeBackend.fontFamily
                        font.pixelSize: root.rootObj.s(12)
                        font.bold: true
                    }

                    MouseArea {
                        id: cardMouse

                        objectName: "sddm-select-" + card.modelData.key
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !Real.SddmTheming.busy
                        onClicked: {
                            pop.restart();
                            Real.SddmTheming.select(card.modelData.key);
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }

                    }

                }

            }

        }

    }

}
