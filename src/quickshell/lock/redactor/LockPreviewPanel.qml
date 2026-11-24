import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/expressive"
import "../../widgets"

// Lock Screen Redactor's left preview panel: hidden until an element/widget is clicked in the bottom bar.
// Every click spawns a new item onto the lock stage (duplicates allowed; singleton password switches style).
Item {
    id: root

    property var selectedProxy: null
    property string scope: "screen"
    property string typeId: ""
    signal closeRequested()
    signal variantPicked(string typeId, string variantId)
    signal addRequested(string typeId, string variantId)

    function s(v) { return Scaler.s(v); }

    property bool facesReady: false
    Timer {
        id: faceDelay
        interval: 190
        repeat: false
        onTriggered: root.facesReady = true
    }
    onTypeIdChanged: {
        facesReady = false;
        if (typeId !== "") faceDelay.restart();
        else faceDelay.stop();
    }

    readonly property bool hasType: root.typeId !== "" && LockElementRegistry.hasType(root.typeId)
    readonly property bool isSingleton: root.hasType && !LockElementRegistry.isDeletable(root.typeId)
    readonly property var variants: root.hasType ? LockElementRegistry.variantList(root.typeId) : []
    readonly property var defSize: {
        let d = root.hasType ? LockElementRegistry.defaultSize(root.typeId) : { w: 200, h: 120 };
        return { w: d.w > 0 ? d.w : 180, h: d.h > 0 ? d.h : 52 };
    }
    readonly property real pad: s(16)
    readonly property real gap: s(12)
    readonly property real cellWidth: Math.floor((width - pad * 2 - gap) / 2)
    readonly property real boxHeight: Math.round(cellWidth * 0.72)

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: panelGlass.active ? "transparent" : ThemeBackend.base
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.surface1, 0.65)

        WallpaperBlur {
            id: panelGlass
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => wheel.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: s(12)
        visible: root.hasType

        RowLayout {
            Layout.fillWidth: true
            spacing: s(8)

            Text {
                text: root.hasType ? LockElementRegistry.typeIcon(root.typeId) : ""
                font.family: ThemeBackend.iconFont
                font.pixelSize: s(22)
                color: ThemeBackend.mauve
            }
            Text {
                Layout.fillWidth: true
                text: root.hasType ? LockElementRegistry.typeName(root.typeId) : ""
                elide: Text.ElideRight
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(17)
                font.bold: true
                color: ThemeBackend.text
            }
            Rectangle {
                ExSpring {
                    id: closeSc
                    token: "spatialFast"
                    target: closeMa.pressed ? 0.86 : (closeMa.containsMouse ? 1.08 : 1.0)
                }
                scale: closeSc.value
                width: s(28)
                height: s(28)
                radius: closeMa.pressed ? s(8) : width / 2
                Behavior on radius {
                    SpringAnimation {
                        spring: ExMotion.qtSpring("spatialFast")
                        damping: ExMotion.qtDamping("spatialFast")
                        epsilon: 0.2
                    }
                }
                color: closeMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                Behavior on color { ColorAnimation { duration: ExMotion.fast } }
                Text {
                    anchors.centerIn: parent
                    text: "󰅖"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: s(14)
                    color: closeMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                        root.closeRequested();
                    }
                }
            }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: grid.height
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            WheelHandler {
                acceptedDevices: PointerDevice.AllDevices
                onWheel: (ev) => {
                    let maxY = Math.max(0, flick.contentHeight - flick.height);
                    flick.contentY = Math.max(0, Math.min(maxY, flick.contentY - ev.angleDelta.y * 0.65));
                    ev.accepted = true;
                }
            }

            Grid {
                id: grid
                columns: 2
                spacing: root.gap

                Repeater {
                    model: root.hasType ? root.variants : []

                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index

                        width: root.cellWidth
                        height: root.boxHeight + s(30)

                        opacity: 0
                        scale: 0.86
                        SequentialAnimation {
                            running: true
                            PauseAnimation { duration: Math.min(card.index, 10) * 35 }
                            ParallelAnimation {
                                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 190; easing.type: Easing.OutCubic }
                                NumberAnimation { target: card; property: "scale"; to: 1; duration: 400; easing.type: Easing.OutBack; easing.overshoot: 1.7 }
                            }
                        }

                        ExSpring {
                            id: cardSc
                            token: "spatialFast"
                            target: cardMa.pressed ? 0.92 : (cardMa.containsMouse ? 1.035 : 1.0)
                        }

                        Rectangle {
                            id: box
                            width: parent.width
                            height: root.boxHeight
                            radius: cardMa.pressed ? s(10) : ThemeBackend.borderRadius
                            Behavior on radius {
                                SpringAnimation {
                                    spring: ExMotion.qtSpring("spatialFast")
                                    damping: ExMotion.qtDamping("spatialFast")
                                    epsilon: 0.2
                                }
                            }
                            color: cardMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                            Behavior on color { ColorAnimation { duration: ExMotion.fast } }
                            border.width: cardMa.containsMouse ? 1 : 0
                            border.color: Qt.alpha(ThemeBackend.mauve, 0.55)
                            clip: true
                            scale: cardSc.value

                            Item {
                                id: faceHolder
                                readonly property real fit: Math.min((box.width - s(16)) / Math.max(1, root.defSize.w), (box.height - s(16)) / Math.max(1, root.defSize.h))
                                width: root.defSize.w
                                height: root.defSize.h
                                anchors.centerIn: parent
                                scale: fit
                                enabled: false

                                Loader {
                                    id: face
                                    anchors.fill: parent
                                    asynchronous: true
                                    active: root.facesReady && root.typeId !== ""
                                    opacity: status === Loader.Ready ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                    source: active ? LockElementRegistry.faceSource(root.typeId, card.modelData.id) : ""
                                    onLoaded: {
                                        if (!item) return;
                                        if ("variant" in item) item.variant = card.modelData.id;
                                        if ("wVariant" in item) item.wVariant = card.modelData.id;
                                        if ("wWidth" in item) item.wWidth = root.defSize.w;
                                        if ("wHeight" in item) item.wHeight = root.defSize.h;
                                        if ("previewMode" in item) item.previewMode = true;
                                        if ("isPreview" in item) item.isPreview = true;
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: face.status !== Loader.Ready
                                text: root.hasType ? LockElementRegistry.typeIcon(root.typeId) : "󰕰"
                                font.family: ThemeBackend.iconFont
                                font.pixelSize: Math.round(box.height * 0.35)
                                color: Qt.alpha(ThemeBackend.mauve, 0.7)
                            }
                        }

                        Text {
                            anchors.top: box.bottom
                            anchors.topMargin: s(8)
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: card.modelData.name || card.modelData.label || card.modelData.id
                            elide: Text.ElideRight
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: s(13)
                            color: cardMa.containsMouse ? ThemeBackend.mauve : ThemeBackend.text
                        }

                        MouseArea {
                            id: cardMa
                            anchors.fill: box
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Sounds.playSfx("reusables/clickbutton/click.wav");
                                if (root.isSingleton) root.variantPicked(root.typeId, card.modelData.id);
                                else root.addRequested(root.typeId, card.modelData.id);
                            }
                            onWheel: (w) => { w.accepted = false; }
                        }
                    }
                }
            }
        }
    }
}
