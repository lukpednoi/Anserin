import QtQuick
import "../../"

// The colour squares of Select Wallpaper (the picker's colour row when it is embedded, and the left panel's Wallpaper
// page): one square per colour group, spread over the row's width; the current one a little bigger with a light rim.
// `colors` are { name, hex } (Select's groups unless given), `scaler` the host's s(); a click sends picked(name).
Row {
    id: row
    // Select Wallpaper's colour groups (WallpaperPicker.filterData, the indexer's buckets), in its order
    readonly property var groups: [
        { name: "Red", hex: "#FF4500" }, { name: "Orange", hex: "#FFA500" }, { name: "Yellow", hex: "#FFD700" },
        { name: "Green", hex: "#32CD32" }, { name: "Blue", hex: "#1E90FF" }, { name: "Purple", hex: "#8A2BE2" },
        { name: "Pink", hex: "#FF69B4" }, { name: "Brown", hex: "#8B5A2B" }, { name: "Black", hex: "#181818" },
        { name: "Gray", hex: "#A9A9A9" }, { name: "White", hex: "#F0F0F0" }
    ]
    property var colors: groups
    property string current: ""
    property bool active: true
    property var scaler: function(v) { return v; }
    signal picked(string name)

    readonly property real cell: scaler(34)
    height: cell
    spacing: Math.max(0, (width - colors.length * cell) / Math.max(1, colors.length - 1))
    Repeater {
        model: row.colors
        delegate: Rectangle {
            id: swatch
            required property var modelData
            objectName: "wallpaper-filter-" + modelData.name
            width: row.cell; height: row.cell
            radius: ThemeBackend.borderRadius
            color: modelData.hex
            border.color: row.current === modelData.name ? ThemeBackend.text : ThemeBackend.surface1
            border.width: row.current === modelData.name ? row.scaler(1.5) : 1
            scale: row.current === modelData.name ? 1.05 : (swatchMouse.containsMouse ? 1.03 : 1.0)
            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuint } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            MouseArea {
                id: swatchMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: row.active
                cursorShape: Qt.PointingHandCursor
                onClicked: row.picked(swatch.modelData.name)
            }
        }
    }
}
