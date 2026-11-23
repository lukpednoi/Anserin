import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import ".."
import "../../../"

// 1. WELCOME — lightweight hero + real SystemInfo hardware & OS cards (zero heavy logic/pickers!)
Column {
    id: page
    property var app: null
    spacing: 10

    Component.onCompleted: { if (typeof SystemInfo.fetch === "function") SystemInfo.fetch(); }

    readonly property string osName: SystemInfo.osName || ""
    readonly property string kernel: SystemInfo.kernelVersion || ""
    readonly property string desktop: SystemInfo.desktopEnv || ""
    readonly property string shellName: SystemInfo.shell || ""
    readonly property string uptime: SystemInfo.uptime || ""
    readonly property string hostName: SystemInfo.hostname || ""
    readonly property string cpuModel: SystemInfo.cpuModel || ""
    readonly property string gpuModel: SystemInfo.gpuModel || ""
    readonly property string memTotal: SystemInfo.totalRamGb ? SystemInfo.totalRamGb + " GB" : ""
    readonly property string diskText: (SystemInfo.diskUsedGb || 0) + " / " + (SystemInfo.diskTotalGb || 0) + " GB"
    readonly property int diskPct: SystemInfo.diskTotalGb ? Math.round(100 * SystemInfo.diskUsedGb / SystemInfo.diskTotalGb) : 0
    readonly property string installedVer: Updates.localVersion || ""

    component SCard: SmartCard {
        cornerRadius: page.app.cornerRadius; darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cCard; accent: page.app.cAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }

    component InfoTile: Rectangle {
        id: it
        property string icon: "󰌽"
        property string label: ""
        property string val: ""
        property bool accentVal: false
        height: 54; radius: Math.max(11, page.app.cornerRadius - 3)
        color: page.app.cTile
        border.width: 1; border.color: page.app.darkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
        Column {
            anchors.fill: parent; anchors.margins: 10; spacing: 3
            Row {
                spacing: 5
                Text { text: it.icon; font.family: page.app.iconFont; font.pixelSize: 11; color: page.app.cAccent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: it.label.toUpperCase(); font.family: page.app.uiFont; font.pixelSize: 9; font.letterSpacing: 0.9; color: page.app.cSub; anchors.verticalCenter: parent.verticalCenter }
            }
            Text {
                width: parent.width; elide: Text.ElideRight; text: it.val
                font.family: page.app.uiFont; font.pixelSize: 12; font.weight: it.accentVal ? Font.Medium : Font.Normal
                color: it.accentVal ? page.app.cAccent : page.app.cText
            }
        }
    }

    // Hero card
    Rectangle {
        width: parent.width; height: 120; radius: Math.max(14, page.app.cornerRadius)
        color: page.app.liquidGlass ? Qt.rgba(page.app.cCard.r, page.app.cCard.g, page.app.cCard.b, page.app.darkMode ? 0.48 : 0.62) : page.app.cCard
        border.width: 1; border.color: page.app.darkMode ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.07)
        clip: true

        Rectangle {
            anchors.fill: parent; radius: parent.radius; opacity: 0.17
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: page.app.cAccent }
                GradientStop { position: 1.0; color: "transparent" }
            }
        }
        Row {
            anchors.left: parent.left; anchors.leftMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 15
            Item {
                width: 68; height: 68
                SpringVal { id: crSc; target: crMa.pressed ? 0.90 : 1.0; stiffness: 460; damping: 0.40; eps: 0.002 }
                SpringVal { id: crRot; target: 0.0; stiffness: 220; damping: 0.35; eps: 0.1 }
                scale: crSc.value; rotation: crRot.value
                Rectangle { anchors.fill: parent; radius: 20; color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.15); border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.38) }
                Item {
                    id: logoMask; anchors.centerIn: parent; width: 48; height: 48; visible: false; layer.enabled: true; layer.smooth: true
                    Image {
                        anchors.fill: parent
                        source: "file://" + (Caching.anserinDir || (page.app.repoUrl.replace(/^file:\/\//, "") + "/src")) + "/assets/logo.svg"
                        sourceSize: Qt.size(96, 96); fillMode: Image.PreserveAspectFit; smooth: true; antialiasing: true
                    }
                }
                Item {
                    id: logoFill; anchors.fill: logoMask; visible: false; layer.enabled: true; layer.smooth: true
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: page.app.cAccent } GradientStop { position: 1.0; color: page.app.cAccent2 } }
                    }
                }
                MultiEffect { anchors.fill: logoMask; source: logoFill; maskEnabled: true; maskSource: logoMask; autoPaddingEnabled: false }
                MouseArea { id: crMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { crSc.kick(1.3); crRot.kick(200); page.app.sfx.playQuick(); } }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Row {
                    spacing: 8
                    Text { text: "Anserin"; font.family: page.app.uiFont; font.pixelSize: 24; font.weight: Font.Light; color: page.app.cText }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 20; width: vLb.implicitWidth + 14; radius: 10; color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.18)
                        Text { id: vLb; anchors.centerIn: parent; text: "v" + page.installedVer; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: page.app.cAccent } }
                }
                Text { text: "by M✦Mi"; font.family: page.app.uiFont; font.pixelSize: 11; font.weight: Font.Light; color: page.app.cSub }
            }
        }
        Rectangle {
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12; height: 24; width: ghRow.implicitWidth + 18; radius: 12
            color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, ghMa.containsMouse ? 0.28 : 0.16)
            Row { id: ghRow; anchors.centerIn: parent; spacing: 5
                Text { text: "󰊤"; font.family: page.app.iconFont; font.pixelSize: 12; color: page.app.cAccent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "lukpednoi"; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: page.app.cAccent; anchors.verticalCenter: parent.verticalCenter } }
            MouseArea { id: ghMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { page.app.sfx.playClick(); Qt.openUrlExternally("https://github.com/lukpednoi/Anserin"); } }
        }
    }

    SCard {
        title: "System"; icon: "󰌽"; statusText: page.osName.toUpperCase()
        RowLayout { width: parent.width; spacing: 8
            InfoTile { Layout.fillWidth: true; Layout.preferredWidth: 52; icon: "󰣇"; label: "OS Name"; val: page.osName; accentVal: true }
            InfoTile { Layout.fillWidth: true; Layout.preferredWidth: 48; icon: "󰌽"; label: "Kernel Version"; val: page.kernel } }
        RowLayout { width: parent.width; spacing: 8
            InfoTile { Layout.fillWidth: true; icon: "󰧨"; label: "Desktop"; val: page.desktop }
            InfoTile { Layout.fillWidth: true; icon: "󰆍"; label: "Shell"; val: page.shellName }
            InfoTile { Layout.fillWidth: true; icon: "󰔛"; label: "Uptime"; val: page.uptime; accentVal: true } }
    }

    SCard {
        title: "Hardware"; icon: "󰍛"; statusText: page.hostName
        RowLayout { width: parent.width; spacing: 8
            InfoTile { Layout.fillWidth: true; Layout.preferredWidth: 56; icon: "󰌢"; label: "Device Name"; val: page.hostName }
            InfoTile { Layout.fillWidth: true; Layout.preferredWidth: 44; icon: "󰍛"; label: "Memory"; val: page.memTotal; accentVal: true } }
        InfoTile { width: parent.width; icon: "󰻠"; label: "Processor"; val: page.cpuModel }
        InfoTile { width: parent.width; icon: "󰢮"; label: "Graphics"; val: page.gpuModel }
        Rectangle {
            width: parent.width; height: 56; radius: 13; color: page.app.cTile
            border.width: 1; border.color: page.app.darkMode ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
            Column {
                anchors.fill: parent; anchors.margins: 11; spacing: 7
                Item { width: parent.width; height: 15
                    Row { anchors.left: parent.left; spacing: 6
                        Text { text: "󰋊"; font.family: page.app.iconFont; font.pixelSize: 12; color: page.app.cAccent }
                        Text { text: "DISK CAPACITY"; font.family: page.app.uiFont; font.pixelSize: 9; font.letterSpacing: 0.9; color: page.app.cSub; anchors.verticalCenter: parent.verticalCenter } }
                    Text { anchors.right: parent.right; text: page.diskText + "  (" + page.diskPct + "%)"; font.family: page.app.uiFont; font.pixelSize: 11; font.weight: Font.Medium; color: page.app.cAccent } }
                Rectangle { width: parent.width; height: 5; radius: 2.5; color: page.app.darkMode ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.09)
                    Rectangle { width: parent.width * (page.diskPct / 100.0); height: parent.height; radius: 2.5
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: page.app.cAccent } GradientStop { position: 1.0; color: page.app.cAccent2 } } } }
            }
        }
    }
}
