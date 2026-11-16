import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../"
import "../reusables"

Item {
    id: root
    property string appearance: "original"
    property string cover: "original"
    readonly property bool split: appearance === "m3"
    readonly property bool stage: appearance === "m5"
    readonly property string effectiveCover: stage ? "image" : (["original","record","image"].indexOf(cover) >= 0 ? cover : (split ? "image" : "original"))
    readonly property bool record: effectiveCover !== "image"
    readonly property real unit: width/625
    readonly property real corners: ThemeBackend.clampedBorderRadius * unit
    readonly property real textX: (split ? 28 : stage ? 28 : 245)*unit
    readonly property real textY: (split ? 260 : stage ? 26 : 40)*unit
    readonly property real controlWidth: (split ? 222 : stage ? 569 : 350)*unit
    component Caption: Text {
        color: ThemeBackend.text
        font { family: ThemeBackend.fontFamily; pixelSize: Math.max(6, 12*root.unit) }
        elide: Text.ElideRight
    }
    Rectangle { anchors.fill: parent; color: ThemeBackend.base; radius: root.corners }
    Rectangle { visible: root.split; x: 16*root.unit; y: x; width: 274*root.unit; height: parent.height-2*y; color: ThemeBackend.mantle; radius: root.corners }
    Rectangle { visible: root.split; x: 306*root.unit; y: 16*root.unit; width: 303*root.unit; height: parent.height-2*y; color: ThemeBackend.mantle; radius: root.corners }
    Item {
        id: artwork
        visible: !root.stage
        x: root.stage ? 0 : 28*root.unit
        y: root.stage ? 0 : 28*root.unit
        width: root.stage ? parent.width : (root.split ? 222 : 190)*root.unit
        height: root.stage ? parent.height : width
        Rectangle { anchors.fill: parent; color: ThemeBackend.crust; radius: root.record ? width/2 : root.corners }
        Item {
            id: disc
            objectName: "music-preview-disc"
            anchors.fill: parent
            // the record spins like the real player while the preview is on screen
            NumberAnimation on rotation {
                from: 0; to: 360; duration: 5000
                loops: Animation.Infinite
                running: root.record && root.visible
            }
            ImageBox {
                anchors.fill: parent
                anchors.margins: root.record && root.effectiveCover === "record" ? parent.width*.3 : 0
                source: MprisController.artUrl
                cornerRadius: root.record ? width/2 : root.corners
                fillMode: Image.PreserveAspectCrop
            }
            Repeater {
                model: root.record && root.effectiveCover === "record" ? 7 : 0
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    width: parent.width*(.96-index*.08); height: width; radius: width/2
                    color: "transparent"; border.color: ThemeBackend.surface1
                }
            }
        }
        Rectangle { visible: root.record; anchors.centerIn: parent; width: parent.width*(root.effectiveCover === "record" ? .044 : .2); height: width; radius: width/2; color: ThemeBackend.crust }
        // an image cover stays straight, wherever the record's spin stopped
        Binding { target: disc; property: "rotation"; value: 0; when: !root.record; restoreMode: Binding.RestoreBindingOrValue }
        RecordTonearm { anchors.fill: parent; visible: root.effectiveCover === "record" }
    }
    Caption { visible: !root.stage; x: root.textX; y: root.textY; width: root.controlWidth; text: "Music"; font.bold: true; font.pixelSize: Math.max(7,19*root.unit) }
    Caption { visible: !root.stage; x: root.textX; y: root.textY+28*root.unit; width: root.controlWidth; text: "Artist"; color: ThemeBackend.subtext0 }
    Row {
        visible: !root.stage
        x: root.textX; y: root.textY+56*root.unit; spacing: 8*root.unit
        Repeater { model: ["Speaker","Source"]; Caption { required property string modelData; text: modelData; color: ThemeBackend.subtext0 } }
    }
    Item {
        visible: !root.stage
        x: root.textX; y: (root.split ? 406 : root.stage ? 482 : 156)*root.unit
        width: root.controlWidth; height: 8*root.unit
        Rectangle { anchors.fill: parent; radius: height/2; color: ThemeBackend.surface1 }
        Rectangle { width: parent.width*.4; height: parent.height; radius: height/2; color: ThemeBackend.mauve }
    }
    Caption {
        visible: !root.stage
        x: root.textX; y: (root.split ? 452 : root.stage ? 514 : 194)*root.unit
        width: root.controlWidth
        text: "󰒮     󰐊     󰒭"; horizontalAlignment: Text.AlignHCenter
        font.family: ThemeBackend.iconFont; font.pixelSize: Math.max(8,24*root.unit)
    }
    Item {
        id: eq
        visible: !root.stage
        x: (root.split ? 320 : 28)*root.unit
        y: (root.split ? 84 : root.stage ? 200 : 322)*root.unit
        width: (root.split ? 275 : 569)*root.unit
        height: (root.split ? 336 : root.stage ? 170 : 145)*root.unit
        Caption { y: -42*root.unit; text: "EQ     Lyrics"; color: ThemeBackend.mauve }
        Repeater {
            model: root.stage ? 0 : 10
            Rectangle {
                required property int index
                x: root.split ? 0 : index*eq.width/10
                y: root.split ? index*eq.height/10 : 0
                width: root.split ? eq.width : 9*root.unit
                height: root.split ? 7*root.unit : eq.height
                radius: Math.min(width,height)/2
                color: ThemeBackend.surface1
                Rectangle { width: root.split ? parent.width*.5 : parent.width; height: root.split ? parent.height : parent.height*.5; anchors.bottom: parent.bottom; radius: parent.radius; color: ThemeBackend.mauve }
            }
        }
        Shape {
            visible: root.stage
            anchors.fill: parent
            preferredRendererType: Shape.GeometryRenderer
            ShapePath {
                strokeColor: ThemeBackend.mauve; strokeWidth: 2*root.unit; fillColor: "transparent"
                startX: 0; startY: eq.height*.55
                PathCubic { x: eq.width*.5; y: eq.height*.25; control1X: eq.width*.25; control1Y: eq.height*.55; control2X: eq.width*.25; control2Y: eq.height*.25 }
                PathCubic { x: eq.width; y: eq.height*.55; control1X: eq.width*.75; control1Y: eq.height*.25; control2X: eq.width*.75; control2Y: eq.height*.55 }
            }
        }
        Repeater {
            model: root.stage ? 5 : 0
            Rectangle { required property int index; x: index*(eq.width-width)/4; y: eq.height*([.55,.4,.25,.4,.55][index])-height/2; width: 10*root.unit; height: width; radius: width/2; color: ThemeBackend.text }
        }
    }
    Grid {
        visible: !root.stage
        x: eq.x; y: eq.y+eq.height+22*root.unit
        width: eq.width; columns: 4; spacing: 8*root.unit
        Repeater {
            model: 8
            Rectangle { width: (eq.width-24*root.unit)/4; height: 14*root.unit; radius: height/2; color: index===0 ? ThemeBackend.mauve : ThemeBackend.surface0 }
        }
    }

    // Ambient: a sketch of its stage at 625 x 565 (media/ambient/AmbientStage.qml): the cover on a disc reaching
    // into the top-right corner, its position line and visualizer, the song at the top, a lyric line, the bottom
    // row and the five round buttons
    Loader {
        active: root.stage
        sourceComponent: Item {
            width: 625; height: 565
            transform: Scale { xScale: root.unit; yScale: root.unit }
            readonly property real cx: 50
            readonly property real cy: -420.7
            readonly property real r: 712.5
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: cardCorners }
            Rectangle { id: cardCorners; anchors.fill: parent; radius: ThemeBackend.clampedBorderRadius; visible: false; layer.enabled: true }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.darker(ThemeBackend.surface1, 1.1) }
                    GradientStop { position: 1; color: ThemeBackend.crust }
                }
            }
            Item {
                id: sketchCover
                anchors.fill: parent
                visible: false
                Image { width: parent.width; height: 320; source: MprisController.artUrl; fillMode: Image.PreserveAspectCrop; sourceSize.width: 400 }
                Rectangle { anchors.fill: parent; color: ThemeBackend.surface2; opacity: MprisController.artUrl ? 0 : 1 }
            }
            Item {
                id: sketchDisc
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle { x: parent.cx - parent.r; y: parent.cy - parent.r; width: parent.r * 2; height: width; radius: parent.r }
                readonly property real cx: parent.cx
                readonly property real cy: parent.cy
                readonly property real r: parent.r
            }
            MultiEffect { anchors.fill: parent; source: sketchCover; maskEnabled: true; maskSource: sketchDisc; maskThresholdMin: 0.5; maskSpreadAtMin: 0.004 }
            Shape {
                anchors.fill: parent
                ShapePath {
                    strokeColor: Qt.rgba(1, 1, 1, 0.5); strokeWidth: 3; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 50; centerY: -420.7; radiusX: 696; radiusY: 696; startAngle: 91; sweepAngle: -50 }
                }
            }
            Repeater {
                model: 42
                Rectangle {
                    required property int index
                    readonly property real a: (34 + index * 1.5) * Math.PI / 180
                    width: 3; height: 8 + 18 * Math.abs(Math.sin(index * 0.9) * Math.sin(index * 0.37))
                    radius: 1.5; color: "white"; opacity: 0.7
                    x: 50 + 722.5 * Math.cos(a) - 1.5; y: -420.7 + 722.5 * Math.sin(a)
                    transformOrigin: Item.Top; rotation: (34 + index * 1.5) - 90
                }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; y: 14; text: "Music"; color: "white"; font.family: ThemeBackend.fontFamily; font.pixelSize: 22; font.bold: true }
            Text { x: 26; y: 360; text: "Lyrics line"; color: "white"; font.family: ThemeBackend.fontFamily; font.pixelSize: 44; font.weight: Font.Black }
            Text { x: 26; y: 420; text: "the next line"; color: "white"; opacity: 0.4; font.family: ThemeBackend.fontFamily; font.pixelSize: 26; font.weight: Font.Black }
            Row {
                x: 26; y: 505; spacing: 10
                Repeater { model: [90, 130, 120]; Rectangle { required property int modelData; width: modelData; height: 34; radius: 17; color: Qt.rgba(1, 1, 1, 0.2) } }
            }
            Column {
                x: 625 - 18 - 44; y: 565 - 18 - height; spacing: 10
                Repeater { model: 5; Rectangle { required property int index; width: 44; height: 44; radius: 22; color: index === 0 ? Qt.rgba(1, 1, 1, 0.9) : Qt.rgba(1, 1, 1, 0.2) } }
            }
        }
    }
}
