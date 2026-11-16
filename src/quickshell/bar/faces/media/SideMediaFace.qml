import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../"

Item {
    id: root

    property var module: null
    property var widget: module

    readonly property bool isCompact: module ? module.isCompact : false
    readonly property var barWindow: module ? module.barWindow : null
    readonly property bool isRightBar: module ? module.isRightBar : (barWindow ? (barWindow.barPosition === "right") : false)

    readonly property string musicStyle: (module && module.musicStyle) || Config.getSetting("bar", {}).musicStyle || "full"
    readonly property bool minimal: !Config.getSetting("bar.musicShowInfo", musicStyle === "full")
    readonly property bool showControls: Config.getSetting("bar.musicShowControls", musicStyle === "full" || musicStyle === "controls")
    readonly property bool recordStyle: Config.getSetting("bar.musicSpinningRecord", musicStyle === "record")

    property var playerList: {
        if (!Mpris.players || !Mpris.players.values) return [];
        let list = [];
        let vals = Mpris.players.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i]) list.push(vals[i]);
        }
        return list;
    }

    property var manualPlayer: null

    property var targetPlayer: {
        if (manualPlayer) {
            for (let i = 0; i < playerList.length; i++) {
                if (playerList[i] === manualPlayer) return manualPlayer;
            }
        }
        return MprisController.activePlayer;
    }

    property bool hasTargetPlayer: targetPlayer !== null
    property bool isMediaActive: targetPlayer !== null && targetPlayer.trackTitle !== ""
    property bool isPlaying: targetPlayer ? (targetPlayer.playbackState === MprisPlaybackState.Playing || targetPlayer.isPlaying) : false

    property string rawArtUrl: {
        if (!targetPlayer) return "";
        if (targetPlayer === MprisController.activePlayer) {
            return MprisController.artUrl;
        }
        return targetPlayer.trackArtUrl || "";
    }

    property string activeArtUrl: {
        if (!rawArtUrl) return "";
        if (rawArtUrl.startsWith("file://") || rawArtUrl.startsWith("http")) return rawArtUrl;
        return "file://" + rawArtUrl;
    }

    property real baseHeight: {
        let size = !showControls ? 40 : (minimal ? 68 : (isCompact ? 118 : 130));
        return barWindow ? barWindow.s(size) : size;
    }
    // On the bar itself (not a preview or the panel), Music can step aside while nothing is playing.
    readonly property bool idleHidden: !!module && module.moduleId === "music" && !isMediaActive && Config.getSetting("bar.musicHideWhenIdle", false)
    readonly property bool isFaceVisible: !idleHidden
    property real targetHeight: ((module && !module.moduleActive) || idleHidden) ? 0 : baseHeight

    implicitHeight: targetHeight
    implicitWidth: parent ? parent.width : 0

    Column {
        id: baseCol
        anchors.centerIn: parent
        spacing: barWindow ? barWindow.s(root.isCompact ? 4 : 5) : (root.isCompact ? 4 : 5)

        Rectangle {
            id: thumbBox
            objectName: "music-record"
            anchors.horizontalCenter: parent.horizontalCenter
            width: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
            height: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
            radius: root.recordStyle ? width / 2 : barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
            color: root.isCompact ? Qt.lighter(ThemeBackend.surface1, 1.1) : ThemeBackend.surface1
            border.width: 1
            border.color: (isMediaActive && isPlaying) ? ThemeBackend.mauve : (root.isCompact ? ThemeBackend.surface2 : ThemeBackend.surface1)
            clip: true
            RotationAnimation on rotation {
                id: recordSpin
                from: 0; to: 360; duration: 10000; loops: Animation.Infinite
                running: root.recordStyle && root.visible && (!root.module || root.module.moduleActive) && (!root.barWindow || root.barWindow.visible)
                paused: recordSpin.running && !root.isPlaying
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.18; height: width; radius: width / 2
                color: ThemeBackend.base
                visible: root.recordStyle
                z: 2
            }


            Text {
                anchors.centerIn: parent
                text: "󰎈"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: barWindow ? barWindow.s(root.isCompact ? 12 : 13) : (root.isCompact ? 12 : 13)
                color: root.isCompact ? ThemeBackend.text : ThemeBackend.subtext0
                visible: !sideArtImg.hasImage
            }

            Image {
                id: sideArtImg
                objectName: "music-cover"
                retainWhileLoading: true
                property bool hasImage: false
                onStatusChanged: if (status === Image.Ready) hasImage = true;
                onSourceChanged: if (source.toString() === "") hasImage = false;
                anchors.fill: parent
                source: targetPlayer ? root.activeArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                visible: false
            }

            MultiEffect {
                anchors.fill: sideArtImg
                source: sideArtImg
                maskEnabled: true
                maskSource: sideArtMask
                visible: targetPlayer !== null && root.activeArtUrl !== "" && sideArtImg.hasImage
            }

            Item {
                id: sideArtMask
                anchors.fill: parent
                layer.enabled: true
                visible: false

                Rectangle {
                    anchors.fill: parent
                    radius: thumbBox.radius
                    color: "black"
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: ThemeBackend.surface0
                opacity: 0.15
                visible: targetPlayer !== null && root.activeArtUrl !== "" && sideArtImg.hasImage
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: (root.barWindow ? root.barWindow.togglePopup("music") : Quickshell.execDetached(["bash", Caching.anserinDir + "/scripts/qs_manager.sh", "toggle", "music"]))
            }
        }

        Column {
            visible: root.showControls
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: barWindow ? barWindow.s(root.isCompact ? 3 : 4) : (root.isCompact ? 3 : 4)

            IconButton {
                width: barWindow ? barWindow.s(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                height: barWindow ? barWindow.s(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                cornerRadius: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                visible: !root.minimal && root.showControls
                buttonIcon: "󰒮"
                iconFontSize: barWindow ? barWindow.s(root.isCompact ? 6 : 7) : (root.isCompact ? 6 : 7)
                accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: if (targetPlayer && targetPlayer.canGoPrevious) targetPlayer.previous()
            }

            IconButton {
                width: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                objectName: "music-play-pause"
                height: barWindow ? barWindow.s(root.isCompact ? 26 : 28) : (root.isCompact ? 26 : 28)
                cornerRadius: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                visible: root.showControls
                buttonIcon: (isMediaActive && isPlaying) ? "󰏤" : "󰐊"
                iconFontSize: barWindow ? barWindow.s(root.isCompact ? 8 : 9) : (root.isCompact ? 8 : 9)
                accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                textColor: isHoveredOrHighlighted ? ThemeBackend.green : (root.isCompact ? Qt.lighter(ThemeBackend.text, 1.1) : ThemeBackend.text)
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: MprisController.togglePlaying(targetPlayer)
            }

            IconButton {
                width: barWindow ? barWindow.s(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                height: barWindow ? barWindow.s(root.isCompact ? 24 : 26) : (root.isCompact ? 24 : 26)
                cornerRadius: barWindow ? barWindow.s(root.isCompact ? 7 : 8) : (root.isCompact ? 7 : 8)
                visible: !root.minimal && root.showControls
                buttonIcon: "󰒭"
                iconFontSize: barWindow ? barWindow.s(root.isCompact ? 6 : 7) : (root.isCompact ? 6 : 7)
                accentColor: root.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : (root.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: if (targetPlayer && targetPlayer.canGoNext) targetPlayer.next()
            }
        }
    }
}
