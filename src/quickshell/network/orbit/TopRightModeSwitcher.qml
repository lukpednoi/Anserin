import QtQuick
import "../../"
import "."

/**
 * Compact top-right capsule switcher:
 *   - [1/2]: 2 cells [ Wi-Fi | BT ]
 *   - [2/2]: 4 equal-sized cells [ Power | Wi-Fi | BT | Fullscreen ]
 */
Rectangle {
    id: switcher

    required property NetworkStore store
    property color accentColor: ThemeBackend.mauve
    property bool showPowerCell: false
    property bool customPowerHandler: false
    property bool showFullscreenCell: false
    property bool fullscreenActive: false

    signal powerClicked()
    signal fullscreenClicked()

    readonly property var modes: [
        { id: "wifi" },
        { id: "bt" }
    ]
    readonly property int activeIndex: store.activeMode === "wifi" ? 0 : 1
    readonly property real cellW: 42
    readonly property int totalCells: (showPowerCell ? 1 : 0) + 2 + (showFullscreenCell ? 1 : 0)

    implicitWidth: 8 + totalCells * cellW
    implicitHeight: 38
    radius: 19
    clip: true
    color: Qt.rgba(ThemeBackend.mantle.r, ThemeBackend.mantle.g, ThemeBackend.mantle.b, 0.78)
    border.width: 1
    border.color: Qt.alpha(ThemeBackend.surface2, 0.65)

    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    Item {
        anchors.fill: parent
        anchors.margins: 4

        Rectangle {
            x: ((switcher.showPowerCell ? 1 : 0) + switcher.activeIndex) * switcher.cellW
            y: 0
            width: switcher.cellW
            height: parent.height
            radius: 15
            opacity: switcher.store.currentPower ? 1.0 : 0.35
            color: Qt.alpha(switcher.accentColor, 0.2)
            border.width: 1
            border.color: Qt.alpha(switcher.accentColor, 0.55)

            Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 0.9 } }
            Behavior on opacity { NumberAnimation { duration: 180 } }
        }

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            // Equal-sized Power On/Off cell right next to Wi-Fi (shown in [2/2] Gargantua UI)
            Item {
                id: pwrCell
                width: switcher.showPowerCell ? switcher.cellW : 0
                height: parent.height
                visible: switcher.showPowerCell
                enabled: switcher.showPowerCell

                Rectangle {
                    anchors.fill: parent
                    radius: 15
                    color: pwrCellMa.pressed
                        ? Qt.alpha(switcher.store.currentPower ? switcher.accentColor : ThemeBackend.red, 0.24)
                        : Qt.alpha(switcher.store.currentPower ? switcher.accentColor : ThemeBackend.surface2, 0.14)
                    border.width: 1
                    border.color: Qt.alpha(switcher.store.currentPower ? switcher.accentColor : ThemeBackend.surface2, 0.45)
                    opacity: pwrCellMa.containsMouse ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Text {
                    id: pwrCellGlyph
                    anchors.centerIn: parent
                    text: switcher.store.isPowerPending ? "󰑮" : ""
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: 15
                    color: switcher.store.currentPower
                        ? (pwrCellMa.containsMouse ? ThemeBackend.text : switcher.accentColor)
                        : (pwrCellMa.containsMouse ? ThemeBackend.red : ThemeBackend.subtext0)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RotationAnimation {
                        target: pwrCellGlyph
                        property: "rotation"
                        from: 0; to: 360
                        duration: 800
                        loops: Animation.Infinite
                        running: switcher.showPowerCell && switcher.store.isPowerPending
                        onRunningChanged: {
                            if (!running) pwrCellGlyph.rotation = 0;
                        }
                    }
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    width: 1
                    height: 14
                    color: Qt.alpha(ThemeBackend.surface2, 0.55)
                }

                MouseArea {
                    id: pwrCellMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (switcher.customPowerHandler) switcher.powerClicked();
                        else switcher.store.togglePower();
                    }
                }
            }

            Repeater {
                model: switcher.modes
                Item {
                    id: btn
                    required property var modelData
                    readonly property bool selected: switcher.store.activeMode === modelData.id
                    readonly property bool linked: switcher.store.modeConnected(modelData.id)

                    width: switcher.cellW
                    height: parent.height

                    Text {
                        anchors.centerIn: parent
                        text: switcher.store.modeIcon(modelData.id)
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: 15
                        color: btn.selected
                            ? switcher.accentColor
                            : (ma.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 6
                        anchors.topMargin: 5
                        width: 5
                        height: 5
                        radius: 2.5
                        visible: btn.linked
                        color: ThemeBackend.green
                    }

                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: switcher.store.setMode(modelData.id)
                    }
                }
            }

            // 3rd equal-sized cell: Fullscreen toggle (shown only when showFullscreenCell === true)
            Item {
                id: fsCell
                width: switcher.cellW
                height: parent.height
                opacity: switcher.showFullscreenCell ? 1.0 : 0.0
                visible: opacity > 0.01
                enabled: switcher.showFullscreenCell
                Behavior on opacity { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    width: 1
                    height: 14
                    color: Qt.alpha(ThemeBackend.surface2, 0.55)
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 15
                    color: fsMa.pressed
                        ? Qt.alpha(switcher.accentColor, 0.24)
                        : Qt.alpha(switcher.accentColor, 0.14)
                    border.width: 1
                    border.color: Qt.alpha(switcher.accentColor, 0.45)
                    opacity: fsMa.containsMouse ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: switcher.fullscreenActive ? "󰊔" : "󰊓"
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: 15
                    color: fsMa.containsMouse ? switcher.accentColor : ThemeBackend.subtext0
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: fsMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: switcher.fullscreenClicked()
                }
            }
        }
    }
}
