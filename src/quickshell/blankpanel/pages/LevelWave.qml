import QtQuick
import "../../"

// Water filled to `fillLevel` with rolling waves across the top (assets/shaders/fluid/level_wave.frag): a front
// layer and a fainter back layer moving the other way. It rolls only while `running`.
ShaderEffect {
    id: w
    property real radius: 0
    property real fillLevel: 0
    property real waveAmp: 6
    property color color1: ThemeBackend.mauve
    property color color2: ThemeBackend.mauve
    property color backColor: Qt.alpha(ThemeBackend.mauve, 0.45)
    property bool running: true
    property int period: 3200
    property vector2d itemSize: Qt.vector2d(width, height)
    property real phase: 0
    NumberAnimation on phase { running: w.running && w.visible; loops: Animation.Infinite; from: 0; to: Math.PI * 2; duration: w.period }
    visible: fillLevel > 0.001
    fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/fluid/level_wave.frag.qsb"
}
