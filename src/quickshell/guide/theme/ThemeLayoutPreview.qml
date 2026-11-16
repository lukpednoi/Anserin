import QtQuick
import "../../"
import "../../reusables"

Item {
    id: root
    property string appearance: "original"
    property string imageStyle: "rectangle"
    property string borderStyle: "theme"
    property string connectionStyle: "link"
    property string backgroundStyle: "panel"
    property string ringStyle: "original"
    readonly property bool orbit: appearance === "orbit"
    readonly property bool roundImage: orbit && imageStyle !== "rectangle"
    readonly property real unit: width / 880
    component Caption: Text {
        color: ThemeBackend.text
        font { family: ThemeBackend.fontFamily; pixelSize: Math.max(6, 16 * root.unit) }
        elide: Text.ElideRight
    }
    ImageBox {
        anchors.fill: parent
        visible: root.backgroundStyle === "transparent"
        source: visible ? ("file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png?preview=" + Date.now()) : ""
        cornerRadius: ThemeBackend.clampedBorderRadius
    }
    Rectangle { anchors.fill: parent; color: root.backgroundStyle === "transparent" ? "transparent" : ThemeBackend.base; radius: ThemeBackend.clampedBorderRadius }
    Loader {
        anchors.fill: parent
        active: root.backgroundStyle === "wifi"
        sourceComponent: OrbitBackdrop { unit: root.unit }
    }
    OrbitSignals {
        id: signals
        objectName: "theme-orbit-preview-signals"
        visible: root.orbit
        anchors.fill: parent
        active: root.orbit && root.visible
        style: root.connectionStyle
        networkStyle: root.ringStyle
        circleX: ring.x; circleY: ring.y; diameter: ring.width
        targets: [Qt.rect(lock.x,lock.y,lock.width,lock.height),Qt.rect(music.x,music.y,music.width,music.height),Qt.rect(general.x,general.y,general.width,general.height),Qt.rect(theme.x,theme.y,theme.width,theme.height)]
        unit: root.unit
        signalColor: ring.border.color
    }
    Rectangle {
        id: ring
        z: 1
        visible: root.orbit
        x: (root.width - width) / 2; y: (root.height - height) / 2
        width: 280 * root.unit; height: width; radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: root.borderStyle === "white" ? "#ffffff" : ThemeBackend.mauve
    }
    ImageBox {
        x: root.orbit ? (root.width - width) / 2 : 28 * root.unit
        y: root.orbit ? (root.height - height) / 2 : 24 * root.unit
        width: root.orbit ? (root.roundImage ? ring.width - (root.imageStyle === "bordered" ? 2 * (ring.border.width + 12 * root.unit) : 0) : 240 * root.unit) : 824 * root.unit
        height: root.orbit ? (root.roundImage ? width : 144 * root.unit) : 204 * root.unit
        source: "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png?preview=" + Date.now()
        cornerRadius: root.roundImage ? width / 2 : ThemeBackend.clampedBorderRadius * root.unit
    }
    Rectangle {
        id: lock
        transform: Translate { x: signals.driftX(0); y: signals.driftY(0) }
        visible: root.orbit
        width: 144 * root.unit; height: 41 * root.unit
        x: (root.width - width) / 2; y: ring.y - height - 44 * root.unit
        radius: ThemeBackend.clampedBorderRadius * root.unit; color: ThemeBackend.surface0
        Caption { anchors.centerIn: parent; text: "Lock screen" }
    }
    Rectangle {
        id: general
        transform: Translate { x: signals.driftX(2); y: signals.driftY(2) }
        visible: root.orbit
        width: 144 * root.unit; height: 41 * root.unit
        x: (root.width - width) / 2; y: ring.y + ring.height + 44 * root.unit
        radius: ThemeBackend.clampedBorderRadius * root.unit
        color: ThemeBackend.surface0
        Caption { anchors.centerIn: parent; width: parent.width * .9; text: "General"; horizontalAlignment: Text.AlignHCenter }
    }
    Rectangle {
        id: music
        transform: Translate { x: signals.driftX(1); y: signals.driftY(1) }
        visible: root.orbit
        width: 144 * root.unit; height: 41 * root.unit
        x: ring.x + ring.width + 44 * root.unit; y: ring.y + (ring.height-height)/2
        radius: ThemeBackend.clampedBorderRadius * root.unit; color: ThemeBackend.surface0
        Caption { anchors.centerIn: parent; text: AnserinMode.active ? "Pet" : "Music" }
    }
    Rectangle {
        id: theme
        transform: Translate { x: signals.driftX(3); y: signals.driftY(3) }
        visible: root.orbit
        width: 144 * root.unit; height: 41 * root.unit
        x: ring.x - width - 44 * root.unit; y: ring.y + (ring.height-height)/2
        radius: ThemeBackend.clampedBorderRadius * root.unit; color: ThemeBackend.surface0
        Caption { anchors.centerIn: parent; text: "Style" }
    }
    Repeater {
        model: root.orbit ? [] : ["Wallpaper", "Typography", "Corners", "Colors"]
        Rectangle {
            required property string modelData
            required property int index
            x: 28 * root.unit; y: (254 + index * 68) * root.unit
            width: 824 * root.unit; height: 54 * root.unit
            radius: ThemeBackend.clampedBorderRadius * root.unit
            color: ThemeBackend.surface0
            Caption { x: 18 * root.unit; anchors.verticalCenter: parent.verticalCenter; width: parent.width * .5; text: modelData }
            Rectangle { anchors.right: parent.right; anchors.rightMargin: 16 * root.unit; anchors.verticalCenter: parent.verticalCenter; width: 188 * root.unit; height: 24 * root.unit; radius: height / 3; color: ThemeBackend.mauve }
        }
    }
}
