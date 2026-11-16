import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../"
import "../../reusables"

// The colour themes as preview cards (the theme's own colours; Matugen shows the wallpaper), the user's themes
// first; a click applies one, a custom one can be deleted. Shared by Theme (ThemeTab.qml) and the Control
// Center's board. `page` gives the themes and actions (ThemeLogic, or a page that forwards to it).
GridLayout {
    id: grid
    required property var page
    required property var rootObj
    readonly property real tileWidth: Math.max(rootObj.s(80), (width - 2 * rootObj.s(10)) / 3)
    columns: 3
    rowSpacing: rootObj.s(10)
    columnSpacing: rootObj.s(10)

    Repeater {
        model: grid.page.filteredUserPresets
        delegate: presetDelegateComp
    }

    Repeater {
        model: grid.page.filteredSystemPresets
        delegate: presetDelegateComp
    }

    Component {
        id: presetDelegateComp
        Loader {
            id: delegateLoader
            property var themeData: modelData
            property int itemIndex: index
            readonly property bool isDiv: modelData.isDivider === true

            asynchronous: false
            sourceComponent: isDiv ? dividerComp : tileComp

            Layout.columnSpan: isDiv ? 3 : 1
            Layout.fillWidth: true
            Layout.preferredWidth: isDiv ? grid.width : grid.tileWidth
            Layout.minimumWidth: isDiv ? 0 : grid.tileWidth
            Layout.preferredHeight: isDiv ? grid.rootObj.s(17) : grid.rootObj.s(44)
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        }
    }

    Component {
        id: dividerComp
        Item {
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.4)
            }
        }
    }

    Component {
        id: tileComp
        Rectangle {
            id: delegateContainer
            property var modelData: parent.themeData
            objectName: "theme-preset-" + modelData.name
            property int itemIndex: parent.itemIndex

            radius: ThemeBackend.borderRadius
            color: delegateContainer.baseC

            opacity: 0.0
            scale: (presetMouse.pressed ? 0.96 : (delegateContainer.isHovered ? 1.03 : 1.0)) * popScale

            property bool isSelected: grid.page.currentPreset === modelData.name
            property real flashOpacity: 0.0
            property real popScale: 1.0

            property color baseC: grid.page.getCardBase(modelData)
            property color textC: grid.page.getCardText(modelData)

            HoverHandler {
                id: delegateHover
            }

            property bool isHovered: delegateHover.hovered

            Component.onCompleted: {
                popInTimer.start();
            }

            Timer {
                id: popInTimer
                interval: Math.min(delegateContainer.itemIndex * 10, 200)
                onTriggered: delegateContainer.opacity = 1.0
            }

            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

            Loader {
                anchors.fill: parent
                active: modelData.isMatugen === true && grid.page.currentWallpaperPath !== ""
                sourceComponent: Item {
                    anchors.fill: parent

                    Rectangle {
                        id: matugenMask
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius
                        color: "black"
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        id: matugenContent
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Image {
                            id: matugenWall
                            anchors.fill: parent
                            source: grid.page.isWallpaperVideo ? ("file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png?rev=" + grid.page.wallpaperRevision) : ("file://" + grid.page.currentWallpaperPath + (grid.page.wallpaperRevision > 0 ? ("?rev=" + grid.page.wallpaperRevision) : ""))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            cache: true
                            sourceSize: Qt.size(Math.round(grid.rootObj.s(360)), Math.round(grid.rootObj.s(120)))
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: matugenWall
                            blurEnabled: true
                            blurMax: 4
                            blur: 0.4
                            colorizationColor: delegateContainer.baseC
                            colorization: 0.35
                            opacity: 0.85
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: ThemeBackend.borderRadius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.35; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.alpha(delegateContainer.baseC, 0.55) }
                            }
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: matugenContent
                        maskEnabled: true
                        maskSource: matugenMask
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: delegateContainer.textC
                opacity: delegateContainer.isSelected ? 0.15 : (delegateContainer.isHovered ? 0.08 : 0.0)
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: "#ffffff"
                opacity: delegateContainer.flashOpacity
                PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
            }

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: "transparent"
                border.color: delegateContainer.isSelected ? delegateContainer.textC : "transparent"
                border.width: delegateContainer.isSelected ? 2 : 0
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            SequentialAnimation {
                id: btnPopAnim
                NumberAnimation { target: delegateContainer; property: "popScale"; to: 1.04; duration: 100; easing.type: Easing.OutQuad }
                NumberAnimation { target: delegateContainer; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
            }

            MouseArea {
                id: presetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    btnPopAnim.start();
                    delegateContainer.flashOpacity = 0.15;
                    btnFlashAnim.start();
                    if (typeof Sounds !== "undefined") {
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                    }
                    grid.page.applyPreset(delegateContainer.modelData);
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: grid.rootObj.s(10)
                anchors.rightMargin: grid.rootObj.s(modelData.isCustom === true ? 6 : 10)
                spacing: grid.rootObj.s(6)

                Text {
                    text: modelData.name
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: grid.rootObj.s(11)
                    font.weight: delegateContainer.isSelected ? Font.Bold : Font.Medium
                    color: delegateContainer.textC
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: grid.rootObj.s(4)

                    Repeater {
                        model: grid.page.getCardDots(delegateContainer.modelData)
                        Rectangle {
                            width: grid.rootObj.s(8)
                            height: grid.rootObj.s(8)
                            radius: grid.rootObj.s(4)
                            color: modelData
                        }
                    }
                }

                DeleteButton {
                    visible: modelData.isCustom === true
                    size: grid.rootObj.s(24)
                    cornerRadius: Math.min(ThemeBackend.borderRadius, grid.rootObj.s(6))
                    iconFontSize: grid.rootObj.s(12)
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        grid.page.deleteCustomTheme(delegateContainer.modelData.name);
                    }
                }
            }
        }
    }
}
