import "../../"
import "../../reusables"
import QtQuick
import QtQuick.Layouts

// The wallpaper transition, played on the current wallpaper and a sample (the real transition shader).
// play() runs the saved effect once. Shared by Theme → Style (WallpaperTransitions.qml) and the Control Center's
// board.
Item {
    id: root
    required property var rootObj
    function s(value) { return rootObj.s(value); }
    Layout.fillWidth: true
    Layout.preferredHeight: s(220)
    implicitHeight: s(220)
    readonly property var saved: Wallpaper.transitionSettings()
    readonly property int effect: Math.max(0, Wallpaper.transitionIds.indexOf(saved.pool[0]))
    readonly property string effectId: Wallpaper.transitionIds[effect]
    readonly property var effectSettings: saved.effects[effectId]
    property bool alternate: false
    property real progress: 1
    property var previewTransition: ({
            vertical: false,
            direction: 0
        })
    property point previewOrigin: Qt.point(0.5, 0.5)
    property real seed: 0
    function play() {
        reveal.stop();
        previewTransition = Wallpaper.resolveTransition(effectId);
        previewOrigin = previewTransition.centered ? Qt.point(0.5, 0.5) : Qt.point(0.15 + Math.random() * 0.7, 0.15 + Math.random() * 0.7);
        seed = Math.random() * 100;
        alternate = !alternate;
        reveal.restart();
    }
    onVisibleChanged: {
        if (!visible) {
            reveal.stop();
            progress = 1;
            alternate = false;
        }
    }
    Loader {
        id: preview
        anchors.fill: parent
        objectName: "wallpaper-transition-preview"
        clip: true
        active: visible
        sourceComponent: Item {
            id: scene
            property url background: current
            readonly property url current: "file://" + Caching.cacheDir + "/wallpaper/current_wallpaper.png?preview=" + Date.now()
            readonly property url sample: layoutPreview.sampleWallpaper

            Item {
                id: outgoing
                anchors.fill: parent

                Image {
                    anchors.fill: parent
                    source: scene.background
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 1000
                }

                WallpaperLayoutPreview {
                    id: layoutPreview
                    anchors.fill: parent
                    showLayout: false
                    currentWallpaper: scene.current
                }
            }

            Image {
                id: incoming

                anchors.fill: parent
                source: root.alternate ? parent.sample : parent.current
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 1000
                visible: false
                layer.enabled: true
            }

            ShaderEffectSource {
                id: outgoingTexture
                sourceItem: outgoing
                hideSource: true
                visible: false
            }

            ShaderEffect {
                objectName: "wallpaper-transition-shader"
                property variant oldTex: outgoingTexture
                property variant newTex: incoming
                property vector2d itemSize: Qt.vector2d(width, height)
                property real progress: reveal.running ? root.progress : -1
                property real transitionType: root.effect
                property vector2d origin: Qt.vector2d(root.previewOrigin.x, root.previewOrigin.y)
                property vector4d params: Qt.vector4d(root.previewTransition.vertical ? 1 : 0, root.previewTransition.direction, root.seed, 0)

                anchors.fill: parent
                fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/transitions/wallpaper_blend.frag.qsb"
            }

            // Paint's glow on the cells just painted in, as on the desktop
            ShaderEffect {
                anchors.fill: parent
                visible: root.effect === 4 && reveal.running
                property vector2d itemSize: Qt.vector2d(width, height)
                property real progress: root.progress
                property real transitionType: root.effect
                property vector2d origin: Qt.vector2d(root.previewOrigin.x, root.previewOrigin.y)
                property vector4d params: Qt.vector4d(0, 0, root.seed, 1)
                property color tint: ThemeBackend.mauve
                fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/transitions/wallpaper_transition.frag.qsb"
            }
        }
    }
    NumberAnimation {
        id: reveal

        target: root
        property: "progress"
        from: 0
        to: 1
        duration: root.effectSettings.duration
        easing.type: Easing.InOutCubic
        onFinished: if (preview.item) preview.item.background = root.alternate ? preview.item.sample : preview.item.current
    }
}
