import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

// Open Redactor's left panel: the styles of the widget picked in the bottom bar, two per row, each drawn
// live. Clicking one puts that widget (in that style) on the desktop. The faces load only for the picked
// widget and are released when another widget is picked or the redactor closes.
Item {
    id: root

    property var redactor: null
    property string typeId: ""

    function s(v) { return Scaler.s(v); }

    readonly property var typeDef: root.typeId !== "" ? (WidgetRegistry.types[root.typeId] || null) : null
    readonly property var variants: root.typeDef ? WidgetRegistry.variantList(root.typeId) : []
    readonly property var defSize: WidgetRegistry.defaultSize(root.typeId)
    readonly property real pad: s(16)
    readonly property real gap: s(12)
    readonly property real cellWidth: Math.floor((width - pad * 2 - gap) / 2)
    readonly property real boxHeight: Math.round(cellWidth * 0.72)

    // the widget selected on the desktop, so its style can be marked
    readonly property var selectedRow: {
        let r = root.redactor;
        if (!r || !r.selectedId || !r.activeWidgetsModel) return null;
        for (let i = 0; i < r.activeWidgetsModel.count; i++) {
            let row = r.activeWidgetsModel.get(i);
            if (String(row.wId) === String(r.selectedId)) return { type: row.wType, variant: row.wVariant };
        }
        return null;
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: panelGlass.active ? "transparent" : ThemeBackend.base
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.surface1, 0.6)

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

    // Nothing picked yet
    ColumnLayout {
        anchors.centerIn: parent
        width: parent.width - root.pad * 2
        spacing: s(8)
        visible: root.typeDef === null

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "󰕰"
            font.family: ThemeBackend.iconFont
            font.pixelSize: s(40)
            color: Qt.alpha(ThemeBackend.mauve, 0.8)
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: I18n.t("widgets.redactor.pick_hint", "Pick a group below, then a widget, to see its styles here.")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: s(14)
            color: ThemeBackend.subtext0
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: s(12)
        visible: root.typeDef !== null

        RowLayout {
            Layout.fillWidth: true
            spacing: s(10)

            Text {
                text: root.typeDef ? (root.typeDef.icon || "") : ""
                font.family: ThemeBackend.iconFont
                font.pixelSize: s(22)
                color: ThemeBackend.mauve
            }
            Text {
                Layout.fillWidth: true
                text: root.typeDef ? (root.typeDef.name || root.typeId) : ""
                elide: Text.ElideRight
                font.family: ThemeBackend.fontFamily
                font.pixelSize: s(18)
                font.bold: true
                color: ThemeBackend.text
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

            Grid {
                id: grid
                columns: 2
                spacing: root.gap

                Repeater {
                    // re-created when the picked widget changes, so the old faces are released
                    model: root.typeDef ? root.variants : []

                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        readonly property bool current: root.selectedRow !== null && root.selectedRow.type === root.typeId && root.selectedRow.variant === modelData.id

                        width: root.cellWidth
                        height: root.boxHeight + s(30)

                        // pops in one after another when the widget is picked
                        opacity: 0
                        scale: 0.9
                        SequentialAnimation {
                            running: true
                            PauseAnimation { duration: card.index * 45 }
                            ParallelAnimation {
                                NumberAnimation { target: card; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
                                NumberAnimation { target: card; property: "scale"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
                            }
                        }

                        Rectangle {
                            id: box
                            width: parent.width
                            height: root.boxHeight
                            radius: ThemeBackend.borderRadius
                            color: cardMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                            Behavior on color { ColorAnimation { duration: 140 } }
                            border.width: card.current ? s(2) : 0
                            border.color: ThemeBackend.mauve
                            clip: true
                            scale: cardMa.pressed ? 0.96 : (cardMa.containsMouse ? 1.02 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

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
                                    source: WidgetRegistry.faceFile(root.typeId, card.modelData.id)
                                    onLoaded: {
                                        if (!item) return;
                                        if ("variant" in item) item.variant = card.modelData.id;
                                        if ("wVariant" in item) item.wVariant = card.modelData.id;
                                        if ("type" in item) item.type = root.typeId;
                                        if ("wType" in item) item.wType = root.typeId;
                                        if ("wWidth" in item) item.wWidth = root.defSize.w;
                                        if ("wHeight" in item) item.wHeight = root.defSize.h;
                                        if ("previewMode" in item) item.previewMode = true;
                                    }
                                }
                            }

                            // still loading, or a face that cannot be drawn without a file (Image)
                            Text {
                                anchors.centerIn: parent
                                visible: face.status !== Loader.Ready
                                text: root.typeDef ? (root.typeDef.icon || "󰕰") : ""
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
                            text: card.modelData.label || card.modelData.id
                            elide: Text.ElideRight
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: s(13)
                            font.bold: card.current
                            color: card.current ? ThemeBackend.mauve : ThemeBackend.text
                        }

                        MouseArea {
                            id: cardMa
                            anchors.fill: box
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Sounds.playSfx("reusables/clickbutton/click.wav");
                                if (root.redactor) root.redactor.addWidget(root.typeId, card.modelData.id);
                            }
                        }
                    }
                }
            }
        }
    }
}
