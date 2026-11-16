import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"
import "../../reusables"
import "../../widgets"

// A screen's widget presets as preview cards (each a small copy of the screen with the preset's widgets on its
// wallpaper); a click applies it, a custom one can be deleted. Shared by the Widgets page (DisplayWidgetsTab.qml)
// and the Control Center's board. `logic` is a WidgetsLogic.
Column {
    id: presetsContainerCol
    required property var logic
    required property string monName
    required property var rootObj
    width: Math.max(0, cardLayout.width - presetsContainerCol.rootObj.s(24))
    spacing: presetsContainerCol.rootObj.s(10)

    readonly property real containerWidth: Math.max(0, width)
    readonly property int gridColumns: Math.max(3, Math.floor(containerWidth / presetsContainerCol.rootObj.s(180)))
    readonly property real gridColumnSpacing: presetsContainerCol.rootObj.s(8)
    readonly property real gridRowSpacing: presetsContainerCol.rootObj.s(8)
    readonly property real presetTileWidth: gridColumns > 0 ? Math.max(0, (containerWidth - gridColumnSpacing * (gridColumns - 1)) / gridColumns) : 0

    Component {
        id: presetCardComp

        Rectangle {
            id: presetCard
            required property var modelData
            required property int index

            property color accentColor: ThemeBackend.surface0
            property real popScale: 1.0
            property real flashOpacity: 0.0

            width: presetsContainerCol.presetTileWidth
            height: presetPreviewBox.height + presetsContainerCol.rootObj.s(28)
            radius: ThemeBackend.borderRadius
            clip: true

            color: presetMouse.pressed ? Qt.darker(presetCard.accentColor, 1.28) : (presetHover.hovered ? Qt.darker(presetCard.accentColor, 1.14) : presetCard.accentColor)
            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            scale: (presetMouse.pressed ? 0.985 : (presetHover.hovered ? 1.015 : 1.0)) * presetCard.popScale
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            HoverHandler {
                id: presetHover
            }

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: "#ffffff"
                opacity: presetCard.flashOpacity
                PropertyAnimation on opacity { id: flashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
            }

            SequentialAnimation {
                id: popAnim
                NumberAnimation { target: presetCard; property: "popScale"; to: 1.015; duration: 100; easing.type: Easing.OutQuad }
                NumberAnimation { target: presetCard; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
            }

            MouseArea {
                id: presetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    popAnim.start();
                    presetCard.flashOpacity = 0.15;
                    flashAnim.start();
                    if (typeof Sounds !== "undefined") {
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                    }
                    presetsContainerCol.logic.applyWidgetPreset(presetsContainerCol.monName, presetCard.modelData);
                }
            }

            Rectangle {
                id: presetPreviewBox
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                property var screenDims: presetsContainerCol.logic.getScreenDimensions(presetsContainerCol.monName)
                property real sWidth: screenDims.w > 0 ? screenDims.w : 1920
                property real sHeight: screenDims.h > 0 ? screenDims.h : 1080
                property real sAspect: (sWidth > 0 && sHeight > 0) ? (sWidth / sHeight) : (16 / 9)

                height: Math.round(width / sAspect)
                color: Qt.darker(presetCard.accentColor, 1.15)
                clip: true

                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: previewMask
                }

                Item {
                    id: previewMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        width: parent.width
                        height: parent.height + ThemeBackend.borderRadius * 2
                        radius: ThemeBackend.borderRadius
                        color: "white"
                    }
                }

                Item {
                    id: virtualScreenWrapper
                    anchors.fill: parent
                    clip: true

                    Item {
                        id: virtualScreen
                        width: presetPreviewBox.sWidth
                        height: presetPreviewBox.sHeight
                        transformOrigin: Item.TopLeft
                        scale: presetPreviewBox.width / presetPreviewBox.sWidth
                        enabled: false

                        Image {
                            id: presetWpImg
                            anchors.fill: parent
                            source: presetsContainerCol.logic.getWallpaperSource(presetsContainerCol.monName)
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            cache: true
                            asynchronous: false
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "#000000"
                            opacity: 0.25
                        }

                        Item {
                            id: presetWidgetsLayer
                            anchors.fill: parent

                            Repeater {
                                model: (presetCard.modelData && presetCard.modelData.widgets) ? presetCard.modelData.widgets : []
                                delegate: Item {
                                    id: miniWidgetContainer
                                    required property var modelData
                                    required property int index

                                    readonly property string typeStr: modelData.type || modelData.wType || "time"
                                    readonly property var defSize: (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultSize === "function")
                                        ? WidgetRegistry.defaultSize(typeStr)
                                        : ({ w: 250, h: 120 })

                                    readonly property string defVariant: (typeof WidgetRegistry !== "undefined" && typeof WidgetRegistry.defaultVariant === "function")
                                        ? WidgetRegistry.defaultVariant(typeStr)
                                        : "default"

                                    readonly property string variantStr: modelData.variant || modelData.wVariant || miniWidgetContainer.defVariant

                                    readonly property bool isStretchW: !!(modelData.stretchWidth || modelData.wStretchWidth)
                                    readonly property bool isStretchH: !!(modelData.stretchHeight || modelData.wStretchHeight)

                                    readonly property real rawW: modelData.w !== undefined ? modelData.w : (modelData.width !== undefined ? modelData.width : (modelData.wWidth !== undefined ? modelData.wWidth : defSize.w))
                                    readonly property real rawH: modelData.h !== undefined ? modelData.h : (modelData.height !== undefined ? modelData.height : (modelData.wHeight !== undefined ? modelData.wHeight : defSize.h))

                                    readonly property real resolvedW: isStretchW ? presetPreviewBox.sWidth : presetsContainerCol.logic.resolveDimension(rawW, presetPreviewBox.sWidth, defSize.w)
                                    readonly property real resolvedH: isStretchH ? presetPreviewBox.sHeight : presetsContainerCol.logic.resolveDimension(rawH, presetPreviewBox.sHeight, defSize.h)

                                    readonly property var resolvedPos: presetsContainerCol.logic.resolvePosition(modelData, presetPreviewBox.sWidth, presetPreviewBox.sHeight, resolvedW, resolvedH)

                                    x: isStretchW ? 0 : resolvedPos.x
                                    y: isStretchH ? 0 : resolvedPos.y
                                    width: resolvedW
                                    height: resolvedH
                                    opacity: modelData.opacity !== undefined ? modelData.opacity : 1.0
                                    rotation: modelData.rotation !== undefined ? modelData.rotation : 0

                                    Loader {
                                        id: widgetFaceLoader
                                        anchors.fill: parent
                                        asynchronous: false
                                        source: presetsContainerCol.logic.getFaceUrl(miniWidgetContainer.typeStr, miniWidgetContainer.variantStr)

                                        onLoaded: {
                                            if (item) {
                                                if ("variant" in item) item.variant = miniWidgetContainer.variantStr;
                                                if ("wVariant" in item) item.wVariant = miniWidgetContainer.variantStr;
                                                if ("type" in item) item.type = miniWidgetContainer.typeStr;
                                                if ("wType" in item) item.wType = miniWidgetContainer.typeStr;
                                                if ("wWidth" in item) item.wWidth = miniWidgetContainer.width;
                                                if ("wHeight" in item) item.wHeight = miniWidgetContainer.height;
                                                if ("imagePath" in item) item.imagePath = modelData.imagePath || modelData.wImagePath || "";
                                                if ("wImagePath" in item) item.wImagePath = modelData.imagePath || modelData.wImagePath || "";
                                                if ("previewMode" in item) item.previewMode = true;
                                                if ("screen" in item) item.screen = presetsContainerCol.logic.getScreen(presetsContainerCol.monName);
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: widgetFaceLoader.status === Loader.Error
                                        radius: ThemeBackend.borderRadius
                                        color: Qt.alpha(ThemeBackend.surface0, 0.72)
                                        border.width: 1
                                        border.color: Qt.alpha(ThemeBackend.mauve, 0.65)

                                        readonly property var typeInfo: (typeof WidgetRegistry !== "undefined" && WidgetRegistry.types && WidgetRegistry.types[miniWidgetContainer.typeStr]) ? WidgetRegistry.types[miniWidgetContainer.typeStr] : null

                                        Text {
                                            anchors.centerIn: parent
                                            text: (parent.typeInfo && parent.typeInfo.icon) ? parent.typeInfo.icon : "󰕰"
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: Math.max(12, Math.min(parent.width * 0.4, parent.height * 0.45))
                                            color: ThemeBackend.mauve
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.alpha(ThemeBackend.surface2, 0.3)
                }
            }

            Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.top: presetPreviewBox.bottom

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: presetsContainerCol.rootObj.s(8)
                    anchors.rightMargin: presetsContainerCol.rootObj.s(8)
                    spacing: presetsContainerCol.rootObj.s(4)

                    Text {
                        property int widgetCount: (presetCard.modelData && presetCard.modelData.widgets) ? presetCard.modelData.widgets.length : 0
                        property string rawName: (presetCard.modelData && presetCard.modelData.name) ? presetCard.modelData.name : ((presetCard.modelData && presetCard.modelData.id) ? presetCard.modelData.id : "")
                        text: (rawName ? I18n.t(rawName, rawName) : "") + " (" + widgetCount + ")"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: presetsContainerCol.rootObj.s(12)
                        font.bold: true
                        color: ThemeBackend.text
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    DeleteButton {
                        visible: presetCard.modelData.isCustom === true || presetCard.modelData.category === "user"
                        size: presetsContainerCol.rootObj.s(22)
                        cornerRadius: Math.min(ThemeBackend.borderRadius, presetsContainerCol.rootObj.s(6))
                        iconFontSize: presetsContainerCol.rootObj.s(11)
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: {
                            presetsContainerCol.logic.deleteCustomPreset(presetCard.modelData.name || presetCard.modelData.id);
                        }
                    }
                }
            }
        }
    }

    Grid {
        id: userPresetsGrid
        width: parent.width
        columns: presetsContainerCol.gridColumns
        rowSpacing: presetsContainerCol.gridRowSpacing
        columnSpacing: presetsContainerCol.gridColumnSpacing
        visible: presetsContainerCol.logic.userPresets.length > 0

        Repeater {
            model: presetsContainerCol.logic.userPresets
            delegate: presetCardComp
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.alpha(ThemeBackend.surface2, 0.35)
        visible: presetsContainerCol.logic.userPresets.length > 0 && presetsContainerCol.logic.systemPresets.length > 0
    }

    Grid {
        id: systemPresetsGrid
        width: parent.width
        columns: presetsContainerCol.gridColumns
        rowSpacing: presetsContainerCol.gridRowSpacing
        columnSpacing: presetsContainerCol.gridColumnSpacing
        visible: presetsContainerCol.logic.systemPresets.length > 0

        Repeater {
            model: presetsContainerCol.logic.systemPresets
            delegate: presetCardComp
        }
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Qt.alpha(ThemeBackend.surface2, 0.35)
    }
}
