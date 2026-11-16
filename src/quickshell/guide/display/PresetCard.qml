import "../../"
import "../../reusables"
import "../../widgets" as Widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var profile
    required property int profileIndex
    required property var rootObj
    readonly property var presetPalette: profile.palette || (profile.settings.theme || {
    }).colors || {
    }
    readonly property var snapshot: profile.snapshot || {
        "width": 1920,
        "height": 1080,
        "screen": ""
    }
    readonly property var widgets: profile.widgets ? profile.widgets[snapshot.screen.replace(/[^a-zA-Z0-9_-]/g, "_")] || profile.widgets[Object.keys(profile.widgets)[0]] || [] : []
    readonly property var bar: profile.settings.bar || {
    }

    implicitHeight: preview.height + rootObj.s(100)
    radius: ThemeBackend.clampedBorderRadius
    color: presetGlass.active ? "transparent" : ThemeBackend.surface0
    GlassFill {
        id: presetGlass
        objectName: "preset-card-glass-" + root.profileIndex
        anchors.fill: parent
        radius: root.radius
        allowed: !!root.rootObj.compactSettings
        tintColor: ThemeBackend.surface0
    }

    Rectangle {
        id: preview

        x: root.rootObj.s(8)
        y: root.rootObj.s(8)
        width: parent.width - x * 2
        height: width * root.snapshot.height / Math.max(1, root.snapshot.width)
        radius: ThemeBackend.clampedBorderRadius
        color: root.presetPalette.base || ThemeBackend.base
        clip: true

        Image {
            anchors.fill: parent
            source: root.profile.wallpapers && root.profile.wallpapers.preview ? "file://" + root.profile.wallpapers.preview : ""
            sourceSize.width: 600
            fillMode: Image.PreserveAspectCrop
        }

        Item {
            width: root.snapshot.width
            height: root.snapshot.height
            scale: preview.width / width
            transformOrigin: Item.TopLeft

            Repeater {
                model: root.widgets

                Rectangle {
                    required property var modelData
                    readonly property string type: modelData.wType || modelData.type || "time"
                    readonly property var defaults: Widgets.WidgetRegistry.defaultSize(type)
                    readonly property var position: Widgets.WidgetRegistry.resolvePosition(modelData, root.snapshot.width, root.snapshot.height, width, height)

                    x: position.x
                    y: position.y
                    width: Number(modelData.wWidth || modelData.width || defaults.w)
                    height: Number(modelData.wHeight || modelData.height || defaults.h)
                    rotation: Number(modelData.wRotation || 0)
                    opacity: modelData.wOpacity === undefined ? 1 : modelData.wOpacity
                    radius: Number((root.profile.settings.theme || {
                    }).borderRadius || 8)
                    color: Qt.alpha(root.presetPalette.surface0 || ThemeBackend.surface0, 0.85)
                    border.color: root.presetPalette.mauve || ThemeBackend.mauve
                    border.width: 2

                    Text {
                        anchors.centerIn: parent
                        text: (Widgets.WidgetRegistry.types[parent.type] || {
                        }).icon || ""
                        color: root.presetPalette.text || ThemeBackend.text
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: Math.min(parent.height * 0.5, 72)
                    }

                }

            }

            Rectangle {
                readonly property bool vertical: root.bar.position === "left" || root.bar.position === "right"

                width: vertical ? 40 : parent.width * Number(root.bar.width || 100) / 100
                height: vertical ? parent.height * Number(root.bar.width || 100) / 100 : 40
                x: root.bar.position === "right" ? parent.width - width : vertical ? 0 : (parent.width - width) / 2
                y: root.bar.position === "bottom" ? parent.height - height : vertical ? (parent.height - height) / 2 : 0
                color: root.presetPalette.surface0 || ThemeBackend.surface0
                radius: 12
                visible: root.bar.enabled !== false
            }

        }

    }

    ColumnLayout {
        x: root.rootObj.s(12)
        y: preview.y + preview.height + root.rootObj.s(8)
        width: parent.width - x * 2
        spacing: root.rootObj.s(6)

        Text {
            Layout.fillWidth: true
            text: root.profile.name
            elide: Text.ElideRight
            color: ThemeBackend.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.rootObj.s(12)
            font.bold: true
        }

        Text {
            text: root.profile.widgets ? "Settings + desktop widgets" : "Settings only"
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.rootObj.s(10)
        }

        RowLayout {
            Layout.fillWidth: true

            ClickButton {
                objectName: "apply-preset-" + root.profileIndex
                buttonText: "Apply"
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: ConfigProfiles.load(root.profileIndex)
            }

            Item {
                Layout.fillWidth: true
            }

            // a shareable copy in Downloads, without this machine's location and paths
            ClickButton {
                objectName: "export-preset-" + root.profileIndex
                buttonText: "Export"
                buttonIcon: "󰈇"
                accentColor: ThemeBackend.surface1
                textColor: ThemeBackend.text
                onClicked: ConfigProfiles.exportProfile(root.profileIndex)
            }

            DeleteButton {
                objectName: "remove-preset-" + root.profileIndex
                size: root.rootObj.s(28)
                onClicked: ConfigProfiles.remove(root.profileIndex)
            }

        }

    }

}
