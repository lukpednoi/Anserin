import QtQuick

// Smart Home Category & Sub-category Navigation Bar:
// - Uses Anserin's exact original icons (from GuideTabs.js).
// - Inactive category = compact circular icon button.
// - Active category = springs open into an expanded pill revealing the category name, with top-left -> bottom-right gradient!
// - Scrolls just like original Control (BoardSettings.qml):
//   * Mouse wheel / touchpad swipe steps one category per notch (wrapping cleanly around ends)
//   * Horizontal drag / flick also works smoothly
//   * Auto-centers the active expanded pill smoothly on a spring!
Item {
    id: bar
    property var categories: []
    property int currentIndex: 0
    property int subIndex: 0
    property bool darkMode: true
    property bool liquidGlass: false
    property color surface: "#171a20"
    property color surfaceHover: "#222630"
    property color accent: "#a5c8ff"
    property color accent2: "#dabde2"
    property color inkAccent: "#0c0e13"
    property color textColor: "#e8ecf2"
    property color subColor: "#9aa2b0"
    property string uiFont: "Noto Sans"
    property string iconFont: "Symbols Nerd Font Mono"

    signal categoryPicked(int index, bool fromClick)
    signal subPicked(int index)

    readonly property var curCat: (categories && categories.length > 0) ? categories[Math.max(0, Math.min(currentIndex, categories.length - 1))] : null
    readonly property var curSubs: (curCat && curCat.subtabs) ? curCat.subtabs : []
    readonly property bool hasSubs: curSubs.length > 0

    SpringVal { id: subHeightSp; target: bar.hasSubs ? 40 : 0; stiffness: 320; damping: 0.72; eps: 0.3 }

    implicitHeight: 54 + (subHeightSp.value > 1 ? subHeightSp.value + 6 : 0)
    height: implicitHeight

    // Auto-center active category pill in Flickable whenever index or pill width settles
    SpringVal {
        id: scrollXSp
        stiffness: 220
        damping: 0.76
        eps: 0.5
        onValueChanged: {
            if (!catFlick.dragging && !catFlick.flicking) catFlick.contentX = value;
        }
    }

    function centerActive(immediate) {
        if (catRep.count <= currentIndex || currentIndex < 0) return;
        const item = catRep.itemAt(currentIndex);
        if (!item) return;
        let totalW = 24;
        let beforeW = 12;
        for (let i = 0; i < catRep.count; i++) {
            const it = catRep.itemAt(i);
            const w = it ? it.targetWidth : 42;
            if (i < currentIndex) beforeW += w + catRow.spacing;
            totalW += w + (i > 0 ? catRow.spacing : 0);
        }
        const activeW = item.targetWidth;
        const maxX = Math.max(0, Math.max(catRow.width + 24, totalW) - catFlick.width);
        const desired = Math.max(0, Math.min(maxX, beforeW + activeW * 0.5 - catFlick.width * 0.5));
        if (immediate) {
            scrollXSp.snap(desired);
            catFlick.contentX = desired;
        } else {
            if (!scrollXSp.moving) scrollXSp.snap(catFlick.contentX);
            scrollXSp.target = desired;
        }
    }

    property bool _alive: true
    Component.onDestruction: _alive = false
    onCurrentIndexChanged: Qt.callLater(() => { if (bar && bar._alive) bar.centerActive(false); })
    onWidthChanged: Qt.callLater(() => { if (bar && bar._alive) bar.centerActive(true); })
    Component.onCompleted: Qt.callLater(() => { if (bar && bar._alive) bar.centerActive(true); })

    // ---------- Main Categories Strip ----------
    Item {
        id: mainStrip
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        height: 54

        // Subtle Smart Mirror hairline container
        Rectangle {
            anchors.fill: parent
            radius: 27
            color: bar.liquidGlass
                ? Qt.rgba(bar.surface.r, bar.surface.g, bar.surface.b, bar.darkMode ? 0.52 : 0.65)
                : bar.surface
            border.width: 1
            border.color: bar.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
        }

        Flickable {
            id: catFlick
            anchors.fill: parent
            anchors.leftMargin: 5; anchors.rightMargin: 5
            contentWidth: catRow.width + 24
            contentHeight: height
            clip: true
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.DragAndOvershootBounds
            onDraggingChanged: if (dragging) scrollXSp.snap(contentX)

            Row {
                id: catRow
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Repeater {
                    id: catRep
                    model: bar.categories

                    Item {
                        id: pillItem
                        required property var modelData
                        required property int index
                        readonly property bool active: index === bar.currentIndex
                        readonly property real expandedW: Math.ceil(42 + nameText.implicitWidth + 16)
                        readonly property real targetWidth: active ? expandedW : 42

                        SpringVal { id: widthSp; target: pillItem.targetWidth; stiffness: 360; damping: 0.56; eps: 0.25 }
                        SpringVal { id: openSp;  target: pillItem.active ? 1.0 : 0.0; stiffness: 340; damping: 0.58; eps: 0.002 }
                        SpringVal { id: scaleSp; target: pillMa.pressed ? 0.93 : (pillHov.hovered && !pillItem.active ? 1.06 : 1.0); stiffness: 520; damping: 0.44; eps: 0.001 }
                        SpringVal { id: iconPopSp; target: 1.0; stiffness: 420; damping: 0.42; eps: 0.002 }

                        onActiveChanged: {
                            if (active) {
                                iconPopSp.snapAndGo(0.76, 1.0);
                                iconPopSp.kick(4.5);
                            }
                        }

                        width: Math.max(42, widthSp.value)
                        height: 42
                        clip: true
                        scale: scaleSp.value
                        z: active ? 3 : 1

                        // Pill background with top-left -> bottom-right gradient when active
                        Rectangle {
                            id: pillBg
                            anchors.fill: parent
                            radius: 21
                            color: pillItem.active
                                ? "transparent"
                                : (pillHov.hovered
                                   ? bar.surfaceHover
                                   : (bar.darkMode ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(0, 0, 0, 0.04)))
                            border.width: pillItem.active ? 0 : 1
                            border.color: bar.darkMode ? Qt.rgba(1, 1, 1, pillHov.hovered ? 0.16 : 0.08) : Qt.rgba(0, 0, 0, pillHov.hovered ? 0.14 : 0.07)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            clip: true

                            // Native GPU gradient fill when active (no Canvas backing texture)
                            Rectangle {
                                anchors.fill: parent
                                radius: height * 0.5
                                visible: openSp.value > 0.01
                                opacity: Math.max(0, Math.min(1, openSp.value))
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: bar.accent }
                                    GradientStop { position: 1.0; color: bar.accent2 }
                                }
                            }
                        }

                        // Original Anserin category icon (centered when collapsed, tucked left when expanded)
                        Text {
                            id: iconText
                            x: 13 + (pillItem.modelData.iconOffsetX || 0)
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16
                            horizontalAlignment: Text.AlignHCenter
                            text: pillItem.modelData.icon
                            font.family: bar.iconFont
                            font.pixelSize: 17
                            scale: iconPopSp.value
                            color: pillItem.active ? bar.inkAccent : (pillHov.hovered ? bar.textColor : bar.subColor)
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }

                        // Category name — revealed smoothly as the pill expands!
                        Text {
                            id: nameText
                            anchors.left: iconText.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: pillItem.modelData.name
                            font.family: bar.uiFont
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            font.letterSpacing: 0.2
                            color: bar.inkAccent
                            opacity: Math.max(0, Math.min(1, (openSp.value - 0.18) / 0.82))
                            visible: openSp.value > 0.12
                            transform: Translate { x: (1.0 - Math.max(0, Math.min(1, openSp.value))) * -8 }
                        }

                        HoverHandler { id: pillHov }

                        MouseArea {
                            id: pillMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                scaleSp.kick(0.7);
                                if (pillItem.index !== bar.currentIndex) {
                                    bar.categoryPicked(pillItem.index, true);
                                }
                            }
                        }
                    }
                }
            }
        }

        // Subtle edge scroll indicators when overflowing
        readonly property color fadeEdgeColor: bar.liquidGlass
            ? Qt.rgba(bar.surface.r, bar.surface.g, bar.surface.b, 0.72)
            : bar.surface
        Rectangle {
            anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.leftMargin: 4; anchors.topMargin: 2; anchors.bottomMargin: 2
            width: 20; radius: 24
            visible: catFlick.contentX > 4
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: mainStrip.fadeEdgeColor }
                GradientStop { position: 1.0; color: "transparent" }
            }
            enabled: false
        }
        Rectangle {
            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.rightMargin: 4; anchors.topMargin: 2; anchors.bottomMargin: 2
            width: 20; radius: 24
            visible: catFlick.contentX < (catFlick.contentWidth - catFlick.width - 4)
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: mainStrip.fadeEdgeColor }
            }
            enabled: false
        }

        // Exact original Control wheel navigation: 1 notch = next/prev category (wrapping!)
        property real wheelAcc: 0
        WheelHandler {
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (e) => {
                if (!bar.categories || bar.categories.length === 0) return;
                const d = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y;
                mainStrip.wheelAcc += d;
                if (Math.abs(mainStrip.wheelAcc) >= 120) {
                    const step = mainStrip.wheelAcc < 0 ? 1 : -1;
                    mainStrip.wheelAcc = 0;
                    const n = bar.categories.length;
                    const next = (bar.currentIndex + step + n) % n;
                    bar.categoryPicked(next, false);
                }
                e.accepted = true;
            }
        }
    }

    // ---------- Sub-categories Strip (same icon -> expanded pill with name!) ----------
    Item {
        id: subWrap
        anchors.top: mainStrip.bottom
        anchors.topMargin: 6
        anchors.left: parent.left; anchors.right: parent.right
        height: Math.max(0, subHeightSp.value)
        opacity: Math.max(0, Math.min(1, subHeightSp.value / 34.0))
        visible: height > 1
        clip: true

        Rectangle {
            id: subContainer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: 36
            width: Math.min(parent.width, subRow.implicitWidth + 12)
            radius: 18
            color: bar.liquidGlass
                ? Qt.rgba(bar.surface.r, bar.surface.g, bar.surface.b, bar.darkMode ? 0.45 : 0.60)
                : bar.surface
            border.width: 1
            border.color: bar.darkMode ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.06)

            Row {
                id: subRow
                anchors.centerIn: parent
                spacing: 5

                Repeater {
                    model: bar.curSubs

                    Item {
                        id: subItem
                        required property var modelData
                        required property int index
                        readonly property bool active: index === bar.subIndex
                        readonly property real expandedW: Math.ceil(30 + subLabel.implicitWidth + 20)

                        SpringVal { id: swSp; target: subItem.active ? subItem.expandedW : 30; stiffness: 380; damping: 0.58; eps: 0.2 }
                        SpringVal { id: soSp; target: subItem.active ? 1.0 : 0.0; stiffness: 350; damping: 0.62; eps: 0.002 }
                        SpringVal { id: ssSp; target: subMa.pressed ? 0.92 : 1.0; stiffness: 520; damping: 0.45; eps: 0.001 }

                        width: Math.max(30, swSp.value)
                        height: 28
                        clip: true
                        scale: ssSp.value

                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: subItem.active
                                ? Qt.rgba(bar.accent.r, bar.accent.g, bar.accent.b, bar.darkMode ? 0.24 : 0.20)
                                : (subHov.hovered ? bar.surfaceHover : "transparent")
                            border.width: subItem.active ? 1 : 0
                            border.color: Qt.rgba(bar.accent.r, bar.accent.g, bar.accent.b, 0.48)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            id: subIcon
                            x: 8
                            anchors.verticalCenter: parent.verticalCenter
                            width: 14
                            horizontalAlignment: Text.AlignHCenter
                            text: subItem.modelData.icon
                            font.family: bar.iconFont
                            font.pixelSize: 13
                            color: subItem.active ? bar.accent : (subHov.hovered ? bar.textColor : bar.subColor)
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Text {
                            id: subLabel
                            anchors.left: subIcon.right
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            text: subItem.modelData.name
                            font.family: bar.uiFont
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: bar.accent
                            opacity: Math.max(0, Math.min(1, (soSp.value - 0.15) / 0.85))
                            visible: soSp.value > 0.12
                        }

                        HoverHandler { id: subHov }
                        MouseArea {
                            id: subMa
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                ssSp.kick(0.7);
                                bar.subPicked(subItem.index);   // the board decides (Orbit: picking it again goes back)
                            }
                        }
                    }
                }
            }
        }
    }
}
