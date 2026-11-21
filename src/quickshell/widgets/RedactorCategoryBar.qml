import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

// Open Redactor's bottom bar. The first page lists the widget groups (Clocks, System, Media, Weather, Other);
// picking one slides to its widgets, and picking a widget shows its styles in the preview panel (typeId).
// Grid, Clear and Done stay at the right end on both pages.
Item {
    id: root

    property var redactor: null
    property string categoryId: ""
    property string typeId: ""
    signal doneClicked()

    function s(v) { return Scaler.s(v); }

    readonly property real pad: s(14)
    readonly property real tileGap: s(10)
    // the tiles are 70% of the bar's inner height, centred in it
    readonly property real tileHeight: Math.round(Math.max(s(64), height - pad * 2) * 0.7)
    readonly property real tileWidth: Math.round(tileHeight * 1.15)

    // Same grouping as WidgetPicker: the registry's categories, then anything left over under Other.
    readonly property var sections: {
        let types = WidgetRegistry.types;
        let placed = {};
        let out = [];
        let entry = id => ({ id: id, icon: types[id].icon || "", name: types[id].name || id });
        for (let cat of WidgetRegistry.categories) {
            let items = Object.keys(types).filter(id => WidgetRegistry.categoryFor(id) === cat.id).map(entry);
            items.forEach(it => placed[it.id] = true);
            if (items.length > 0) out.push({ id: cat.id, name: cat.name, icon: cat.icon, items: items });
        }
        let rest = Object.keys(types).filter(id => !placed[id]).map(entry);
        if (rest.length > 0) {
            let other = out.find(sec => sec.id === "other");
            if (other) other.items = other.items.concat(rest);
            else out.push({ id: "other", name: I18n.t("widgets.redactor.category.other", "Other"), icon: String.fromCodePoint(0xF0431), items: rest });
        }
        return out;
    }

    readonly property var currentSection: sections.find(sec => sec.id === root.categoryId) || null

    function openCategory(id) {
        root.typeId = "";
        root.categoryId = id;
    }

    // Steps back one page; false when already on the groups page (Escape then closes the redactor).
    function back() {
        if (root.categoryId === "") return false;
        root.typeId = "";
        root.categoryId = "";
        return true;
    }

    // 0 = groups page, 1 = a group's widgets
    property real page: root.categoryId === "" ? 0 : 1
    Behavior on page { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: barGlass.active ? "transparent" : ThemeBackend.base
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.surface1, 0.6)

        WallpaperBlur {
            id: barGlass
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

    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property bool selected: false
        signal activated()

        width: root.tileWidth
        height: root.tileHeight
        radius: ThemeBackend.borderRadius
        color: tile.selected ? ThemeBackend.mauve : (tileMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
        Behavior on color { ColorAnimation { duration: 140 } }
        scale: tileMa.pressed ? 0.95 : (tileMa.containsMouse ? 1.03 : 1.0)
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - root.s(12)
            spacing: root.s(4)

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: tile.icon
                font.family: ThemeBackend.iconFont
                font.pixelSize: Math.round(root.tileHeight * 0.34)
                color: tile.selected ? ThemeBackend.crust : ThemeBackend.mauve
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: tile.title
                elide: Text.ElideRight
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(13)
                font.bold: true
                color: tile.selected ? ThemeBackend.crust : ThemeBackend.text
            }
        }

        MouseArea {
            id: tileMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                Sounds.playSfx("reusables/clickbutton/click.wav");
                tile.activated();
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.pad

        Item {
            id: pages
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Groups page
            Flickable {
                id: groupFlick
                width: pages.width
                height: pages.height
                x: -root.page * s(60)
                opacity: Math.max(0, 1 - root.page)
                visible: opacity > 0.01
                enabled: root.categoryId === ""
                contentWidth: groupRow.width
                contentHeight: height
                interactive: contentWidth > width
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: groupRow
                    y: Math.round((groupFlick.height - root.tileHeight) / 2)
                    spacing: root.tileGap
                    Repeater {
                        model: root.sections
                        delegate: Tile {
                            required property var modelData
                            icon: modelData.icon
                            title: modelData.name
                            onActivated: root.openCategory(modelData.id)
                        }
                    }
                }
            }

            // A group's widgets, with a back tile first
            Flickable {
                id: typeFlick
                width: pages.width
                height: pages.height
                x: (1 - root.page) * s(60)
                opacity: Math.max(0, Math.min(1, root.page))
                visible: opacity > 0.01
                enabled: root.categoryId !== ""
                contentWidth: typeRow.width
                contentHeight: height
                interactive: contentWidth > width
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: typeRow
                    y: Math.round((typeFlick.height - root.tileHeight) / 2)
                    spacing: root.tileGap

                    Tile {
                        width: Math.round(root.tileHeight * 0.7)
                        icon: "󰁍"
                        title: root.currentSection ? root.currentSection.name : ""
                        onActivated: root.back()
                    }

                    Repeater {
                        model: root.currentSection ? root.currentSection.items : []
                        delegate: Tile {
                            required property var modelData
                            icon: modelData.icon
                            title: modelData.name
                            selected: root.typeId === modelData.id
                            onActivated: root.typeId = modelData.id
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: s(96)
            Layout.maximumWidth: s(96)
            spacing: s(8)

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: s(8)

                IconButton {
                    size: s(40)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰕰"
                    iconFontSize: s(16)
                    accentColor: root.redactor && root.redactor.gridEnabled ? ThemeBackend.mauve : ThemeBackend.surface0
                    textColor: root.redactor && root.redactor.gridEnabled ? ThemeBackend.crust : ThemeBackend.text
                    onClicked: {
                        if (!root.redactor) return;
                        let turningOn = !root.redactor.gridEnabled;
                        root.redactor.gridEnabled = turningOn;
                        if (turningOn) root.redactor.snapAllWidgetsToGrid();
                    }
                }

                IconButton {
                    size: s(40)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰑐"
                    iconFontSize: s(16)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    enabled: root.redactor && root.redactor.activeWidgetsModel ? root.redactor.activeWidgetsModel.count > 0 : false
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.redactor.removeAllWidgets()
                }
            }

            ClickButton {
                Layout.fillWidth: true
                implicitHeight: s(40)
                horizontalPadding: s(14)
                cornerRadius: ThemeBackend.borderRadius
                buttonText: I18n.t("widgets.redactor.done")
                textFontSize: s(13)
                accentColor: ThemeBackend.mauve
                textColor: ThemeBackend.crust
                onClicked: root.doneClicked()
            }
        }
    }
}
