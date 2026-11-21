import QtQuick
import "../../"
import QtQuick.Layouts
import "."

/**
 * Left Side 3-Part Glass Drawer for [2/2] Bubble Network UI:
 *   1) Upper section: Sized circular Wi-Fi / BT hero glyph with status lock badge
 *   2) Middle section: Network/Device title + full specification grid
 *   3) Bottom section: Password input (if locked & unsaved) OR Connect / Disconnect button
 *
 * Intentionally spans only the left ~50% width so the right side of the 360° network
 * remains completely visible, draggable, and zoomable while the drawer is open.
 */
Rectangle {
    id: drawer

    property bool open: false
    property bool checking: false        // the typed password is being tried
    property bool isFullscreen: false
    property string side: "left"         // "left" | "right"
    property bool cosmosDarkStyle: false // sleek obsidian glass style for [4/4] Gargantua
    property var itemData: null
    property string activeMode: "wifi" // "wifi" | "bt"
    property color accentColor: ThemeBackend.mauve
    property string lockState: "none"   // "none" | "locked" | "unlocked" | "saved" | "error"
    property bool isConnected: false
    property var storeRef: null

    signal submitPassword(string uid, string password)
    signal connectRequested(string uid)
    signal disconnectRequested(string uid)
    signal closeRequested()

    readonly property string uid: itemData ? (itemData.id || "") : ""
    readonly property bool isWifi: activeMode === "wifi"
    readonly property int sig: itemData ? (itemData.sig || 0) : 0
    readonly property color sigColor: NetLook.signalColor(sig)
    readonly property bool needsPassword: isWifi && !!itemData && !!itemData.locked && !itemData.saved && !isConnected

    readonly property string heroGlyph: {
        if (!itemData) return "󰤨";
        if (!isWifi) return itemData.icon || "󰂯";
        if (sig >= 75) return "󰤨";
        if (sig >= 50) return "󰤥";
        if (sig >= 30) return "󰤢";
        return "󰤟";
    }

    readonly property color heroAccent: {
        if (lockState === "error") return ThemeBackend.red;
        if (lockState === "unlocked") return ThemeBackend.green;
        if (isConnected) return accentColor;
        return accentColor;
    }

    readonly property string statusText: {
        if (!itemData) return "";
        if (isConnected) return "Connected";
        if (!isWifi) return itemData.paired ? "Paired Device" : "Available Device";
        if (itemData.saved) return "Saved Network";
        if (itemData.locked) return (itemData.sec || "WPA2") + " Secured";
        return "Open Network";
    }

    readonly property var detailSpecs: {
        if (!itemData) return [];
        const tier = sig >= 75 ? "Strong" : (sig >= 45 ? "Fair" : "Weak");
        if (isWifi) {
            return [
                { label: "SIGNAL", value: sig + "% · " + tier, col: sigColor, wide: false },
                { label: "BAND", value: itemData.band || "—", col: ThemeBackend.text, wide: false },
                { label: "SECURITY", value: itemData.sec || (itemData.locked ? "WPA2" : "Open"), col: ThemeBackend.text, wide: false },
                { label: "LINK SPEED", value: itemData.speed || "—", col: ThemeBackend.text, wide: false },
                { label: "CHANNEL", value: itemData.channel || "—", col: ThemeBackend.subtext1, wide: true },
                { label: "IP ADDRESS", value: isConnected ? (itemData.ip || "—") : (itemData.saved ? "Auto DHCP" : "Unassigned"), col: ThemeBackend.subtext1, wide: false },
                { label: "SOURCE", value: itemData.sourceType === "phone" ? "Hotspot" : "Router", col: ThemeBackend.subtext1, wide: false },
                { label: "MAC ADDRESS", value: itemData.mac || "—", col: ThemeBackend.subtext0, wide: true }
            ];
        }
        return [
            // Bluetooth gives no signal strength here
            { label: "SIGNAL", value: itemData.sigKnown === false ? "—" : sig + "% · " + tier, col: itemData.sigKnown === false ? ThemeBackend.subtext0 : sigColor, wide: false },
            { label: "CATEGORY", value: itemData.kind || "Device", col: ThemeBackend.text, wide: false },
            { label: "PROFILE", value: (itemData.profile && itemData.profile !== "") ? itemData.profile : "—", col: ThemeBackend.text, wide: false },
            { label: "BATTERY", value: itemData.battery >= 0 ? (itemData.battery + "%") : "N/A", col: ThemeBackend.text, wide: false },
            { label: "LINK MODE", value: isConnected ? "Multi-Link Active" : (itemData.paired ? "Bonded Ready" : "Unpaired"), col: ThemeBackend.subtext1, wide: true },
            { label: "MAC ADDRESS", value: itemData.mac || "—", col: ThemeBackend.subtext0, wide: true }
        ];
    }

    function clearInput() {
        pwdInput.text = "";
    }

    function focusPasswordField() {
        if (open && needsPassword) {
            pwdInput.forceActiveFocus();
        }
    }

    onOpenChanged: {
        if (open) {
            pwdInput.text = "";
            if (needsPassword) focusTimer.restart();
        } else {
            focusTimer.stop();
        }
    }

    onUidChanged: {
        pwdInput.text = "";
        if (open && needsPassword) focusTimer.restart();
    }

    Timer {
        id: focusTimer
        interval: 210
        onTriggered: drawer.focusPasswordField()
    }

    readonly property bool isRightSide: side === "right"
    readonly property real parentW: parent ? parent.width : (isFullscreen ? 1920 : 565)

    width: isFullscreen ? Math.round(Math.max(304, Math.min(368, parentW * 0.24))) : 230
    height: parent ? parent.height : 525
    x: isRightSide
        ? (open ? (parentW - width) : (parentW + 14))
        : (open ? 0 : -(width + 14))
    y: 0
    opacity: open ? 1.0 : 0.0
    visible: (isRightSide ? (x < parentW + 8) : (x > -(width + 8))) || opacity > 0.01
    color: cosmosDarkStyle
        ? Qt.rgba(0.035, 0.035, 0.048, 0.93)
        : Qt.rgba(ThemeBackend.mantle.r, ThemeBackend.mantle.g, ThemeBackend.mantle.b, 0.94)
    clip: true

    Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    // Subtle edge hairline accent divider
    Rectangle {
        x: drawer.isRightSide ? 0 : (parent.width - 1)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 1
        color: drawer.cosmosDarkStyle
            ? Qt.rgba(1.0, 0.88, 0.66, 0.22)
            : Qt.alpha(drawer.heroAccent, 0.30)
    }

    // Top-left atmospheric tint glow behind hero icon
    Rectangle {
        x: (drawer.width - width) / 2
        y: -48
        width: 220
        height: 200
        radius: 110
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(drawer.heroAccent, 0.16) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Consume pointer/wheel strictly inside drawer bounds so right canvas stays interactive
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onWheel: (w) => w.accepted = true
    }

    // Close button inside drawer (placed on inner edge so right-side drawer avoids top-right mode capsule)
    Rectangle {
        id: closeBtn
        readonly property int btnSz: drawer.isFullscreen ? 28 : 24
        readonly property int inset: drawer.isFullscreen ? 14 : 10
        x: drawer.isRightSide ? inset : (parent.width - width - inset)
        y: inset
        width: btnSz
        height: btnSz
        radius: btnSz / 2
        z: 10
        color: closeMa.containsMouse ? Qt.alpha(ThemeBackend.surface2, 0.85) : Qt.alpha(ThemeBackend.surface0, 0.65)
        border.width: 1
        border.color: closeMa.containsMouse ? Qt.alpha(drawer.accentColor, 0.55) : Qt.alpha(ThemeBackend.surface2, 0.5)
        scale: closeMa.pressed ? 0.92 : (closeMa.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            font.family: ThemeBackend.iconFont
            font.pixelSize: drawer.isFullscreen ? 13 : 11
            color: ThemeBackend.subtext1
        }

        MouseArea {
            id: closeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: drawer.closeRequested()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: drawer.isFullscreen ? 18 : 12
        anchors.rightMargin: drawer.isFullscreen ? 18 : 12
        anchors.topMargin: drawer.isFullscreen ? 18 : 12
        anchors.bottomMargin: drawer.isFullscreen ? 16 : 12
        spacing: drawer.isFullscreen ? 12 : 8

        // ============================================================
        // Part 1: Sized Hero Icon Medallion
        // ============================================================
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: drawer.isFullscreen ? 180 : 76

            Rectangle {
                anchors.centerIn: parent
                width: drawer.isFullscreen ? 96 : 68
                height: width
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(drawer.heroAccent, 0.22)
            }

            Rectangle {
                id: iconMedallion
                anchors.centerIn: parent
                width: drawer.isFullscreen ? 74 : 54
                height: width
                radius: width / 2
                color: Qt.alpha(drawer.heroAccent, 0.14)
                border.width: 1.5
                border.color: Qt.alpha(drawer.heroAccent, drawer.isConnected ? 0.85 : 0.55)
                Behavior on border.color { ColorAnimation { duration: 180 } }

                Text {
                    anchors.centerIn: parent
                    text: drawer.heroGlyph
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: drawer.isFullscreen ? 33 : 24
                    color: drawer.lockState === "error" ? ThemeBackend.red : drawer.heroAccent
                    Behavior on color { ColorAnimation { duration: 180 } }
                }

                // Corner lock badge for Wi-Fi
                Rectangle {
                    visible: drawer.isWifi && (drawer.lockState !== "none")
                    width: drawer.isFullscreen ? 22 : 18
                    height: width
                    radius: width / 2
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: -2
                    anchors.bottomMargin: -2
                    color: ThemeBackend.crust
                    border.width: 1.2
                    border.color: {
                        if (drawer.lockState === "error") return ThemeBackend.red;
                        if (drawer.lockState === "unlocked") return ThemeBackend.green;
                        if (drawer.lockState === "saved") return ThemeBackend.teal;
                        return ThemeBackend.peach;
                    }

                    Text {
                        anchors.centerIn: parent
                        text: (drawer.lockState === "unlocked" || drawer.lockState === "saved") ? "󰌿" : "󰌾"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: drawer.isFullscreen ? 11 : 9
                        color: parent.border.color
                    }
                }
            }
        }

        // ============================================================
        // Part 2: Network / Device Name + Complete Spec Details
        // ============================================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: drawer.isFullscreen ? 8 : 6

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: drawer.itemData ? (drawer.itemData.name || "") : ""
                font.family: ThemeBackend.fontFamily
                font.pixelSize: drawer.isFullscreen ? 16 : 14
                font.weight: Font.DemiBold
                color: ThemeBackend.text
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Status pill
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: statusLbl.implicitWidth + (drawer.isFullscreen ? 18 : 14)
                height: drawer.isFullscreen ? 22 : 19
                radius: height / 2
                color: drawer.isConnected
                    ? Qt.alpha(drawer.heroAccent, 0.22)
                    : Qt.alpha(ThemeBackend.surface1, 0.85)
                border.width: 1
                border.color: drawer.isConnected
                    ? Qt.alpha(drawer.heroAccent, 0.65)
                    : Qt.alpha(ThemeBackend.surface2, 0.7)

                Text {
                    id: statusLbl
                    anchors.centerIn: parent
                    text: drawer.statusText
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: drawer.isFullscreen ? 10 : 9
                    font.weight: Font.DemiBold
                    color: drawer.isConnected ? drawer.heroAccent : ThemeBackend.subtext1
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: drawer.isFullscreen ? 2 : 1
                Layout.bottomMargin: drawer.isFullscreen ? 2 : 1
                height: 1
                color: Qt.alpha(drawer.heroAccent, 0.16)
            }

            // Full specification card (airy & evenly distributed in both Panel & Fullscreen!)
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: !drawer.isFullscreen
                Layout.preferredHeight: drawer.isFullscreen ? 340 : 260
                Layout.minimumHeight: drawer.isFullscreen ? 300 : 210
                radius: drawer.isFullscreen ? 12 : 10
                color: Qt.alpha(ThemeBackend.surface0, 0.52)
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.surface2, 0.55)

                GridLayout {
                    id: specGrid
                    anchors.fill: parent
                    anchors.margins: drawer.isFullscreen ? 14 : 12
                    columns: 2
                    columnSpacing: drawer.isFullscreen ? 12 : 10
                    rowSpacing: drawer.isFullscreen ? 12 : 10

                    Repeater {
                        model: drawer.detailSpecs

                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.alignment: Qt.AlignVCenter
                            Layout.columnSpan: modelData.wide ? 2 : 1
                            spacing: drawer.isFullscreen ? 3 : 2

                            Text {
                                text: modelData.label
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: drawer.isFullscreen ? 10 : 9
                                font.weight: Font.Bold
                                font.letterSpacing: 0.6
                                color: ThemeBackend.overlay1
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.value
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: drawer.isFullscreen ? 13 : 12
                                font.weight: Font.Medium
                                color: modelData.col
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }
                    }
                }
            }

            Item {
                visible: drawer.isFullscreen
                Layout.fillHeight: true
            }
        }

        // ============================================================
        // Part 3: Password Box (locked) OR Connect / Disconnect Action
        // ============================================================
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: drawer.isFullscreen ? 44 : 38

            // Case A: Password Input (locked & unsaved Wi-Fi)
            Rectangle {
                anchors.fill: parent
                visible: drawer.needsPassword
                radius: 11
                color: ThemeBackend.crust
                border.width: pwdInput.activeFocus ? 1.5 : 1.0
                border.color: pwdInput.activeFocus ? drawer.accentColor : Qt.alpha(ThemeBackend.surface2, 0.85)
                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 6
                    spacing: 8

                    Text {
                        text: "󰌾"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: 13
                        color: pwdInput.activeFocus ? drawer.accentColor : ThemeBackend.subtext0
                    }

                    TextInput {
                        id: pwdInput
                        Layout.fillWidth: true
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 12
                        color: ThemeBackend.text
                        selectionColor: Qt.alpha(drawer.accentColor, 0.35)
                        echoMode: TextInput.Password
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        onTextEdited: Sounds.playSfx("reusables/input/type.wav", 0.25)
                        onAccepted: {
                            if (drawer.uid !== "") {
                                drawer.submitPassword(drawer.uid, text);
                            }
                        }
                        Keys.onEscapePressed: drawer.closeRequested()

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: pwdInput.text.length === 0
                            text: "Enter password..."
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: 12
                            color: ThemeBackend.overlay1
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: drawer.isFullscreen ? 32 : 28
                        Layout.preferredHeight: drawer.isFullscreen ? 32 : 28
                        radius: 8
                        color: submitMa.containsMouse ? drawer.accentColor : Qt.alpha(drawer.accentColor, 0.85)
                        scale: submitMa.pressed ? 0.93 : (submitMa.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: drawer.checking ? "󰑮" : "󰁔"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: 15
                            color: ThemeBackend.crust
                            RotationAnimation on rotation {
                                running: drawer.checking
                                from: 0; to: 360; duration: 800; loops: Animation.Infinite
                                onRunningChanged: if (!running) parent.rotation = 0
                            }
                        }

                        MouseArea {
                            id: submitMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (drawer.uid !== "") {
                                    drawer.submitPassword(drawer.uid, pwdInput.text);
                                }
                            }
                        }
                    }
                }
            }

            // Case B: Direct Connect Button (open / saved Wi-Fi or unconnected Bluetooth)
            Rectangle {
                anchors.fill: parent
                visible: !drawer.needsPassword && !drawer.isConnected
                radius: 11
                scale: connBtnMa.pressed ? 0.97 : (connBtnMa.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.lighter(drawer.accentColor, connBtnMa.containsMouse ? 1.18 : 1.10) }
                    GradientStop { position: 1.0; color: drawer.accentColor }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: drawer.isWifi ? "󰤨" : "󰂱"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: 15
                        color: ThemeBackend.crust
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Connect"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.Bold
                        color: ThemeBackend.crust
                    }
                }

                MouseArea {
                    id: connBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (drawer.uid !== "") {
                            drawer.connectRequested(drawer.uid);
                        }
                    }
                }
            }

            // Case C: Disconnect Button (already connected node)
            Rectangle {
                anchors.fill: parent
                visible: drawer.isConnected
                radius: 11
                color: discBtnMa.containsMouse
                    ? Qt.alpha(ThemeBackend.red, 0.24)
                    : Qt.alpha(ThemeBackend.red, 0.13)
                border.width: 1.2
                border.color: discBtnMa.containsMouse
                    ? ThemeBackend.red
                    : Qt.alpha(ThemeBackend.red, 0.55)
                scale: discBtnMa.pressed ? 0.97 : (discBtnMa.containsMouse ? 1.02 : 1.0)
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: 14
                        color: ThemeBackend.red
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Disconnect"
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        color: ThemeBackend.red
                    }
                }

                MouseArea {
                    id: discBtnMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (drawer.uid !== "") {
                            drawer.disconnectRequested(drawer.uid);
                        }
                    }
                }
            }
        }
    }
}
