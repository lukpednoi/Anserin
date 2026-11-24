import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"
import "../reusables/expressive"

// Open Redactor's bottom bar: width matches the shrunk desktop canvas, smooth wheel scrolling,
// bouncy expressive springs on tiles & page transitions, plus Undo / Redo / Grid / Clear / Done.
Item {
    id: root

    property var redactor: null
    property string categoryId: ""
    property string typeId: ""
    signal doneClicked()

    function s(v) { return Scaler.s(v); }

    readonly property real pad: s(10)
    readonly property real tileGap: s(8)
    readonly property real tileHeight: Math.round(Math.max(s(56), height - pad * 2) * 0.78)
    readonly property real tileWidth: Math.round(tileHeight * 1.18)

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

    function back() {
        if (root.categoryId === "") return false;
        root.typeId = "";
        root.categoryId = "";
        return true;
    }

    property real page: root.categoryId === "" ? 0 : 1
    Behavior on page {
        SpringAnimation {
            spring: ExMotion.qtSpring("spatialDefault")
            damping: ExMotion.qtDamping("spatialDefault") * 0.74
            epsilon: 0.001
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.borderRadius
        color: barGlass.active ? "transparent" : ThemeBackend.base
        border.width: 1
        border.color: Qt.alpha(ThemeBackend.surface1, 0.65)

        WallpaperBlur {
            id: barGlass
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onWheel: (wheel) => {
                let target = root.categoryId === "" ? groupFlick : typeFlick;
                if (!target) { wheel.accepted = true; return; }
                let d = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                let maxX = Math.max(0, target.contentWidth - target.width);
                if (maxX > 0) target.contentX = Math.max(0, Math.min(maxX, target.contentX - d * 0.75));
                wheel.accepted = true;
            }
        }
    }

    component Tile: Rectangle {
        id: tile
        property string icon: ""
        property string title: ""
        property bool selected: false
        signal activated()

        ExSpring {
            id: tileSc
            token: "spatialFast"
            target: tileMa.pressed ? 0.90 : (tileMa.containsMouse ? 1.055 : 1.0)
        }

        width: root.tileWidth
        height: root.tileHeight
        radius: tileMa.pressed ? root.s(8) : (tile.selected ? root.s(15) : Math.max(8, ThemeBackend.borderRadius - 2))
        Behavior on radius {
            SpringAnimation {
                spring: ExMotion.qtSpring("spatialFast")
                damping: ExMotion.qtDamping("spatialFast")
                epsilon: 0.2
            }
        }
        color: tile.selected ? ThemeBackend.mauve : (tileMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
        Behavior on color { ColorAnimation { duration: ExMotion.fast } }
        scale: tileSc.value

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - root.s(8)
            spacing: root.s(3)

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
                font.pixelSize: root.s(11)
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
            onWheel: (wheel) => { wheel.accepted = false; }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.s(10)

        Item {
            id: pages
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Flickable {
                id: groupFlick
                width: pages.width
                height: pages.height
                x: -root.page * s(48)
                opacity: Math.max(0, Math.min(1, 1 - root.page))
                visible: opacity > 0.01
                enabled: root.categoryId === ""
                contentWidth: groupRow.width
                contentHeight: height
                interactive: contentWidth > width
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                Behavior on contentX { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                WheelHandler {
                    acceptedDevices: PointerDevice.AllDevices
                    onWheel: (event) => {
                        let d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        let maxX = Math.max(0, groupFlick.contentWidth - groupFlick.width);
                        groupFlick.contentX = Math.max(0, Math.min(maxX, groupFlick.contentX - d * 0.75));
                        event.accepted = true;
                    }
                }

                Row {
                    id: groupRow
                    height: root.tileHeight
                    y: Math.round((groupFlick.height - height) / 2)
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

            Flickable {
                id: typeFlick
                width: pages.width
                height: pages.height
                x: (1 - root.page) * s(48)
                opacity: Math.max(0, Math.min(1, root.page))
                visible: opacity > 0.01
                enabled: root.categoryId !== ""
                contentWidth: typeRow.width
                contentHeight: height
                interactive: contentWidth > width
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                Behavior on contentX { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                WheelHandler {
                    acceptedDevices: PointerDevice.AllDevices
                    onWheel: (event) => {
                        let d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        let maxX = Math.max(0, typeFlick.contentWidth - typeFlick.width);
                        typeFlick.contentX = Math.max(0, Math.min(maxX, typeFlick.contentX - d * 0.75));
                        event.accepted = true;
                    }
                }

                Row {
                    id: typeRow
                    height: root.tileHeight
                    y: Math.round((typeFlick.height - height) / 2)
                    spacing: root.tileGap

                    Tile {
                        width: Math.round(root.tileHeight * 0.78)
                        icon: "󰁍"
                        title: I18n.t("common.back", "Back")
                        onActivated: root.back()
                    }

                    Repeater {
                        model: root.currentSection ? root.currentSection.items : []
                        delegate: Tile {
                            required property var modelData
                            icon: modelData.icon
                            title: modelData.name
                            selected: root.typeId === modelData.id
                            onActivated: root.typeId = (root.typeId === modelData.id ? "" : modelData.id)
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: root.s(6)
            Layout.bottomMargin: root.s(6)
            color: Qt.alpha(ThemeBackend.surface1, 0.7)
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: false
            Layout.preferredWidth: actionsRow.implicitWidth
            spacing: root.s(6)

            RowLayout {
                id: actionsRow
                spacing: root.s(5)

                IconButton {
                    size: root.s(30)
                    cornerRadius: Math.max(6, ThemeBackend.borderRadius - 4)
                    buttonIcon: "󰕌"
                    iconFontSize: root.s(15)
                    accentColor: ThemeBackend.surface0
                    textColor: (root.redactor && root.redactor.canUndo) ? ThemeBackend.text : ThemeBackend.overlay0
                    enabled: !!(root.redactor && root.redactor.canUndo)
                    onClicked: if (root.redactor) root.redactor.undo()
                }
                IconButton {
                    size: root.s(30)
                    cornerRadius: Math.max(6, ThemeBackend.borderRadius - 4)
                    buttonIcon: "󰑎"
                    iconFontSize: root.s(15)
                    accentColor: ThemeBackend.surface0
                    textColor: (root.redactor && root.redactor.canRedo) ? ThemeBackend.text : ThemeBackend.overlay0
                    enabled: !!(root.redactor && root.redactor.canRedo)
                    onClicked: if (root.redactor) root.redactor.redo()
                }
                IconButton {
                    size: root.s(30)
                    cornerRadius: Math.max(6, ThemeBackend.borderRadius - 4)
                    buttonIcon: "󰋁"
                    iconFontSize: root.s(15)
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
                    size: root.s(30)
                    cornerRadius: Math.max(6, ThemeBackend.borderRadius - 4)
                    buttonIcon: "󰑐"
                    iconFontSize: root.s(15)
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    enabled: root.redactor && root.redactor.activeWidgetsModel ? root.redactor.activeWidgetsModel.count > 0 : false
                    opacity: enabled ? 1 : 0.4
                    onClicked: root.redactor.removeAllWidgets()
                }
            }

            Rectangle {
                id: doneBtn
                ExSpring {
                    id: doneSc
                    token: "spatialFast"
                    target: doneMa.pressed ? 0.92 : (doneMa.containsMouse ? 1.04 : 1.0)
                }
                Layout.fillWidth: true
                Layout.preferredHeight: root.s(32)
                scale: doneSc.value
                radius: doneMa.pressed ? root.s(7) : Math.max(8, ThemeBackend.borderRadius - 2)
                Behavior on radius {
                    SpringAnimation {
                        spring: ExMotion.qtSpring("spatialFast")
                        damping: ExMotion.qtDamping("spatialFast")
                        epsilon: 0.2
                    }
                }
                color: doneMa.pressed ? Qt.darker(ThemeBackend.mauve, 1.12) : (doneMa.containsMouse ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve)
                Behavior on color { ColorAnimation { duration: ExMotion.fast } }

                Text {
                    anchors.centerIn: parent
                    text: I18n.t("widgets.redactor.done", "Done")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(12)
                    font.bold: true
                    color: ThemeBackend.crust
                }

                MouseArea {
                    id: doneMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                        root.doneClicked();
                    }
                }
            }
        }
    }
}
