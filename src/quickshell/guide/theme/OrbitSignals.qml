import QtQuick
import QtQuick.Shapes
import "../../"

Item {
    id: root
    property bool active: false
    property string style: "link"
    property string networkStyle: "original"
    property color signalColor: ThemeBackend.mauve
    property real circleX: 0
    property real circleY: 0
    property real diameter: 0
    property var targets: []
    property real unit: 1
    property real phase: 0
    property real driftPhase: 0
    property real introState: 1
    function animWin(t, a, b) { return Math.max(0, Math.min(1, (t - a) / (b - a))); }
    readonly property real coreProgress: animWin(introState, 0, .225)
    readonly property real coreScale: .1 + .9 * coreProgress * coreProgress * (3 - 2 * coreProgress)
    readonly property real connectionProgress: animWin(introState, .1875, .6875)
    property real connectionOpacity: 1
    property real buttonProgress: 1
    property real buttonScale: 1
    // the rings draw while the category buttons pop out and fly to their places (225–825 ms), not after them
    readonly property real ringProgress: animWin(introState, .1875, .6875)
    readonly property var movingTargets: targets.map((target, index) => Qt.rect(
        centerX - target.width / 2 + (target.x + target.width / 2 - centerX + driftX(index)) * buttonProgress,
        centerY - target.height / 2 + (target.y + target.height / 2 - centerY + driftY(index)) * buttonProgress,
        target.width, target.height))
    readonly property var connectionTargets: movingTargets.map(target => Qt.rect(
        target.x + target.width * (1 - buttonScale) / 2,
        target.y + target.height * (1 - buttonScale) / 2,
        target.width * buttonScale, target.height * buttonScale))
    onActiveChanged: {
        buttonProgress = active ? 0 : 1;
        buttonScale = active ? 0 : 1;
        connectionOpacity = active ? 0 : 1;
        if (!active) introState = 1;
    }
    NumberAnimation {
        objectName: "orbit-entry-animation"
        target: root; property: "introState"
        from: 0; to: 1; duration: 1200
        running: root.active
    }
    SequentialAnimation {
        objectName: "orbit-button-entry"
        running: root.active
        PauseAnimation { duration: 225 }
        ParallelAnimation {
            NumberAnimation {
                objectName: "orbit-button-flight"
                target: root; property: "buttonProgress"
                from: 0; to: 1; duration: 600; easing.type: Easing.OutBack
            }
            NumberAnimation {
                objectName: "orbit-button-scale"
                target: root; property: "buttonScale"
                from: 0; to: 1; duration: 250; easing.type: Easing.OutQuint
            }
            NumberAnimation {
                objectName: "orbit-button-fade"
                target: root; property: "connectionOpacity"
                from: 0; to: 1; duration: 400; easing.type: Easing.OutQuint
            }
        }
    }
    readonly property real centerX: circleX + diameter / 2
    readonly property real centerY: circleY + diameter / 2
    readonly property real borderScale: 1 + Math.sin(phase * Math.PI * 2) * .012
    readonly property real networkRadiusX: Math.max(0, ...targets.map(t => Math.abs(t.x + t.width / 2 - centerX)))
    readonly property real networkRadiusY: Math.max(0, ...targets.map(t => Math.abs(t.y + t.height / 2 - centerY)))
    function driftX(index) { return active ? 3 * unit * (2 * Math.sin(driftPhase + index * 1.7) + Math.sin(driftPhase * 2 + index)) : 0; }
    function driftY(index) { return active ? 3 * unit * (2 * Math.cos(driftPhase + index * 1.3) + .7 * Math.sin(driftPhase * 3 + index * .7)) : 0; }

    NumberAnimation on driftPhase {
        from: 0; to: Math.PI * 2; duration: 12000
        loops: Animation.Infinite
        running: root.active
    }

    NumberAnimation on phase {
        objectName: "orbit-signal-animation"
        from: 0; to: 1; duration: 2600
        loops: Animation.Infinite
        running: root.active
    }
    Repeater {
        model: root.active ? 3 : 0
        Rectangle {
            required property int index
            objectName: "orbit-signal-ring-" + index
            readonly property real progress: (root.phase + index / 3) % 1
            x: root.circleX - (width - root.diameter) / 2
            y: root.circleY - (height - root.diameter) / 2
            width: root.diameter * (1 + progress * .35); height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: root.signalColor
            opacity: root.coreProgress * .12 * (1 - progress)
        }
    }
    Repeater {
        objectName: "orbit-network"
        model: root.targets.length === 4 && root.networkStyle !== "wifi" ? 12 : 0
        Shape {
            id: originalRing
            required property int index
            readonly property int ringIndex: Math.floor(index / 4)
            readonly property real angle: (index % 4 - 1) * Math.PI / 2
            objectName: "orbit-network-" + index
            x: root.centerX - root.networkRadiusX - ringIndex * 4 * root.unit
            y: root.centerY - root.networkRadiusY - ringIndex * 4 * root.unit
            width: 2 * (root.networkRadiusX + ringIndex * 4 * root.unit)
            height: 2 * (root.networkRadiusY + ringIndex * 4 * root.unit)
            opacity: .12 + .22 * (.5 + .5 * Math.sin(root.phase * Math.PI * 2 - ringIndex * Math.PI * 2 / 3))
            scale: 1 + Math.sin(root.phase * Math.PI * 2 - ringIndex) * .004
            preferredRendererType: Shape.GeometryRenderer
            ShapePath {
                objectName: "orbit-network-path"
                trim.end: root.ringProgress
                strokeColor: root.signalColor
                strokeWidth: root.unit
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                startX: originalRing.width / 2 * (1 + Math.cos(originalRing.angle))
                startY: originalRing.height / 2 * (1 + Math.sin(originalRing.angle))
                PathArc {
                    x: originalRing.width / 2 * (1 + Math.cos(originalRing.angle + Math.PI / 2))
                    y: originalRing.height / 2 * (1 + Math.sin(originalRing.angle + Math.PI / 2))
                    radiusX: originalRing.width / 2; radiusY: originalRing.height / 2
                    direction: PathArc.Clockwise
                }
            }
        }
    }
    component NetworkLightning: ShaderEffect {
        property vector2d itemSize: Qt.vector2d(width, height)
        property real time: root.lightningTime
        property real strikeProg: 1
        property real scale: root.unit
        property real beamCount: 4
        property color activeColor: root.signalColor
        property vector4d ringGeometry: Qt.vector4d(0, 0, 0, 0)
        property vector4d beam0: Qt.vector4d(-1, -1, -1, -1)
        property vector4d beam1: Qt.vector4d(-1, -1, -1, -1)
        property vector4d beam2: Qt.vector4d(-1, -1, -1, -1)
        property vector4d beam3: Qt.vector4d(-1, -1, -1, -1)
        property vector4d beam4: Qt.vector4d(-1, -1, -1, -1)
        property vector4d beam5: Qt.vector4d(-1, -1, -1, -1)
        property vector4d beam6: Qt.vector4d(-1, -1, -1, -1)
        property vector4d beam7: Qt.vector4d(-1, -1, -1, -1)
        // Keep Qt's cached straight-beam interface separate across shell reloads.
        fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/vfx/node_beams.frag.qsb?curved"
    }
    property real lightningTime: 0
    NumberAnimation on lightningTime {
        objectName: "orbit-network-lightning-animation"
        running: root.active
        loops: Animation.Infinite
        from: 0; to: 1000; duration: 1000000
    }
    Loader {
        objectName: "orbit-network-wifi"
        anchors.fill: parent
        active: root.visible && root.targets.length === 4 && root.networkStyle === "wifi"
        sourceComponent: NetworkLightning {
            objectName: "orbit-network-lightning"
            beamCount: 2
            strikeProg: root.ringProgress
            ringGeometry: Qt.vector4d(root.centerX, root.centerY, root.networkRadiusX, root.networkRadiusY)
        }
    }
    function connectionBeam(index) {
        let target = movingTargets[index];
        return Qt.vector4d(centerX, centerY, target.x + target.width / 2, target.y + target.height / 2);
    }
    Loader {
        objectName: "orbit-connection-wifi"
        anchors.fill: parent
        active: root.visible && root.targets.length === 4 && root.style === "wifi"
        sourceComponent: NetworkLightning {
            opacity: root.connectionOpacity
            beam0: root.connectionBeam(0)
            beam1: root.connectionBeam(1)
            beam2: root.connectionBeam(2)
            beam3: root.connectionBeam(3)
        }
    }
    Repeater {
        model: root.targets.length === 4 ? 4 : 0
        Item {
            id: connection
            objectName: "orbit-connection-" + index
            required property int index
            readonly property rect target: root.connectionTargets[index] || Qt.rect(0, 0, 0, 0)
            anchors.fill: parent
            readonly property real dx: target.x + target.width / 2 - root.centerX
            readonly property real dy: target.y + target.height / 2 - root.centerY
            readonly property real distance: Math.max(1, Math.sqrt(dx * dx + dy * dy))
            readonly property point from: {
                let vx = to.x - root.centerX, vy = to.y - root.centerY;
                let length = Math.max(1, Math.hypot(vx, vy));
                let offset = Math.min(root.diameter / 2 + 8 * root.unit, length);
                return Qt.point(root.centerX + vx / length * offset, root.centerY + vy / length * offset);
            }
            readonly property point to: Math.abs(dx) > Math.abs(dy) ? Qt.point(target.x + (dx > 0 ? 0 : target.width), target.y + target.height / 2) : Qt.point(target.x + target.width / 2, target.y + (dy > 0 ? 0 : target.height))
            readonly property real bendSize: Math.min(24 * root.unit, Math.hypot(to.x - from.x, to.y - from.y) / 2)
            readonly property point bend: Qt.point(-dy / distance * bendSize, dx / distance * bendSize)
            Shape {
                visible: root.style === "link"
                opacity: root.connectionOpacity
                anchors.fill: parent
                preferredRendererType: Shape.GeometryRenderer
                ShapePath {
                    objectName: "orbit-flow-line"
                    strokeColor: Qt.alpha(root.signalColor, .22)
                    strokeWidth: 2 * root.unit
                    fillColor: "transparent"
                    startX: connection.from.x; startY: connection.from.y
                    PathCubic { objectName: "orbit-flow-endpoint"; x: connection.to.x; y: connection.to.y; control1X: connection.from.x + (connection.to.x-connection.from.x)*.3 + connection.bend.x; control1Y: connection.from.y + (connection.to.y-connection.from.y)*.3 + connection.bend.y; control2X: connection.from.x + (connection.to.x-connection.from.x)*.7 - connection.bend.x; control2Y: connection.from.y + (connection.to.y-connection.from.y)*.7 - connection.bend.y }
                }
                ShapePath {
                    objectName: "orbit-flow-highlight"
                    strokeColor: Qt.alpha(root.signalColor, .7)
                    strokeWidth: 3 * root.unit
                    fillColor: "transparent"
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [3, 18]
                    dashOffset: -root.phase * 42
                    startX: connection.from.x; startY: connection.from.y
                    PathCubic { objectName: "orbit-flow-endpoint"; x: connection.to.x; y: connection.to.y; control1X: connection.from.x + (connection.to.x-connection.from.x)*.3 + connection.bend.x; control1Y: connection.from.y + (connection.to.y-connection.from.y)*.3 + connection.bend.y; control2X: connection.from.x + (connection.to.x-connection.from.x)*.7 - connection.bend.x; control2Y: connection.from.y + (connection.to.y-connection.from.y)*.7 - connection.bend.y }
                }
            }
        }
    }
}
