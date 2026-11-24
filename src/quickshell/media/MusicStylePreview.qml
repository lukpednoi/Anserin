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

    // Smart ("m5"): sketch of Smart Glasses HUD at 625 x 565 (media/smart/SmartMusicStage.qml):
    // deep smoked obsidian card, left AR HUD clock + hairline scrubber + lyrics + bottom pills, right clipped vinyl disc + progress ring
    Loader {
        active: root.stage
        sourceComponent: Item {
            width: 625; height: 565
            transform: Scale { xScale: root.unit; yScale: root.unit }
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: cardCorners }
            Rectangle { id: cardCorners; anchors.fill: parent; radius: ThemeBackend.clampedBorderRadius; visible: false; layer.enabled: true }

            Rectangle { anchors.fill: parent; color: "#06080c" }

            // Right clipped vinyl disc + circular progress arc
            Item {
                x: 625 - 196; y: (565 - 340) * 0.5; width: 340; height: 340
                Shape {
                    anchors.centerIn: parent; width: 372; height: 372
                    ShapePath {
                        strokeColor: Qt.rgba(1, 1, 1, 0.16); strokeWidth: 2; fillColor: "transparent"
                        PathAngleArc { centerX: 186; centerY: 186; radiusX: 178; radiusY: 178; startAngle: 0; sweepAngle: 360 }
                    }
                    ShapePath {
                        strokeColor: ThemeBackend.mauve; strokeWidth: 3.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 186; centerY: 186; radiusX: 178; radiusY: 178; startAngle: -90; sweepAngle: -105 }
                    }
                }
                Rectangle {
                    anchors.fill: parent; radius: 170; color: "#11151e"
                    border.width: 2; border.color: Qt.rgba(1, 1, 1, 0.25)
                    ImageBox {
                        anchors.fill: parent
                        source: MprisController.artUrl
                        cornerRadius: 170
                        fillMode: Image.PreserveAspectCrop
                    }
                    Rectangle { anchors.centerIn: parent; width: 58; height: 58; radius: 29; color: "#06080c"; border.width: 2; border.color: ThemeBackend.mauve }
                }
            }

            // Left HUD stack sketch
            Column {
                x: 28; y: 28; width: 350; spacing: 14
                Column {
                    width: parent.width; spacing: 6
                    Text { text: "01:30  / 03:58"; color: "#ffffff"; font.family: ThemeBackend.fontFamily; font.pixelSize: 38; font.weight: Font.ExtraLight }
                    Rectangle { width: 244; height: 2; color: Qt.rgba(1, 1, 1, 0.18); Rectangle { width: 112; height: 2; color: "#ffffff" } }
                    Text { text: "Smart Music"; color: "#ffffff"; font.family: ThemeBackend.fontFamily; font.pixelSize: 20; font.weight: Font.Light }
                    Text { text: "Speaker · via Player"; color: Qt.rgba(1, 1, 1, 0.65); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.Light }
                }
                Rectangle { width: 244; height: 1; color: Qt.rgba(1, 1, 1, 0.16) }
                Column {
                    width: parent.width; spacing: 8; topPadding: 34
                    Text { text: "Floating glass lyrics"; color: "#ffffff"; font.family: ThemeBackend.fontFamily; font.pixelSize: 16; font.weight: Font.Normal }
                    Text { text: "Liquid Mercury EQ ready"; color: Qt.rgba(1, 1, 1, 0.45); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.weight: Font.ExtraLight }
                }
            }

            // Bottom bar sketch
            Row {
                x: 28; y: 565 - 28 - 40; spacing: 10
                Rectangle { width: 36; height: 36; radius: 18; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22) }
                Rectangle { width: 42; height: 42; radius: 21; color: "#ffffff" }
                Rectangle { width: 36; height: 36; radius: 18; color: "transparent"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.22) }
                Rectangle { width: 96; height: 36; radius: 18; color: Qt.rgba(1, 1, 1, 0.08); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.20) }
                Rectangle { width: 84; height: 36; radius: 18; color: Qt.rgba(1, 1, 1, 0.08); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.20) }
            }
        }
    }
}
