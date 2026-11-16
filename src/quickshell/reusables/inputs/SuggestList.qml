import QtQuick
import QtQuick.Controls
import "../../"
import "../"

// Names offered under a text field while it is typed in (Location's Country / Province), in the Dropdown's list look:
// the same blurred card, rows, glass hover and open/close motion. Set `parent` to the field; `items` are the names,
// `shown` is whether the field is being typed in, `current` its text (a list that is only that name stays closed).
// A row clicked sends picked(name). The list never takes the keyboard from the field.
Popup {
    id: root
    property var items: []
    property bool shown: false
    property string current: ""
    property color dropdownColor: ThemeBackend.surface0
    property color textColor: ThemeBackend.text
    property color hoverColor: ThemeBackend.surface1
    property real cornerRadius: ThemeBackend.borderRadius
    property int fontPixelSize: 12
    property string fontFamily: ThemeBackend.fontFamily
    signal picked(string name)

    // stays while the pointer is on the list, so a click on a row lands even if the field lets go of the keyboard
    readonly property bool wanted: (shown || listHover.hovered) && items.length > 0
                                   && !(items.length === 1 && String(items[0]).toLowerCase() === current.trim().toLowerCase())
    onWantedChanged: wanted ? open() : close()
    onItemsChanged: if (wanted && !opened) open()

    y: parent ? parent.height + 6 : 0
    width: parent ? Math.max(parent.width, 180) : 180
    padding: 4
    margins: 0
    focus: false
    transformOrigin: Item.Top
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

    background: Rectangle {
        radius: Math.min(root.cornerRadius, 16)
        color: menuGlass.active ? "transparent" : root.dropdownColor
        WallpaperBlur { id: menuGlass; anchors.fill: parent; radius: parent.radius; tintColor: root.dropdownColor; tintAmount: 0.3 }
        layer.enabled: true
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200; easing.type: Easing.OutQuint }
        NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 200; easing.type: Easing.OutQuint }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 150; easing.type: Easing.InQuint }
        NumberAnimation { property: "scale"; from: 1.0; to: 0.9; duration: 150; easing.type: Easing.InQuint }
    }

    contentItem: ListView {
        id: listView
        implicitHeight: Math.min(contentHeight, 250)
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        spacing: 2
        model: root.items
        HoverHandler { id: listHover }

        property Item hoverItem: null
        GlassLens {
            id: hoverLens
            z: 0
            follow: listView.hoverItem
            radius: Math.max(2, Math.min(root.cornerRadius - 4, 16))
            backdropOverride: menuGlass
            followBackdropHover: false
            forceClear: true
            tintColor: root.textColor
            tintAmount: 0.14
            tintStrength: 1.0
            shadow: 0
            restPress: 0.25
            fastDuration: 180
            slowDuration: 180
            press: listView.hoverItem && listView.hoverItem.pressed ? 0.8 : 0
        }

        delegate: Rectangle {
            id: row
            required property string modelData
            width: listView.width
            height: 32
            radius: Math.max(2, Math.min(root.cornerRadius - 4, 16))
            color: (itemMa.pressed && !hoverLens.glassActive) ? Qt.darker(root.hoverColor, 1.1)
                 : (itemMa.containsMouse && !hoverLens.glassActive) ? root.hoverColor : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
            readonly property bool pressed: itemMa.pressed
            readonly property bool lensWanted: itemMa.containsMouse
            onLensWantedChanged: {
                if (lensWanted) listView.hoverItem = row;
                else if (listView.hoverItem === row) listView.hoverItem = null;
            }
            Component.onDestruction: if (listView.hoverItem === row) listView.hoverItem = null
            scale: itemMa.pressed ? 0.96 : ((itemMa.containsMouse && !hoverLens.glassActive) ? 1.02 : 1.0)
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                horizontalAlignment: I18n.textAlignment
                verticalAlignment: Text.AlignVCenter
                text: row.modelData
                font.family: root.fontFamily
                font.pixelSize: root.fontPixelSize
                color: root.textColor
                elide: Text.ElideRight
            }
            MouseArea {
                id: itemMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/dropdown/click.wav");
                    root.picked(row.modelData);
                    root.close();
                }
            }
        }
    }
}
