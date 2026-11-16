import QtQuick
import QtQuick.Window
import QtQuick.Effects
import "../"
import "../reusables"

Item {
    id: backdrop
    required property var screenRoot
    property alias freezeWallpaperView: freezeWallpaperView
    anchors.fill: parent
    // During the intro the waves draw the frozen desktop themselves and open onto the wallpaper, so it is already fully there.
    readonly property real wallpaperReveal: screenRoot.isPlayingIntro ? 1.0 : screenRoot.panelReveal
Item {
    id: freezeBackdropLayer
    anchors.fill: parent
    z: 0

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.crust
    }

    Image {
        id: fallbackWallpaperView
        anchors.fill: parent
        source: screenRoot.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))
        onStatusChanged: {
            if (status === Image.Error) {
                let defaultPath = "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png";
                if (source.toString() !== defaultPath) {
                    source = defaultPath;
                }
            }
        }
    }

    Image {
        id: freezeWallpaperView
        anchors.fill: parent
        source: (screenRoot.currentFreezePath !== "" && screenRoot.lockController.freezeTimestamp !== "") ? ("file://" + screenRoot.currentFreezePath) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))
        opacity: (status === Image.Ready && source.toString() !== "") ? 1.0 : 0.0

        onStatusChanged: {
            if (status === Image.Ready && screenRoot.isPlayingIntro && !screenRoot.introSequence.running) {
                screenRoot.introStartDelayTimer.stop();
                screenRoot.introSequence.start();
            } else if (status === Image.Error && screenRoot.lockController.freezeTimestamp !== "") {
                let defaultFreeze = "file://" + Caching.getRunDir("screenshot") + "/lock_freeze_default_" + screenRoot.lockController.freezeTimestamp + ".png";
                if (source.toString() !== defaultFreeze) {
                    source = defaultFreeze;
                }
            }
        }
    }
}

Item {
    id: wallpaperContainer
    anchors.fill: parent

    Image {
        id: liveWallpaperView
        anchors.fill: parent
        source: screenRoot.wallpaperSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize: Qt.size(Math.ceil(parent.width * (Screen.devicePixelRatio || 1)), Math.ceil(parent.height * (Screen.devicePixelRatio || 1)))

        onStatusChanged: {
            if (status === Image.Error) {
                let defaultPath = "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png";
                if (source.toString() !== defaultPath) {
                    source = defaultPath;
                }
            }
        }
    }

    WallpaperMedia {
        id: customWallpaper
        anchors.fill: parent
        path: screenRoot.lockController.customBackground
        active: screenRoot.sceneActive && blurEffect.visible && blurEffect.parent.height > 0
    }
}

ShaderEffectSource {
    id: wallpaperTexture
    anchors.fill: parent
    sourceItem: wallpaperContainer
    // Hiding the item itself stops video frames from scheduling renders while idle.
    hideSource: true
    visible: false
}

Item {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: screenRoot.height * (screenRoot.slides ? 1 - screenRoot.slide : 1)
    z: 1
    clip: true

    MultiEffect {
        id: blurEffect
        source: wallpaperTexture
        width: parent.width
        // Keep the texture fixed at screen size while its visible region shrinks.
        height: screenRoot.height
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: screenRoot.s(64)
        saturation: 0.25
        contrast: 0.06
        brightness: 0.02
        blur: screenRoot.inputActive ? 1.0 : 0.72
        Behavior on blur {
            enabled: !screenRoot.isPlayingIntro && !screenRoot.isUnlocking
            NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
        }
        opacity: backdrop.wallpaperReveal
        visible: opacity > 0.01
    }
}

Rectangle {
    id: dimmer
    anchors.fill: parent
    z: 2
    color: ThemeBackend.crust
    transform: Translate { y: screenRoot.slides ? -screenRoot.height * screenRoot.slide : 0 }
    opacity: (screenRoot.inputActive ? 0.14 : 0.38) * backdrop.wallpaperReveal
    Behavior on opacity {
        enabled: !screenRoot.isPlayingIntro && !screenRoot.isUnlocking
        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
    }
}

ShaderEffect {
    id: wipeCanvas
    anchors.fill: parent
    z: 10

    // curvier, layered waves over the frozen desktop that open onto the wallpaper
    visible: screenRoot.isPlayingIntro

    property vector2d itemSize: Qt.vector2d(width, height)
    property real reveal: screenRoot.panelReveal
    property real s28: screenRoot.s(28)
    property color color0: ThemeBackend.crust
    property color color1: ThemeBackend.surface1
    property color color2: ThemeBackend.sapphire
    property color color3: ThemeBackend.blue
    property color color4: ThemeBackend.mauve
    // after the corner revolver's Lock: from the top-right corner to the bottom-left instead of down from the top
    property real diagonal: screenRoot.diagonalIntro ? 1 : 0
    property var source: ShaderEffectSource {
        sourceItem: freezeBackdropLayer
        hideSource: false
        live: true
    }

    fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/effects/curtain_wipe.frag.qsb"
}

}
