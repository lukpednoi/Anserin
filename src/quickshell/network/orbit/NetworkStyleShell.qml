import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../"
import "."

// The left edge panel's Network page in the Radar or Gargantua style (panel.styles.network), at the page's design
// size of 565 × 525, on the real Wi-Fi and Bluetooth (NetworkStore).
//   Radar      the connected network at the bottom over a 28-node constellation (NetworkBackdrop, ConnectedHeroView,
//              a 44 px On/Off button); Host or the hub opens the Scan radar (InteractiveRadarView), which sends a faint
//              wave out of the Host every few seconds.
//   Gargantua  the black hole with the networks orbiting it (BlackHoleNetworkView) and the top-right capsule
//              [Power | Wi-Fi | BT]. Its look is panel.gargantua { colour, tilt, unified }.
//              Full screen: an overlay window with its own Gargantua view on the same store opens behind a signal
//              wave; the panel's view pauses meanwhile. Leaving freezes the full-screen picture once and the wave
//              closes over that still, so nothing is moved between windows and nothing heavy draws twice.
// The page is created when it is shown and destroyed after it is closed (BlankPanel), so nothing here runs in the
// background. `preview` (Edit panel): the store does not scan and nothing takes input; `still` also stops it once
// its opening has played (the style cards).
Rectangle {
    id: page

    property string style: "radar"          // radar | gargantua
    property bool shown: true
    property bool preview: false            // Edit panel: no scanning, no input
    property bool still: false              // Edit panel's style cards: stops once its opening has played
    readonly property bool blackHoleMode: style === "gargantua"

    // a still card runs only long enough to settle, then stays as it is
    property bool settled: false
    Timer { running: page.still; interval: 1800; onTriggered: page.settled = true }
    readonly property bool winVisible: shown && !(still && settled)

    readonly property var look: Config.getSetting("panel.gargantua", {}) || {}
    readonly property real bhColorMode: look.colour === "champagne" ? 0.0 : 1.0
    readonly property bool bhTilted: look.tilt === true
    readonly property bool useUnifiedBlackHole: look.unified !== false


    NetworkStore {
        id: store
        live: page.shown && !page.preview
    }
    readonly property alias netStore: store
    Component.onCompleted: if (blackHoleMode) store.searchOpen = true

    readonly property color modeAccent: store.activeMode === "wifi" ? ThemeBackend.mauve : ThemeBackend.blue
    readonly property bool showConnected: !blackHoleMode && store.currentPower && !!store.activeConnection && !store.searchOpen && !store.modeSwitching
    readonly property bool showRadar: blackHoleMode ? true : (store.currentPower && (!store.activeConnection || store.searchOpen) && !store.modeSwitching)
    readonly property bool hideTopChromeForPwd: showRadar && radarLoader.item && radarLoader.item.hideTopChrome === true
    readonly property string hubSourceKind: {
        if (store.activeMode === "bt") return "bt";
        const c = store.activeConnection;
        return c && c.sourceType === "phone" ? "phone" : "router";
    }
    readonly property string hubBtIcon: "󰂯"
    readonly property real hubPosXRatio: 0.50
    readonly property real hubPosYRatio: 0.37

    radius: NetLook.cardRadius
    color: blackHoleMode ? "#020204" : ThemeBackend.base
    border.width: 1
    border.color: blackHoleMode
        ? Qt.rgba(0.94, 0.77, 0.49, store.currentPower ? 0.28 : 0.16)
        : Qt.alpha(modeAccent, store.currentPower ? 0.36 : 0.22)
    clip: true
    Behavior on border.color { ColorAnimation { duration: 350 } }

    // ---------- Radar: the constellation, the connected bar ----------
    Loader {
        anchors.fill: parent
        active: !page.blackHoleMode
        z: 0
        sourceComponent: NetworkBackdrop {
            accentColor: page.modeAccent
            active: page.winVisible && page.visible
            powerOn: store.currentPower
            winVisible: page.winVisible
            showCenterHub: page.showConnected
            showMesh: true
            hubClickable: false
            hubXRatio: page.hubPosXRatio
            hubYRatio: page.hubPosYRatio
            sourceKind: page.hubSourceKind
            btIconGlyph: page.hubBtIcon
            onHubClicked: store.openSearch()
        }
    }
    ConnectedHeroView {
        id: heroView
        anchors.fill: parent
        visible: !page.blackHoleMode && opacity > 0.01
        store: store
        accentColor: page.modeAccent
        layoutVariant: "bottomBar"
        barStyle: "underline"
        showPanelWaves: true
        showHostButton: true
        hubXRatio: page.hubPosXRatio
        hubYRatio: page.hubPosYRatio
        active: !page.blackHoleMode && page.showConnected
        winVisible: page.winVisible
        z: 2
        opacity: (!page.blackHoleMode && page.showConnected) ? 1.0 : 0.0
        scale: (!page.blackHoleMode && page.showConnected) ? 1.0 : 0.96
        enabled: !page.blackHoleMode && page.showConnected
        Behavior on opacity { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    // ---------- the Scan radar (Radar) or the black hole (Gargantua) ----------
    Component {
        id: radarComp
        InteractiveRadarView {
            store: page.netStore
            accentColor: page.modeAccent
            active: page.showRadar
            winVisible: page.winVisible
        }
    }
    Component {
        id: blackHoleComp
        BlackHoleNetworkView {
            store: page.netStore
            accentColor: page.modeAccent
            sourceKind: page.hubSourceKind
            btIconGlyph: page.hubBtIcon
            isFullscreen: false
            stormGasMode: true
            showBlackHole: true
            blackHoleCenterMode: true
            useUnifiedBlackHole: page.useUnifiedBlackHole
            bhColorMode: page.bhColorMode
            bhTilted: page.bhTilted
            entranceReady: true
            // paused (hidden behind) while the full-screen view runs; back as the closing wave starts
            winVisible: page.winVisible
        }
    }
    Loader {
        id: radarLoader
        anchors.fill: parent
        z: 3
        active: page.blackHoleMode || page.showRadar || opacity > 0.01
        sourceComponent: page.blackHoleMode ? blackHoleComp : radarComp
        opacity: (page.blackHoleMode || page.showRadar) ? 1.0 : 0.0
        scale: (page.blackHoleMode || page.showRadar) ? 1.0 : 0.96
        visible: opacity > 0.01
        enabled: !page.preview && (page.blackHoleMode || page.showRadar)
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    // the capsule: [Wi-Fi | BT] (Radar), [Power | Wi-Fi | BT] (Gargantua)
    TopRightModeSwitcher {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 18
        anchors.rightMargin: 18
        z: 35
        store: store
        accentColor: page.modeAccent
        showPowerCell: page.blackHoleMode
        customPowerHandler: page.blackHoleMode
        fullscreenActive: false
        onPowerClicked: {
            if (radarLoader.item && radarLoader.item.requestPowerToggle) radarLoader.item.requestPowerToggle();
            else store.togglePower();
        }
        opacity: page.hideTopChromeForPwd ? 0.0 : (page.blackHoleMode ? 1.0 : (store.currentPower ? 1.0 : 0.72))
        visible: opacity > 0.01
        enabled: !page.preview && !page.hideTopChromeForPwd
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }

    // ---------- Radar's On/Off button (NetworkPopup's pwrMorph: 124 px in the middle when off, 44 px when on) ----------
    Item {
        id: powerToggleContainer
        z: 20
        readonly property bool hiddenForScan: page.blackHoleMode || page.showRadar
        readonly property bool hiddenForDetails: page.showConnected && heroView.detailsOpen
        readonly property bool hiddenForSwitch: store.modeSwitching
        opacity: (hiddenForScan || hiddenForDetails || hiddenForSwitch) ? 0.0 : 1.0
        visible: opacity > 0.01
        enabled: !page.preview && !hiddenForScan && !hiddenForDetails && !hiddenForSwitch
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

        property real pwrMorph: store.currentPower ? 1.0 : 0.0
        Behavior on pwrMorph {
            enabled: page.winVisible
            NumberAnimation { duration: 800; easing.type: Easing.InOutQuint }
        }
        readonly property real offSize: 124
        readonly property real onSize: 44
        readonly property real targetOnX: page.showRadar ? (page.width - 18 - onSize) : (hiddenForDetails ? 575 : 503)
        readonly property real targetOnY: page.showRadar
            ? (page.height - 18 - onSize)
            : (page.height - heroView.barBottomMargin - (heroView.targetBarHeight / 2) - (onSize / 2))
        property real animOnX: targetOnX
        property real animOnY: targetOnY
        Behavior on animOnX { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on animOnY { NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 0.6 } }
        readonly property real offX: (page.width - offSize) / 2
        readonly property real offY: (page.height - offSize) / 2
        width: offSize + (onSize - offSize) * pwrMorph
        height: width
        x: offX + (animOnX - offX) * pwrMorph
        y: offY + (animOnY - offY) * pwrMorph

        property real switchPopScale: store.modeSwitching ? 0.72 : 1.0
        Behavior on switchPopScale { NumberAnimation { duration: 280; easing.type: Easing.OutBack; easing.overshoot: 0.85 } }

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: -2
            radius: width / 2
            scale: powerToggleContainer.switchPopScale
            color: Qt.rgba(0, 0, 0, 0.22)
            z: -1
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            scale: powerToggleContainer.switchPopScale * (pwrMa.pressed ? 0.95 : (pwrMa.containsMouse ? 1.05 : 1.0))
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            color: store.currentPower ? "transparent" : (pwrMa.containsMouse ? Qt.lighter(ThemeBackend.base, 1.6) : Qt.lighter(ThemeBackend.base, 1.3))
            Behavior on color { ColorAnimation { duration: 200 } }
            border.color: store.isPowerPending ? page.modeAccent
                : (store.currentPower ? "transparent" : (pwrMa.containsMouse ? Qt.lighter(ThemeBackend.base, 1.45) : Qt.lighter(ThemeBackend.base, 1.25)))
            border.width: 1
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                opacity: store.currentPower ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 800; easing.type: Easing.InOutQuint } }
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.lighter(page.modeAccent, 1.15) }
                    GradientStop { position: 1.0; color: page.modeAccent }
                }
            }
            Text {
                id: pwrIcon
                anchors.centerIn: parent
                font.family: ThemeBackend.iconFont
                font.pixelSize: 54
                scale: 1.0 + ((20.0 / 54.0) - 1.0) * powerToggleContainer.pwrMorph
                color: store.currentPower ? ThemeBackend.crust : ThemeBackend.subtext0
                text: store.isPowerPending ? "󰑮" : "\uf011"
                Behavior on color { ColorAnimation { duration: 800; easing.type: Easing.InOutQuint } }
                RotationAnimation {
                    target: pwrIcon
                    property: "rotation"
                    from: 0; to: 360
                    duration: 800
                    loops: Animation.Infinite
                    running: page.winVisible && store.isPowerPending
                    onRunningChanged: if (!running) pwrIcon.rotation = 0
                }
            }
            MouseArea {
                id: pwrMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: store.togglePower()
            }
        }
    }
}
